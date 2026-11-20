/*****************************************************************************/
/*                                                                           */
/*                                debugger.c                                 */
/*                                                                           */
/*           Interactive step debugger for the vendored sim65 (sim65i)       */
/*                                                                           */
/*  Mirrors the UX of z80/sim's "simz80 -debug": a REPL with step, next      */
/*  (over JSR), continue, breakpoints, register dump, disassembly and        */
/*  memory dump. Each step shows the executed instruction, register and      */
/*  flag diffs (old -> new) and the consumed cycles. The REPL and guest      */
/*  stdin (PVRead on fd 0) share one console line reader, so both work       */
/*  interactively and when piped.                                            */
/*                                                                           */
/*  This software is provided 'as-is', without any expressed or implied      */
/*  warranty.  In no event will the authors be held liable for any damages   */
/*  arising from the use of this software.                                   */
/*                                                                           */
/*  Permission is granted to anyone to use this software for any purpose,    */
/*  including commercial applications, and to alter and redistribute it      */
/*  freely, subject to the following restrictions:                           */
/*                                                                           */
/*  1. The origin of this software must not be misrepresented; you must not  */
/*     claim that you wrote the original software. If you use this software  */
/*     in a product, an acknowledgment of the product documentation would be */
/*     appreciated but is not required.                                      */
/*  2. Altered source versions must be plainly marked as such, and must not  */
/*     be misrepresented as being the original software.                     */
/*  3. This notice may not be removed or altered from any source             */
/*     distribution.                                                         */
/*                                                                           */
/*****************************************************************************/



#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/types.h>
#include <inttypes.h>

/* sim65 */
#include "6502.h"
#include "debugger.h"
#include "memory.h"
#include "paravirt.h"
#include "peripherals.h"
#include "trace.h"



/*****************************************************************************/
/*                                   Data                                    */
/*****************************************************************************/



int DebuggerActive = 0;
int DbgExitCode = -1;

/* Console line reader shared by the REPL and guest stdin */
static char*  InBuf;
static size_t InCap;
static size_t InLen;
static size_t InPos;
static int    InEOF;

/* Breakpoints (index = address); DoNext uses a temporary one */
static unsigned char Bps[0x10000];

/* Symbol table loaded from the linker map (<program>.map); b/d/x accept
** symbol names in addition to addresses.
*/
typedef struct Sym Sym;
struct Sym {
    const char* Name;
    unsigned    Addr;
    Sym*        Next;
};
static Sym* Syms;

/* Source listing loaded from ca65 -l .lst files (<program>.lst and
** helpers.lst), kept in file order for source-context display mirroring
** the QEMU gdb TUI source window. Each listing offset is segment-local;
** the run address is resolved per segment by anchoring on an exported
** label (base = symbol address - label's listing offset), which stays
** correct when several object files share one linker segment. Segments
** without an exported label fall back to the map's segment start.
*/
typedef struct SrcLine SrcLine;
struct SrcLine {
    unsigned    Offs;       /* listing offset within its segment */
    unsigned    Addr;       /* resolved run address (when HasAddr) */
    unsigned    SegIdx;     /* index into Segments, or SRC_NO_SEG */
    unsigned    HasAddr  :1;
    unsigned    HasBytes :1;
    char        Text[240];  /* source text after the bytes column */
    SrcLine*    Next;
};
#define SRC_MAX_SEGS 16
#define SRC_NO_SEG   255
static struct { char Name[32]; unsigned Start; } Segments[SRC_MAX_SEGS];
static unsigned SegCount;
static SrcLine* SrcLines;
static SrcLine* SrcLinesTail;

/* Run configuration */
static unsigned char     DbgSPAddr;
static unsigned long long MaxCyclesLimit;

/* Last command line, repeated by an empty line */
static char LastCmd[80];

/* Status register bits in display order, with set/clear letters */
static const struct {
    unsigned char Bit;
    char Set;
    char Clear;
} FlagBits[] = {
    { SF, 'N', 'n' },
    { OF, 'V', 'v' },
    { DF, 'D', 'd' },
    { IF, 'I', 'i' },
    { ZF, 'Z', 'z' },
    { CF, 'C', 'c' },
};
#define FLAG_COUNT (sizeof (FlagBits) / sizeof (FlagBits[0]))



/*****************************************************************************/
/*                                   Code                                    */
/*****************************************************************************/



static char* ConsGetLine (const char* Prompt)
/* Read the next console line into the shared buffer. Return NULL on EOF. */
{
    ssize_t Len;

    if (InEOF) {
        return 0;
    }
    fputs (Prompt, stdout);
    fflush (stdout);
    Len = getline (&InBuf, &InCap, stdin);
    if (Len < 0) {
        InEOF = 1;
        InLen = InPos = 0;
        return 0;
    }
    InLen = (size_t) Len;
    InPos = 0;
    return InBuf;
}



int DbgConsoleRead (unsigned char* Buf, unsigned Count)
/* Serve a guest stdin read from the shared console reader. At most one
** line is served per call (a short read is valid), so REPL commands that
** follow in the input stream are not swallowed by the guest.
*/
{
    unsigned Done = 0;

    if (InEOF || Count == 0) {
        return 0;
    }
    if (InPos >= InLen) {
        if (ConsGetLine ("[INPUT]> ") == 0) {
            return 0;
        }
    }
    while (Done < Count && InPos < InLen) {
        unsigned char C = InBuf[InPos++];
        Buf[Done++] = C;
        if (C == '\n') {
            break;
        }
    }
    return Done;
}



static int ParseAddr (const char* S, unsigned* Addr)
/* Parse a hex address ("0100", "$0100" or "0x0100"). Return 0 on failure. */
{
    if (S == 0 || *S == '\0') {
        return 0;
    }
    if (*S == '$') {
        ++S;
    } else if (S[0] == '0' && (S[1] == 'x' || S[1] == 'X')) {
        S += 2;
    }
    if (!isxdigit ((unsigned char) *S)) {
        return 0;
    }
    *Addr = (unsigned) strtoul (S, 0, 16);
    return *Addr <= 0xFFFF;
}



static void SymAdd (const char* Name, unsigned Addr)
/* Add a symbol to the table; the first definition of a name wins */
{
    Sym* S;
    for (S = Syms; S != 0; S = S->Next) {
        if (strcmp (S->Name, Name) == 0) {
            return;
        }
    }
    S = malloc (sizeof (Sym));
    if (S == 0) {
        return;
    }
    S->Name = strdup (Name);
    S->Addr = Addr;
    S->Next = Syms;
    Syms = S;
}



static void DbgLoadSymbols (const char* ProgramFile)
/* Load symbols and the segment list from the linker map (<program>.map),
** if present. The "Exports list by name/value" sections hold name-address-
** type pairs ("_main 000229 RLA ...", several per line); the "Segment
** list" section holds "Name Start End Size Align" rows used to resolve
** listing offsets to run addresses.
*/
{
    char        Path[1024];
    FILE*       F;
    char        Line[1024];
    const char* Dot   = strrchr (ProgramFile, '.');
    const char* Slash = strrchr (ProgramFile, '/');
    int         InExports = 0;
    int         InSegs = 0;

    if (Dot != 0 && (Slash == 0 || Dot > Slash)) {
        snprintf (Path, sizeof (Path), "%.*s.map", (int) (Dot - ProgramFile), ProgramFile);
    } else {
        snprintf (Path, sizeof (Path), "%s.map", ProgramFile);
    }
    F = fopen (Path, "r");
    if (F == 0) {
        return;                     /* no map: symbols stay unavailable */
    }
    while (fgets (Line, sizeof (Line), F) != 0) {
        char*       Save = 0;
        const char* Tok;
        if (strncmp (Line, "Exports list by", 15) == 0) {
            InExports = 1;
            InSegs = 0;
            continue;
        }
        if (strncmp (Line, "Imports list", 12) == 0) {
            InExports = 0;
            continue;
        }
        if (strncmp (Line, "Segment list:", 13) == 0) {
            InSegs = 1;
            InExports = 0;
            continue;
        }
        if (InSegs) {
            /* "NAME  SSSSSS  EEEEEE  ZZZZZZ  AAAAAA" (header dashes fail) */
            char Name[32];
            unsigned Start;
            char Sep;
            int  N = sscanf (Line, "%31s %6x%c", Name, &Start, &Sep);
            if (N >= 2 && strlen (Name) > 0 && SegCount < SRC_MAX_SEGS &&
                strcmp (Name, "Name") != 0 && Name[0] != '-') {
                strcpy (Segments[SegCount].Name, Name);
                Segments[SegCount].Start = Start;
                ++SegCount;
            }
            continue;
        }
        if (!InExports) {
            continue;
        }
        Tok = strtok_r (Line, " \t\r\n", &Save);
        while (Tok != 0) {
            const char* Next = strtok_r (0, " \t\r\n", &Save);
            int         Hex = (Next != 0 && strlen (Next) == 6);
            const char* P;
            if (Hex) {
                for (P = Next; *P != '\0'; ++P) {
                    if (!isxdigit ((unsigned char) *P)) {
                        Hex = 0;
                        break;
                    }
                }
            }
            if (Hex) {
                SymAdd (Tok, (unsigned) strtoul (Next, 0, 16));
                Tok = strtok_r (0, " \t\r\n", &Save);   /* skip the address */
            } else {
                Tok = Next;
            }
        }
    }
    fclose (F);
}



static int ResolveArg (const char* S, unsigned* Addr)
/* Parse an argument as a hex address or a symbol name. Return 0 on failure. */
{
    Sym* S2;
    if (ParseAddr (S, Addr)) {
        return 1;
    }
    for (S2 = Syms; S2 != 0; S2 = S2->Next) {
        if (strcmp (S2->Name, S) == 0) {
            *Addr = S2->Addr;
            return 1;
        }
    }
    return 0;
}



static int SymLookup (const char* Name, unsigned* Addr)
/* Find an exported symbol by exact name. Return 0 when absent. */
{
    Sym* S;
    for (S = Syms; S != 0; S = S->Next) {
        if (strcmp (S->Name, Name) == 0) {
            *Addr = S->Addr;
            return 1;
        }
    }
    return 0;
}

static unsigned SegFind (const char* Name)
/* Segment index for Name from the map, or SRC_NO_SEG. */
{
    unsigned I;
    for (I = 0; I < SegCount; ++I) {
        if (strcmp (Segments[I].Name, Name) == 0) {
            return I;
        }
    }
    return SRC_NO_SEG;
}

static void SrcAppend (SrcLine* S)
/* Append to the file-ordered listing list. */
{
    if (SrcLinesTail == 0) {
        SrcLines = S;
    } else {
        SrcLinesTail->Next = S;
    }
    SrcLinesTail = S;
}

static void DbgLoadListing (const char* Path)
/* Parse one ca65 listing file and resolve its offsets to run addresses.
** Rows look like "000000r 1  A9 rr      lda #<x": segment offset, 'r',
** file number, emitted bytes (two hex digits or the "rr" placeholder)
** and the source text. A .segment directive switches the segment used
** for the rows that follow.
*/
{
    FILE*       F = fopen (Path, "r");
    char        Line[1024];
    unsigned    CurSeg = SRC_NO_SEG;
    SrcLine*    First = SrcLinesTail;     /* tail before this file */

    if (F == 0) {
        return;
    }
    while (fgets (Line, sizeof (Line), F) != 0) {
        unsigned    Offs;
        char        Rel;
        const char* P;
        char*       T;
        int         HasBytes = 0;
        SrcLine*    S;

        if (sscanf (Line, "%6x%c", &Offs, &Rel) != 2) {
            continue;
        }
        if (Rel != 'r' && Rel != 'R') {
            continue;
        }
        P = Line;
        while (isxdigit ((unsigned char) *P)) {
            ++P;                          /* offset column */
        }
        ++P;                              /* relocation flag */
        while (isspace ((unsigned char) *P)) {
            ++P;
        }
        while (isdigit ((unsigned char) *P)) {
            ++P;                          /* file-number column */
        }
        while (isspace ((unsigned char) *P)) {
            ++P;
        }
        /* Skip emitted bytes: two hex digits or the "rr" placeholder. */
        {
            const char* Q = P;
            for (;;) {
                const char* Tok = Q;
                while (*Q != '\0' && *Q != ' ' && *Q != '\t') {
                    ++Q;
                }
                if (Q - Tok == 2 &&
                    ((isxdigit ((unsigned char) Tok[0]) && isxdigit ((unsigned char) Tok[1])) ||
                     (Tok[0] == 'r' && Tok[1] == 'r'))) {
                    HasBytes = 1;
                    while (*Q == ' ' || *Q == '\t') {
                        ++Q;
                    }
                    continue;
                }
                Q = Tok;      /* not an emitted byte: rewind to its start */
                break;
            }
            P = Q;
        }
        while (*P == ' ' || *P == '\t') {
            ++P;
        }
        S = calloc (1, sizeof (*S));
        if (S == 0) {
            fclose (F);
            return;
        }
        S->Offs = Offs;
        S->SegIdx = CurSeg;
        S->HasBytes = (unsigned) HasBytes;
        for (T = S->Text; *P != '\0' && *P != '\n' && *P != '\r' &&
                        T < S->Text + sizeof (S->Text) - 1; ++P) {
            *T++ = (*P == '\t') ? ' ' : *P;
        }
        *T = '\0';
        while (T > S->Text && T[-1] == ' ') {
            *--T = '\0';
        }
        SrcAppend (S);
        /* A .segment directive switches the segment for the NEXT row. */
        if (strncmp (S->Text, ".segment", 8) == 0) {
            const char* Q1 = strchr (S->Text, '"');
            const char* Q2 = (Q1 != 0) ? strchr (Q1 + 1, '"') : 0;
            if (Q2 != 0) {
                char Name[32];
                size_t Len = Q2 - Q1 - 1;
                if (Len >= sizeof (Name)) {
                    Len = sizeof (Name) - 1;
                }
                memcpy (Name, Q1 + 1, Len);
                Name[Len] = '\0';
                CurSeg = SegFind (Name);
            }
        }
    }
    fclose (F);
    /* Resolve run addresses per segment, using only the rows added by
    ** this file: anchor on the first exported label of the segment
    ** (base = symbol address - listing offset), falling back to the
    ** map's segment start.
    */
    {
        unsigned Seg;
        SrcLine* S;
        SrcLine* From = (First != 0) ? First->Next : SrcLines;
        for (Seg = 0; Seg < SegCount; ++Seg) {
            unsigned Base = Segments[Seg].Start;
            for (S = From; S != 0; S = S->Next) {
                char     Lbl[64];
                unsigned A;
                if (S->SegIdx != Seg) {
                    continue;
                }
                if (sscanf (S->Text, "%63[a-zA-Z_0-9]:", Lbl) == 1 &&
                    SymLookup (Lbl, &A) && A >= S->Offs) {
                    Base = A - S->Offs;
                    break;
                }
            }
            for (S = From; S != 0; S = S->Next) {
                if (S->SegIdx == Seg) {
                    S->Addr = Base + S->Offs;
                    S->HasAddr = 1;
                }
            }
        }
    }
}

static void DbgLoadSource (const char* ProgramFile)
/* Load <program>.lst and helpers.lst (when present). */
{
    char        Path[1024];
    char        Dir[1024];
    const char* Dot   = strrchr (ProgramFile, '.');
    const char* Slash = strrchr (ProgramFile, '/');
    size_t      DirLen;

    if (Dot != 0 && (Slash == 0 || Dot > Slash)) {
        snprintf (Path, sizeof (Path), "%.*s.lst", (int) (Dot - ProgramFile), ProgramFile);
    } else {
        snprintf (Path, sizeof (Path), "%s.lst", ProgramFile);
    }
    DbgLoadListing (Path);

    DirLen = (Slash != 0) ? (size_t) (Slash + 1 - ProgramFile) : 0;
    if (DirLen < sizeof (Dir)) {
        memcpy (Dir, ProgramFile, DirLen);
        Dir[DirLen] = '\0';
        snprintf (Path, sizeof (Path), "%shelpers.lst", Dir);
        DbgLoadListing (Path);
    }
}

static SrcLine* SrcLineForAddr (unsigned Addr)
/* Exact-match lookup of a byte-bearing listing row at Addr. */
{
    SrcLine* S;
    for (S = SrcLines; S != 0; S = S->Next) {
        if (S->HasAddr && S->HasBytes && S->Addr == Addr) {
            return S;
        }
    }
    return 0;
}

static int SrcWindow (unsigned Addr, int Before, int After)
/* Print the listing rows around Addr like the TUI source window.
** Returns the number of rows printed (0 = no source at Addr).
*/
{
    SrcLine* Cur = SrcLineForAddr (Addr);
    SrcLine* S;
    int      Pos = 0, Start, I;

    if (Cur == 0) {
        return 0;
    }
    for (S = SrcLines; S != Cur; S = S->Next) {
        ++Pos;
    }
    Start = Pos - Before;
    if (Start < 0) {
        Start = 0;
    }
    S = SrcLines;
    for (I = 0; I < Start && S != 0; ++I) {
        S = S->Next;
    }
    for (I = Start; S != 0 && I <= Pos + After; ++I) {
        if (S->HasAddr) {
            printf ("%04X %s %s\n", S->Addr, (S == Cur) ? "◀" : " ", S->Text);
        } else {
            printf ("      %s %s\n", (S == Cur) ? "◀" : " ", S->Text);
        }
        S = S->Next;
    }
    return 1;
}



static const char* SymName (unsigned Addr)
/* Return the first symbol defined at ADDR, or 0 */
{
    Sym* S;
    for (S = Syms; S != 0; S = S->Next) {
        if (S->Addr == Addr) {
            return S->Name;
        }
    }
    return 0;
}



static void FormatFlags (uint8_t SR, char* Buf)
/* Format the status register as "NVDIZC" letters (set = upper case) */
{
    unsigned I;
    for (I = 0; I < FLAG_COUNT; ++I) {
        *Buf++ = (SR & FlagBits[I].Bit) ? FlagBits[I].Set : FlagBits[I].Clear;
    }
    *Buf = '\0';
}



static void DumpRegs (void)
/* Print the CPU registers plus the cc65 software stack pointer */
{
    char Flags[FLAG_COUNT + 1];
    FormatFlags (Regs.SR, Flags);
    printf ("A=%02X X=%02X Y=%02X S=%02X\n", Regs.AC, Regs.XR, Regs.YR, Regs.SP);
    printf ("PC=%04X  P=%s ($%02X)\n", Regs.PC, Flags, Regs.SR);
    printf ("SP=%04X (cc65)  instr=%" PRIu64 "  cycles=%" PRIu64 "\n",
            MemReadZPWord (DbgSPAddr),
            Peripherals.Counter.CpuInstructions,
            Peripherals.Counter.ClockCycles);
}



static void DisasmLine (unsigned Addr, int Mark)
/* Print one disassembly line: "addr  opcode bytes  mnemonic and operand" */
{
    char Text[64];
    unsigned Len = TraceInsnLen (Addr);
    unsigned I;

    TraceDisasmText (Addr, Text);
    printf ("%04X  ", Addr);
    for (I = 0; I < 3; ++I) {
        if (I < Len) {
            printf ("%02X ", MemReadByte ((Addr + I) & 0xFFFF));
        } else {
            fputs ("   ", stdout);
        }
    }
    printf (" %-16s %s\n", Text, Mark ? "◀ PC" : "");
}



static void DisasmWindow (unsigned Addr, unsigned Count)
/* Print Count disassembly lines starting at Addr, marking the current PC */
{
    while (Count--) {
        DisasmLine (Addr, Addr == Regs.PC);
        Addr = (Addr + TraceInsnLen (Addr)) & 0xFFFF;
    }
}



static void ShowStep (CPURegs Prev, unsigned Cycles, uint64_t PrevNmi, uint64_t PrevIrq)
/* Print the step header, the executed instruction or interrupt, the
** register and flag diffs, and a source window at the new PC.
*/
{
    char Flags[2][FLAG_COUNT + 1];
    unsigned I;
    int Any;

    printf ("── #%" PRIu64 "  CYC+%u (total %" PRIu64 ") ──\n",
            Peripherals.Counter.CpuInstructions, Cycles,
            Peripherals.Counter.ClockCycles);

    if (Peripherals.Counter.NmiEvents != PrevNmi) {
        puts ("  *** NMI ***");
    } else if (Peripherals.Counter.IrqEvents != PrevIrq) {
        puts ("  *** IRQ ***");
    } else if (Prev.PC >= PARAVIRT_BASE) {
        printf ("  *** paravirt $%04X ***\n", Prev.PC);
    } else {
        SrcLine* Src = SrcLineForAddr (Prev.PC);
        if (Src != 0) {
            /* Listing row found: show the source text with real bytes. */
            unsigned Len = TraceInsnLen (Prev.PC);
            unsigned I;
            printf ("%04X  ", Prev.PC);
            for (I = 0; I < 3; ++I) {
                if (I < Len) {
                    printf ("%02X ", MemReadByte ((Prev.PC + I) & 0xFFFF));
                } else {
                    fputs ("   ", stdout);
                }
            }
            printf (" %s\n", Src->Text);
        } else {
            DisasmLine (Prev.PC, 0);
        }
    }

    /* Register diffs */
    if (Prev.AC != Regs.AC) {
        printf ("  A   %02X → %02X\n", Prev.AC, Regs.AC);
    }
    if (Prev.XR != Regs.XR) {
        printf ("  X   %02X → %02X\n", Prev.XR, Regs.XR);
    }
    if (Prev.YR != Regs.YR) {
        printf ("  Y   %02X → %02X\n", Prev.YR, Regs.YR);
    }
    if (Prev.SP != Regs.SP) {
        printf ("  S   %02X → %02X\n", Prev.SP, Regs.SP);
    }

    /* Flag diffs */
    FormatFlags (Prev.SR, Flags[0]);
    FormatFlags (Regs.SR, Flags[1]);
    Any = 0;
    for (I = 0; I < FLAG_COUNT; ++I) {
        if (Flags[0][I] != Flags[1][I]) {
            if (!Any) {
                fputs ("  flags", stdout);
                Any = 1;
            }
            printf (" %c %d→%d", FlagBits[I].Set,
                    (Prev.SR & FlagBits[I].Bit) != 0,
                    (Regs.SR & FlagBits[I].Bit) != 0);
        }
    }
    if (Any) {
        putchar ('\n');
    }

    /* Source window at the new PC (skipped once the program has exited:
    ** the paravirt exit leaves the PC meaningless. Falls back to the
    ** disassembly window when no listing row matches (e.g. in crt0).
    */
    if (DbgExitCode < 0) {
        if (SrcWindow (Regs.PC, 1, 3) == 0) {
            DisasmWindow (Regs.PC, 3);
        }
    }
}



static int DoStep (void)
/* Execute one instruction and show the step. Return 0 while running. */
{
    CPURegs Prev = Regs;
    uint64_t PrevNmi = Peripherals.Counter.NmiEvents;
    uint64_t PrevIrq = Peripherals.Counter.IrqEvents;
    unsigned Cycles = ExecuteInsn ();

    ShowStep (Prev, Cycles, PrevNmi, PrevIrq);
    return DbgExitCode >= 0;
}



static int DoContinue (void)
/* Run until a breakpoint, program exit or the cycle limit. */
{
    unsigned long long Remain = MaxCyclesLimit;

    while (1) {
        CPURegs Prev = Regs;
        uint64_t PrevNmi = Peripherals.Counter.NmiEvents;
        uint64_t PrevIrq = Peripherals.Counter.IrqEvents;
        unsigned Cycles = ExecuteInsn ();

        if (MaxCyclesLimit) {
            if (Cycles > Remain) {
                printf ("stopped: cycle limit reached (%llu cycles)\n",
                        MaxCyclesLimit);
                return 1;
            }
            Remain -= Cycles;
        }
        if (DbgExitCode >= 0 || Bps[Regs.PC]) {
            ShowStep (Prev, Cycles, PrevNmi, PrevIrq);
            return DbgExitCode >= 0;
        }
    }
}



static int DoNext (void)
/* Step over a JSR; single-step any other instruction. */
{
    if (MemReadByte (Regs.PC) == 0x20) {        /* JSR */
        unsigned Addr = (Regs.PC + 3) & 0xFFFF;
        unsigned char Saved = Bps[Addr];
        int Exited;

        Bps[Addr] = 1;
        Exited = DoContinue ();
        Bps[Addr] = Saved;
        return Exited;
    }
    return DoStep ();
}



static void SetBreakpoint (const char* Arg)
/* Toggle a breakpoint at ADDR or SYM, or list all breakpoints */
{
    unsigned Addr, I, Any = 0;
    const char* Name;

    if (Arg == 0 || *Arg == '\0') {
        fputs ("breakpoints:", stdout);
        for (I = 0; I < 0x10000; ++I) {
            if (Bps[I]) {
                Name = SymName (I);
                if (Name != 0) {
                    printf (" $%04X (%s)", I, Name);
                } else {
                    printf (" $%04X", I);
                }
                Any = 1;
            }
        }
        puts (Any ? "" : " (none)");
        return;
    }
    if (!ResolveArg (Arg, &Addr)) {
        printf ("bad address or symbol: %s\n", Arg);
        return;
    }
    Bps[Addr] = !Bps[Addr];
    Name = SymName (Addr);
    if (Name != 0) {
        printf ("breakpoint $%04X (%s) %s\n", Addr, Name, Bps[Addr] ? "set" : "cleared");
    } else {
        printf ("breakpoint $%04X %s\n", Addr, Bps[Addr] ? "set" : "cleared");
    }
}



static void DisasmCmd (const char* Arg1, const char* Arg2)
/* "d [ADDR|SYM] [N]": disassemble N instructions (default 10) at ADDR (default PC) */
{
    unsigned Addr = Regs.PC, Count = 10;

    if (Arg1 && *Arg1 && !ResolveArg (Arg1, &Addr)) {
        printf ("bad address or symbol: %s\n", Arg1);
        return;
    }
    if (Arg2 && *Arg2) {
        Count = (unsigned) strtoul (Arg2, 0, 0);
        if (Count == 0 || Count > 100) {
            printf ("bad count: %s\n", Arg2);
            return;
        }
    }
    DisasmWindow (Addr, Count);
}



static void HexDump (const char* Arg1, const char* Arg2)
/* "x ADDR|SYM [N]": dump N lines of 16 bytes (default 1) starting at ADDR */
{
    unsigned Addr, Rows = 1, I, R;

    if (!ResolveArg (Arg1, &Addr)) {
        puts ("usage: x ADDR [N]");
        return;
    }
    if (Arg2 && *Arg2) {
        Rows = (unsigned) strtoul (Arg2, 0, 0);
        if (Rows == 0 || Rows > 64) {
            printf ("bad row count: %s\n", Arg2);
            return;
        }
    }
    for (R = 0; R < Rows; ++R) {
        printf ("%04X:", Addr);
        for (I = 0; I < 16; ++I) {
            printf (" %02X", MemReadByte ((Addr + I) & 0xFFFF));
        }
        putchar ('\n');
        Addr = (Addr + 16) & 0xFFFF;
    }
}



void DebuggerRun (unsigned long long MaxCycles, uint8_t SPAddr, const char* ProgramFile)
/* Interactive step debugger main loop */
{
    char Cmd[80];

    DbgSPAddr = SPAddr;
    MaxCyclesLimit = MaxCycles;
    strcpy (LastCmd, "s");
    if (ProgramFile != 0) {
        DbgLoadSymbols (ProgramFile);
        DbgLoadSource (ProgramFile);
    }

    printf ("sim65i debugger — commands: s=step  n=next(JSR)  c=continue  "
            "b ADDR|SYM=breakpoint  r=regs  d [ADDR|SYM]=disasm  src [ADDR|SYM]=source  x ADDR|SYM=mem  q=quit\n");

    while (1) {
        char* Word;
        char* Arg1;
        char* Arg2;

        if (DbgExitCode >= 0) {
            printf ("stopped: exit (code %d)\n", DbgExitCode);
            return;
        }

        if (ConsGetLine ("> ") == 0) {
            return;                         /* EOF quits the debugger */
        }

        /* The command line is consumed by the REPL, never by the guest */
        while (InLen > 0 && (InBuf[InLen - 1] == '\n' || InBuf[InLen - 1] == '\r')) {
            InBuf[--InLen] = '\0';
        }
        InPos = InLen;

        if (InBuf[0] == '\0') {
            /* An empty line repeats the last command */
            strcpy (Cmd, LastCmd);
        } else {
            strncpy (Cmd, InBuf, sizeof (Cmd) - 1);
            Cmd[sizeof (Cmd) - 1] = '\0';
            strcpy (LastCmd, Cmd);
        }

        Word = strtok (Cmd, " \t");
        Arg1 = strtok (0, " \t");
        Arg2 = strtok (0, " \t");

        if (Word == 0) {
            continue;
        }

        if (strcmp (Word, "s") == 0 || strcmp (Word, "si") == 0 || strcmp (Word, "step") == 0) {
            DoStep ();
        } else if (strcmp (Word, "n") == 0 || strcmp (Word, "next") == 0) {
            DoNext ();
        } else if (strcmp (Word, "c") == 0 || strcmp (Word, "cont") == 0 || strcmp (Word, "continue") == 0) {
            DoContinue ();
        } else if (strcmp (Word, "b") == 0) {
            SetBreakpoint (Arg1);
        } else if (strcmp (Word, "r") == 0 || strcmp (Word, "regs") == 0) {
            DumpRegs ();
        } else if (strcmp (Word, "d") == 0 || strcmp (Word, "disasm") == 0) {
            DisasmCmd (Arg1, Arg2);
        } else if (strcmp (Word, "src") == 0 || strcmp (Word, "source") == 0) {
            unsigned Addr = Regs.PC;
            if (Arg1 != 0 && !ResolveArg (Arg1, &Addr)) {
                printf ("bad address or symbol '%s'\n", Arg1);
            } else if (SrcWindow (Addr, 3, 3) == 0) {
                puts ("no source line at this address (.lst not found or segment unresolved)");
            }
        } else if (strcmp (Word, "x") == 0 || strcmp (Word, "mem") == 0) {
            HexDump (Arg1, Arg2);
        } else if (strcmp (Word, "q") == 0 || strcmp (Word, "quit") == 0) {
            return;
        } else if (strcmp (Word, "h") == 0 || strcmp (Word, "?") == 0 || strcmp (Word, "help") == 0) {
            puts ("s=step  n=next(JSR)  c=continue  b ADDR|SYM=breakpoint  r=regs  "
                  "d [ADDR|SYM] [N]=disasm  src [ADDR|SYM]=source  x ADDR|SYM [N]=mem  q=quit  "
                  "(empty line repeats last command)");
        } else {
            printf ("unknown command '%s' (h for help)\n", Word);
        }
    }
}

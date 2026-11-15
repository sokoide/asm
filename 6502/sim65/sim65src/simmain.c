/*****************************************************************************/
/*                                                                           */
/*                                 simmain.c                                 */
/*                                                                           */
/*        Standalone main program for the vendored sim65 (sim65i)            */
/*                                                                           */
/*  Based on cc65's sim65/main.c (V2.19, zlib license, see LICENSE).         */
/*  Rewritten to drop the cc65 command line infrastructure and to keep the   */
/*  simulator buildable inside this repository. IRQ/NMI support is already   */
/*  present in 6502.c (IRQRequest/NMIRequest); this build exposes it via     */
/*  memory-mapped interrupt triggers in memory.c.                            */
/*                                                                           */
/*  This software is provided 'as-is', without any expressed or implied      */
/*  warranty.  In no event will the authors be held liable for any damages   */
/*  arising from the use of this software.                                   */
/*                                                                           */
/*  Permission is granted to anyone to use this software for any purpose,    */
/*  including commercial applications, and to alter it and redistribute it   */
/*  freely, subject to the following restrictions:                           */
/*                                                                           */
/*  1. The origin of this software must not be misrepresented; you must not  */
/*     claim that you wrote the original software. If you use this software  */
/*     in a product, an acknowledgment in the product documentation would be */
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
#include <errno.h>

#include "6502.h"
#include "debugger.h"
#include "error.h"
#include "memory.h"
#include "paravirt.h"
#include "peripherals.h"
#include "trace.h"
#include "compat/cmdline.h"
#include "compat/print.h"



/*****************************************************************************/
/*                                   Data                                    */
/*****************************************************************************/



/* Name of program file */
static const char* ProgramFile;

/* Exit simulator after MaxCycles (0 = unlimited) */
static unsigned long long MaxCycles = 0;

/* Run the interactive step debugger */
static int DebugMode = 0;

/* Program header */
static const unsigned char HeaderSignature[] = {
    0x73, 0x69, 0x6D, 0x36, 0x35                 /* "sim65" */
};
#define HEADER_SIGNATURE_LENGTH (sizeof(HeaderSignature)/sizeof(HeaderSignature[0]))
static const unsigned char HeaderVersion = 2;

/* CPU type (defined in 6502.c) */
extern CPUType CPU;



/*****************************************************************************/
/*                                   Code                                    */
/*****************************************************************************/



static void Usage (void)
{
    printf ("Usage: sim65i [options] file\n"
            "sim65 variant with IRQ/NMI support (repo-local build)\n"
            "Short options:\n"
            "  -h\t\t\tHelp (this text)\n"
            "  -c\t\t\tPrint amount of executed CPU cycles\n"
            "  -g\t\t\tInteractive step debugger\n"
            "  -t\t\t\tEnable CPU trace\n"
            "  -v\t\t\tIncrease verbosity\n"
            "  -x <num>\t\tExit simulator after <num> cycles\n");
}



static unsigned char ReadProgramFile (void)
/* Load program into memory */
{
    unsigned I;
    int Val, Val2;
    unsigned char SPAddr = 0x00;
    unsigned Addr;
    unsigned Load, Reset;

    /* Open the file */
    FILE* F = fopen (ProgramFile, "rb");
    if (F == 0) {
        Error ("Cannot open '%s': %s", ProgramFile, strerror (errno));
    }

    /* Verify the header signature */
    for (I = 0; I < HEADER_SIGNATURE_LENGTH; ++I) {
        if ((Val = fgetc(F)) != HeaderSignature[I]) {
            Error ("'%s': Invalid header signature.", ProgramFile);
        }
    }

    /* Get header version */
    if (fgetc(F) != HeaderVersion) {
        Error ("'%s': Invalid header version.", ProgramFile);
    }

    /* Get the CPU type from the file header */
    if ((Val = fgetc(F)) != EOF) {
        if (Val != CPU_6502 && Val != CPU_65C02) {
            Error ("'%s': Invalid CPU type", ProgramFile);
        }
        CPU = Val;
    }

    /* Get the address of sp from the file header */
    if ((Val = fgetc(F)) != EOF) {
        SPAddr = Val;
    }

    /* Get load address */
    if (((Val = fgetc(F)) == EOF) ||
        ((Val2 = fgetc(F)) == EOF)) {
        Error ("'%s': Header missing load address", ProgramFile);
    }
    Load = Val | (Val2 << 8);

    /* Get reset address */
    if (((Val = fgetc(F)) == EOF) ||
        ((Val2 = fgetc(F)) == EOF)) {
        Error ("'%s': Header missing reset address", ProgramFile);
    }
    Reset = Val | (Val2 << 8);

    /* Read the file body into memory */
    Addr = Load;
    while ((Val = fgetc(F)) != EOF) {
        if (Addr >= PARAVIRT_BASE) {
            Error ("'%s': To large to fit into $%04X-$%04X", ProgramFile, Addr, PARAVIRT_BASE);
        }
        MemWriteByte (Addr++, (unsigned char) Val);
    }

    if (ferror (F)) {
        Error ("Error reading from '%s': %s", ProgramFile, strerror (errno));
    }
    fclose (F);

    Print (stderr, 1, "Loaded '%s' at $%04X-$%04X\n", ProgramFile, Load, Addr - 1);
    Print (stderr, 1, "Reset: $%04X\n", Reset);

    MemWriteWord (0xFFFC, Reset);
    return SPAddr;
}



int main (int argc, char* argv[])
{
    unsigned char SPAddr;

    /* Parse the command line */
    for (int I = 1; I < argc; ++I) {
        const char* Arg = argv[I];
        if (Arg[0] == '-') {
            if (strcmp (Arg, "--trace") == 0) {
                TraceMode = TRACE_ENABLE_FULL;
                continue;
            }
            if (strcmp (Arg, "--debug") == 0) {
                DebugMode = 1;
                continue;
            }
            switch (Arg[1]) {
                case 'c':
                    PrintCycles = 1;
                    break;
                case 'g':
                    DebugMode = 1;
                    break;
                case 'v':
                    ++Verbosity;
                    break;
                case 't':
                    TraceMode = TRACE_ENABLE_FULL;
                    break;
                case 'x':
                    if (++I >= argc) {
                        fprintf (stderr, "sim65i: missing argument for -x\n");
                        return EXIT_FAILURE;
                    }
                    MaxCycles = strtoull (argv[I], NULL, 0);
                    break;
                case 'h':
                case '?':
                    Usage ();
                    return EXIT_SUCCESS;
                default:
                    fprintf (stderr, "sim65i: unknown option '%s'\n", Arg);
                    Usage ();
                    return EXIT_FAILURE;
            }
        } else {
            ProgramFile = Arg;
            break;
        }
    }

    if (ProgramFile == 0) {
        Usage ();
        return EXIT_FAILURE;
    }

    MemInit ();
    PeripheralsInit ();
    SPAddr = ReadProgramFile ();
    TraceInit (SPAddr);
    ParaVirtInit (0, SPAddr);
    Reset ();

    if (DebugMode) {
        DebuggerActive = 1;
        DebuggerRun (MaxCycles, SPAddr);
        return EXIT_SUCCESS;
    }

    unsigned long long RemainCycles = MaxCycles;
    while (1) {
        unsigned long Cycles = ExecuteInsn ();
        if (MaxCycles) {
            if (Cycles > RemainCycles) {
                ErrorCode (SIM65_ERROR_TIMEOUT, "Maximum number of cycles reached.");
            }
            RemainCycles -= Cycles;
        }
    }

    return EXIT_SUCCESS;
}

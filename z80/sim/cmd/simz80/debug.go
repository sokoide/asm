// Interactive step debugger (-debug), per-instruction trace (-trace)
// and cycle summary (-cycles) modes.

package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// regState is a register snapshot used for old -> new diffs.
type regState struct {
	a, f, b, c, d, e, h, l         byte
	a_, f_, b_, c_, d_, e_, h_, l_ byte
	ixh, ixl, iyh, iyl             byte
	i, r, im                       byte
	iff1, iff2                     byte
	sp, pc                         uint16
}

func snapshot(z *Z80) regState {
	boolByte := func(b bool) byte {
		if b {
			return 1
		}
		return 0
	}
	return regState{
		z.a, z.f, z.b, z.c, z.d, z.e, z.h, z.l,
		z.a_, z.f_, z.b_, z.c_, z.d_, z.e_, z.h_, z.l_,
		z.ixh, z.ixl, z.iyh, z.iyl,
		z.i, z.r, z.im, boolByte(z.iff1), boolByte(z.iff2),
		z.sp, z.pc,
	}
}

// flagsString renders the documented flags S Z . H . P/V N C as set/clear.
func flagsString(f byte) string {
	s := func(bit byte, name string) string {
		if f&bit != 0 {
			return name
		}
		return "."
	}
	return s(SF, "S") + s(ZF, "Z") + "." + s(HF, "H") + "." +
		s(PF, "V") + s(NF, "N") + s(CF, "C")
}

// regDiffs formats "name old -> new" lines for every changed register.
// Returns nil when nothing changed.
func regDiffs(prev, cur regState) []string {
	type pair struct {
		name string
		o, n byte
	}
	bytePairs := []pair{
		{"A", prev.a, cur.a}, {"F", prev.f, cur.f},
		{"B", prev.b, cur.b}, {"C", prev.c, cur.c},
		{"D", prev.d, cur.d}, {"E", prev.e, cur.e},
		{"H", prev.h, cur.h}, {"L", prev.l, cur.l},
		{"IXH", prev.ixh, cur.ixh}, {"IXL", prev.ixl, cur.ixl},
		{"IYH", prev.iyh, cur.iyh}, {"IYL", prev.iyl, cur.iyl},
		{"I", prev.i, cur.i}, {"R", prev.r, cur.r}, {"IM", prev.im, cur.im},
		{"IFF1", prev.iff1, cur.iff1}, {"IFF2", prev.iff2, cur.iff2},
		{"A'", prev.a_, cur.a_}, {"F'", prev.f_, cur.f_},
		{"B'", prev.b_, cur.b_}, {"C'", prev.c_, cur.c_},
		{"D'", prev.d_, cur.d_}, {"E'", prev.e_, cur.e_},
		{"H'", prev.h_, cur.h_}, {"L'", prev.l_, cur.l_},
	}
	var out []string
	for _, p := range bytePairs {
		if p.o != p.n {
			out = append(out, fmt.Sprintf("%-3s %02X → %02X", p.name, p.o, p.n))
		}
	}
	if prev.sp != cur.sp {
		out = append(out, fmt.Sprintf("SP  %04X → %04X", prev.sp, cur.sp))
	}
	return out
}

// flagDiffs renders per-flag changes like "S 0→1  H 0→1", or nil.
func flagDiffs(prevF, curF byte) []string {
	names := []string{"S", "Z", "H", "P/V", "N", "C"}
	bits := []byte{SF, ZF, HF, PF, NF, CF}
	var out []string
	for i, name := range names {
		o := prevF & bits[i]
		n := curF & bits[i]
		if o != n {
			v := "0→1"
			if n == 0 {
				v = "1→0"
			}
			out = append(out, fmt.Sprintf("%s %s", name, v))
		}
	}
	return out
}

// stopReason explains why Step() returned false.
func (z *Z80) stopReason() string {
	switch {
	case z.pc == 0x0000:
		return "program returned to 0x0000 (CP/M warm boot) — exit"
	case z.halted:
		return "HALT executed"
	default:
		return fmt.Sprintf("instruction limit reached (%d T-states)", z.maxCycles)
	}
}

// Debugger is the interactive REPL.
type Debugger struct {
	z   *Z80
	lst *Listing
	in  *bufio.Reader // shared stdin (also feeds BDOS input prompts)
	bps map[uint16]bool
}

func newDebugger(z *Z80, lst *Listing) *Debugger {
	d := &Debugger{z: z, lst: lst, in: bufio.NewReader(os.Stdin), bps: map[uint16]bool{}}
	// BDOS console input falls back to a prompt in debug mode.
	z.lineReader = func() string {
		fmt.Print("[INPUT]> ")
		line, err := d.in.ReadString('\n')
		if err != nil && line == "" {
			return ""
		}
		return line
	}
	return d
}

func (d *Debugger) window(pc uint16, n int) {
	for _, ins := range d.lst.Window(pc, n) {
		fmt.Println(formatInsn(ins, ins.Addr == pc))
	}
}

// showStep prints the just-executed instruction, its register/flag diffs
// and the next few instructions.
func (d *Debugger) showStep(prev regState) {
	z := d.z
	if z.lastBDOS {
		fmt.Printf("── #%d  T+0 (host call) ──\n%s\n", z.instrCount, z.bdosLine())
	} else if z.lastINT {
		fmt.Printf("── #%d  T+%d (total %d) ──\n%s\n", z.instrCount, z.lastT, z.cycles, z.lastINTText)
	} else {
		fmt.Printf("── #%d  T+%d (total %d) ──\n", z.instrCount, z.lastT, z.cycles)
		fmt.Println(z.disasmLine(z.lastPc, d.lst, false))
	}
	if diffs := regDiffs(prev, snapshot(z)); len(diffs) > 0 {
		fmt.Println("   " + strings.Join(diffs, "   "))
	}
	if fd := flagDiffs(prev.f, z.f); len(fd) > 0 {
		fmt.Printf("   flags: F %02X → %02X (%s)  %s\n", prev.f, z.f, flagsString(z.f), strings.Join(fd, "  "))
	}
	if z.halted || z.pc == 0x0000 {
		fmt.Println("   stopped: " + z.stopReason())
		return
	}
	d.window(z.pc, 3)
}

func (d *Debugger) run() {
	z := d.z
	n := 0
	if d.lst != nil {
		n = len(d.lst.insns)
	}
	fmt.Printf("simz80 step debugger — %d listed instructions\n", n)
	fmt.Println("commands: s=step  n=next(call)  c=continue  b ADDR=breakpoint  r=regs  d [ADDR]=disasm  x ADDR=mem  q=quit")
	fmt.Println()
	d.window(z.pc, 5)

	prev := snapshot(z)
	lastCmd := "s"
	for {
		if z.halted || z.pc == 0x0000 {
			fmt.Println("stopped: " + z.stopReason())
			break
		}
		fmt.Print("> ")
		line, err := d.in.ReadString('\n')
		if err != nil && line == "" {
			fmt.Println()
			break // EOF
		}
		line = strings.TrimSpace(line)
		if line == "" {
			line = lastCmd // Enter repeats the previous command
		}
		lastCmd = strings.Fields(line)[0]
		args := strings.Fields(line)[1:]

		switch strings.Fields(line)[0] {
		case "s", "si", "step":
			if z.Step() {
				d.showStep(prev)
				prev = snapshot(z)
			} else {
				fmt.Println("stopped: " + z.stopReason())
			}
		case "n", "next":
			d.stepOver(&prev)
		case "c", "cont", "continue":
			d.continueAll(&prev)
		case "b":
			d.setBreakpoint(args)
		case "r", "regs":
			d.dumpRegs()
		case "d", "disasm":
			d.disasm(args)
		case "x", "mem":
			d.hexdump(args)
		case "q", "quit":
			return
		case "h", "?", "help":
			fmt.Println("s=step  n=next(call)  c=continue  b ADDR  r=regs  d [ADDR] [N]  x ADDR  q=quit")
		default:
			fmt.Printf("unknown command %q (h for help)\n", strings.Fields(line)[0])
		}
	}
}

// stepOver runs until the instruction after a CALL/RST, or a single step.
func (d *Debugger) stepOver(prev *regState) {
	z := d.z
	callStart := z.pc
	ret, isCall := d.callReturnAddr(callStart)
	if !isCall {
		if z.Step() {
			d.showStep(*prev)
			*prev = snapshot(z)
		} else {
			fmt.Println("stopped: " + z.stopReason())
		}
		return
	}
	stopped := false
	for z.pc != ret {
		if !z.Step() {
			stopped = true
			break
		}
		if z.halted || z.pc == 0x0000 {
			stopped = true
			break
		}
	}
	if stopped {
		fmt.Println("stopped: " + z.stopReason())
	} else {
		fmt.Printf("stepped over call at %04X; now before:\n", callStart)
	}
	d.window(z.pc, 3)
	*prev = snapshot(z)
}

// callReturnAddr reports the return address when a CALL/RST (optionally
// DD/FD prefixed) starts at pc, for step-over.
func (d *Debugger) callReturnAddr(pc uint16) (uint16, bool) {
	prefix := uint16(0)
	for prefix <= 4 {
		op := d.z.rb(pc + prefix)
		if op != 0xDD && op != 0xFD {
			switch {
			case op == 0xCD: // CALL nn
				return pc + prefix + 3, true
			case op == 0xC4, op == 0xCC, op == 0xD4, op == 0xDC,
				op == 0xE4, op == 0xEC, op == 0xF4, op == 0xFC: // CALL cc,nn
				return pc + prefix + 3, true
			case op >= 0xC7 && op <= 0xFF && op&7 == 7: // RST
				return pc + prefix + 1, true
			}
			return 0, false
		}
		prefix++
	}
	return 0, false
}

func (d *Debugger) continueAll(prev *regState) {
	z := d.z
	steps := 0
	for {
		if z.halted || z.pc == 0x0000 {
			break
		}
		if d.bps[z.pc] {
			fmt.Printf("breakpoint at %s\n", z.disasmLine(z.pc, d.lst, true))
			d.window(z.pc, 3)
			*prev = snapshot(z)
			return
		}
		if !z.Step() {
			break
		}
		steps++
	}
	fmt.Printf("stopped after %d instructions: %s\n", steps, z.stopReason())
	d.window(z.pc, 3)
	*prev = snapshot(z)
}

func (d *Debugger) setBreakpoint(args []string) {
	if len(args) == 0 {
		if len(d.bps) == 0 {
			fmt.Println("no breakpoints")
			return
		}
		var addrs []string
		for a := range d.bps {
			addrs = append(addrs, fmt.Sprintf("%04X", a))
		}
		fmt.Println("breakpoints: " + strings.Join(addrs, " "))
		return
	}
	addr, err := parseAddr(args[0])
	if err != nil {
		fmt.Printf("bad address %q\n", args[0])
		return
	}
	if d.bps[addr] {
		delete(d.bps, addr)
		fmt.Printf("breakpoint removed at %s\n", zdis(d.z, addr, d.lst))
	} else {
		d.bps[addr] = true
		fmt.Printf("breakpoint set at %s\n", zdis(d.z, addr, d.lst))
	}
}

func zdis(z *Z80, addr uint16, lst *Listing) string {
	if ins := lst.At(addr); ins != nil {
		return fmt.Sprintf("%04X (%s)", addr, strings.TrimSpace(ins.Text))
	}
	return fmt.Sprintf("%04X", addr)
}

func (d *Debugger) dumpRegs() {
	z := d.z
	fmt.Printf("A=%02X F=%02X(%s)  B=%02X C=%02X  D=%02X E=%02X  H=%02X L=%02X\n",
		z.a, z.f, flagsString(z.f), z.b, z.c, z.d, z.e, z.h, z.l)
	fmt.Printf("BC=%04X DE=%04X HL=%04X  IX=%04X IY=%04X  SP=%04X PC=%04X\n",
		z.bc(), z.de(), z.hl(), z.ix(), z.iy(), z.sp, z.pc)
	fmt.Printf("AF'=%04X BC'=%04X DE'=%04X HL'=%04X  I=%02X R=%02X IM=%d IFF1=%v IFF2=%v\n",
		z.af_(), z.bc_(), z.de_(), z.hl_(), z.i, z.r, z.im, z.iff1, z.iff2)
}

func (d *Debugger) disasm(args []string) {
	addr := d.z.pc
	n := 10
	if len(args) > 0 {
		if a, err := parseAddr(args[0]); err == nil {
			addr = a
		}
	}
	if len(args) > 1 {
		if v, err := strconv.Atoi(args[1]); err == nil && v > 0 && v <= 100 {
			n = v
		}
	}
	for _, ins := range d.lst.Window(addr, n) {
		fmt.Println(formatInsn(ins, ins.Addr == d.z.pc))
	}
}

func (d *Debugger) hexdump(args []string) {
	if len(args) == 0 {
		fmt.Println("usage: x ADDR")
		return
	}
	addr, err := parseAddr(args[0])
	if err != nil {
		fmt.Printf("bad address %q\n", args[0])
		return
	}
	fmt.Printf("%04X:", addr)
	for i := 0; i < 16; i++ {
		fmt.Printf(" %02X", d.z.rb(addr+uint16(i)))
	}
	fmt.Println()
}

func parseAddr(s string) (uint16, error) {
	s = strings.TrimPrefix(strings.TrimPrefix(s, "0x"), "0X")
	v, err := strconv.ParseUint(s, 16, 16)
	if err != nil {
		return 0, err
	}
	return uint16(v), nil
}

// runTrace executes the whole program printing one block per instruction.
func runTrace(z *Z80, lst *Listing) {
	prev := snapshot(z)
	for z.Step() {
		if z.lastBDOS {
			fmt.Printf("#%-5d T+0    %s\n", z.instrCount, z.bdosLine())
		} else if z.lastINT {
			fmt.Printf("#%-5d T+%-3d Σ%-6d %s\n", z.instrCount, z.lastT, z.cycles, z.lastINTText)
		} else {
			fmt.Printf("#%-5d T+%-3d Σ%-6d %s\n", z.instrCount, z.lastT, z.cycles,
				z.disasmLine(z.lastPc, lst, false))
		}
		if diffs := regDiffs(prev, snapshot(z)); len(diffs) > 0 {
			fmt.Printf("         %s\n", strings.Join(diffs, "   "))
		}
		if fd := flagDiffs(prev.f, z.f); len(fd) > 0 {
			fmt.Printf("         flags %s\n", strings.Join(fd, "  "))
		}
		prev = snapshot(z)
	}
	fmt.Printf("── stopped: %s\n", z.stopReason())
	fmt.Printf("── %d instructions, %d T-states (BDOS host calls excluded; interrupt acceptances included)\n", z.instrCount, z.cycles)
}

// runCycles executes silently and prints a timing summary.
func runCycles(z *Z80) {
	for z.Step() {
	}
	fmt.Printf("instructions: %d\n", z.instrCount)
	fmt.Printf("T-states:     %d (BDOS host calls excluded; interrupt acceptances included)\n", z.cycles)
	fmt.Printf("@ 4 MHz:      %.3f ms\n", float64(z.cycles)/4000.0)
}

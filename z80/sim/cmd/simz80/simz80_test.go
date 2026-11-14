package main

import (
	"os"
	"strings"
	"testing"
)

func writeFile(path, content string) error {
	return os.WriteFile(path, []byte(content), 0o644)
}

// runProg loads prog at 0x0100 and executes exactly steps Step() calls,
// failing the test when the CPU stops early.
func runProg(t *testing.T, prog []byte, steps int) *Z80 {
	t.Helper()
	z := NewZ80()
	copy(z.mem[0x0100:], prog)
	z.pc = 0x0100
	for i := 0; i < steps; i++ {
		if !z.Step() {
			t.Fatalf("step %d/%d stopped early: %s", i+1, steps, z.stopReason())
		}
	}
	return z
}

// The reference example from the learning materials:
// LD A,7Fh / ADD A,01h must produce A=80h, F=94h (S=1, H=1, P/V=1).
func TestAddFlagsReferenceExample(t *testing.T) {
	z := NewZ80()
	prog := []byte{0x3E, 0x7F, 0xC6, 0x01, 0x76} // LD A,7Fh; ADD A,01h; HALT
	copy(z.mem[0x0100:], prog)
	z.pc = 0x0100

	if !z.Step() {
		t.Fatal("first step should execute")
	}
	if z.a != 0x7F {
		t.Fatalf("A = %02X, want 7F", z.a)
	}
	if !z.Step() {
		t.Fatal("second step should execute")
	}
	if z.a != 0x80 {
		t.Fatalf("A = %02X, want 80", z.a)
	}
	if z.f != 0x94 {
		t.Fatalf("F = %02X, want 94 (S+H+P/V)", z.f)
	}
	if z.f&PF == 0 {
		t.Fatal("P/V (overflow) must be set for 7Fh+01h")
	}
}

func TestStepStopsAtHaltAndExit(t *testing.T) {
	z := NewZ80()
	copy(z.mem[0x0100:], []byte{0x3E, 0x42, 0x76}) // LD A,42h; HALT
	z.pc = 0x0100
	if !z.Step() {
		t.Fatal("LD should step")
	}
	if !z.Step() {
		t.Fatal("HALT itself is a step")
	}
	if !z.halted {
		t.Fatal("halted should be set after HALT")
	}
	if z.Step() {
		t.Fatal("step after HALT should report stop")
	}

	// RET to the 0x0000 return address pushed by loadCom.
	z2 := NewZ80()
	if err := z2.loadCom("nonexistent"); err == nil {
		t.Fatal("expected error for missing file")
	}
	copy(z2.mem[0x0100:], []byte{0xC9}) // RET
	z2.pc = 0x0100
	z2.sp = 0xFFFF
	z2.push(0x0000)
	if !z2.Step() {
		t.Fatal("RET itself is a step")
	}
	if z2.pc != 0x0000 {
		t.Fatalf("PC = %04X, want 0000", z2.pc)
	}
	if z2.Step() {
		t.Fatal("step at PC=0 should report exit")
	}
}

func TestTstatesSpotValues(t *testing.T) {
	cases := []struct {
		name string
		got  int
		want int
	}{
		{"NOP", tstatesMain(0x00), 4},
		{"LD A,n", tstatesMain(0x3E), 7},
		{"ADD A,n", tstatesMain(0xC6), 7},
		{"LD (HL),n", tstatesMain(0x36), 10},
		{"LD HL,nn", tstatesMain(0x21), 10},
		{"ADD HL,rp", tstatesMain(0x09), 11},
		{"INC rp", tstatesMain(0x23), 6},
		{"INC (HL)", tstatesMain(0x34), 11},
		{"DJNZ base", tstatesMain(0x10), 5},
		{"JR d", tstatesMain(0x18), 12},
		{"JR cc base", tstatesMain(0x20), 7},
		{"RET cc base", tstatesMain(0xC0), 5},
		{"CALL nn", tstatesMain(0xCD), 17},
		{"CALL cc base", tstatesMain(0xC4), 10},
		{"PUSH", tstatesMain(0xC5), 11},
		{"POP", tstatesMain(0xC1), 10},
		{"RST", tstatesMain(0xC7), 11},
		{"HALT", tstatesMain(0x76), 4},
		{"JP (HL)", tstatesMain(0xE9), 4},
		{"EX (SP),HL", tstatesMain(0xE3), 19},
		{"CB r", tstatesCB(0x07), 8},
		{"CB (HL)", tstatesCB(0x06), 15},
		{"ED IN r,(C)", tstatesED(0x40), 12},
		{"ED SBC HL,rp", tstatesED(0x42), 15},
		{"ED LD (nn),rp", tstatesED(0x43), 20},
		{"ED NEG", tstatesED(0x44), 8},
		{"ED RETN", tstatesED(0x45), 14},
		{"ED LD A,I", tstatesED(0x57), 9},
		{"ED RLD", tstatesED(0x67), 18},
		{"ED LDI", tstatesED(0xA0), 16},
		{"ED LDIR", tstatesED(0xB0), 16},
		{"ED invalid", tstatesED(0x00), 8},
		{"IX LD IX,nn", tstatesIX(0x21), 14},
		{"IX ADD IX,rp", tstatesIX(0x09), 15},
		{"IX LD A,(IX+d)", tstatesIX(0x7E), 19},
		{"IX LD (IX+d),r", tstatesIX(0x70), 19},
		{"IX LD (IX+d),n", tstatesIX(0x36), 19},
		{"IX ALU (IX+d)", tstatesIX(0x86), 19},
		{"IX INC (IX+d)", tstatesIX(0x34), 23},
		{"IX INC IX", tstatesIX(0x23), 10},
		{"IX PUSH IX", tstatesIX(0xE5), 15},
		{"IX POP IX", tstatesIX(0xE1), 14},
		{"IX EX (SP),IX", tstatesIX(0xE3), 23},
		{"IX JP (IX)", tstatesIX(0xE9), 8},
		{"IX LD SP,IX", tstatesIX(0xF9), 10},
		{"IX plain LD B,C", tstatesIX(0x41), 8},
	}
	for _, c := range cases {
		if c.got != c.want {
			t.Errorf("%s: got %d, want %d", c.name, c.got, c.want)
		}
	}
}

// tstatesHere resolves prefixes from memory.
func TestTstatesHere(t *testing.T) {
	z := NewZ80()
	z.wb(0x0100, 0xDD)
	z.wb(0x0101, 0xCB)
	z.wb(0x0102, 0x05)
	z.wb(0x0103, 0x06)
	z.pc = 0x0100
	if got := z.tstatesHere(); got != 23 {
		t.Errorf("DD CB: got %d, want 23", got)
	}
}

// Taken branches must add their conditional T-states via Step().
func TestStepConditionalTstates(t *testing.T) {
	// JR NZ,-3 with Z clear: 7 + 5 = 12.
	z := NewZ80()
	copy(z.mem[0x0100:], []byte{0x20, 0xFD}) // JR NZ,-3
	z.pc = 0x0100
	z.f &^= ZF
	z.Step()
	if z.lastT != 12 {
		t.Fatalf("JR NZ taken: lastT = %d, want 12", z.lastT)
	}

	// JR NZ with Z set: not taken, 7.
	z2 := NewZ80()
	copy(z2.mem[0x0100:], []byte{0x20, 0xFD})
	z2.pc = 0x0100
	z2.f |= ZF
	z2.Step()
	if z2.lastT != 7 {
		t.Fatalf("JR NZ not taken: lastT = %d, want 7", z2.lastT)
	}

	// DJNZ with B=2, d=-1: taken, 5 + 3 = 8.
	z3 := NewZ80()
	copy(z3.mem[0x0100:], []byte{0x10, 0xFF})
	z3.pc = 0x0100
	z3.b = 2
	z3.Step()
	if z3.lastT != 8 {
		t.Fatalf("DJNZ taken: lastT = %d, want 8", z3.lastT)
	}

	// DD-prefixed JR NZ,-3 (executed via execMain fallback), taken:
	// 4 (prefix) + 7 + 5 = 16.
	z4 := NewZ80()
	copy(z4.mem[0x0100:], []byte{0xDD, 0x20, 0xFD})
	z4.pc = 0x0100
	z4.f &^= ZF
	z4.Step()
	if z4.lastT != 16 {
		t.Fatalf("DD JR NZ taken: lastT = %d, want 16", z4.lastT)
	}
}

// LDIR charges 21 T-states while repeating and 16 on completion.
func TestLDIRRepeatTiming(t *testing.T) {
	z := NewZ80()
	copy(z.mem[0x0100:], []byte{0xED, 0xB0}) // LDIR
	z.pc = 0x0100
	z.setHl(0x2000)
	z.setDe(0x3000)
	z.setBc(2)
	z.wb(0x2000, 0xAA)
	z.wb(0x2001, 0xBB)

	if !z.Step() {
		t.Fatal("first LDIR iteration")
	}
	if z.pc != 0x0100 {
		t.Fatalf("LDIR should repeat while BC != 0, pc = %04X", z.pc)
	}
	if z.lastT != 21 {
		t.Fatalf("LDIR repeat: lastT = %d, want 21", z.lastT)
	}
	if !z.Step() {
		t.Fatal("second LDIR iteration")
	}
	if z.lastT != 16 {
		t.Fatalf("LDIR final: lastT = %d, want 16", z.lastT)
	}
	if z.rb(0x3000) != 0xAA || z.rb(0x3001) != 0xBB {
		t.Fatal("LDIR did not copy bytes")
	}
}

func TestParseListingLine(t *testing.T) {
	cases := []struct {
		line    string
		addr    uint16
		bytes   []byte
		text    string
		wantNil bool
	}{
		{"# File s03_stack.asm", 0, nil, "", true},
		{"0100 \t\t\t_start: ", 0, nil, "", true},
		{"0100 21 bd 01\t\t    ld      hl, msg_title ", 0x0100, []byte{0x21, 0xBD, 0x01}, "ld hl, msg_title", false},
		{"0109 3e 42\t\t    ld      a, 0x42 ", 0x0109, []byte{0x3E, 0x42}, "ld a, 0x42", false},
		{"010b f5\t\t    push    af ", 0x010B, []byte{0xF5}, "push af", false},
		{"0127 \t\t    ; Pop AF (should be 0x42) ", 0, nil, "", true},
	}
	for _, c := range cases {
		ins := parseListingLine(c.line)
		if c.wantNil {
			if ins != nil {
				t.Errorf("%q: want nil, got %+v", c.line, ins)
			}
			continue
		}
		if ins == nil {
			t.Errorf("%q: want entry, got nil", c.line)
			continue
		}
		if ins.Addr != c.addr {
			t.Errorf("%q: addr %04X, want %04X", c.line, ins.Addr, c.addr)
		}
		if len(ins.Bytes) != len(c.bytes) {
			t.Errorf("%q: bytes %v, want %v", c.line, ins.Bytes, c.bytes)
			continue
		}
		for i := range c.bytes {
			if ins.Bytes[i] != c.bytes[i] {
				t.Errorf("%q: bytes %v, want %v", c.line, ins.Bytes, c.bytes)
				break
			}
		}
		if ins.Text != c.text {
			t.Errorf("%q: text %q, want %q", c.line, ins.Text, c.text)
		}
	}
}

func TestListingWindow(t *testing.T) {
	src := strings.Join([]string{
		"# File t.asm",
		"0100 21 bd 01\t\tld hl, msg",
		"0103 cd 6a 01\t\tcall print_str",
		"0106 c9\t\tret",
		"0107 3e 42\t\tld a, 0x42",
	}, "\n")
	tmp := t.TempDir() + "/t.lst"
	if err := writeFile(tmp, src); err != nil {
		t.Fatal(err)
	}
	lst, err := loadListing(tmp)
	if err != nil || lst == nil {
		t.Fatalf("loadListing: %v", err)
	}
	if got := len(lst.insns); got != 4 {
		t.Fatalf("insns = %d, want 4", got)
	}
	w := lst.Window(0x0104, 3) // window containing addr 0104 (inside the call)
	if len(w) != 3 || w[0].Addr != 0x0103 || w[1].Addr != 0x0106 || w[2].Addr != 0x0107 {
		t.Fatalf("Window(0104) = %+v", w)
	}
	if lst.At(0x0106) == nil || lst.At(0x0106).Text != "ret" {
		t.Fatal("At(0106) should be the ret")
	}
}

// INC IX (DD 23) must increment IX itself, not fall back to INC HL.
// Official timing: DD 23 = 10 T-states (4 prefix + 6 INC rp).
func TestINCDECIndexRegisters(t *testing.T) {
	// LD IX,0x1234; INC IX; DEC IX
	z := runProg(t, []byte{0xDD, 0x21, 0x34, 0x12, 0xDD, 0x23, 0xDD, 0x2B}, 3)
	// After step 2 INC IX ran; step 3 DEC IX returned IX to 0x1234.
	if z.ix() != 0x1234 {
		t.Fatalf("IX = %04X after INC+DEC, want 1234", z.ix())
	}
	if z.lastT != 10 {
		t.Fatalf("DEC IX T-states = %d, want 10", z.lastT)
	}

	// INC IX alone: IX 0x1234 -> 0x1235 with 10 T-states.
	z2 := runProg(t, []byte{0xDD, 0x21, 0x34, 0x12, 0xDD, 0x23}, 2)
	if z2.ix() != 0x1235 {
		t.Fatalf("IX = %04X after INC IX, want 1235", z2.ix())
	}
	if z2.lastT != 10 {
		t.Fatalf("INC IX T-states = %d, want 10", z2.lastT)
	}

	// LD IY,0x1234; INC IY (FD 23); DEC IY (FD 2B)
	z3 := runProg(t, []byte{0xFD, 0x21, 0x34, 0x12, 0xFD, 0x23}, 2)
	if z3.iy() != 0x1235 {
		t.Fatalf("IY = %04X after INC IY, want 1235", z3.iy())
	}
	if z3.lastT != 10 {
		t.Fatalf("INC IY T-states = %d, want 10", z3.lastT)
	}
	z4 := runProg(t, []byte{0xFD, 0x21, 0x34, 0x12, 0xFD, 0x2B}, 2)
	if z4.iy() != 0x1233 {
		t.Fatalf("IY = %04X after DEC IY, want 1233", z4.iy())
	}
}

// INC (IX+d) (DD 34) / DEC (IY+d) (FD 35) operate on memory with 23 T-states.
func TestINCDECIndexIndirect(t *testing.T) {
	z := runProg(t, []byte{0xDD, 0x21, 0x00, 0x20, 0xDD, 0x34, 0x02}, 2)
	if z.rb(0x2002) != 1 {
		t.Fatalf("(IX+2) = %02X, want 01", z.rb(0x2002))
	}
	if z.lastT != 23 {
		t.Fatalf("INC (IX+d) T-states = %d, want 23", z.lastT)
	}

	z2 := runProg(t, []byte{0xFD, 0x21, 0x00, 0x20, 0xFD, 0x35, 0x02}, 2)
	// mem[0x2002] is 0 -> DEC wraps to FF.
	if z2.rb(0x2002) != 0xFF {
		t.Fatalf("(IY+2) = %02X, want FF", z2.rb(0x2002))
	}
	if z2.lastT != 23 {
		t.Fatalf("DEC (IY+d) T-states = %d, want 23", z2.lastT)
	}
}

// DD-prefixed x==2 opcodes other than (IX+d) forms are ALU A,r:
// DD 83 must be ADD A,E (it used to be mis-decoded as INC BC).
func TestDDPrefixALUFallback(t *testing.T) {
	// LD A,1; LD E,2; ADD A,E (DD 83)
	z := runProg(t, []byte{0x3E, 0x01, 0x1E, 0x02, 0xDD, 0x83}, 3)
	if z.a != 3 {
		t.Fatalf("A = %02X after DD 83 (ADD A,E with A=1,E=2), want 03", z.a)
	}
	if z.bc() != 0 {
		t.Fatalf("BC = %04X, want 0000 (DD 83 must not increment BC)", z.bc())
	}
}

// ---- Interrupt injection (port 0x10 INT line model) ----

// OUT to port 0x10 asserts INT and latches the value as the vector byte.
func TestPortOutInterruptRequest(t *testing.T) {
	z := NewZ80()
	z.portOut(0x0010, 0x80) // OUT (0x10),A with A=0x80
	if !z.intPending {
		t.Fatal("INT line must be pending after OUT (0x10)")
	}
	if z.intVector != 0x80 {
		t.Fatalf("vector byte = %02X, want 80", z.intVector)
	}
	// A second OUT updates the latched vector byte.
	z.portOut(0x0010, 0x42)
	if z.intVector != 0x42 {
		t.Fatalf("vector byte = %02X, want 42", z.intVector)
	}
	// Other ports do not touch the INT line.
	z2 := NewZ80()
	z2.portOut(0x0000, 0x55)
	z2.portOut(0x0011, 0x55)
	if z2.intPending {
		t.Fatal("OUT to a port other than 0x10 must not assert INT")
	}
}

// IM 1: pending INT with IFF1 set is accepted as RST 38h at the next
// instruction boundary (13 T-states), IFF1/IFF2 cleared, PC pushed.
func TestInterruptAcceptIM1(t *testing.T) {
	// IM 1; EI; OUT (0x10),A; NOP (never reached before acceptance)
	prog := []byte{0xED, 0x56, 0xFB, 0xD3, 0x10, 0x00, 0x00}
	z := runProg(t, prog, 3) // IM 1, EI, OUT
	if !z.intPending {
		t.Fatal("INT must be pending after OUT (0x10)")
	}
	if !z.iff1 {
		t.Fatal("IFF1 must be set after EI")
	}

	// Step 4: interrupt acceptance instead of the NOP.
	if !z.Step() {
		t.Fatal("acceptance step")
	}
	if z.pc != 0x0038 {
		t.Fatalf("PC = %04X after acceptance, want 0038", z.pc)
	}
	if z.lastT != 13 {
		t.Fatalf("IM 1 response T-states = %d, want 13", z.lastT)
	}
	if z.intPending {
		t.Fatal("INT line must be cleared after acceptance")
	}
	if z.iff1 || z.iff2 {
		t.Fatal("IFF1/IFF2 must be cleared by acceptance")
	}
	if ret := z.rw(z.sp); ret != 0x0105 {
		t.Fatalf("stack return address = %04X, want 0105", ret)
	}

	// RETN at the handler restores IFF1 from IFF2 (both 0 here) and pops PC.
	z.wb(0x0038, 0xED)
	z.wb(0x0039, 0x45)
	if !z.Step() {
		t.Fatal("RETN step")
	}
	if z.pc != 0x0105 {
		t.Fatalf("PC = %04X after RETN, want 0105", z.pc)
	}
	if z.iff1 {
		t.Fatal("RETN restores IFF1 from IFF2 (clear after acceptance)")
	}
}

// IM 2: vector = (I << 8) | vector byte, handler address read from the
// vector table (19 T-states).
func TestInterruptAcceptIM2(t *testing.T) {
	// LD A,0x80; IM 2; LD I,A; EI; OUT (0x10),A; NOP
	prog := []byte{0x3E, 0x80, 0xED, 0x5E, 0xED, 0x47, 0xFB, 0xD3, 0x10, 0x00}
	z := NewZ80()
	copy(z.mem[0x0100:], prog)
	z.pc = 0x0100
	// Vector table: 0x8080 -> handler 0x1234.
	z.wb(0x8080, 0x34)
	z.wb(0x8081, 0x12)
	for i := 0; i < 5; i++ {
		if !z.Step() {
			t.Fatalf("step %d stopped early", i+1)
		}
	}
	if !z.intPending || !z.iff1 {
		t.Fatal("INT must be pending with IFF1 set before acceptance")
	}
	if !z.Step() {
		t.Fatal("acceptance step")
	}
	if z.pc != 0x1234 {
		t.Fatalf("PC = %04X after IM 2 acceptance, want 1234", z.pc)
	}
	if z.lastT != 19 {
		t.Fatalf("IM 2 response T-states = %d, want 19", z.lastT)
	}
	if ret := z.rw(z.sp); ret != 0x0109 {
		t.Fatalf("stack return address = %04X, want 0109", ret)
	}
}

// IM 0: the device supplies RST 10h (13 T-states).
func TestInterruptAcceptIM0(t *testing.T) {
	prog := []byte{0xED, 0x46, 0xFB, 0xD3, 0x10, 0x00} // IM 0; EI; OUT; NOP
	z := runProg(t, prog, 3)
	if !z.Step() {
		t.Fatal("acceptance step")
	}
	if z.pc != 0x0010 {
		t.Fatalf("PC = %04X after IM 0 acceptance, want 0010", z.pc)
	}
	if z.lastT != 13 {
		t.Fatalf("IM 0 response T-states = %d, want 13", z.lastT)
	}
}

// A pending INT is not accepted while IFF1 is clear (DI); the pending
// request survives until interrupts are enabled.
func TestInterruptNotAcceptedWhenDisabled(t *testing.T) {
	prog := []byte{0xED, 0x56, 0xF3, 0xD3, 0x10, 0x00, 0x00} // IM 1; DI; OUT; NOP; NOP
	z := runProg(t, prog, 3)
	if !z.intPending {
		t.Fatal("INT must be pending")
	}
	if !z.Step() {
		t.Fatal("NOP step with interrupts disabled")
	}
	if z.pc != 0x0106 {
		t.Fatalf("PC = %04X, want 0106 (NOP must execute, no acceptance)", z.pc)
	}
	if !z.intPending {
		t.Fatal("INT request must stay pending while IFF1 is clear")
	}
}

func TestADDIndexRegisters(t *testing.T) {
	// DD 39: ADD IX,SP = 15T. Before the fix, ADD IX,rp was mis-executed
	// as LD IX,nn (the LD rp,nn handler did not check q == 0).
	// LD IX,0x1000 / LD SP,0x0234 / ADD IX,SP -> IX=0x1234, carry per half
	// 0x1000+0x0234: no carry, half-carry none
	prog := []byte{0xDD, 0x21, 0x00, 0x10, 0x31, 0x34, 0x02, 0xDD, 0x39}
	z := runProg(t, prog, 3) // LD IX,nn / LD SP,nn / ADD IX,SP
	if z.ix() != 0x1234 {
		t.Fatalf("ADD IX,SP: IX=%04X, want 1234", z.ix())
	}
	if z.lastT != 15 {
		t.Fatalf("ADD IX,SP: lastT=%d, want 15", z.lastT)
	}
	if z.f&CF != 0 {
		t.Fatalf("ADD IX,SP: unexpected carry")
	}

	// FD 29: ADD IY,IY -> 0x1000*2 = 0x2000
	prog2 := []byte{0xFD, 0x21, 0x00, 0x10, 0xFD, 0x29}
	z2 := runProg(t, prog2, 2) // LD IY,nn / ADD IY,IY
	if z2.iy() != 0x2000 {
		t.Fatalf("ADD IY,IY: IY=%04X, want 2000", z2.iy())
	}
}

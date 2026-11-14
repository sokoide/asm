package main

import (
	"os"
	"strings"
	"testing"
)

func writeFile(path, content string) error {
	return os.WriteFile(path, []byte(content), 0o644)
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

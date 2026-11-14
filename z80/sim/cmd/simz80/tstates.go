// T-state timing tables for the Z80, based on the official Z80 manual.
// Conditional instructions return the "condition not met" timing here;
// Step() adds the taken-branch delta via conditionalT.

package main

// tstatesMain returns base T-states for an unprefixed opcode.
func tstatesMain(op byte) int {
	x := op >> 6
	y := (op >> 3) & 7
	z := op & 7
	p := y >> 1
	q := y & 1

	switch x {
	case 0:
		switch z {
		case 0:
			switch {
			case y == 2:
				return 8 // DJNZ (not taken; UM0080: 8T)
			case y == 3:
				return 12 // JR d (always taken)
			case y >= 4:
				return 7 // JR cc,d (not taken)
			default:
				return 4 // NOP, EX AF,AF'
			}
		case 1:
			if q == 0 {
				return 10 // LD rp,nn
			}
			return 11 // ADD HL,rp
		case 2:
			switch {
			case y < 4:
				return 7 // LD (BC),A / LD A,(BC) / LD (DE),A / LD A,(DE)
			case y < 6:
				return 16 // LD (nn),HL / LD HL,(nn)
			default:
				return 13 // LD (nn),A / LD A,(nn)
			}
		case 3:
			return 6 // INC rp / DEC rp
		case 4, 5:
			if y == 6 {
				return 11 // INC (HL) / DEC (HL)
			}
			return 4 // INC r / DEC r
		case 6:
			if y == 6 {
				return 10 // LD (HL),n
			}
			return 7 // LD r,n
		default:
			return 4 // RLCA..CCF, DAA, CPL, SCF, CCF
		}
	case 1:
		if op == 0x76 {
			return 4 // HALT
		}
		if y == 6 || z == 6 {
			return 7 // LD r,(HL) / LD (HL),r (UM0080: 7T)
		}
		return 4 // LD r,r'
	case 2:
		if z == 6 {
			return 7 // ALU A,(HL) (オペランド選択は z。UM0080: 7T)
		}
		return 4 // ALU A,r
	default: // x == 3
		switch z {
		case 0:
			return 5 // RET cc (not taken)
		case 1:
			if q == 0 {
				return 10 // POP rp2
			}
			switch p {
			case 0:
				return 10 // RET
			case 1:
				return 4 // EXX
			case 2:
				return 4 // JP (HL)
			default:
				return 6 // LD SP,HL
			}
		case 2:
			return 10 // JP cc,nn (same either way)
		case 3:
			switch y {
			case 0:
				return 10 // JP nn
			case 2:
				return 11 // OUT (n),A
			case 3:
				return 11 // IN A,(n)
			case 4:
				return 19 // EX (SP),HL
			case 5:
				return 4 // EX DE,HL
			default:
				return 4 // DI, EI (y=1 is the CB prefix, unreachable)
			}
		case 4:
			return 10 // CALL cc,nn (not taken)
		case 5:
			if q == 0 {
				return 11 // PUSH rp2
			}
			if p == 0 {
				return 17 // CALL nn
			}
			return 4 // prefixes (unreachable)
		case 6:
			return 7 // ALU A,n
		default:
			return 11 // RST
		}
	}
}

// tstatesCB returns T-states for a CB-prefixed opcode.
func tstatesCB(op byte) int {
	if op&7 == 6 {
		// BIT b,(HL) (x == 1) は 12T、rotate/SET/RES 系 (HL) は 15T。
		// (UM0080: BIT は S/Z/P/V 更新のみで 12T)
		if (op >> 6) == 1 {
			return 12
		}
		return 15
	}
	return 8
}

// tstatesED returns base T-states for an ED-prefixed opcode.
// Block repeats (LDIR etc.) return the completion timing; Step() adds
// the +5 repeat delta via conditionalT.
func tstatesED(op byte) int {
	x := op >> 6
	y := (op >> 3) & 7
	z := op & 7

	switch x {
	case 1:
		switch z {
		case 0, 1:
			return 12 // IN r,(C) / OUT (C),r
		case 2:
			return 15 // SBC HL,rp / ADC HL,rp
		case 3:
			return 20 // LD (nn),rp / LD rp,(nn)
		case 4:
			return 8 // NEG
		case 5:
			return 14 // RETN / RETI
		case 6:
			return 8 // IM n
		default:
			if y < 4 {
				return 9 // LD I,A / LD R,A / LD A,I / LD A,R
			}
			if y < 6 {
				return 18 // RRD / RLD
			}
			return 8 // invalid
		}
	case 2:
		return 16 // LDI/LDIR/CPI/CPIR/INI/... (completion timing)
	}
	return 8 // invalid ED op behaves as NOPs
}

// tstatesIX returns T-states for the opcode following a DD/FD prefix.
// DD CB / FD CB is handled by the caller (fixed 23).
func tstatesIX(op byte) int {
	if op == 0x76 {
		return 4 // DD 76: treated as HALT by this simulator
	}

	x := op >> 6
	y := (op >> 3) & 7
	z := op & 7
	p := y >> 1
	q := y & 1

	switch x {
	case 0:
		switch {
		case op == 0x36:
			return 19 // LD (IX+d),n
		case z == 1 && q == 0 && p == 2:
			return 14 // LD IX,nn
		case z == 1 && q == 1:
			return 15 // ADD IX,rp
		case (z == 4 || z == 5) && y == 6:
			return 23 // INC (IX+d) / DEC (IX+d)
		}
	case 1:
		if z == 6 || y == 6 {
			return 19 // LD r,(IX+d) / LD (IX+d),r
		}
	case 2:
		if z == 6 {
			return 19 // ALU A,(IX+d)
		}
	default: // x == 3
		switch {
		case z == 1 && q == 0 && p == 2:
			return 14 // POP IX
		case z == 5 && q == 0 && p == 2:
			return 15 // PUSH IX
		case z == 3 && y == 4:
			return 23 // EX (SP),IX
		case z == 1 && q == 1 && p == 2:
			return 8 // JP (IX)
		case z == 3 && q == 1 && p == 2:
			return 10 // LD SP,IX
		}
	}
	return tstatesMain(op) + 4 // prefix overhead on an otherwise unchanged op
}

// tstatesHere returns the base T-state count for the instruction
// currently at PC, resolving prefixes. Does not modify CPU state.
func (z *Z80) tstatesHere() int {
	pc := z.pc
	extra := 0
	for {
		b := z.rb(pc)
		if b == 0xDD || b == 0xFD {
			next := z.rb(pc + 1)
			if next == 0xDD || next == 0xFD {
				// stacked prefixes: charge 4 per redundant prefix
				extra += 4
				pc++
				continue
			}
			if next == 0xCB {
				return 23 + extra // DD CB d op / FD CB d op
			}
			return tstatesIX(next) + extra
		}
		switch b {
		case 0xCB:
			return tstatesCB(z.rb(pc+1)) + extra
		case 0xED:
			return tstatesED(z.rb(pc+1)) + extra
		}
		return tstatesMain(b) + extra
	}
}

// conditionalDelta returns the extra T-states for a taken branch or a
// repeating block instruction starting at start, inferred from where PC
// ended up. DD/FD prefixes (executed via the execMain fallback) are
// skipped so prefixed conditionals are also timed. Reads the instruction
// bytes from memory after execution (self-modifying code is not expected).
//
// Known limitation: when a taken branch target happens to equal the
// fall-through address, the delta is not added.
func (z *Z80) conditionalDelta(start, end uint16) int {
	pc := start
	prefix := 0
	for pc-start <= 4 {
		op := z.rb(pc)
		if op != 0xDD && op != 0xFD {
			break
		}
		prefix++
		pc++
	}
	op := z.rb(pc)
	switch op {
	case 0x10: // DJNZ
		if end != start+uint16(prefix+2) {
			return 5 // 8 + 5 = 13 when taken (UM0080: 13T)
		}
	case 0x20, 0x28, 0x30, 0x38: // JR cc,d
		if end != start+uint16(prefix+2) {
			return 5 // 7 + 5 = 12 when taken
		}
	case 0xC0, 0xC8, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8: // RET cc
		if end != start+uint16(prefix+1) {
			return 6 // 5 + 6 = 11 when taken
		}
	case 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC: // CALL cc,nn
		if end != start+uint16(prefix+3) {
			return 7 // 10 + 7 = 17 when taken
		}
	case 0xED:
		switch z.rb(pc + 1) {
		case 0xB0, 0xB1, 0xB2, 0xB3, // LDIR, CPIR, INIR, OTIR
			0xB8, 0xB9, 0xBA, 0xBB: // LDDR, CPDR, INDR, OTDR
			if end != start+uint16(prefix+2) {
				return 5 // 16 + 5 = 21 while repeating
			}
		}
	}
	return 0
}

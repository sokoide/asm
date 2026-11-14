package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"
)

// Z80 CPU simulator
type Z80 struct {
	mem [65536]byte
	// 8-bit registers
	a, f, b, c, d, e, h, l byte
	// Shadow registers
	a_, f_, b_, c_, d_, e_, h_, l_ byte
	// Index registers
	ixh, ixl, iyh, iyl byte
	// Stack pointer, program counter
	sp, pc uint16
	// Interrupt
	i, r       byte
	iff1, iff2 bool
	im         byte
	halted     bool
	// INT line model (educational): OUT to port 0x10 latches the
	// written value as the IM 2 vector byte and asserts INT until it
	// is accepted at an instruction boundary.
	intPending bool
	eiDelay    bool // EI 直後の 1 命令は割り込みを禁止 (Z80 割り込み Window)
	intVector  byte
	// lastINT/lastINTText describe an interrupt acceptance performed
	// by the most recent Step() (for trace/debug display, like lastBDOS).
	lastINT     bool
	lastINTText string
	// I/O
	inputBuf []byte
	inputPos int
	// Shared stdin reader (a single bufio.Reader must be reused across
	// BDOS calls, otherwise buffered bytes are lost between calls).
	stdioIn *bufio.Reader
	// lineReader supplies a program input line when inputBuf is exhausted
	// (set by the step debugger to show an [INPUT]> prompt).
	lineReader func() string
	// Cumulative T-states (used as the runaway limit) and per-step info.
	cycles     int
	maxCycles  int
	lastPc     uint16
	lastT      int
	lastBDOS   bool
	instrCount int
	// 計測用カウンタ。instrCount はデバッガの通番 (BDOS トラップと割り込み
	// 受付も 1 イベントとして数える)。icount 計測には cpuInsns を使う。
	cpuInsns   int
	bdosCalls  int
	intAccepts int
}

// Flag bits
const (
	SF = 0x80 // Sign
	ZF = 0x40 // Zero
	YF = 0x20 // undocumented
	HF = 0x10 // Half-carry
	XF = 0x08 // undocumented
	PF = 0x04 // Parity/Overflow
	NF = 0x02 // Subtract
	CF = 0x01 // Carry
)

func NewZ80() *Z80 {
	return &Z80{
		sp: 0xFFFF,
		// Runaway guard in T-states (was 10M instructions before the
		// debugger rework; 100M T-states ~= 10M average instructions).
		maxCycles: 100_000_000,
		stdioIn:   bufio.NewReader(os.Stdin),
	}
}

// Register pair getters/setters
func (z *Z80) af() uint16 { return uint16(z.a)<<8 | uint16(z.f) }
func (z *Z80) setAf(v uint16) {
	z.a = byte(v >> 8)
	z.f = byte(v)
}

func (z *Z80) bc() uint16 { return uint16(z.b)<<8 | uint16(z.c) }
func (z *Z80) setBc(v uint16) {
	z.b = byte(v >> 8)
	z.c = byte(v)
}

func (z *Z80) de() uint16 { return uint16(z.d)<<8 | uint16(z.e) }
func (z *Z80) setDe(v uint16) {
	z.d = byte(v >> 8)
	z.e = byte(v)
}

func (z *Z80) hl() uint16 { return uint16(z.h)<<8 | uint16(z.l) }
func (z *Z80) setHl(v uint16) {
	z.h = byte(v >> 8)
	z.l = byte(v)
}

func (z *Z80) ix() uint16 { return uint16(z.ixh)<<8 | uint16(z.ixl) }
func (z *Z80) setIx(v uint16) {
	z.ixh = byte(v >> 8)
	z.ixl = byte(v)
}

func (z *Z80) iy() uint16 { return uint16(z.iyh)<<8 | uint16(z.iyl) }
func (z *Z80) setIy(v uint16) {
	z.iyh = byte(v >> 8)
	z.iyl = byte(v)
}

// Shadow register pairs
func (z *Z80) bc_() uint16 { return uint16(z.b_)<<8 | uint16(z.c_) }
func (z *Z80) setBc_(v uint16) {
	z.b_ = byte(v >> 8)
	z.c_ = byte(v)
}

func (z *Z80) de_() uint16 { return uint16(z.d_)<<8 | uint16(z.e_) }
func (z *Z80) setDe_(v uint16) {
	z.d_ = byte(v >> 8)
	z.e_ = byte(v)
}

func (z *Z80) hl_() uint16 { return uint16(z.h_)<<8 | uint16(z.l_) }
func (z *Z80) setHl_(v uint16) {
	z.h_ = byte(v >> 8)
	z.l_ = byte(v)
}

func (z *Z80) af_() uint16 { return uint16(z.a_)<<8 | uint16(z.f_) }
func (z *Z80) setAf_(v uint16) {
	z.a_ = byte(v >> 8)
	z.f_ = byte(v)
}

// Memory access
func (z *Z80) rb(addr uint16) byte {
	return z.mem[addr]
}

func (z *Z80) wb(addr uint16, v byte) {
	z.mem[addr] = v
}

func (z *Z80) rw(addr uint16) uint16 {
	return uint16(z.rb(addr)) | uint16(z.rb(addr+1))<<8
}

func (z *Z80) ww(addr uint16, v uint16) {
	z.wb(addr, byte(v))
	z.wb(addr+1, byte(v>>8))
}

// Stack operations
func (z *Z80) push(v uint16) {
	z.sp -= 2
	z.ww(z.sp, v)
}

func (z *Z80) pop() uint16 {
	v := z.rw(z.sp)
	z.sp += 2
	return v
}

// Fetch operations
func (z *Z80) fetch() byte {
	v := z.rb(z.pc)
	z.pc++
	return v
}

func (z *Z80) fetchWord() uint16 {
	lo := z.fetch()
	hi := z.fetch()
	return uint16(hi)<<8 | uint16(lo)
}

func (z *Z80) fetchSigned() int8 {
	v := int8(z.fetch())
	return v
}

// Flag helpers
func (z *Z80) szpFlags(v byte) byte {
	f := byte(0)
	if v&0x80 != 0 {
		f |= SF
	}
	if v == 0 {
		f |= ZF
	}
	// Parity
	p := v
	p ^= p >> 4
	p ^= p >> 2
	p ^= p >> 1
	if p&1 == 0 {
		f |= PF
	}
	return f
}

func (z *Z80) setFlagsAdd(a, b byte, cy byte) {
	r := uint16(a) + uint16(b) + uint16(cy)
	f := z.szpFlags(byte(r))
	if r&0x100 != 0 {
		f |= CF
	}
	if (uint16(a)&0x0F + uint16(b)&0x0F + uint16(cy)) > 0x0F {
		f |= HF
	}
	// P/V is overflow (not parity) for ADD/ADC: operands with the same
	// sign producing a result of the opposite sign.
	if ^(uint16(a)^uint16(b))&(uint16(a)^r)&0x0080 != 0 {
		f |= PF
	} else {
		f &^= PF
	}
	z.f = f
}

func (z *Z80) setFlagsSub(a, b, cy byte) {
	r := int(a) - int(b) - int(cy)
	f := z.szpFlags(byte(r))
	f |= NF
	if r < 0 {
		f |= CF
	}
	if (int(a&0x0F) - int(b&0x0F) - int(cy)) < 0 {
		f |= HF
	}
	// P/V is signed overflow for SUB/SBC/CP (not parity). Clear the
	// parity bit szpFlags() left behind when there is no overflow.
	if (a^b)&(a^byte(r))&0x80 != 0 {
		f |= PF
	} else {
		f &^= PF
	}
	z.f = f
}

func (z *Z80) setFlagsLogic(v byte) {
	z.f = z.szpFlags(v)
}

func (z *Z80) setFlagsInc(v byte) {
	cf := z.f & CF
	f := z.szpFlags(v) &^ PF
	if v&0x0F == 0 {
		f |= HF
	}
	// P/V is signed overflow for INC: only 0x7F + 1 = 0x80 overflows.
	// (the caller passes the result, so old value == v - 1)
	if v == 0x80 {
		f |= PF
	}
	z.f = f | cf
}

func (z *Z80) setFlagsDec(v byte) {
	cf := z.f & CF
	f := z.szpFlags(v) &^ PF
	f |= NF
	if v&0x0F == 0x0F {
		f |= HF
	}
	// P/V is signed overflow for DEC: only 0x80 - 1 = 0x7F overflows.
	// (the caller passes the result, so old value == v + 1)
	if v == 0x7F {
		f |= PF
	}
	z.f = f | cf
}

// Condition check
func (z *Z80) checkCC(cc byte) bool {
	switch cc {
	case 0: // NZ
		return z.f&ZF == 0
	case 1: // Z
		return z.f&ZF != 0
	case 2: // NC
		return z.f&CF == 0
	case 3: // C
		return z.f&CF != 0
	case 4: // PO
		return z.f&PF == 0
	case 5: // PE
		return z.f&PF != 0
	case 6: // P
		return z.f&SF == 0
	case 7: // M
		return z.f&SF != 0
	}
	return false
}

// Register access by index
func (z *Z80) getReg(idx byte) byte {
	switch idx {
	case 0:
		return z.b
	case 1:
		return z.c
	case 2:
		return z.d
	case 3:
		return z.e
	case 4:
		return z.h
	case 5:
		return z.l
	case 6:
		return z.rb(z.hl())
	case 7:
		return z.a
	}
	return 0
}

func (z *Z80) setReg(idx, v byte) {
	v &= 0xFF
	switch idx {
	case 0:
		z.b = v
	case 1:
		z.c = v
	case 2:
		z.d = v
	case 3:
		z.e = v
	case 4:
		z.h = v
	case 5:
		z.l = v
	case 6:
		z.wb(z.hl(), v)
	case 7:
		z.a = v
	}
}

func (z *Z80) getRp(idx byte) uint16 {
	switch idx {
	case 0:
		return z.bc()
	case 1:
		return z.de()
	case 2:
		return z.hl()
	case 3:
		return z.sp
	}
	return 0
}

func (z *Z80) setRp(idx byte, v uint16) {
	v &= 0xFFFF
	switch idx {
	case 0:
		z.setBc(v)
	case 1:
		z.setDe(v)
	case 2:
		z.setHl(v)
	case 3:
		z.sp = v
	}
}

func (z *Z80) getRp2(idx byte) uint16 {
	switch idx {
	case 0:
		return z.bc()
	case 1:
		return z.de()
	case 2:
		return z.hl()
	case 3:
		return z.af()
	}
	return 0
}

func (z *Z80) setRp2(idx byte, v uint16) {
	v &= 0xFFFF
	switch idx {
	case 0:
		z.setBc(v)
	case 1:
		z.setDe(v)
	case 2:
		z.setHl(v)
	case 3:
		z.setAf(v)
	}
}

// I/O
func (z *Z80) portIn(port uint16) byte {
	return 0xFF // floating bus
}

func (z *Z80) portOut(port uint16, val byte) {
	// Educational INT device (see s102_interrupts): an OUT to port 0x10
	// (low byte of the port address) asserts the INT line and latches
	// the written value as the vector byte for IM 2. One OUT request
	// raises INT once; the CPU clears the line when it accepts the
	// interrupt. All other ports remain no-ops.
	if port&0xFF == 0x10 {
		z.intVector = val
		z.intPending = true
	}
}

// BDOS handler
func (z *Z80) bdosCall() {
	fn := z.c
	if fn == 1 || fn == 10 {
		// Input functions: in debug mode, exhausted program input
		// falls back to an [INPUT]> prompt.
		if z.inputPos >= len(z.inputBuf) && z.lineReader != nil {
			if line := z.lineReader(); line != "" {
				z.inputBuf = append(z.inputBuf[:z.inputPos], []byte(line)...)
			}
		}
	}
	switch fn {
	case 1: // Console input
		if z.inputPos < len(z.inputBuf) {
			ch := z.inputBuf[z.inputPos]
			z.inputPos++
			// Echo
			if ch == 0x0A || ch == 0x0D {
				fmt.Print("\r\n")
			} else {
				fmt.Printf("%c", ch)
			}
			z.a = ch & 0x7F
		} else {
			ch, err := z.stdioIn.ReadByte()
			if err != nil {
				z.a = 0x0D
			} else {
				z.a = ch & 0x7F
			}
		}
	case 2: // Console output
		fmt.Printf("%c", z.e&0x7F)
	case 9: // Print string ($-terminated)
		addr := z.de()
		for {
			ch := z.rb(addr)
			if ch == '$' || ch == 0 {
				break
			}
			fmt.Printf("%c", ch)
			addr++
		}
	case 10: // Read console buffer
		bufAddr := z.de()
		maxLen := z.rb(bufAddr)
		if maxLen == 0 {
			z.wb(bufAddr+1, 0)
			return
		}
		if z.inputPos < len(z.inputBuf) {
			remaining := z.inputBuf[z.inputPos:]
			// Find newline
			lineEnd := -1
			for i, b := range remaining {
				if b == '\n' {
					lineEnd = i
					break
				}
			}
			var line []byte
			if lineEnd >= 0 {
				line = remaining[:lineEnd]
				z.inputPos += lineEnd + 1
			} else {
				line = remaining
				z.inputPos = len(z.inputBuf)
			}
			if len(line) > int(maxLen) {
				line = line[:maxLen]
			}
			for i, b := range line {
				z.wb(bufAddr+uint16(i)+2, b)
			}
			z.wb(bufAddr+1, byte(len(line)))
			fmt.Print(string(line) + "\r\n")
		} else {
			line, err := z.stdioIn.ReadString('\n')
			if err != nil {
				z.wb(bufAddr+1, 0)
			} else {
				if len(line) > int(maxLen) {
					line = line[:maxLen]
				}
				z.wb(bufAddr+1, byte(len(line)-1)) // exclude newline
				for i, ch := range line {
					if i < int(maxLen) && ch != '\r' && ch != '\n' {
						z.wb(bufAddr+uint16(i)+2, byte(ch))
					}
				}
			}
		}
	case 12: // S_BDOSVER - Get CP/M version number
		// CP/M 2.2: B=0x00 (CP/M family), A=0x22 (version 2.2)
		// HL 全体にも同じ値を設定（多くのプログラムが HL を参照するため）
		z.b = 0x00
		z.a = 0x22
		z.setHl(0x0022)
	default:
		z.a = 0xFF // Unknown function
	}
}

// ALU operations
func (z *Z80) alu(op, val byte) {
	switch op {
	case 0: // ADD
		z.setFlagsAdd(z.a, val, 0)
		z.a += val
	case 1: // ADC
		cy := byte(0)
		if z.f&CF != 0 {
			cy = 1
		}
		z.setFlagsAdd(z.a, val, cy)
		z.a = z.a + val + cy
	case 2: // SUB
		z.setFlagsSub(z.a, val, 0)
		z.a -= val
	case 3: // SBC
		cy := byte(0)
		if z.f&CF != 0 {
			cy = 1
		}
		z.setFlagsSub(z.a, val, cy)
		z.a = z.a - val - cy
	case 4: // AND
		z.a &= val
		z.setFlagsLogic(z.a)
		z.f |= HF
	case 5: // XOR
		z.a ^= val
		z.setFlagsLogic(z.a)
	case 6: // OR
		z.a |= val
		z.setFlagsLogic(z.a)
	case 7: // CP
		z.setFlagsSub(z.a, val, 0)
	}
}

// CB prefix (rotates, shifts, BIT/SET/RES)
func (z *Z80) execCB() {
	op := z.fetch()
	x := (op >> 6) & 3
	y := (op >> 3) & 7
	z_ := op & 7

	if x == 0 { // Rotate/shift
		val := z.getReg(z_)
		var cy byte
		var newVal byte

		switch y {
		case 0: // RLC
			cy = (val >> 7) & 1
			newVal = (val << 1) | cy
		case 1: // RRC
			cy = val & 1
			newVal = (val >> 1) | (cy << 7)
		case 2: // RL
			oldCy := byte(0)
			if z.f&CF != 0 {
				oldCy = 1
			}
			newCy := (val >> 7) & 1
			newVal = (val << 1) | oldCy
			cy = newCy
		case 3: // RR
			oldCy := byte(0)
			if z.f&CF != 0 {
				oldCy = 1
			}
			newCy := val & 1
			newVal = (val >> 1) | (oldCy << 7)
			cy = newCy
		case 4: // SLA
			cy = (val >> 7) & 1
			newVal = val << 1
		case 5: // SRA
			cy = val & 1
			newVal = (val >> 1) | (val & 0x80)
		case 6: // SLL (undocumented)
			cy = (val >> 7) & 1
			newVal = (val << 1) | 1
		case 7: // SRL
			cy = val & 1
			newVal = val >> 1
		}

		f := z.szpFlags(newVal)
		if y <= 7 {
			if y == 0 || y == 2 || y == 4 || y == 6 {
				f |= cy
			} else if y == 1 || y == 3 || y == 5 || y == 7 {
				f |= cy
			}
		}
		z.f = f
		z.setReg(z_, newVal)

	} else if x == 1 { // BIT y, r[z]
		val := z.getReg(z_)
		result := val & (1 << y)
		f := z.f & CF
		f |= HF
		if result == 0 {
			f |= ZF
		}
		if y == 7 && (val&0x80 != 0) {
			f |= SF
		}
		z.f = f

	} else if x == 2 { // RES y, r[z]
		val := z.getReg(z_)
		val &= ^(1 << y)
		z.setReg(z_, val)

	} else if x == 3 { // SET y, r[z]
		val := z.getReg(z_)
		val |= (1 << y)
		z.setReg(z_, val)
	}
}

// ED prefix (block ops, extra instructions)
func (z *Z80) execED() {
	op := z.fetch()
	x := (op >> 6) & 3
	y := (op >> 3) & 7
	z_ := op & 7
	p := (y >> 1) & 3
	q := y & 1

	if x == 1 {
		if z_ == 0 { // IN r, (C) / IN (C)
			val := z.portIn(z.bc())
			if y != 6 {
				z.setReg(y, val)
			}
			z.f = z.szpFlags(val)
		} else if z_ == 1 { // OUT (C), r / OUT (C), 0
			val := byte(0)
			if y != 6 {
				val = z.getReg(y)
			}
			z.portOut(z.bc(), val)
		} else if z_ == 2 { // SBC HL,rp / ADC HL,rp
			rpVal := z.getRp(p)
			hl := z.hl()
			if q == 0 { // SBC
				cy := byte(0)
				if z.f&CF != 0 {
					cy = 1
				}
				result := int(hl) - int(rpVal) - int(cy)
				f := byte(0)
				if result&0x8000 != 0 {
					f |= SF
				}
				if result&0xFFFF == 0 {
					f |= ZF
				}
				f |= NF
				if result < 0 {
					f |= CF
				}
				if (int(hl&0xFFF) - int(rpVal&0xFFF) - int(cy)) < 0 {
					f |= HF
				}
				if (hl^rpVal)&(hl^uint16(result))&0x8000 != 0 {
					f |= PF
				}
				z.f = f
				z.setHl(uint16(result))
			} else { // ADC
				cy := byte(0)
				if z.f&CF != 0 {
					cy = 1
				}
				result := int(hl) + int(rpVal) + int(cy)
				f := byte(0)
				if result&0x8000 != 0 {
					f |= SF
				}
				if result&0xFFFF == 0 {
					f |= ZF
				}
				if result > 0xFFFF {
					f |= CF
				}
				if (int(hl&0xFFF) + int(rpVal&0xFFF) + int(cy)) > 0xFFF {
					f |= HF
				}
				if (hl^uint16(result))&(rpVal^uint16(result))&0x8000 != 0 {
					f |= PF
				}
				z.f = f
				z.setHl(uint16(result))
			}
		} else if z_ == 3 { // LD (nn),rp / LD rp,(nn)
			addr := z.fetchWord()
			if q == 0 {
				z.ww(addr, z.getRp(p))
			} else {
				z.setRp(p, z.rw(addr))
			}
		} else if z_ == 4 { // NEG
			z.setFlagsSub(0, z.a, 0)
			z.a = -z.a
		} else if z_ == 5 { // RETN / RETI
			z.iff1 = z.iff2
			z.pc = z.pop()
		} else if z_ == 6 { // IM mode
			modes := []byte{0, 0, 1, 2, 0, 0, 1, 2}
			z.im = modes[y]
		} else if z_ == 7 {
			if y == 0 { // LD I, A
				z.i = z.a
			} else if y == 1 { // LD R, A
				z.r = z.a
			} else if y == 2 { // LD A, I
				z.a = z.i
				f := z.szpFlags(z.a)
				f |= z.f & CF
				if z.iff2 {
					f |= PF
				}
				z.f = f
			} else if y == 3 { // LD A, R
				z.a = z.r
				f := z.szpFlags(z.a)
				f |= z.f & CF
				if z.iff2 {
					f |= PF
				}
				z.f = f
			} else if y == 4 { // RRD
				val := z.rb(z.hl())
				newVal := ((z.a & 0x0F) << 4) | ((val >> 4) & 0x0F)
				z.a = (z.a & 0xF0) | (val & 0x0F)
				z.wb(z.hl(), newVal)
				z.f = z.szpFlags(z.a) | (z.f & CF)
			} else if y == 5 { // RLD
				val := z.rb(z.hl())
				newVal := ((val << 4) & 0xF0) | (z.a & 0x0F)
				z.a = (z.a & 0xF0) | ((val >> 4) & 0x0F)
				z.wb(z.hl(), newVal)
				z.f = z.szpFlags(z.a) | (z.f & CF)
			}
		}

	} else if x == 2 {
		if z_ == 0 { // LDI, LDD, LDIR, LDDR
			val := z.rb(z.hl())
			z.wb(z.de(), val)
			if q == 0 { // LDI / LDIR
				z.setHl(z.hl() + 1)
				z.setDe(z.de() + 1)
			} else { // LDD / LDDR
				z.setHl(z.hl() - 1)
				z.setDe(z.de() - 1)
			}
			z.setBc(z.bc() - 1)
			f := z.f & (SF | ZF | CF)
			if z.bc() != 0 {
				f |= PF
			}
			z.f = f
			if q == 0 && p == 3 && z.bc() != 0 { // LDIR
				z.pc -= 2
			} else if q == 1 && p == 3 && z.bc() != 0 { // LDDR
				z.pc -= 2
			}
		} else if z_ == 1 { // CPI, CPD, CPIR, CPDR
			val := z.rb(z.hl())
			result := (int(z.a) - int(val)) & 0xFF
			if q == 0 {
				z.setHl(z.hl() + 1)
			} else {
				z.setHl(z.hl() - 1)
			}
			z.setBc(z.bc() - 1)
			f := z.szpFlags(byte(result))
			f |= NF
			if (z.a & 0x0F) < (val & 0x0F) {
				f |= HF
			}
			if z.bc() != 0 {
				f |= PF
			}
			z.f = f
			if q == 0 && p == 3 && z.bc() != 0 && result != 0 { // CPIR
				z.pc -= 2
			} else if q == 1 && p == 3 && z.bc() != 0 && result != 0 { // CPDR
				z.pc -= 2
			}
		} else if z_ == 2 { // INI, IND, INIR, INDR
			val := z.portIn(z.bc())
			z.wb(z.hl(), val)
			z.b = (z.b - 1) & 0xFF
			if q == 0 {
				z.setHl(z.hl() + 1)
			} else {
				z.setHl(z.hl() - 1)
			}
			if z.b == 0 {
				z.f |= ZF
			} else {
				z.f &^= ZF
			}
			z.f |= NF
		} else if z_ == 3 { // OUTI, OUTD, OTIR, OTDR
			val := z.rb(z.hl())
			z.portOut(z.bc(), val)
			z.b = (z.b - 1) & 0xFF
			if q == 0 {
				z.setHl(z.hl() + 1)
			} else {
				z.setHl(z.hl() - 1)
			}
			if z.b == 0 {
				z.f |= ZF
			} else {
				z.f &^= ZF
			}
			z.f |= NF
		}
	}
}

// Main execution
func (z *Z80) Run() {
	for z.Step() {
	}
}

// Step executes exactly one instruction (or one BDOS trap) and reports
// whether execution should continue. Timing and instruction bookkeeping
// are recorded in lastPc/lastT/lastBDOS/cycles/instrCount.
func (z *Z80) Step() bool {
	if z.halted || z.cycles >= z.maxCycles {
		return false
	}

	// BDOS trap at 0x0005 (host call, no T-states)
	if z.pc == 0x0005 {
		z.lastBDOS = true
		z.lastPc = 0x0005
		z.lastT = 0
		z.instrCount++
		z.bdosCall()
		z.pc = z.pop()
		return true
	}
	z.lastBDOS = false
	z.lastINT = false

	// Terminal trap at 0x0000
	if z.pc == 0x0000 {
		return false
	}

	// Interrupt acceptance: a pending INT is taken at the instruction
	// boundary when IFF1 is set (i.e. after EI). The BDOS host call and
	// the PC=0x0000 exit take priority over the interrupt.
	// EI の割り込み Window: EI 完了直後の 1 個の境界は受付をスキップする
	// (UM0080: EI は「次の命令の後」まで割り込みを認識しない)。
	// Window はこの境界で消費され、それ以降は通常の受付状態に戻る。
	if z.eiDelay {
		z.eiDelay = false
	} else if z.intPending && z.iff1 {
		z.acceptInterrupt()
		return true
	}

	start := z.pc
	z.lastPc = start
	base := z.tstatesHere()

	op := z.fetch()

	// CB prefix
	if op == 0xCB {
		z.execCB()
	} else if op == 0xDD {
		// DD prefix (IX)
		z.execIX()
	} else if op == 0xED {
		// ED prefix
		z.execED()
	} else if op == 0xFD {
		// FD prefix (IY)
		z.execIY()
	} else {
		z.execMain(op)
	}

	t := base + z.conditionalDelta(start, z.pc)
	z.lastT = t
	z.cycles += t
	z.instrCount++
	z.cpuInsns++
	return true
}

// acceptInterrupt emulates the Z80 interrupt acknowledge sequence for a
// pending INT. The interrupted PC is pushed and IFF1/IFF2 are cleared;
// the handler returns with RETN/RETI (both restore IFF1 from IFF2).
// Response T-states follow the official Z80 timing (Zilog UM0080):
// IM 0/1 = 13 T, IM 2 = 19 T.
func (z *Z80) acceptInterrupt() {
	z.lastINT = true
	z.lastPc = z.pc
	z.intAccepts++
	ret := z.pc
	z.push(ret)
	z.iff1 = false
	z.iff2 = false
	z.intPending = false

	switch z.im {
	case 0:
		// IM 0: the interrupting device supplies an opcode on the data
		// bus which the CPU executes. This educational device model
		// always supplies RST 10h.
		z.pc = 0x0010
		z.lastT = 13
		z.lastINTText = fmt.Sprintf("%04X  INT (IM 0): device supplies RST 10h -> PC=0010", ret)
	case 1:
		// IM 1: fixed RST 38h
		z.pc = 0x0038
		z.lastT = 13
		z.lastINTText = fmt.Sprintf("%04X  INT (IM 1): RST 38h -> PC=0038", ret)
	default:
		// IM 2: vector table at (I << 8) | vector byte; the handler
		// address is read from memory (device-supplied vector byte).
		vec := (uint16(z.i) << 8) | uint16(z.intVector)
		z.pc = z.rw(vec)
		z.lastT = 19
		z.lastINTText = fmt.Sprintf("%04X  INT (IM 2): vector %04X -> handler %04X", ret, vec, z.pc)
	}
	z.cycles += z.lastT
	z.instrCount++
}

func (z *Z80) execIX() {
	op := z.fetch()
	if op == 0xCB {
		// DD CB dd op - bit op on (IX+d)
		d := z.fetchSigned()
		addr := (z.ix() + uint16(d)) & 0xFFFF
		cbop := z.fetch()
		x := (cbop >> 6) & 3
		y := (cbop >> 3) & 7
		z_ := cbop & 7
		val := z.rb(addr)
		if x == 0 { // rotate/shift
			val = z.rotate(y, val)
			z.wb(addr, val)
			z.setReg(z_, val)
		} else if x == 1 { // BIT
			f := z.f & CF
			f |= HF
			if val&(1<<y) == 0 {
				f |= ZF
			}
			z.f = f
		} else if x == 2 { // RES
			val &= ^(1 << y)
			z.wb(addr, val)
			z.setReg(z_, val)
		} else if x == 3 { // SET
			val |= (1 << y)
			z.wb(addr, val)
			z.setReg(z_, val)
		}
		return
	}
	if op == 0xDD {
		// DD DD = prefix on prefix, treat as single DD
		z.execIX()
		return
	}

	z.execWithHL(op, true)
}

func (z *Z80) execIY() {
	op := z.fetch()
	if op == 0xCB {
		d := z.fetchSigned()
		addr := (z.iy() + uint16(d)) & 0xFFFF
		cbop := z.fetch()
		x := (cbop >> 6) & 3
		y := (cbop >> 3) & 7
		z_ := cbop & 7
		val := z.rb(addr)
		if x == 0 {
			val = z.rotate(y, val)
			z.wb(addr, val)
			z.setReg(z_, val)
		} else if x == 1 {
			f := z.f & CF
			f |= HF
			if val&(1<<y) == 0 {
				f |= ZF
			}
			z.f = f
		} else if x == 2 {
			val &= ^(1 << y)
			z.wb(addr, val)
			z.setReg(z_, val)
		} else if x == 3 {
			val |= (1 << y)
			z.wb(addr, val)
			z.setReg(z_, val)
		}
		return
	}
	if op == 0xFD {
		z.execIY()
		return
	}

	z.execWithHL(op, false)
}

func (z *Z80) getHLorIndex(useIX bool) uint16 {
	if useIX {
		return z.ix()
	}
	return z.iy()
}

func (z *Z80) setHLorIndex(useIX bool, v uint16) {
	if useIX {
		z.setIx(v)
	} else {
		z.setIy(v)
	}
}

func (z *Z80) execWithHL(op byte, useIX bool) {
	x := (op >> 6) & 3
	y := (op >> 3) & 7
	z_ := op & 7
	p := (y >> 1) & 3
	q := y & 1

	ixAddr := func() uint16 {
		d := z.fetchSigned()
		return (z.getHLorIndex(useIX) + uint16(d)) & 0xFFFF
	}

	if x == 0 {
		if z_ == 6 { // LD (IX/IY+d), n
			addr := ixAddr()
			val := z.fetch()
			z.wb(addr, val)
			return
		} else if y == 6 && z_ == 4 { // INC (IX/IY+d)
			addr := ixAddr()
			val := (z.rb(addr) + 1) & 0xFF
			z.setFlagsInc(val)
			z.wb(addr, val)
			return
		} else if y == 6 && z_ == 5 { // DEC (IX/IY+d)
			addr := ixAddr()
			val := (z.rb(addr) - 1) & 0xFF
			z.setFlagsDec(val)
			z.wb(addr, val)
			return
		} else if z_ == 3 { // INC/DEC rp (p==2: IX/IY)
			// DD/FD 23/2B/33/3B: INC/DEC IX/IY (or SP). Before the fix,
			// the p==2 case fell through to the unprefixed INC/DEC HL.
			if q == 0 {
				if p == 2 {
					z.setHLorIndex(useIX, z.getHLorIndex(useIX)+1)
				} else {
					z.setRp(p, z.getRp(p)+1)
				}
			} else {
				if p == 2 {
					z.setHLorIndex(useIX, z.getHLorIndex(useIX)-1)
				} else {
					z.setRp(p, z.getRp(p)-1)
				}
			}
			return
		}
		if z_ == 1 && q == 1 { // ADD IX/IY, rp[p]
			// DD/FD 09/19/29/39: ADD IX,BC/DE/IX/SP (same for IY).
			// Before the fix this fell through to the LD rp,nn handler
			// below and ADD IX,rp was mis-executed as LD IX,nn.
			var addend uint16
			if p == 2 {
				addend = z.getHLorIndex(useIX) // ADD IX,IX / ADD IY,IY
			} else {
				addend = z.getRp(p)
			}
			hl := z.getHLorIndex(useIX)
			result := hl + addend
			f := z.f & (SF | ZF | PF)
			if result > 0xFFFF {
				f |= CF
			}
			if (hl&0xFFF + addend&0xFFF) > 0xFFF {
				f |= HF
			}
			z.f = f
			z.setHLorIndex(useIX, result&0xFFFF)
			return
		}
		// LD rp, nn (HL→IX/IY)
		if z_ == 1 && q == 0 {
			val := z.fetchWord()
			if p == 2 { // IX/IY
				z.setHLorIndex(useIX, val)
			} else {
				z.setRp(p, val)
			}
			return
		}
	}

	if x == 1 {
		if z_ == 6 && y == 6 {
			z.halted = true
			return
		}
		if z_ == 6 { // LD r, (IX/IY+d)  ソースが(IX+d)→読み込み
			addr := ixAddr()
			z.setReg(y, z.rb(addr))
			return
		}
		if y == 6 { // LD (IX/IY+d), r  デスティネーションが(IX+d)→書き込み
			addr := ixAddr()
			z.wb(addr, z.getReg(z_))
			return
		}
		return
	}

	if x == 2 {
		if y == 6 && z_ == 6 { // ADD A, (IX/IY+d)
			addr := ixAddr()
			z.alu(0, z.rb(addr))
			return
		} else if z_ == 6 { // ALU A, (IX/IY+d)
			addr := ixAddr()
			z.alu(y, z.rb(addr))
			return
		}
		// Other x==2 opcodes (e.g. DD 83 = ADD A,E) fall through to
		// execMain, which handles the unprefixed ALU A,r form. The old
		// INC/DEC rp handling that lived here was misplaced: INC/DEC rp
		// is encoded in the x==0 group (00 rp0 011) and is now handled
		// above, while x==2 z==3 opcodes are ALU A,r (ADD A,E etc.).
	}

	if x == 3 {
		if z_ == 1 { // POP
			if p == 2 { // IX/IY
				z.setHLorIndex(useIX, z.pop())
			} else {
				z.setRp2(p, z.pop())
			}
			return
		}
		if z_ == 3 && y == 4 { // EX (SP), IX/IY
			val := z.rw(z.sp)
			z.ww(z.sp, z.getHLorIndex(useIX))
			z.setHLorIndex(useIX, val)
			return
		}
		if z_ == 5 { // PUSH
			if p == 2 {
				z.push(z.getHLorIndex(useIX))
			} else {
				z.push(z.getRp2(p))
			}
			return
		}
		if z_ == 3 {
			if q == 0 { // INC
				if p == 2 {
					z.setHLorIndex(useIX, z.getHLorIndex(useIX)+1)
				} else {
					z.setRp(p, z.getRp(p)+1)
				}
			} else { // DEC
				if p == 2 {
					z.setHLorIndex(useIX, z.getHLorIndex(useIX)-1)
				} else {
					z.setRp(p, z.getRp(p)-1)
				}
			}
			return
		}
	}

	// Fallback: treat as unprefixed
	z.execMain(op)
}

func (z *Z80) rotate(y, val byte) byte {
	var f byte
	var newVal byte
	var cy byte

	switch y {
	case 0: // RLC
		cy = (val >> 7) & 1
		newVal = (val << 1) | cy
		f = z.szpFlags(newVal)
		f |= cy
	case 1: // RRC
		cy = val & 1
		newVal = (val >> 1) | (cy << 7)
		f = z.szpFlags(newVal)
		f |= cy
	case 2: // RL
		oldCy := byte(0)
		if z.f&CF != 0 {
			oldCy = 1
		}
		newCy := (val >> 7) & 1
		newVal = (val << 1) | oldCy
		cy = newCy
		f = z.szpFlags(newVal)
		f |= cy
	case 3: // RR
		oldCy := byte(0)
		if z.f&CF != 0 {
			oldCy = 1
		}
		newCy := val & 1
		newVal = (val >> 1) | (oldCy << 7)
		cy = newCy
		f = z.szpFlags(newVal)
		f |= cy
	case 4: // SLA
		cy = (val >> 7) & 1
		newVal = val << 1
		f = z.szpFlags(newVal)
		f |= cy
	case 5: // SRA
		cy = val & 1
		newVal = (val >> 1) | (val & 0x80)
		f = z.szpFlags(newVal)
	case 7: // SRL
		cy = val & 1
		newVal = val >> 1
		f = z.szpFlags(newVal)
		f |= cy
	}

	z.f = f
	return newVal
}

func (z *Z80) execMain(op byte) {
	x := (op >> 6) & 3
	y := (op >> 3) & 7
	z_ := op & 7
	p := (y >> 1) & 3
	q := y & 1

	if x == 0 {
		if z_ == 0 {
			if y == 0 { // NOP
				// nothing
			} else if y == 1 { // EX AF, AF'
				af, af_ := z.af(), z.af_()
				z.setAf_(af)
				z.setAf(af_)
			} else if y == 2 { // DJNZ
				d := z.fetchSigned()
				z.b = (z.b - 1) & 0xFF
				if z.b != 0 {
					z.pc = (z.pc + uint16(d)) & 0xFFFF
				}
			} else if y == 3 { // JR d
				d := z.fetchSigned()
				z.pc = (z.pc + uint16(d)) & 0xFFFF
			} else { // JR cc, d (y=4..7 -> cc=y-4 -> NZ,Z,NC,C)
				d := z.fetchSigned()
				if z.checkCC(y - 4) {
					z.pc = (z.pc + uint16(d)) & 0xFFFF
				}
			}
		} else if z_ == 1 {
			if q == 0 { // LD rp, nn
				val := z.fetchWord()
				z.setRp(p, val)
			} else { // ADD HL, rp
				hl := z.hl()
				rpVal := z.getRp(p)
				result := hl + rpVal
				f := z.f & (SF | ZF | PF)
				if result > 0xFFFF {
					f |= CF
				}
				if (hl&0xFFF + rpVal&0xFFF) > 0xFFF {
					f |= HF
				}
				z.f = f
				z.setHl(result & 0xFFFF)
			}
		} else if z_ == 2 {
			if y == 0 { // LD (BC), A
				z.wb(z.bc(), z.a)
			} else if y == 1 { // LD A, (BC)
				z.a = z.rb(z.bc())
			} else if y == 2 { // LD (DE), A
				z.wb(z.de(), z.a)
			} else if y == 3 { // LD A, (DE)
				z.a = z.rb(z.de())
			} else if y == 4 { // LD (nn), HL
				addr := z.fetchWord()
				z.ww(addr, z.hl())
			} else if y == 5 { // LD HL, (nn)
				addr := z.fetchWord()
				z.setHl(z.rw(addr))
			} else if y == 6 { // LD (nn), A
				addr := z.fetchWord()
				z.wb(addr, z.a)
			} else if y == 7 { // LD A, (nn)
				addr := z.fetchWord()
				z.a = z.rb(addr)
			}
		} else if z_ == 3 {
			if q == 0 { // INC rp
				z.setRp(p, z.getRp(p)+1)
			} else { // DEC rp
				z.setRp(p, z.getRp(p)-1)
			}
		} else if z_ == 4 {
			if y == 6 { // INC (HL)
				addr := z.hl()
				val := (z.rb(addr) + 1) & 0xFF
				z.setFlagsInc(val)
				z.wb(addr, val)
			} else { // INC r
				val := (z.getReg(y) + 1) & 0xFF
				z.setFlagsInc(val)
				z.setReg(y, val)
			}
		} else if z_ == 5 {
			if y == 6 { // DEC (HL)
				addr := z.hl()
				val := (z.rb(addr) - 1) & 0xFF
				z.setFlagsDec(val)
				z.wb(addr, val)
			} else { // DEC r
				val := (z.getReg(y) - 1) & 0xFF
				z.setFlagsDec(val)
				z.setReg(y, val)
			}
		} else if z_ == 6 {
			if y == 6 { // LD (HL), n
				val := z.fetch()
				z.wb(z.hl(), val)
			} else { // LD r, n
				val := z.fetch()
				z.setReg(y, val)
			}
		} else if z_ == 7 {
			if y == 0 { // RLCA
				cy := (z.a >> 7) & 1
				z.a = (z.a << 1) | cy
				f := z.szpFlags(z.a)
				f |= cy
				z.f = f
			} else if y == 1 { // RRCA
				cy := z.a & 1
				z.a = (z.a >> 1) | (cy << 7)
				f := z.szpFlags(z.a)
				f |= cy
				z.f = f
			}
		}

	} else if x == 1 {
		if z_ == 6 && y == 6 { // HALT
			z.halted = true
		} else if z_ == 6 && y != 6 { // LD r[y], (HL) - dest=y, src=(HL): read memory at HL into register y
			z.setReg(y, z.rb(z.hl()))
		} else if y == 6 && z_ != 6 { // LD (HL), r[z] - dest=(HL), src=z: write register z to memory at HL
			z.wb(z.hl(), z.getReg(z_))
		} else { // LD r, r' - dest=y, src=z
			z.setReg(y, z.getReg(z_))
		}

	} else if x == 2 { // ALU A, r[z]
		if z_ == 6 {
			z.alu(y, z.rb(z.hl()))
		} else {
			z.alu(y, z.getReg(z_))
		}

	} else if x == 3 {
		if z_ == 0 { // RET cc
			if z.checkCC(y) {
				z.pc = z.pop()
			}
		} else if z_ == 1 {
			if q == 0 { // POP rp2
				z.setRp2(p, z.pop())
			} else { // misc
				if p == 0 { // RET
					z.pc = z.pop()
				} else if p == 1 { // EXX
					bc, bc_ := z.bc(), z.bc_()
					z.setBc_(bc)
					z.setBc(bc_)
					de, de_ := z.de(), z.de_()
					z.setDe_(de)
					z.setDe(de_)
					hl, hl_ := z.hl(), z.hl_()
					z.setHl_(hl)
					z.setHl(hl_)
				} else if p == 2 { // JP (HL)
					z.pc = z.hl()
				} else if p == 3 { // LD SP, HL
					z.sp = z.hl()
				}
			}
		} else if z_ == 2 { // JP cc, nn
			addr := z.fetchWord()
			if z.checkCC(y) {
				z.pc = addr
			}
		} else if z_ == 3 {
			if y == 0 { // JP nn
				z.pc = z.fetchWord()
			} else if y == 1 { // CB prefix (handled above)
				// shouldn't reach
			} else if y == 2 { // OUT (n), A
				port := z.fetch()
				z.portOut((uint16(z.a)<<8)|uint16(port), z.a)
			} else if y == 3 { // IN A, (n)
				port := z.fetch()
				z.a = z.portIn((uint16(z.a)<<8 | uint16(port)))
			} else if y == 4 { // EX (SP), HL
				val := z.rw(z.sp)
				z.ww(z.sp, z.hl())
				z.setHl(val)
			} else if y == 5 { // EX DE, HL
				de, hl := z.de(), z.hl()
				z.setHl(de)
				z.setDe(hl)
			} else if y == 6 { // DI
				z.iff1 = false
				z.iff2 = false
			} else if y == 7 { // EI
				z.iff1 = true
				z.eiDelay = true // 割り込み Window: EI の次の 1 命令は受付しない
				z.iff2 = true
			}
		} else if z_ == 4 { // CALL cc, nn
			addr := z.fetchWord()
			if z.checkCC(y) {
				z.push(z.pc)
				z.pc = addr
			}
		} else if z_ == 5 {
			if q == 0 { // PUSH rp2
				z.push(z.getRp2(p))
			} else {
				if p == 0 { // CALL nn
					addr := z.fetchWord()
					z.push(z.pc)
					z.pc = addr
				} else if p == 1 { // DD prefix (handled above)
					// shouldn't reach
				} else if p == 2 { // ED prefix (handled above)
					// shouldn't reach
				} else if p == 3 { // FD prefix (handled above)
					// shouldn't reach
				}
			}
		} else if z_ == 6 { // ALU A, n
			val := z.fetch()
			z.alu(y, val)
		} else if z_ == 7 { // RST
			z.push(z.pc)
			z.pc = uint16(y * 8)
		}
	}
}

func (z *Z80) loadCom(filename string) error {
	data, err := os.ReadFile(filename)
	if err != nil {
		return err
	}
	for i, b := range data {
		z.mem[0x0100+i] = b
	}
	// Set up for CP/M BDOS
	z.mem[0x0000] = 0x00 // NOP (will be caught by PC==0 check)
	z.pc = 0x0100
	z.sp = 0xFFFF
	// Push 0x0000 as return address
	z.push(0x0000)
	return nil
}

func main() {
	debugMode := flag.Bool("debug", false, "interactive step debugger")
	traceMode := flag.Bool("trace", false, "print one block per executed instruction")
	cyclesMode := flag.Bool("cycles", false, "run and print instruction/T-state summary")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <file.com> [input_text]\n\nOptions:\n", os.Args[0])
		flag.PrintDefaults()
	}
	flag.Parse()

	if flag.NArg() < 1 {
		flag.Usage()
		os.Exit(1)
	}

	filename := flag.Arg(0)
	cpu := NewZ80()

	// Set up input from command line argument or stdin
	if flag.NArg() >= 2 {
		cpu.inputBuf = []byte(flag.Arg(1))
		cpu.inputPos = 0
	}

	err := cpu.loadCom(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	switch {
	case *debugMode:
		lst, err := loadListing(strings.TrimSuffix(filename, ".com") + ".lst")
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: %v (disassembly unavailable)\n", err)
		}
		if lst == nil {
			fmt.Fprintln(os.Stderr, "note: no .lst file found; assemble with z80asm -l for source display")
		}
		newDebugger(cpu, lst).run()
	case *traceMode:
		lst, _ := loadListing(strings.TrimSuffix(filename, ".com") + ".lst")
		runTrace(cpu, lst)
	case *cyclesMode:
		runCycles(cpu)
	default:
		cpu.Run()
	}
}

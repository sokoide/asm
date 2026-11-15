// Listing-based disassembly display.
//
// simz80 does not include its own disassembler; instead it reuses the
// listing file produced by z80asm (Makefile recipes always generate
// `<name>.lst` next to `<name>.com`). Each listing line with emitted bytes
// has the form:
//
//	0100 21 bd 01 <tabs> ld hl, msg_title
//
// which gives an address -> (bytes, source text) map that is exact for the
// assembled program (the samples never execute data or self-modifying code).

package main

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

// Insn is one instruction from the assembler listing.
type Insn struct {
	Addr  uint16
	Bytes []byte
	Text  string
}

// Listing is the address-sorted instruction map built from a .lst file.
type Listing struct {
	insns  []*Insn
	byAddr map[uint16]*Insn
}

func isHexByte(s string) bool {
	if len(s) != 2 {
		return false
	}
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

func hexAddr(s string) (uint16, bool) {
	if len(s) != 4 {
		return 0, false
	}
	v := 0
	for _, c := range s {
		v <<= 4
		switch {
		case c >= '0' && c <= '9':
			v |= int(c - '0')
		case c >= 'a' && c <= 'f':
			v |= int(c-'a') + 10
		case c >= 'A' && c <= 'F':
			v |= int(c-'A') + 10
		default:
			return 0, false
		}
	}
	return uint16(v), true
}

// parseListingLine extracts one listing entry, or nil for lines without
// emitted bytes (headers, comments, labels).
func parseListingLine(line string) *Insn {
	line = strings.TrimRight(line, " \t\r\n")
	if len(line) < 4 {
		return nil
	}
	addr, ok := hexAddr(line[:4])
	if !ok {
		return nil
	}
	fields := strings.Fields(line[4:])

	// Consume leading 2-digit hex tokens (max 4: longest Z80 encoding).
	var bytes []byte
	for len(fields) > 0 && len(bytes) < 4 && isHexByte(fields[0]) {
		b, _ := hexAddr("00" + fields[0])
		bytes = append(bytes, byte(b))
		fields = fields[1:]
	}
	if len(bytes) == 0 {
		return nil // label or comment line: nothing emitted
	}
	return &Insn{Addr: addr, Bytes: bytes, Text: strings.Join(fields, " ")}
}

// loadListing reads a z80asm .lst file. Missing file returns (nil, nil).
func loadListing(path string) (*Listing, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	l := &Listing{byAddr: map[uint16]*Insn{}}
	for _, line := range strings.Split(string(data), "\n") {
		ins := parseListingLine(line)
		if ins == nil {
			continue
		}
		l.byAddr[ins.Addr] = ins
		l.insns = append(l.insns, ins)
	}
	sort.SliceStable(l.insns, func(i, j int) bool {
		return l.insns[i].Addr < l.insns[j].Addr
	})
	return l, nil
}

// indexAt returns the index of the instruction at or before addr.
func (l *Listing) indexAt(addr uint16) int {
	// Listing entries are unique per address; binary search for the
	// largest entry whose Addr <= addr.
	lo, hi := 0, len(l.insns)
	for lo < hi {
		mid := (lo + hi) / 2
		if l.insns[mid].Addr <= addr {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	return lo - 1
}

// At returns the instruction starting exactly at addr, or nil.
func (l *Listing) At(addr uint16) *Insn {
	if l == nil {
		return nil
	}
	return l.byAddr[addr]
}

// Window returns up to n instructions starting at the instruction
// containing addr (at or before it).
func (l *Listing) Window(addr uint16, n int) []*Insn {
	if l == nil || len(l.insns) == 0 {
		return nil
	}
	i := l.indexAt(addr)
	if i < 0 {
		i = 0
	}
	var out []*Insn
	for ; i < len(l.insns) && len(out) < n; i++ {
		out = append(out, l.insns[i])
	}
	return out
}

// formatBytes renders instruction bytes in fixed width (uppercase hex).
func formatBytes(b []byte) string {
	parts := make([]string, len(b))
	for i, x := range b {
		parts[i] = fmt.Sprintf("%02X", x)
	}
	s := strings.Join(parts, " ")
	// Pad to the width of a 4-byte instruction ("XX XX XX XX").
	const width = 11
	if len(s) < width {
		s += strings.Repeat(" ", width-len(s))
	}
	return s
}

// formatInsn renders one listing line like "0100  21 BD 01    ld hl, msg_title".
func formatInsn(ins *Insn, marker bool) string {
	line := fmt.Sprintf("%04X  %s  %s", ins.Addr, formatBytes(ins.Bytes), ins.Text)
	if marker {
		line += "   ◀ PC"
	}
	return line
}

// disasmLine renders the instruction at addr from the listing, falling
// back to raw memory bytes when no listing is available.
func (z *Z80) disasmLine(addr uint16, lst *Listing, marker bool) string {
	if ins := lst.At(addr); ins != nil {
		return formatInsn(ins, marker)
	}
	if lst != nil {
		// Address falls between listing entries (e.g. jumped into data).
		return fmt.Sprintf("%04X  (not in listing: %02X %02X)", addr, z.rb(addr), z.rb(addr+1))
	}
	return fmt.Sprintf("%04X  %02X %02X %02X %02X", addr, z.rb(addr), z.rb(addr+1), z.rb(addr+2), z.rb(addr+3))
}

// bdosLine renders a pseudo-instruction for the CP/M BDOS trap at 0x0005.
func (z *Z80) bdosLine() string {
	name := fmt.Sprintf("BDOS fn=%d", z.c)
	switch z.c {
	case 1:
		name = "BDOS C=1 console input"
	case 2:
		name = fmt.Sprintf("BDOS C=2 console output E=%02X '%c'", z.e, z.e&0x7F)
	case 9:
		name = fmt.Sprintf("BDOS C=9 print string DE=%04X", z.de())
	case 10:
		name = fmt.Sprintf("BDOS C=10 read line DE=%04X", z.de())
	case 12:
		name = "BDOS C=12 version"
	}
	return fmt.Sprintf("0005  %s", name)
}

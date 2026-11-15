#!/usr/bin/env python3
"""simz80.py - Minimal Z80 simulator for educational assembly programs.

Supports CP/M BDOS calling convention:
  CALL 0x0005 with C=function, DE=parameter
  Fn 1:  Console input  -> A=char
  Fn 2:  Console output (E=char)
  Fn 9:  Print string (DE=addr, '$'-terminated)
  Fn 10: Read console buffer (DE=addr)

Usage: simz80.py <file.com> [input_text]
"""

import sys
import os


class Z80:
    """Minimal Z80 CPU simulator."""

    def __init__(self):
        self.mem = bytearray(65536)
        # Registers
        self.a = 0; self.f = 0
        self.b = 0; self.c = 0
        self.d = 0; self.e = 0
        self.h = 0; self.l = 0
        # Shadow registers
        self.a_ = 0; self.f_ = 0
        self.b_ = 0; self.c_ = 0
        self.d_ = 0; self.e_ = 0
        self.h_ = 0; self.l_ = 0
        # Index registers
        self.ixh = 0; self.ixl = 0
        self.iyh = 0; self.iyl = 0
        # Stack pointer, program counter
        self.sp = 0xFFFF
        self.pc = 0x0000
        # Interrupt
        self.i = 0; self.r = 0
        self.iff1 = False; self.iff2 = False
        self.im = 0
        self.halted = False
        # I/O
        self.input_buf = b""
        self.input_pos = 0
        # Cycle count limit to prevent infinite loops
        self.cycles = 0
        self.max_cycles = 10_000_000

    # -- Flag bits --
    SF = 0x80  # Sign
    ZF = 0x40  # Zero
    YF = 0x20  # undocumented
    HF = 0x10  # Half-carry
    XF = 0x08  # undocumented
    PF = 0x04  # Parity/Overflow
    NF = 0x02  # Subtract
    CF = 0x01  # Carry

    # -- Register pairs --
    @property
    def af(self): return (self.a << 8) | self.f
    @af.setter
    def af(self, v): self.a = (v >> 8) & 0xFF; self.f = v & 0xFF

    @property
    def bc(self): return (self.b << 8) | self.c
    @bc.setter
    def bc(self, v): self.b = (v >> 8) & 0xFF; self.c = v & 0xFF

    @property
    def de(self): return (self.d << 8) | self.e
    @de.setter
    def de(self, v): self.d = (v >> 8) & 0xFF; self.e = v & 0xFF

    @property
    def hl(self): return (self.h << 8) | self.l
    @hl.setter
    def hl(self, v): self.h = (v >> 8) & 0xFF; self.l = v & 0xFF

    @property
    def sp_val(self): return self.sp
    @sp_val.setter
    def sp_val(self, v): self.sp = v & 0xFFFF

    @property
    def ix(self): return (self.ixh << 8) | self.ixl
    @ix.setter
    def ix(self, v): self.ixh = (v >> 8) & 0xFF; self.ixl = v & 0xFF

    @property
    def iy(self): return (self.iyh << 8) | self.iyl
    @iy.setter
    def iy(self, v): self.iyh = (v >> 8) & 0xFF; self.iyl = v & 0xFF

    # -- Memory access --
    def rb(self, addr):
        return self.mem[addr & 0xFFFF]

    def wb(self, addr, v):
        self.mem[addr & 0xFFFF] = v & 0xFF

    def rw(self, addr):
        return self.rb(addr) | (self.rb(addr + 1) << 8)

    def ww(self, addr, v):
        self.wb(addr, v & 0xFF)
        self.wb(addr + 1, (v >> 8) & 0xFF)

    # -- Stack --
    def push(self, v):
        self.sp = (self.sp - 2) & 0xFFFF
        self.ww(self.sp, v)

    def pop(self):
        v = self.rw(self.sp)
        self.sp = (self.sp + 2) & 0xFFFF
        return v

    # -- Fetch --
    def fetch(self):
        v = self.rb(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetch_word(self):
        lo = self.fetch()
        hi = self.fetch()
        return (hi << 8) | lo

    def fetch_signed(self):
        v = self.fetch()
        return v - 256 if v > 127 else v

    # -- Flag helpers --
    def szp_flags(self, v):
        """Compute S, Z, P flags for 8-bit value."""
        f = 0
        if v & 0x80: f |= self.SF
        if (v & 0xFF) == 0: f |= self.ZF
        # Parity
        p = v & 0xFF
        p ^= p >> 4; p ^= p >> 2; p ^= p >> 1
        if not (p & 1): f |= self.PF
        return f

    def set_flags_add(self, a, b, cy=0):
        """Set flags for ADD/ADC."""
        r = a + b + cy
        f = self.szp_flags(r & 0xFF)
        if r & 0x100: f |= self.CF
        if ((a & 0x0F) + (b & 0x0F) + cy) > 0x0F: f |= self.HF
        self.f = f

    def set_flags_sub(self, a, b, cy=0):
        """Set flags for SUB/SBC."""
        r = a - b - cy
        f = self.szp_flags(r & 0xFF)
        f |= self.NF
        if r < 0: f |= self.CF
        if ((a & 0x0F) - (b & 0x0F) - cy) < 0: f |= self.HF
        # Overflow: sign of result differs from first operand
        if ((a ^ b) & (a ^ r)) & 0x80: f |= self.PF
        self.f = f

    def set_flags_logic(self, v):
        """Set flags for AND/OR/XOR (clears N, H, C)."""
        f = self.szp_flags(v)
        self.f = f

    def set_flags_inc(self, v):
        """Set flags for INC (preserves CF)."""
        cf = self.f & self.CF
        f = self.szp_flags(v & 0xFF)
        if (v & 0x0F) == 0x00: f |= self.HF
        self.f = f | cf

    def set_flags_dec(self, v):
        """Set flags for DEC (preserves CF)."""
        cf = self.f & self.CF
        f = self.szp_flags(v & 0xFF)
        f |= self.NF
        if (v & 0x0F) == 0x0F: f |= self.HF
        self.f = f | cf

    def parity(self, v):
        """Return True if even parity."""
        v &= 0xFF
        v ^= v >> 4; v ^= v >> 2; v ^= v >> 1
        return not (v & 1)

    # -- Condition check --
    def check_cc(self, cc):
        if cc == 0: return not (self.f & self.ZF)   # NZ
        if cc == 1: return bool(self.f & self.ZF)     # Z
        if cc == 2: return not (self.f & self.CF)     # NC
        if cc == 3: return bool(self.f & self.CF)     # C
        if cc == 4: return not (self.f & self.PF)     # PO
        if cc == 5: return bool(self.f & self.PF)     # PE
        if cc == 6: return not (self.f & self.SF)     # P
        if cc == 7: return bool(self.f & self.SF)     # M
        return False

    # -- Register access by index --
    def get_reg(self, idx):
        """Get 8-bit register by index: B=0,C=1,D=2,E=3,H=4,L=5,(HL)=6,A=7"""
        if idx == 0: return self.b
        if idx == 1: return self.c
        if idx == 2: return self.d
        if idx == 3: return self.e
        if idx == 4: return self.h
        if idx == 5: return self.l
        if idx == 6: return self.rb(self.hl)
        if idx == 7: return self.a

    def set_reg(self, idx, v):
        v &= 0xFF
        if idx == 0: self.b = v
        elif idx == 1: self.c = v
        elif idx == 2: self.d = v
        elif idx == 3: self.e = v
        elif idx == 4: self.h = v
        elif idx == 5: self.l = v
        elif idx == 6: self.wb(self.hl, v)
        elif idx == 7: self.a = v

    def get_rp(self, idx):
        """Get register pair: BC=0,DE=1,HL=2,SP=3"""
        if idx == 0: return self.bc
        if idx == 1: return self.de
        if idx == 2: return self.hl
        if idx == 3: return self.sp

    def set_rp(self, idx, v):
        v &= 0xFFFF
        if idx == 0: self.bc = v
        elif idx == 1: self.de = v
        elif idx == 2: self.hl = v
        elif idx == 3: self.sp = v

    def get_rp2(self, idx):
        """Get register pair (AF variant): BC=0,DE=1,HL=2,AF=3"""
        if idx == 0: return self.bc
        if idx == 1: return self.de
        if idx == 2: return self.hl
        if idx == 3: return self.af

    def set_rp2(self, idx, v):
        v &= 0xFFFF
        if idx == 0: self.bc = v
        elif idx == 1: self.de = v
        elif idx == 2: self.hl = v
        elif idx == 3: self.af = v

    # -- I/O --
    def port_in(self, port):
        return 0xFF  # Default: floating bus

    def port_out(self, port, val):
        pass  # Default: no-op

    # -- BDOS handler --
    def bdos_call(self):
        fn = self.c
        if fn == 1:  # Console input
            if self.input_pos < len(self.input_buf):
                ch = self.input_buf[self.input_pos]
                self.input_pos += 1
                # Echo
                if ch == 0x0A or ch == 0x0D:
                    sys.stdout.write("\r\n")
                else:
                    sys.stdout.write(chr(ch))
                sys.stdout.flush()
                self.a = ch & 0x7F
            else:
                ch = sys.stdin.read(1)
                if not ch:
                    self.a = 0x0D
                else:
                    self.a = ord(ch) & 0x7F
        elif fn == 2:  # Console output
            sys.stdout.write(chr(self.e & 0x7F))
            sys.stdout.flush()
        elif fn == 9:  # Print string ($-terminated)
            addr = self.de
            while True:
                ch = self.rb(addr)
                if ch == ord('$') or ch == 0:
                    break
                sys.stdout.write(chr(ch))
                addr = (addr + 1) & 0xFFFF
            sys.stdout.flush()
        elif fn == 10:  # Read console buffer
            buf_addr = self.de
            max_len = self.rb(buf_addr)
            if max_len == 0:
                self.wb(buf_addr + 1, 0)
                return
            if self.input_pos < len(self.input_buf):
                remaining = self.input_buf[self.input_pos:]
                # Find newline
                line_end = remaining.find(b'\n')
                if line_end >= 0:
                    line = remaining[:line_end]
                    self.input_pos += line_end + 1
                else:
                    line = remaining
                    self.input_pos = len(self.input_buf)
                if len(line) > max_len:
                    line = line[:max_len]
                for i, b in enumerate(line):
                    self.wb(buf_addr + 2 + i, b)
                self.wb(buf_addr + 1, len(line))
                sys.stdout.write(line.decode('ascii', errors='replace') + "\r\n")
                sys.stdout.flush()
            else:
                try:
                    line = input()
                    line = line[:max_len]
                    self.wb(buf_addr + 1, len(line))
                    for i, ch in enumerate(line):
                        self.wb(buf_addr + 2 + i, ord(ch))
                except EOFError:
                    self.wb(buf_addr + 1, 0)
        else:
            self.a = 0xFF  # Unknown function

    # -- ALU operations --
    def alu(self, op, val):
        """Execute ALU operation: ADD=0,ADC=1,SUB=2,SBC=3,AND=4,XOR=5,OR=6,CP=7"""
        if op == 0:  # ADD
            self.set_flags_add(self.a, val)
            self.a = (self.a + val) & 0xFF
        elif op == 1:  # ADC
            cy = self.f & self.CF
            self.set_flags_add(self.a, val, cy)
            self.a = (self.a + val + cy) & 0xFF
        elif op == 2:  # SUB
            self.set_flags_sub(self.a, val)
            self.a = (self.a - val) & 0xFF
        elif op == 3:  # SBC
            cy = self.f & self.CF
            self.set_flags_sub(self.a, val, cy)
            self.a = (self.a - val - cy) & 0xFF
        elif op == 4:  # AND
            self.a = self.a & val
            self.set_flags_logic(self.a)
            self.f |= self.HF  # AND sets H
        elif op == 5:  # XOR
            self.a = (self.a ^ val) & 0xFF
            self.set_flags_logic(self.a)
        elif op == 6:  # OR
            self.a = (self.a | val) & 0xFF
            self.set_flags_logic(self.a)
        elif op == 7:  # CP
            self.set_flags_sub(self.a, val)

    # -- CB prefix (rotates, shifts, BIT/SET/RES) --
    def exec_cb(self):
        op = self.fetch()
        x = (op >> 6) & 3
        y = (op >> 3) & 7
        z = op & 7

        if x == 0:  # Rotate/shift
            val = self.get_reg(z)
            cy = 0
            if y == 0:  # RLC
                cy = (val >> 7) & 1
                val = ((val << 1) | cy) & 0xFF
            elif y == 1:  # RRC
                cy = val & 1
                val = ((val >> 1) | (cy << 7)) & 0xFF
            elif y == 2:  # RL
                cy = (self.f & self.CF) != 0
                new_cy = (val >> 7) & 1
                val = ((val << 1) | (1 if cy else 0)) & 0xFF
                cy = new_cy
            elif y == 3:  # RR
                cy = (self.f & self.CF) != 0
                new_cy = val & 1
                val = ((val >> 1) | (0x80 if cy else 0)) & 0xFF
                cy = new_cy
            elif y == 4:  # SLA
                cy = (val >> 7) & 1
                val = (val << 1) & 0xFF
            elif y == 5:  # SRA
                cy = val & 1
                val = ((val >> 1) | (val & 0x80)) & 0xFF
            elif y == 6:  # SLL (undocumented) / SWAP
                cy = (val >> 7) & 1
                val = ((val << 1) | 1) & 0xFF
            elif y == 7:  # SRL
                cy = val & 1
                val = (val >> 1) & 0xFF

            f = self.szp_flags(val)
            if y <= 7:
                # carry from the operation above
                if y in (0, 2, 4, 6):
                    f |= cy  # carry from bit 7
                elif y in (1, 3, 5, 7):
                    f |= cy  # carry from bit 0
            self.f = f
            self.set_reg(z, val)

        elif x == 1:  # BIT y, r[z]
            val = self.get_reg(z)
            result = val & (1 << y)
            f = self.f & self.CF  # preserve carry
            f |= self.HF
            if result == 0: f |= self.ZF
            if y == 7 and (val & 0x80): f |= self.SF
            self.f = f

        elif x == 2:  # RES y, r[z]
            val = self.get_reg(z)
            val &= ~(1 << y)
            self.set_reg(z, val)

        elif x == 3:  # SET y, r[z]
            val = self.get_reg(z)
            val |= (1 << y)
            self.set_reg(z, val)

    # -- ED prefix (block ops, extra instructions) --
    def exec_ed(self):
        op = self.fetch()
        x = (op >> 6) & 3
        y = (op >> 3) & 7
        z = op & 7
        p = (y >> 1) & 3
        q = y & 1

        if x == 1:
            if z == 0:  # IN r, (C) / IN (C)
                val = self.port_in(self.bc)
                if y != 6: self.set_reg(y, val)
                self.f = self.szp_flags(val)
                # TODO: half-carry, overflow flags
            elif z == 1:  # OUT (C), r / OUT (C), 0
                val = self.get_reg(y) if y != 6 else 0
                self.port_out(self.bc, val)
            elif z == 2:  # SBC HL,rp / ADC HL,rp
                rp_val = self.get_rp(p)
                hl = self.hl
                if q == 0:  # SBC
                    cy = self.f & self.CF
                    result = hl - rp_val - cy
                    f = 0
                    if result & 0x8000: f |= self.SF
                    if (result & 0xFFFF) == 0: f |= self.ZF
                    f |= self.NF
                    if result < 0: f |= self.CF
                    # half-carry (simplified)
                    if ((hl & 0xFFF) - (rp_val & 0xFFF) - cy) < 0: f |= self.HF
                    # overflow
                    if ((hl ^ rp_val) & (hl ^ result)) & 0x8000: f |= self.PF
                    self.f = f
                    self.hl = result & 0xFFFF
                else:  # ADC
                    cy = self.f & self.CF
                    result = hl + rp_val + cy
                    f = 0
                    if result & 0x8000: f |= self.SF
                    if (result & 0xFFFF) == 0: f |= self.ZF
                    if result > 0xFFFF: f |= self.CF
                    if ((hl & 0xFFF) + (rp_val & 0xFFF) + cy) > 0xFFF: f |= self.HF
                    if ((hl ^ result) & (rp_val ^ result)) & 0x8000: f |= self.PF
                    self.f = f
                    self.hl = result & 0xFFFF
            elif z == 3:  # LD (nn),rp / LD rp,(nn)
                addr = self.fetch_word()
                if q == 0:
                    self.ww(addr, self.get_rp(p))
                else:
                    self.set_rp(p, self.rw(addr))
            elif z == 4:  # NEG
                self.set_flags_sub(0, self.a)
                self.a = (-self.a) & 0xFF
            elif z == 5:  # RETN / RETI
                self.iff1 = self.iff2
                self.pc = self.pop()
            elif z == 6:  # IM mode
                modes = [0, 0, 1, 2, 0, 0, 1, 2]
                self.im = modes[y]
            elif z == 7:
                if y == 0:  # LD I, A
                    self.i = self.a
                elif y == 1:  # LD R, A
                    self.r = self.a
                elif y == 2:  # LD A, I
                    self.a = self.i
                    f = self.szp_flags(self.a)
                    f |= self.f & self.CF
                    if self.iff2: f |= self.PF
                    self.f = f
                elif y == 3:  # LD A, R
                    self.a = self.r
                    f = self.szp_flags(self.a)
                    f |= self.f & self.CF
                    if self.iff2: f |= self.PF
                    self.f = f
                elif y == 4:  # RRD
                    val = self.rb(self.hl)
                    new_val = ((self.a & 0x0F) << 4) | ((val >> 4) & 0x0F)
                    self.a = (self.a & 0xF0) | (val & 0x0F)
                    self.wb(self.hl, new_val)
                    self.f = self.szp_flags(self.a) | (self.f & self.CF)
                elif y == 5:  # RLD
                    val = self.rb(self.hl)
                    new_val = ((val << 4) & 0xF0) | (self.a & 0x0F)
                    self.a = (self.a & 0xF0) | ((val >> 4) & 0x0F)
                    self.wb(self.hl, new_val)
                    self.f = self.szp_flags(self.a) | (self.f & self.CF)

        elif x == 2:
            if z == 0:  # LDI, LDD, LDIR, LDDR
                val = self.rb(self.hl)
                self.wb(self.de, val)
                if q == 0:  # LDI / LDIR
                    self.hl = (self.hl + 1) & 0xFFFF
                    self.de = (self.de + 1) & 0xFFFF
                else:  # LDD / LDDR
                    self.hl = (self.hl - 1) & 0xFFFF
                    self.de = (self.de - 1) & 0xFFFF
                self.bc = (self.bc - 1) & 0xFFFF
                f = self.f & (self.SF | self.ZF | self.CF)
                if self.bc != 0: f |= self.PF
                self.f = f
                if q == 0 and p == 1 and self.bc != 0:  # LDIR
                    self.pc = (self.pc - 2) & 0xFFFF
                elif q == 1 and p == 1 and self.bc != 0:  # LDDR
                    self.pc = (self.pc - 2) & 0xFFFF
            elif z == 1:  # CPI, CPD, CPIR, CPDR
                val = self.rb(self.hl)
                result = (self.a - val) & 0xFF
                if q == 0:
                    self.hl = (self.hl + 1) & 0xFFFF
                else:
                    self.hl = (self.hl - 1) & 0xFFFF
                self.bc = (self.bc - 1) & 0xFFFF
                f = self.szp_flags(result)
                f |= self.NF
                if (self.a & 0x0F) < (val & 0x0F): f |= self.HF
                if self.bc != 0: f |= self.PF
                self.f = f
                if q == 0 and p == 1 and self.bc != 0 and result != 0:  # CPIR
                    self.pc = (self.pc - 2) & 0xFFFF
                elif q == 1 and p == 1 and self.bc != 0 and result != 0:  # CPDR
                    self.pc = (self.pc - 2) & 0xFFFF
            elif z == 2:  # INI, IND, INIR, INDR
                val = self.port_in(self.bc)
                self.wb(self.hl, val)
                self.b = (self.b - 1) & 0xFF
                if q == 0:
                    self.hl = (self.hl + 1) & 0xFFFF
                else:
                    self.hl = (self.hl - 1) & 0xFFFF
                # Z flag
                if self.b == 0: self.f |= self.ZF
                else: self.f &= ~self.ZF
                self.f |= self.NF
            elif z == 3:  # OUTI, OUTD, OTIR, OTDR
                val = self.rb(self.hl)
                self.port_out(self.bc, val)
                self.b = (self.b - 1) & 0xFF
                if q == 0:
                    self.hl = (self.hl + 1) & 0xFFFF
                else:
                    self.hl = (self.hl - 1) & 0xFFFF
                if self.b == 0: self.f |= self.ZF
                else: self.f &= ~self.ZF
                self.f |= self.NF

    # -- Main execution --
    def run(self):
        while not self.halted and self.cycles < self.max_cycles:
            self.cycles += 1

            # BDOS trap at 0x0005
            if self.pc == 0x0005:
                self.bdos_call()
                self.pc = self.pop()
                continue

            # Terminal trap at 0x0000
            if self.pc == 0x0000:
                break

            op = self.fetch()

            # -- CB prefix --
            if op == 0xCB:
                self.exec_cb()
                continue

            # -- DD prefix (IX) --
            if op == 0xDD:
                self._exec_ix()
                continue

            # -- ED prefix --
            if op == 0xED:
                self.exec_ed()
                continue

            # -- FD prefix (IY) --
            if op == 0xFD:
                self._exec_iy()
                continue

            self._exec_main(op)

        if self.cycles >= self.max_cycles:
            pass  # silent timeout, like QEMU timeout

    def _exec_ix(self):
        """Execute instruction with IX prefix."""
        op = self.fetch()
        if op == 0xCB:
            # DD CB dd op - bit op on (IX+d)
            d = self.fetch_signed()
            addr = (self.ix + d) & 0xFFFF
            cbop = self.fetch()
            x = (cbop >> 6) & 3
            y = (cbop >> 3) & 7
            z = cbop & 7
            val = self.rb(addr)
            if x == 0:  # rotate/shift
                val = self._rotate(y, val)
                self.wb(addr, val)
                self.set_reg(z, val)
            elif x == 1:  # BIT
                f = self.f & self.CF
                f |= self.HF
                if not (val & (1 << y)): f |= self.ZF
                self.f = f
            elif x == 2:  # RES
                val &= ~(1 << y)
                self.wb(addr, val)
                self.set_reg(z, val)
            elif x == 3:  # SET
                val |= (1 << y)
                self.wb(addr, val)
                self.set_reg(z, val)
            return
        if op == 0xDD:
            # DD DD = prefix on prefix, treat as single DD
            self._exec_ix()
            return

        self._exec_with_hl(op, use_ix=True)

    def _exec_iy(self):
        """Execute instruction with IY prefix."""
        op = self.fetch()
        if op == 0xCB:
            d = self.fetch_signed()
            addr = (self.iy + d) & 0xFFFF
            cbop = self.fetch()
            x = (cbop >> 6) & 3
            y = (cbop >> 3) & 7
            z = cbop & 7
            val = self.rb(addr)
            if x == 0:
                val = self._rotate(y, val)
                self.wb(addr, val)
                self.set_reg(z, val)
            elif x == 1:
                f = self.f & self.CF
                f |= self.HF
                if not (val & (1 << y)): f |= self.ZF
                self.f = f
            elif x == 2:
                val &= ~(1 << y)
                self.wb(addr, val)
                self.set_reg(z, val)
            elif x == 3:
                val |= (1 << y)
                self.wb(addr, val)
                self.set_reg(z, val)
            return
        if op == 0xFD:
            self._exec_iy()
            return

        self._exec_with_hl(op, use_ix=False)

    def _get_hl_or_index(self, use_ix):
        if use_ix:
            return self.ix
        else:
            return self.iy

    def _set_hl_or_index(self, use_ix, v):
        if use_ix:
            self.ix = v
        else:
            self.iy = v

    def _exec_with_hl(self, op, use_ix):
        """Execute instruction replacing HL with IX or IY."""
        x = (op >> 6) & 3
        y = (op >> 3) & 7
        z = op & 7
        p = (y >> 1) & 3
        q = y & 1

        # Helper: get displacement address for (IX/IY+d)
        def ix_addr():
            d = self.fetch_signed()
            return (self._get_hl_or_index(use_ix) + d) & 0xFFFF

        if x == 0:
            if z == 6:  # LD (IX/IY+d), n
                addr = ix_addr()
                val = self.fetch()
                self.wb(addr, val)
                return
            elif y == 6:  # LD (IX/IY+d)
                addr = ix_addr()
                self.a = self.rb(addr)
                return
            elif y == 4 or y == 5:
                # NOP-like, shouldn't happen with IX prefix in our programs
                pass
            else:
                # Try treating as regular instruction with IX displacement
                # For LD (IX/IY+d), r / LD r, (IX/IY+d)
                if z == 4 or z == 5:
                    pass
                # Fallback: re-decode
                pass

        if x == 1:
            if z == 6 and y == 6:
                self.halted = True
                return
            if z == 6:  # LD (IX/IY+d), r
                addr = ix_addr()
                self.wb(addr, self.get_reg(y))
                return
            if y == 6:  # LD r, (IX/IY+d)
                addr = ix_addr()
                self.set_reg(z, self.rb(addr))
                return
            # For other x=1 instructions, treat as HL replacements
            # LD rp, nn
            if z == 1:
                val = self.fetch_word()
                if p == 2:  # IX/IY
                    self._set_hl_or_index(use_ix, val)
                else:
                    self.set_rp(p, val)
                return
            # ADD IX/IY, rp
            if y == 4 and z == 3:
                pass
            return

        if x == 2:
            if y == 6 and z == 6:  # LD (IX/IY+d)
                addr = ix_addr()
                self.alu(0, self.rb(addr))
                return
            elif z == 6:  # ALU A, (IX/IY+d)
                addr = ix_addr()
                self.alu(y, self.rb(addr))
                return
            # INC/DEC
            if z == 3:
                if q == 0:  # INC rp (IX/IY)
                    if p == 2:
                        self._set_hl_or_index(use_ix, (self._get_hl_or_index(use_ix) + 1) & 0xFFFF)
                    else:
                        self.set_rp(p, (self.get_rp(p) + 1) & 0xFFFF)
                else:  # DEC rp
                    if p == 2:
                        self._set_hl_or_index(use_ix, (self._get_hl_or_index(use_ix) - 1) & 0xFFFF)
                    else:
                        self.set_rp(p, (self.get_rp(p) - 1) & 0xFFFF)
                return
            if z == 4:  # INC (IX/IY+d)
                addr = ix_addr()
                val = (self.rb(addr) + 1) & 0xFF
                self.set_flags_inc(val)
                self.wb(addr, val)
                return
            if z == 5:  # DEC (IX/IY+d)
                addr = ix_addr()
                val = (self.rb(addr) - 1) & 0xFF
                self.set_flags_dec(val)
                self.wb(addr, val)
                return

        if x == 3:
            if z == 1:  # POP
                if p == 2:  # IX/IY
                    self._set_hl_or_index(use_ix, self.pop())
                else:
                    self.set_rp2(p, self.pop())
                return
            if z == 3 and y == 4:  # EX (SP), IX/IY
                val = self.rw(self.sp)
                self.ww(self.sp, self._get_hl_or_index(use_ix))
                self._set_hl_or_index(use_ix, val)
                return
            if z == 5:  # PUSH
                if p == 2:
                    self.push(self._get_hl_or_index(use_ix))
                else:
                    self.push(self.get_rp2(p))
                return
            if z == 3:
                if q == 0:  # INC
                    if p == 2:
                        self._set_hl_or_index(use_ix, (self._get_hl_or_index(use_ix) + 1) & 0xFFFF)
                    else:
                        self.set_rp(p, (self.get_rp(p) + 1) & 0xFFFF)
                else:  # DEC
                    if p == 2:
                        self._set_hl_or_index(use_ix, (self._get_hl_or_index(use_ix) - 1) & 0xFFFF)
                    else:
                        self.set_rp(p, (self.get_rp(p) - 1) & 0xFFFF)
                return

        # If we get here, treat as unprefixed (simplified fallback)
        self._exec_main(op)

    def _rotate(self, y, val):
        """Execute rotate/shift for CB prefix."""
        if y == 0:  # RLC
            cy = (val >> 7) & 1
            val = ((val << 1) | cy) & 0xFF
        elif y == 1:  # RRC
            cy = val & 1
            val = ((val >> 1) | (cy << 7)) & 0xFF
        elif y == 2:  # RL
            cy = (self.f & self.CF) != 0
            new_cy = (val >> 7) & 1
            val = ((val << 1) | (1 if cy else 0)) & 0xFF
        elif y == 3:  # RR
            cy = (self.f & self.CF) != 0
            new_cy = val & 1
            val = ((val >> 1) | (0x80 if cy else 0)) & 0xFF
        elif y == 4:  # SLA
            val = (val << 1) & 0xFF
        elif y == 5:  # SRA
            val = ((val >> 1) | (val & 0x80)) & 0xFF
        elif y == 7:  # SRL
            val = (val >> 1) & 0xFF
        f = self.szp_flags(val)
        if y in (0, 4):
            f |= (val & 1)  # bit 0 was shifted in
        elif y in (1, 5, 7):
            pass  # carry already handled
        self.f = f
        return val

    def _exec_main(self, op):
        """Execute main (unprefixed) instruction."""
        x = (op >> 6) & 3
        y = (op >> 3) & 7
        z = op & 7
        p = (y >> 1) & 3
        q = y & 1

        if x == 0:
            if z == 0:
                if y == 0:  # NOP
                    pass
                elif y == 1:  # EX AF, AF'
                    self.af, self.af_ = self.af_, self.af
                elif y == 2:  # DJNZ
                    d = self.fetch_signed()
                    self.b = (self.b - 1) & 0xFF
                    if self.b != 0:
                        self.pc = (self.pc + d) & 0xFFFF
                elif y == 3:  # JR d
                    d = self.fetch_signed()
                    self.pc = (self.pc + d) & 0xFFFF
                else:  # JR cc, d (y=4..7 -> cc=y-4 -> NZ,Z,NC,C)
                    d = self.fetch_signed()
                    if self.check_cc(y - 4):
                        self.pc = (self.pc + d) & 0xFFFF
            elif z == 1:
                if q == 0:  # LD rp, nn
                    val = self.fetch_word()
                    self.set_rp(p, val)
                else:  # ADD HL, rp
                    hl = self.hl
                    rp_val = self.get_rp(p)
                    result = hl + rp_val
                    f = self.f & (self.SF | self.ZF | self.PF)
                    if result > 0xFFFF: f |= self.CF
                    if ((hl & 0xFFF) + (rp_val & 0xFFF)) > 0xFFF: f |= self.HF
                    self.f = f
                    self.hl = result & 0xFFFF
            elif z == 2:
                if y == 0:  # LD (BC), A
                    self.wb(self.bc, self.a)
                elif y == 1:  # LD A, (BC)
                    self.a = self.rb(self.bc)
                elif y == 2:  # LD (DE), A
                    self.wb(self.de, self.a)
                elif y == 3:  # LD A, (DE)
                    self.a = self.rb(self.de)
                elif y == 4:  # LD (nn), HL
                    addr = self.fetch_word()
                    self.ww(addr, self.hl)
                elif y == 5:  # LD HL, (nn)
                    addr = self.fetch_word()
                    self.hl = self.rw(addr)
                elif y == 6:  # LD (nn), A
                    addr = self.fetch_word()
                    self.wb(addr, self.a)
                elif y == 7:  # LD A, (nn)
                    addr = self.fetch_word()
                    self.a = self.rb(addr)
            elif z == 3:
                if q == 0:  # INC rp
                    self.set_rp(p, (self.get_rp(p) + 1) & 0xFFFF)
                else:  # DEC rp
                    self.set_rp(p, (self.get_rp(p) - 1) & 0xFFFF)
            elif z == 4:
                if y == 6:  # INC (HL)
                    addr = self.hl
                    val = (self.rb(addr) + 1) & 0xFF
                    self.set_flags_inc(val)
                    self.wb(addr, val)
                else:  # INC r
                    val = (self.get_reg(y) + 1) & 0xFF
                    self.set_flags_inc(val)
                    self.set_reg(y, val)
            elif z == 5:
                if y == 6:  # DEC (HL)
                    addr = self.hl
                    val = (self.rb(addr) - 1) & 0xFF
                    self.set_flags_dec(val)
                    self.wb(addr, val)
                else:  # DEC r
                    val = (self.get_reg(y) - 1) & 0xFF
                    self.set_flags_dec(val)
                    self.set_reg(y, val)
            elif z == 6:
                if y == 6:  # LD (HL), n
                    val = self.fetch()
                    self.wb(self.hl, val)
                else:  # LD r, n
                    val = self.fetch()
                    self.set_reg(y, val)

        elif x == 1:
            if z == 6 and y == 6:  # HALT
                self.halted = True
            elif z == 6:  # LD (HL), r
                self.wb(self.hl, self.get_reg(y))
            elif y == 6:  # LD r, (HL)
                self.set_reg(z, self.rb(self.hl))
            else:  # LD r, r'
                self.set_reg(y, self.get_reg(z))

        elif x == 2:  # ALU A, r[z]
            if z == 6:
                self.alu(y, self.rb(self.hl))
            else:
                self.alu(y, self.get_reg(z))

        elif x == 3:
            if z == 0:  # RET cc
                if self.check_cc(y):
                    self.pc = self.pop()
            elif z == 1:
                if q == 0:  # POP rp2
                    self.set_rp2(p, self.pop())
                else:  # misc
                    if p == 0:  # RET
                        self.pc = self.pop()
                    elif p == 1:  # EXX
                        self.bc_, self.bc = self.bc, self.bc_
                        self.de_, self.de = self.de, self.de_
                        self.hl_, self.hl = self.hl, self.hl_
                    elif p == 2:  # JP (HL)
                        self.pc = self.hl
                    elif p == 3:  # LD SP, HL
                        self.sp = self.hl
            elif z == 2:  # JP cc, nn
                addr = self.fetch_word()
                if self.check_cc(y):
                    self.pc = addr
            elif z == 3:
                if y == 0:  # JP nn
                    self.pc = self.fetch_word()
                elif y == 1:  # CB prefix (handled above, shouldn't reach)
                    pass
                elif y == 2:  # OUT (n), A
                    port = self.fetch()
                    self.port_out((self.a << 8) | port, self.a)
                elif y == 3:  # IN A, (n)
                    port = self.fetch()
                    self.a = self.port_in((self.a << 8) | port)
                elif y == 4:  # EX (SP), HL
                    val = self.rw(self.sp)
                    self.ww(self.sp, self.hl)
                    self.hl = val
                elif y == 5:  # EX DE, HL
                    self.de, self.hl = self.hl, self.de
                elif y == 6:  # DI
                    self.iff1 = False
                    self.iff2 = False
                elif y == 7:  # EI
                    self.iff1 = True
                    self.iff2 = True
            elif z == 4:  # CALL cc, nn
                addr = self.fetch_word()
                if self.check_cc(y):
                    self.push(self.pc)
                    self.pc = addr
            elif z == 5:
                if q == 0:  # PUSH rp2
                    self.push(self.get_rp2(p))
                else:
                    if p == 0:  # CALL nn
                        addr = self.fetch_word()
                        self.push(self.pc)
                        self.pc = addr
                    elif p == 1:  # DD prefix (handled above)
                        pass
                    elif p == 2:  # ED prefix (handled above)
                        pass
                    elif p == 3:  # FD prefix (handled above)
                        pass
            elif z == 6:  # ALU A, n
                val = self.fetch()
                self.alu(y, val)
            elif z == 7:  # RST
                self.push(self.pc)
                self.pc = y * 8

    def load_com(self, filename):
        """Load a CP/M .COM file at 0x0100."""
        with open(filename, 'rb') as f:
            data = f.read()
        for i, b in enumerate(data):
            self.mem[0x0100 + i] = b
        # Set up for CP/M BDOS
        # Place a return trap at 0x0000 (program RET lands here)
        self.mem[0x0000] = 0x00  # NOP (will be caught by PC==0 check)
        self.pc = 0x0100
        self.sp = 0xFFFF
        # Push 0x0000 as return address (program RET will land at 0)
        self.push(0x0000)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file.com> [input_text]", file=sys.stderr)
        sys.exit(1)

    filename = sys.argv[1]
    if not os.path.exists(filename):
        print(f"Error: file not found: {filename}", file=sys.stderr)
        sys.exit(1)

    cpu = Z80()

    # Set up input from command line argument or stdin
    if len(sys.argv) >= 3:
        input_text = sys.argv[2]
        # Convert \n and \r escapes
        input_text = input_text.replace('\\n', '\n').replace('\\r', '\r')
        cpu.input_buf = input_text.encode('ascii')
        cpu.input_pos = 0

    cpu.load_com(filename)
    cpu.run()


if __name__ == '__main__':
    main()

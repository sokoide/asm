# s101_movem.s - MOVEM.L Multi-Register Save/Restore (m68k-specific)
# Learning objectives:
# - MOVEM.L: save/restore multiple registers with ONE instruction
# - Code size comparison vs individual MOVE.L pushes (see below)
# - Typical subroutine prologue/epilogue pattern
# - MOVEM.L (%sp)+ pop restores registers regardless of list order
# (push uses descending, pop ascending register numbers automatically)
#
# Task:
# - A subroutine that clobbers D0-D3 and A0-A1, using MOVEM.L at entry/exit
# - Verify caller's registers survive the call
#
# ---- Code size comparison: MOVEM vs individual MOVE.L ----
# Basis: MC68000 User's Manual instruction encoding/timing table
# (MOVEM.L list,-(A7) = 2 words = 4 bytes, 8+8n cycles;
# MOVE.L Dn,-(A7) = 1 word = 2 bytes, 8 cycles each).
#
# Saving 8 registers (D0-D7):
# MOVEM.L D0-D7,-(A7)   : 1 instruction, 4 bytes, 8+8*8 = 72 cycles
# MOVE.L Dn,-(A7) x 8   : 8 instructions, 16 bytes, 8*8 = 64 cycles
# Saving 6 registers (D0-D3/A0-A1, as used in this scenario):
# MOVEM.L D0-D3/A0-A1   : 4 bytes, 8+8*6 = 56 cycles
# MOVE.L ... x 6        : 12 bytes, 48 cycles
#
# MOVEM costs ~8 extra cycles per call, but wins decisively on code size
# (4 bytes total vs 2 bytes per register) and instruction fetch bandwidth.
# This is why compiler-generated m68k code uses MOVEM for large register
# sets and MOVE.L only for 1-2 registers.

.text
.global _start

_start:
	move.l  #0x4000, %sp

	lea     msg_before, %a0
	bsr     print_str

    # Set distinctive values in the registers the callee will clobber
	move.l  #0x11111111, %d0
	move.l  #0x22222222, %d1
	move.l  #0x33333333, %d2
	move.l  #0x44444444, %d3
	move.l  #0xAAAA0000, %a1

	bsr     work

    # Verify all registers were restored (print_str/print_hex32 preserve them)
	lea     msg_after, %a0
	bsr     print_str

	lea     msg_d0, %a0
	bsr     print_str
    # D0 as-is
	bsr     print_hex32
	bsr     print_crlf

	lea     msg_d1, %a0
	bsr     print_str
	move.l  %d1, %d0
	bsr     print_hex32
	bsr     print_crlf

	lea     msg_d2, %a0
	bsr     print_str
	move.l  %d2, %d0
	bsr     print_hex32
	bsr     print_crlf

	lea     msg_d3, %a0
	bsr     print_str
	move.l  %d3, %d0
	bsr     print_hex32
	bsr     print_crlf

	lea     msg_a1, %a0
	bsr     print_str
	move.l  %a1, %d0
	bsr     print_hex32
	bsr     print_crlf

	lea     msg_ok, %a0
	bsr     print_str

halt:   bra     halt

# ---- Subroutines ----

# work: clobbers D0-D3 and A0-A1, restores them on exit via MOVEM
work:
    # 1 instruction saves 6 registers (24 bytes on the stack)
	movem.l %d0-%d3/%a0-%a1, -(%sp)
	move.l  #0, %d0
	move.l  #0, %d1
	move.l  #0, %d2
	move.l  #0, %d3
	move.l  #0, %a1
	lea     msg_working, %a0
	bsr     print_str
    # 1 instruction restores 6 registers
	movem.l (%sp)+, %d0-%d3/%a0-%a1
	rts

print_str:
	movem.l %d0/%a0, -(%sp)
.Lps_loop:
	move.b  (%a0)+, %d0
	tst.b   %d0
	beq     .Lps_done
	bsr     putchar
	bra     .Lps_loop
.Lps_done:
	movem.l (%sp)+, %d0/%a0
	rts

print_hex32:
	movem.l %d0-%d2, -(%sp)
	move.l  %d0, %d1
	moveq   #28, %d2
.Lph_loop:
	move.l  %d1, %d0
	lsr.l   %d2, %d0
	and.l   #0xf, %d0
	cmpi.b  #9, %d0
	ble     .Lph_digit
	addq.b  #7, %d0
.Lph_digit:
	addi.b  #'0', %d0
	bsr     putchar
	subq.l  #4, %d2
	bpl     .Lph_loop
	movem.l (%sp)+, %d0-%d2
	rts

print_crlf:
	movem.l %d0, -(%sp)
	move.l  #0x0d, %d0; bsr putchar
	move.l  #0x0a, %d0; bsr putchar
	movem.l (%sp)+, %d0
	rts

putchar:
	move.l  %d0, 0xff008000
	rts

# ---- Data ----
msg_before:  .asciz "Calling work (clobbers D0-D3/A0-A1)\n"
msg_working: .asciz "  work: registers zeroed, then MOVEM restore\n"
msg_after:   .asciz "After return:\n"
msg_d0:      .asciz "  D0 = 0x"
msg_d1:      .asciz "  D1 = 0x"
msg_d2:      .asciz "  D2 = 0x"
msg_d3:      .asciz "  D3 = 0x"
msg_a1:      .asciz "  A1 = 0x"
msg_ok:      .asciz "MOVEM OK!\n"

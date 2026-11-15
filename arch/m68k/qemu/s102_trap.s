# s102_trap.s - TRAP #0 Software Exception (m68k-specific)
# Learning objectives:
# - TRAP #n: software exception -> exception vector 32+n
# - Exception vector table: vector 32 (TRAP #0) lives at address 0x80
# - Exception stack frame: PC and SR are pushed on the supervisor stack
# - RTE: exception return (pops the frame, restores PC and SR)
# - Supervisor mode (SR S-bit): TRAP always switches to supervisor state,
# which is why OS services on classic m68k systems are TRAP-based
#
# Task:
# - Register a handler for vector 32 (= TRAP #0) at address 0x80
# - Execute TRAP #0; the handler dumps the exception stack frame contents
# and returns via RTE
#
# Exception stack frame (68000, group 1 exception such as TRAP):
#
# SSP+0: SR   (status register at exception time)
# SSP+2: PC   (return address: instruction after TRAP #0)
#
# The pushed SR has the S-bit (bit 13, 0x2000) set: exception processing
# always switches to supervisor state. On the 68010 and later the frame
# grows by a format/vector word; QEMU's -cpu m68000 pushes the plain
# 68000-style frame (verified with the values printed by this scenario).
#
# Supervisor mode notes:
# - SR is writable only in supervisor state; TRAP is the standard way for
# user code to enter it (this is how GEMDOS/TOS/AmigaDOS system calls work)
# - QEMU starts -kernel programs in supervisor state with interrupts masked
# (SR = 0x2700 base; the CCR low byte reflects the last executed
# instruction), so this scenario runs entirely in supervisor state
# - `make trace S=s102_trap` shows the exception entry in QEMU's trace log
# (look for the PC jump to the handler and the stack pointer change)

.text
.global _start

_start:
	move.l  #0x4000, %sp

	lea     msg_title, %a0
	bsr     print_str

    # --- Register TRAP #0 handler: vector 32 at address 32*4 = 0x80 ---
	lea     trap0_handler, %a0
	move.l  %a0, 0x80

	lea     msg_before, %a0
	bsr     print_str

    # -> vector 32 (0x80), frame pushed on SSP
	trap    #0

	lea     msg_after, %a0
	bsr     print_str

halt:   bra     halt

# ---- TRAP #0 handler ----
# Entry stack frame at (%sp): SR (word at +0), PC (longword at +2).
# The handler dumps the frame, then RTE pops it to resume.
trap0_handler:
    # save everything we touch; the frame moves up by 24 bytes
	movem.l %d0-%d3/%a0-%a1, -(%sp)

	lea     msg_enter, %a0
	bsr     print_str

	lea     msg_sr, %a0
	bsr     print_str
    # SR pushed by the exception (word at frame +0)
	clr.l   %d0
	move.w  24(%sp), %d0
	bsr     print_hex16
	bsr     print_crlf

	lea     msg_sbit, %a0
	bsr     print_str

	lea     msg_pc, %a0
	bsr     print_str
    # PC pushed by the exception (longword at frame +2)
	move.l  26(%sp), %d0
	bsr     print_hex32
	bsr     print_crlf

	movem.l (%sp)+, %d0-%d3/%a0-%a1
    # pop SR and PC -> resume after TRAP #0
	rte

# ---- Subroutines ----

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

print_hex16:
    # low word of D0 in 4 hex digits
	movem.l %d0-%d2, -(%sp)
	move.l  %d0, %d1
	moveq   #12, %d2
.Lphw_loop:
	move.l  %d1, %d0
	lsr.l   %d2, %d0
	and.l   #0xf, %d0
	cmpi.b  #9, %d0
	ble     .Lphw_digit
	addq.b  #7, %d0
.Lphw_digit:
	addi.b  #'0', %d0
	bsr     putchar
	subq.l  #4, %d2
	bpl     .Lphw_loop
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
msg_title:  .asciz "TRAP #0 exception demo\n"
msg_before: .asciz "Before TRAP #0\n"
msg_enter:  .asciz "  [trap0 handler]\n"
msg_sr:     .asciz "  SR = 0x"
msg_sbit:   .asciz "  (S bit = 0x2000: supervisor state)\n"
msg_pc:     .asciz "  PC = 0x"
msg_after:  .asciz "Back after RTE\n"

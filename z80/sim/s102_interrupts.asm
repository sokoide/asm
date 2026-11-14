; s102_interrupts.asm - Scenario 102: Interrupts (IM 0 / IM 1 / IM 2)
; ====================================================================
; The Z80 supports three interrupt modes. This scenario demonstrates
; all of them on simz80, which injects an INT request when the program
; writes to I/O port 0x10 (OUT (0x10),A):
;
;   OUT (0x10),A  ->  INT line asserted, A latched as the vector byte
;
; The interrupt is accepted at the next instruction boundary when IFF1
; is set (after EI). Each mode dispatches differently:
;
;   IM 0  device supplies an opcode on the data bus - here fixed
;         RST 10h -> handler at 0x0010 (13 T-states response)
;   IM 1  fixed RST 38h -> handler at 0x0038 (13 T-states response)
;   IM 2  vectored: table address = (I << 8) | vector byte, handler
;         address read from the table (19 T-states response)
;
; On acceptance the CPU pushes the return PC and clears IFF1/IFF2, so
; each handler ends with RETI: RETI restores IFF1 from IFF2 like RETN,
; but also signals "interrupt finished" to external daisy-chain devices.
; Maskable-interrupt (INT) handlers conventionally return with RETI;
; RETN is for NMI return. simz80 has no daisy chain so both behave the
; same here - the point of the scenario is choosing the right instruction.
; The main
; code executes EI before raising the next interrupt.
;
; Page zero notes (simz80 = CP/M layout):
;   - 0x0000 warm boot jump, 0x0005 BDOS entry - both untouched.
;   - 0x0010 and 0x0038 are unused RAM in this simulator, so the
;     handlers are patched there at runtime with JP instructions.
;     (Real CP/M also leaves 0x0038 alone; RST 10h is free in the TPA.)
;
; The handlers call the BDOS print routine directly. This works in
; simz80 because BDOS is a host-call trap at PC=0x0005 (not real
; re-entrant OS code) - on real CP/M, calling BDOS from an ISR is not
; safe and handlers would set a flag instead.
;
; Observe with the debugger: make debug S=s102_interrupts
;   - the INT acceptance prints its own line, e.g.
;       0109  INT (IM 2): vector 8080 -> handler 013F
;   - the register diff shows IFF1 1 -> 0  IFF2 1 -> 0 at acceptance,
;     and SP drops by 2 (return PC pushed)
;   - make cycles S=s102_interrupts includes the response T-states
;     (13 + 13 + 19 = 45 T for the three demos) in the total.

	org 0x0100

INT_PORT:	equ	0x10		; OUT here = INT request (simz80 model)

_start:
	; ---- Title ----
	ld	hl, msg_title
	call	print_str
	call	newline

	; ============================================================
	; Demo 1: IM 2 - vectored interrupt via the I register
	; ============================================================
	ld	hl, msg_im2
	call	print_str
	call	newline

	; Build the vector table: I = 0x80, vector byte 0x80
	;   -> table address 0x8080 holds the handler address
	ld	a, 0x80
	ld	i, a			; I = 0x80
	ld	hl, isr_im2
	ld	(0x8080), hl		; table[0x80] = handler address

	im	2			; IM 00 -> 02 (visible in debug diffs)
	ei			; IFF1/IFF2 -> 1
	ld	a, 0x80
	out	(INT_PORT), a		; INT! vector 0x80 -> 0x8080 -> handler
	; acceptance happens here: PC pushed, IFF cleared, jump to isr_im2

	; back from the handler - execution continues here
	ld	hl, msg_back
	call	print_str
	call	newline

	; ============================================================
	; Demo 2: IM 1 - fixed RST 38h handler at 0x0038
	; ============================================================
	ld	hl, msg_im1
	call	print_str
	call	newline

	; Patch page zero: JP isr_im1 at 0x0038 (C3 = JP opcode).
	; CP/M uses 0x0000 (warm boot) and 0x0005 (BDOS); 0x0038 is free
	; RAM in this simulator, so no save/restore is needed.
	ld	a, 0xC3
	ld	(0x0038), a
	ld	hl, isr_im1
	ld	(0x0039), hl		; JP target (little-endian word)

	im	1			; IM 02 -> 01
	ei			; RETI cleared IFF1, re-enable
	ld	a, 0x38
	out	(INT_PORT), a		; INT! -> RST 38h -> 0x0038

	ld	hl, msg_back
	call	print_str
	call	newline

	; ============================================================
	; Demo 3: IM 0 - device supplies RST 10h on the data bus
	; ============================================================
	ld	hl, msg_im0
	call	print_str
	call	newline

	; Patch page zero: JP isr_im0 at 0x0010 (the RST 10h target)
	ld	a, 0xC3
	ld	(0x0010), a
	ld	hl, isr_im0
	ld	(0x0011), hl

	im	0			; IM 01 -> 00
	ei
	ld	a, 0x10
	out	(INT_PORT), a		; INT! -> device sends RST 10h -> 0x0010

	ld	hl, msg_back
	call	print_str
	call	newline

	ret			; back to CP/M (PC=0x0000 trap -> exit)

; ================================================================
; Interrupt service routines
; Entered with IFF1/IFF2 cleared by the CPU (no nested INTs).
; simz80 lets ISRs call the BDOS print trap safely; each ISR saves
; the registers it clobbers and returns with RETI.
; ================================================================

isr_im2:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl, msg_isr2
	call	print_str
	call	newline
	pop	hl
	pop	de
	pop	bc
	pop	af
	reti			; IFF1 <- IFF2, PC <- stack (daisy-chain EOI)

isr_im1:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl, msg_isr1
	call	print_str
	call	newline
	pop	hl
	pop	de
	pop	bc
	pop	af
	reti

isr_im0:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl, msg_isr0
	call	print_str
	call	newline
	pop	hl
	pop	de
	pop	bc
	pop	af
	reti

; ================================================================
; Common subroutines
; ================================================================

print_str:
	push	af
	push	bc
	push	de
.ps_loop:
	ld	a, (hl)
	cp	'$'
	jr	z, .ps_done
	ld	c, 2
	push	hl
	ld	e, a
	call	0x0005
	pop	hl
	inc	hl
	jr	.ps_loop
.ps_done:
	pop	de
	pop	bc
	pop	af
	ret

newline:
	push	af
	push	bc
	push	de
	ld	c, 2
	ld	e, 13
	call	0x0005
	ld	c, 2
	ld	e, 10
	call	0x0005
	pop	de
	pop	bc
	pop	af
	ret

; ================================================================
; Data section
; ================================================================

; IM 2 vector table (I=0x80, vector byte 0x80 -> address 0x8080)
; The handler word is stored at runtime before enabling interrupts.
vect_table:	equ	0x8080

; Messages
msg_title:	defm	"--- s102: Interrupts (IM 0/1/2) ---$"
msg_im2:	defm	"--- Demo 1: IM 2 (vectored, I=0x80 vec=0x80) ---$"
msg_im1:	defm	"--- Demo 2: IM 1 (fixed RST 38h) ---$"
msg_im0:	defm	"--- Demo 3: IM 0 (device sends RST 10h) ---$"
msg_isr2:	defm	"  [IM2 ISR] vectored handler entered$"
msg_isr1:	defm	"  [IM1 ISR] RST 38h handler entered$"
msg_isr0:	defm	"  [IM0 ISR] RST 10h handler entered$"
msg_back:	defm	"  returned to main, execution continues$"

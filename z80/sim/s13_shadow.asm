; s13_shadow.asm - Scenario 13: Shadow Registers (Alternate Register Set)
; ================================================================
; The Z80 has two complete sets of registers: main and alternate (shadow):
;
;   Main:    A  F  B  C  D  E  H  L
;   Shadow:  A' F' B' C' D' E' H' L'
;
; Two instructions swap between sets instantly:
;   EXX         -> BC<->BC', DE<->DE', HL<->HL' (all three pairs at once)
;   EX AF,AF'   -> AF<->AF'
;
; Typical use cases:
;   - Interrupt Service Routine (ISR) fast context save
;     (saves/restores all registers in just 2 instructions, no stack needed)
;   - Switching between two computation contexts
;   - Saving temporary values without using the stack
;
; Note: IX/IY and SP have no shadow registers.
; ================================================================

	org 0x0100

_start:
	; ---- Title ----
	ld	hl, msg_title
	call	print_str
	call	newline

	; ============================================================
	; Step 1: Set values in main registers and display
	; ============================================================
	ld	hl, msg_step1
	call	print_str
	call	newline

	ld	bc, 0x1234		; BC = 0x1234
	ld	de, 0x5678		; DE = 0x5678
	ld	hl, 0x9ABC		; HL = 0x9ABC
	ld	a, 0x42		; A  = 0x42
	call	save_regs		; save to memory

	ld	hl, msg_main
	call	show_regs		; display saved values

	; ============================================================
	; Step 2: EXX + EX AF,AF' to switch to shadow set
	; ============================================================
	; Reload from memory before swap (display changed HL)
	ld	hl, msg_exx
	call	print_str
	call	newline

	call	load_regs		; restore from memory: 1234/5678/9ABC/42

	exx			; BC<->BC', DE<->DE', HL<->HL'
	ex	af, af'		; AF<->AF'
	; -> shadow now holds 1234/5678/9ABC/42
	; -> main now shows shadow's initial values (zero)

	; Set new values in the registers now visible as "main"
	ld	bc, 0xABCD
	ld	de, 0xEF01
	ld	hl, 0x2345
	ld	a, 0x99
	call	save_regs

	ld	hl, msg_shadow
	call	show_regs

	; ============================================================
	; Step 3: Swap again to restore main values
	; ============================================================
	ld	hl, msg_back
	call	print_str
	call	newline

	call	load_regs		; restore from memory: ABCD/EF01/2345/99

	exx			; shadow <- ABCD/EF01/2345/99
	ex	af, af'
	; -> main now has 1234/5678/9ABC/42 restored!

	call	save_regs
	ld	hl, msg_restored
	call	show_regs

	; ============================================================
	; Step 4: ISR-style context save/restore pattern
	; ============================================================
	ld	hl, msg_step4
	call	print_str
	call	newline

	; Set "main program" values
	ld	bc, 0xAAAA
	ld	de, 0xBBBB
	ld	hl, 0xCCCC
	ld	a, 0xDD
	call	save_regs

	ld	hl, msg_pre_isr
	call	show_regs

	; --- ISR entry: save all registers in 2 instructions! (no stack) ---
	call	load_regs		; reload AAAA/BBBB/CCCC/DD

	exx			; BC/DE/HL -> shadow
	ex	af, af'		; AF -> shadow

	; ISR body: freely use registers
	ld	bc, 0x1111
	ld	de, 0x2222
	ld	hl, 0x3333
	ld	a, 0x44
	call	save_regs

	ld	hl, msg_in_isr
	call	show_regs

	; --- ISR exit: restore all registers in 2 instructions! ---
	call	load_regs		; reload 1111/2222/3333/44

	exx			; BC/DE/HL <- restored from shadow
	ex	af, af'		; AF <- restored from shadow
	; -> AAAA/BBBB/CCCC/DD restored!

	call	save_regs
	ld	hl, msg_post_isr
	call	show_regs

	ret

; ================================================================
; save_regs: save BC, DE, HL, A to memory
; ================================================================
save_regs:
	ld	(save_bc), bc
	ld	(save_de), de
	ld	(save_hl), hl
	ld	(save_a), a
	ret

; ================================================================
; load_regs: restore BC, DE, HL, A from memory
; ================================================================
load_regs:
	ld	bc, (save_bc)
	ld	de, (save_de)
	ld	hl, (save_hl)
	ld	a, (save_a)
	ret

; ================================================================
; show_regs: display memory-saved values with a label
;   Input: HL = label message address
; ================================================================
show_regs:
	call	print_str

	; Display BC
	ld	hl, msg_bc
	call	print_str
	ld	a, (save_bc+1)		; B (Z80 is little-endian)
	call	print_hex8
	ld	a, (save_bc)		; C
	call	print_hex8
	call	newline

	; Display DE
	ld	hl, msg_de
	call	print_str
	ld	a, (save_de+1)		; D
	call	print_hex8
	ld	a, (save_de)		; E
	call	print_hex8
	call	newline

	; Display HL
	ld	hl, msg_hl
	call	print_str
	ld	a, (save_hl+1)		; H
	call	print_hex8
	ld	a, (save_hl)		; L
	call	print_hex8
	call	newline

	; Display A
	ld	hl, msg_a
	call	print_str
	ld	a, (save_a)
	call	print_hex8
	call	newline

	call	newline
	ret

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

print_hex8:
	push	bc
	ld	b, a
	; high nibble
	rrca
	rrca
	rrca
	rrca
	call	hex_nibble
	ld	c, 2
	ld	e, a
	call	0x0005
	; low nibble
	ld	a, b
	call	hex_nibble
	ld	c, 2
	ld	e, a
	call	0x0005
	pop	bc
	ret

hex_nibble:
	and	0x0F
	cp	10
	jr	c, .hn_dec
	add	'A' - 10
	ret
.hn_dec:
	add	'0'
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

; Register save area (little-endian: low byte, high byte)
save_bc:	defw	0
save_de:	defw	0
save_hl:	defw	0
save_a:		defb	0

; Messages
msg_title:	defm	"=== s13: Shadow Registers ===$"
msg_step1:	defm	"--- Step 1: Set main registers ---$"
msg_main:	defm	"Main:     $"
msg_exx:	defm	"--- Step 2: EXX + EX AF,AF' ---$"
msg_shadow:	defm	"Shadow:   $"
msg_back:	defm	"--- Step 3: Swap back to main ---$"
msg_restored:	defm	"Restored: $"
msg_step4:	defm	"--- Step 4: ISR context save/restore ---$"
msg_pre_isr:	defm	"Pre-ISR:  $"
msg_in_isr:	defm	"In ISR:   $"
msg_post_isr:	defm	"Post-ISR: $"

msg_bc:		defm	"  BC=$"
msg_de:		defm	"  DE=$"
msg_hl:		defm	"  HL=$"
msg_a:		defm	"  A=$"

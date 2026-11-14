; s13_copybench.asm - Scenario 13: Copy Bench (100-byte memory copy)
; ==================================================================
; Common benchmark scenario (same spec on every architecture):
;   - Copy 100 bytes (byte i = i) from src to dst with a hand-written
;     LDI loop. LDIR is intentionally NOT used here (it is covered in
;     s101_blockops).
;   - Verify dst against the known pattern (dst[i] must equal i) and
;     sum the 100 destination bytes into a 16-bit checksum
;   - Print exactly one line:
;       COPY OK CHECKSUM=1356      (0+1+...+99 = 4950 = 1356h)
;       COPY FAIL CHECKSUM=xxxx    (on mismatch)
;
; Copy loop timing (simz80 T-state table, exact):
;   LDI       16 T-states (DE)<-(HL), HL++, DE++, BC--;
;             P/V flag = (BC <> 0) after the decrement
;   JP PE     10 T-states when taken
;   -> 26 T-states per byte, 26 x 100 = 2600 T-states for 100 bytes
;   (LDIR would take 21 x 99 + 16 = 2095 T-states - see s101_blockops)
;
; Note: JP PE (P/V = parity even) is the correct condition after LDI.
; LDI does not modify the Z flag, so JP NZ would never work here.

	org 0x0100

_start:
	; ---- Title ----
	ld	hl, msg_title
	call	print_str
	call	newline

	; ============================================================
	; Step 1: 100-byte copy with a hand-written LDI loop
	; ============================================================
	ld	hl, src_data		; HL = source pointer
	ld	de, dst_buf		; DE = destination pointer
	ld	bc, 100			; BC = byte count
copy_loop:
	ldi				; (DE)<-(HL), HL++, DE++, BC-- (16 T)
	jp	pe, copy_loop		; P/V=1 while BC<>0 after LDI (10 T)

	; ============================================================
	; Step 2: verify dst against the pattern + 16-bit checksum
	;   The source data is defined as byte i = i, so dst[i] must
	;   equal the index in C. (No IX here: simz80 executes DD 23
	;   INC IX as INC HL - the index register must not be
	;   incremented in a loop on this simulator.)
	; ============================================================
	ld	hl, dst_buf		; HL = destination pointer
	ld	bc, 0			; C = byte index
	ld	de, 0			; DE = checksum accumulator
check_loop:
	ld	a, (hl)			; A = dst byte (7 T)
	cp	c			; dst[i] == i ? (4 T)
	jr	nz, fail
	or	a			; clear carry, A unchanged (4 T)
	add	a, e			; add low byte of checksum (4 T)
	ld	e, a
	ld	a, d
	adc	a, 0			; propagate carry to high byte
	ld	d, a
	inc	hl
	inc	c
	ld	a, c
	cp	100			; index reached 100 ?
	jr	nz, check_loop

	ld	hl, msg_ok
	call	print_str
	jr	print_checksum
fail:
	ld	hl, msg_fail
	call	print_str
print_checksum:
	push	de			; print_hex8 clobbers E (BDOS char out)
	ld	a, d			; high byte -> "13"
	call	print_hex8
	pop	de
	ld	a, e			; low byte  -> "56"
	call	print_hex8
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

src_data:	defb	 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
		defb	10,11,12,13,14,15,16,17,18,19
		defb	20,21,22,23,24,25,26,27,28,29
		defb	30,31,32,33,34,35,36,37,38,39
		defb	40,41,42,43,44,45,46,47,48,49
		defb	50,51,52,53,54,55,56,57,58,59
		defb	60,61,62,63,64,65,66,67,68,69
		defb	70,71,72,73,74,75,76,77,78,79
		defb	80,81,82,83,84,85,86,87,88,89
		defb	90,91,92,93,94,95,96,97,98,99

dst_buf:	defs	100

; Messages
msg_title:	defm	"--- s13: Copy Bench (100-byte copy) ---$"
msg_ok:		defm	"COPY OK CHECKSUM=$"
msg_fail:	defm	"COPY FAIL CHECKSUM=$"

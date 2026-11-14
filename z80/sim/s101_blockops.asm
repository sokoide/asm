; s101_blockops.asm - Scenario 101: Block Transfer (LDIR vs LDI loop)
; ====================================================================
; The Z80 has hardware block transfer instructions. This scenario copies
; the same 100 bytes twice - once with LDIR, once with a hand-written
; LDI + JP PE loop - and prints the checksum of each result.
;
; T-state cost of copying 100 bytes (simz80 T-state table, exact):
;
;   LDIR      21 T-states per repeated byte, 16 for the last one
;             -> 21 x 99 + 16 = 2095 T-states
;   LDI loop  LDI 16 + JP PE 10 = 26 T-states per byte
;             -> 26 x 100      = 2600 T-states
;
;   LDIR replaces the 10 T-state JP with a 5 T-state repeat increment,
;   saving 5 T/byte: about 19% faster than the hand-written loop here.
;
; Verify + checksum is shared (verify_sum): checks dst[i] == i (the
; source data is defined as byte i = i) and sums the 100 destination
; bytes into a 16-bit checksum.
;   0+1+...+99 = 4950 = 1356h -> "OK CHECKSUM=1356"
;
; Note: the verify loop uses HL/BC only. (simz80 used to execute DD 23
; INC IX as INC HL through the unprefixed fallback - that bug was fixed;
; INC/DEC IX/IY now update the index registers correctly.)
;
; IM 1 / IFF observation (make debug S=s101_blockops):
;   Step through with `s` and watch the diff line when `im 1` executes:
;       IM  00 -> 01
;   Press `r` (regs): the dump prints
;       ... I=00 R=.. IM=1 IFF1=true IFF2=true
;   (after `ei`). This scenario only observes the flags; s102_interrupts
;   actually injects INT requests via OUT (0x10),A.
;
; OTIR note: simz80 decodes and counts OTIR (tstates.go, ED B3) but its
; portOut() is a no-op outside the INT line model on port 0x10 (see
; s102_interrupts) and portIn() returns 0xFF (floating bus). No port
; device is emulated, so an OTIR transfer has no observable effect -
; it is left out of this scenario on purpose.

	org 0x0100

_start:
	; ---- Title ----
	ld	hl, msg_title
	call	print_str
	call	newline

	; ============================================================
	; Method 1: LDIR (hardware block transfer)
	; ============================================================
	ld	hl, msg_ldir
	call	print_str

	ld	hl, src_data		; HL = source
	ld	de, dst_buf		; DE = destination
	ld	bc, 100			; BC = byte count
	ldir				; 21 x 99 + 16 = 2095 T-states

	call	verify_sum
	call	print_result

	; ============================================================
	; Clear dst, then Method 2: LDI + JP PE hand-written loop
	; ============================================================
	ld	hl, msg_ldi
	call	print_str

	ld	b, 100			; fill 100 bytes with 0
	ld	hl, dst_buf
	xor	a
fill_loop:
	ld	(hl), a
	inc	hl
	djnz	fill_loop

	ld	hl, src_data
	ld	de, dst_buf
	ld	bc, 100
ldi_loop:
	ldi				; 16 T
	jp	pe, ldi_loop		; 10 T -> 26 T/byte, 2600 total

	call	verify_sum
	call	print_result

	; ============================================================
	; IM 1 setting (observe IM/IFF with make debug)
	; ============================================================
	im	1			; interrupt mode 1: diff line "IM 00 -> 01"
	ei			; IFF1/IFF2 -> true (visible via `r` command)

	ret

; ================================================================
; verify_sum: check dst against the pattern (dst[i] == i), sum in DE
;   Returns: DE = 16-bit checksum, Z = 1 if all bytes matched
; ================================================================
verify_sum:
	ld	hl, dst_buf
	ld	bc, 0			; C = byte index
	ld	de, 0
.vs_loop:
	ld	a, (hl)
	cp	c			; dst[i] == i ?
	jr	nz, .vs_mismatch
	or	a			; clear carry, A unchanged
	add	a, e
	ld	e, a
	ld	a, d
	adc	a, 0
	ld	d, a
	inc	hl
	inc	c
	ld	a, c
	cp	100
	jr	nz, .vs_loop
	xor	a			; Z=1: all bytes matched
	ret
.vs_mismatch:
	or	1			; Z=0 (A|1 is never 0)
	ret

; ================================================================
; print_result: print "OK CHECKSUM=xxxx" / "FAIL CHECKSUM=xxxx"
;   Input: DE = checksum, Z flag from verify_sum
; ================================================================
print_result:
	jr	z, .pr_ok
	ld	hl, msg_fail
	jr	.pr_print
.pr_ok:
	ld	hl, msg_ok
.pr_print:
	call	print_str
	push	de			; print_hex8 clobbers E (BDOS char out)
	ld	a, d
	call	print_hex8
	pop	de
	ld	a, e
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
msg_title:	defm	"--- s101: Block Transfer (LDIR vs LDI loop) ---$"
msg_ldir:	defm	"LDIR  $"
msg_ldi:	defm	"LDI   $"
msg_ok:		defm	"OK CHECKSUM=$"
msg_fail:	defm	"FAIL CHECKSUM=$"

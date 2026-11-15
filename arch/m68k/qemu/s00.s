# s01 - scratch

.text
.global _start

_start:
	move.l  #0x4000, %sp

	move.l  #1, %d0
	move.l  #2, %d0
	move.l  #3, %d0

halt:
	bra     halt

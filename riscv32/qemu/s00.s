.section .text
.global _start

_start:
	li      sp, 0x80200000
	li      t0, 1
	li      t0, 2
	li      t0, 3
	ret


cpu 8086
bits 16
global _start

section .text
_start:
	mov     ax, 1
	mov     bx, 2
	mov     cx, 3
	ret

times 510-($-$$) db 0
dw 0xAA55

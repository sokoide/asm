; s10_bitwise.asm - Scenario 10: Bitwise Operations
; ====================================================
; Learning objectives:
;   - AND: mask / extract specific bits
;   - OR: set / combine bits
;   - XOR: toggle bits, zero a register (XOR reg, reg)
;   - NOT: invert all bits
;   - SHL / SHR: shift left/right (multiply/divide by 2)
;   - Visual binary display subroutine

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- AND: mask to extract lower nibble ---
    mov si, msg_and
    call print_str
    mov al, 0x5A            ; 0101 1010
    and al, 0x0F            ; 0000 1010 = 0x0A
    call print_bin8
    mov al, ' '
    call uart_putc
    mov al, '='
    call uart_putc
    mov al, ' '
    call uart_putc
    mov al, 0x5A
    and al, 0x0F
    call print_hex8
    call print_crlf

    ; --- OR: combine bits ---
    mov si, msg_or
    call print_str
    mov al, 0x50            ; 0101 0000
    or  al, 0x0A            ; 0101 1010 = 0x5A
    call print_hex8
    call print_crlf

    ; --- XOR: toggle bits ---
    mov si, msg_xor
    call print_str
    mov al, 0xFF            ; 1111 1111
    xor al, 0x0F            ; 1111 0000 = 0xF0
    call print_hex8
    call print_crlf

    ; --- XOR reg,reg: fastest way to zero ---
    ; xor ax, ax sets AX = 0 (smaller and faster than mov ax, 0)

    ; --- SHL: multiply by 2 ---
    mov si, msg_shl
    call print_str
    mov al, 3               ; 3 << 1 = 6
    shl al, 1
    call print_hex8
    call print_crlf

    ; --- SHR: divide by 2 ---
    mov si, msg_shr
    call print_str
    mov al, 10              ; 10 >> 1 = 5
    shr al, 1
    call print_hex8
    call print_crlf

    ; --- Visual: show 0xA5 in binary ---
    mov si, msg_vis
    call print_str
    mov al, 0xA5            ; 1010 0101
    call print_bin8
    call print_crlf

    mov si, msg_done
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

uart_putc:
    push    dx
    push    ax
    mov     dx, 0x3FD
.wait:
    in      al, dx
    test    al, 0x20
    jz      .wait
    mov     dx, 0x3F8
    pop     ax
    out     dx, al
    pop     dx
    ret

; print_bin8: display AL as 8 binary digits (MSB first)
print_bin8:
    mov cx, 8
.bit_loop:
    shl al, 1               ; Shift highest bit into carry flag
    push ax                  ; Save shifted value
    mov al, '0'
    jnc .zero
    mov al, '1'
.zero:
    call uart_putc
    pop ax
    loop .bit_loop
    ret

print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

print_hex8:
    push ax
    mov cl, 4
    shr al, cl
    call print_nibble
    pop ax
print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    call uart_putc
    ret

print_crlf:
    push ax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop ax
    ret

; ---- Data ----
msg_and  db "AND 0x5A, 0x0F: ", 0
msg_or   db "OR  0x50, 0x0A: 0x", 0
msg_xor  db "XOR 0xFF, 0x0F: 0x", 0
msg_shl  db "SHL 3, 1:       0x", 0
msg_shr  db "SHR 10, 1:      0x", 0
msg_vis  db "0xA5 binary: ", 0
msg_done db 13, 10, "Bitwise done!", 0

times 510-($-$$) db 0
dw 0xAA55

; s10_bitwise.asm - Scenario 10: Bitwise Operations
; ===================================================
; Learning objectives:
;   - AND: mask (extract specific bits)
;   - OR: set bits (combine flags)
;   - XOR: toggle bits, zero a register (XOR reg, reg)
;   - NOT: invert all bits
;   - SHL: shift left = multiply by 2
;   - SHR: shift right = divide by 2
;   - Binary display subroutine
; Difficulty: ★★★★☆

segment .text
global start

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax

    ; --- AND: extract low nibble ---
    mov si, msg_and
    call print_str
    mov al, 0ABh
    call print_bin8
    mov al, ' '
    call print_char
    mov si, msg_and2
    call print_str
    mov al, 0ABh
    and al, 0Fh             ; mask: keep low 4 bits
    call print_bin8
    call print_crlf

    ; --- OR: combine flags ---
    mov si, msg_or
    call print_str
    mov al, 0F0h
    call print_bin8
    mov al, ' '
    call print_char
    mov si, msg_or2
    call print_str
    mov al, 0F0h
    or  al, 0Ah             ; set bits: F0 | 0A = FA
    call print_bin8
    call print_crlf

    ; --- XOR: toggle bits ---
    mov si, msg_xor
    call print_str
    mov al, 0FFh
    call print_bin8
    mov al, ' '
    call print_char
    mov si, msg_xor2
    call print_str
    mov al, 0FFh
    xor al, 55h             ; toggle: FF ^ 55 = AA
    call print_bin8
    call print_crlf

    ; --- SHL: multiply by 2 ---
    mov si, msg_shl
    call print_str
    mov al, 7               ; 7
    call print_hex8
    mov al, ' '
    call print_char
    mov al, 7
    shl al, 1               ; 7 << 1 = 14
    call print_hex8
    mov al, ' '
    call print_char
    mov al, 14
    shl al, 1               ; 14 << 1 = 28
    call print_hex8
    call print_crlf

    ; --- SHR: divide by 2 ---
    mov si, msg_shr
    call print_str
    mov al, 100             ; 100
    call print_hex8
    mov al, ' '
    call print_char
    mov al, 100
    shr al, 1               ; 100 >> 1 = 50
    call print_hex8
    mov al, ' '
    call print_char
    mov al, 50
    shr al, 1               ; 50 >> 1 = 25
    call print_hex8
    call print_crlf

    ; --- Binary display demo ---
    mov si, msg_bindemo
    call print_str
    mov al, 0A5h
    call print_bin8
    call print_crlf

    mov si, msg_done
    call print_str

    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

; print_bin8: print AL as 8 binary digits
print_bin8:
    push cx
    push ax
    mov cx, 8
.bit_loop:
    shl al, 1               ; shift MSB into carry flag
    push ax
    jc  .one
    mov dl, '0'
    jmp .print_bit
.one:
    mov dl, '1'
.print_bit:
    mov ah, 02h
    int 21h
    pop ax
    loop .bit_loop
    pop ax
    pop cx
    ret

print_str:
    lodsb
    or  al, al
    jz  .done
    mov dl, al
    mov ah, 02h
    int 21h
    jmp print_str
.done:
    ret

print_char:
    mov dl, al
    mov ah, 02h
    int 21h
    ret

print_hex8:
    push ax
    mov cl, 4
    shr al, cl
    call print_nibble
    pop ax
print_nibble:
    and al, 0Fh
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    mov dl, al
    mov ah, 02h
    int 21h
    ret

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

msg1:       db "Bitwise ops:", 13, 10, 0
msg_and:    db "  AND: ", 0
msg_and2:   db "& 0Fh = ", 0
msg_or:     db "  OR:  ", 0
msg_or2:    db "| 0Ah = ", 0
msg_xor:    db "  XOR: ", 0
msg_xor2:   db "^ 55h = ", 0
msg_shl:    db "  SHL: 7 -> 14 -> 28 = ", 0
msg_shr:    db "  SHR: 100 -> 50 -> 25 = ", 0
msg_bindemo db "  Bin: 0xA5 = ", 0
msg_done    db "Done!", 13, 10, 0

segment .stack stack
    resb 100h

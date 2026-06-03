; s03_stack.asm - Scenario 3: Stack Operations
; ==============================================
; Learning objectives:
;   - PUSH / POP instructions
;   - LIFO (Last In, First Out) behavior
;   - Stack pointer (SP) auto-adjustment
;   - Save/restore register pattern

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Stack starts at 0x7C00, grows down

    ; --- PUSH: SP decreases by 2, value stored at [SS:SP] ---
    ; --- POP:  value loaded from [SS:SP], SP increases by 2 ---

    push 0x1234             ; SP: 0x7C00 -> 0x7BFE, [0x7BFE] = 0x1234
    push 0x5678             ; SP: 0x7BFE -> 0x7BFC, [0x7BFC] = 0x5678

    ; POP in reverse order (LIFO)
    pop bx                  ; BX = 0x5678 (last pushed = first popped)
    pop ax                  ; AX = 0x1234
    push ax                 ; Save on stack for later

    ; Display first POP result
    mov si, msg1
    call print_str
    mov ax, bx              ; 0x5678
    call print_hex16
    call print_crlf

    ; Display second POP result
    mov si, msg2
    call print_str
    pop ax                  ; 0x1234 (restored from stack)
    call print_hex16
    call print_crlf

    ; --- Save/restore pattern ---
    mov ax, 42              ; AX = 42
    push ax                 ; Save AX on stack
    mov ax, 99              ; AX now = 99 (clobbered)
    ; ... do other work ...
    pop ax                  ; AX restored = 42

    push ax                 ; Save before print
    mov si, msg3
    call print_str
    pop ax                  ; 42
    call print_hex16
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

print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

print_hex16:
    push ax
    mov al, ah
    call print_hex8
    pop ax
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
msg1     db "1st POP = 0x", 0
msg2     db "2nd POP = 0x", 0
msg3     db "Saved/restored AX = 0x", 0
msg_done db 13, 10, "Stack demo done!", 0

times 510-($-$$) db 0
dw 0xAA55

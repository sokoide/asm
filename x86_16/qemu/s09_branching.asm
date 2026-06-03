; s09_branching.asm - Scenario 9: Conditional Branching
; ======================================================
; Learning objectives:
;   - CMP: compare two values (sets flags without modifying operands)
;   - Conditional jumps: JE/JNE (equal), JL/JG (signed), JB/JA (unsigned)
;   - Building decision trees with branch instructions
;   - Signed vs unsigned comparison semantics

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Test 1: JE / JNE (equal / not-equal) ---
    mov si, msg_eq
    call print_str
    mov ax, 42
    mov bx, 42
    cmp ax, bx
    je  .yes1
    mov si, msg_no
    call print_str
    jmp .next1
.yes1:
    mov si, msg_yes
    call print_str
.next1:

    ; --- Test 2: JL (signed less than) ---
    mov si, msg_slt
    call print_str
    mov ax, -5
    mov bx, 10
    cmp ax, bx
    jl  .yes2
    mov si, msg_no
    call print_str
    jmp .next2
.yes2:
    mov si, msg_yes
    call print_str
.next2:

    ; --- Test 3: JG (signed greater than) ---
    mov si, msg_sgt
    call print_str
    mov ax, 30
    mov bx, 10
    cmp ax, bx
    jg  .yes3
    mov si, msg_no
    call print_str
    jmp .next3
.yes3:
    mov si, msg_yes
    call print_str
.next3:

    ; --- Test 4: If-else chain ---
    mov si, msg_ife
    call print_str
    mov ax, 50
    cmp ax, 10
    jl  .small
    cmp ax, 100
    jg  .big
    mov si, msg_mid
    call print_str
    jmp .done4
.small:
    mov si, msg_small
    call print_str
    jmp .done4
.big:
    mov si, msg_big
    call print_str
.done4:

    mov si, msg_dn
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

print_crlf:
    push ax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop ax
    ret

; ---- Data ----
msg_eq:    db "42 == 42? ", 0
msg_slt:   db "-5 < 10?  ", 0
msg_sgt:   db "30 > 10?  ", 0
msg_ife:   db "50: ", 0
msg_small: db "small (<10)", 13, 10, 0
msg_mid:   db "mid (10..100)", 13, 10, 0
msg_big:   db "big (>100)", 13, 10, 0
msg_yes:   db "Yes!", 13, 10, 0
msg_no:    db "No!", 13, 10, 0
msg_dn:    db "Done!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

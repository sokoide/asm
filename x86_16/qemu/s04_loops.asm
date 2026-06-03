; s04_loops.asm - Scenario 4: Loops and Counters
; ================================================
; Learning objectives:
;   - LOOP instruction (auto-decrements CX, jumps if CX != 0)
;   - CMP instruction and condition flags
;   - Conditional jumps: JE, JNE, JL, JG, JLE, JGE
;   - Count-up and countdown patterns

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Demo 1: LOOP countdown (5 to 1) ---
    ; LOOP decrements CX and jumps if CX != 0
    mov si, msg1
    call print_str

    mov cx, 5
.loop1:
    mov al, cl
    add al, '0'            ; Convert number to ASCII digit
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    mov al, ' '
    int 0x10
    loop .loop1             ; CX--; if CX != 0, jump

    call print_crlf

    ; --- Demo 2: Count-up with CMP + JLE ---
    mov si, msg2
    call print_str

    mov cl, 1
.loop2:
    mov al, cl
    add al, '0'
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    mov al, ' '
    int 0x10
    inc cl
    cmp cl, 6              ; Stop after printing 5
    jle .loop2             ; Jump if CL <= 5

    call print_crlf

    ; --- Demo 3: Even/odd with TEST ---
    ; TEST does AND but only sets flags (doesn't store result)
    mov si, msg3
    call print_str

    mov al, 7
    test al, 1             ; Test bit 0 (odd/even)
    jz  .even
    mov si, msg_odd
    call print_str
    jmp .done3
.even:
    mov si, msg_even
    call print_str
.done3:
    call print_crlf

    mov si, msg_done
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----
print_str:
    lodsb
    or  al, al
    jz  .ret
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp print_str
.ret:
    ret

print_crlf:
    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ---- Data ----
msg1    db "LOOP  5..1: ", 0
msg2    db "Count 1..5: ", 0
msg3    db "7 is ", 0
msg_odd db "odd", 0
msg_even db "even", 0
msg_done db 13, 10, "Loops done!", 0

times 510-($-$$) db 0
dw 0xAA55

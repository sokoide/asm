; s02_registers.asm - Scenario 2: Registers and Arithmetic
; =========================================================
; Learning objectives:
;   - General-purpose registers: AX, BX, CX, DX
;   - High/low byte access: AH/AL, BH/BL, etc.
;   - MOV, ADD, SUB, INC, DEC instructions
;   - Hex display subroutine (print_hex16)
;   - BIOS INT 0x10 for character output

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- MOV: move data between registers ---
    mov ax, 0x1234          ; AX = 0x1234
    mov bx, ax              ; BX = AX (copy)
    mov cx, 0x00FF          ; CX = 0x00FF

    ; --- High/low byte access ---
    mov dx, 0xABCD          ; DH = 0xAB, DL = 0xCD

    ; --- ADD, SUB ---
    mov ax, 10              ; AX = 10
    mov bx, 20              ; BX = 20
    add ax, bx              ; AX = 30 (0x001E)
    mov cx, ax              ; CX = 30
    sub cx, 5               ; CX = 25 (0x0019)
    inc cx                  ; CX = 26 (0x001A)
    dec cx                  ; CX = 25 again

    ; --- Display results ---
    mov si, msg1
    call print_str
    mov ax, 0x1234
    call print_hex16
    call print_crlf

    mov si, msg2
    call print_str
    mov ax, 30
    call print_hex16
    call print_crlf

    mov si, msg3
    call print_str
    mov ax, 25
    call print_hex16
    call print_crlf

    mov si, msg_done
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

; print_str: null-terminated string at DS:SI
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

; print_hex16: print AX as 4 hex digits
print_hex16:
    push ax
    mov al, ah              ; High byte first
    call print_hex8
    pop ax                  ; Then low byte
print_hex8:
    push ax
    mov cl, 4
    shr al, cl             ; High nibble
    call print_nibble
    pop ax                 ; Low nibble
print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7               ; 'A' - '9' - 1
.out:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret

print_crlf:
    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ---- Data ----
msg1    db "mov ax, 0x1234 -> AX=", 0
msg2    db "10 + 20      = 0x", 0
msg3    db "30 - 5       = 0x", 0
msg_done db 13, 10, "Done!", 0

times 510-($-$$) db 0
dw 0xAA55

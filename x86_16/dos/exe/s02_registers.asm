; s02_registers.asm - Scenario 2: Registers and Arithmetic
; =========================================================
; Learning objectives:
;   - General-purpose registers: AX, BX, CX, DX
;   - High/low byte access: AH/AL, BH/BL, CH/CL, DH/DL
;   - MOV, ADD, SUB, INC, DEC instructions
;   - Hex display subroutine (print_hex16)
;   - Null-terminated strings + LODSB-based print_str
;   - DOS INT 21h AH=02h (single character output)
; Difficulty: ★☆☆☆☆

segment .text
global start

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax              ; ES = DS for string operations

    ; --- MOV: copy data between registers ---
    mov ax, 1234h           ; AX = 0x1234
    mov bx, ax              ; BX = AX (copy)
    mov cx, 00FFh           ; CX = 0x00FF

    ; --- High/low byte access ---
    mov dx, 0ABCDh          ; DH = 0xAB, DL = 0xCD

    ; --- ADD, SUB, INC, DEC ---
    mov ax, 10              ; AX = 10
    mov bx, 20              ; BX = 20
    add ax, bx              ; AX = 30 (0x001E)
    mov cx, ax              ; CX = 30
    sub cx, 5               ; CX = 25 (0x0019)
    inc cx                  ; CX = 26 (0x001A)
    dec cx                  ; CX = 25 (0x0019)

    ; --- Display results ---
    mov si, msg1
    call print_str
    mov ax, 1234h
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

    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

; print_str: print null-terminated string at DS:SI
print_str:
    lodsb                   ; AL = [DS:SI], SI++
    or  al, al              ; check for null terminator
    jz  .done
    mov dl, al
    mov ah, 02h             ; DOS function: output character
    int 21h
    jmp print_str
.done:
    ret

; print_hex16: print AX as 4 hex digits
print_hex16:
    push ax
    mov al, ah              ; high byte first
    call print_hex8
    pop ax                  ; then low byte
print_hex8:
    push ax
    mov cl, 4
    shr al, cl              ; high nibble
    call print_nibble
    pop ax                  ; low nibble
print_nibble:
    and al, 0Fh
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7               ; 'A' - '9' - 1
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

msg1:    db "mov ax, 1234h -> AX=0x", 0
msg2:    db "10 + 20        = 0x", 0
msg3:    db "30 - 5         = 0x", 0
msg_done db 13, 10, "Done!", 13, 10, 0

segment .stack stack
    resb 100h

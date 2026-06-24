; s07_subroutines.asm - Scenario 7: Subroutines
; ================================================
; Learning objectives:
;   - CALL / RET: return address saved on stack
;   - Parameter passing via registers (AX, BX, SI, etc.)
;   - Register save/restore with PUSH/POP
;   - Nested subroutine calls
;   - Near vs far call (all near in same segment)
; Difficulty: ★★★☆☆

segment .text
global start

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax

    ; --- 1. Simple call: add_three ---
    mov si, msg_add3
    call print_str

    mov ax, 10              ; parameter: AX = 10
    call add_three          ; returns AX = 13
    call print_hex16
    call print_crlf

    ; --- 2. Multiple parameters via registers ---
    mov si, msg_sum
    call print_str

    mov ax, 100             ; parameter 1
    mov bx, 200             ; parameter 2
    call sum_ab             ; returns AX = AX + BX
    call print_hex16
    call print_crlf

    ; --- 3. Nested calls: greet_user ---
    mov si, msg_greet
    call print_str
    call greet_user         ; calls print_str and print_crlf internally
    call print_crlf

    ; --- 4. Register preservation ---
    mov si, msg_preserve
    call print_str

    mov ax, 1234h           ; important value
    call safe_subroutine    ; internally preserves all registers
    ; AX is still 1234h after the call
    call print_hex16
    call print_crlf

    mov si, msg_done
    call print_str

    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

; add_three: returns AX + 3 in AX
;   Input:  AX = value
;   Output: AX = value + 3
add_three:
    add ax, 3
    ret

; sum_ab: returns AX + BX in AX
;   Input:  AX, BX = values to add
;   Output: AX = AX + BX
sum_ab:
    add ax, bx
    ret

; greet_user: prints "Hello from subroutine!"
;   Demonstrates nested calls (calls print_str)
greet_user:
    push si                 ; save SI (print_str will modify it)
    mov si, msg_hello_sub
    call print_str          ; nested call
    pop si                  ; restore SI
    ret

; safe_subroutine: does some work but preserves ALL registers
safe_subroutine:
    push ax                 ; save AX
    push bx                 ; save BX
    push cx                 ; save CX

    ; ... do work that clobbers AX, BX, CX ...
    mov ax, 0FFFFh
    mov bx, 0FFFFh
    mov cx, 0FFFFh

    pop cx                  ; restore in reverse order (LIFO)
    pop bx
    pop ax
    ret

; ---- Utility subroutines ----

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

msg1          db "Subroutines:", 13, 10, 0
msg_add3      db "  add_three(10)  = 0x", 0
msg_sum       db "  sum(100, 200) = 0x", 0
msg_greet     db "  Nested call:  ", 0
msg_hello_sub db "Hello from subroutine!", 0
msg_preserve  db "  After safe_subroutine, AX = 0x", 0
msg_done      db "Done!", 13, 10, 0

segment .stack stack
    resb 100h

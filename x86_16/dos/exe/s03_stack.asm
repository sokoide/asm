; s03_stack.asm - Scenario 3: Stack Operations
; ==============================================
; Learning objectives:
;   - PUSH / POP instructions (SP changes by ±2)
;   - LIFO (Last In, First Out) behavior
;   - Register preservation pattern (push -> work -> pop)
;   - Stack pointer (SP) observation
; Difficulty: ★★☆☆☆

segment .text

start:
    mov ax, seg msg_sp_before
    mov ds, ax
    mov es, ax

    ; --- Show initial SP ---
    mov si, msg_sp_before
    call print_str
    mov ax, sp
    call print_hex16
    call print_crlf

    ; --- LIFO demonstration ---
    mov si, msg_push
    call print_str
    call print_crlf

    mov ax, 1111h
    push ax                 ; first push
    mov ax, 2222h
    push ax                 ; second push
    mov ax, 3333h
    push ax                 ; third push

    ; Show SP after pushes
    mov si, msg_sp_after_push
    call print_str
    mov ax, sp
    call print_hex16
    call print_crlf

    ; Pop and display (LIFO order: 3333, 2222, 1111)
    mov si, msg_pop
    call print_str

    pop ax
    call print_hex16
    mov al, ' '
    call print_char

    pop ax
    call print_hex16
    mov al, ' '
    call print_char

    pop ax
    call print_hex16
    call print_crlf

    ; --- Register preservation pattern ---
    mov si, msg_preserve
    call print_str

    mov ax, 0AAAAh          ; value to preserve
    push ax                 ; save AX on stack
    mov ax, 0BBBBh          ; use AX for other work
    ; ... do work ...
    pop ax                  ; restore AX -> 0AAAAh

    call print_hex16        ; should print AAAA
    call print_crlf

    ; Show SP after pops (back to original)
    mov si, msg_sp_after
    call print_str
    mov ax, sp
    call print_hex16
    call print_crlf

    mov si, msg_done
    call print_str

    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

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

msg_sp_before:    db "SP before pushes: 0x", 0
msg_push:         db "Pushing: 1111h, 2222h, 3333h", 0
msg_sp_after_push db "SP after pushes:  0x", 0
msg_pop:          db "Popping (LIFO):   ", 0
msg_preserve:     db "Preserve: AX after push/pop = 0x", 0
msg_sp_after:     db "SP after pops:    0x", 0
msg_done:         db "Done!", 13, 10, 0

segment .stack stack
    resb 100h

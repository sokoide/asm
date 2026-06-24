; s04_loops.asm - Scenario 4: Loops and Branching
; =================================================
; Learning objectives:
;   - LOOP instruction (CX--, jump if CX != 0)
;   - CMP + conditional jumps (JE, JNE, JLE, JG, JB, JA)
;   - Count-up vs count-down patterns
;   - TEST instruction for even/odd detection
; Difficulty: ★★☆☆☆

segment .text
global start

start:
    mov ax, seg msg_countdown
    mov ds, ax
    mov es, ax

    ; --- Count down with LOOP (10 to 1) ---
    mov si, msg_countdown
    call print_str

    mov cx, 10
.loop_down:
    mov ax, cx
    call print_hex8         ; print as 2-digit hex
    mov al, ' '
    call print_char
    loop .loop_down         ; CX--, if CX != 0: jump

    call print_crlf

    ; --- Count up with CMP + JLE (1 to 10) ---
    mov si, msg_countup
    call print_str

    mov cx, 1
.loop_up:
    mov ax, cx
    call print_hex8
    mov al, ' '
    call print_char
    inc cx
    cmp cx, 10
    jle .loop_up            ; if CX <= 10: jump

    call print_crlf

    ; --- Even/odd detection with TEST ---
    mov si, msg_even_odd
    call print_str

    mov cx, 5
.test_loop:
    mov ax, cx
    call print_hex8
    mov al, ':'
    call print_char

    test cx, 1              ; check bit 0
    jz .is_even
    mov al, 'O'             ; Odd
    call print_char
    mov al, ' '
    call print_char
    jmp .next
.is_even:
    mov al, 'E'             ; Even
    call print_char
    mov al, ' '
    call print_char
.next:
    loop .test_loop

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

; print_hex8: print AL as 2 hex digits
print_hex8:
    push ax
    push cx
    mov cl, 4
    shr al, cl
    call print_nibble
    pop cx
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

msg_countdown db "Countdown: ", 0
msg_countup   db "Count up:  ", 0
msg_even_odd  db "Even/Odd:  ", 0
msg_done      db "Done!", 13, 10, 0

segment .stack stack
    resb 100h

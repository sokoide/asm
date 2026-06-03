; s06_keyboard.asm - Scenario 6: Keyboard Input
; ================================================
; Learning objectives:
;   - INT 21h AH=01h: character input with echo (AL = ASCII)
;   - INT 21h AH=07h: character input without echo
;   - INT 21h AH=0Ah: buffered line input
;   - Enter key detection (CR = 13)
;   - Backspace handling in manual input
;   - Input buffer structure for AH=0Ah
; Difficulty: ★★★☆☆

segment .text

start:
    mov ax, seg msg_single
    mov ds, ax
    mov es, ax

    ; --- 1. Single character with echo (AH=01h) ---
    mov si, msg_single
    call print_str

    mov ah, 01h             ; DOS: read char with echo
    int 21h                 ; AL = character (echoed to screen)
    mov bx, ax              ; save the character

    call print_crlf
    mov si, msg_you_typed
    call print_str
    mov al, bl
    call print_char
    call print_crlf

    ; --- 2. Single character without echo (AH=07h) ---
    mov si, msg_noecho
    call print_str

    mov ah, 07h             ; DOS: read char without echo
    int 21h
    mov bx, ax

    mov si, msg_you_typed
    call print_str
    mov al, bl
    call print_char
    call print_crlf

    ; --- 3. Buffered line input (AH=0Ah) ---
    mov si, msg_buffered
    call print_str

    mov dx, input_buf
    mov ah, 0Ah             ; DOS: buffered input
    int 21h

    call print_crlf
    mov si, msg_buf_contents
    call print_str

    ; Display the buffered input
    ; input_buf+0 = max chars, input_buf+1 = actual count
    ; input_buf+2 ... = characters (no null terminator)
    mov cl, [input_buf+1]   ; get actual character count
    xor ch, ch
    mov si, input_buf+2     ; point to first character
.print_buf:
    lodsb
    mov dl, al
    mov ah, 02h
    int 21h
    loop .print_buf

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

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

msg_single:     db "Press a key (echo on): ", 0
msg_noecho:     db "Press a key (echo off): ", 0
msg_buffered:   db "Type a line (Enter to finish): ", 0
msg_you_typed:  db "  You typed: ", 0
msg_buf_contents db "  Buffer: ", 0
msg_done:       db "Done!", 13, 10, 0

; AH=0Ah buffer: [max_chars][actual_count][chars...]
input_buf db 80               ; max 80 characters
          db 0                ; actual count (filled by DOS)
          times 81 db 0       ; character buffer + room for CR

segment .stack stack
    resb 100h

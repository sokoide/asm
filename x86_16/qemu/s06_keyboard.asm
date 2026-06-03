; s06_keyboard.asm - Scenario 6: Keyboard Input
; ================================================
; Learning objectives:
;   - INT 0x16 AH=00h: wait for keypress, return ASCII in AL
;   - Echo typed characters back to screen
;   - Backspace handling (move cursor, overwrite with space)
;   - Enter key to submit line
;   - Simple line editing with a buffer

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_intro
    call print_str

    ; --- Main input loop ---
    mov di, buffer          ; DI -> input buffer
    xor cx, cx              ; CX = character count

.read_loop:
    mov ah, 0x00            ; BIOS: wait for keypress
    int 0x16                ; Returns ASCII in AL, scan code in AH

    cmp al, 13              ; Enter key?
    je  .enter

    cmp al, 8               ; Backspace?
    je  .backspace

    cmp al, ' '             ; Only printable chars (>= 0x20)
    jb  .read_loop

    cmp cx, 30              ; Buffer limit
    jge .read_loop

    ; Store character and echo it
    stosb                   ; [ES:DI] = AL, DI++
    inc cx
    mov ah, 0x0E            ; Echo to screen
    xor bh, bh
    int 0x10
    jmp .read_loop

.backspace:
    test cx, cx             ; Any chars to delete?
    jz  .read_loop          ; No: ignore backspace
    dec di                  ; Move buffer pointer back
    dec cx                  ; Decrease count
    ; Erase character on screen: BS + space + BS
    mov ah, 0x0E
    mov al, 8               ; Backspace (move cursor left)
    int 0x10
    mov al, ' '             ; Overwrite with space
    int 0x10
    mov al, 8               ; Backspace again
    int 0x10
    jmp .read_loop

.enter:
    xor al, al
    stosb                   ; Null-terminate the buffer
    call print_crlf

    ; Echo back what was typed
    mov si, msg_echo
    call print_str
    mov si, buffer
    call print_str
    call print_crlf

    ; Reset for next line
    mov si, msg_again
    call print_str
    mov di, buffer
    xor cx, cx
    jmp .read_loop

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
msg_intro db "Type text (Enter to echo, Ctrl+Esc to stop):", 13, 10, 0
msg_echo  db "You typed: ", 0
msg_again db 13, 10, "> ", 0
buffer    times 32 db 0

times 510-($-$$) db 0
dw 0xAA55

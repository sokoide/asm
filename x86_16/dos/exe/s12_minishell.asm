; s12_minishell.asm - Scenario 12: Mini Shell (Comprehensive)
; =============================================================
; Learning objectives:
;   - Line editor: character-by-character input with backspace
;   - String comparison (byte-by-byte strcmp)
;   - Command dispatch table
;   - Screen clearing via BIOS INT 10h
;   - Combining all previous concepts into one program
; Difficulty: ★★★★★
;
; Commands:
;   hello  - display a greeting
;   clear  - clear the screen
;   help   - show command list
;   ver    - show version
;   exit   - exit to DOS

segment .text

start:
    mov ax, seg prompt
    mov ds, ax
    mov es, ax

    ; Show welcome banner
    mov si, banner
    call print_str

    ; --- Main loop ---
.main_loop:
    ; Print prompt
    mov si, prompt
    call print_str

    ; Read line into cmdbuf
    call read_line

    ; Skip empty input
    cmp byte [cmdbuf], 0
    je  .main_loop

    ; Try each command
    mov si, cmdbuf
    mov di, cmd_hello
    call strcmp
    cmp al, 0
    je  .do_hello

    mov si, cmdbuf
    mov di, cmd_clear
    call strcmp
    cmp al, 0
    je  .do_clear

    mov si, cmdbuf
    mov di, cmd_help
    call strcmp
    cmp al, 0
    je  .do_help

    mov si, cmdbuf
    mov di, cmd_ver
    call strcmp
    cmp al, 0
    je  .do_ver

    mov si, cmdbuf
    mov di, cmd_exit
    call strcmp
    cmp al, 0
    je  .do_exit

    ; Unknown command
    mov si, msg_unknown
    call print_str
    mov si, cmdbuf
    call print_str
    call print_crlf
    jmp .main_loop

.do_hello:
    mov si, msg_hello_out
    call print_str
    jmp .main_loop

.do_clear:
    ; Clear screen using BIOS
    mov ax, 0600h           ; scroll up, entire window
    mov bh, 07h             ; attribute: light gray on black
    mov cx, 0000h           ; top-left (0,0)
    mov dx, 184Fh           ; bottom-right (24,79)
    int 10h
    ; Reset cursor to top-left
    mov ah, 02h
    mov bh, 0
    mov dx, 0000h
    int 10h
    jmp .main_loop

.do_help:
    mov si, msg_help
    call print_str
    jmp .main_loop

.do_ver:
    mov si, msg_ver
    call print_str
    jmp .main_loop

.do_exit:
    mov si, msg_bye
    call print_str
    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

; read_line: read keyboard input into cmdbuf
;   Handles: printable chars, Enter (CR), Backspace
read_line:
    push ax
    push bx
    push si

    mov si, cmdbuf
    xor bx, bx             ; character count

.read_char:
    mov ah, 07h             ; read key without echo
    int 21h

    cmp al, 13              ; Enter?
    je  .line_done
    cmp al, 8               ; Backspace?
    je  .backspace

    ; Printable character (ignore others for simplicity)
    cmp al, ' '
    jb  .read_char
    cmp al, '~'
    ja  .read_char

    ; Convert to lowercase (A-Z -> a-z)
    cmp al, 'A'
    jb  .store
    cmp al, 'Z'
    ja  .store
    add al, 20h             ; to lowercase

.store:
    cmp bx, 78              ; buffer full?
    jae .read_char
    mov [si+bx], al
    inc bx

    ; Echo the character
    mov dl, al
    mov ah, 02h
    int 21h
    jmp .read_char

.backspace:
    cmp bx, 0               ; nothing to delete?
    je  .read_char
    dec bx
    ; Erase on screen: BS + space + BS
    mov dl, 8
    mov ah, 02h
    int 21h
    mov dl, ' '
    mov ah, 02h
    int 21h
    mov dl, 8
    mov ah, 02h
    int 21h
    jmp .read_char

.line_done:
    mov byte [si+bx], 0     ; null terminate
    call print_crlf
    pop si
    pop bx
    pop ax
    ret

; strcmp: compare null-terminated strings at DS:SI and ES:DI
;   Returns: AL = 0 if equal, nonzero otherwise
strcmp:
    push si
    push di
.cmp_loop:
    lodsb                   ; AL = [DS:SI], SI++
    mov ah, [di]            ; AH = [ES:DI]
    inc di
    cmp al, ah
    jne .not_equal
    cmp al, 0               ; end of both strings?
    jne .cmp_loop
    ; Strings are equal
    pop di
    pop si
    xor al, al              ; return 0
    ret
.not_equal:
    pop di
    pop si
    mov al, 1               ; return nonzero
    ret

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

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

banner:     db "8086 Mini Shell v1.0", 13, 10
            db "Type 'help' for commands.", 13, 10, 0
prompt:     db "> ", 0
cmd_hello:  db "hello", 0
cmd_clear:  db "clear", 0
cmd_help:   db "help", 0
cmd_ver:    db "ver", 0
cmd_exit:   db "exit", 0
msg_hello_out db "Hello from 8086!", 13, 10, 0
msg_help:   db "Commands: hello, clear, help, ver, exit", 13, 10, 0
msg_ver:    db "8086 Mini Shell v1.0", 13, 10, 0
msg_unknown db "Unknown: ", 0
msg_bye:    db "Bye!", 13, 10, 0

cmdbuf times 80 db 0       ; input command buffer

segment .stack stack
    resb 200h               ; 512-byte stack for shell

bits 16

global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 80x25 text mode (16 colors)
    mov ax, 0x0003
    int 0x10

    call draw_header

    mov si, msg_welcome
    call print_str

; ---- Main command loop ----
cmd_loop:
    mov si, msg_prompt
    call print_str
    call read_line

    ; --- dispatch ---
    mov si, input_buf
    mov di, cmd_hello
    call strcmp
    je  .hello

    mov si, input_buf
    mov di, cmd_help
    call strcmp
    je  .help

    mov si, input_buf
    mov di, cmd_clear
    call strcmp
    je  .clear

    mov si, input_buf
    mov di, cmd_reboot
    call strcmp
    je  .reboot

    ; empty line -> just prompt again
    cmp byte [input_buf], 0
    je  cmd_loop

    mov si, msg_unknown
    call print_str
    jmp cmd_loop

.hello:
    mov si, msg_hello_r
    call print_str
    jmp cmd_loop

.help:
    mov si, msg_help
    call print_str
    jmp cmd_loop

.clear:
    mov ax, 0x0003
    int 0x10
    call draw_header
    jmp cmd_loop

.reboot:
    mov al, 0xFE
    out 0x64, al

; ---- Subroutines ----

; print_str: print null-terminated string at DS:SI via BIOS
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

; read_line: read line into input_buf (lowercased, backspace ok)
read_line:
    mov byte [input_len], 0
    mov di, input_buf
.loop:
    xor ah, ah
    int 0x16             ; wait for keystroke

    cmp al, 13           ; Enter
    je  .enter
    cmp al, 8            ; Backspace
    je  .bs
    cmp al, ' '
    jb  .loop            ; ignore other control chars
    cmp byte [input_len], 48
    jge .loop            ; buffer full

    ; A-Z -> a-z
    cmp al, 'A'
    jb  .store
    cmp al, 'Z'
    ja  .store
    add al, 32
.store:
    stosb
    inc byte [input_len]
    mov ah, 0x0E
    xor bh, bh
    int 0x10             ; echo
    jmp .loop
.bs:
    cmp byte [input_len], 0
    je  .loop
    dec di
    dec byte [input_len]
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .loop
.enter:
    xor al, al
    stosb                ; null terminate
    mov si, msg_crlf
    call print_str
    ret

; strcmp: compare DS:SI and DS:DI — ZF=1 if equal
strcmp:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .ret
    inc si
    inc di
    test al, al
    jnz strcmp
.ret:
    ret

; draw_header: colored title bar via direct VRAM write
draw_header:
    pusha
    push es
    mov ax, 0xB800
    mov es, ax

    ; --- row 0: white on red ---
    xor di, di
    mov ah, 0x4F
    mov si, header_text
.hloop:
    lodsb
    or  al, al
    jz  .hfill
    stosw
    jmp .hloop
.hfill:
    mov al, ' '
    mov cx, di
    shr cx, 1
    neg cx
    add cx, 80
    rep stosw

    ; cursor to row 1
    mov dh, 1
    xor dl, dl
    xor bh, bh
    mov ah, 0x02
    int 0x10

    pop es
    popa
    ret

; ---- Data ----
header_text  db " 8086 MiniShell v1.0 ", 0
msg_welcome  db 13, 10, "Type 'help' for commands.", 13, 10, 0
msg_prompt   db "> ", 0
msg_crlf     db 13, 10, 0
msg_hello_r  db "Hello from the 8086!", 13, 10, 0
msg_help     db "Commands: hello, clear, help, reboot", 13, 10, 0
msg_unknown  db "Unknown command.", 13, 10, 0
cmd_hello    db "hello", 0
cmd_help     db "help", 0
cmd_clear    db "clear", 0
cmd_reboot   db "reboot", 0
input_len    db 0
input_buf    times 48 db 0

times 510-($-$$) db 0
dw 0xAA55

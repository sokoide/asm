; s12_minishell.asm - Scenario 12: Interactive Mini Shell
; =======================================================
; Learning objectives:
;   - Combining all previous concepts into one program
;   - Serial input and output (UART TX/RX)
;   - String comparison for command dispatch
;   - Building a read-eval-print loop (REPL)

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Print banner
    mov si, msg_banner
    call print_str
    mov si, msg_h1
    call print_str
    mov si, msg_h2
    call print_str
    mov si, msg_h3
    call print_str

    ; Main loop: print prompt, read line, dispatch
.main:
    mov si, msg_prompt
    call print_str
    call read_line
    call print_crlf

    ; Compare input with "hello"
    mov si, input
    mov di, cmd_hello
    call strcmp
    je  .hello

    ; Compare input with "help"
    mov si, input
    mov di, cmd_help
    call strcmp
    je  .help

    ; Compare input with "quit"
    mov si, input
    mov di, cmd_quit
    call strcmp
    je  .quit

    ; Empty line? (first char is null) -> just loop
    mov al, [input]
    or  al, al
    jz  .main

    ; Unknown command
    mov si, msg_unk
    call print_str
    jmp .main

.hello:
    mov si, msg_hi
    call print_str
    jmp .main

.help:
    mov si, msg_h1
    call print_str
    mov si, msg_h2
    call print_str
    mov si, msg_h3
    call print_str
    jmp .main

.quit:
    mov si, msg_bye
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

uart_putc:
    push    dx
    push    ax
    mov     dx, 0x3FD
.wait:
    in      al, dx
    test    al, 0x20
    jz      .wait
    mov     dx, 0x3F8
    pop     ax
    out     dx, al
    pop     dx
    ret

uart_getc:
    push    dx
    mov     dx, 0x3FD
.wait:
    in      al, dx
    test    al, 0x01
    jz      .wait
    mov     dx, 0x3F8
    in      al, dx
    pop     dx
    ret

; read_line: read chars into input buffer until Enter
read_line:
    pusha
    mov di, input
.rl_loop:
    call uart_getc
    ; Check for Enter (CR or LF)
    cmp al, 13
    je  .rl_enter
    cmp al, 10
    je  .rl_enter
    ; Check for Backspace (0x08)
    cmp al, 8
    je  .rl_bs
    ; Only store printable chars (>= 0x20)
    cmp al, 0x20
    jb  .rl_loop
    ; Check buffer limit
    push ax
    mov ax, di
    sub ax, input
    cmp ax, 30
    pop ax
    jge .rl_loop
    ; Store and echo
    mov [di], al
    inc di
    call uart_putc
    jmp .rl_loop
.rl_bs:
    mov ax, di
    sub ax, input
    or  ax, ax
    jz  .rl_loop
    dec di
    push ax
    mov al, 8
    call uart_putc
    mov al, ' '
    call uart_putc
    mov al, 8
    call uart_putc
    pop ax
    jmp .rl_loop
.rl_enter:
    mov byte [di], 0
    popa
    ret

; strcmp: compare strings at SI and DI. ZF=1 if equal
strcmp:
    pusha
.sc_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .sc_done
    or  al, al
    jz  .sc_done
    inc si
    inc di
    jmp .sc_loop
.sc_done:
    cmp al, bl
    popa
    ret

print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

print_crlf:
    push ax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop ax
    ret

; ---- Data ----
msg_banner db "8086 MiniShell", 13, 10, 0
msg_prompt db "> ", 0
msg_hi     db "Hello, 8086!", 13, 10, 0
msg_h1     db "Commands: hello, help, quit", 13, 10, 0
msg_h2     db "  hello - Say hello", 13, 10, 0
msg_h3     db "  quit  - Exit", 13, 10, 0
msg_bye    db "Bye!", 13, 10, 0
msg_unk    db "Unknown command", 13, 10, 0
cmd_hello  db "hello", 0
cmd_help   db "help", 0
cmd_quit   db "quit", 0
input      times 32 db 0

times 510-($-$$) db 0
dw 0xAA55

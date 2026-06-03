; s06_serial_in.asm - Scenario 6: Serial Input
; ==============================================
; Learning objectives:
;   - COM1 UART receive (LSR bit 0 = Data Ready)
;   - Polling loop for serial input
;   - Echo typed characters back to terminal
;   - Enter key handling

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Print intro
    mov si, msg_intro
    call print_str

    ; Main loop: read and echo characters
.loop:
    call uart_getc          ; AL = character

    ; Check for Enter (CR or LF)
    cmp al, 13
    je  .done
    cmp al, 10
    je  .done

    ; Echo character back
    call uart_putc
    jmp .loop

.done:
    call print_crlf
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

; uart_getc: read character from COM1 into AL
uart_getc:
    push    dx
    mov     dx, 0x3FD       ; LSR
.wait:
    in      al, dx
    test    al, 0x01        ; bit 0 = Data Ready
    jz      .wait
    mov     dx, 0x3F8       ; RBR
    in      al, dx
    pop     dx
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
msg_intro db "Type chars (Enter=quit):", 13, 10, 0
msg_bye   db "Bye!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

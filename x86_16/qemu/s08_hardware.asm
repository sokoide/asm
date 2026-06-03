; s08_hardware.asm - Scenario 8: Hardware Access (PIT Timer)
; ===========================================================
; Learning objectives:
;   - Intel 8254 PIT (Programmable Interval Timer) at I/O 0x40-0x43
;   - Latch and read counter via I/O port access
;   - IN / OUT instructions for hardware register access
;   - 16-bit counter value: high byte / low byte read order

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Read PIT Counter 0 ---
    ; PIT Counter 0 is at I/O port 0x40
    ; Control register at I/O port 0x43
    ; To latch (freeze) the current count:
    ;   Write 0x00 to port 0x43 (select counter 0, latch)
    ;   Then read low byte, then high byte from port 0x40

    mov si, msg_cnt
    call print_str

    ; Latch counter 0
    mov al, 0x00            ; Control: select counter 0, latch
    mov dx, 0x43
    out dx, al

    ; Read low byte, then high byte
    mov dx, 0x40
    in  al, dx              ; Low byte
    mov bl, al
    in  al, dx              ; High byte
    mov bh, al              ; BX = 16-bit counter value

    mov ax, bx
    call print_hex16
    call print_crlf

    ; Read again to show it's ticking
    mov si, msg_cnt2
    call print_str

    mov al, 0x00
    mov dx, 0x43
    out dx, al

    mov dx, 0x40
    in  al, dx
    mov bl, al
    in  al, dx
    mov bh, al

    mov ax, bx
    call print_hex16
    call print_crlf

    mov si, msg_done
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

print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
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
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    call uart_putc
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
msg_cnt  db "PIT Counter 0: 0x", 0
msg_cnt2 db "PIT Counter 0: 0x", 0
msg_done db 13, 10, "Hardware access done!", 0

times 510-($-$$) db 0
dw 0xAA55

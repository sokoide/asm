; s11_memory.asm - Scenario 11: Memory and Block Operations
; ==========================================================
; Learning objectives:
;   - REP STOSB: fill memory block with a byte
;   - REP MOVSB: copy memory block
;   - Addressing modes: [immediate], [register], [base+index]
;   - Buffer manipulation patterns

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    cld                     ; Direction: forward (SI/DI increment)

    ; --- Demo 1: Block fill with REP STOSB ---
    ; Fill 'display' buffer with '.' characters
    mov al, '.'             ; Fill byte
    mov cx, 20              ; Count
    mov di, display         ; Destination
    rep stosb               ; Fill CX bytes at [ES:DI]
    mov byte [di], 0        ; Null-terminate

    mov si, msg1
    call print_str
    mov si, display
    call print_str
    call print_crlf

    ; --- Demo 2: Block copy with REP MOVSB ---
    ; Copy "Hello" into display buffer
    mov cx, 5               ; 5 bytes to copy
    mov si, src_hello       ; Source
    mov di, display         ; Destination
    rep movsb               ; Copy CX bytes from [DS:SI] to [ES:DI]
    mov byte [display+5], 0 ; Null-terminate

    mov si, msg2
    call print_str
    mov si, display
    call print_str
    call print_crlf

    ; --- Demo 3: Direct indexed addressing ---
    ; Write individual bytes into buffer using offset notation
    mov byte [display+0], 'W'
    mov byte [display+1], 'O'
    mov byte [display+2], 'R'
    mov byte [display+3], 'L'
    mov byte [display+4], 'D'
    mov byte [display+5], 0

    mov si, msg3
    call print_str
    mov si, display
    call print_str
    call print_crlf

    ; --- Demo 4: Base + index addressing ---
    ; Access display[3] using BX+SI
    mov bx, display         ; BX = base address
    mov si, 3               ; SI = index
    mov al, [bx+si]         ; AL = display[3] = 'L' = 0x4C
    push ax                 ; Save value

    mov si, msg4
    call print_str
    pop ax                  ; Restore value
    call print_hex8
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
src_hello db "Hello"
display   times 24 db 0
msg1 db "Fill:  ", 0
msg2 db "Copy:  ", 0
msg3 db "Index: ", 0
msg4 db "[BX+SI] display[3]=0x", 0
msg_done db 13, 10, "Memory ops done!", 0

times 510-($-$$) db 0
dw 0xAA55

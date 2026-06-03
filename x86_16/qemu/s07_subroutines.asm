; s07_subroutines.asm - Scenario 7: Subroutines
; ================================================
; Learning objectives:
;   - CALL: push return address, jump to label
;   - RET: pop return address, jump back
;   - Parameter passing via registers
;   - Nested subroutine calls
;   - PUSHA/POPA: save/restore all registers

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Call 1: Print a string ---
    mov si, msg1            ; Parameter: SI = string pointer
    call print_str
    call print_crlf

    ; --- Call 2: Print hex values (reuse print_hex16 from s02) ---
    mov si, msg2
    call print_str
    mov ax, 0xBEEF          ; Parameter: AX = value to display
    call print_hex16
    call print_crlf

    mov si, msg3
    call print_str
    mov ax, 0xCAFE
    call print_hex16
    call print_crlf

    ; --- Call 3: Nested call (print_dots calls uart_putc) ---
    mov si, msg4
    call print_str
    mov cx, 5               ; Parameter: CX = count
    call print_dots
    call print_crlf

    ; --- Call 4: Compute and display (add_bytes) ---
    mov al, 42              ; Parameter: AL = first operand
    mov bl, 13              ; Parameter: BL = second operand
    call add_bytes           ; Returns: AL = AL + BL
    push ax
    mov si, msg5
    call print_str
    pop ax
    call print_hex8
    call print_crlf

    mov si, msg_done
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

; uart_putc: output character in AL to COM1 (16550 UART at 0x3F8)
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

; add_bytes: return AL + BL in AL
;   Input:  AL, BL
;   Output: AL = AL + BL
add_bytes:
    add al, bl
    ret

; print_dots: print CX dots using nested call
print_dots:
    mov al, '.'
    call uart_putc          ; Nested call
    loop print_dots
    ret

; print_str: print null-terminated string at DS:SI
;   Uses PUSHA/POPA to preserve all registers
print_str:
    pusha
.loop:
    lodsb
    or  al, al
    jz  .done
    call uart_putc
    jmp .loop
.done:
    popa
    ret

; print_hex16: print AX as 4 hex digits
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
msg1    db "Hello from subroutine!", 0
msg2    db "Hex: 0x", 0
msg3    db "Hex: 0x", 0
msg4    db "Loading", 0
msg5    db "42+13=0x", 0
msg_done db 13, 10, "Subroutines done!", 0

times 510-($-$$) db 0
dw 0xAA55

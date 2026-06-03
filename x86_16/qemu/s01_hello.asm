; s01_hello.asm - Scenario 1: Hello World
; =========================================
; Learning objectives:
;   - Boot sector structure (bits 16, 0x7C00, 0xAA55)
;   - Segment register initialization (DS, ES, SS, SP)
;   - COM1 UART output (16550 at I/O port 0x3F8)
;   - LODSB instruction and null-terminated strings
;   - CPU halt loop (CLI + HLT)

bits 16
global _start

section .text
_start:
    ; Initialize segments to 0
    ; On boot, BIOS loads our 512-byte sector at 0x0000:0x7C00
    xor ax, ax
    mov ds, ax              ; Data segment = 0
    mov es, ax              ; Extra segment = 0

    ; Set up stack below our code (grows downward)
    mov ss, ax              ; Stack segment = 0
    mov sp, 0x7C00          ; Stack pointer starts just below code

    ; Print each character using COM1 UART
    mov si, message          ; SI = pointer to string

.print_loop:
    lodsb                   ; Load byte at [DS:SI] into AL, SI++
    or  al, al              ; Check AL == 0 (null terminator)?
    jz  .done               ; Yes -> stop
    call uart_putc          ; Output character via COM1
    jmp .print_loop         ; Next character

.done:
    cli                     ; Disable interrupts
    hlt                     ; Halt CPU
    jmp .done               ; Safety: re-halt if NMI wakes us

; ---- Subroutines ----

; uart_putc: output character in AL to COM1 (16550 UART at 0x3F8)
uart_putc:
    push    dx
    push    ax
    mov     dx, 0x3FD       ; LSR (Line Status Register)
.wait:
    in      al, dx
    test    al, 0x20        ; bit 5 = THRE (Transmitter Holding Register Empty)
    jz      .wait
    mov     dx, 0x3F8       ; THR (Transmitter Holding Register)
    pop     ax
    out     dx, al
    pop     dx
    ret

; ---- Data ----
message db "Hello, 8086 World!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

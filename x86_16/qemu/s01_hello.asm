; s01_hello.asm - Scenario 1: Hello World
; =========================================
; Learning objectives:
;   - Boot sector structure (bits 16, 0x7C00, 0xAA55)
;   - Segment register initialization (DS, ES, SS, SP)
;   - BIOS INT 0x10 AH=0Eh (teletype character output)
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

    ; Print each character using BIOS teletype output
    mov si, message          ; SI = pointer to string

.print_loop:
    lodsb                   ; Load byte at [DS:SI] into AL, SI++
    or  al, al              ; Check AL == 0 (null terminator)?
    jz  .done               ; Yes -> stop
    mov ah, 0x0E            ; INT 0x10 function: teletype output
    xor bh, bh              ; Display page 0
    int 0x10                ; Call BIOS video service
    jmp .print_loop         ; Next character

.done:
    cli                     ; Disable interrupts
    hlt                     ; Halt CPU
    jmp .done               ; Safety: re-halt if NMI wakes us

; ---- Data ----
message db "Hello, 8086 World!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

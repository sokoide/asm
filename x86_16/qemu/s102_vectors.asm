; s102_vectors.asm - Scenario 102: Interrupt Vector Table (x86-specific)
; =======================================================================
; Learning objectives:
;   - IVT (Interrupt Vector Table): 256 entries at physical 0x00000-0x003FF
;     entry n = dword at 0x0000:(n*4) -> [offset word][segment word]
;   - Registering a custom handler (INT 60h) by writing to the IVT
;   - INT n pushes FLAGS, CS, IP then dispatches; IRET pops them back
;   - Software interrupts (INT n) work even with IF=0 — they are traps,
;     not maskable hardware interrupts
;
; Task:
;   - Install a handler for vector 0x60 (IVT entry at 0x0000:0x0180)
;   - Execute INT 60h; the handler prints a message and returns via IRET
;   - Main code resumes after the INT and prints a confirmation
;
; IVT layout for vector 0x60 (0x60 * 4 = 0x0180):
;
;       0x0180: handler IP (offset)   word
;       0x0182: handler CS (segment)  word   (0 here: our code runs at CS=0)
;
; Why vector 0x60: 0x00-0x1F are reserved/used by the CPU and BIOS
; (0x00 divide error, 0x08 timer, 0x0E disk, 0x10 video, 0x13 disk BIOS...).
; User-defined software interrupts conventionally start at 0x60 (unused
; range 0x60-0x66).

cpu 8086
bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Install handler for INT 60h ---
    ; Handler lives in this boot sector: CS=0, offset = handler label
    mov ax, handler
    mov [0x0180], ax        ; IVT[0x60].offset
    mov ax, cs              ; CS = 0 on this boot path
    mov [0x0182], ax        ; IVT[0x60].segment

    mov si, msg_before
    call print_str

    int 0x60                ; FLAGS/CS/IP pushed, IP := IVT[0x60].offset

    mov si, msg_after
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Interrupt handler (called via INT 60h) ----
; INT n pushed FLAGS, CS, IP automatically; IRET pops them in reverse.
; The handler must preserve every register the interrupted code needs.
handler:
    push ax
    push dx
    push si
    mov si, msg_handler
    call print_str
    pop si
    pop dx
    pop ax
    iret                    ; pop IP, CS, FLAGS -> back after INT 60h

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

print_crlf:
    push ax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop ax
    ret

; ---- Data ----
msg_before  db "Before INT 60h", 13, 10, 0
msg_handler db "  [INT 60h handler fired!]", 13, 10, 0
msg_after   db "Back after IRET", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

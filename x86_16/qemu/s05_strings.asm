; s05_strings.asm - Scenario 5: String Operations
; =================================================
; Learning objectives:
;   - LODSB: load byte from [DS:SI], increment SI
;   - STOSB: store byte to [ES:DI], increment DI
;   - SCASB: compare AL with [ES:DI], increment DI
;   - REP prefix: repeat CX times
;   - Direction flag: CLD (forward) / STD (backward)
;   - String length measurement, string copy

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    cld                     ; Clear direction flag (SI/DI auto-increment)

    ; --- Demo 1: Measure string length with REPNE SCASB ---
    ; SCASB compares AL with [ES:DI] and advances DI
    ; REPNE repeats while not equal and CX > 0
    mov di, greeting        ; DI -> string
    xor al, al              ; AL = 0 (search for null terminator)
    mov cx, 0xFFFF          ; Maximum search count
    repne scasb             ; Scan until [DI] == 0
    ; After: CX was decremented for each byte including the null
    ; Length = 0xFFFF - CX - 1
    mov ax, 0xFFFF
    sub ax, cx
    dec ax
    push ax                 ; Save length

    mov si, msg_len
    call print_str
    pop ax
    add al, '0'            ; Convert to ASCII (safe if < 10)
    call uart_putc
    call print_crlf

    ; --- Demo 2: Copy string with REP MOVSB ---
    ; MOVSB copies byte from [DS:SI] to [ES:DI], advances both
    mov si, source          ; Source string
    mov di, dest            ; Destination buffer
    mov cx, 6               ; 5 chars + null terminator
    rep movsb               ; Copy CX bytes

    mov si, msg_copy
    call print_str
    mov si, dest
    call print_str
    call print_crlf

    ; --- Demo 3: Print string with LODSB (same as print_str) ---
    mov si, msg_greet
    call print_str
    mov si, greeting
    call print_str
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
    lodsb                   ; AL = [DS:SI], SI++
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
greeting  db "Hello", 0           ; 5 chars
source    db "World", 0           ; 5 chars + null = 6
dest      times 6 db 0           ; Destination buffer
msg_len   db "Length of 'Hello': ", 0
msg_copy  db "Copied: ", 0
msg_greet db "Original: ", 0
msg_done  db 13, 10, "String ops done!", 0

times 510-($-$$) db 0
dw 0xAA55

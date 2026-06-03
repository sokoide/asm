; s09_branching.asm - Scenario 9: Branching and Menu System
; ==========================================================
; Learning objectives:
;   - CMP: compare two values (sets flags without modifying operands)
;   - Conditional jumps: JE/JNE (equal), JL/JG (signed), JB/JA (unsigned)
;   - Signed vs unsigned comparison
;   - Building an interactive menu with keyboard dispatch

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    call show_menu

    ; --- Main loop: read key, dispatch ---
.menu:
    mov ah, 0x00
    int 0x16                ; Wait for keypress -> AL = ASCII

    cmp al, '1'
    je  .hello
    cmp al, '2'
    je  .test_signed
    cmp al, '3'
    je  .test_unsigned
    cmp al, 'q'
    je  .quit
    ; Ignore other keys
    jmp .menu

.hello:
    mov si, msg_hello
    call print_str
    call show_menu
    jmp .menu

.test_signed:
    ; Signed comparison: JL / JG use SF and OF flags
    mov al, -5              ; 0xFB = 251 unsigned, -5 signed
    cmp al, 10
    jl  .is_neg             ; JL: signed less than
    mov si, msg_pos
    call print_str
    jmp .back
.is_neg:
    mov si, msg_neg
    call print_str
.back:
    call show_menu
    jmp .menu

.test_unsigned:
    ; Unsigned comparison: JB / JA use CF flag only
    ; Same bit pattern 0xFB, but treated as unsigned
    mov al, 0xFB            ; 251 unsigned
    cmp al, 200
    jb  .below              ; JB: unsigned below (CF=1)
    mov si, msg_above
    call print_str
    jmp .back2
.below:
    mov si, msg_below
    call print_str
.back2:
    call show_menu
    jmp .menu

.quit:
    mov si, msg_bye
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

show_menu:
    mov si, msg_menu
    call print_str
    ret

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

; ---- Data ----
msg_menu  db 13, 10, "== Menu ==", 13, 10
          db "1 - Hello", 13, 10
          db "2 - Signed test (-5 < 10?)", 13, 10
          db "3 - Unsigned test (251 < 200?)", 13, 10
          db "q - Quit", 13, 10
          db "> ", 0
msg_hello db 13, 10, "Hello!", 13, 10, 0
msg_pos   db 13, 10, "Result: -5 >= 10 (wrong!)", 13, 10, 0
msg_neg   db 13, 10, "Result: -5 < 10 (JL signed)", 13, 10, 0
msg_above db 13, 10, "Result: 251 >= 200 (JA unsigned)", 13, 10, 0
msg_below db 13, 10, "Result: 251 < 200 (wrong!)", 13, 10, 0
msg_bye   db 13, 10, "Bye!", 0

times 510-($-$$) db 0
dw 0xAA55

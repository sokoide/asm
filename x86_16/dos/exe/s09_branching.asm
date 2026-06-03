; s09_branching.asm - Scenario 9: Branching and Menus
; =====================================================
; Learning objectives:
;   - Key input dispatch: read key -> CMP -> JE/JNE -> action
;   - Signed comparison: JL, JG (SF != OF)
;   - Unsigned comparison: JB, JA (CF = 1)
;   - Same bits, different interpretation (e.g. 0xFB = -5 or 251)
;   - Menu loop with quit option
; Difficulty: ★★★★☆

segment .text

start:
    mov ax, seg msg_menu
    mov ds, ax
    mov es, ax

    ; --- Main menu loop ---
.menu:
    call print_crlf
    mov si, msg_menu
    call print_str
    mov si, msg_prompt
    call print_str

    mov ah, 07h             ; read key without echo
    int 21h                 ; AL = key

    ; Dispatch on key
    cmp al, '1'
    je  .option_hello
    cmp al, '2'
    je  .option_signed
    cmp al, '3'
    je  .option_unsigned
    cmp al, 'q'
    je  .quit
    cmp al, 'Q'
    je  .quit

    ; Unknown key
    mov si, msg_unknown
    call print_str
    jmp .menu

.option_hello:
    mov si, msg_hello
    call print_str
    jmp .menu

.option_signed:
    ; Demonstrate signed comparison
    mov si, msg_signed
    call print_str

    mov al, 0FBh            ; AL = 0xFB = -5 (signed) or 251 (unsigned)
    mov bl, 10
    cmp al, bl
    jl  .signed_less
    mov si, msg_ge
    call print_str
    jmp .menu
.signed_less:
    mov si, msg_lt
    call print_str
    jmp .menu

.option_unsigned:
    ; Demonstrate unsigned comparison
    mov si, msg_unsigned
    call print_str

    mov al, 0FBh            ; same 0xFB, but compared unsigned
    mov bl, 10
    cmp al, bl
    jb  .unsigned_below
    mov si, msg_ae
    call print_str
    jmp .menu
.unsigned_below:
    mov si, msg_below
    call print_str
    jmp .menu

.quit:
    mov si, msg_bye
    call print_str
    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

print_str:
    lodsb
    or  al, al
    jz  .done
    mov dl, al
    mov ah, 02h
    int 21h
    jmp print_str
.done:
    ret

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

msg_menu:    db "=== Menu ===", 13, 10
             db "1. Hello", 13, 10
             db "2. Signed: 0xFB vs 10", 13, 10
             db "3. Unsigned: 0xFB vs 10", 13, 10
             db "q. Quit", 13, 10, 0
msg_prompt:  db "> ", 0
msg_hello:   db "  Hello from menu!", 13, 10, 0
msg_signed:  db "  Signed: 0xFB (-5) vs 10: ", 0
msg_lt:      db "-5 < 10 (JL taken)", 13, 10, 0
msg_ge:      db "-5 >= 10 (JL not taken)", 13, 10, 0
msg_unsigned db "  Unsigned: 0xFB (251) vs 10: ", 0
msg_ae:      db "251 >= 10 (JB not taken)", 13, 10, 0
msg_below:   db "251 < 10 (JB taken)", 13, 10, 0
msg_unknown: db "  Unknown option", 13, 10, 0
msg_bye:     db "Bye!", 13, 10, 0

segment .stack stack
    resb 200h

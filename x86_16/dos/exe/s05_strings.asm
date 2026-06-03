; s05_strings.asm - Scenario 5: String Operations
; =================================================
; Learning objectives:
;   - LODSB: load byte from [DS:SI] into AL, SI++
;   - STOSB: store AL to [ES:DI], DI++
;   - SCASB: compare AL with [ES:DI], DI++
;   - MOVSB: copy byte from [DS:SI] to [ES:DI], SI++, DI++
;   - REP / REPNE / REPZ prefixes
;   - CLD: clear direction flag (SI/DI auto-increment)
;   - String length measurement with REPNE SCASB
;   - String copy with REP MOVSB
; Difficulty: ★★☆☆☆

segment .text

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax              ; ES = DS for string ops
    cld                     ; clear direction flag: SI/DI auto-increment

    ; --- 1. String length using REPNE SCASB ---
    mov si, msg_len
    call print_str

    mov al, 0               ; search for null terminator
    mov di, source          ; ES:DI -> source string
    mov cx, 0FFFFh          ; max count
    repne scasb             ; scan until AL == [ES:DI] or CX == 0
    ; DI now points PAST the null; length = DI - source - 1
    mov ax, di
    sub ax, source
    dec ax                  ; exclude the null byte
    call print_hex8
    call print_crlf

    ; --- 2. String copy using REP MOVSB ---
    mov si, msg_copy
    call print_str

    ; Copy "Hello!" from source to dest
    mov si, source          ; DS:SI -> source
    mov di, dest            ; ES:DI -> destination
    mov cx, 7               ; length of "Hello!" + null = 7
    rep movsb               ; copy CX bytes

    ; Print the copied string
    mov si, dest
    call print_str
    call print_crlf

    ; --- 3. String compare using REPZ CMPSB ---
    mov si, msg_cmp_eq
    call print_str

    mov si, source          ; DS:SI -> "Hello!"
    mov di, dest            ; ES:DI -> "Hello!" (copied)
    mov cx, 6               ; compare 6 chars (without null)
    repz cmpsb              ; compare while equal
    jz .strings_equal
    mov si, msg_no
    jmp .show_cmp
.strings_equal:
    mov si, msg_yes
.show_cmp:
    call print_str
    call print_crlf

    ; --- 4. Memory fill using REP STOSB ---
    mov si, msg_fill
    call print_str

    mov di, fillbuf
    mov al, 'X'
    mov cx, 8
    rep stosb               ; fill 8 bytes with 'X'

    ; Null-terminate and print
    mov al, 0
    stosb
    mov si, fillbuf
    call print_str
    call print_crlf

    mov si, msg_done
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

print_hex8:
    push ax
    mov cl, 4
    shr al, cl
    call print_nibble
    pop ax
print_nibble:
    and al, 0Fh
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    mov dl, al
    mov ah, 02h
    int 21h
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

msg1      db "String ops:", 13, 10, 0
msg_len   db "  Length of source: ", 0
msg_copy  db "  Copy result:      ", 0
msg_cmp_eq db "  source == dest?   ", 0
msg_yes   db "YES", 0
msg_no    db "NO", 0
msg_fill  db "  Fill 8x 'X':     ", 0
msg_done  db "Done!", 13, 10, 0

source  db "Hello!", 0           ; 7 bytes including null
dest    times 8 db 0             ; destination buffer
fillbuf times 9 db 0             ; 8 fill bytes + null

segment .stack stack
    resb 100h

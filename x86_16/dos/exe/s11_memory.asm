; s11_memory.asm - Scenario 11: Memory and Block Operations
; ===========================================================
; Learning objectives:
;   - REP STOSB: fill memory block with a byte
;   - REP MOVSB: copy memory block
;   - Addressing modes: [immediate], [BX+SI], [BX+offset]
;   - Direct memory modification: mov byte [addr], value
;   - Block operations with CX count
; Difficulty: ★★★★☆

segment .text
global start

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax
    cld

    ; --- 1. REP STOSB: fill block with a character ---
    mov si, msg_fill
    call print_str

    mov di, buf1            ; ES:DI -> destination
    mov al, '*'             ; fill byte
    mov cx, 10              ; count
    rep stosb               ; fill 10 bytes with '*'
    mov al, 0
    stosb                   ; null terminate

    mov si, buf1
    call print_str
    call print_crlf

    ; --- 2. REP MOVSB: copy block ---
    mov si, msg_copy
    call print_str

    mov si, source2         ; DS:SI -> source
    mov di, buf2            ; ES:DI -> destination
    mov cx, 14              ; length
    rep movsb               ; copy 14 bytes
    mov al, 0
    stosb                   ; null terminate

    mov si, buf2
    call print_str
    call print_crlf

    ; --- 3. Direct memory write ---
    mov si, msg_direct
    call print_str

    mov al, 'X'
    mov [buf1+3], al        ; change 4th byte to 'X'
    mov [buf1+4], al        ; change 5th byte to 'X'

    mov si, buf1
    call print_str
    call print_crlf

    ; --- 4. [BX+SI] addressing: access array elements ---
    mov si, msg_index
    call print_str

    mov bx, array           ; BX = base of array
    mov si, 2               ; SI = index (3rd element, 0-based)
    mov al, [bx+si]         ; AL = array[2]
    call print_hex8
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

msg1:     db "Memory ops:", 13, 10, 0
msg_fill: db "  Fill 10x '*':   ", 0
msg_copy: db "  Copy string:    ", 0
msg_direct db "  Direct write:   ", 0
msg_index db "  array[2] = 0x", 0
msg_done  db "Done!", 13, 10, 0

source2 db "Copied string!", 0   ; 14 chars + null
buf1    times 12 db 0            ; fill buffer (10 + null + pad)
buf2    times 16 db 0            ; copy buffer
array   db 10h, 20h, 30h, 40h, 50h  ; byte array for indexed access

segment .stack stack
    resb 100h

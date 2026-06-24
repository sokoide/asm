; s08_vram.asm - Scenario 8: Direct VRAM Access
; ================================================
; Learning objectives:
;   - Video memory segment: 0xB800 (text mode 80x25)
;   - Character + attribute byte pair (2 bytes per character)
;   - Attribute byte: [Blink][BG RGB][Bright][FG RGB]
;   - STOSW for fast character+attribute write
;   - 16 foreground colors, 8 background colors
;   - Bypassing DOS: direct hardware access
; Difficulty: ★★★☆☆

segment .text
global start

start:
    mov ax, seg msg_header
    mov ds, ax
    mov es, ax

    ; --- Print header via DOS ---
    mov si, msg_header
    call print_str

    ; --- 1. Write colored text directly to VRAM ---
    ; Text mode VRAM is at B800:0000, 80x25 = 4000 bytes
    ; Each character: [ASCII byte][Attribute byte]
    ; Attribute: [Blink][BG R G B][Bright][FG R G B]

    mov ax, 0B800h
    mov es, ax              ; ES -> video memory segment
    xor di, di              ; ES:DI = B800:0000 (row 0, col 0)

    ; Write "COLOR" in different foreground colors
    ; Row 1 (offset = 160 = 80*2) to skip the header area
    mov di, 160             ; row 1, col 0

    ; 'C' in bright red (0Ch) on black (0h)
    mov ax, 0Ch * 256 + 'C'
    stosw

    ; 'O' in bright green (0Ah) on black
    mov ax, 0Ah * 256 + 'O'
    stosw

    ; 'L' in bright yellow (0Eh) on black
    mov ax, 0Eh * 256 + 'L'
    stosw

    ; 'O' in bright blue (09h) on black
    mov ax, 09h * 256 + 'O'
    stosw

    ; 'R' in bright magenta (0Dh) on black
    mov ax, 0Dh * 256 + 'R'
    stosw

    ; 'S' in bright cyan (0Bh) on black
    mov ax, 0Bh * 256 + 'S'
    stosw

    ; --- 2. Fill a row with a color bar ---
    ; Row 3: show all 16 foreground colors
    mov di, 160 * 3         ; row 3
    mov cx, 16
    mov bl, 0               ; color counter
.color_loop:
    mov al, 219             ; full block character
    mov ah, bl              ; attribute = color index
    stosw
    inc bl
    loop .color_loop

    ; --- 3. Inverted text (white on blue) ---
    ; Row 5
    mov di, 160 * 5
    mov si, msg_inverted
    mov ah, 1Fh             ; bright white (F) on blue (1)
.print_inv:
    lodsb
    or  al, al
    jz  .inv_done
    stosw                   ; write [AL][AH] to ES:DI
    jmp .print_inv
.inv_done:

    ; --- 4. Blinking text ---
    ; Row 7: attribute bit 7 = blink
    mov di, 160 * 7
    mov si, msg_blink
    mov ah, 8Ch             ; blink (80h) + bright red (0Ch) on black
.print_blink:
    lodsb
    or  al, al
    jz  .blink_done
    stosw
    jmp .print_blink
.blink_done:

    ; Restore ES to data segment for DOS output
    mov ax, seg msg_done
    mov ds, ax
    mov es, ax
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

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

msg_header:  db "VRAM demo - look at the screen!", 13, 10, 0
msg_inverted db " White on Blue Background ", 0
msg_blink:   db " Blinking Text! ", 0
msg_done:    db "Done!", 13, 10, 0

segment .stack stack
    resb 100h

; s08_vram.asm - Scenario 8: Direct Video Memory Access
; ======================================================
; Learning objectives:
;   - Text mode VRAM at segment 0xB800 (80 columns x 25 rows)
;   - Each character: [ASCII byte][attribute byte]
;   - Attribute format: [Blink][R G B bg][Bright][R G B fg]
;   - Direct memory write vs BIOS calls
;   - STOSW for fast screen updates

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Set 80x25 text mode (also clears screen)
    mov ax, 0x0003
    int 0x10

    ; Point ES to VRAM segment
    mov ax, 0xB800
    mov es, ax

    ; Hide cursor
    mov ch, 0x20
    mov ah, 0x01
    int 0x10

    ; --- Row 0: Title bar (white on red) ---
    xor di, di              ; DI = 0 (row 0, col 0)
    mov ah, 0x4F            ; White text on red background
    mov si, header
.h_loop:
    lodsb
    or  al, al
    jz  .h_fill
    stosw                   ; [ES:DI] = AX (char + attr), DI += 2
    jmp .h_loop
.h_fill:
    mov al, ' '
    mov cx, di
    shr cx, 1               ; Chars written so far
    mov dx, 80
    sub dx, cx
    mov cx, dx
    rep stosw               ; Fill rest of row with spaces

    ; --- Row 2: Colored text (each letter different color) ---
    ; Attribute byte: [blink:1][bg_RGB:3][bright:1][fg_RGB:3]
    mov di, 80 * 2 * 2      ; Row 2 byte offset = 320

    mov ax, 0x0E48          ; Yellow 'H'
    stosw
    mov ax, 0x0A45          ; Light green 'E'
    stosw
    mov ax, 0x0C4C          ; Light red 'L'
    stosw
    mov ax, 0x0C4C          ; Light red 'L'
    stosw
    mov ax, 0x094F          ; Light blue 'O'
    stosw
    mov ax, 0x0F21          ; White '!'
    stosw

    ; --- Row 4: All 16 foreground colors ---
    mov di, 80 * 2 * 4      ; Row 4
    mov cx, 15              ; 15 colors (skip 0 = invisible on black)
    mov al, 0xDB            ; Solid block character
    mov ah, 0x01            ; Start with color 1 (blue)
.clr_loop:
    stosw
    inc ah                  ; Next foreground color
    loop .clr_loop

    ; --- Row 6: Attribute byte explanation ---
    mov di, 80 * 2 * 6      ; Row 6
    mov ah, 0x1F            ; White on blue
    mov si, msg_attr
.a_loop:
    lodsb
    or  al, al
    jz  .done
    stosw
    jmp .a_loop
.done:
    cli
    hlt
    jmp .done

; ---- Data ----
header   db " VRAM Direct Write Demo ", 0
msg_attr db "Attr: [blink][bg RGB][bright][fg RGB]", 0

times 510-($-$$) db 0
dw 0xAA55

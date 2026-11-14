; s101_segments.asm - Scenario 101: Segment Addressing (x86-specific)
; ====================================================================
; Learning objectives:
;   - segment:offset -> physical address = seg*16 + offset (20-bit address)
;   - Multiple segment:offset pairs can point to the same physical address
;   - 64KB wraparound: the offset is 16-bit, so it wraps inside the segment
;     window (offset 0xFFFF + 1 -> 0x0000) without carrying into the segment
;   - Why BIOS can load the boot sector as 0x07C0:0000 or 0x0000:0x7C00
;
; Task:
;   - Compute physical addresses from several seg:off pairs and print them
;   - Show two different pairs that alias the same physical address
;
; How it works (8086 real mode):
;   The 16-bit segment register value is shifted left 4 bits (multiplied by 16)
;   and the 16-bit offset is added, producing a 20-bit physical address:
;
;       0x07C0 << 4 = 0x7C00,  + 0x0000  ->  0x07C00
;       0x0000 << 4 = 0x0000,  + 0x7C00  ->  0x07C00   (same address!)
;       0x1000 << 4 = 0x10000, + 0x0023  ->  0x10023
;       0x1002 << 4 = 0x10020, + 0x0003  ->  0x10023   (alias!)
;
;   64KB wraparound: within one segment, the offset wraps at 0xFFFF -> 0x0000.
;   Example with DS=0x07C0: byte at DS:0xFFFF is physical 0x17BFF; accessing
;   the "next" byte reads DS:0x0000 (physical 0x07C00) — it wraps inside the
;   segment window and does NOT continue to physical 0x17C00. Segmentation is
;   a 64KB sliding window, not a flat address space.
;
;   At boot, some BIOS implementations jump to 0x07C0:0000, others to
;   0x0000:0x7C00. Both are physical 0x07C00, but CS (and thus the "default"
;   data segment for relative references) differs — a classic boot loader pit.

bits 16
global _start

section .text
_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_title
    call print_str

    ; --- Pair 1: 0x0000:0x7C00 (BIOS convention) ---
    mov bx, 0x0000
    mov cx, 0x7C00
    call print_pair

    ; --- Pair 2: 0x07C0:0x0000 (same physical address) ---
    mov bx, 0x07C0
    mov cx, 0x0000
    call print_pair

    ; --- Pair 3: 0x1000:0x0023 ---
    mov bx, 0x1000
    mov cx, 0x0023
    call print_pair

    ; --- Pair 4: 0x1002:0x0003 (alias of pair 3) ---
    mov bx, 0x1002
    mov cx, 0x0003
    call print_pair

    mov si, msg_done
    call print_str

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

; print_pair: print "seg:off -> phys" for BX=seg, CX=off
print_pair:
    push bx
    push cx
    push dx
    push si
    mov ax, bx
    call print_hex16
    mov al, ':'
    call uart_putc
    mov ax, cx
    call print_hex16
    mov si, msg_arrow
    call print_str
    call calc_phys          ; DX = high nibble, AX = low 16 bits
    push ax
    mov al, dl
    call print_nibble       ; 5th hex digit (top of the 20-bit address)
    pop ax
    call print_hex16        ; low 16 bits, 4 hex digits
    call print_crlf
    pop si
    pop dx
    pop cx
    pop bx
    ret

; calc_phys: BX=seg, CX=off -> DX=seg>>12 (+carry), AX=seg*16+off (low 16)
calc_phys:
    push cx
    mov ax, bx
    mov dx, bx
    mov cl, 12
    shr dx, cl              ; DX = seg >> 12 (top nibble)
    mov cl, 4
.shl4:
    shl ax, 1               ; AX = seg * 16 (mod 64K)
    dec cl
    jnz .shl4
    pop cx
    add ax, cx              ; + offset
    adc dx, 0               ; carry into the 20th bit
    ret

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

print_hex16:
    push ax
    mov al, ah
    call print_hex8
    pop ax
    jmp print_hex8

print_hex8:
    push ax
    push cx
    mov cl, 4
    shr al, cl
    call print_nibble
    pop cx
    pop ax
print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    call uart_putc
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
msg_title db 13, 10, "physical = seg*16 + offset", 13, 10, 0
msg_arrow db " -> ", 0
msg_done  db 13, 10, "Segment demo done", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

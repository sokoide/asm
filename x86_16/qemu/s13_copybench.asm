; s13_copybench.asm - Scenario 13: Copy Benchmark (common to all architectures)
; ==============================================================================
; Learning objectives:
;   - REP MOVSB: the 8086's block transfer (copy loop without loop code)
;   - Measuring copy cost: hand-calculated 8086 cycle counts (QEMU TCG cannot
;     measure cycles, so the breakdown is documented in comments below)
;   - Checksum verification of a 100-byte memory copy
;
; Task (common spec across architectures):
;   - Copy 100 bytes where byte i = i (0..99)
;   - Sum the 100 destination bytes (checksum of 0+1+...+99 = 4950 = 0x1356)
;   - Output exactly one line: "COPY OK CHECKSUM=1356"
;     (or "COPY FAIL CHECKSUM=xxxx" on mismatch)
;
; Build: nasm -f elf32 + ld.lld (single sector, same as s01-s12)
;
; ---- Cycle breakdown of the COPY BODY (hand calculation) ----
; Basis: 8086 Family User's Manual Table 2-21 (MOVS: 18 OR 9+17n; the same
;        table row appears in 8086マシン語秘伝の書(1990) 三の章ニモニック表,
;        mirrored in `isa x86_16 MOVS`). Sanity check: an 8086 bus cycle is
;        4 clocks, so a byte move (read + write) cannot be fewer than 8
;        clocks/byte - 17 clocks/byte is the physically consistent figure.
;   cld                 =  2
;   mov si, imm16       =  4
;   mov di, imm16       =  4
;   mov cx, imm16       =  4
;   rep movsb           = 9 + 17*n          (n = CX = 100)
;                       = 9 + 1700 = 1709
;   copy body total     = 2 + 4 + 4 + 4 + 1709 = 1723 cycles (17.09 cyc/byte)
;
; For comparison, a hand-rolled loop costs ~18 (movsb) + loop overhead per
; byte - still more than REP MOVSB's 17.09, but the margin is small.
; NOTE: cycles alone do not compare speed across CPUs. At the typical clock
; rates (Z80 4 MHz / 8086 5 MHz) Z80's LDIR runs 21/4 MHz = 5.25 us/byte and
; 8086 REP MOVSB runs 17.09/5 MHz = 3.42 us/byte - close in time per byte.
;
; ---- Cycle breakdown of the CHECKSUM LOOP (hand calculation) ----
;   xor bx, bx          =  3
;   mov si, imm16       =  4
;   mov cx, imm16       =  4
;   per iteration:      lodsb(12) + add bl,al(3) + adc bh,0(3) + loop(17 taken)
;                       = 35 cycles x 99
;   final iteration:    lodsb(12) + add bl,al(3) + adc bh,0(3) + loop(5, exit)
;                       = 23 cycles
;   checksum total      = 3 + 4 + 4 + 99*35 + 23 = 3499 cycles
; (I/O and print routines are excluded: their cost is UART-speed dependent.)

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
    cld                     ; Direction flag = forward (SI/DI increment)

    ; --- Build source data: byte i = i (0..99) ---
    mov di, src
    xor al, al              ; AL = 0
    mov cx, 100
.fill:
    stosb                   ; [ES:DI] = AL, DI++
    inc al
    loop .fill              ; CX--, repeat while CX != 0

    ; --- Copy body: REP MOVSB (9+17n = 1709 cycles for n=100, see breakdown above) ---
    mov si, src             ; DS:SI = source
    mov di, dst             ; ES:DI = destination
    mov cx, 100             ; byte count
    rep movsb               ; copy CX bytes, SI++/DI++ each

    ; --- Checksum: sum 100 destination bytes ---
    xor bx, bx              ; BX = 0 (16-bit accumulator: sum = 4950 > 255)
    mov si, dst
    mov cx, 100
.sum:
    lodsb                   ; AL = [DS:SI], SI++
    add bl, al
    adc bh, 0               ; carry into high byte
    loop .sum

    ; --- Verify and print result ---
    cmp bx, 0x1356          ; 0+1+...+99 = 4950 = 0x1356
    jne .fail

    mov si, msg_ok
    call print_str
    mov ax, bx
    call print_hex16
    call print_crlf
    jmp .halt

.fail:
    mov si, msg_fail
    call print_str
    mov ax, bx
    call print_hex16
    call print_crlf

.halt:
    cli
    hlt
    jmp .halt

; ---- Subroutines ----

uart_putc:
    push    dx
    push    ax
    mov     dx, 0x3FD       ; LSR (Line Status Register)
.wait:
    in      al, dx
    test    al, 0x20        ; bit 5 = THRE
    jz      .wait
    mov     dx, 0x3F8       ; THR
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

print_hex16:                ; AX in 4 hex digits
    push ax
    mov al, ah
    call print_hex8         ; high byte
    pop ax
    jmp print_hex8          ; tail call for low byte

print_hex8:
    push ax
    mov cl, 4
    shr al, cl
    call print_nibble
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
msg_ok   db "COPY OK CHECKSUM=", 0
msg_fail db "COPY FAIL CHECKSUM=", 0
src      times 100 db 0    ; filled at runtime with byte i = i
dst      times 100 db 0

times 510-($-$$) db 0
dw 0xAA55

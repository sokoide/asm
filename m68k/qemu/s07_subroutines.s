# s07_subroutines.s - Subroutines (BSR/RTS)
# Learning objectives:
#   - BSR (Branch to Subroutine) for calls
#   - RTS (Return from Subroutine)
#   - Leaf functions (no stack frame needed)
#   - MOVEM.L for register save/restore in non-leaf functions

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # Call add3(10) -> 13
    move.l  #10, %d0; bsr add3
    move.l  %d0, %d5
    lea     msg1, %a0; bsr print_str
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

    # Call add3(20) -> 23
    move.l  #20, %d0; bsr add3
    move.l  %d0, %d5
    lea     msg2, %a0; bsr print_str
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

    # Call double(add3(5)) -> 16
    move.l  #5, %d0; bsr add3; bsr double_val
    move.l  %d0, %d5
    lea     msg3, %a0; bsr print_str
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

halt:   bra     halt

# Leaf functions (no stack frame)
add3:
    add.l   #3, %d0
    rts

double_val:
    lsl.l   #1, %d0
    rts

# ---- Subroutines with stack frames ----

print_str:
    movem.l %d0/%a0, -(%sp)
.Lps_loop:
    move.b  (%a0)+, %d0
    tst.b   %d0
    beq     .Lps_done
    bsr     putchar
    bra     .Lps_loop
.Lps_done:
    movem.l (%sp)+, %d0/%a0
    rts

print_hex32:
    movem.l %d0-%d2, -(%sp)
    move.l  %d0, %d1
    moveq   #28, %d2
.Lph_loop:
    move.l  %d1, %d0
    lsr.l   %d2, %d0
    and.l   #0xf, %d0
    cmpi.b  #9, %d0
    ble     .Lph_digit
    addq.b  #7, %d0
.Lph_digit:
    addi.b  #'0', %d0
    bsr     putchar
    subq.l  #4, %d2
    bpl     .Lph_loop
    movem.l (%sp)+, %d0-%d2
    rts

print_crlf:
    movem.l %d0, -(%sp)
    move.l  #0x0d, %d0; bsr putchar
    move.l  #0x0a, %d0; bsr putchar
    movem.l (%sp)+, %d0
    rts

putchar:
    move.l  %d0, 0xff008000
    rts

# ---- Data ----
msg1: .asciz "add3(10)        = 0x"
msg2: .asciz "add3(20)        = 0x"
msg3: .asciz "double(add3(5)) = 0x"

# s02_registers.s - Registers and Arithmetic
# Learning objectives:
#   - Data registers D0-D7, address registers A0-A7
#   - MOVE.L, ADD.L, SUB.L (即値/レジスタ演算), ADDQ/SUBQ, CMPI.B
#   - LEA pseudo-instruction for address loading
#   - Hex display subroutine (print_hex32)

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg1, %a0; bsr print_str
    move.l  #0x1234, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg2, %a0; bsr print_str
    move.l  #10, %d0
    add.l   #20, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg3, %a0; bsr print_str
    move.l  #30, %d0
    sub.l   #5, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg4, %a0; bsr print_str
    move.l  #7, %d0
    move.w  #6, %d1
    mulu.w  %d1, %d0
    and.l   #0xFFFF, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg5, %a0; bsr print_str
    move.l  #100, %d0
    # DIVU result format: D0[0:15]=quotient, D0[16:31]=remainder
    divu.w  #3, %d0              | 100/3 => quotient=33 (0x21), remainder=1
    and.l   #0xFFFF, %d0         | extract quotient (lower 16 bits)
    bsr     print_hex32
    bsr     print_crlf

    lea     msg6, %a0; bsr print_str

halt:   bra     halt

# ---- Subroutines ----

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

putchar:
    move.l  %d0, 0xff008000
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
    move.l  #0x0d, %d0
    bsr     putchar
    move.l  #0x0a, %d0
    bsr     putchar
    movem.l (%sp)+, %d0
    rts

# ---- Data ----
msg1: .asciz "move.l #0x1234 -> D0=0x"
msg2: .asciz "10 + 20        = 0x"
msg3: .asciz "30 - 5         = 0x"
msg4: .asciz "7 * 6          = 0x"
msg5: .asciz "100 / 3        = 0x"
msg6: .asciz "Done!\n"

# s10_bitwise.s - Bitwise Operations
# Learning objectives:
#   - AND.L / OR.L / EOR.L for bitwise ops
#   - LSL.L / LSR.L for shift operations
#   - Display results in hex and pseudo-binary
#   - Immediate vs register operands

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # AND: 0xFF & 0x0F = 0x0F
    lea     msg_and, %a0; bsr print_str
    move.l  #0xFF, %d5
    and.l   #0x0F, %d5
    move.l  %d5, %d0; bsr print_hex8
    move.l  #0x20, %d0; bsr putchar
    move.l  %d5, %d0; bsr print_bin8
    bsr     print_crlf

    # OR: 0xF0 | 0x0F = 0xFF
    lea     msg_or, %a0; bsr print_str
    move.l  #0xF0, %d5
    or.l    #0x0F, %d5
    move.l  %d5, %d0; bsr print_hex8
    move.l  #0x20, %d0; bsr putchar
    move.l  %d5, %d0; bsr print_bin8
    bsr     print_crlf

    # EOR: 0xFF ^ 0x0F = 0xF0
    lea     msg_xor, %a0; bsr print_str
    move.l  #0xFF, %d5
    eor.l   #0x0F, %d5
    move.l  %d5, %d0; bsr print_hex8
    move.l  #0x20, %d0; bsr putchar
    move.l  %d5, %d0; bsr print_bin8
    bsr     print_crlf

    # SHL: 1 << 4 = 0x10
    lea     msg_shl, %a0; bsr print_str
    move.l  #1, %d5
    lsl.l   #4, %d5
    move.l  %d5, %d0; bsr print_hex8
    move.l  #0x20, %d0; bsr putchar
    move.l  %d5, %d0; bsr print_bin8
    bsr     print_crlf

    # SHR: 0x80 >> 3 = 0x10
    lea     msg_shr, %a0; bsr print_str
    move.l  #0x80, %d5
    lsr.l   #3, %d5
    move.l  %d5, %d0; bsr print_hex8
    move.l  #0x20, %d0; bsr putchar
    move.l  %d5, %d0; bsr print_bin8
    bsr     print_crlf

halt:   bra     halt

# ---- Subroutines ----

# print_hex8: print d0 as 2 hex digits
print_hex8:
    movem.l %d0-%d1, -(%sp)
    and.l   #0xFF, %d0
    move.l  %d0, %d1
    lsr.l   #4, %d0
    bsr     print_nibble
    move.l  %d1, %d0
    and.l   #0xF, %d0
    bsr     print_nibble
    movem.l (%sp)+, %d0-%d1
    rts

# print_nibble: print d0 (0-15) as one hex digit
print_nibble:
    cmpi.b  #9, %d0
    ble     .Lpn_digit
    addq.b  #7, %d0
.Lpn_digit:
    addi.b  #'0', %d0
    bra     putchar

# print_bin8: print d0 as 8 bits (MSB first)
print_bin8:
    movem.l %d0-%d2, -(%sp)
    and.l   #0xFF, %d0
    move.l  %d0, %d1
    moveq   #7, %d2
.Lpb_loop:
    move.l  %d1, %d0
    lsr.l   %d2, %d0
    and.l   #1, %d0
    addi.b  #'0', %d0
    bsr     putchar
    subq.l  #1, %d2
    bpl     .Lpb_loop
    movem.l (%sp)+, %d0-%d2
    rts

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
msg_and: .asciz "0xFF & 0x0F = "
msg_or:  .asciz "0xF0 | 0x0F = "
msg_xor: .asciz "0xFF ^ 0x0F = "
msg_shl: .asciz "1 << 4      = "
msg_shr: .asciz "0x80 >> 3   = "

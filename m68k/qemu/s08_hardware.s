# s08_hardware.s - Hardware Access (Goldfish RTC)
# Learning objectives:
#   - Goldfish RTC at 0xff006000
#   - Reading TIME_LOW (offset 0x00) and TIME_HIGH (offset 0x04)
#   - Memory-mapped hardware registers
#   - Observing time progression

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg_tl, %a0; bsr print_str
    move.l  0xff006000, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg_th, %a0; bsr print_str
    move.l  0xff006004, %d0
    bsr     print_hex32
    bsr     print_crlf

    move.l  #0, %d6
.Ldelay:
    addq.l  #1, %d6
    cmpi.l  #0x20000, %d6
    blt     .Ldelay

    lea     msg_tl2, %a0; bsr print_str
    move.l  0xff006000, %d0
    bsr     print_hex32
    bsr     print_crlf

    lea     msg_th2, %a0; bsr print_str
    move.l  0xff006004, %d0
    bsr     print_hex32
    bsr     print_crlf

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
    move.l  #0x0d, %d0; bsr putchar
    move.l  #0x0a, %d0; bsr putchar
    movem.l (%sp)+, %d0
    rts

# ---- Data ----
msg_tl:  .asciz "RTC TIME_LOW (1):  0x"
msg_th:  .asciz "RTC TIME_HIGH (1): 0x"
msg_tl2: .asciz "RTC TIME_LOW (2):  0x"
msg_th2: .asciz "RTC TIME_HIGH (2): 0x"

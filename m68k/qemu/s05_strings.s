# s05_strings.s - String Operations
# Learning objectives:
#   - MOVE.B for byte-level memory access
#   - Implementing strlen and strcpy in assembly
#   - Pointer arithmetic with ADDA/SUBA
#   - Null terminator detection

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg_src, %a0; bsr print_str
    lea     src, %a0; bsr print_str
    bsr     print_crlf

    # strlen: count characters until null
    lea     src, %a0
    bsr     strlen
    move.l  %d0, %d5
    lea     msg_len, %a0; bsr print_str
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

    # strcpy: copy src to dst
    lea     dst, %a0
    lea     src, %a1
    bsr     strcpy
    lea     msg_cp, %a0; bsr print_str
    lea     dst, %a0; bsr print_str
    bsr     print_crlf

halt:   bra     halt

# strlen: return length of string at a0 in d0
strlen:
    movem.l %a0, -(%sp)
    move.l  %a0, %a1
.Lsl_loop:
    tst.b   (%a0)+
    bne     .Lsl_loop
    sub.l   %a1, %a0
    move.l  %a0, %d0
    subq.l  #1, %d0
    movem.l (%sp)+, %a0
    rts

# strcpy: copy string from a1 (src) to a0 (dst)
strcpy:
    movem.l %d0/%a0/%a1, -(%sp)
.Lsc_loop:
    move.b  (%a1)+, %d0
    move.b  %d0, (%a0)+
    tst.b   %d0
    bne     .Lsc_loop
    movem.l (%sp)+, %d0/%a0/%a1
    rts

# ---- Common subroutines ----

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
msg_src: .asciz "Source: "
msg_len: .asciz "Length: 0x"
msg_cp:  .asciz "Copy:   "
src:     .asciz "Hello"
dst:     .space 32

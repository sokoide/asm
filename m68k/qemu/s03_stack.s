# s03_stack.s - Stack Operations
# Learning objectives:
#   - MOVE.L to/from stack with pre-decrement / post-increment
#   - MOVEM.L for multi-register push/pop
#   - LIFO (Last In, First Out) behavior

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg_push, %a0; bsr print_str

    lea     msg_d1, %a0; bsr print_str
    move.l  #0xAAAA, %d5
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

    lea     msg_d2, %a0; bsr print_str
    move.l  #0xBBBB, %d6
    move.l  %d6, %d0; bsr print_hex32; bsr print_crlf

    lea     msg_d3, %a0; bsr print_str
    move.l  #0xCCCC, %d7
    move.l  %d7, %d0; bsr print_hex32; bsr print_crlf

    movem.l %d5-%d7, -(%sp)

    moveq   #0, %d5
    moveq   #0, %d6
    moveq   #0, %d7

    # MOVEM.L は push (-(sp)) 時はレジスタ番号降順、pop ((sp)+) 時は昇順で
    # 自動的に転送する。このためレジスタリストの記載順序に関わらず
    # d5/d6/d7 はそれぞれ正しい値に復元される（リストを反転させる必要はない）。
    movem.l (%sp)+, %d5-%d7

    lea     msg_pop, %a0; bsr print_str
    lea     msg_p1, %a0; bsr print_str
    move.l  %d5, %d0; bsr print_hex32; bsr print_crlf

    lea     msg_p2, %a0; bsr print_str
    move.l  %d6, %d0; bsr print_hex32; bsr print_crlf

    lea     msg_p3, %a0; bsr print_str
    move.l  %d7, %d0; bsr print_hex32; bsr print_crlf

    lea     msg_ok, %a0; bsr print_str

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
msg_push: .asciz "=== Push ===\n"
msg_d1:   .asciz "  D5 = 0x"
msg_d2:   .asciz "  D6 = 0x"
msg_d3:   .asciz "  D7 = 0x"
msg_pop:  .asciz "=== Pop ===\n"
msg_p1:   .asciz "  D5 = 0x"
msg_p2:   .asciz "  D6 = 0x"
msg_p3:   .asciz "  D7 = 0x"
msg_ok:   .asciz "Stack OK!\n"

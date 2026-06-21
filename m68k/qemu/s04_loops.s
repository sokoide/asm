# s04_loops.s - Loops and Conditional Branching
# Learning objectives:
#   - DBRA (decrement and branch) for counted loops
#   - CMPI / Bcc for conditional branching
#   - Countdown, count-up, and filtered iteration

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # Countdown 5->1 (DBRA: decrement-and-branch for counted loops)
    #   d2 = 表示値 (5->1), d1 = DBRA カウンタ (4->0 で5回ループ)
    #   dbra は D1-- 後、D1 != -1 なら分岐
    lea     msg_dn, %a0; bsr print_str
    move.l  #5, %d2
    moveq   #4, %d1
.Lcd_loop:
    move.l  %d2, %d0
    addi.b  #'0', %d0
    bsr     putchar
    move.l  #0x20, %d0
    bsr     putchar
    subq.l  #1, %d2
    dbra    %d1, .Lcd_loop
    bsr     print_crlf

    # Count-up 1->5
    lea     msg_up, %a0; bsr print_str
    move.l  #1, %d1
.Lcu_loop:
    move.l  %d1, %d0
    addi.b  #'0', %d0
    bsr     putchar
    move.l  #0x20, %d0
    bsr     putchar
    addq.l  #1, %d1
    cmpi.l  #6, %d1
    blt     .Lcu_loop
    bsr     print_crlf

    # Even 2,4,6,8
    lea     msg_ev, %a0; bsr print_str
    move.l  #2, %d1
.Lev_loop:
    move.l  #0x20, %d0; bsr putchar
    move.l  %d1, %d0
    addi.b  #'0', %d0
    bsr     putchar
    addq.l  #2, %d1
    cmpi.l  #10, %d1
    blt     .Lev_loop
    bsr     print_crlf

    # Odds 1,3,5,7,9
    lea     msg_od, %a0; bsr print_str
    move.l  #1, %d1
.Lod_loop:
    move.l  #0x20, %d0; bsr putchar
    move.l  %d1, %d0
    addi.b  #'0', %d0
    bsr     putchar
    addq.l  #2, %d1
    cmpi.l  #10, %d1
    blt     .Lod_loop
    bsr     print_crlf

halt: bra halt

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

print_crlf:
    movem.l %d0, -(%sp)
    move.l  #0x0d, %d0; bsr putchar
    move.l  #0x0a, %d0; bsr putchar
    movem.l (%sp)+, %d0
    rts

# ---- Data ----
msg_dn: .asciz "Countdown: "
msg_up: .asciz "Count-up:  "
msg_ev: .asciz "Even:      "
msg_od: .asciz "Odd:       "

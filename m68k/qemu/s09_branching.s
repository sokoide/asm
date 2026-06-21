# s09_branching.s - Conditional Branching
# Learning objectives:
#   - CMP.L / CMPI.L / TST for setting condition codes
#   - BEQ / BNE (equal / not-equal)
#   - BLT / BGT (signed less-than / greater-than)
#   - BMI / BPL (negative / positive)
#   - Building decision trees with Bcc

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # Test 1: BEQ / BNE
    lea     msg_eq, %a0; bsr print_str
    move.l  #42, %d0
    move.l  #42, %d1
    cmp.l   %d1, %d0
    beq     .Lyes1
    lea     msg_no, %a0; bsr print_str
    bra     .Lnext1
.Lyes1:
    lea     msg_yes, %a0; bsr print_str
.Lnext1:

    # Test 2: BLT
    lea     msg_slt, %a0; bsr print_str
    move.l  #-5, %d0
    move.l  #10, %d1
    cmp.l   %d1, %d0
    blt     .Lyes2
    lea     msg_no, %a0; bsr print_str
    bra     .Lnext2
.Lyes2:
    lea     msg_yes, %a0; bsr print_str
.Lnext2:

    # Test 3: BGT
    lea     msg_sgt, %a0; bsr print_str
    move.l  #30, %d0
    move.l  #10, %d1
    cmp.l   %d1, %d0
    bgt     .Lyes3
    lea     msg_no, %a0; bsr print_str
    bra     .Lnext3
.Lyes3:
    lea     msg_yes, %a0; bsr print_str
.Lnext3:

    # Test 4: BMI / BPL
    lea     msg_neg, %a0; bsr print_str
    move.l  #-1, %d0
    tst.l   %d0
    bmi     .Lyes4
    lea     msg_no, %a0; bsr print_str
    bra     .Lnext4
.Lyes4:
    lea     msg_yes, %a0; bsr print_str
.Lnext4:

    # Test 5: Multiple branches
    lea     msg_ife, %a0; bsr print_str
    move.l  #50, %d0
    cmpi.l  #10, %d0
    blt     .Lsmall
    cmpi.l  #100, %d0
    bgt     .Lbig
    lea     msg_mid, %a0; bsr print_str
    bra     .Ldone5
.Lsmall:
    lea     msg_small, %a0; bsr print_str
    bra     .Ldone5
.Lbig:
    lea     msg_big, %a0; bsr print_str
.Ldone5:

    lea     msg_dn, %a0; bsr print_str

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

# ---- Data ----
msg_eq:    .asciz "42 == 42? "
msg_slt:   .asciz "-5 < 10?  "
msg_sgt:   .asciz "30 > 10?  "
msg_neg:   .asciz "-1 < 0?   "
msg_ife:   .asciz "50: "
msg_small: .asciz "small (<10)\n"
msg_mid:   .asciz "mid (10..100)\n"
msg_big:   .asciz "big (>100)\n"
msg_yes:   .asciz "Yes!\n"
msg_no:    .asciz "No!\n"
msg_dn:    .asciz "Done!\n"

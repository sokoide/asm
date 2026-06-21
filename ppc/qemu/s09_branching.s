// s09_branching.s - Scenario 9: Conditional Branching
// ========================================
// Learning objectives:
//   - CMPW / CMPWI to set Condition Register (CR)
//   - Signed comparisons: BLT, BGT, BEQ, BNE
//   - Unsigned comparisons: CMPLW (BLT/BGT act on the unsigned result)
//   - Building decision trees with branch instructions

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // --- Test 1: BEQ / BNE (equal / not-equal) ---
    lis     %r3, msg_eq@ha; addi %r3, %r3, msg_eq@l; bl print_str
    li      %r3, 42
    li      %r4, 42
    cmpw    %r3, %r4
    beq     .Lyes1
    lis     %r3, msg_no@ha; addi %r3, %r3, msg_no@l; bl print_str
    b       .Lnext1
.Lyes1:
    lis     %r3, msg_yes@ha; addi %r3, %r3, msg_yes@l; bl print_str
.Lnext1:

    // --- Test 2: BLT (signed less than) ---
    lis     %r3, msg_slt@ha; addi %r3, %r3, msg_slt@l; bl print_str
    li      %r3, -5
    li      %r4, 10
    cmpw    %r3, %r4
    blt     .Lyes2
    lis     %r3, msg_no@ha; addi %r3, %r3, msg_no@l; bl print_str
    b       .Lnext2
.Lyes2:
    lis     %r3, msg_yes@ha; addi %r3, %r3, msg_yes@l; bl print_str
.Lnext2:

    // --- Test 3: BGT (signed greater than) ---
    lis     %r3, msg_sgt@ha; addi %r3, %r3, msg_sgt@l; bl print_str
    li      %r3, 30
    li      %r4, 10
    cmpw    %r3, %r4
    bgt     .Lyes3
    lis     %r3, msg_no@ha; addi %r3, %r3, msg_no@l; bl print_str
    b       .Lnext3
.Lyes3:
    lis     %r3, msg_yes@ha; addi %r3, %r3, msg_yes@l; bl print_str
.Lnext3:

    // --- Test 4: Unsigned greater-than (CMPLW) ---
    //   -1 reads as 0xFFFFFFFF unsigned, so it is greater than 1.
    lis     %r3, msg_uns@ha; addi %r3, %r3, msg_uns@l; bl print_str
    li      %r3, -1
    li      %r4, 1
    cmplw   %r3, %r4
    bgt     .Lyes4
    lis     %r3, msg_no@ha; addi %r3, %r3, msg_no@l; bl print_str
    b       .Lnext4
.Lyes4:
    lis     %r3, msg_yes@ha; addi %r3, %r3, msg_yes@l; bl print_str
.Lnext4:

    // --- Test 5: if-else chain (decision tree) ---
    lis     %r3, msg_ife@ha; addi %r3, %r3, msg_ife@l; bl print_str
    li      %r3, 50
    cmpwi   %r3, 10
    blt     .Lsmall
    cmpwi   %r3, 100
    bgt     .Lbig
    lis     %r3, msg_mid@ha; addi %r3, %r3, msg_mid@l; bl print_str
    b       .Ldone5
.Lsmall:
    lis     %r3, msg_small@ha; addi %r3, %r3, msg_small@l; bl print_str
    b       .Ldone5
.Lbig:
    lis     %r3, msg_big@ha; addi %r3, %r3, msg_big@l; bl print_str
.Ldone5:

    lis     %r3, msg_dn@ha; addi %r3, %r3, msg_dn@l; bl print_str

halt:   b       halt

// ---- Subroutines ----

print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r4, %r3
.Lps_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .Lps_done
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1
    b       .Lps_loop
.Lps_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lup_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .Lup_wait
    stb     %r3, 0(%r8)
    blr

// ---- Data ----
msg_eq:    .asciz "42 == 42? "
msg_slt:   .asciz "-5 < 10?  "
msg_sgt:   .asciz "30 > 10?  "
msg_uns:   .asciz "u(-1) > 1? "
msg_ife:   .asciz "50: "
msg_small: .asciz "small (<10)\n"
msg_mid:   .asciz "mid (10..100)\n"
msg_big:   .asciz "big (>100)\n"
msg_yes:   .asciz "Yes!\n"
msg_no:    .asciz "No!\n"
msg_dn:    .asciz "Done!\n"

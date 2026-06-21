// s09_branching.s - Scenario 9: Conditional Branching
// ========================================
// Learning objectives:
//   - CMP / TST to set condition flags (NZCV)
//   - B.EQ / B.NE (equal / not-equal)
//   - B.LT / B.GT (signed less-than / greater-than)
//   - B.MI / B.PL (negative / positive)
//   - B.LO / B.HI (unsigned lower / higher)
//   - Building decision trees with B.cond

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Test 1: B.EQ / B.NE (equal)
    ldr     x0, =msg_eq
    bl      print_str
    mov     x0, #42
    mov     x1, #42
    cmp     x0, x1
    b.eq    .Lyes1
    ldr     x0, =msg_no
    bl      print_str
    b       .Lnext1
.Lyes1:
    ldr     x0, =msg_yes
    bl      print_str
.Lnext1:

    // Test 2: B.LT (signed less-than)
    ldr     x0, =msg_slt
    bl      print_str
    mov     x0, #-5
    mov     x1, #10
    cmp     x0, x1
    b.lt    .Lyes2
    ldr     x0, =msg_no
    bl      print_str
    b       .Lnext2
.Lyes2:
    ldr     x0, =msg_yes
    bl      print_str
.Lnext2:

    // Test 3: B.GT (signed greater-than)
    ldr     x0, =msg_sgt
    bl      print_str
    mov     x0, #30
    mov     x1, #10
    cmp     x0, x1
    b.gt    .Lyes3
    ldr     x0, =msg_no
    bl      print_str
    b       .Lnext3
.Lyes3:
    ldr     x0, =msg_yes
    bl      print_str
.Lnext3:

    // Test 4: B.MI / B.PL (sign test via TST)
    ldr     x0, =msg_neg
    bl      print_str
    mov     x0, #-1
    tst     x0, x0
    b.mi    .Lyes4
    ldr     x0, =msg_no
    bl      print_str
    b       .Lnext4
.Lyes4:
    ldr     x0, =msg_yes
    bl      print_str
.Lnext4:

    // Test 5: B.HI (unsigned higher) — -1 reads as 0xFFFF...FFFF unsigned
    ldr     x0, =msg_uns
    bl      print_str
    mov     x0, #-1
    mov     x1, #1
    cmp     x0, x1
    b.hi    .Lyes5
    ldr     x0, =msg_no
    bl      print_str
    b       .Lnext5
.Lyes5:
    ldr     x0, =msg_yes
    bl      print_str
.Lnext5:

    // Test 6: if-else chain (decision tree)
    ldr     x0, =msg_ife
    bl      print_str
    mov     x0, #50
    cmp     x0, #10
    b.lt    .Lsmall
    cmp     x0, #100
    b.gt    .Lbig
    ldr     x0, =msg_mid
    bl      print_str
    b       .Ldone6
.Lsmall:
    ldr     x0, =msg_small
    bl      print_str
    b       .Ldone6
.Lbig:
    ldr     x0, =msg_big
    bl      print_str
.Ldone6:

    ldr     x0, =msg_dn
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Subroutines ----

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
.Lps_loop:
    ldrb    w5, [x4]
    cbz     w5, .Lps_done
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       .Lps_loop
.Lps_done:
    ldp     x29, x30, [sp], #16
    ret

uart_putc:
    movz    x8, #0x0900, lsl #16
.Lup_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, .Lup_wait
    strb    w0, [x8]
    ret

// ---- Data ----
msg_eq:    .asciz "42 == 42? "
msg_slt:   .asciz "-5 < 10?  "
msg_sgt:   .asciz "30 > 10?  "
msg_neg:   .asciz "-1 < 0?   "
msg_uns:   .asciz "u(-1) > 1? "
msg_ife:   .asciz "50: "
msg_small: .asciz "small (<10)\n"
msg_mid:   .asciz "mid (10..100)\n"
msg_big:   .asciz "big (>100)\n"
msg_yes:   .asciz "Yes!\n"
msg_no:    .asciz "No!\n"
msg_dn:    .asciz "Done!\n"

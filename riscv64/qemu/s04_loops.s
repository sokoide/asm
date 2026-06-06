// s04_loops.s - Scenario 4: Loops (RV64I)
// =========================================
// Learning objectives:
//   - ADDI + BNE for countdown loops
//   - ADDI + BLT for count-up loops
//   - BGE / BGTZ for conditional loops
//   - Loop counter in a register

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: Countdown 5..1
    la      a0, msg_down
    jal     ra, print_str
    li      s0, 5
.down:
    mv      a0, s0
    jal     ra, print_dec
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, -1
    bnez    s0, .down
    la      a0, newline
    jal     ra, print_str

    // Demo 2: Count up 0..4
    la      a0, msg_up
    jal     ra, print_str
    li      s0, 0
    li      s1, 5
.up:
    mv      a0, s0
    jal     ra, print_dec
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, 1
    blt     s0, s1, .up
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Sum 1..10
    la      a0, msg_sum
    jal     ra, print_str
    li      s0, 1
    li      s1, 11
    li      s2, 0
.sum:
    add     s2, s2, s0
    addi    s0, s0, 1
    blt     s0, s1, .sum
    mv      a0, s2
    jal     ra, print_dec
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

print_str:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    sd      s0, 0(sp)
    mv      s0, a0
.ps_loop:
    lbu     t1, 0(s0)
    beqz    t1, .ps_ret
    mv      a0, t1
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .ps_loop
.ps_ret:
    ld      s0, 0(sp)
    ld      ra, 8(sp)
    addi    sp, sp, 16
    ret

print_dec:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s0, a0
    bnez    s0, .pd_nonzero
    li      a0, '0'
    jal     ra, uart_putc
    j       .pd_done
.pd_nonzero:
    addi    sp, sp, -80
    li      s2, 0
.pd_extract:
    beqz    s0, .pd_print_digits
    li      t0, 10
    remu    t1, s0, t0
    divu    s0, s0, t0
    addi    t1, t1, '0'
    addi    sp, sp, -8
    sd      t1, 0(sp)
    addi    s2, s2, 1
    j       .pd_extract
.pd_print_digits:
    beqz    s2, .pd_digits_done
    ld      a0, 0(sp)
    addi    sp, sp, 8
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .pd_print_digits
.pd_digits_done:
    addi    sp, sp, 80
.pd_done:
    ld      s1, 8(sp)
    ld      s0, 16(sp)
    ld      ra, 24(sp)
    addi    sp, sp, 32
    ret

uart_putc:
    li      t0, 0x10000000
.wait:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x20
    beqz    t1, .wait
    sb      a0, 0(t0)
    ret

// ---- Data ----
msg_down: .asciz "Countdown: "
msg_up:   .asciz "Count up:  "
msg_sum:  .asciz "Sum 1..10: "
newline:  .asciz "\n"

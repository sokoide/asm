// s04_loops.s - Scenario 4: Loops
// ================================
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

    li      s0, 5                 // counter = 5
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

    li      s0, 0                 // counter = 0
    li      s1, 5                 // limit = 5
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

    li      s0, 1                 // i = 1
    li      s1, 11                // limit = 11
    li      s2, 0                 // sum = 0
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

// ---- Common subroutines ----

print_str:
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    mv      s0, a0
.loop:
    lbu     t1, 0(s0)
    beqz    t1, .ret
    mv      a0, t1
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .loop
.ret:
    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

print_dec:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s0, a0               // value
    li      s1, 10               // divisor
    // Handle 0
    bnez    s0, .nonzero
    li      a0, '0'
    jal     ra, uart_putc
    j       .done
.nonzero:
    // Extract digits (max 10 digits for 32-bit)
    addi    sp, sp, -40          // digit buffer on stack
    li      s2, 0                // digit count
.extract:
    beqz    s0, .print_digits
    li      t0, 10
    remu    t1, s0, t0           // t1 = s0 % 10
    divu    s0, s0, t0           // s0 = s0 / 10
    addi    t1, t1, '0'
    addi    sp, sp, -4
    sw      t1, 0(sp)            // push digit
    addi    s2, s2, 1
    j       .extract
.print_digits:
    beqz    s2, .digits_done
    lw      a0, 0(sp)            // pop digit
    addi    sp, sp, 4
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .print_digits
.digits_done:
    addi    sp, sp, 40           // restore digit buffer
.done:
    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
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

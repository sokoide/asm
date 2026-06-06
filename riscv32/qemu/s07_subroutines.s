// s07_subroutines.s - Scenario 7: Subroutines (JAL/RET)
// =====================================================
// Learning objectives:
//   - JAL (jump and link) and RET
//   - Parameter passing in A0-A7
//   - Return value in A0
//   - Callee-saved registers S0-S11
//   - Nested subroutine calls

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // add3(10)
    li      a0, 10
    jal     ra, add3
    la      s0, msg1
    jal     ra, show_result

    // add3(20)
    li      a0, 20
    jal     ra, add3
    la      s0, msg2
    jal     ra, show_result

    // add3(30)
    li      a0, 30
    jal     ra, add3
    la      s0, msg3
    jal     ra, show_result

    // Nested: double(add3(5))
    li      a0, 5
    jal     ra, add3              // a0 = 8
    jal     ra, double_val        // a0 = 16
    la      s0, msg4
    jal     ra, show_result

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Subroutines ----

// add3: return a0 + 3
add3:
    addi    a0, a0, 3
    ret

// double_val: return a0 * 2
double_val:
    slli    a0, a0, 1
    ret

// show_result: print label (s0) and hex value (a0)
show_result:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s1, a0               // save result
    mv      a0, s0
    jal     ra, print_str
    mv      a0, s1
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str
    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
    ret

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

print_hex32:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s0, a0
    li      s1, 28
.hex_loop:
    srl     a0, s0, s1
    andi    a0, a0, 0xF
    li      t0, 9
    bgt     a0, t0, .alpha
    addi    a0, a0, '0'
    j       .print
.alpha:
    addi    a0, a0, ('A' - 10)
.print:
    jal     ra, uart_putc
    addi    s1, s1, -4
    bgez    s1, .hex_loop
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
msg1:    .asciz "add3(10)         = 0x"
msg2:    .asciz "add3(20)         = 0x"
msg3:    .asciz "add3(30)         = 0x"
msg4:    .asciz "double(add3(5))  = 0x"
newline: .asciz "\n"

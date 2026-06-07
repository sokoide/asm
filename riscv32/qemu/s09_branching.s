// s09_branching.s - Scenario 9: Conditional Branching
// =====================================================
// Learning objectives:
//   - BEQ / BNE — branch if equal / not equal
//   - BLT / BGE — branch if less than / greater or equal (signed)
//   - BLTU / BGEU — unsigned comparisons
//   - SLT / SLTI — set on less than
//   - Jump table (indirect branch via JALR)

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: BEQ / BNE
    la      a0, msg_beq
    jal     ra, print_str
    li      a0, 5
    li      a1, 5
    bne     a0, a1, .not_equal1
    la      a0, msg_yes
    jal     ra, print_str
    j       .next1
.not_equal1:
    la      a0, msg_no
    jal     ra, print_str
.next1:

    // Demo 2: BLT signed
    la      a0, msg_blt
    jal     ra, print_str
    li      a0, -1
    li      a1, 1
    blt     a0, a1, .less_yes
    la      a0, msg_no
    jal     ra, print_str
    j       .next2
.less_yes:
    la      a0, msg_yes
    jal     ra, print_str
.next2:

    // Demo 3: BLTU unsigned
    la      a0, msg_bltu
    jal     ra, print_str
    li      a0, -1               // 0xFFFFFFFF unsigned
    li      a1, 1
    bltu    a0, a1, .lessu_yes
    la      a0, msg_no
    jal     ra, print_str
    j       .next3
.lessu_yes:
    la      a0, msg_yes
    jal     ra, print_str
.next3:

    // Demo 4: SLT
    la      a0, msg_slt
    jal     ra, print_str
    li      a0, -5
    li      a1, 3
    slt     a2, a0, a1           // a2 = (-5 < 3) ? 1 : 0
    mv      a0, a2
    jal     ra, print_dec
    la      a0, newline
    jal     ra, print_str

    // Demo 5: Jump table
    la      a0, msg_table
    jal     ra, print_str
    li      a0, 2                 // index = 2
    jal     ra, jump_table_demo

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Jump table demonstration ----

jump_table_demo:
    addi    sp, sp, -4
    sw      ra, 0(sp)
    la      t0, jt_base
    slli    a0, a0, 2            // index * 4 (word size)
    add     t0, t0, a0
    lw      t0, 0(t0)            // load target address
    jalr    x0, 0(t0)            // jump to target

jt_base:
    .word   jt_case0
    .word   jt_case1
    .word   jt_case2
    .word   jt_case3

jt_case0:
    la      a0, msg_case0
    jal     ra, print_str
    j       jt_done
jt_case1:
    la      a0, msg_case1
    jal     ra, print_str
    j       jt_done
jt_case2:
    la      a0, msg_case2
    jal     ra, print_str
    j       jt_done
jt_case3:
    la      a0, msg_case3
    jal     ra, print_str
    j       jt_done

jt_done:
    lw      ra, 0(sp)
    addi    sp, sp, 4
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

print_dec:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s0, a0
    bnez    s0, .nonzero
    li      a0, '0'
    jal     ra, uart_putc
    j       .done
.nonzero:
    li      s2, 0
.extract:
    beqz    s0, .print_digits
    li      t0, 10
    remu    t1, s0, t0
    divu    s0, s0, t0
    addi    t1, t1, '0'
    addi    sp, sp, -4
    sw      t1, 0(sp)
    addi    s2, s2, 1
    j       .extract
.print_digits:
    beqz    s2, .done
    lw      a0, 0(sp)
    addi    sp, sp, 4
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .print_digits
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
msg_beq:   .asciz "5 == 5? "
msg_blt:   .asciz "-1 < 1 (signed)? "
msg_bltu:  .asciz "0xFFFFFFFF < 1 (unsigned)? "
msg_slt:   .asciz "slt(-5, 3) = "
msg_table: .asciz "Jump table[2]: "
msg_yes:   .asciz "yes\n"
msg_no:    .asciz "no\n"
msg_case0: .asciz "case 0\n"
msg_case1: .asciz "case 1\n"
msg_case2: .asciz "case 2\n"
msg_case3: .asciz "case 3\n"
newline:   .asciz "\n"

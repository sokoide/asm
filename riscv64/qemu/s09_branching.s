// s09_branching.s - Scenario 9: Conditional Branching (RV64I)
// ============================================================
// Learning objectives:
//   - BEQ / BNE — branch if equal / not equal
//   - BLT / BGE — signed comparisons
//   - BLTU / BGEU — unsigned comparisons
//   - SLT / SLTI — set on less than
//   - Jump table via JALR

.section .text
.global _start

_start:
    li      sp, 0x80200000

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

    la      a0, msg_bltu
    jal     ra, print_str
    li      a0, -1
    li      a1, 1
    bltu    a0, a1, .lessu_yes
    la      a0, msg_no
    jal     ra, print_str
    j       .next3
.lessu_yes:
    la      a0, msg_yes
    jal     ra, print_str
.next3:

    la      a0, msg_slt
    jal     ra, print_str
    li      a0, -5
    li      a1, 3
    slt     a2, a0, a1
    mv      a0, a2
    jal     ra, print_dec
    la      a0, newline
    jal     ra, print_str

    la      a0, msg_table
    jal     ra, print_str
    li      a0, 2
    jal     ra, jump_table_demo

    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

jump_table_demo:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    la      t0, jt_base
    slli    a0, a0, 3            // index * 8 (64-bit word)
    add     t0, t0, a0
    ld      t0, 0(t0)
    jalr    x0, 0(t0)

jt_base:
    .dword  jt_case0
    .dword  jt_case1
    .dword  jt_case2
    .dword  jt_case3

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
    ld      ra, 8(sp)
    addi    sp, sp, 16
    ret

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
msg_beq:   .asciz "5 == 5? "
msg_blt:   .asciz "-1 < 1 (signed)? "
msg_bltu:  .asciz "0xFFFFFFFFFFFFFFFF < 1 (unsigned)? "
msg_slt:   .asciz "slt(-5, 3) = "
msg_table: .asciz "Jump table[2]: "
msg_yes:   .asciz "yes\n"
msg_no:    .asciz "no\n"
msg_case0: .asciz "case 0\n"
msg_case1: .asciz "case 1\n"
msg_case2: .asciz "case 2\n"
msg_case3: .asciz "case 3\n"
newline:   .asciz "\n"

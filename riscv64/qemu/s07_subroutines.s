// s07_subroutines.s - Scenario 7: Subroutines (RV64I)
// ====================================================
// Learning objectives:
//   - JAL (jump and link) and RET
//   - Parameter passing in A0-A7
//   - Return value in A0
//   - Callee-saved registers S0-S11 (64-bit)
//   - Nested subroutine calls

.section .text
.global _start

_start:
    li      sp, 0x80200000

    li      a0, 10
    jal     ra, add3
    la      s0, msg1
    jal     ra, show_result

    li      a0, 20
    jal     ra, add3
    la      s0, msg2
    jal     ra, show_result

    li      a0, 30
    jal     ra, add3
    la      s0, msg3
    jal     ra, show_result

    li      a0, 5
    jal     ra, add3
    jal     ra, double_val
    la      s0, msg4
    jal     ra, show_result

    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

add3:
    addi    a0, a0, 3
    ret

double_val:
    slli    a0, a0, 1
    ret

show_result:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s1, a0
    mv      a0, s0
    jal     ra, print_str
    mv      a0, s1
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str
    ld      s1, 8(sp)
    ld      s0, 16(sp)
    ld      ra, 24(sp)
    addi    sp, sp, 32
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

print_hex64:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s0, a0
    li      s1, 60
.ph_loop:
    srl     a0, s0, s1
    andi    a0, a0, 0xF
    li      t0, 9
    bgt     a0, t0, .ph_alpha
    addi    a0, a0, '0'
    j       .ph_print
.ph_alpha:
    addi    a0, a0, ('A' - 10)
.ph_print:
    jal     ra, uart_putc
    addi    s1, s1, -4
    bgez    s1, .ph_loop
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
msg1:    .asciz "add3(10)         = 0x"
msg2:    .asciz "add3(20)         = 0x"
msg3:    .asciz "add3(30)         = 0x"
msg4:    .asciz "double(add3(5))  = 0x"
newline: .asciz "\n"

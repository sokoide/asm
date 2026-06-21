// s02_registers.s - Scenario 2: Registers and Arithmetic (RV64I)
// ================================================================
// Learning objectives:
//   - RISC-V x0-x31 registers (64-bit) and ABI names
//   - LI / MV for loading and moving values
//   - ADD / SUB / ADDI for arithmetic
//   - Print 64-bit hexadecimal output subroutine

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Test 1: LI (load immediate)
    la      a0, msg1_li
    jal     ra, print_str
    li      a0, 0x1234
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Test 2: ADD (10 + 20)
    la      a0, msg2_add
    jal     ra, print_str
    li      a0, 10
    li      a1, 20
    add     a2, a0, a1
    mv      a0, a2
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Test 3: SUB (30 - 5)
    la      a0, msg3_sub
    jal     ra, print_str
    li      a0, 30
    li      a1, 5
    sub     a2, a0, a1
    mv      a0, a2
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Test 4: ADDI (INC: 99 + 1)
    la      a0, msg4_inc
    jal     ra, print_str
    li      a0, 99
    addi    a0, a0, 1
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Test 5: ADDI (DEC: 51 - 1)
    la      a0, msg5_dec
    jal     ra, print_str
    li      a0, 51
    addi    a0, a0, -1
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Common subroutines ----

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
msg1_li:   .asciz "li a0, 0x1234     -> A0=0x"
msg2_add:  .asciz "10 + 20           = 0x"
msg3_sub:  .asciz "30 - 5            = 0x"
msg4_inc:  .asciz "INC(99)          = 0x"
msg5_dec:  .asciz "DEC(51)          = 0x"
newline:   .asciz "\n"

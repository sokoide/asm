// s03_stack.s - Scenario 3: Stack Operations (RV64I)
// ====================================================
// Learning objectives:
//   - RISC-V has no PUSH/POP — use ADDI SP + SD/LD
//   - Stack grows downward, 16-byte aligned on RV64I
//   - LIFO: Last In, First Out
//   - 64-bit register save/restore

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: Basic push/pop
    la      a0, msg1
    jal     ra, print_str

    li      a0, 0x41
    jal     ra, push_a0
    li      a0, 0x42
    jal     ra, push_a0
    li      a0, 0x43
    jal     ra, push_a0

    jal     ra, pop_a0
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc
    jal     ra, pop_a0
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc
    jal     ra, pop_a0
    jal     ra, uart_putc
    la      a0, newline
    jal     ra, print_str

    // Demo 2: Save/restore callee-saved registers
    la      a0, msg2
    jal     ra, print_str

    li      s0, 0x10
    li      s1, 0x20

    addi    sp, sp, -16
    sd      s0, 0(sp)
    sd      s1, 8(sp)

    li      s0, 0xFF
    li      s1, 0x00

    ld      s0, 0(sp)
    ld      s1, 8(sp)
    addi    sp, sp, 16

    mv      a0, s0
    jal     ra, print_hex64
    li      a0, ' '
    jal     ra, uart_putc
    mv      a0, s1
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Stack frame with ra save
    la      a0, msg3
    jal     ra, print_str
    li      a0, 42
    jal     ra, add_ten
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

push_a0:
    addi    sp, sp, -8
    sd      a0, 0(sp)
    ret

pop_a0:
    ld      a0, 0(sp)
    addi    sp, sp, 8
    ret

add_ten:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    addi    a0, a0, 10
    jal     ra, print_hex64
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
msg1:  .asciz "--- Stack Push/Pop ---\n"
msg2:  .asciz "Restore s0,s1: "
msg3:  .asciz "42+10 = 0x"
newline: .asciz "\n"

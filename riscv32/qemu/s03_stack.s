// s03_stack.s - Scenario 3: Stack Operations
// ===========================================
// Learning objectives:
//   - RISC-V has no PUSH/POP — use ADDI SP + SW/LW
//   - Stack grows downward (push = subtract SP)
//   - LIFO: Last In, First Out
//   - Saving/restoring multiple registers
//   - Stack frame convention

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: Basic push/pop
    la      a0, msg1
    jal     ra, print_str

    li      a0, 0x41              // 'A'
    jal     ra, push_a0
    li      a0, 0x42              // 'B'
    jal     ra, push_a0
    li      a0, 0x43              // 'C'
    jal     ra, push_a0

    // Pop and print (C, B, A — LIFO order)
    jal     ra, pop_a0
    jal     ra, uart_putc         // prints 'C'
    li      a0, ' '
    jal     ra, uart_putc
    jal     ra, pop_a0
    jal     ra, uart_putc         // prints 'B'
    li      a0, ' '
    jal     ra, uart_putc
    jal     ra, pop_a0
    jal     ra, uart_putc         // prints 'A'
    la      a0, newline
    jal     ra, print_str

    // Demo 2: Save/restore callee-saved registers
    la      a0, msg2
    jal     ra, print_str

    li      s0, 0x10
    li      s1, 0x20

    // Save s0, s1 to stack
    addi    sp, sp, -8
    sw      s0, 0(sp)
    sw      s1, 4(sp)

    // Clobber s0, s1
    li      s0, 0xFF
    li      s1, 0x00

    // Restore s0, s1 from stack
    lw      s0, 0(sp)
    lw      s1, 4(sp)
    addi    sp, sp, 8

    // Print restored values
    mv      a0, s0
    jal     ra, print_hex32
    li      a0, ' '
    jal     ra, uart_putc
    mv      a0, s1
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Stack frame with ra save
    la      a0, msg3
    jal     ra, print_str
    li      a0, 42
    jal     ra, add_ten           // should print 52
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Push/pop helpers ----

push_a0:
    addi    sp, sp, -4
    sw      a0, 0(sp)
    ret

pop_a0:
    lw      a0, 0(sp)
    addi    sp, sp, 4
    ret

// ---- Subroutines ----

add_ten:
    addi    sp, sp, -4
    sw      ra, 0(sp)
    addi    a0, a0, 10
    jal     ra, print_hex32
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

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
msg1:  .asciz "--- Stack Push/Pop ---\n"
msg2:  .asciz "Restore s0,s1: "
msg3:  .asciz "42+10 = 0x"
newline: .asciz "\n"

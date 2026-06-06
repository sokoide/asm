// s01_hello.s - Scenario 1: Hello World
// ========================================
// Learning objectives:
//   - RISC-V bare-metal program structure
//   - UART NS16550A output on QEMU virt machine
//   - LI pseudo-instruction for loading constants
//   - LB/SB for byte-level memory access
//   - Null-terminated string iteration
//   - SiFive test finisher for QEMU exit

.section .text
.global _start

_start:
    // Set up stack pointer
    li      sp, 0x80200000

    // Print message
    la      a0, message
    jal     ra, print_str

    // Exit via SiFive test finisher
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Subroutines ----

// print_str: print null-terminated string at a0
// Uses s0 (callee-saved) as string pointer
print_str:
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    mv      s0, a0             // s0 = string pointer
.loop:
    lbu     t1, 0(s0)          // load byte (unsigned)
    beqz    t1, .ret           // if null, done
    mv      a0, t1             // character to a0
    jal     ra, uart_putc      // print character
    addi    s0, s0, 1          // next byte
    j       .loop
.ret:
    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

// uart_putc: write character in a0 to NS16550A THR
uart_putc:
    li      t0, 0x10000000     // UART base address
.wait:
    lbu     t1, 5(t0)          // read LSR
    andi    t1, t1, 0x20       // bit 5 = THRE
    beqz    t1, .wait          // wait if TX FIFO full
    sb      a0, 0(t0)          // write byte to THR
    ret

// ---- Data ----
message:
    .asciz "Hello, RISC-V World!\n"

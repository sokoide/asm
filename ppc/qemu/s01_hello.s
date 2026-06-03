// s01_hello.s - Scenario 1: Hello World
// ========================================
// Learning objectives:
//   - PPC bare-metal program structure
//   - 16550 UART output at 0xef600300
//   - LIS/ORI for loading 32-bit constants
//   - STB for MMIO byte write
//   - BL/BLR for subroutine calls

.section .text
.global _start

_start:
    // Set up stack
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Print message
    lis     %r3, msg1@ha
    addi    %r3, %r3, msg1@l
    bl      print_str

    // Halt
halt:
    b       halt

// ---- Subroutines ----

// print_str: print null-terminated string at r3
// Saves LR because it calls uart_putc
print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)

    mr      %r4, %r3
.ps_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .ps_done
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1
    b       .ps_loop
.ps_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// uart_putc: write char in r3 to UART (leaf function)
uart_putc:
    lis     %r8, 0xef60
    ori     %r8, %r8, 0x0300
.up_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .up_wait
    stb     %r3, 0(%r8)
    blr

// ---- Data ----
msg1:
    .asciz "Hello, PowerPC World!\n"

// s06_serial_in.s - Scenario 6: Serial Input
// ========================================
// Learning objectives:
//   - 16550 UART receive (LSR bit 0 = Data Ready)
//   - Polling loop for serial input
//   - Echo characters back to terminal
//   - Enter key (0x0D) to quit

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    lis     %r3, msg_intro@ha; addi %r3, %r3, msg_intro@l; bl print_str

    // Read and echo characters until Enter
.Linput_loop:
    bl      uart_getc
    mr      %r4, %r3              // save received char
    // Echo the character back
    mr      %r3, %r4
    bl      uart_putc
    // Check for Enter (CR = 0x0D)
    cmpwi   %r4, 0x0D
    beq     .Ldone
    b       .Linput_loop

.Ldone:
    lis     %r3, msg_bye@ha; addi %r3, %r3, msg_bye@l; bl print_str

halt:   b       halt

// ---- Subroutines ----

print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r4, %r3
.Lps_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .Lps_done
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1
    b       .Lps_loop
.Lps_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// uart_putc: write char in r3 to UART (leaf function)
uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lup_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .Lup_wait
    stb     %r3, 0(%r8)
    blr

// uart_getc: read char from UART into r3 (leaf function)
uart_getc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lug_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x01      // Check LSR bit 0 (Data Ready)
    beq     .Lug_wait
    lbz     %r3, 0(%r8)          // Read received char from RBR
    blr

// ---- Data ----
msg_intro: .asciz "Type chars (Enter=quit):\n"
msg_bye:   .asciz "Bye!\n"
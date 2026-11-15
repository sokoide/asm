// s04_loops.s - Scenario 4: Loops and Conditional Branching
// ========================================
// Learning objectives:
//   - Countdown loop with ADDIC. + BNE
//   - Count-up loop with ADDI + CMPWI + BLT
//   - Even-number filter with ANDI. (bit test)
//   - Loop counter management with R30

.section .text
.global _start
_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // ---- Countdown 5 -> 1 ----
    lis     %r3, msg_dn@ha; addi %r3,%r3,msg_dn@l; bl print_str
    li      %r30, 5                // counter = 5
.cd:
    addi    %r3, %r30, 0x30        // digit = counter + '0'
    bl      uart_putc
    li      %r3, 0x20              // space
    bl      uart_putc
    addic.  %r30, %r30, -1         // counter-- (sets CR0)
    bne     .cd                    // loop while counter != 0
    bl      print_crlf

    // ---- Count-up 1 -> 5 ----
    lis     %r3, msg_up@ha; addi %r3,%r3,msg_up@l; bl print_str
    li      %r30, 1                // counter = 1
.cu:
    addi    %r3, %r30, 0x30        // digit = counter + '0'
    bl      uart_putc
    li      %r3, 0x20              // space
    bl      uart_putc
    addi    %r30, %r30, 1          // counter++
    cmpwi   %r30, 6                // counter < 6?
    blt     .cu                    // loop while counter < 6
    bl      print_crlf

    // ---- Even numbers 2, 4, 6, 8 ----
    lis     %r3, msg_ev@ha; addi %r3,%r3,msg_ev@l; bl print_str
    li      %r30, 2                // counter = 2
.ev:
    andi.   %r9, %r30, 1          // test bit 0 (odd/even)
    bne     .sk                    // skip if odd
    addi    %r3, %r30, 0x30        // digit = counter + '0'
    bl      uart_putc
    li      %r3, 0x20              // space
    bl      uart_putc
.sk:
    addi    %r30, %r30, 1          // counter++
    cmpwi   %r30, 10               // counter < 10?
    blt     .ev                    // loop while counter < 10
    bl      print_crlf

halt:   b       halt

// ---- Subroutines ----

print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r4, %r3
.ps:
    lbz     %r5, 0(%r4)            // load byte from string
    cmpwi   %r5, 0                 // null terminator?
    beq     .pd
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1            // advance pointer
    b       .ps
.pd:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

print_crlf:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    li      %r3, 0x0D              // CR
    bl      uart_putc
    li      %r3, 0x0A              // LF
    bl      uart_putc
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300       // UART base = 0xEF600300
.uw:
    lbz     %r9, 5(%r8)            // read LSR (offset 5)
    andi.   %r9, %r9, 0x20         // THRE (bit 5) set?
    beq     .uw                     // wait until ready
    stb     %r3, 0(%r8)            // write char to THR
    blr

// ---- Data ----
msg_dn: .asciz "Countdown: "
msg_up: .asciz "Count-up:  "
msg_ev: .asciz "Even:      "

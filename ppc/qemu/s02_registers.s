// s02_registers.s - Scenario 2: Registers and Arithmetic
// ========================================
// Learning objectives:
//   - General-purpose registers: R3-R31
//   - ADDI, ADD, SUBF for arithmetic
//   - LIS/ORI for loading 32-bit constants
//   - Hex display subroutine (print_hex32)

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // MOV: load 32-bit constant using LIS/ORI
    lis     %r3, msg1@ha; addi %r3, %r3, msg1@l; bl print_str
    lis     %r3, 0x0000; ori %r3, %r3, 0x1234
    bl      print_hex32
    bl      print_crlf

    // ADD: 10 + 20 = 30 (0x1E)
    lis     %r3, msg2@ha; addi %r3, %r3, msg2@l; bl print_str
    addi    %r3, %r0, 10
    addi    %r4, %r0, 20
    add     %r3, %r3, %r4
    bl      print_hex32
    bl      print_crlf

    // SUBF: 30 - 5 = 25 (0x19)
    lis     %r3, msg3@ha; addi %r3, %r3, msg3@l; bl print_str
    addi    %r3, %r0, 30
    addi    %r4, %r0, 5
    subf    %r3, %r4, %r3
    bl      print_hex32
    bl      print_crlf

    // Done
    lis     %r3, msg4@ha; addi %r3, %r3, msg4@l; bl print_str

halt:   b       halt

// ---- Subroutines ----

// print_str: print null-terminated string at r3
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

// print_hex32: print r3 as 8 hex digits
print_hex32:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 12(%r1)
    mr      %r31, %r3
    addi    %r4, %r0, 28
.Lph_loop:
    srw     %r3, %r31, %r4
    andi.   %r3, %r3, 0xF
    cmpwi   %r3, 9
    ble     .Lph_digit
    addi    %r3, %r3, 7
.Lph_digit:
    addi    %r3, %r3, 0x30
    bl      uart_putc
    addic.  %r4, %r4, -4
    bge     .Lph_loop
    lwz     %r31, 12(%r1)
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// print_crlf: print CR+LF
print_crlf:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    addi    %r3, %r0, 0x0D
    bl      uart_putc
    addi    %r3, %r0, 0x0A
    bl      uart_putc
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// uart_putc: write char in r3 to 16550 UART at 0xEF600300
uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lup_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .Lup_wait
    stb     %r3, 0(%r8)
    blr

// ---- Data ----
msg1:   .asciz "li r3, 0x1234  -> R3=0x"
msg2:   .asciz "10 + 20        = 0x"
msg3:   .asciz "30 - 5         = 0x"
msg4:   .asciz "Done!\n"
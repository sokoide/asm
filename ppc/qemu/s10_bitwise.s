// s10_bitwise.s - Scenario 10: Bitwise Operations
// ========================================
// Learning objectives:
//   - ANDI. / ORI / XORI for immediate bitwise ops
//   - SLWI / SRWI for shift operations
//   - RLWINM for rotate-and-mask (extract nibble, extract bit)
//   - Display results in both hex and binary

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // AND: 0xFF & 0x0F = 0x0F
    lis     %r3, msg_and@ha; addi %r3, %r3, msg_and@l; bl print_str
    li      %r30, 0xFF
    andi.   %r30, %r30, 0x0F
    mr      %r3, %r30
    bl      print_hex8
    li      %r3, 0x20
    bl      uart_putc
    mr      %r3, %r30
    bl      print_bin8
    bl      print_crlf

    // OR: 0xF0 | 0x0F = 0xFF
    lis     %r3, msg_or@ha; addi %r3, %r3, msg_or@l; bl print_str
    li      %r30, 0xF0
    ori     %r30, %r30, 0x0F
    mr      %r3, %r30
    bl      print_hex8
    li      %r3, 0x20
    bl      uart_putc
    mr      %r3, %r30
    bl      print_bin8
    bl      print_crlf

    // XOR: 0xFF ^ 0x0F = 0xF0
    lis     %r3, msg_xor@ha; addi %r3, %r3, msg_xor@l; bl print_str
    li      %r30, 0xFF
    xori    %r30, %r30, 0x0F
    mr      %r3, %r30
    bl      print_hex8
    li      %r3, 0x20
    bl      uart_putc
    mr      %r3, %r30
    bl      print_bin8
    bl      print_crlf

    // SHL: 1 << 4 = 0x10
    lis     %r3, msg_shl@ha; addi %r3, %r3, msg_shl@l; bl print_str
    li      %r30, 1
    slwi    %r30, %r30, 4
    mr      %r3, %r30
    bl      print_hex8
    li      %r3, 0x20
    bl      uart_putc
    mr      %r3, %r30
    bl      print_bin8
    bl      print_crlf

    // SHR: 0x80 >> 3 = 0x10
    lis     %r3, msg_shr@ha; addi %r3, %r3, msg_shr@l; bl print_str
    li      %r30, 0x80
    srwi    %r30, %r30, 3
    mr      %r3, %r30
    bl      print_hex8
    li      %r3, 0x20
    bl      uart_putc
    mr      %r3, %r30
    bl      print_bin8
    bl      print_crlf

halt:   b       halt

// ---- Subroutines ----

// print_hex8: print r3 as 2 hex digits (high nibble first, then low)
print_hex8:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 12(%r1)
    andi.   %r31, %r3, 0xFF
    // High nibble: shift right by 4, then mask
    srwi    %r3, %r31, 4
    bl      print_nibble
    // Low nibble: mask with 0xF
    andi.   %r3, %r31, 0xF
    bl      print_nibble
    lwz     %r31, 12(%r1)
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// print_nibble: print r3 (0-15) as one hex digit
print_nibble:
    cmpwi   %r3, 9
    ble     .Lpn_digit
    addi    %r3, %r3, 7         // 'A' - '9' - 1 = 7
.Lpn_digit:
    addi    %r3, %r3, 0x30       // add '0'
    b       uart_putc

// print_bin8: print r3 as 8 bits (MSB first)
print_bin8:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 4(%r1)
    stw     %r30, 12(%r1)
    andi.   %r31, %r3, 0xFF
    li      %r30, 7              // bit counter: 7 down to 0
.Lpb_loop:
    srw     %r3, %r31, %r30      // shift right by bit position
    andi.   %r3, %r3, 1          // extract bit 0
    addi    %r3, %r3, 0x30       // convert to ASCII '0' or '1'
    bl      uart_putc
    addic.  %r30, %r30, -1
    bge     .Lpb_loop
    lwz     %r30, 12(%r1)
    lwz     %r31, 4(%r1)
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

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
msg_and: .asciz "0xFF & 0x0F = "
msg_or:  .asciz "0xF0 | 0x0F = "
msg_xor: .asciz "0xFF ^ 0x0F = "
msg_shl: .asciz "1 << 4      = "
msg_shr: .asciz "0x80 >> 3   = "
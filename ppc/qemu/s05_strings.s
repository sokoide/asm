// s05_strings.s - Scenario 5: String Operations
// ========================================
// Learning objectives:
//   - LBZ / STB for byte-level memory access
//   - Implementing strlen and strcpy in assembly
//   - Pointer arithmetic with ADDI
//   - Null terminator detection with CMPWI

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Show source string
    lis     %r3, msg_src@ha; addi %r3, %r3, msg_src@l; bl print_str
    lis     %r3, src@ha; addi %r3, %r3, src@l; bl print_str
    bl      print_crlf

    // strlen: count characters until null
    lis     %r3, src@ha; addi %r3, %r3, src@l
    bl      strlen
    mr      %r31, %r3
    lis     %r3, msg_len@ha; addi %r3, %r3, msg_len@l; bl print_str
    mr      %r3, %r31; bl print_hex32; bl print_crlf

    // strcpy: copy src to dst
    lis     %r3, dst@ha; addi %r3, %r3, dst@l
    lis     %r4, src@ha; addi %r4, %r4, src@l
    bl      strcpy
    lis     %r3, msg_cp@ha; addi %r3, %r3, msg_cp@l; bl print_str
    lis     %r3, dst@ha; addi %r3, %r3, dst@l; bl print_str
    bl      print_crlf

halt:   b       halt

// strlen: return length of string at r3
strlen:
    mr      %r4, %r3
.Lsl_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .Lsl_done
    addi    %r4, %r4, 1
    b       .Lsl_loop
.Lsl_done:
    subf    %r3, %r3, %r4
    blr

// strcpy: copy string from r4 (src) to r3 (dst)
strcpy:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r5, %r3
.Lsc_loop:
    lbz     %r6, 0(%r4)
    stb     %r6, 0(%r5)
    cmpwi   %r6, 0
    beq     .Lsc_done
    addi    %r4, %r4, 1
    addi    %r5, %r5, 1
    b       .Lsc_loop
.Lsc_done:
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

print_crlf:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    li      %r3, 0x0D
    bl      uart_putc
    li      %r3, 0x0A
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
msg_src: .asciz "Source: "
msg_len: .asciz "Length: 0x"
msg_cp:  .asciz "Copy:   "
src:     .asciz "Hello"
dst:     .space 32
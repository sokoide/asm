// s11_memory.s - Scenario 11: Memory Operations
// ========================================
// Learning objectives:
//   - LBZ / STB for byte load/store
//   - LBZU for pre-increment addressing (update base register)
//   - Implementing memset and memcpy in assembly
//   - .space directive for uninitialized memory

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // memset: fill buffer with 'X'
    lis     %r3, msg_f@ha; addi %r3, %r3, msg_f@l; bl print_str
    lis     %r3, buf1@ha; addi %r3, %r3, buf1@l
    li      %r4, 0x58             // 'X'
    li      %r5, 5
    bl      my_memset
    // Print filled buffer using a pointer
    lis     %r4, buf1@ha; addi %r4, %r4, buf1@l
    li      %r30, 5
.Lfp_loop:
    lbz     %r3, 0(%r4)
    bl      uart_putc
    li      %r3, 0x20
    bl      uart_putc
    addi    %r4, %r4, 1
    addic.  %r30, %r30, -1
    bne     .Lfp_loop
    bl      print_crlf

    // memcpy: copy "Hello" into buffer
    lis     %r3, msg_c@ha; addi %r3, %r3, msg_c@l; bl print_str
    lis     %r3, buf2@ha; addi %r3, %r3, buf2@l
    lis     %r4, src@ha; addi %r4, %r4, src@l
    bl      my_memcpy
    lis     %r3, buf2@ha; addi %r3, %r3, buf2@l; bl print_str
    bl      print_crlf

    // LBZU / STBU demo: pre-increment addressing
    // LBZU loads byte at (rA+d) and updates rA = rA+d
    lis     %r3, msg_lb@ha; addi %r3, %r3, msg_lb@l; bl print_str
    lis     %r4, src@ha; addi %r4, %r4, src@l
    addi    %r4, %r4, -1          // start one byte before string
    li      %r30, 5              // 5 chars in "Hello"
.Llb_loop:
    lbzu    %r3, 1(%r4)          // load byte and update r4 to r4+1
    bl      uart_putc
    addic.  %r30, %r30, -1
    bne     .Llb_loop
    bl      print_crlf

halt:   b       halt

// ---- Subroutines ----

// my_memset: fill r3 (dst) with r4 (byte) for r5 (count)
my_memset:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r6, %r3
.Lms_loop:
    cmpwi   %r5, 0
    beq     .Lms_done
    stb     %r4, 0(%r6)
    addi    %r6, %r6, 1
    addic.  %r5, %r5, -1
    bne     .Lms_loop
.Lms_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// my_memcpy: copy string from r4 (src) to r3 (dst)
my_memcpy:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r5, %r3
.Lmc_loop:
    lbz     %r6, 0(%r4)
    stb     %r6, 0(%r5)
    cmpwi   %r6, 0
    beq     .Lmc_done
    addi    %r4, %r4, 1
    addi    %r5, %r5, 1
    b       .Lmc_loop
.Lmc_done:
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
msg_f:  .asciz "Fill:  "
msg_c:  .asciz "Copy:  "
msg_lb: .asciz "LBZU:  "
src:    .asciz "Hello"
buf1:   .space 32
buf2:   .space 32
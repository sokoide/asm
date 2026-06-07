// s07_subroutines.s - Scenario 7: Subroutines (BL/BLR)
// ========================================
// Learning objectives:
//   - BL (Branch and Link) for subroutine calls
//   - BLR (Branch to Link Register) for returns
//   - Leaf functions (no stack frame needed)
//   - Saving/restoring LR with MFLR/MTLR/STW

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Call add3(10) -> 13
    li      %r3, 10; bl add3
    mr      %r30, %r3
    lis     %r3, msg1@ha; addi %r3, %r3, msg1@l; bl print_str
    mr      %r3, %r30; bl print_hex32; bl print_crlf

    // Call add3(20) -> 23
    li      %r3, 20; bl add3
    mr      %r30, %r3
    lis     %r3, msg2@ha; addi %r3, %r3, msg2@l; bl print_str
    mr      %r3, %r30; bl print_hex32; bl print_crlf

    // Call double(add3(5)) -> 16
    li      %r3, 5; bl add3; bl double_val
    mr      %r30, %r3
    lis     %r3, msg3@ha; addi %r3, %r3, msg3@l; bl print_str
    mr      %r3, %r30; bl print_hex32; bl print_crlf

halt:   b       halt

// ---- Leaf functions (no stack frame) ----

// add3: return r3 + 3
add3:
    addi    %r3, %r3, 3
    blr

// double_val: return r3 * 2
double_val:
    slwi    %r3, %r3, 1
    blr

// ---- Subroutines with stack frames ----

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
msg1: .asciz "add3(10)    = 0x"
msg2: .asciz "add3(20)    = 0x"
msg3: .asciz "double(add3(5)) = 0x"
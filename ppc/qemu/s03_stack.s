// s03_stack.s - Scenario 3: Stack Operations
// ========================================
// Learning objectives:
//   - STWU / LWZ for stack push and pop
//   - Stack frame creation and cleanup (R1 adjustment)
//   - Save/restore callee-saved registers (R30, R31)
//   - LIFO (Last In, First Out) behavior

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Show initial register values
    lis     %r3, msg_push@ha; addi %r3, %r3, msg_push@l; bl print_str

    lis     %r3, msg_r3@ha; addi %r3, %r3, msg_r3@l; bl print_str
    lis     %r3, 0x0000; ori %r3, %r3, 0xAAAA
    mr      %r30, %r3
    bl      print_hex32
    bl      print_crlf

    lis     %r3, msg_r4@ha; addi %r3, %r3, msg_r4@l; bl print_str
    lis     %r3, 0x0000; ori %r3, %r3, 0xBBBB
    mr      %r31, %r3
    bl      print_hex32
    bl      print_crlf

    // Push R30 and R31 onto the stack
    // STWU creates a 16-byte frame and saves old R1 at frame base
    stwu    %r1, -16(%r1)       // R1 -= 16; *(new R1) = old R1
    stw     %r30, 8(%r1)        // save R30 at frame+8
    stw     %r31, 12(%r1)       // save R31 at frame+12

    // Corrupt R30, R31 to prove the stack works
    li      %r30, 0
    li      %r31, 0

    // Pop R30 and R31 from the stack
    lis     %r3, msg_pop@ha; addi %r3, %r3, msg_pop@l; bl print_str
    lwz     %r30, 8(%r1)         // restore R30
    lwz     %r31, 12(%r1)        // restore R31
    addi    %r1, %r1, 16         // R1 += 16 (deallocate frame)

    lis     %r3, msg_p1@ha; addi %r3, %r3, msg_p1@l; bl print_str
    mr      %r3, %r30; bl print_hex32; bl print_crlf

    lis     %r3, msg_p2@ha; addi %r3, %r3, msg_p2@l; bl print_str
    mr      %r3, %r31; bl print_hex32; bl print_crlf

    lis     %r3, msg_ok@ha; addi %r3, %r3, msg_ok@l; bl print_str

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
msg_push: .asciz "=== Push ===\n"
msg_r3:   .asciz "  R30 = 0x"
msg_r4:   .asciz "  R31 = 0x"
msg_pop:  .asciz "=== Pop ===\n"
msg_p1:   .asciz "  R30 = 0x"
msg_p2:   .asciz "  R31 = 0x"
msg_ok:   .asciz "Stack OK!\n"
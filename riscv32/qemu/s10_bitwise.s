// s10_bitwise.s - Scenario 10: Bitwise Operations
// ================================================
// Learning objectives:
//   - AND / OR / XOR — bitwise logic
//   - ANDI / ORI / XORI — immediate forms
//   - SLL / SRL / SRA — shift left / logical right / arithmetic right
//   - Bit masking and extraction
//   - Toggle and set/clear patterns

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: AND mask — extract lower nibble
    la      a0, msg_and
    jal     ra, print_str
    li      a0, 0xAB
    li      a1, 0x0F
    and     a2, a0, a1           // a2 = 0x0B
    mv      a0, a2
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 2: OR — set bits
    la      a0, msg_or
    jal     ra, print_str
    li      a0, 0x0A
    li      a1, 0x50
    or      a2, a0, a1           // a2 = 0x5A
    mv      a0, a2
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 3: XOR — toggle bits
    la      a0, msg_xor
    jal     ra, print_str
    li      a0, 0xFF
    li      a1, 0x0F
    xor     a2, a0, a1           // a2 = 0xF0
    mv      a0, a2
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 4: SLL — shift left (multiply by 2)
    la      a0, msg_sll
    jal     ra, print_str
    li      a0, 3
    slli    a0, a0, 3            // 3 << 3 = 24
    jal     ra, print_dec
    la      a0, newline
    jal     ra, print_str

    // Demo 5: SRL — logical shift right
    la      a0, msg_srl
    jal     ra, print_str
    li      a0, 0xFF
    srli    a0, a0, 4            // 0xFF >> 4 = 0x0F
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 6: SRA — arithmetic shift right (sign extend)
    la      a0, msg_sra
    jal     ra, print_str
    li      a0, -16              // 0xFFFFFFF0
    srai    a0, a0, 4            // -16 >> 4 = -1 (sign extended)
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 7: ANDI mask — test specific bit
    la      a0, msg_bit
    jal     ra, print_str
    li      a0, 0x28             // bit 5 and bit 3 set
    andi    a0, a0, 0x20         // test bit 5
    bnez    a0, .bit_set
    la      a0, msg_zero
    jal     ra, print_str
    j       .next
.bit_set:
    la      a0, msg_one
    jal     ra, print_str
.next:

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Common subroutines ----

print_str:
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    mv      s0, a0
.loop:
    lbu     t1, 0(s0)
    beqz    t1, .ret
    mv      a0, t1
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .loop
.ret:
    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

print_hex32:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s0, a0
    li      s1, 28
.hex_loop:
    srl     a0, s0, s1
    andi    a0, a0, 0xF
    li      t0, 9
    bgt     a0, t0, .alpha
    addi    a0, a0, '0'
    j       .print
.alpha:
    addi    a0, a0, ('A' - 10)
.print:
    jal     ra, uart_putc
    addi    s1, s1, -4
    bgez    s1, .hex_loop
    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
    ret

print_dec:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)
    mv      s0, a0
    bnez    s0, .nonzero
    li      a0, '0'
    jal     ra, uart_putc
    j       .done
.nonzero:
    li      s2, 0
.extract:
    beqz    s0, .print_digits
    li      t0, 10
    remu    t1, s0, t0
    divu    s0, s0, t0
    addi    t1, t1, '0'
    addi    sp, sp, -4
    sw      t1, 0(sp)
    addi    s2, s2, 1
    j       .extract
.print_digits:
    beqz    s2, .done
    lw      a0, 0(sp)
    addi    sp, sp, 4
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .print_digits
.done:
    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
    ret

uart_putc:
    li      t0, 0x10000000
.wait:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x20
    beqz    t1, .wait
    sb      a0, 0(t0)
    ret

// ---- Data ----
msg_and:  .asciz "0xAB & 0x0F  = 0x"
msg_or:   .asciz "0x0A | 0x50  = 0x"
msg_xor:  .asciz "0xFF ^ 0x0F  = 0x"
msg_sll:  .asciz "3 << 3       = "
msg_srl:  .asciz "0xFF >> 4    = 0x"
msg_sra:  .asciz "-16 >> 4 (arith) = 0x"
msg_bit:  .asciz "Bit 5 of 0x28: "
msg_zero: .asciz "0\n"
msg_one:  .asciz "1\n"
newline:  .asciz "\n"

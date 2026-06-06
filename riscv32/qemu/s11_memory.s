// s11_memory.s - Scenario 11: Memory Operations
// ==============================================
// Learning objectives:
//   - LW / SW — word (32-bit) load/store
//   - LB / SB — byte load/store
//   - LH / SH — halfword load/store
//   - LUI for upper immediate (address construction)
//   - Memory fill, block copy
//   - Indexed addressing with ADD offset

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: SW / LW — store and load words
    la      a0, msg_store
    jal     ra, print_str
    li      t0, 0xDEADBEEF
    la      t1, test_word
    sw      t0, 0(t1)            // store 0xDEADBEEF
    lw      t2, 0(t1)            // load it back
    mv      a0, t2
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 2: SB — store individual bytes
    la      a0, msg_bytes
    jal     ra, print_str
    la      t0, test_bytes
    li      t1, 'R'
    sb      t1, 0(t0)
    li      t1, 'V'
    sb      t1, 1(t0)
    li      t1, '3'
    sb      t1, 2(t0)
    li      t1, '2'
    sb      t1, 3(t0)
    li      t1, 0
    sb      t1, 4(t0)
    la      a0, test_bytes
    jal     ra, print_str
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Memory fill
    la      a0, msg_fill
    jal     ra, print_str
    la      a0, fill_buf          // dst
    li      a1, 8                 // count
    li      a2, 0x42              // fill value
    jal     ra, memfill
    // Print filled buffer as hex
    la      s0, fill_buf
    li      s1, 8
.print_fill:
    beqz    s1, .fill_done
    lw      a0, 0(s0)
    jal     ra, print_hex32
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, 4
    addi    s1, s1, -1
    j       .print_fill
.fill_done:
    la      a0, newline
    jal     ra, print_str

    // Demo 4: Block copy
    la      a0, msg_copy
    jal     ra, print_str
    la      a0, copy_dst          // dst
    la      a1, test_bytes        // src
    li      a2, 5                 // 5 bytes
    jal     ra, memcpy
    la      a0, copy_dst
    jal     ra, print_str
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Memory subroutines ----

// memfill: fill a0[0..a1-1] with a2 (word fill)
memfill:
    beqz    a1, .mf_ret
    sw      a2, 0(a0)
    addi    a0, a0, 4
    addi    a1, a1, -1
    j       memfill
.mf_ret:
    ret

// memcpy: copy a1[0..a2-1] to a0 (byte copy)
memcpy:
    beqz    a2, .mc_ret
    lbu     t0, 0(a1)
    sb      t0, 0(a0)
    addi    a0, a0, 1
    addi    a1, a1, 1
    addi    a2, a2, -1
    j       memcpy
.mc_ret:
    ret

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

uart_putc:
    li      t0, 0x10000000
.wait:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x20
    beqz    t1, .wait
    sb      a0, 0(t0)
    ret

// ---- Data ----
.bss
test_word:  .space 4
test_bytes: .space 8
fill_buf:   .space 32
copy_dst:   .space 8

.section .rodata
msg_store: .asciz "SW/LW: 0x"
msg_bytes: .asciz "SB: "
msg_fill:  .asciz "Fill 8 words: "
msg_copy:  .asciz "Copy: "
newline:   .asciz "\n"

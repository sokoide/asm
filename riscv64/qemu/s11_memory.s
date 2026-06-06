// s11_memory.s - Scenario 11: Memory Operations (RV64I)
// ======================================================
// Learning objectives:
//   - LD / SD — doubleword (64-bit) load/store
//   - LW / SW — word (32-bit) load/store
//   - LB / SB — byte load/store
//   - LUI for upper immediate
//   - Memory fill, block copy

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: SD / LD — store and load doublewords
    la      a0, msg_store
    jal     ra, print_str
    li      t0, 0xDEADBEEFCAFEBABE
    la      t1, test_dword
    sd      t0, 0(t1)
    ld      t2, 0(t1)
    mv      a0, t2
    jal     ra, print_hex64
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
    li      t1, '6'
    sb      t1, 2(t0)
    li      t1, '4'
    sb      t1, 3(t0)
    li      t1, 0
    sb      t1, 4(t0)
    la      a0, test_bytes
    jal     ra, print_str
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Memory fill (word fill)
    la      a0, msg_fill
    jal     ra, print_str
    la      a0, fill_buf
    li      a1, 8
    li      a2, 0x42
    jal     ra, memfill
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
    la      a0, copy_dst
    la      a1, test_bytes
    li      a2, 5
    jal     ra, memcpy
    la      a0, copy_dst
    jal     ra, print_str
    la      a0, newline
    jal     ra, print_str

    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

memfill:
    beqz    a1, .mf_ret
    sw      a2, 0(a0)
    addi    a0, a0, 4
    addi    a1, a1, -1
    j       memfill
.mf_ret:
    ret

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

print_str:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    sd      s0, 0(sp)
    mv      s0, a0
.ps_loop:
    lbu     t1, 0(s0)
    beqz    t1, .ps_ret
    mv      a0, t1
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .ps_loop
.ps_ret:
    ld      s0, 0(sp)
    ld      ra, 8(sp)
    addi    sp, sp, 16
    ret

print_hex64:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s0, a0
    li      s1, 60
.ph_loop:
    srl     a0, s0, s1
    andi    a0, a0, 0xF
    li      t0, 9
    bgt     a0, t0, .ph_alpha
    addi    a0, a0, '0'
    j       .ph_print
.ph_alpha:
    addi    a0, a0, ('A' - 10)
.ph_print:
    jal     ra, uart_putc
    addi    s1, s1, -4
    bgez    s1, .ph_loop
    ld      s1, 8(sp)
    ld      s0, 16(sp)
    ld      ra, 24(sp)
    addi    sp, sp, 32
    ret

print_hex32:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s0, a0
    li      s1, 28
.ph32_loop:
    srl     a0, s0, s1
    andi    a0, a0, 0xF
    li      t0, 9
    bgt     a0, t0, .ph32_alpha
    addi    a0, a0, '0'
    j       .ph32_print
.ph32_alpha:
    addi    a0, a0, ('A' - 10)
.ph32_print:
    jal     ra, uart_putc
    addi    s1, s1, -4
    bgez    s1, .ph32_loop
    ld      s1, 8(sp)
    ld      s0, 16(sp)
    ld      ra, 24(sp)
    addi    sp, sp, 32
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
test_dword: .space 8
test_bytes: .space 8
fill_buf:   .space 32
copy_dst:   .space 8

.section .rodata
msg_store: .asciz "SD/LD: 0x"
msg_bytes: .asciz "SB: "
msg_fill:  .asciz "Fill 8 words: "
msg_copy:  .asciz "Copy: "
newline:   .asciz "\n"

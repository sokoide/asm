// s08_hardware.s - Scenario 8: Hardware Access (RV64I)
// =====================================================
// Learning objectives:
//   - RDCYCLE / RDTIME pseudo-instructions (CSR read)
//   - CLINT mtime register (0x200BFF8) direct read
//   - Cycle difference measurement

.section .text
.global _start

_start:
    li      sp, 0x80200000

    la      a0, msg_cycle
    jal     ra, print_str
    rdcycle a0
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    la      a0, msg_time
    jal     ra, print_str
    rdtime  a0
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    la      a0, msg_mtime
    jal     ra, print_str
    li      t0, 0x200BFF8
    ld      a0, 0(t0)
    jal     ra, print_hex64
    la      a0, newline
    jal     ra, print_str

    la      a0, msg_measure
    jal     ra, print_str
    rdcycle s0
    li      s1, 100
.delay:
    addi    s1, s1, -1
    bnez    s1, .delay
    rdcycle s2
    sub     s2, s2, s0
    mv      a0, s2
    jal     ra, print_dec
    la      a0, msg_cycles
    jal     ra, print_str

    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

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

print_dec:
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    mv      s0, a0
    bnez    s0, .pd_nonzero
    li      a0, '0'
    jal     ra, uart_putc
    j       .pd_done
.pd_nonzero:
    li      s2, 0
.pd_extract:
    beqz    s0, .pd_print_digits
    li      t0, 10
    remu    t1, s0, t0
    divu    s0, s0, t0
    addi    t1, t1, '0'
    addi    sp, sp, -8
    sd      t1, 0(sp)
    addi    s2, s2, 1
    j       .pd_extract
.pd_print_digits:
    beqz    s2, .pd_done
    ld      a0, 0(sp)
    addi    sp, sp, 8
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .pd_print_digits
.pd_done:
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
msg_cycle:   .asciz "Cycle counter: 0x"
msg_time:    .asciz "Time counter:  0x"
msg_mtime:   .asciz "CLINT mtime:   0x"
msg_measure: .asciz "100 iterations: "
msg_cycles:  .asciz " cycles\n"
newline:     .asciz "\n"

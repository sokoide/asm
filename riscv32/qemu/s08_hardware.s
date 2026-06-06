// s08_hardware.s - Scenario 8: Hardware Access
// =============================================
// Learning objectives:
//   - RDCYCLE / RDTIME pseudo-instructions (CSR read)
//   - CLINT mtime register (0x200BFF8) direct read
//   - Cycle difference measurement
//   - Memory-mapped I/O for timer access

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: Read cycle counter
    la      a0, msg_cycle
    jal     ra, print_str
    rdcycle a0
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 2: Read time counter
    la      a0, msg_time
    jal     ra, print_str
    rdtime  a0
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 3: Read CLINT mtime directly (MMIO)
    la      a0, msg_mtime
    jal     ra, print_str
    li      t0, 0x200BFF8         // CLINT mtime address
    lw      a0, 0(t0)
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // Demo 4: Measure cycles for a small loop
    la      a0, msg_measure
    jal     ra, print_str

    rdcycle s0                    // start cycle count

    li      s1, 100               // loop 100 times
.delay:
    addi    s1, s1, -1
    bnez    s1, .delay

    rdcycle s2                    // end cycle count
    sub     s2, s2, s0            // difference
    mv      a0, s2
    jal     ra, print_dec
    la      a0, msg_cycles
    jal     ra, print_str

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
    addi    sp, sp, -40
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
    beqz    s2, .digits_done
    lw      a0, 0(sp)
    addi    sp, sp, 4
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .print_digits
.digits_done:
    addi    sp, sp, 40
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
msg_cycle:   .asciz "Cycle counter: 0x"
msg_time:    .asciz "Time counter:  0x"
msg_mtime:   .asciz "CLINT mtime:   0x"
msg_measure: .asciz "100 iterations: "
msg_cycles:  .asciz " cycles\n"
newline:     .asciz "\n"

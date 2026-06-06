// s06_serial_in.s - Scenario 6: Serial Input (RV64I)
// ====================================================
// Learning objectives:
//   - UART NS16550A RBR (Receiver Buffer Register)
//   - LSR bit 0 (Data Ready) polling
//   - Echo back received characters
//   - Character classification

.section .text
.global _start

_start:
    li      sp, 0x80200000

    la      a0, msg_welcome
    jal     ra, print_str

.read_loop:
    jal     ra, uart_getc
    li      t0, 'q'
    beq     a0, t0, .done
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc

    li      t0, '0'
    blt     a0, t0, .not_digit
    li      t0, '9'
    bgt     a0, t0, .not_digit
    la      a0, msg_digit
    jal     ra, print_str
    j       .read_loop
.not_digit:
    li      t0, 'A'
    blt     a0, t0, .not_upper
    li      t0, 'Z'
    bgt     a0, t0, .not_upper
    la      a0, msg_upper
    jal     ra, print_str
    j       .read_loop
.not_upper:
    li      t0, 'a'
    blt     a0, t0, .not_lower
    li      t0, 'z'
    bgt     a0, t0, .not_lower
    la      a0, msg_lower
    jal     ra, print_str
    j       .read_loop
.not_lower:
    la      a0, msg_other
    jal     ra, print_str
    j       .read_loop

.done:
    la      a0, msg_quit
    jal     ra, print_str
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

uart_putc:
    li      t0, 0x10000000
.wait_tx:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x20
    beqz    t1, .wait_tx
    sb      a0, 0(t0)
    ret

uart_getc:
    li      t0, 0x10000000
.wait_rx:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x01
    beqz    t1, .wait_rx
    lbu     a0, 0(t0)
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

// ---- Data ----
msg_welcome: .asciz "Type chars (q=quit):\n"
msg_quit:    .asciz "\nGoodbye!\n"
msg_digit:   .asciz "-> digit\n"
msg_upper:   .asciz "-> UPPER\n"
msg_lower:   .asciz "-> lower\n"
msg_other:   .asciz "-> other\n"

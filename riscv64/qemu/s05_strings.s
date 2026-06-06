// s05_strings.s - Scenario 5: String Operations (RV64I)
// =======================================================
// Learning objectives:
//   - LB / LBU for byte load (signed / unsigned)
//   - SB for byte store
//   - Null-terminated string traversal
//   - strlen: count characters until null
//   - String copy: byte-by-byte transfer

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // Demo 1: String length
    la      a0, msg_len
    jal     ra, print_str
    la      a0, test_str
    jal     ra, strlen
    jal     ra, print_dec
    la      a0, newline
    jal     ra, print_str

    // Demo 2: Print each character
    la      a0, msg_chars
    jal     ra, print_str
    la      s0, test_str
.char_loop:
    lbu     t1, 0(s0)
    beqz    t1, .char_done
    mv      a0, t1
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .char_loop
.char_done:
    la      a0, newline
    jal     ra, print_str

    // Demo 3: String copy
    la      a0, msg_copy
    jal     ra, print_str
    la      a0, dest_buf
    la      a1, test_str
    jal     ra, strcpy
    la      a0, dest_buf
    jal     ra, print_str
    la      a0, newline
    jal     ra, print_str

    // Exit
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

strlen:
    mv      t0, a0
    li      t1, 0
.sl_loop:
    lbu     t2, 0(t0)
    beqz    t2, .sl_ret
    addi    t0, t0, 1
    addi    t1, t1, 1
    j       .sl_loop
.sl_ret:
    mv      a0, t1
    ret

strcpy:
    addi    sp, sp, -16
    sd      ra, 8(sp)
    sd      s0, 0(sp)
    mv      s0, a0
.sc_loop:
    lbu     t0, 0(a1)
    sb      t0, 0(a0)
    beqz    t0, .sc_ret
    addi    a0, a0, 1
    addi    a1, a1, 1
    j       .sc_loop
.sc_ret:
    ld      s0, 0(sp)
    ld      ra, 8(sp)
    addi    sp, sp, 16
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
    addi    sp, sp, -80
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
    beqz    s2, .pd_digits_done
    ld      a0, 0(sp)
    addi    sp, sp, 8
    addi    s2, s2, -1
    jal     ra, uart_putc
    j       .pd_print_digits
.pd_digits_done:
    addi    sp, sp, 80
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
test_str:  .asciz "RISC-V"
dest_buf:  .space 32
msg_len:   .asciz "strlen(\"RISC-V\") = "
msg_chars: .asciz "Chars: "
msg_copy:  .asciz "Copy:  "
newline:   .asciz "\n"

// s12_minishell.s - Scenario 12: Interactive Mini Shell
// =====================================================
// Learning objectives:
//   - UART getc/putc for character I/O
//   - Line editor with backspace handling
//   - Command parsing: string compare
//   - Menu dispatch pattern
//   - Integration of all previous concepts
// Commands: hello, count, hex, help, quit

.section .text
.global _start

_start:
    li      sp, 0x80200000

    la      a0, msg_welcome
    jal     ra, print_str

    li      s10, 1                // running = 1

main_loop:
    beqz    s10, main_exit

    la      a0, msg_prompt
    jal     ra, print_str

    jal     ra, read_line
    jal     ra, dispatch

    j       main_loop

main_exit:
    // Exit via SiFive test finisher
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)

// ---- Read line ----
// Stores into input_buf, null-terminated
read_line:
    addi    sp, sp, -4
    sw      ra, 0(sp)
    la      s0, input_buf
    li      s1, 0                 // index
.rl_loop:
    jal     ra, uart_getc
    li      t0, '\n'
    beq     a0, t0, .rl_done
    li      t0, '\r'
    beq     a0, t0, .rl_done
    li      t0, 0x7F              // DEL
    beq     a0, t0, .rl_bs
    li      t0, 0x08              // BS
    beq     a0, t0, .rl_bs
    li      t0, 30
    bge     s1, t0, .rl_loop
    sb      a0, 0(s0)            // store char
    addi    s0, s0, 1
    addi    s1, s1, 1
    jal     ra, uart_putc         // echo
    j       .rl_loop
.rl_bs:
    beqz    s1, .rl_loop
    addi    s0, s0, -1
    addi    s1, s1, -1
    li      a0, 0x08
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc
    li      a0, 0x08
    jal     ra, uart_putc
    j       .rl_loop
.rl_done:
    sb      zero, 0(s0)          // null terminate
    li      a0, '\n'
    jal     ra, uart_putc
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

// ---- Dispatch ----
dispatch:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    la      a0, input_buf
    la      a1, cmd_hello
    jal     ra, streq
    bnez    a0, .do_hello

    la      a0, input_buf
    la      a1, cmd_count
    jal     ra, streq
    bnez    a0, .do_count

    la      a0, input_buf
    la      a1, cmd_hex
    jal     ra, streq
    bnez    a0, .do_hex

    la      a0, input_buf
    la      a1, cmd_help
    jal     ra, streq
    bnez    a0, .do_help

    la      a0, input_buf
    la      a1, cmd_quit
    jal     ra, streq
    bnez    a0, .do_quit

    la      a0, msg_unknown
    jal     ra, print_str
    j       .disp_ret

.do_hello:
    la      a0, msg_hello
    jal     ra, print_str
    j       .disp_ret
.do_count:
    jal     ra, do_count
    j       .disp_ret
.do_hex:
    jal     ra, do_hex
    j       .disp_ret
.do_help:
    la      a0, msg_help
    jal     ra, print_str
    j       .disp_ret
.do_quit:
    la      a0, msg_quit
    jal     ra, print_str
    li      s10, 0                // running = 0
.disp_ret:
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

// ---- String compare ----
// streq(a0, a1): return 1 if equal, 0 if not
streq:
    mv      t0, a0
    mv      t1, a1
.se_loop:
    lbu     t2, 0(t0)
    lbu     t3, 0(t1)
    bne     t2, t3, .se_ne
    beqz    t2, .se_eq
    addi    t0, t0, 1
    addi    t1, t1, 1
    j       .se_loop
.se_eq:
    li      a0, 1
    ret
.se_ne:
    li      a0, 0
    ret

// ---- Command: count ----
do_count:
    addi    sp, sp, -4
    sw      ra, 0(sp)
    la      a0, msg_count
    jal     ra, print_str
    li      s0, 5
.dc_loop:
    addi    a0, s0, '0'
    jal     ra, uart_putc
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, -1
    bnez    s0, .dc_loop
    la      a0, newline
    jal     ra, print_str
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

// ---- Command: hex ----
do_hex:
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    la      a0, msg_hex_hdr
    jal     ra, print_str
    li      s0, 0
.dh_loop:
    mv      a0, s0
    jal     ra, print_hex32
    li      a0, ' '
    jal     ra, uart_putc
    addi    s0, s0, 1
    li      t0, 16
    bne     s0, t0, .dh_loop
    la      a0, newline
    jal     ra, print_str
    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

// ---- UART I/O ----

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

// ---- Data ----
.bss
input_buf:  .space 32

.section .rodata
msg_welcome: .asciz "RISC-V Mini Shell - type 'help'\n"
msg_prompt:  .asciz "> "
msg_unknown: .asciz "? Unknown command\n"
msg_hello:   .asciz "Hello from RISC-V!\n"
msg_help:    .asciz "Commands: hello count hex help quit\n"
msg_quit:    .asciz "Goodbye!\n"
msg_count:   .asciz "Count: "
msg_hex_hdr: .asciz "Hex: "
cmd_hello:   .asciz "hello"
cmd_count:   .asciz "count"
cmd_hex:     .asciz "hex"
cmd_help:    .asciz "help"
cmd_quit:    .asciz "quit"
newline:     .asciz "\n"

// s12_minishell.s - Scenario 12: Interactive Mini Shell
// =====================================================
// Learning objectives:
//   - PL011 UART getc/putc for character I/O
//   - Line editor with backspace handling
//   - Command parsing via string compare (streq)
//   - Menu dispatch pattern
//   - Read-Eval-Print Loop (REPL) integrating all prior concepts
// Commands: hello, count, hex, help, quit

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    ldr     x0, =msg_welcome
    bl      print_str

    mov     x19, #1                // running = 1 (callee-saved)

main_loop:
    cbz     x19, main_exit

    ldr     x0, =msg_prompt
    bl      print_str

    bl      read_line
    bl      dispatch

    b       main_loop

main_exit:
    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- read_line: store a null-terminated line into input_buf ----
//   x20 = cursor into input_buf, x21 = length
read_line:
    stp     x29, x30, [sp, #-32]!
    stp     x20, x21, [sp, #16]
    mov     x29, sp
    ldr     x20, =input_buf
    mov     x21, #0
.rl_loop:
    bl      uart_getc
    mov     w9, #'\n'
    cmp     w0, w9
    b.eq    .rl_done
    mov     w9, #'\r'
    cmp     w0, w9
    b.eq    .rl_done
    mov     w9, #0x7F              // DEL
    cmp     w0, w9
    b.eq    .rl_bs
    mov     w9, #0x08              // BS
    cmp     w0, w9
    b.eq    .rl_bs
    mov     x9, #30
    cmp     x21, x9
    b.ge    .rl_loop              // buffer full, drop char
    strb    w0, [x20]
    add     x20, x20, #1
    add     x21, x21, #1
    bl      uart_putc             // echo
    b       .rl_loop
.rl_bs:
    cbz     x21, .rl_loop         // empty, ignore
    sub     x20, x20, #1
    sub     x21, x21, #1
    mov     w0, #0x08
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    mov     w0, #0x08
    bl      uart_putc
    b       .rl_loop
.rl_done:
    strb    wzr, [x20]            // null terminate
    mov     w0, #'\n'
    bl      uart_putc
    ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ---- dispatch: compare input_buf against each command ----
dispatch:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    ldr     x0, =input_buf
    ldr     x1, =cmd_hello
    bl      streq
    cbnz    w0, .do_hello

    ldr     x0, =input_buf
    ldr     x1, =cmd_count
    bl      streq
    cbnz    w0, .do_count

    ldr     x0, =input_buf
    ldr     x1, =cmd_hex
    bl      streq
    cbnz    w0, .do_hex

    ldr     x0, =input_buf
    ldr     x1, =cmd_help
    bl      streq
    cbnz    w0, .do_help

    ldr     x0, =input_buf
    ldr     x1, =cmd_quit
    bl      streq
    cbnz    w0, .do_quit

    // Empty line → silently re-prompt
    ldr     x4, =input_buf
    ldrb    w5, [x4]
    cbz     w5, .disp_ret

    ldr     x0, =msg_unknown
    bl      print_str
    b       .disp_ret

.do_hello:
    ldr     x0, =msg_hello
    bl      print_str
    b       .disp_ret
.do_count:
    bl      cmd_do_count
    b       .disp_ret
.do_hex:
    bl      cmd_do_hex
    b       .disp_ret
.do_help:
    ldr     x0, =msg_help
    bl      print_str
    b       .disp_ret
.do_quit:
    ldr     x0, =msg_quit
    bl      print_str
    mov     x19, #0                // running = 0
.disp_ret:
    ldp     x29, x30, [sp], #16
    ret

// ---- streq(x0, a; x1, b): returns w0 = 1 if equal, 0 otherwise ----
streq:
.seq_loop:
    ldrb    w9, [x0]
    ldrb    w10, [x1]
    cmp     w9, w10
    b.ne    .seq_ne
    cbz     w9, .seq_eq
    add     x0, x0, #1
    add     x1, x1, #1
    b       .seq_loop
.seq_eq:
    mov     w0, #1
    ret
.seq_ne:
    mov     w0, #0
    ret

// ---- Command: count (print 5 4 3 2 1) ----
cmd_do_count:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    ldr     x0, =msg_count
    bl      print_str
    mov     x20, #5
.dc_loop:
    add     w0, w20, #'0'
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    sub     x20, x20, #1
    cbnz    x20, .dc_loop
    ldr     x0, =newline
    bl      print_str
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---- Command: hex (print 0..F) ----
cmd_do_hex:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    ldr     x0, =msg_hex_hdr
    bl      print_str
    mov     x20, #0
.dh_loop:
    mov     x0, x20
    bl      print_hex64
    mov     w0, #' '
    bl      uart_putc
    add     x20, x20, #1
    cmp     x20, #16
    b.ne    .dh_loop
    ldr     x0, =newline
    bl      print_str
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---- UART I/O ----

uart_putc:
    movz    x8, #0x0900, lsl #16
.Lup_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, .Lup_wait
    strb    w0, [x8]
    ret

uart_getc:
    movz    x8, #0x0900, lsl #16
.Lug_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #4, .Lug_wait     // bit 4 = RXFE
    ldrb    w0, [x8]
    ret

// ---- Common subroutines ----

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
.Lps_loop:
    ldrb    w5, [x4]
    cbz     w5, .Lps_done
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       .Lps_loop
.Lps_done:
    ldp     x29, x30, [sp], #16
    ret

// print_hex64: print x0 as 16 hex digits
print_hex64:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x19, x0
    mov     x20, #60
.Lph_loop:
    lsr     x0, x19, x20
    and     x0, x0, #0xF
    cmp     x0, #9
    b.hi    .Lph_alpha
    add     x0, x0, #'0'
    b       .Lph_print
.Lph_alpha:
    add     x0, x0, #('A' - 10)
.Lph_print:
    bl      uart_putc
    subs    x20, x20, #4
    b.pl    .Lph_loop
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---- Data ----
msg_welcome: .asciz "ARM64 Mini Shell - type 'help'\n"
msg_prompt:  .asciz "> "
msg_unknown: .asciz "? Unknown command\n"
msg_hello:   .asciz "Hello from ARM64!\n"
msg_help:    .asciz "Commands: hello count hex help quit\n"
msg_quit:    .asciz "Goodbye!\n"
msg_count:   .asciz "Count: "
msg_hex_hdr: .asciz "Hex:   "
cmd_hello:   .asciz "hello"
cmd_count:   .asciz "count"
cmd_hex:     .asciz "hex"
cmd_help:    .asciz "help"
cmd_quit:    .asciz "quit"
newline:     .asciz "\n"

.section .bss
input_buf:   .space 32

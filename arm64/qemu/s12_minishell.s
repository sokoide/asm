// s12_minishell.s - Scenario 12: Interactive Mini Shell
// =====================================================
// Learning objectives:
//   - Command parsing and dispatch
//   - Integrating all previous concepts
//   - Automated demo mode

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    ldr     x0, =msg_banner
    bl      print_str

    // Demo: hello
    ldr     x0, =msg_prompt
    bl      print_str
    ldr     x0, =msg_hello_out
    bl      print_str

    // Demo: help
    ldr     x0, =msg_prompt
    bl      print_str
    ldr     x0, =msg_help1
    bl      print_str
    ldr     x0, =msg_help2
    bl      print_str
    ldr     x0, =msg_help3
    bl      print_str
    ldr     x0, =msg_help4
    bl      print_str

    // Demo: quit
    ldr     x0, =msg_prompt
    bl      print_str
    ldr     x0, =msg_bye
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Subroutines ----

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
.loop:
    ldrb    w5, [x4]
    cbz     w5, .ret
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       .loop
.ret:
    ldp     x29, x30, [sp], #16
    ret

uart_putc:
    movz    x8, #0x0900, lsl #16
.wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, .wait
    strb    w0, [x8]
    ret

// ---- Data ----
msg_banner:   .asciz "ARM64 MiniShell\n"
msg_prompt:   .asciz "> "
msg_hello_out:.asciz "Hello!\n"
msg_bye:      .asciz "Bye!\n"
msg_help1:    .asciz "=== Commands ===\n"
msg_help2:    .asciz "hello - Say hello\n"
msg_help3:    .asciz "help  - Show help\n"
msg_help4:    .asciz "quit  - Exit\n"

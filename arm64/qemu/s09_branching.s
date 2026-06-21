// s09_branching.s - Scenario 9: Menu Branching
// ==============================================
// Learning objectives:
//   - Sequential menu text output (automated demo)
//   - Building structured output from string constants
//   - (演習) CMP + B.EQ/B.NE で選択肢を分岐させる処理を追加してみよう

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Print menu
    ldr     x0, =msg_header
    bl      print_str
    ldr     x0, =msg_opt1
    bl      print_str
    ldr     x0, =msg_opt2
    bl      print_str
    ldr     x0, =msg_opt3
    bl      print_str
    ldr     x0, =msg_opt4
    bl      print_str

    // Auto-execute option 1: Hello
    ldr     x0, =msg_arrow
    bl      print_str
    ldr     x0, =msg_hello
    bl      print_str

    // Auto-execute option 2: Count 1-5
    ldr     x0, =msg_arrow
    bl      print_str
    mov     x19, #1
.count:
    add     w0, w19, #'0'
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    add     x19, x19, #1
    cmp     x19, #6
    b.lt    .count
    mov     w0, #'\n'
    bl      uart_putc

    // Auto-execute option 3: Show regs
    ldr     x0, =msg_arrow
    bl      print_str
    ldr     x0, =msg_x0
    bl      print_str
    mov     x0, #1
    bl      print_hex64
    mov     w0, #' '
    bl      uart_putc
    ldr     x0, =msg_x1
    bl      print_str
    mov     x0, #2
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str

    ldr     x0, =msg_done
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

print_hex64:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x19, x0
    mov     x20, #60
.hex_loop:
    lsr     x0, x19, x20
    and     x0, x0, #0xF
    cmp     x0, #9
    b.hi    .alpha
    add     x0, x0, #'0'
    b       .print
.alpha:
    add     x0, x0, #('A' - 10)
.print:
    bl      uart_putc
    subs    x20, x20, #4
    b.pl    .hex_loop
    ldp     x19, x20, [sp], #16
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
msg_header: .asciz "=== Menu ===\n"
msg_opt1:   .asciz "1: Say Hello\n"
msg_opt2:   .asciz "2: Count 1-5\n"
msg_opt3:   .asciz "3: Show regs\n"
msg_opt4:   .asciz "4: Quit\n"
msg_arrow:  .asciz "-> "
msg_hello:  .asciz "Hello!\n"
msg_x0:     .asciz "X0=0x"
msg_x1:     .asciz "X1=0x"
msg_done:   .asciz "Done!\n"
newline:    .asciz "\n"

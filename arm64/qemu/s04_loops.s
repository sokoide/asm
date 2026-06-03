// s04_loops.s - Scenario 4: Loops and Conditional Branching
// ==========================================================
// Learning objectives:
//   - SUBS + B.NE for countdown loops
//   - ADD + CMP + B.LT for count-up loops
//   - TST + B.EQ for even/odd testing

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // --- Countdown 5 to 1 ---
    ldr     x0, =msg_down
    bl      print_str

    mov     x19, #5
.countdown:
    add     w0, w19, #'0'
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    subs    x19, x19, #1
    b.ne    .countdown
    ldr     x0, =newline
    bl      print_str

    // --- Count-up 1 to 5 ---
    ldr     x0, =msg_up
    bl      print_str

    mov     x19, #1
.countup:
    add     w0, w19, #'0'
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    add     x19, x19, #1
    cmp     x19, #6
    b.lt    .countup
    ldr     x0, =newline
    bl      print_str

    // --- Even numbers ---
    ldr     x0, =msg_even
    bl      print_str

    mov     x19, #2
.even_loop:
    tst     x19, #1
    b.ne    .not_even
    add     w0, w19, #'0'
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
.not_even:
    add     x19, x19, #1
    cmp     x19, #10
    b.lt    .even_loop
    ldr     x0, =newline
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
msg_down: .asciz "Countdown: "
msg_up:   .asciz "Count-up:  "
msg_even: .asciz "Even:      "
newline:  .asciz "\n"

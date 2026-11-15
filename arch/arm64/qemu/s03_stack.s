// s03_stack.s - Scenario 3: Stack Operations
// ===========================================
// Learning objectives:
//   - STP/LDP for pushing/popping register pairs
//   - Stack grows downward (SP decreases)
//   - LIFO: last pushed = first popped

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // --- Push two values ---
    ldr     x0, =msg_push
    bl      print_str

    ldr     x2, =0xAAAA
    ldr     x3, =0xBBBB

    ldr     x0, =msg_x2
    bl      print_str
    mov     x0, x2
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str

    ldr     x0, =msg_x3
    bl      print_str
    mov     x0, x3
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str

    // Push x2, x3 onto stack
    stp     x2, x3, [sp, #-16]!

    // Corrupt to prove stack works
    mov     x2, #0
    mov     x3, #0

    // --- Pop values ---
    ldr     x0, =msg_pop
    bl      print_str

    ldp     x4, x5, [sp], #16

    // Save popped values in callee-saved regs before calling print functions
    mov     x19, x4
    mov     x20, x5

    ldr     x0, =msg_p1
    bl      print_str
    mov     x0, x19
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str

    ldr     x0, =msg_p2
    bl      print_str
    mov     x0, x20
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
msg_push: .asciz "=== Push ===\n"
msg_x2:   .asciz "  X2 = 0x"
msg_x3:   .asciz "  X3 = 0x"
msg_pop:  .asciz "=== Pop (LIFO) ===\n"
msg_p1:   .asciz "  Pop1 = 0x"
msg_p2:   .asciz "  Pop2 = 0x"
msg_done: .asciz "Stack OK!\n"
newline:  .asciz "\n"

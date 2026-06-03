// s07_subroutines.s - Scenario 7: Subroutines (BL/RET)
// =====================================================
// Learning objectives:
//   - BL (branch with link) and RET
//   - Parameter passing in X0-X7
//   - Nested subroutine calls
//   - STP/LDP for callee-saved registers

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // add3(x) = x + 3
    mov     x0, #10
    bl      add3
    ldr     x19, =msg1
    bl      show_result

    mov     x0, #20
    bl      add3
    ldr     x19, =msg2
    bl      show_result

    mov     x0, #30
    bl      add3
    ldr     x19, =msg3
    bl      show_result

    // Nested: double(add3(5))
    mov     x0, #5
    bl      add3               // x0 = 8
    bl      double_val         // x0 = 16
    ldr     x19, =msg4
    bl      show_result

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// add3: return x0 + 3
add3:
    add     x0, x0, #3
    ret

// double_val: return x0 * 2
double_val:
    lsl     x0, x0, #1
    ret

// show_result: print label (x19) and hex value (x0)
show_result:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x20, x0            // save result
    mov     x0, x19
    bl      print_str
    mov     x0, x20
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ---- Common subroutines ----

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
msg1:    .asciz "add3(10)         = 0x"
msg2:    .asciz "add3(20)         = 0x"
msg3:    .asciz "add3(30)         = 0x"
msg4:    .asciz "double(add3(5))  = 0x"
newline: .asciz "\n"

// s10_bitwise.s - Scenario 10: Bitwise Operations
// =================================================
// Learning objectives:
//   - AND, ORR, EOR, LSL, LSR
//   - Binary output subroutine
//   - Bit manipulation patterns

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // AND: 0xFF & 0x0F = 0x0F
    ldr     x0, =msg_and
    bl      print_str
    mov     x19, #0xFF
    and     x19, x19, #0x0F
    mov     x0, x19
    bl      print_hex8
    mov     w0, #' '
    bl      uart_putc
    mov     x0, x19
    bl      print_bin8
    ldr     x0, =newline
    bl      print_str

    // ORR: 0xF0 | 0x0F = 0xFF
    ldr     x0, =msg_or
    bl      print_str
    mov     x19, #0xF0
    orr     x19, x19, #0x0F
    mov     x0, x19
    bl      print_hex8
    mov     w0, #' '
    bl      uart_putc
    mov     x0, x19
    bl      print_bin8
    ldr     x0, =newline
    bl      print_str

    // EOR: 0xFF ^ 0x0F = 0xF0
    ldr     x0, =msg_xor
    bl      print_str
    mov     x19, #0xFF
    eor     x19, x19, #0x0F
    mov     x0, x19
    bl      print_hex8
    mov     w0, #' '
    bl      uart_putc
    mov     x0, x19
    bl      print_bin8
    ldr     x0, =newline
    bl      print_str

    // LSL: 1 << 4 = 0x10
    ldr     x0, =msg_shl
    bl      print_str
    mov     x19, #1
    lsl     x19, x19, #4
    mov     x0, x19
    bl      print_hex8
    mov     w0, #' '
    bl      uart_putc
    mov     x0, x19
    bl      print_bin8
    ldr     x0, =newline
    bl      print_str

    // LSR: 0x80 >> 3 = 0x10
    ldr     x0, =msg_shr
    bl      print_str
    mov     x19, #0x80
    lsr     x19, x19, #3
    mov     x0, x19
    bl      print_hex8
    mov     w0, #' '
    bl      uart_putc
    mov     x0, x19
    bl      print_bin8
    ldr     x0, =newline
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Subroutines ----

// print_hex8: print low byte of x0 as 2 hex digits
print_hex8:
    stp     x29, x30, [sp, #-16]!
    str     x19, [sp, #-16]!
    mov     x29, sp
    and     x19, x0, #0xFF      // save original byte
    lsr     x0, x19, #4         // high nibble
    bl      print_nibble
    and     x0, x19, #0xF       // low nibble from saved value
    bl      print_nibble
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

print_nibble:
    cmp     x0, #9
    b.hi    .alpha
    add     w0, w0, #'0'
    b       uart_putc_branch
.alpha:
    add     w0, w0, #('A' - 10)
uart_putc_branch:
    b       uart_putc

// print_bin8: print low byte of x0 as 8 binary digits
print_bin8:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    and     x19, x0, #0xFF
    mov     x20, #7
.bin_loop:
    lsr     x0, x19, x20
    and     x0, x0, #1
    add     w0, w0, #'0'
    bl      uart_putc
    subs    x20, x20, #1
    b.pl    .bin_loop
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

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
msg_and: .asciz "0xFF & 0x0F = "
msg_or:  .asciz "0xF0 | 0x0F = "
msg_xor: .asciz "0xFF ^ 0x0F = "
msg_shl: .asciz "1 << 4      = "
msg_shr: .asciz "0x80 >> 3   = "
newline: .asciz "\n"

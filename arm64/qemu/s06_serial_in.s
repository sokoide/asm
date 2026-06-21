// s06_serial_in.s - Scenario 6: Serial Input
// ============================================
// Learning objectives:
//   - PL011 UART receive (UARTFR bit 4 = RXFE)
//   - uart_getc subroutine for character input
//   - Echo back received characters
//   - Character classification (digit / uppercase / lowercase / other)

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    ldr     x0, =msg_welcome
    bl      print_str

    // Read and echo characters until 'q'
.Lread_loop:
    bl      uart_getc            // x0 = received char
    mov     w9, #'q'
    cmp     w0, w9
    b.eq    .Ldone

    // Echo the character back, then a space
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc

    // Classify: digit? (unsigned compare, ASCII is 0..255)
    mov     w9, #'0'
    cmp     w0, w9
    b.lo    .Lnot_digit
    mov     w9, #'9'
    cmp     w0, w9
    b.hi    .Lnot_digit
    ldr     x0, =msg_digit
    bl      print_str
    b       .Lread_loop
.Lnot_digit:

    // Classify: uppercase letter?
    mov     w9, #'A'
    cmp     w0, w9
    b.lo    .Lnot_upper
    mov     w9, #'Z'
    cmp     w0, w9
    b.hi    .Lnot_upper
    ldr     x0, =msg_upper
    bl      print_str
    b       .Lread_loop
.Lnot_upper:

    // Classify: lowercase letter?
    mov     w9, #'a'
    cmp     w0, w9
    b.lo    .Lnot_lower
    mov     w9, #'z'
    cmp     w0, w9
    b.hi    .Lnot_lower
    ldr     x0, =msg_lower
    bl      print_str
    b       .Lread_loop
.Lnot_lower:
    ldr     x0, =msg_other
    bl      print_str
    b       .Lread_loop

.Ldone:
    ldr     x0, =msg_quit
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- UART I/O ----

uart_putc:
    movz    x8, #0x0900, lsl #16
.Lup_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, .Lup_wait     // bit 5 = TXFF (wait while full)
    strb    w0, [x8]
    ret

uart_getc:
    movz    x8, #0x0900, lsl #16
.Lug_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #4, .Lug_wait     // bit 4 = RXFE (wait while empty)
    ldrb    w0, [x8]              // read UARTDR
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

// ---- Data ----
msg_welcome: .asciz "Type chars (q=quit):\n"
msg_quit:    .asciz "\nGoodbye!\n"
msg_digit:   .asciz "-> digit\n"
msg_upper:   .asciz "-> UPPER\n"
msg_lower:   .asciz "-> lower\n"
msg_other:   .asciz "-> other\n"

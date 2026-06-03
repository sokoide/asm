// s08_hardware.s - Scenario 8: Hardware Access
// =============================================
// Learning objectives:
//   - Read ARM generic timer (CNTVCT_EL0)
//   - Read timer frequency (CNTFRQ_EL0)
//   - MRS instruction for system register access

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Read timer counter
    ldr     x0, =msg_cnt
    bl      print_str
    mrs     x0, CNTVCT_EL0
    bl      print_hex64
    ldr     x0, =newline
    bl      print_str

    // Read timer frequency
    ldr     x0, =msg_freq
    bl      print_str
    mrs     x0, CNTFRQ_EL0
    bl      print_hex64
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
msg_cnt:  .asciz "Timer counter: 0x"
msg_freq: .asciz "Timer freq:    0x"
newline:  .asciz "\n"

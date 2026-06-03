// s05_strings.s - Scenario 5: String Operations
// ==============================================
// Learning objectives:
//   - String length measurement
//   - String copy (LDRB/STRB)
//   - BSS buffer usage

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    ldr     x0, =msg_src
    bl      print_str
    ldr     x0, =src
    bl      print_str
    ldr     x0, =nl
    bl      print_str

    ldr     x0, =src
    bl      strlen
    ldr     x1, =msg_len
    bl      show_dec

    ldr     x0, =dst
    ldr     x1, =src
    bl      strcpy
    ldr     x0, =msg_copy
    bl      print_str
    ldr     x0, =dst
    bl      print_str
    ldr     x0, =nl
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// show_dec: print label (x1) then decimal value (x0) then newline
show_dec:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x19, x0
    mov     x0, x1
    bl      print_str
    mov     x0, x19
    bl      print_uint
    ldr     x0, =nl
    bl      print_str
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// strlen: x0 = string ptr, returns length in x0
strlen:
    mov     x1, x0
sl_loop:
    ldrb    w2, [x1]
    cbz     w2, sl_done
    add     x1, x1, #1
    b       sl_loop
sl_done:
    sub     x0, x1, x0
    ret

// strcpy: copy x1 to x0 until null
strcpy:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x0
sc_loop:
    ldrb    w3, [x1]
    strb    w3, [x2]
    cbz     w3, sc_done
    add     x1, x1, #1
    add     x2, x2, #1
    b       sc_loop
sc_done:
    ldp     x29, x30, [sp], #16
    ret

// print_uint: print x0 as decimal (0-99)
print_uint:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x19, x0
    cmp     x19, #10
    b.lt    pu_ones
    mov     x20, #10
    udiv    x3, x19, x20            // x3 = quotient (tens digit)
    add     w0, w3, #'0'
    bl      uart_putc
    msub    x19, x3, x20, x19      // x19 = remainder (ones digit)
pu_ones:
    add     w0, w19, #'0'
    bl      uart_putc
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
ps_loop:
    ldrb    w5, [x4]
    cbz     w5, ps_done
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       ps_loop
ps_done:
    ldp     x29, x30, [sp], #16
    ret

uart_putc:
    movz    x8, #0x0900, lsl #16
up_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, up_wait
    strb    w0, [x8]
    ret

msg_src:  .asciz "Source: "
msg_len:  .asciz "Length: "
msg_copy: .asciz "Copy:   "
nl:       .asciz "\n"
src:      .asciz "Hello"
.section .bss
dst:      .space 32

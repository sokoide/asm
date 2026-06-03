// s11_memory.s - Scenario 11: Memory Operations
// ===============================================
// Learning objectives:
//   - Block fill (memset)
//   - Block copy (memcpy)
//   - Pre/post-index addressing

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Memset: fill with 'X'
    ldr     x0, =msg_fill
    bl      print_str
    ldr     x0, =buf1
    mov     w1, #'X'
    mov     x2, #5
    bl      my_memset
    // Print result
    ldr     x4, =buf1
    mov     x19, #5
fp_lp:
    ldrb    w0, [x4]
    bl      uart_putc
    mov     w0, #' '
    bl      uart_putc
    add     x4, x4, #1
    subs    x19, x19, #1
    b.ne    fp_lp
    ldr     x0, =nl
    bl      print_str

    // Memcpy: copy string
    ldr     x0, =msg_copy
    bl      print_str
    ldr     x0, =buf2
    ldr     x1, =src
    bl      my_memcpy
    ldr     x0, =buf2
    bl      print_str
    ldr     x0, =nl
    bl      print_str

    // Post-index: [Xn], #imm — access THEN advance pointer
    ldr     x0, =msg_post
    bl      print_str
    ldr     x4, =buf1
    mov     w0, #'A'
    strb    w0, [x4], #1           // store 'A', x4++
    mov     w0, #'B'
    strb    w0, [x4], #1           // store 'B', x4++
    mov     w0, #'C'
    strb    w0, [x4], #1           // store 'C', x4++
    strb    wzr, [x4]              // null terminate
    ldr     x0, =buf1
    bl      print_str
    ldr     x0, =nl
    bl      print_str

    // Pre-index: [Xn, #imm]! — advance pointer THEN access
    ldr     x0, =msg_pre
    bl      print_str
    ldr     x4, =buf1
    sub     x4, x4, #1             // start one byte before buf1
    ldrb    w0, [x4, #1]!          // x4++, load 'A'
    bl      uart_putc
    ldrb    w0, [x4, #1]!          // x4++, load 'B'
    bl      uart_putc
    ldrb    w0, [x4, #1]!          // x4++, load 'C'
    bl      uart_putc
    ldr     x0, =nl
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

my_memset:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x3, x0
ms_lp:
    cbz     x2, ms_dn
    strb    w1, [x3], #1
    subs    x2, x2, #1
    b.ne    ms_lp
ms_dn:
    ldp     x29, x30, [sp], #16
    ret

my_memcpy:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x3, x0
mc_lp:
    ldrb    w4, [x1], #1
    strb    w4, [x3], #1
    cbz     w4, mc_dn
    b       mc_lp
mc_dn:
    ldp     x29, x30, [sp], #16
    ret

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x4, x0
ps_lp:
    ldrb    w5, [x4]
    cbz     w5, ps_dn
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       ps_lp
ps_dn:
    ldp     x29, x30, [sp], #16
    ret

print_hex64:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x29, sp
    mov     x19, x0
    mov     x20, #60
ph_lp:
    lsr     x0, x19, x20
    and     x0, x0, #0xF
    cmp     x0, #9
    b.hi    ph_al
    add     x0, x0, #'0'
    b       ph_pr
ph_al:
    add     x0, x0, #('A' - 10)
ph_pr:
    bl      uart_putc
    subs    x20, x20, #4
    b.pl    ph_lp
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

uart_putc:
    movz    x8, #0x0900, lsl #16
up_wt:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, up_wt
    strb    w0, [x8]
    ret

msg_fill: .asciz "Fill:   "
msg_copy: .asciz "Copy:   "
msg_post: .asciz "Post-id: "
msg_pre:  .asciz "Pre-id:  "
nl:       .asciz "\n"
src:      .asciz "Hello"
buf1:     .space 32
buf2:     .space 32

// s06_serial_in.s - Scenario 6: Serial Input
// ============================================
// Learning objectives:
//   - UART receive (UARTFR bit 4 = RXFE)
//   - uart_getc サブルーチンを定義（自動テストでは未使用、
//     演習としてエコーバックの実装に活用できる）

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    ldr     x0, =msg
    bl      print_str

    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

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

uart_putc:
    movz    x8, #0x0900, lsl #16
up_wt:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, up_wt
    strb    w0, [x8]
    ret

uart_getc:
    movz    x8, #0x0900, lsl #16
ug_wt:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #4, ug_wt
    ldrb    w0, [x8]
    ret

msg: .asciz "Type chars (Enter=quit):\n"

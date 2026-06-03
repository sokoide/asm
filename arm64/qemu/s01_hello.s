// s01_hello.s - Scenario 1: Hello World
// ========================================
// Learning objectives:
//   - ARM64 program structure (AArch64 bare-metal)
//   - UART PL011 output on QEMU virt machine
//   - MOVZ instruction for loading constants
//   - STRB instruction for MMIO write
//   - Null-terminated string iteration
//   - Semihosting exit for clean QEMU termination

.section .text
.global _start

_start:
    // Set up stack pointer (below kernel load address)
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Print message
    ldr     x0, =message
    bl      print_str

    // Exit via semihosting (AArch64: x1 must be a pointer to a two-word block)
    mov     x0, #0x18            // angel_SWIreason_ReportException
    ldr     x1, =exit_reason     // pointer to { ADP_Stopped_ApplicationExit, 0 }
    hlt     #0xF000

// ---- Subroutines ----

// print_str: print null-terminated string at x0
print_str:
    stp     x29, x30, [sp, #-16]!   // Save frame pointer and LR
    mov     x29, sp                  // Set frame pointer (optional but conventional)
    mov     x4, x0               // x4 = string pointer
.loop:
    ldrb    w5, [x4]             // load byte
    cbz     w5, .ret             // if null, done
    mov     w0, w5               // character to w0
    bl      uart_putc            // print character
    add     x4, x4, #1           // next byte
    b       .loop
.ret:
    ldp     x29, x30, [sp], #16     // Restore frame pointer and LR
    ret

// uart_putc: write character in w0 to UART0
// Preserves all registers except x8, x9
uart_putc:
    movz    x8, #0x0900, lsl #16    // x8 = 0x09000000 (UART0 base)
.wait:
    ldr     w9, [x8, #0x18]         // read UARTFR
    tbnz    w9, #5, .wait           // bit 5 = TXFF, wait if full
    strb    w0, [x8]                // write byte to UARTDR
    ret

// ---- Data ----
message:
    .asciz "Hello, ARM64 World!\n"

    .align 3
exit_reason:
    .dword 0x20026               // ADP_Stopped_ApplicationExit
    .dword 0x0                   // subcode

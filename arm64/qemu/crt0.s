// crt0.s - C runtime startup for _common/c/c*.c scenarios (c01, c02, ...)
// Learning objectives:
//   - minimal C runtime: stack setup, .bss clear, main() call
//   - how clang-compiled code (c01.s etc.) is bootstrapped on bare metal
//
// C scenarios are built as (see Makefile build-c):
//   clang --target=aarch64-none-elf -g -O0 -S
//         ../../_common/c/c01.c -o ../../_common/c/c01.s
//   clang crt0.s + c01.s -> ld.lld -T linker.ld  (ENTRY(_start) is here)

.section .text
.global _start

_start:
    // Set up stack pointer (same as s01_hello)
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Clear .bss (__bss_start..__bss_end from linker.ld); C assumes zeroed bss
    // (byte loop: no alignment assumption on __bss_start)
    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
.Lbss:
    cmp     x0, x1
    b.hs    .Lbss_done
    strb    wzr, [x0], #1
    b       .Lbss
.Lbss_done:

    // Call main(); return value is left in w0
    bl      main

    // Exit via semihosting (same as s01_hello; AArch64: x1 must be a pointer
    // to a two-word block). Pass main's return value (w0) as the subcode:
    // QEMU exits with the subcode when the reason is ApplicationExit
    // (verified: subcode 42 -> host exit code 42)
    mov     x2, x0               // save main's return value
    mov     x0, #0x18            // angel_SWIreason_ReportException
    ldr     x1, =exit_reason     // pointer to { ADP_Stopped_ApplicationExit, subcode }
    str     x2, [x1, #8]         // subcode = main's return value
    hlt     #0xF000

// ---- Data ----

    .align 3
exit_reason:
    .dword 0x20026               // ADP_Stopped_ApplicationExit
    .dword 0x0                   // subcode (filled with main's return value at exit)

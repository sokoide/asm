// crt0.s - C runtime startup for _common/c/c*.c scenarios (c01, c02, ...)
// ========================================
// Learning objectives:
//   - minimal C runtime: stack setup, .bss clear, main() call
//   - how clang-compiled code (c01.s etc.) is bootstrapped on bare metal
//
// C scenarios are built as (see Makefile build-c):
//   clang --target=powerpc-none-elf -g -O0 -S
//         ../../_common/c/c01.c -o ../../_common/c/c01.s
//   clang crt0.s + c01.s -> ld.lld -T linker.ld  (ENTRY(_start) is here)

.section .text
.global _start

_start:
    // Set up stack (same as s01_hello)
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Clear .bss (__bss_start..__bss_end from linker.ld); C assumes zeroed bss
    // (byte loop: no alignment assumption on __bss_start)
    lis     %r8, __bss_start@ha
    addi    %r8, %r8, __bss_start@l
    lis     %r9, __bss_end@ha
    addi    %r9, %r9, __bss_end@l
    li      %r10, 0
.bss_loop:
    cmplw   %r8, %r9
    bge     .bss_done
    stb     %r10, 0(%r8)
    addi    %r8, %r8, 1
    b       .bss_loop
.bss_done:

    // Call main(); return value is left in r3 (ELFv1 ABI)
    bl      main

    // Halt
    // No exit device on bamboo (same as s01_hello)
halt:
    b       halt

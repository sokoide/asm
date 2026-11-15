// crt0.s - C runtime startup for common/c/c*.c scenarios (c01, c02, ...)
// Learning objectives:
//   - minimal C runtime: stack setup, .bss clear, main() call
//   - how clang-compiled code (c01.s etc.) is bootstrapped on bare metal
//
// C scenarios are built as (see Makefile build-c):
//   clang --target=riscv64-unknown-elf -march=rv64im -mabi=lp64 -g -O0 -S
//         ../../../common/c/c01.c -o ../../../common/c/c01.s
//   clang crt0.s + c01.s -> ld.lld -T linker.ld  (ENTRY(_start) is here)

.section .text
.global _start

_start:
	// Set up stack pointer (same as s01_hello)
	li      sp, 0x80200000

	// Clear .bss (__bss_start..__bss_end from linker.ld); C assumes zeroed bss
	// (byte loop: no alignment assumption on __bss_start)
	la      a0, __bss_start
	la      a1, __bss_end
.Lbss:
	bgeu    a0, a1, .Lbss_done
	sb      zero, 0(a0)
	addi    a0, a0, 1
	j       .Lbss
.Lbss_done:

	// Call main(); return value is left in a0
	call    main

	// Exit via SiFive test finisher (same as s01_hello)
	li      t0, 0x100000
	li      t1, 0x5555
	sw      t1, 0(t0)

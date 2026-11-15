# crt0.s - C runtime startup for common/c/c*.c scenarios (c01, c02, ...)
# Learning objectives:
# - minimal C runtime: stack setup, .bss clear, main() call
# - how gcc-compiled code (c01.s etc.) is bootstrapped on bare metal
#
# C scenarios are built as (see Makefile build-c):
# gcc -g -O0 -m68000 -S ../../../common/c/c01.c -o ../../../common/c/c01.s
# as  crt0.s + c01.s -> ld -T linker.ld  (ENTRY(_start) is defined here)
#
# Note: on m68k gas '#' is the immediate prefix, so comments are
# full-line only (same convention as the other scenario files).

.text
.global _start

_start:
	# stack top (same as s01_hello)
	move.l  #0x4000, %sp

	# clear .bss (__bss_start..__bss_end from linker.ld); C assumes zeroed bss
	lea     __bss_start, %a0
	lea     __bss_end, %a1
.Lbss:
	# loop while a0 < a1 (unsigned): a0 - a1 sets carry
	cmpa.l  %a1, %a0
	bcc     .Lbss_done
	clr.l   (%a0)+
	bra     .Lbss
.Lbss_done:

	# main() return value is left in %d0
	jsr     main

halt:
	# no clean exit on the virt machine (same as s01)
	bra     halt

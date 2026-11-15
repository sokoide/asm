; crt0.asm - C runtime startup for _common/c/c*.c scenarios (c01, c02, ...)
; =========================================================
; Learning objectives:
;   - minimal C runtime: what boot.asm leaves for the C code to do
;   - System V ABI: main の戻り値は RAX
;
; C scenarios are built as (see Makefile build-c):
;   clang --target=x86_64-pc-none-elf -mno-red-zone -g -O0 -S
;         ../../_common/c/c01.c -o ../../_common/c/c01.s
;   nasm crt0.asm + clang c01.s -> ld.lld -T linker.ld (boot.o + crt0.o + c01.o)
;
; boot.asm の移行スタブが 16->64bit ロングモード移行・RSP=0x90000 ・
; .bss ゼロ初期化 (rep stosb) まで済ませて _start (0x8000) へ jmp してくる
; ため、ここでは main を呼んで hlt するだけ。

bits 64

section .text
global _start, scenario_halt
extern main

_start:
	call    main                ; 戻り値は RAX (System V ABI)

; trace/icount/test (python スクリプト) は scenario_halt シンボルで
; 終了位置を検出する (s01_hello 等と同じ規約)
scenario_halt:
	cli ; IDT 未構築のため割り込み禁止のまま停止
	hlt
	jmp     scenario_halt

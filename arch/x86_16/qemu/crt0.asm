; crt0.asm - C runtime startup for common/c/c*.c scenarios (c01, c02, ...)
; =========================================
; Learning objectives:
;   - boot sector structure (bits 16, 0x7C00) and segment/stack setup
;   - how -m16 C code (.code16) is bootstrapped on real mode
;
; C scenarios are built as (see Makefile build-c):
;   clang --target=i386-pc-none-elf -m16 -g -O0 -S
;         ../../../common/c/c01.c -o ../../../common/c/c01.s
;   nasm -f elf32 crt0.asm + clang c01.s -> ld.lld -T linker.ld
;
; 注意: clang -m16 の出力 (.code16) は 386 以降の命令 (32-bit オペランドの
; 66/67 プレフィックス付き命令) を含み、関数の call/ret も 4 バイト戻り
; アドレス (calll/retd) で行う。QEMU の既定 CPU (qemu32) では動作するが、
; 実 8086 では動作しない (手書きシナリオが cpu 8086 なのとの違い)。
; ブート署名 (0xAA55 @ 510) は Makefile の build-c がリンク後に追記する
; (ELF リンクではイメージ末尾の位置が確定しないため)。

cpu 386
bits 16

section .text
global _start
extern main

_start:
	; セグメントとスタックの初期化 (s01_hello と同じ)
	xor     ax, ax
	mov     ds, ax              ; データセグメント = 0 (フラット)
	mov     es, ax              ; エクストラセグメント = 0
	mov     ss, ax              ; スタックセグメント = 0
	mov     sp, 0x7C00          ; スタックはコード直下から下方成長

	; o32 (66 プレフィックス) 付き call = 4 バイト戻りアドレスを push。
	; clang -m16 の関数は retd (4 バイト pop) で返るため、16-bit call (2 バイト
	; push) だとスタックがずれて戻り先が狂う。このため cpu 386 が必要。
	o32     call main           ; 戻り値は AX (EAX 下位 16 bit)

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
	jmp     .halt               ; NMI で再開しても再度停止

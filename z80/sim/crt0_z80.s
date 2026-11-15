; crt0_z80.s - C runtime startup for _common/c/c*.c scenarios (c01, c02, ...)
; =========================================
; Learning objectives:
;   - CP/M .com structure (TPA 0x0100) shared with the hand-written scenarios
;   - how SDCC (-mz80, sdcccall(1)) C code is bootstrapped: first 16-bit arg
;     in HL, second in DE, 16-bit return value in DE
;
; C scenarios are built as (see Makefile build-c):
;   sdcc  -mz80 --no-peep -S ../../_common/c/c01.c -o ../../_common/c/c01.s
;   sdasz80 -go crt0_z80.rel crt0_z80.s + sdasz80 -go c01.rel c01.s
;   sdcc  -mz80 --no-std-crt0 --code-loc 0x0100 -o c01.ihx crt0_z80.rel c01.rel
;   makebin -p -o 256 c01.ihx c01.com  (ihx は 0x0000 起点で書くため先頭 256 バイトを捨てる)
;
; 注意: 生成される c01.s は sdasz80 構文 (.area ディレクティブ付き) のため
; z80asm ではアセンブルできない。また本 crt0 は GSINIT (静的変数の初期化)
; を呼ばない最小構成で、_common/c/c01.c / c02.c は静的変数を持たないため
; これで十分 (static 変数付きの C を置く場合は要改造)。

	.module	crt0_z80

	.area	_CODE

start:
	call    _main       ; SDCC の C main (sdcccall(1): 戻り値 16-bit は DE)
	ret ; CP/M へ復帰 (SP 上の 0x0000 に戻り simz80 停止)

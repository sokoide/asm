; s01_hello.asm - Scenario 1: Hello World (64-bit ロングモード)
; =========================================
; Learning objectives:
;   - ブート → 移行スタブ (16 → 32 → 64) → 0x8000 の _start という実行フローの確認
;   - 64-bit レジスタ (RSI/RDX/RAX) とポート入出力 (IN/OUT)
;   - COM1 UART 出力 (16550 at I/O port 0x3F8)
;   - LODSB と NULL 終端文字列
;   - CPU 停止ループ (CLI + HLT)
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。IDT 未構築のため INT は使用不可なので、
; 出力は UART を直接叩く。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
	lea     rsi, [rel message]    ; RSI = 文字列へのポインタ (RIP 相対)
.print_loop:
	lodsb ; AL = [DS:RSI], RSI++ (DF = 0 なので正向き)
	or      al, al                ; NULL 終端?
	jz      .halt
	call    uart_putc             ; COM1 へ 1 文字出力
    jmp  .print_loop

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
	push    rdx
	push    rax
	mov     dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8             ; THR (送信保持レジスタ)
	pop     rax
	out     dx, al
	pop     rdx
	ret

; ---- データ ----
section .rodata
message db "Hello, x86_64 World!", 13, 10, 0

scenario_halt equ _start.halt

; s06_serial_in.asm - Scenario 6: Serial Input (32-bit 保護モード)
; ==============================================
; Learning objectives:
;   - COM1 UART の受信 (LSR bit 0 = Data Ready)
;   - ポーリングループによるシリアル入力
;   - 入力文字のエコーバック
;   - Enter キー (CR/LF) による終了
;
; 本シナリオは boot.asm のスタブが保護モード移行を終えた後、
; 0x8000 から実行される。IDT 未構築のため割り込みは使えず、
; UART のラインステータスレジスタをポーリングして入力を待つ。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; イントロを表示
	mov     esi, msg_intro
	call    print_str

    ; メインループ: 1 文字読んではエコーする
.loop:
	call    uart_getc            ; AL = 受信文字

    ; Enter (CR または LF) で終了
	cmp     al, 13
	je      .done
	cmp     al, 10
	je      .done

    ; エコーバック
	call    uart_putc
    jmp  .loop

.done:
	call    print_crlf
	mov     esi, msg_bye
	call    print_str

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
	push    edx
	push    eax
	mov     dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8             ; THR (送信保持レジスタ)
	pop     eax
	out     dx, al
	pop     edx
	ret

; uart_getc: COM1 から 1 文字を受信して AL に返す
uart_getc:
	push    edx
	mov     dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x01              ; bit 0 = DR (受信データあり)
	jz      .wait
	mov     dx, 0x3F8             ; RBR (受信バッファレジスタ)
	in      al, dx
	pop     edx
	ret

; print_str: ESI が指す NULL 終端文字列を出力 (ESI を進める)
print_str:
	lodsb
	or      al, al
	jz      .ret
	call    uart_putc
    jmp  print_str
.ret:
	ret

; print_crlf: CR + LF を出力
print_crlf:
	push    eax
	mov     al, 13
	call    uart_putc
	mov     al, 10
	call    uart_putc
	pop     eax
	ret

; ---- データ ----
section .rodata
msg_intro db "Type chars (Enter=quit):", 13, 10, 0
msg_bye   db "Bye!", 13, 10, 0

scenario_halt equ _start.halt

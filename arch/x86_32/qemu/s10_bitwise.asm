; s10_bitwise.asm - Scenario 10: ビット演算 (32-bit 保護モード)
; ====================================================
; Learning objectives:
;   - AND: マスクで特定ビットの抽出
;   - OR: ビットのセット / 合成
;   - XOR: ビットのトグル, レジスタのゼロ化 (XOR reg, reg)
;   - SHL / SHR: 32 ビットの左 / 右シフト (bit 31 の扱い)
;   - ROR: 32 ビットの回転 (はみ出したビットは反対側へ戻る)
;   - 32 桁の 2 進表示, 8 桁の 16 進表示ルーチン
;
; 16-bit 版との違いはシフト / マスク / 回転の対象が 32 ビット幅に
; なった点。bit 31 (最上位ビット) が実際に使われる値での SHL/SHR は
; 32-bit ならではの学習ポイント。本シナリオは boot.asm のスタブが
; 保護モード移行を終えた後, 0x8000 から実行され, 出力は UART を
; 直接叩く。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- AND: マスクで各バイトの下位ニブルを抽出 ---
	mov     esi, msg_and
	call    print_str
	mov     eax, 0x5A5A5A5A    ; 0101 1010 x 4
	and     eax, 0x0F0F0F0F    ; 下位ニブルだけ残す = 0x0A0A0A0A
	call    print_bin32
	mov     al, ' '
	call    uart_putc
	mov     al, '='
	call    uart_putc
	mov     al, ' '
	call    uart_putc
	mov     eax, 0x5A5A5A5A    ; print_bin32 は EAX を壊すので再度計算
	and     eax, 0x0F0F0F0F
	call    print_hex32
	call    print_crlf

    ; --- OR: ビットの合成 ---
	mov     esi, msg_or
	call    print_str
	mov     eax, 0x50505050    ; 0101 0000 x 4
	or      eax, 0x0A0A0A0A    ; 上位ニブル + 下位ニブル = 0x5A5A5A5A
	call    print_hex32
	call    print_crlf

    ; --- XOR: ビットのトグル ---
	mov     esi, msg_xor
	call    print_str
	mov     eax, 0xFFFFFFFF    ; 1111 1111 x 4
	xor     eax, 0x0F0F0F0F    ; 下位ニブルを反転 = 0xF0F0F0F0
	call    print_hex32
	call    print_crlf

    ; --- XOR reg, reg: ゼロ化の定石 ---
    ; xor eax, eax は mov eax, 0 より短く, フラグもクリアする

    ; --- SHL: 32 ビットを 1 ビット左シフト (bit 30 -> bit 31) ---
	mov     esi, msg_shl
	call    print_str
	mov     eax, 0x40000000
	shl     eax, 1             ; 最上位ビットに立つ = 0x80000000
	call    print_hex32
	call    print_crlf

    ; --- SHR: 32 ビットを 1 ビット右シフト (bit 31 -> bit 30, 0 埋め) ---
	mov     esi, msg_shr
	call    print_str
	mov     eax, 0x80000000
	shr     eax, 1             ; bit 31 が落ちる = 0x40000000
	call    print_hex32
	call    print_crlf

    ; --- ROR: 回転シフト (落ちたビットは最上位へ戻る) ---
	mov     esi, msg_ror
	call    print_str
	mov     eax, 0x12345678
	ror     eax, 8             ; 下位 8 ビットが最上位へ = 0x78123456
	call    print_hex32
	call    print_crlf

    ; --- 視覚確認: 0xA5A5A5A5 を 32 桁の 2 進数で表示 ---
	mov     esi, msg_vis
	call    print_str
	mov     eax, 0xA5A5A5A5
	call    print_bin32
	call    print_crlf

	mov     esi, msg_done
	call    print_str

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt              ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
	push    edx
	push    eax
	mov     dx, 0x3FD          ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20           ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8          ; THR (送信保持レジスタ)
	pop     eax
	out     dx, al
	pop     edx
	ret

; print_bin32: EAX を 32 桁の 2 進数で表示 (MSB 先頭, EAX/ECX 破壊)
print_bin32:
	mov     ecx, 32            ; ビット数
.bit_loop:
	shl     eax, 1             ; 最上位ビットを CF へ押し出す (32-bit シフト)
	push    eax                ; シフト後の値を退避
	mov     al, '0'
	jnc     .zero
	mov     al, '1'
.zero:
	call    uart_putc
	pop     eax
	loop    .bit_loop
	ret

; print_str: ESI が指す NULL 終端文字列を表示 (LODSB が ESI を自動進行)
print_str:
	lodsb ; AL = [DS:ESI], ESI++
	or      al, al             ; NULL 終端?
	jz      .ret
	call    uart_putc
    jmp  print_str
.ret:
	ret

; print_hex32: EAX を 8 桁の 16 進数で表示 (上位ニブルから, EAX/ECX 破壊)
;   ROL 4 を 8 回行うと元に戻る性質を利用してニブルを取り出す
print_hex32:
	mov     ecx, 8             ; ニブル数
.next:
	rol     eax, 4             ; 上位ニブルを下位 4 ビットへ回転
	push    eax
	call    print_nibble       ; AL の下位ニブルを表示 (print_nibble 内でマスク)
	pop     eax
	loop    .next
	ret

; print_nibble: AL の下位 4 ビットを 1 桁の 16 進文字で表示 (AL 破壊)
print_nibble:
	and     al, 0x0F
	add     al, '0'
	cmp     al, '9'
	jle     .out
	add     al, 7
.out:
	call    uart_putc
	ret

; print_crlf: CR (0x0D) + LF (0x0A) を出力
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
msg_and  db "AND 0x5A5A5A5A, 0x0F0F0F0F: ", 0
msg_or   db "OR  0x50505050, 0x0A0A0A0A: 0x", 0
msg_xor  db "XOR 0xFFFFFFFF, 0x0F0F0F0F: 0x", 0
msg_shl  db "SHL 0x40000000, 1: 0x", 0
msg_shr  db "SHR 0x80000000, 1: 0x", 0
msg_ror  db "ROR 0x12345678, 8: 0x", 0
msg_vis  db "0xA5A5A5A5 binary: ", 0
msg_done db 13, 10, "Bitwise done!", 0

scenario_halt equ _start.halt

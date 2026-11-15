; s13_copybench.asm - Scenario 13: Copy Benchmark (全アーキ共通課題)
; ==============================================================================
; Learning objectives:
;   - REP MOVSB: 32-bit ESI/EDI/ECX を使う 386 のブロック転送 (ループコードなしのコピー)
;   - 100 バイトメモリコピーのチェックサム検証
;
; Task (全アーキ共通仕様):
;   - byte i = i (0..99) となる 100 バイトをコピー
;   - 宛先 100 バイトの総和を計算 (0+1+...+99 = 4950 = 0x1356)
;   - 出力はちょうど 1 行: "COPY OK CHECKSUM=1356"
;     (不一致時は "COPY FAIL CHECKSUM=xxxx")
;
; Build: nasm -f elf32 + ld.lld (boot.asm スタブ経由で 0x8000 から実行、s01 と同じ)
;
; NOTE: サイクル数だけでは CPU 間の速度比較はできない (QEMU TCG はサイクル
;       精度でない)。REP MOVSB の手計算サイクル内訳 (8086: 9+17n =
;       17.09 クロック/バイト) は x86_16/qemu/s13_copybench.asm と
;       compare/copybench.md に記載。386 のブロック転送タイミングは
;       copybench.md の比較表の対象外。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
	cld ; DF = 0 (文字列操作は正向き: ESI/EDI をインクリメント)

    ; --- ソースデータ生成: byte i = i (0..99) ---
	mov     edi, src
	xor     eax, eax            ; AL = 0
	mov     ecx, 100
.fill:
	stosb ; [ES:EDI] = AL, EDI++
	inc     al
	loop    .fill              ; ECX--, ECX != 0 の間繰り返し

    ; --- コピー本体: REP MOVSB ---
	mov     esi, src            ; DS:ESI = 転送元
	mov     edi, dst            ; ES:EDI = 転送先
	mov     ecx, 100            ; バイト数
    rep movsb               ; ECX バイトをコピー (ESI/EDI は 1 バイトずつ進む)

    ; --- チェックサム: 宛先 100 バイトの総和 ---
	xor     ebx, ebx            ; EBX = 0 (総和 4950 は 8 ビットに収まらない)
	mov     esi, dst
	mov     ecx, 100
.sum:
	lodsb ; AL = [DS:ESI], ESI++
	add     bl, al
	adc     bh, 0               ; キャリーを上位バイトへ
	loop    .sum

    ; --- 検証して結果を出力 ---
	cmp     ebx, 0x1356         ; 0+1+...+99 = 4950 = 0x1356
	jne     .fail

	mov     esi, msg_ok
	call    print_str
	mov     eax, ebx
	call    print_hex16
	call    print_crlf
    jmp .halt

.fail:
	mov     esi, msg_fail
	call    print_str
	mov     eax, ebx
	call    print_hex16
	call    print_crlf

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp .halt               ; NMI で再開しても再度停止

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

print_str:
	lodsb
	or      al, al
	jz      .ret
	call    uart_putc
    jmp print_str
.ret:
	ret

print_hex16:                ; EAX の下 16 ビットを 4 桁の 16 進で出力
	push    eax
	mov     al, ah
	call    print_hex8         ; 上位バイト
	pop     eax
    jmp print_hex8          ; 下位バイト (末尾呼び出し)

print_hex8:
	push    eax
	mov     cl, 4
	shr     al, cl
	call    print_nibble
	pop     eax
print_nibble:
	and     al, 0x0F
	add     al, '0'
	cmp     al, '9'
	jle     .out
	add     al, 7
.out:
	call    uart_putc
	ret

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
msg_ok   db "COPY OK CHECKSUM=", 0
msg_fail db "COPY FAIL CHECKSUM=", 0

section .data
src      times 100 db 0    ; 実行時に byte i = i (0..99) で埋める
dst      times 100 db 0

scenario_halt equ _start.halt

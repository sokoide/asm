; s04_loops.asm - Scenario 4: Loops and Counters (32-bit 保護モード)
; ================================================
; Learning objectives:
;   - LOOP 命令 (ECX をデクリメントし、ECX != 0 ならジャンプ)
;   - CMP 命令と条件フラグ
;   - 条件分岐: JE, JNE, JL, JG, JLE, JGE
;   - カウントアップ / カウントダウンのパターン
;
; 本シナリオは boot.asm のスタブが保護モード移行を終えた後、
; 0x8000 から実行される。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- Demo 1: LOOP によるカウントダウン (5 から 1) ---
    ; LOOP は ECX をデクリメントし、ECX != 0 ならジャンプする
	mov     esi, msg1
	call    print_str

	mov     ecx, 5
.loop1:
	mov     al, cl
	add     al, '0'             ; 数値を ASCII 数字へ変換
	call    uart_putc
	mov     al, ' '
	call    uart_putc
	loop    .loop1             ; ECX--; ECX != 0 ならジャンプ

	call    print_crlf

    ; ループ終了後の ECX は 0 (32 ビット全体がクリアされている)
	mov     esi, msg_ecx
	call    print_str
	mov     eax, ecx
	call    print_hex32
	call    print_crlf

    ; --- Demo 2: CMP + JLE によるカウントアップ ---
	mov     esi, msg2
	call    print_str

	mov     ecx, 1
.loop2:
	mov     al, cl
	add     al, '0'
	call    uart_putc
	mov     al, ' '
	call    uart_putc
	inc     ecx
	cmp     ecx, 5              ; 5 まで表示したら終了
	jle     .loop2              ; ECX <= 5 ならジャンプ → 出力は 1..5

	call    print_crlf

    ; --- Demo 3: TEST による偶数/奇数判定 ---
    ; TEST は AND を行うが結果は保存せずフラグだけを設定する
	mov     esi, msg3
	call    print_str

	mov     eax, 7
	test    al, 1              ; bit 0 をテスト (奇数/偶数)
	jz      .even
	mov     esi, msg_odd
	call    print_str
    jmp .done3
.even:
	mov     esi, msg_even
	call    print_str
.done3:
	call    print_crlf

	mov     esi, msg_done
	call    print_str

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
	push    edx
	push    eax
	mov     dx, 0x3FD       ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20        ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8       ; THR (送信保持レジスタ)
	pop     eax
	out     dx, al
	pop     edx
	ret

; print_str: NULL 終端文字列を DS:ESI から表示 (ESI は文字列末尾へ進む)
print_str:
	lodsb
	or      al, al              ; NULL 終端?
	jz      .ret
	call    uart_putc
    jmp print_str
.ret:
	ret

; print_hex32: EAX を 8 桁の 16 進数字で表示 (上位バイトから)
print_hex32:
	push    eax
	shr     eax, 16         ; 上位 16 ビットを下位へ
	call    print_hex16
	pop     eax
print_hex16:
	push    eax
	shr     eax, 8          ; bits 8-15 を AL へ
	call    print_hex8
	pop     eax
print_hex8:
	push    eax
	shr     eax, 4          ; 上位ニブル
	call    print_nibble
	pop     eax
print_nibble:
	and     al, 0x0F        ; 下位ニブル
	add     al, '0'
	cmp     al, '9'
	jle     .out
	add     al, 7           ; 'A' - '9' - 1
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
msg1     db "LOOP  5..1: ", 0
msg_ecx  db "ECX after LOOP = 0x", 0
msg2     db "Count 1..5: ", 0
msg3     db "7 is ", 0
msg_odd  db "odd", 0
msg_even db "even", 0
msg_done db 13, 10, "Loops done!", 0

scenario_halt equ _start.halt

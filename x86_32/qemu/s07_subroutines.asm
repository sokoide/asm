; s07_subroutines.asm - Scenario 7: サブルーチン (32-bit 保護モード)
; ================================================
; Learning objectives:
;   - CALL: 戻りアドレスをスタックに退避してラベルへジャンプ
;   - RET: 戻りアドレスをスタックから復帰して呼び出し元へ戻る
;   - レジスタによる引数渡しと戻り値
;   - ネストしたサブルーチン呼び出し
;   - PUSH/POP (32-bit): レジスタの保存と復元
;
; 移行スタブ (boot.asm) が SS/DS/ES をフラットセグメント (0x10) に設定し、
; ESP = 0x90000 (スタックトップ) に初期化済み。保護モードでは常に CPL=0 で
; 動作するため、特別な設定なしにスタックが使える。CALL は 32-bit の
; 戻りアドレス (4 バイト) をスタックに PUSH し、RET がそれを POP する。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- 呼び出し 1: 文字列を出力 ---
	mov     esi, msg1            ; 引数: ESI = 文字列へのポインタ
	call    print_str
	call    print_crlf

    ; --- 呼び出し 2: 値を 8 桁の 16 進で出力 ---
	mov     esi, msg2
	call    print_str
	mov     eax, 0xDEADBEEF      ; 引数: EAX = 表示する値 (32-bit 全幅)
	call    print_hex32
	call    print_crlf

	mov     esi, msg3
	call    print_str
	mov     eax, 0x00C0FFEE      ; 上位桁の 0 も 8 桁すべて出力される
	call    print_hex32
	call    print_crlf

    ; --- 呼び出し 3: ネストした呼び出し (print_dots が uart_putc を呼ぶ) ---
	mov     esi, msg4
	call    print_str
	mov     ecx, 5               ; 引数: ECX = 個数 (32-bit の LOOP は ECX を減らす)
	call    print_dots
	call    print_crlf

    ; --- 呼び出し 4: 計算して表示 (add_values) ---
	mov     eax, 42              ; 引数: EAX = 第 1 オペランド
	mov     ebx, 13              ; 引数: EBX = 第 2 オペランド
	call    add_values           ; 戻り値: EAX = EAX + EBX
	mov     esi, msg5
	call    print_str            ; print_str は汎用レジスタを保存する (EAX は無傷)
	call    print_hex32          ; EAX = 42 + 13 = 55 = 0x37 を出力
	call    print_crlf

	mov     esi, msg_done
	call    print_str

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt                ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
	push    edx
	push    eax
	mov     dx, 0x3FD            ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20             ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8            ; THR (送信保持レジスタ)
	pop     eax
	out     dx, al
	pop     edx
	ret

; add_values: EAX + EBX を EAX に返す
;   引数:   EAX, EBX
;   戻り値: EAX = EAX + EBX
add_values:
	add     eax, ebx
	ret

; print_dots: '.' を ECX 個出力 (ネストした呼び出し)
print_dots:
	mov     al, '.'
	call    uart_putc            ; ネストした呼び出し
	loop    print_dots           ; LOOP: ECX を減算し 0 でなければ分岐
	ret

; print_str: DS:ESI の NULL 終端文字列を出力
;   汎用レジスタを PUSH/POP で保存する (呼び出し側はレジスタ破壊を気にしない)
print_str:
	push    eax
	push    ebx
	push    ecx
	push    edx
	push    esi
	push    edi
	push    ebp
.loop:
	lodsb ; AL = [DS:ESI], ESI++ (DF = 0 なので正向き)
	or      al, al                ; NULL 終端?
	jz      .done
	call    uart_putc
    jmp .loop
.done:
	pop     ebp
	pop     edi
	pop     esi
	pop     edx
	pop     ecx
	pop     ebx
	pop     eax
	ret

; print_hex32: EAX を 8 桁の 16 進数字として出力 (EAX を保存)
print_hex32:
	push    eax
	push    ecx
	mov     ecx, 8               ; 出力するニブル数 = 8
.nibble:
	rol     eax, 4               ; 最上位ニブルを下位 4 ビットへ回転
	push    eax
	and     al, 0x0F
	call    print_nibble
	pop     eax
	dec     ecx
	jnz     .nibble
	pop     ecx
	pop     eax
	ret

; print_nibble: AL の下位 4 ビットを 1 桁の 16 進数字として出力
print_nibble:
	push    eax
	and     al, 0x0F
	add     al, '0'
	cmp     al, '9'
	jle     .out
	add     al, 7                 ; 'A'-'F' のため '9' との隙間 (7) を詰める
.out:
	call    uart_putc
	pop     eax
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
msg1     db "Hello from subroutine!", 0
msg2     db "Hex: 0x", 0
msg3     db "Hex: 0x", 0
msg4     db "Loading", 0
msg5     db "42+13=0x", 0
msg_done db 13, 10, "Subroutines done!", 0

scenario_halt equ _start.halt

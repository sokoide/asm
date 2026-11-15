; s03_stack.asm - Scenario 3: Stack Operations (32-bit 保護モード)
; ==============================================
; Learning objectives:
;   - PUSH / POP 命令 (32-bit: 1 回に 4 バイト)
;   - LIFO (Last In, First Out) の動作
;   - スタックポインタ ESP の自動調整 (PUSH で -4、POP で +4)
;   - レジスタの保存/復元パターン
;
; 本シナリオは boot.asm のスタブが SS = フラット、ESP = 0x90000 に
; 初期化済みのため、シナリオ側の SS/ESP 設定は不要。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- PUSH: ESP は 4 減り、値は [ESP] に格納される ---
    ; --- POP:  [ESP] から値をロードし、ESP は 4 増える ---

	mov     eax, 0x12345678
	push    eax                ; ESP: 0x90000 -> 0x8FFFC, [0x8FFFC] = 0x12345678
	mov     eax, 0x9ABCDEF0
	push    eax                ; ESP: 0x8FFFC -> 0x8FFF8, [0x8FFF8] = 0x9ABCDEF0

    ; --- ESP 表示: 2 回の PUSH で 8 減少している ---
	mov     esi, msg_esp1
	call    print_str
	mov     eax, esp
	call    print_hex32
	call    print_crlf

    ; --- POP は逆順 (LIFO: 最後に積んだものが最初に取り出される) ---
	pop     ebx                 ; EBX = 0x9ABCDEF0 (最後に push した値)
	pop     eax                 ; EAX = 0x12345678
	push    eax                ; あとで使うのでスタックへ退避

    ; 1 つ目の POP 結果を表示
	mov     esi, msg1
	call    print_str
	mov     eax, ebx            ; 0x9ABCDEF0
	call    print_hex32
	call    print_crlf

    ; 2 つ目の POP 結果を表示
	mov     esi, msg2
	call    print_str
	pop     eax                 ; 0x12345678 (退避した値を復元)
	call    print_hex32
	call    print_crlf

    ; --- ESP 表示: PUSH と POP が対になれば開始値 (0x90000) に戻る ---
	mov     esi, msg_esp2
	call    print_str
	mov     eax, esp
	call    print_hex32
	call    print_crlf

    ; --- 保存/復元パターン ---
	mov     eax, 42             ; EAX = 42
	push    eax                ; EAX をスタックに保存
	mov     eax, 99             ; EAX = 99 (壊す)
    ; ... 他の処理 ...
	pop     eax                 ; EAX = 42 に復元

	mov     edx, eax            ; 表示中の破壊に備えて退避
	mov     esi, msg3
	call    print_str
	mov     eax, edx            ; 42
	call    print_hex32
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
msg_esp1 db "ESP after 2 PUSH = 0x", 0
msg1     db "1st POP = 0x", 0
msg2     db "2nd POP = 0x", 0
msg_esp2 db "ESP back to start = 0x", 0
msg3     db "Saved/restored EAX = 0x", 0
msg_done db 13, 10, "Stack demo done!", 0

scenario_halt equ _start.halt

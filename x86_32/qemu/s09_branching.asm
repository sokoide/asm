; s09_branching.asm - Scenario 9: 条件分岐 (32-bit 保護モード)
; ======================================================
; Learning objectives:
;   - CMP: オペランドを変更せずにフラグを設定する (減算結果でフラグのみ更新)
;   - 条件分岐: JE/JNE (等しい), JL/JG (符号あり), JB/JA (符号なし)
;   - JL/JG は SF と OF で大小を判定 (符号ありの解釈)
;   - JB/JA は CF (桁借り) と CF+ZF で大小を判定 (符号なしの解釈)
;   - 同じビットパターンでも符号あり/符号なしで比較結果が変わる
;     (0xFFFFFFFF は符号付きでは -1、符号なしでは 4294967295)

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- テスト 1: JE / JNE (等しい / 等しくない) ---
	mov     esi, msg_eq
	call    print_str
	mov     eax, 42
	mov     ebx, 42
	cmp     eax, ebx            ; 注意: print_str 内の OR がフラグを壊すため
	je      .yes1               ;       CMP は分岐の直前に置く
	mov     esi, msg_no
	call    print_str
    jmp  .next1
.yes1:
	mov     esi, msg_yes
	call    print_str
.next1:

    ; --- テスト 2: JL (符号あり「より小さい」) ---
	mov     esi, msg_slt
	call    print_str
	mov     eax, -5             ; 符号ありの負数 (0xFFFFFFFB)
	mov     ebx, 10
	cmp     eax, ebx            ; -5 - 10 = 負 → JL 成立
	jl      .yes2
	mov     esi, msg_no
	call    print_str
    jmp  .next2
.yes2:
	mov     esi, msg_yes
	call    print_str
.next2:

    ; --- テスト 3: JG (符号あり「より大きい」) ---
	mov     esi, msg_sgt
	call    print_str
	mov     eax, 30
	mov     ebx, 10
	cmp     eax, ebx            ; 30 - 10 = 正 → JG 成立
	jg      .yes3
	mov     esi, msg_no
	call    print_str
    jmp  .next3
.yes3:
	mov     esi, msg_yes
	call    print_str
.next3:

    ; --- テスト 4: 符号あり JL vs 符号なし JA (同じ CMP、違う解釈) ---
    ; 0xFFFFFFFF は符号付きでは -1、符号なしでは 4294967295。
	mov     eax, 0xFFFFFFFF
	mov     ebx, 1
	mov     esi, msg_jl
	call    print_str
	cmp     eax, ebx            ; 符号あり解釈: -1 < 1 → JL 成立
	jl      .yes4
	mov     esi, msg_no
	call    print_str
    jmp  .next4
.yes4:
	mov     esi, msg_yes
	call    print_str
.next4:

	mov     eax, 0xFFFFFFFF     ; 同じ値を今度は符号なしで比較
	mov     ebx, 1
	mov     esi, msg_ja
	call    print_str
	cmp     eax, ebx            ; 符号なし解釈: 4294967295 > 1 → JA 成立
	ja      .yes5
	mov     esi, msg_no
	call    print_str
    jmp  .next5
.yes5:
	mov     esi, msg_yes
	call    print_str
.next5:

    ; --- テスト 5: if-else チェーン ---
	mov     esi, msg_ife
	call    print_str
	mov     eax, 50
	cmp     eax, 10
	jl      .small
	cmp     eax, 100
	jg      .big
	mov     esi, msg_mid
	call    print_str
    jmp  .done5
.small:
	mov     esi, msg_small
	call    print_str
    jmp  .done5
.big:
	mov     esi, msg_big
	call    print_str
.done5:

	mov     esi, msg_dn
	call    print_str

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
	push    edx
	push    eax
	mov     dx, 0x3FD           ; LSR (ラインステータスレジスタ)
.wait:
	in      al, dx
	test    al, 0x20            ; bit 5 = THRE (送信保持レジスタ空)
	jz      .wait
	mov     dx, 0x3F8           ; THR (送信保持レジスタ)
	pop     eax
	out     dx, al
	pop     edx
	ret

; print_str: DS:ESI の NULL 終端文字列を出力 (EAX/ESI は破壊する)
print_str:
	lodsb
	or      al, al
	jz      .ret
	call    uart_putc
    jmp print_str
.ret:
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
msg_eq:  db "42 == 42? ", 0
msg_slt: db "-5 < 10?  ", 0
msg_sgt: db "30 > 10?  ", 0
msg_jl:  db "-1 < 1?  (JL, signed)     ", 0
msg_ja:  db "0xFFFFFFFF > 1?  (JA, unsigned)  ", 0
msg_ife: db "50: ", 0
msg_small: db "small (<10)", 13, 10, 0
msg_mid:   db "mid (10..100)", 13, 10, 0
msg_big:   db "big (>100)", 13, 10, 0
msg_yes:   db "Yes!", 13, 10, 0
msg_no:    db "No!", 13, 10, 0
msg_dn:    db "Done!", 13, 10, 0

scenario_halt equ _start.halt

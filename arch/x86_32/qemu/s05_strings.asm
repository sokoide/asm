; s05_strings.asm - Scenario 5: 文字列操作 (32-bit 保護モード)
; =================================================
; Learning objectives:
;   - LODSB: [DS:ESI] から 1 バイト読み込み, ESI を進める
;   - STOSB: AL を [ES:EDI] へ書き込み, EDI を進める
;   - SCASB: AL と [ES:EDI] を比較し, EDI を進める
;   - REP/REPNE プレフィックス: ECX 回の繰り返し
;   - ディレクションフラグ: CLD (正向き) / STD (逆向き)
;   - 文字列長の測定, 文字列コピー
;
; 16-bit では SI/DI だった文字列命令の暗黙レジスタが, 32-bit では
; ESI/EDI になる。命令の動作自体は同じで, ポインタ幅が 32-bit に
; なっただけ。本シナリオは boot.asm のスタブが保護モード移行を終えた
; 後, 0x8000 から実行される。BIOS 割り込みは使用不可のため出力は
; UART を直接叩く。転送先バッファは .bss に置く (boot スタブが
; __bss_start..__bss_end をゼロ初期化済み)。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
	cld ; DF = 0: 文字列命令で ESI/EDI は +1 (正向き)

    ; --- Demo 1: REPNE SCASB で文字列長を測定 ---
    ; SCASB は AL と [ES:EDI] を比較して EDI を進める
    ; REPNE は「一致しない間」ECX > 0 で繰り返す
	mov     edi, greeting      ; EDI -> 探索対象文字列
	xor     al, al             ; AL = 0 (NULL 終端を探す)
	mov     ecx, 0xFFFFFFFF    ; 探索上限 (32-bit なので 4G バイトまで表現できる)
    repne scasb             ; [EDI] == 0 で停止 (EDI は NULL の次を指す)
    ; 停止までに NULL 分を含めて ECX が減っているので
    ; 長さ = 0xFFFFFFFF - ECX - 1
	mov     eax, 0xFFFFFFFF
	sub     eax, ecx
	dec     eax
	push    eax                ; 長さを退避

	mov     esi, msg_len
	call    print_str
	pop     eax
	add     al, '0'            ; ASCII 変換 (10 未満の前提)
	call    uart_putc
	call    print_crlf

    ; --- Demo 2: REP MOVSB で文字列コピー + STOSB で NULL 終端 ---
    ; MOVSB は [DS:ESI] から [ES:EDI] へ 1 バイト転送し, 両方を進める
	mov     esi, source        ; 転送元文字列
	mov     edi, dest          ; 転送先バッファ
	mov     ecx, 5             ; "World" の 5 バイト
    rep  movsb              ; [ES:EDI] <= [DS:ESI] を ECX バイト
	mov     al, 0
	stosb ; NULL 終端を書き込み ([ES:EDI] <= AL, EDI++)

	mov     esi, msg_copy
	call    print_str
	mov     esi, dest
	call    print_str
	call    print_crlf

    ; --- Demo 3: LODSB ベースの print_str で元の文字列を表示 ---
	mov     esi, msg_greet
	call    print_str
	mov     esi, greeting
	call    print_str
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

; print_str: ESI が指す NULL 終端文字列を表示 (LODSB が ESI を自動進行)
print_str:
	lodsb ; AL = [DS:ESI], ESI++
	or      al, al             ; NULL 終端?
	jz      .ret
	call    uart_putc
    jmp  print_str
.ret:
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
greeting  db "Hello", 0        ; 5 文字
source    db "World", 0        ; 5 文字
msg_len   db "Length of 'Hello': ", 0
msg_copy  db "Copied: ", 0
msg_greet db "Original: ", 0
msg_done  db 13, 10, "String ops done!", 0

section .bss
dest      resb 6               ; 転送先バッファ (boot スタブがゼロに初期化済み)

scenario_halt equ _start.halt

; s12_minishell.asm - Scenario 12: Interactive Mini Shell (32-bit 保護モード)
; =======================================================
; Learning objectives:
;   - これまでの概念 (UART 入出力、文字列比較、分岐) の統合
;   - 行入力 (エコー + バックスペース処理)
;   - 文字列比較によるコマンドディスパッチ
;   - READ-EVAL-PRINT ループ (REPL) の構築
;
; 本シナリオは boot.asm のスタブが保護モード移行を終えた後、
; 0x8000 から実行される。IDT 未構築のため割り込みは使えず、
; UART のポーリングで入力を待つ。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; バナーとヘルプを表示
	mov     esi, msg_banner
	call    print_str
	mov     esi, msg_h1
	call    print_str
	mov     esi, msg_h2
	call    print_str
	mov     esi, msg_h3
	call    print_str

    ; メインループ: プロンプト表示 → 1 行読み込み → コマンド判定
.main:
	mov     esi, msg_prompt
	call    print_str
	call    read_line
	call    print_crlf

    ; 入力と "hello" を比較
	mov     esi, input
	mov     edi, cmd_hello
	call    strcmp
	je      .hello

    ; 入力と "help" を比較
	mov     esi, input
	mov     edi, cmd_help
	call    strcmp
	je      .help

    ; 入力と "quit" を比較
	mov     esi, input
	mov     edi, cmd_quit
	call    strcmp
	je      .quit

    ; 空行? (先頭が NULL なら何もせずループへ)
	mov     al, [input]
	or      al, al
	jz      .main

    ; 不明なコマンド
	mov     esi, msg_unk
	call    print_str
    jmp  .main

.hello:
	mov     esi, msg_hi
	call    print_str
    jmp  .main

.help:
	mov     esi, msg_h1
	call    print_str
	mov     esi, msg_h2
	call    print_str
	mov     esi, msg_h3
	call    print_str
    jmp  .main

.quit:
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

; read_line: Enter まで 1 行読み込み、NULL 終端で input バッファへ格納
;   - 表示可能文字 (>= 0x20) は格納してエコー
;   - Backspace (0x08) は末尾 1 文字を削除 ("BS space BS" を出力)
;   - CR/LF で確定。バッファ上限は INPUT_MAX 文字 (超過分は無視)
read_line:
	push    eax
	push    ebx
	push    ecx
	push    edx
	push    esi
	push    edi
	push    ebp
	mov     edi, input
.rl_loop:
	call    uart_getc
    ; Enter (CR または LF) で確定
	cmp     al, 13
	je      .rl_enter
	cmp     al, 10
	je      .rl_enter
    ; Backspace (0x08)
	cmp     al, 8
	je      .rl_bs
    ; 表示可能文字のみ格納 (0x20 以上)
	cmp     al, 0x20
	jb      .rl_loop
    ; バッファ上限チェック
	push    eax
	mov     eax, edi
	sub     eax, input
	cmp     eax, INPUT_MAX
	pop     eax
	jge     .rl_loop
    ; 格納してエコー
	mov     [edi], al
	inc     edi
	call    uart_putc
    jmp  .rl_loop
.rl_bs:
    ; バッファが空なら無視
	mov     eax, edi
	sub     eax, input
	or      eax, eax
	jz      .rl_loop
	dec     edi
    ; "BS space BS" を出力して画面上の 1 文字を消す
	push    eax
	mov     al, 8
	call    uart_putc
	mov     al, ' '
	call    uart_putc
	mov     al, 8
	call    uart_putc
	pop     eax
    jmp  .rl_loop
.rl_enter:
	mov     byte [edi], 0         ; NULL 終端
	pop     ebp
	pop     edi
	pop     esi
	pop     edx
	pop     ecx
	pop     ebx
	pop     eax
	ret

; strcmp: ESI と EDI が指す文字列を比較。一致したら ZF=1 で戻る
strcmp:
	push    eax
	push    ebx
	push    ecx
	push    edx
	push    esi
	push    edi
	push    ebp
.sc_loop:
	mov     al, [esi]
	mov     bl, [edi]
	cmp     al, bl
	jne     .sc_done
	or      al, al                ; 両方 NULL に達したら一致
	jz      .sc_done
	inc     esi
	inc     edi
    jmp  .sc_loop
.sc_done:
	cmp     al, bl                ; 最後の比較結果で ZF を設定
	pop     ebp
	pop     edi
	pop     esi
	pop     edx
	pop     ecx
	pop     ebx
	pop     eax
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
msg_banner db "80386 MiniShell", 13, 10, 0
msg_prompt db "> ", 0
msg_hi     db "Hello, 80386!", 13, 10, 0
msg_h1     db "Commands: hello, help, quit", 13, 10, 0
msg_h2     db "  hello - Say hello", 13, 10, 0
msg_h3     db "  quit  - Exit", 13, 10, 0
msg_bye    db "Bye!", 13, 10, 0
msg_unk    db "Unknown command", 13, 10, 0
cmd_hello  db "hello", 0
cmd_help   db "help", 0
cmd_quit   db "quit", 0

; ---- BSS (boot スタブが __bss_start..__bss_end をゼロ初期化) ----
section .bss
INPUT_MAX equ 30              ; 行の最大文字数
input     resb 32             ; 行入力バッファ (30 文字 + NULL + 予備)

scenario_halt equ _start.halt

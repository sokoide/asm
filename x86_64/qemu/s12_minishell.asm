; s12_minishell.asm - Scenario 12: Interactive Mini Shell (64-bit ロングモード)
; =======================================================
; Learning objectives:
;   - これまでの概念 (UART 入出力、文字列比較、分岐) の統合
;   - 行入力 (エコー + バックスペース処理)
;   - 文字列比較によるコマンドディスパッチ
;   - READ-EVAL-PRINT ループ (REPL) の構築
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。IDT 未構築のため割り込みは使えず、
; UART のポーリングで入力を待つ。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; バナーとヘルプを表示
    lea  rsi, [rel msg_banner] ; RSI = 文字列へのポインタ (RIP 相対)
    call print_str
    lea  rsi, [rel msg_h1]
    call print_str
    lea  rsi, [rel msg_h2]
    call print_str
    lea  rsi, [rel msg_h3]
    call print_str

    ; メインループ: プロンプト表示 → 1 行読み込み → コマンド判定
.main:
    lea  rsi, [rel msg_prompt]
    call print_str
    call read_line
    call print_crlf

    ; 入力と "hello" を比較
    lea  rsi, [rel input]
    lea  rdi, [rel cmd_hello]
    call strcmp
    je   .hello

    ; 入力と "help" を比較
    lea  rsi, [rel input]
    lea  rdi, [rel cmd_help]
    call strcmp
    je   .help

    ; 入力と "quit" を比較
    lea  rsi, [rel input]
    lea  rdi, [rel cmd_quit]
    call strcmp
    je   .quit

    ; 空行? (先頭が NULL なら何もせずループへ)
    mov  al, [rel input]
    or   al, al
    jz   .main

    ; 不明なコマンド
    lea  rsi, [rel msg_unk]
    call print_str
    jmp  .main

.hello:
    lea  rsi, [rel msg_hi]
    call print_str
    jmp  .main

.help:
    lea  rsi, [rel msg_h1]
    call print_str
    lea  rsi, [rel msg_h2]
    call print_str
    lea  rsi, [rel msg_h3]
    call print_str
    jmp  .main

.quit:
    lea  rsi, [rel msg_bye]
    call print_str

.halt:
    cli                        ; 割り込み禁止
    hlt                        ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push rdx
    push rax
    mov  dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8             ; THR (送信保持レジスタ)
    pop  rax
    out  dx, al
    pop  rdx
    ret

; uart_getc: COM1 から 1 文字を受信して AL に返す
uart_getc:
    push rdx
    mov  dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x01              ; bit 0 = DR (受信データあり)
    jz   .wait
    mov  dx, 0x3F8             ; RBR (受信バッファレジスタ)
    in   al, dx
    pop  rdx
    ret

; read_line: Enter まで 1 行読み込み、NULL 終端で input バッファへ格納
;   - 表示可能文字 (>= 0x20) は格納してエコー
;   - Backspace (0x08) は末尾 1 文字を削除 ("BS space BS" を出力)
;   - CR/LF で確定。バッファ上限は INPUT_MAX 文字 (超過分は無視)
read_line:
    push rax
    push rdi
    lea  rdi, [rel input]      ; RDI = 格納位置 (バッファ先頭)
.rl_loop:
    call uart_getc
    ; Enter (CR または LF) で確定
    cmp  al, 13
    je   .rl_enter
    cmp  al, 10
    je   .rl_enter
    ; Backspace (0x08)
    cmp  al, 8
    je   .rl_bs
    ; 表示可能文字のみ格納 (0x20 以上)
    cmp  al, 0x20
    jb   .rl_loop
    ; バッファ上限チェック
    push rax
    mov  rax, rdi
    sub  rax, input            ; input 先頭からのオフセット (カーネルは 0x8000 固定配置)
    cmp  rax, INPUT_MAX
    pop  rax
    jge  .rl_loop
    ; 格納してエコー
    mov  [rdi], al
    inc  rdi
    call uart_putc
    jmp  .rl_loop
.rl_bs:
    ; バッファが空なら無視 (入力長 = rdi - input の RIP 相対計算)
    lea  rdx, [rel input]
    mov  rax, rdi
    sub  rax, rdx
    or   rax, rax
    jz   .rl_loop
    dec  rdi
    ; "BS space BS" を出力して画面上の 1 文字を消す
    push rax
    mov  al, 8
    call uart_putc
    mov  al, ' '
    call uart_putc
    mov  al, 8
    call uart_putc
    pop  rax
    jmp  .rl_loop
.rl_enter:
    mov  byte [rdi], 0         ; NULL 終端
    pop  rdi
    pop  rax
    ret

; strcmp: RSI と RDI が指す文字列を比較。一致したら ZF=1 で戻る
strcmp:
    push rax
    push rbx
    push rsi
    push rdi
.sc_loop:
    mov  al, [rsi]
    mov  bl, [rdi]
    cmp  al, bl
    jne  .sc_done
    or   al, al                ; 両方 NULL に達したら一致
    jz   .sc_done
    inc  rsi
    inc  rdi
    jmp  .sc_loop
.sc_done:
    cmp  al, bl                ; 最後の比較結果で ZF を設定
    pop  rdi
    pop  rsi
    pop  rbx
    pop  rax
    ret

; print_str: RSI が指す NULL 終端文字列を出力 (RSI を進める)
print_str:
    lodsb
    or   al, al
    jz   .ret
    call uart_putc
    jmp  print_str
.ret:
    ret

; print_crlf: CR + LF を出力
print_crlf:
    push rax
    mov  al, 13
    call uart_putc
    mov  al, 10
    call uart_putc
    pop  rax
    ret

; ---- データ ----
section .rodata
msg_banner db "x86_64 MiniShell", 13, 10, 0
msg_prompt db "> ", 0
msg_hi     db "Hello, x86_64!", 13, 10, 0
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

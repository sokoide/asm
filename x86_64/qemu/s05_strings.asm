; s05_strings.asm - Scenario 5: 文字列操作 (64-bit ロングモード)
; =================================================
; Learning objectives:
;   - LODSB: [RSI] から 1 バイト読み込み, RSI を進める
;   - STOSB: AL を [RDI] へ書き込み, RDI を進める
;   - SCASB: AL と [RDI] を比較し, RDI を進める
;   - REP/REPNE プレフィックス: RCX 回の繰り返し
;   - ディレクションフラグ: CLD (正向き) / STD (逆向き)
;   - 文字列長の測定, 文字列コピー
;
; 16/32-bit では SI/DI (ESI/EDI) だった文字列命令の暗黙レジスタが,
; 64-bit では RSI/RDI になる。命令の動作自体は同じで, ポインタ幅が
; 64-bit になっただけ。繰り返しカウンタも ECX から RCX に変わるため,
; REPNE SCASB の探索上限にアドレス空間全体 (RCX = -1 =
; 0xFFFFFFFFFFFFFFFF) を指定できるのが 64-bit ならではの学習ポイント。
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後, 0x8000
; から実行される。IDT 未構築のため BIOS 割り込みは使用不可なので,
; 出力は UART を直接叩く。転送先バッファは .bss に置く (boot スタブが
; __bss_start..__bss_end をゼロ初期化済み)。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    cld                     ; DF = 0: 文字列命令で RSI/RDI は +1 (正向き)

    ; --- Demo 1: REPNE SCASB で文字列長を測定 ---
    ; SCASB は AL と [RDI] を比較して RDI を進める
    ; REPNE は「一致しない間」RCX > 0 で繰り返す
    lea  rdi, [rel greeting] ; RDI -> 探索対象文字列 (RIP 相対)
    xor  al, al             ; AL = 0 (NULL 終端を探す)
    mov  rcx, -1            ; 探索上限 (64-bit ではアドレス空間全体を指定できる)
    repne scasb             ; [RDI] == 0 で停止 (RDI は NULL の次を指す)
    ; 停止までに NULL 分を含めて RCX が減っているので
    ; 長さ = (-1) - RCX - 1
    mov  rax, -1
    sub  rax, rcx
    dec  rax
    push rax                ; 長さを退避

    lea  rsi, [rel msg_len]
    call print_str
    pop  rax
    add  al, '0'            ; ASCII 変換 (10 未満の前提)
    call uart_putc
    call print_crlf

    ; --- Demo 2: REP MOVSB で文字列コピー + STOSB で NULL 終端 ---
    ; MOVSB は [RSI] から [RDI] へ 1 バイト転送し, 両方を進める
    lea  rsi, [rel source]  ; 転送元文字列
    lea  rdi, [rel dest]    ; 転送先バッファ
    mov  ecx, 5             ; "World" の 5 バイト (RCX の下位 32 ビットで十分)
    rep  movsb              ; [RDI] <= [RSI] を RCX バイト
    mov  al, 0
    stosb                   ; NULL 終端を書き込み ([RDI] <= AL, RDI++)

    lea  rsi, [rel msg_copy]
    call print_str
    lea  rsi, [rel dest]
    call print_str
    call print_crlf

    ; --- Demo 3: LODSB ベースの print_str で元の文字列を表示 ---
    lea  rsi, [rel msg_greet]
    call print_str
    lea  rsi, [rel greeting]
    call print_str
    call print_crlf

    lea  rsi, [rel msg_done]
    call print_str

.halt:
    cli                     ; 割り込み禁止
    hlt                     ; CPU 停止
    jmp  .halt              ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push rdx
    push rax
    mov  dx, 0x3FD          ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20           ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8          ; THR (送信保持レジスタ)
    pop  rax
    out  dx, al
    pop  rdx
    ret

; print_str: RSI が指す NULL 終端文字列を表示 (LODSB が RSI を自動進行)
print_str:
    push rcx                ; 呼び出し規約: 入口は RSP % 16 = 8 のため 1 push して
                            ; CALL 直前の RSP を 16 の倍数に揃える (S07 参照)
.loop:
    lodsb                   ; AL = [RSI], RSI++ (DF = 0 なので正向き)
    or   al, al             ; NULL 終端?
    jz   .ret
    call uart_putc
    jmp .loop
.ret:
    pop rcx
    ret

; print_crlf: CR (0x0D) + LF (0x0A) を出力
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
greeting  db "Hello", 0        ; 5 文字
source    db "World", 0        ; 5 文字
msg_len   db "Length of 'Hello': ", 0
msg_copy  db "Copied: ", 0
msg_greet db "Original: ", 0
msg_done  db 13, 10, "String ops done!", 0

section .bss
dest      resb 6               ; 転送先バッファ (boot スタブがゼロに初期化済み)

scenario_halt equ _start.halt

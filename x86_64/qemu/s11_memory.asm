; s11_memory.asm - Scenario 11: メモリとブロック操作 (64-bit ロングモード)
; ==========================================================
; Learning objectives:
;   - REP STOSB: メモリブロックを 1 バイトで埋める
;   - REP MOVSB: メモリブロックのコピー
;   - アドレッシング: [即値], [レジスタ], [ベース + インデックス * スケール]
;   - スケール 8 による qword 配列アクセス (64-bit の学習ポイント)
;   - qword 読み込みは MOVZX 不要 (レジスタ幅 = 転送幅ならそのまま)
;   - バッファ操作の基本パターン
;
; 32-bit 版との違いはアドレス計算が 64-bit レジスタで行われる点と,
; スケール 8 で qword (8 バイト) 配列を 1 命令でアクセスできる点。
; [RBX + RSI * 8] は table[i] のアドレス計算 (base + i * 8) を
; ハードウェアが 1 命令で実行する。バイト読み込み時は MOVZX が
; 必要なまま (上位ビットのゼロ埋めは転送幅 < レジスタ幅のときだけ
; 必要)。ワーキングバッファは .bss に置く (boot スタブが
; __bss_start..__bss_end をゼロ初期化する)。スタック (RSP = 0x90000)
; とは離れた配置になる。本シナリオも boot.asm のスタブの後 0x8000
; から実行され, 出力は UART を直接叩く。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    cld                     ; DF = 0: 文字列操作は正向き (RSI/RDI を +1)

    ; --- Demo 1: REP STOSB でブロックフィル ---
    ; 'display' バッファを '.' 20 個で埋める
    mov  al, '.'            ; 埋めるバイト
    mov  ecx, 20            ; バイト数
    lea  rdi, [rel display] ; 転送先
    rep  stosb              ; [RDI] <= AL を RCX 回書き込み
    mov  byte [rdi], 0      ; NULL 終端 (RDI は最終書き込み位置の次を指す)

    lea  rsi, [rel msg1]
    call print_str
    lea  rsi, [rel display]
    call print_str
    call print_crlf

    ; --- Demo 2: REP MOVSB でブロックコピー ---
    ; "Hello" を display バッファへコピー
    mov  ecx, 5             ; 5 バイト
    lea  rsi, [rel src_hello] ; 転送元 (NULL 終端なし)
    lea  rdi, [rel display] ; 転送先
    rep  movsb              ; [RDI] <= [RSI] を RCX バイト
    mov  byte [rel display+5], 0 ; NULL 終端

    lea  rsi, [rel msg2]
    call print_str
    lea  rsi, [rel display]
    call print_str
    call print_crlf

    ; --- Demo 3: [ベース + 即値オフセット] による直接書き込み ---
    ; コピー内容を個別バイトの書き込みで置き換える
    mov  byte [rel display+0], 'W'
    mov  byte [rel display+1], 'O'
    mov  byte [rel display+2], 'R'
    mov  byte [rel display+3], 'L'
    mov  byte [rel display+4], 'D'
    mov  byte [rel display+5], 0

    lea  rsi, [rel msg3]
    call print_str
    lea  rsi, [rel display]
    call print_str
    call print_crlf

    ; --- Demo 4: ベース + インデックス * スケール (スケール 1) ---
    ; display[3] を [RBX + RSI * 1] で読む (ベースもインデックスも 64-bit)
    lea  rbx, [rel display] ; RBX = ベースアドレス
    mov  rsi, 3             ; RSI = インデックス
    movzx eax, byte [rbx+rsi*1]  ; EAX = display[3] = 'L' = 0x4C
                                 ; MOVZX: バイト読み込み後に上位ビットを 0 埋め
                                 ; (転送幅 < レジスタ幅のときは必要なまま)
    push rax                ; 値を退避

    lea  rsi, [rel msg4]
    call print_str
    pop  rax
    call print_hex32
    call print_crlf

    ; --- Demo 5: ベース + インデックス * スケール (スケール 8 = qword 配列) ---
    ; table[i] のアドレスは table + i*8。[RBX + RSI * 8] で 1 命令で表現する
    lea  rdi, [rel table]   ; RDI = 配列のベース
    xor  esi, esi           ; ESI = 要素インデックス (0 から)
    mov  rax, 0x1111111111111111 ; table[0] に書く値
    mov  rdx, 0x1111111111111111 ; 増分 (ADD の即値は imm32 までなので
                                 ; 64 ビット定数はレジスタに置く)
.fill_loop:
    mov  [rdi+rsi*8], rax   ; table[i] = RAX (qword 転送)
    add  rax, rdx           ; 値を 0x1111111111111111 ずつ増やす
    inc  rsi
    cmp  esi, 4
    jl   .fill_loop         ; 4 要素分書いたら抜ける

    lea  rbx, [rel table]   ; RBX = ベース
    mov  rsi, 2             ; RSI = インデックス
    mov  rax, [rbx+rsi*8]   ; RAX = table[2] = 0x3333333333333333
                            ; qword 読み込みは MOVZX 不要 (転送幅 = レジスタ幅)
    push rax                ; print_str は LODSB で AL を壊すので退避

    lea  rsi, [rel msg5]
    call print_str
    pop  rax
    call print_hex64
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
    lodsb                   ; AL = [RSI], RSI++
    or   al, al             ; NULL 終端?
    jz   .ret
    call uart_putc
    jmp  print_str
.ret:
    ret

; print_hex32: EAX を 8 桁の 16 進数で表示 (上位ニブルから, EAX/ECX 破壊)
;   ROL 4 を 8 回行うと元に戻る性質を利用してニブルを取り出す
;   バイト値などの部分レジスタの表示に使う (64-bit 版でも有効)
print_hex32:
    mov  ecx, 8             ; ニブル数
.next:
    rol  eax, 4             ; 上位ニブルを下位 4 ビットへ回転
    push rax
    call print_nibble       ; AL の下位ニブルを表示 (print_nibble 内でマスク)
    pop  rax
    loop .next
    ret

; print_hex64: RAX を 16 桁の 16 進数で表示 (上位ニブルから, RAX/RCX 破壊)
;   ROL 4 を 16 回行うと元に戻る性質を利用してニブルを取り出す
print_hex64:
    mov  ecx, 16            ; ニブル数
.next:
    rol  rax, 4             ; 上位ニブルを下位 4 ビットへ回転
    push rax
    call print_nibble       ; AL の下位ニブルを表示 (print_nibble 内でマスク)
    pop  rax
    loop .next
    ret

; print_nibble: AL の下位 4 ビットを 1 桁の 16 進文字で表示 (AL 破壊)
print_nibble:
    and  al, 0x0F
    add  al, '0'
    cmp  al, '9'
    jle  .out
    add  al, 7
.out:
    call uart_putc
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
src_hello db "Hello"          ; NULL 終端なし (5 バイトだけ MOVSB する)
msg1     db "Fill:  ", 0
msg2     db "Copy:  ", 0
msg3     db "Index: ", 0
msg4     db "[RBX+RSI*1] display[3]=0x", 0
msg5     db "[RBX+RSI*8] table[2]=0x", 0
msg_done db 13, 10, "Memory ops done!", 0

section .bss
display  resb 24              ; 作業バッファ 24 バイト (boot スタブがゼロ化済み)
table    resq 4               ; qword 配列 4 要素 (32-bit 版は resd 4)

scenario_halt equ _start.halt

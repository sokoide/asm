; s11_memory.asm - Scenario 11: メモリとブロック操作 (32-bit 保護モード)
; ==========================================================
; Learning objectives:
;   - REP STOSB: メモリブロックを 1 バイトで埋める
;   - REP MOVSB: メモリブロックのコピー
;   - アドレッシング: [即値], [レジスタ], [ベース + インデックス * スケール]
;   - スケール 4 による dword 配列アクセス (386 以降の機能)
;   - バッファ操作の基本パターン
;
; 16-bit にはない「ベース + インデックス * スケール」アドレッシングが
; 32-bit の学習ポイント。スケールは 1/2/4/8 が使え, dword 配列なら
; スケール 4 で table[i] のアドレス計算が 1 命令で済む。
; ワーキングバッファは .bss に置く (boot スタブが __bss_start..__bss_end
; をゼロ初期化する)。スタック (ESP = 0x90000) とは離れた配置になる。
; 本シナリオも boot.asm のスタブの後 0x8000 から実行され, 出力は
; UART を直接叩く。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    cld                     ; DF = 0: 文字列操作は正向き (ESI/EDI を +1)

    ; --- Demo 1: REP STOSB でブロックフィル ---
    ; 'display' バッファを '.' 20 個で埋める
    mov  al, '.'            ; 埋めるバイト
    mov  ecx, 20            ; バイト数
    mov  edi, display       ; 転送先
    rep  stosb              ; [ES:EDI] <= AL を ECX 回書き込み
    mov  byte [edi], 0      ; NULL 終端 (EDI は最終書き込み位置の次を指す)

    mov  esi, msg1
    call print_str
    mov  esi, display
    call print_str
    call print_crlf

    ; --- Demo 2: REP MOVSB でブロックコピー ---
    ; "Hello" を display バッファへコピー
    mov  ecx, 5             ; 5 バイト
    mov  esi, src_hello     ; 転送元 (NULL 終端なし)
    mov  edi, display       ; 転送先
    rep  movsb              ; [ES:EDI] <= [DS:ESI] を ECX バイト
    mov  byte [display+5], 0 ; NULL 終端

    mov  esi, msg2
    call print_str
    mov  esi, display
    call print_str
    call print_crlf

    ; --- Demo 3: [ベース + 即値オフセット] による直接書き込み ---
    ; コピー内容を個別バイトの書き込みで置き換える
    mov  byte [display+0], 'W'
    mov  byte [display+1], 'O'
    mov  byte [display+2], 'R'
    mov  byte [display+3], 'L'
    mov  byte [display+4], 'D'
    mov  byte [display+5], 0

    mov  esi, msg3
    call print_str
    mov  esi, display
    call print_str
    call print_crlf

    ; --- Demo 4: ベース + インデックス * スケール (スケール 1) ---
    ; display[3] を [EBX + ESI * 1] で読む
    mov  ebx, display       ; EBX = ベースアドレス
    mov  esi, 3             ; ESI = インデックス
    movzx eax, byte [ebx+esi*1]  ; EAX = display[3] = 'L' = 0x4C
                                 ; MOVZX: バイト読み込み後に上位ビットを 0 埋め
    push eax                ; 値を退避

    mov  esi, msg4
    call print_str
    pop  eax
    call print_hex32
    call print_crlf

    ; --- Demo 5: ベース + インデックス * スケール (スケール 4 = dword 配列) ---
    ; table[i] のアドレスは table + i*4。[EBX + ESI * 4] で 1 命令で表現する
    mov  edi, table         ; EDI = 配列のベース
    xor  esi, esi           ; ESI = 要素インデックス (0 から)
    mov  eax, 0x11111111    ; table[0] に書く値
.fill_loop:
    mov  [edi+esi*4], eax   ; table[i] = EAX
    add  eax, 0x11111111    ; 値を 0x11111111 ずつ増やす
    inc  esi
    cmp  esi, 4
    jl   .fill_loop         ; 4 要素分書いたら抜ける

    mov  ebx, table         ; EBX = ベース
    mov  esi, 2             ; ESI = インデックス
    mov  eax, [ebx+esi*4]   ; EAX = table[2] = 0x33333333
    push eax                ; print_str は LODSB で AL を壊すので退避

    mov  esi, msg5
    call print_str
    pop  eax
    call print_hex32
    call print_crlf

    mov  esi, msg_done
    call print_str

.halt:
    cli                     ; 割り込み禁止
    hlt                     ; CPU 停止
    jmp  .halt              ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
    push edx
    push eax
    mov  dx, 0x3FD          ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20           ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8          ; THR (送信保持レジスタ)
    pop  eax
    out  dx, al
    pop  edx
    ret

; print_str: ESI が指す NULL 終端文字列を表示 (LODSB が ESI を自動進行)
print_str:
    lodsb                   ; AL = [DS:ESI], ESI++
    or   al, al             ; NULL 終端?
    jz   .ret
    call uart_putc
    jmp  print_str
.ret:
    ret

; print_hex32: EAX を 8 桁の 16 進数で表示 (上位ニブルから, EAX/ECX 破壊)
;   ROL 4 を 8 回行うと元に戻る性質を利用してニブルを取り出す
print_hex32:
    mov  ecx, 8             ; ニブル数
.next:
    rol  eax, 4             ; 上位ニブルを下位 4 ビットへ回転
    push eax
    call print_nibble       ; AL の下位ニブルを表示 (print_nibble 内でマスク)
    pop  eax
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
    push eax
    mov  al, 13
    call uart_putc
    mov  al, 10
    call uart_putc
    pop  eax
    ret

; ---- データ ----
section .rodata
src_hello db "Hello"          ; NULL 終端なし (5 バイトだけ MOVSB する)
msg1     db "Fill:  ", 0
msg2     db "Copy:  ", 0
msg3     db "Index: ", 0
msg4     db "[EBX+ESI*1] display[3]=0x", 0
msg5     db "[EBX+ESI*4] table[2]=0x", 0
msg_done db 13, 10, "Memory ops done!", 0

section .bss
display  resb 24              ; 作業バッファ 24 バイト (boot スタブがゼロ化済み)
table    resd 4               ; dword 配列 4 要素

scenario_halt equ _start.halt

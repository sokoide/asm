; s10_bitwise.asm - Scenario 10: ビット演算 (64-bit ロングモード)
; ====================================================
; Learning objectives:
;   - AND: マスクで特定ビットの抽出
;   - OR: ビットのセット / 合成
;   - XOR: ビットのトグル, レジスタのゼロ化 (XOR reg, reg)
;   - SHL / SHR: 64 ビットの左 / 右シフト (bit 63 の扱い)
;   - ROR: 64 ビットの回転 (はみ出したビットは反対側へ戻る)
;   - 64 桁の 2 進表示, 16 桁の 16 進表示ルーチン
;
; 16/32-bit 版との違いはシフト / マスク / 回転の対象が 64 ビット幅に
; なった点。bit 63 (最上位ビット) が実際に使われる値での SHL/SHR は
; 64-bit ならではの学習ポイント。ニブルマスクも 8 バイト分に拡張し
; (0x0F0F0F0F0F0F0F0F), 回転 ROR 8 では 64 ビット全体を一周させる。
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後, 0x8000
; から実行され, 出力は UART を直接叩く。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- AND: マスクで各バイトの下位ニブルを抽出 ---
    ; 注意: AND/OR/XOR の即値は imm32 (符号拡張) まで。64 ビットの
    ; 定数は mov r64, imm64 でレジスタに置いてから使う
    lea  rsi, [rel msg_and]
    call print_str
    mov  rax, 0x5A5A5A5A5A5A5A5A   ; 0101 1010 x 8
    mov  rcx, 0x0F0F0F0F0F0F0F0F   ; 下位ニブルマスク (imm64 は MOV だけ)
    and  rax, rcx                  ; 下位ニブルだけ残す = 0x0A0A0A0A0A0A0A0A
    call print_bin64
    mov  al, ' '
    call uart_putc
    mov  al, '='
    call uart_putc
    mov  al, ' '
    call uart_putc
    mov  rax, 0x5A5A5A5A5A5A5A5A   ; print_bin64 は RAX を壊すので再度計算
    mov  rcx, 0x0F0F0F0F0F0F0F0F   ; print_bin64 の loop で RCX = 0 になるため再ロード
    and  rax, rcx
    call print_hex64
    call print_crlf

    ; --- OR: ビットの合成 ---
    lea  rsi, [rel msg_or]
    call print_str
    mov  rax, 0x5050505050505050   ; 0101 0000 x 8
    mov  rcx, 0x0A0A0A0A0A0A0A0A   ; 0000 1010 x 8
    or   rax, rcx                  ; 上位ニブル + 下位ニブル = 0x5A5A5A5A5A5A5A5A
    call print_hex64
    call print_crlf

    ; --- XOR: ビットのトグル ---
    lea  rsi, [rel msg_xor]
    call print_str
    mov  rax, -1                   ; 1111 1111 x 8 (= 0xFFFFFFFFFFFFFFFF)
    mov  rcx, 0x0F0F0F0F0F0F0F0F   ; 0000 1111 x 8
    xor  rax, rcx                  ; 下位ニブルを反転 = 0xF0F0F0F0F0F0F0F0
    call print_hex64
    call print_crlf

    ; --- XOR reg, reg: ゼロ化の定石 ---
    ; xor eax, eax は mov eax, 0 より短く, フラグもクリアする

    ; --- SHL: 64 ビットを 1 ビット左シフト (bit 62 -> bit 63) ---
    lea  rsi, [rel msg_shl]
    call print_str
    mov  rax, 0x4000000000000000
    shl  rax, 1                    ; 最上位ビットに立つ = 0x8000000000000000
    call print_hex64
    call print_crlf

    ; --- SHR: 64 ビットを 1 ビット右シフト (bit 63 -> bit 62, 0 埋め) ---
    lea  rsi, [rel msg_shr]
    call print_str
    mov  rax, 0x8000000000000000
    shr  rax, 1                    ; bit 63 が落ちる = 0x4000000000000000
    call print_hex64
    call print_crlf

    ; --- ROR: 回転シフト (落ちたビットは最上位へ戻る) ---
    ; 32-bit 版では下位 8 ビットが bit 31 へ戻ったが, 64-bit では
    ; RAX 全体を一周するので下位 8 ビットは bit 63..56 へ移動する
    lea  rsi, [rel msg_ror]
    call print_str
    mov  rax, 0x123456789ABCDEF0
    ror  rax, 8                    ; 下位 8 ビットが最上位へ = 0xF0123456789ABCDE
    call print_hex64
    call print_crlf

    ; --- 視覚確認: 0xA5A5A5A5A5A5A5A5 を 64 桁の 2 進数で表示 ---
    lea  rsi, [rel msg_vis]
    call print_str
    mov  rax, 0xA5A5A5A5A5A5A5A5
    call print_bin64
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

; print_bin64: RAX を 64 桁の 2 進数で表示 (MSB 先頭, RAX/RCX 破壊)
print_bin64:
    mov  rcx, 64            ; ビット数
.bit_loop:
    shl  rax, 1             ; 最上位ビットを CF へ押し出す (64-bit シフト)
    push rax                ; シフト後の値を退避
    mov  al, '0'
    jnc  .zero
    mov  al, '1'
.zero:
    call uart_putc
    pop  rax
    loop .bit_loop
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
msg_and  db "AND 0x5A5A5A5A5A5A5A5A, 0x0F0F0F0F0F0F0F0F: ", 0
msg_or   db "OR  0x5050505050505050, 0x0A0A0A0A0A0A0A0A: 0x", 0
msg_xor  db "XOR 0xFFFFFFFFFFFFFFFF, 0x0F0F0F0F0F0F0F0F: 0x", 0
msg_shl  db "SHL 0x4000000000000000, 1: 0x", 0
msg_shr  db "SHR 0x8000000000000000, 1: 0x", 0
msg_ror  db "ROR 0x123456789ABCDEF0, 8: 0x", 0
msg_vis  db "0xA5A5A5A5A5A5A5A5 binary: ", 0
msg_done db 13, 10, "Bitwise done!", 0

scenario_halt equ _start.halt

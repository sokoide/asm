; s09_branching.asm - Scenario 9: 条件分岐 (64-bit ロングモード)
; ======================================================
; Learning objectives:
;   - CMP: オペランドを変更せずにフラグを設定する (減算結果でフラグのみ更新)
;   - 条件分岐: JE/JNE (等しい), JL/JG (符号あり), JB/JA (符号なし)
;   - JL/JG は SF と OF で大小を判定 (符号ありの解釈)
;   - JB/JA は CF (桁借り) と CF+ZF で大小を判定 (符号なしの解釈)
;   - 同じビットパターンでも符号あり/符号なしで比較結果が変わる
;     (0xFFFFFFFFFFFFFFFF は符号付きでは -1、符号なしでは 2^64-1 =
;      18446744073709551615。64-bit 幅ではビット 63 が符号ビット)
;
; スタックアラインメント (呼び出し規約の詳細は s07 参照):
;   関数入口は RSP%16==8。サブルーチン内の呼び出しは CALL 直前 RSP%16==0
;   を保つため、入口から PUSH が奇数個になるように調整する。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- テスト 1: JE / JNE (等しい / 等しくない) ---
    lea  rsi, [rel msg_eq]
    call print_str
    mov  rax, 42
    mov  rbx, 42
    cmp  rax, rbx            ; 注意: print_str 内の OR がフラグを壊すため
    je   .yes1               ;       CMP は分岐の直前に置く
    lea  rsi, [rel msg_no]
    call print_str
    jmp  .next1
.yes1:
    lea  rsi, [rel msg_yes]
    call print_str
.next1:

    ; --- テスト 2: JL (符号あり「より小さい」) ---
    lea  rsi, [rel msg_slt]
    call print_str
    mov  rax, -5             ; 符号ありの負数 (0xFFFF...FB)
    mov  rbx, 10
    cmp  rax, rbx            ; -5 - 10 = 負 → JL 成立
    jl   .yes2
    lea  rsi, [rel msg_no]
    call print_str
    jmp  .next2
.yes2:
    lea  rsi, [rel msg_yes]
    call print_str
.next2:

    ; --- テスト 3: JG (符号あり「より大きい」) ---
    lea  rsi, [rel msg_sgt]
    call print_str
    mov  rax, 30
    mov  rbx, 10
    cmp  rax, rbx            ; 30 - 10 = 正 → JG 成立
    jg   .yes3
    lea  rsi, [rel msg_no]
    call print_str
    jmp  .next3
.yes3:
    lea  rsi, [rel msg_yes]
    call print_str
.next3:

    ; --- テスト 4: 符号あり JL vs 符号なし JA (同じ CMP、違う解釈) ---
    ; 0xFFFFFFFFFFFFFFFF は符号付きでは -1、符号なしでは 2^64-1。
    mov  rax, 0xFFFFFFFFFFFFFFFF   ; 同じビットパターンを両方の解釈で使う
    mov  rbx, 1
    lea  rsi, [rel msg_jl]
    call print_str
    cmp  rax, rbx            ; 符号あり解釈: -1 < 1 → JL 成立
    jl   .yes4
    lea  rsi, [rel msg_no]
    call print_str
    jmp  .next4
.yes4:
    lea  rsi, [rel msg_yes]
    call print_str
.next4:

    mov  rax, 0xFFFFFFFFFFFFFFFF   ; 同じ値を今度は符号なしで比較
    mov  rbx, 1
    lea  rsi, [rel msg_ja]
    call print_str
    cmp  rax, rbx            ; 符号なし解釈: 2^64-1 > 1 → JA 成立
    ja   .yes5
    lea  rsi, [rel msg_no]
    call print_str
    jmp  .next5
.yes5:
    lea  rsi, [rel msg_yes]
    call print_str
.next5:

    ; --- テスト 5: if-else チェーン ---
    lea  rsi, [rel msg_ife]
    call print_str
    mov  rax, 50
    cmp  rax, 10
    jl   .small
    cmp  rax, 100
    jg   .big
    lea  rsi, [rel msg_mid]
    call print_str
    jmp  .done5
.small:
    lea  rsi, [rel msg_small]
    call print_str
    jmp  .done5
.big:
    lea  rsi, [rel msg_big]
    call print_str
.done5:

    lea  rsi, [rel msg_dn]
    call print_str

.halt:
    cli                      ; 割り込み禁止
    hlt                      ; CPU 停止
    jmp  .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push rdx
    push rax
    mov  dx, 0x3FD           ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20            ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8           ; THR (送信保持レジスタ)
    pop  rax
    out  dx, al
    pop  rdx
    ret

; print_str: RSI の NULL 終端文字列を出力 (RAX/RSI は破壊する)
;   入口 RSP%16==8 → sub rsp,8 で CALL 直前 RSP%16==0 を保つ (s07 参照)
print_str:
    sub  rsp, 8
.loop:
    lodsb
    or   al, al
    jz   .ret
    call uart_putc
    jmp  .loop
.ret:
    add  rsp, 8
    ret

; ---- データ ----
section .rodata
msg_eq:  db "42 == 42? ", 0
msg_slt: db "-5 < 10?  ", 0
msg_sgt: db "30 > 10?  ", 0
msg_jl:  db "-1 < 1?  (JL, signed)     ", 0
msg_ja:  db "0xFFFFFFFFFFFFFFFF > 1?  (JA, unsigned)  ", 0
msg_ife: db "50: ", 0
msg_small: db "small (<10)", 13, 10, 0
msg_mid:   db "mid (10..100)", 13, 10, 0
msg_big:   db "big (>100)", 13, 10, 0
msg_yes:   db "Yes!", 13, 10, 0
msg_no:    db "No!", 13, 10, 0
msg_dn:    db "Done!", 13, 10, 0

scenario_halt equ _start.halt

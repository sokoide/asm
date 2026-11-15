; s08_hardware.asm - Scenario 8: ハードウェアアクセス (8254 PIT) (64-bit ロングモード)
; ===========================================================
; Learning objectives:
;   - Intel 8254 PIT (Programmable Interval Timer): I/O 0x40-0x43
;   - IN / OUT 命令によるハードウェアレジスタアクセス
;   - カウンタのラッチ (現在値の凍結) と読み取り
;   - 16-bit カウンタ値の読み取り順序: ローバイト → ハイバイト
;   - MOVZX: 16-bit → 32-bit のゼロ拡張。64-bit モードでは EAX への
;     書き込みで上位 32 ビットも 0 になるため、RAX 全体が 16-bit 値になる
;
; PIT の背景:
;   - カウンタ 0 の入力クロックは 1.193182 MHz (約 1.19 MHz)。
;   - ファームウェア (SeaBIOS) はカウンタ 0 を分周比 65536 で初期化するため、
;     1.193182 MHz / 65536 = 約 18.2 Hz でカウントダウンする。
;   - この 18.2 Hz (周期 約 55 ms) が PC/AT 以来の標準タイマ刻み。
;   - カウンタは常に動いているため、ラッチした値は実行のたびに変わる (値は変動)。
;
; 特権レベルについて: IN/OUT は CPL <= IOPL のときに許される特権命令だが、
; 本環境はロングモードで CPL=0 (最高特権) で動くため IOPL の値に関係なく
; 実行できる (CPL=0 は常に CPL <= IOPL を満たす)。
;
; スタックアラインメント (呼び出し規約の詳細は s07 参照):
;   関数入口は RSP%16==8。サブルーチン内の呼び出しは CALL 直前 RSP%16==0
;   を保つため、入口から PUSH が奇数個になるように調整する。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- PIT カウンタ 0 の読み取り ---
    ; カウンタ 0 のデータポートは I/O 0x40、制御レジスタは I/O 0x43。
    ; 現在のカウントを凍結 (ラッチ) するには:
    ;   port 0x43 に 0x00 を書き込む (カウンタ 0 選択 + ラッチ指示)
    ;   その後 port 0x40 から ローバイト → ハイバイト の順に読む

    lea  rsi, [rel msg_cnt]
    call print_str

    ; カウンタ 0 をラッチ
    mov  al, 0x00            ; 制御: カウンタ 0 選択, ラッチ
    mov  dx, 0x43
    out  dx, al

    ; ローバイト → ハイバイトの順に読む
    mov  dx, 0x40
    in   al, dx              ; ローバイト
    mov  bl, al
    in   al, dx              ; ハイバイト
    mov  bh, al              ; BX = 16-bit カウンタ値

    movzx eax, bx            ; 16-bit 値を 32-bit にゼロ拡張 (上位 32 ビットも 0)
    call print_hex64         ; 16 桁表示で上位 32 ビットが 0 であることも確認できる
    call print_crlf

    ; もう一度読んで、カウンタが動作中 (カウントダウン中) であることを示す
    lea  rsi, [rel msg_cnt2]
    call print_str

    mov  al, 0x00
    mov  dx, 0x43
    out  dx, al

    mov  dx, 0x40
    in   al, dx
    mov  bl, al
    in   al, dx
    mov  bh, al

    movzx eax, bx
    call print_hex64
    call print_crlf

    lea  rsi, [rel msg_done]
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

; print_hex64: RAX を 16 桁の 16 進数字として出力 (RAX を保存)
;   呼び出し時点の active PUSH 3 個 (奇数) → RSP%16==0 で呼べる (s07 参照)
print_hex64:
    push rax
    push rcx
    mov  rcx, 16             ; 出力するニブル数 = 16
.nibble:
    rol  rax, 4              ; 最上位ニブルを下位 4 ビットへ回転
    push rax                 ; マスク前の値を退避 (次のニブルのため)
    and  al, 0x0F
    call print_nibble
    pop  rax
    dec  rcx
    jnz  .nibble
    pop  rcx
    pop  rax
    ret

; print_nibble: AL の下位 4 ビットを 1 桁の 16 進数字として出力
print_nibble:
    push rax
    and  al, 0x0F
    add  al, '0'
    cmp  al, '9'
    jle  .out
    add  al, 7               ; 'A'-'F' のため '9' との隙間 (7) を詰める
.out:
    call uart_putc
    pop  rax
    ret

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
msg_cnt  db "PIT Counter 0: 0x", 0
msg_cnt2 db "PIT Counter 0: 0x", 0
msg_done db 13, 10, "Hardware access done!", 0

scenario_halt equ _start.halt

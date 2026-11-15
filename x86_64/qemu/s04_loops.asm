; s04_loops.asm - Scenario 4: Loops and Counters (64-bit ロングモード)
; ================================================
; Learning objectives:
;   - LOOP 命令 (ロングモードでは RCX をデクリメントし、RCX != 0 ならジャンプ)
;   - CMP 命令と条件フラグ
;   - 条件分岐: JE, JNE, JL, JG, JLE, JGE
;   - カウントアップ / カウントダウンのパターン
;
; 64-bit 固有の要点: LOOP が使うカウンタはアドレスサイズに従うため、
; 16-bit モードでは CX、32-bit モードでは ECX、ロングモードでは RCX になる。
; アドレスサイズ 64-bit の .loop ラベルへ loop すると常に RCX を見る。
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- Demo 1: LOOP によるカウントダウン (5 から 1) ---
    ; LOOP は RCX をデクリメントし、RCX != 0 ならジャンプする
    lea rsi, [rel msg1]
    call print_str

    mov rcx, 5
.loop1:
    mov al, cl              ; CL = RCX の下位 8 ビット
    add al, '0'             ; 数値を ASCII 数字へ変換
    call uart_putc
    mov al, ' '
    call uart_putc
    loop .loop1             ; RCX--; RCX != 0 ならジャンプ

    call print_crlf

    ; ループ終了後の RCX は 0 (64 ビット全体がクリアされている)
    lea rsi, [rel msg_rcx]
    call print_str
    mov rax, rcx
    call print_hex64        ; RCX 全体 (16 桁) が 0 で表示される
    call print_crlf

    ; --- Demo 2: CMP + JLE によるカウントアップ ---
    lea rsi, [rel msg2]
    call print_str

    mov rcx, 1
.loop2:
    mov al, cl
    add al, '0'
    call uart_putc
    mov al, ' '
    call uart_putc
    inc rcx
    cmp rcx, 5              ; 5 まで表示したら終了
    jle .loop2              ; RCX <= 5 ならジャンプ → 出力は 1..5

    call print_crlf

    ; --- Demo 3: TEST による偶数/奇数判定 ---
    ; TEST は AND を行うが結果は保存せずフラグだけを設定する
    lea rsi, [rel msg3]
    call print_str

    mov rax, 7
    test al, 1              ; bit 0 をテスト (奇数/偶数)
    jz  .even
    lea rsi, [rel msg_odd]
    call print_str
    jmp .done3
.even:
    lea rsi, [rel msg_even]
    call print_str
.done3:
    call print_crlf

    lea rsi, [rel msg_done]
    call print_str

.halt:
    cli                     ; 割り込み禁止
    hlt                     ; CPU 停止
    jmp .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push    rdx
    push    rax
    mov     dx, 0x3FD       ; LSR (ラインステータスレジスタ)
.wait:
    in      al, dx
    test    al, 0x20        ; bit 5 = THRE (送信保持レジスタ空)
    jz      .wait
    mov     dx, 0x3F8       ; THR (送信保持レジスタ)
    pop     rax
    out     dx, al
    pop     rdx
    ret

; print_str: NULL 終端文字列を RSI から表示 (RSI は文字列末尾へ進む)
print_str:
    lodsb                   ; AL = [RSI], RSI++ (DF = 0 なので正向き)
    or  al, al              ; NULL 終端?
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

; print_hex64: RAX を 16 桁の 16 進数字で表示 (上位 32 ビットから)
print_hex64:
    push    rax
    shr     rax, 32         ; 上位 32 ビットを下位へ
    call    print_hex32
    pop     rax
print_hex32:                ; RAX の下位 32 ビットを 8 桁で表示
    mov     eax, eax        ; 上位 32 ビットを捨てる (EAX 書き込みのゼロ拡張を利用)
    push    rax
    shr     rax, 16         ; bits 16-31 を下位 16 ビットへ
    call    print_hex16
    pop     rax
print_hex16:
    push    rax
    shr     rax, 8          ; bits 8-15 を AL へ
    call    print_hex8
    pop     rax
print_hex8:
    push    rax
    shr     rax, 4          ; 上位ニブル
    call    print_nibble
    pop     rax
print_nibble:
    and     al, 0x0F        ; 下位ニブル
    add     al, '0'
    cmp     al, '9'
    jle     .out
    add     al, 7           ; 'A' - '9' - 1
.out:
    call    uart_putc
    ret

print_crlf:
    push    rax
    mov     al, 13
    call    uart_putc
    mov     al, 10
    call    uart_putc
    pop     rax
    ret

; ---- データ ----
section .rodata
msg1     db "LOOP  5..1: ", 0
msg_rcx  db "RCX after LOOP = 0x", 0
msg2     db "Count 1..5: ", 0
msg3     db "7 is ", 0
msg_odd  db "odd", 0
msg_even db "even", 0
msg_done db 13, 10, "Loops done!", 0

scenario_halt equ _start.halt

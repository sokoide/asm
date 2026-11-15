; s13_copybench.asm - Scenario 13: Copy Benchmark (全アーキ共通課題)
; ==============================================================================
; Learning objectives:
;   - REP MOVSB: 64-bit RSI/RDI/RCX を使うロングモードのブロック転送
;     (ループコードなしのコピー。32-bit 版 x86_32/qemu/s13_copybench.asm との
;      対比でレジスタ幅だけが変わることが分かる)
;   - 100 バイトメモリコピーのチェックサム検証
;
; Task (全アーキ共通仕様):
;   - byte i = i (0..99) となる 100 バイトをコピー
;   - 宛先 100 バイトの総和を計算 (0+1+...+99 = 4950 = 0x1356)
;   - 出力はちょうど 1 行: "COPY OK CHECKSUM=1356"
;     (不一致時は "COPY FAIL CHECKSUM=xxxx")
;
; Build: nasm -f elf64 + ld.lld (boot.asm スタブがロングモード移行と .bss ゼロ
;        初期化を終えた後、0x8000 から実行、s01 と同じ)
;
; NOTE: サイクル数だけでは CPU 間の速度比較はできない (QEMU TCG はサイクル
;       精度でない)。REP MOVSB の手計算サイクル内訳 (8086: 9+17n =
;       17.09 クロック/バイト) は x86_16/qemu/s13_copybench.asm と
;       compare/copybench.md に記載。x86_64 のブロック転送タイミングは
;       copybench.md の比較表の対象外 (386 と同様)。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    cld                     ; DF = 0 (文字列操作は正向き: RSI/RDI をインクリメント)

    ; --- ソースデータ生成: byte i = i (0..99) ---
    lea  rdi, [rel src]     ; RDI = src へのポインタ (RIP 相対、stosb は ES:RDI)
    xor  eax, eax           ; AL = 0
    mov  ecx, 100
.fill:
    stosb                   ; [RDI] = AL, RDI++
    inc  al
    loop .fill              ; RCX--, RCX != 0 の間繰り返し

    ; --- コピー本体: REP MOVSB ---
    lea  rsi, [rel src]     ; RSI = 転送元
    lea  rdi, [rel dst]     ; RDI = 転送先
    mov  ecx, 100           ; バイト数
    rep movsb               ; RCX バイトをコピー (RSI/RDI は 1 バイトずつ進む)

    ; --- チェックサム: 宛先 100 バイトの総和 ---
    xor  ebx, ebx           ; RBX = 0 (総和 4950 は 8 ビットに収まらない。上位 32 ビットも 0 に)
    lea  rsi, [rel dst]
    mov  ecx, 100
.sum:
    lodsb                   ; AL = [DS:RSI], RSI++
    movzx eax, al           ; 8 ビットロードで上位ビットは変わらないため 0 を保証してから
    add  rbx, rax           ; RBX へ 64 ビット幅で加算 (x86_32 の add bl/adc bh を置き換え)
    loop .sum

    ; --- 検証して結果を出力 ---
    cmp  ebx, 0x1356        ; 0+1+...+99 = 4950 = 0x1356 (上位ビットは常に 0 なので EBX 比較でよい)
    jne  .fail

    lea  rsi, [rel msg_ok]
    call print_str
    mov  eax, ebx
    call print_hex16
    call print_crlf
    jmp  .halt

.fail:
    lea  rsi, [rel msg_fail]
    call print_str
    mov  eax, ebx
    call print_hex16
    call print_crlf

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

print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

print_hex16:                ; EAX の下 16 ビットを 4 桁の 16 進で出力
    push rax
    mov  al, ah             ; AH はロングモードでも使用可 (REX レジスタだけが高バイトを持たない)
    call print_hex8         ; 上位バイト
    pop  rax
    jmp  print_hex8         ; 下位バイト (末尾呼び出し)

print_hex8:
    push rax
    mov  cl, 4
    shr al, cl
    call print_nibble
    pop  rax
print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    call uart_putc
    ret

print_crlf:
    push rax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop  rax
    ret

; ---- データ ----
section .rodata
msg_ok   db "COPY OK CHECKSUM=", 0
msg_fail db "COPY FAIL CHECKSUM=", 0

section .data
src      times 100 db 0    ; 実行時に byte i = i (0..99) で埋める
dst      times 100 db 0

scenario_halt equ _start.halt

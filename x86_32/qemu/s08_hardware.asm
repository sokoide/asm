; s08_hardware.asm - Scenario 8: ハードウェアアクセス (8254 PIT) (32-bit 保護モード)
; ===========================================================
; Learning objectives:
;   - Intel 8254 PIT (Programmable Interval Timer): I/O 0x40-0x43
;   - IN / OUT 命令によるハードウェアレジスタアクセス
;   - カウンタのラッチ (現在値の凍結) と読み取り
;   - 16-bit カウンタ値の読み取り順序: ローバイト → ハイバイト
;   - MOVZX: 16-bit → 32-bit のゼロ拡張 (386 で新設された命令)
;
; PIT の背景:
;   - カウンタ 0 の入力クロックは 1.193182 MHz (約 1.19 MHz)。
;   - BIOS はカウンタ 0 を分周比 65536 で初期化するため、
;     1.193182 MHz / 65536 = 約 18.2 Hz でカウントダウンする。
;   - この 18.2 Hz (周期 約 55 ms) が PC/AT 以来の標準タイマ刻み。
;   - カウンタは常に動いているため、ラッチした値は実行のたびに変わる (値は変動)。
;
; 特権レベルについて: IN/OUT は CPL <= IOPL のときに許される特権命令だが、
; 本環境は CPL=0 (最高特権) で動くため IOPL の値に関係なく実行できる
; (CPL=0 は常に CPL <= IOPL を満たす)。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- PIT カウンタ 0 の読み取り ---
    ; カウンタ 0 のデータポートは I/O 0x40、制御レジスタは I/O 0x43。
    ; 現在のカウントを凍結 (ラッチ) するには:
    ;   port 0x43 に 0x00 を書き込む (カウンタ 0 選択 + ラッチ指示)
    ;   その後 port 0x40 から ローバイト → ハイバイト の順に読む

    mov  esi, msg_cnt
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

    movzx eax, bx            ; 16-bit 値を 32-bit にゼロ拡張 (上位 16 ビットは 0)
    call print_hex32
    call print_crlf

    ; もう一度読んで、カウンタが動作中 (カウントダウン中) であることを示す
    mov  esi, msg_cnt2
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
    call print_hex32
    call print_crlf

    mov  esi, msg_done
    call print_str

.halt:
    cli                      ; 割り込み禁止
    hlt                      ; CPU 停止
    jmp  .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
    push edx
    push eax
    mov  dx, 0x3FD           ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20            ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8           ; THR (送信保持レジスタ)
    pop  eax
    out  dx, al
    pop  edx
    ret

; print_str: DS:ESI の NULL 終端文字列を出力 (EAX/ESI は破壊する)
print_str:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

; print_hex32: EAX を 8 桁の 16 進数字として出力 (EAX を保存)
print_hex32:
    push eax
    push ecx
    mov  ecx, 8              ; 出力するニブル数 = 8
.nibble:
    rol  eax, 4              ; 最上位ニブルを下位 4 ビットへ回転
    push eax
    and  al, 0x0F
    call print_nibble
    pop  eax
    dec  ecx
    jnz  .nibble
    pop  ecx
    pop  eax
    ret

; print_nibble: AL の下位 4 ビットを 1 桁の 16 進数字として出力
print_nibble:
    push eax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7                ; 'A'-'F' のため '9' との隙間 (7) を詰める
.out:
    call uart_putc
    pop eax
    ret

print_crlf:
    push eax
    mov al, 13
    call uart_putc
    mov al, 10
    call uart_putc
    pop eax
    ret

; ---- データ ----
section .rodata
msg_cnt  db "PIT Counter 0: 0x", 0
msg_cnt2 db "PIT Counter 0: 0x", 0
msg_done db 13, 10, "Hardware access done!", 0

scenario_halt equ _start.halt

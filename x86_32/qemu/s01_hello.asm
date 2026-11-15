; s01_hello.asm - Scenario 1: Hello World (32-bit 保護モード)
; =========================================
; Learning objectives:
;   - ブート → 移行スタブ → 0x8000 の _start という実行フローの確認
;   - 32-bit レジスタ (ESI/EAX) とポート入出力 (IN/OUT)
;   - COM1 UART 出力 (16550 at I/O port 0x3F8)
;   - LODSB と NULL 終端文字列
;   - CPU 停止ループ (CLI + HLT)
;
; 本シナリオは boot.asm のスタブが保護モード移行を終えた後、
; 0x8000 から実行される。保護モードでは BIOS 割り込みは使用不可
; (IDT 未構築のため INT も不可) なので、出力は UART を直接叩く。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    mov  esi, message          ; ESI = 文字列へのポインタ
.print_loop:
    lodsb                      ; AL = [DS:ESI], ESI++ (DF = 0 なので正向き)
    or   al, al                ; NULL 終端?
    jz   .halt
    call uart_putc             ; COM1 へ 1 文字出力
    jmp  .print_loop

.halt:
    cli                        ; 割り込み禁止
    hlt                        ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
    push edx
    push eax
    mov  dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8             ; THR (送信保持レジスタ)
    pop  eax
    out  dx, al
    pop  edx
    ret

; ---- データ ----
section .rodata
message db "Hello, 80386 World!", 13, 10, 0

scenario_halt equ _start.halt

; s02_registers.asm - Scenario 2: Registers and Arithmetic (32-bit 保護モード)
; =========================================================
; Learning objectives:
;   - 32-bit 汎用レジスタ: EAX, EBX, ECX, EDX, EDI
;   - 部分レジスタアクセス: AL/AX への書き込みは EAX の下位ビットだけ変更
;   - MOV, ADD, SUB, INC, DEC 命令
;   - 16 進表示サブルーチン (print_hex32)
;   - COM1 UART 出力 (16550 at I/O port 0x3F8)
;
; 本シナリオは boot.asm のスタブが保護モード移行とセグメント/スタック
; 初期化 (ESP = 0x90000, DF = 0) を終えた後、0x8000 から実行される。

cpu 386
bits 32
global _start, scenario_halt

section .text
_start:
    ; --- MOV: レジスタ間のデータ転送 ---
    mov eax, 0x12345678     ; EAX = 0x12345678 (x86_16 版の 0x1234 の 32-bit 版)
    mov ebx, eax            ; EBX = EAX (コピー)
    mov ecx, 0x000000FF     ; ECX = 0x000000FF

    ; --- 表示 1: MOV の結果 ---
    mov esi, msg1
    call print_str
    mov eax, 0x12345678
    call print_hex32
    call print_crlf

    ; --- 部分レジスタ: AL は EAX の下位 8 ビット、AX は下位 16 ビット ---
    ; 上位ビットは書き込み前の値がそのまま残る (16-bit CPU には無い挙動)
    mov eax, 0x12345678
    mov al, 0xFF            ; AL のみ: EAX = 0x123456FF
    mov edx, eax            ; 表示のために EDX へ退避 (print_str は AL を壊す)
    mov esi, msg2
    call print_str
    mov eax, edx
    call print_hex32
    call print_crlf

    mov eax, 0x12345678
    mov ax, 0xBEEF          ; AX のみ: EAX = 0x1234BEEF
    mov edx, eax
    mov esi, msg3
    call print_str
    mov eax, edx
    call print_hex32
    call print_crlf

    ; --- ADD, SUB, INC, DEC ---
    mov eax, 10             ; EAX = 10
    mov ebx, 20             ; EBX = 20
    add eax, ebx            ; EAX = 30 (0x0000001E)
    mov edi, eax            ; EDI = 30
    sub edi, 5              ; EDI = 25 (0x00000019)
    inc edi                 ; EDI = 26 (0x0000001A)
    dec edi                 ; EDI = 25 に戻る

    ; --- 表示 2: 演算結果 ---
    mov esi, msg4
    call print_str
    mov eax, 30             ; 10 + 20 の結果
    call print_hex32
    call print_crlf

    mov esi, msg5
    call print_str
    mov eax, edi            ; 30 - 5 の結果
    call print_hex32
    call print_crlf

    mov esi, msg_done
    call print_str

.halt:
    cli                     ; 割り込み禁止
    hlt                     ; CPU 停止
    jmp .halt               ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
uart_putc:
    push    edx
    push    eax
    mov     dx, 0x3FD       ; LSR (ラインステータスレジスタ)
.wait:
    in      al, dx
    test    al, 0x20        ; bit 5 = THRE (送信保持レジスタ空)
    jz      .wait
    mov     dx, 0x3F8       ; THR (送信保持レジスタ)
    pop     eax
    out     dx, al
    pop     edx
    ret

; print_str: NULL 終端文字列を DS:ESI から表示 (ESI は文字列末尾へ進む)
print_str:
    lodsb
    or  al, al              ; NULL 終端?
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

; print_hex32: EAX を 8 桁の 16 進数字で表示 (上位バイトから)
print_hex32:
    push    eax
    shr     eax, 16         ; 上位 16 ビットを下位へ
    call    print_hex16
    pop     eax
print_hex16:
    push    eax
    shr     eax, 8          ; bits 8-15 を AL へ
    call    print_hex8
    pop     eax
print_hex8:
    push    eax
    shr     eax, 4          ; 上位ニブル
    call    print_nibble
    pop     eax
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
    push    eax
    mov     al, 13
    call    uart_putc
    mov     al, 10
    call    uart_putc
    pop     eax
    ret

; ---- データ ----
section .rodata
msg1     db "mov eax, 0x12345678 -> EAX=", 0
msg2     db "mov al, 0xFF       -> EAX=0x", 0
msg3     db "mov ax, 0xBEEF     -> EAX=0x", 0
msg4     db "10 + 20      = 0x", 0
msg5     db "30 - 5       = 0x", 0
msg_done db 13, 10, "Done!", 0

scenario_halt equ _start.halt

; s02_registers.asm - Scenario 2: Registers and Arithmetic (64-bit ロングモード)
; =========================================================
; Learning objectives:
;   - 64-bit 汎用レジスタ: RAX, RBX, RCX, RDX, RDI と拡張レジスタ R8-R15
;   - 部分レジスタアクセス: AL/AX への書き込みは下位ビットだけ変更し上位は保持
;   - 64-bit 固有の挙動: EAX への書き込みは RAX の上位 32 ビットをゼロクリア
;   - MOV, ADD, SUB, INC, DEC 命令 (64-bit 演算)
;   - 16 進表示サブルーチン (print_hex64 / print_hex32)
;   - COM1 UART 出力 (16550 at I/O port 0x3F8)
;
; 本シナリオは boot.asm のスタブがロングモード移行とスタック初期化
; (RSP = 0x90000, DF = 0) を終えた後、0x8000 から実行される。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- MOV: レジスタ間のデータ転送と 64-bit 即値 ---
    ; mov r64, imm64 はロングモード固有の形式 (32-bit では即値は 32-bit まで)
    mov rax, 0x1234567890ABCDEF ; RAX = 0x1234567890ABCDEF
    mov rbx, rax                ; RBX = RAX (コピー)
    mov rcx, 0x00000000000000FF ; RCX = 0xFF

    ; --- 表示 1: MOV の結果 ---
    lea rsi, [rel msg1]
    call print_str
    mov rax, 0x1234567890ABCDEF ; print_str が AL を壊すので再ロードして表示
    call print_hex64
    call print_crlf

    ; --- 部分レジスタ: AL は RAX の下位 8 ビット、AX は下位 16 ビット ---
    ; 上位ビットは書き込み前の値がそのまま残る (32/64-bit では共通の挙動)
    mov rax, 0x1234567890ABCDEF
    mov al, 0xFF                ; AL のみ: RAX = 0x1234567890ABCDFF (上位 56 ビット保持)
    mov rdx, rax                ; 表示のために RDX へ退避 (print_str は AL を壊す)
    lea rsi, [rel msg2]
    call print_str
    mov rax, rdx
    call print_hex64
    call print_crlf

    mov rax, 0x1234567890ABCDEF
    mov ax, 0xBEEF              ; AX のみ: RAX = 0x1234567890ABBEEF (上位 48 ビット保持)
    mov rdx, rax
    lea rsi, [rel msg3]
    call print_str
    mov rax, rdx
    call print_hex64
    call print_crlf

    ; --- 64-bit 固有: EAX への書き込みは RAX 全体を書き換える ---
    ; ロングモードでは 32-bit レジスタへの書き込み結果は上位 32 ビットが
    ; ゼロで埋められる (ゼロ拡張)。AL/AX と違い上位ビットは保持されない。
    mov rax, 0x1234567890ABCDEF
    mov eax, 0x90ABCDEF         ; EAX のみ: RAX = 0x0000000090ABCDEF (上位 32 ビットは 0)
    mov rdx, rax
    lea rsi, [rel msg_eax]
    call print_str
    mov rax, rdx
    call print_hex64
    call print_crlf

    ; --- R8-R15: ロングモードで追加された 8 本の 64-bit レジスタ ---
    ; R8-R15 は命令に REX プレフィックスを付けてエンコードされる
    mov r9, 0x1122334455667788  ; R9 = 0x1122334455667788 (mov r64, imm64)
    lea rsi, [rel msg_r9]
    call print_str
    mov rax, r9
    call print_hex64
    call print_crlf

    ; --- ADD, SUB, INC, DEC (64-bit 演算) ---
    mov rax, 10                 ; RAX = 10
    mov rbx, 20                 ; RBX = 20
    add rax, rbx                ; RAX = 30 (0x000000000000001E)
    mov rdi, rax                ; RDI = 30
    sub rdi, 5                  ; RDI = 25 (0x0000000000000019)
    inc rdi                     ; RDI = 26 (0x000000000000001A)
    dec rdi                     ; RDI = 25 に戻る

    ; --- 表示 2: 演算結果 (32-bit に収まる値は print_hex32 で 8 桁表示) ---
    lea rsi, [rel msg4]
    call print_str
    mov eax, 30                 ; 10 + 20 の結果 (EAX 書き込みで上位は 0)
    call print_hex32
    call print_crlf

    lea rsi, [rel msg5]
    call print_str
    mov eax, edi                ; 30 - 5 の結果
    call print_hex32
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
    push rcx                ; 呼び出し規約: 入口は RSP % 16 = 8 のため 1 push して
                            ; CALL 直前の RSP を 16 の倍数に揃える (S07 参照)
.loop:
    lodsb                   ; AL = [RSI], RSI++ (DF = 0 なので正向き)
    or   al, al             ; NULL 終端?
    jz   .ret
    call uart_putc
    jmp .loop
.ret:
    pop rcx
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
msg1     db "mov rax, 0x1234567890ABCDEF -> RAX=0x", 0
msg2     db "mov al, 0xFF       -> RAX=0x", 0
msg3     db "mov ax, 0xBEEF     -> RAX=0x", 0
msg_eax  db "mov eax, 0x90ABCDEF -> RAX=0x", 0
msg_r9   db "mov r9, 0x1122334455667788 -> R9=0x", 0
msg4     db "10 + 20      = 0x", 0
msg5     db "30 - 5       = 0x", 0
msg_done db 13, 10, "Done!", 0

scenario_halt equ _start.halt

; s03_stack.asm - Scenario 3: Stack Operations (64-bit ロングモード)
; ==============================================
; Learning objectives:
;   - PUSH / POP 命令 (64-bit: 1 回に 8 バイト)
;   - LIFO (Last In, First Out) の動作
;   - スタックポインタ RSP の自動調整 (PUSH で -8、POP で +8)
;   - レジスタの保存/復元パターン
;
; 本シナリオは boot.asm のスタブが SS = フラット、RSP = 0x90000 に
; 初期化済みのため、シナリオ側の SS/RSP 設定は不要。
; 0x90000 は 16 の倍数なので _start 直後の RSP は 16-byte アライン済み。
; System V AMD64 呼び出し規約では call 直前の RSP を 16 の倍数に保つ
; 慣例がある (PUSH 命令自体のハードウェア要件ではない)。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- PUSH: RSP は 8 減り、64 ビット値が [RSP] に格納される ---
    ; --- POP:  [RSP] から 64 ビット値をロードし、RSP は 8 増える ---

    mov rax, 0x1122334455667788
    push rax                ; RSP: 0x90000 -> 0x8FFF8, [0x8FFF8] = 0x1122334455667788
    lea rsi, [rel msg_rsp1]
    call print_str
    mov rax, rsp            ; RSP のスナップショットを表示へ
    call print_hex64
    call print_crlf

    mov rax, 0x99AABBCCDDEEFF00
    push rax                ; RSP: 0x8FFF8 -> 0x8FFF0, [0x8FFF0] = 0x99AABBCCDDEEFF00
    lea rsi, [rel msg_rsp2]
    call print_str
    mov rax, rsp
    call print_hex64
    call print_crlf

    ; --- POP は逆順 (LIFO: 最後に積んだものが最初に取り出される) ---
    pop rbx                 ; RBX = 0x99AABBCCDDEEFF00 (最後に push した値)
    pop rax                 ; RAX = 0x1122334455667788
    push rax                ; あとで使うのでスタックへ退避

    ; 1 つ目の POP 結果を表示
    lea rsi, [rel msg1]
    call print_str
    mov rax, rbx            ; 0x99AABBCCDDEEFF00
    call print_hex64
    call print_crlf

    ; 2 つ目の POP 結果を表示
    lea rsi, [rel msg2]
    call print_str
    pop rax                 ; 0x1122334455667788 (退避した値を復元)
    call print_hex64
    call print_crlf

    ; --- RSP 表示: PUSH と POP が対になれば開始値 (0x90000) に戻る ---
    lea rsi, [rel msg_rsp3]
    call print_str
    mov rax, rsp
    call print_hex64
    call print_crlf

    ; --- 保存/復元パターン ---
    mov rax, 42             ; RAX = 42
    push rax                ; RAX をスタックに保存
    mov rax, 99             ; RAX = 99 (壊す)
    ; ... 他の処理 ...
    pop rax                 ; RAX = 42 に復元

    mov rdx, rax            ; 表示中の破壊に備えて退避
    lea rsi, [rel msg3]
    call print_str
    mov rax, rdx            ; 42
    call print_hex32        ; 32-bit に収まる値は 8 桁表示
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
msg_rsp1 db "RSP after 1 PUSH = 0x", 0
msg_rsp2 db "RSP after 2 PUSH = 0x", 0
msg1     db "1st POP = 0x", 0
msg2     db "2nd POP = 0x", 0
msg_rsp3 db "RSP back to start = 0x", 0
msg3     db "Saved/restored RAX = 0x", 0
msg_done db 13, 10, "Stack demo done!", 0

scenario_halt equ _start.halt

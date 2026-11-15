; s101_riprel.asm - Scenario 101: RIP 相対アドレッシング (x86_64 固有)
; ====================================================================
; Learning objectives:
;   - lea rax, [rel label]: RIP 相対でアドレスを取得する (位置独立コードの基礎)
;   - mov rax, [rel value64]: RIP 相対でデータを読む
;   - RIP 相対の基準は「命令の次のアドレス」: 同じラベルでも命令の場所が
;     違えばエンコードされる disp32 が変わり、計算結果のアドレスは一致する
;   - mov rax, imm64 (絶対即値) との対比: アドレスを機械語に埋め込むため
;     リンク時に確定し、別アドレスへロードすると壊れる = 位置依存。
;     RIP 相対はどこにロードされても disp32 が自動補正される = 位置独立
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- その 1: lea [rel label] でアドレスを取得する ---
    ; lea は実行時に「命令の次のアドレス (RIP) + disp32」を計算する。
    ; 同じラベルを参照する lea を 2 か所 (距離を離して) 置き、
    ; 命令の場所が違っても結果が一致することを確かめる。
    ; ラベルは _start のローカルラベルにする (.halt の所属を _start に保つため)
.lea1_site:
    lea  r12, [rel message]    ; サイト 1: R12 = message のリニアアドレス (7 バイト命令)
    nop                        ; サイト間に他の命令を挟み、
    nop                        ; 「命令サイズぶんずれた」2 つの場所を作る
    nop
.lea2_site:
    lea  r13, [rel message]    ; サイト 2: R13 = 同じ message のアドレス (7 バイト命令)

    ; --- 表示 1: サイト 1 の lea 結果 ---
    lea  rsi, [rel msg_lea1]
    call print_str
    mov  rax, r12
    call print_hex64
    call print_crlf

    ; --- 表示 2: サイト 2 の lea 結果 (サイト 1 と同じ値になる) ---
    lea  rsi, [rel msg_lea2]
    call print_str
    mov  rax, r13
    call print_hex64
    call print_crlf

    ; --- その 2: mov [rel value64] でデータを読む ---
    ; ロード命令も同じ disp32 方式。rodata 上の 64-bit 値を読む。
    lea  rsi, [rel msg_mov]
    call print_str
    mov  rax, [rel value64]
    call print_hex64
    call print_crlf

    ; --- その 3a: 2 つの lea 結果の差 = 0 ---
    ; 命令の場所が 10 バイトずれても disp32 が自動補正されるため、
    ; 計算結果は完全に一致する。これが「命令の場所からの相対」=
    ; 位置独立コード (PIC) の本質。
    lea  rsi, [rel msg_resdiff]
    call print_str
    mov  rax, r12
    sub  rax, r13
    call print_hex64
    call print_crlf

    ; --- その 3b: エンコードされた disp32 の差 = サイト間距離 ---
    ; lea r64, [rel label] は REX(1) + 8D(1) + ModRM(1) + disp32(4) = 7 バイト。
    ; disp32 = ラベル - (命令の次のアドレス)。命令先頭 +3 バイトから
    ; disp32 を直接読むと、エンコードされた「RIP との距離」そのものが見える。
    ; 2 つの disp32 の差 = 2 つの lea の配置差 (lea 7 バイト + nop 3 バイト = 10 バイト)。
    lea  rsi, [rel .lea1_site+3]
    movsxd rax, dword [rsi]    ; RAX = disp1 = message - (.lea1_site + 7)
    lea  rsi, [rel .lea2_site+3]
    movsxd rcx, dword [rsi]    ; RCX = disp2 = message - (.lea2_site + 7)
    sub  rax, rcx              ; RAX = disp1 - disp2 = lea2_site - lea1_site = サイト間距離
    mov  rdx, rax              ; print_str が AL を壊すため退避
    lea  rsi, [rel msg_dispdiff]
    call print_str
    mov  rax, rdx
    call print_hex64
    call print_crlf

    ; --- 終了 ---
    lea  rsi, [rel msg_done]
    call print_str

.halt:
    cli                        ; 割り込み禁止
    hlt                        ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push rdx
    push rax
    mov  dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8             ; THR (送信保持レジスタ)
    pop  rax
    out  dx, al
    pop  rdx
    ret

; print_str: NULL 終端文字列を RSI から表示 (RSI と AL を壊す)
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
msg_lea1     db "lea  [rel msg]    = 0x", 0
msg_lea2     db "lea2 [rel msg]    = 0x", 0
msg_mov      db "mov  [rel value]  = 0x", 0
msg_resdiff  db "res diff          = 0x", 0
msg_dispdiff db "disp diff         = 0x", 0
msg_done     db 13, 10, "RIP-relative done!", 13, 10, 0

value64      dq 0x1122334455667788  ; mov [rel value64] で読む値
message      db "rip-relative", 0   ; lea のターゲット (コード直後の rodata)

scenario_halt equ _start.halt

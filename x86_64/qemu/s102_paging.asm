; s102_paging.asm - Scenario 102: 4 段ページングと 2MB ページ (x86_64 固有)
; ========================================================================
; Learning objectives:
;   - CR3 は第 4 段 (PML4) の物理アドレスを持つ。ロングモードのアドレス変換は
;     PML4 → PDPT → PD → PT の 4 段 (各テーブルは 512 エントリ x 8 バイト)
;   - エントリのフラグビット: P (bit 0) / RW (bit 1) / US (bit 2) / PS (bit 7)
;   - A (bit 5, accessed) と D (bit 6, dirty) は CPU が変換に使ったときに
;     自動で立てるビット。シナリオ実行時には boot 直後の値に A/D が付いている
;     (PD[1] は一度も使われないため生値のまま)。本シナリオでは boot が書いた
;     構築値を表示するため A/D をマスクしてから出力する
;   - PD エントリの PS=1 は 2MB ページ (大ページ): このエントリがページ物理
;     アドレス (bits 51:21) を直接持つため PT は参照されない。ここが
;     4KB ページ (第 5 段の PT まで参照) との違い
;   - boot.asm が構築した実テーブルをダンプし、CR3 を起点に手計算の
;     3 段ウォークで VA → PA 変換を確認する
;
; boot.asm が構築したテーブル (先頭 1GB を 512 個の 2MB ページで identity map):
;   PML4 @ 0x1000: PML4[0] = 0x0000000000002003 (PDPT @ 0x2000 へ)
;   PDPT @ 0x2000: PDPT[0] = 0x0000000000003003 (PD   @ 0x3000 へ)
;   PD   @ 0x3000: PD[i]   = (i << 21) | 0x083  (P | RW | PS)
;
; 物理 0x1000 / 0x2000 / 0x3000 は identity map 済みで CPL=0 なので
; リニアアドレス経由で直接読める。64-bit では絶対アドレス指定を
; レジスタ経由で行う (mov rsi, 0x1000 → mov rax, [rsi])。

cpu x64
bits 64
global _start, scenario_halt

; --- エントリのフィールドマスク (64-bit 即値はレジスタ経由で使う) ---
MASK_ADDR equ 0x000FFFFFFFFFF000   ; PML4/PDPT/CR3: 次層テーブルの物理アドレス (bits 51:12)
MASK_2MB  equ 0x000FFFFFE00000     ; 2MB ページエントリ: ページ物理アドレス (bits 51:21)
MASK_AD   equ 0xFFFFFFFFFFFFFF9F   ; ~(A | D) = ~(bit5 | bit6): 構築値表示用
VA_WALK   equ 0x004123456          ; ウォークする VA: PD index = 0x4123456 >> 21 = 32,
                                  ; ページ内オフセット = 0x123456

section .text
_start:
    ; R12-R15 にマスク定数を置く (AND r64, imm64 は符号拡張 imm32 までの
    ; エンコーディングしかないため 64-bit 即値はレジスタ経由にする)
    mov  r15, MASK_ADDR        ; R15 = 次層アドレスマスク
    mov  r14, MASK_2MB         ; R14 = 2MB ページ物理アドレスマスク
    mov  r13, MASK_AD          ; R13 = A/D 除外マスク

    ; --- 1. CR3 を読む: PML4 の物理アドレス ---
    ; CR3[51:12] = PML4 の物理アドレス。CR3[11:0] は PCID / PWT・PCD フラグ
    ; なのでページフレーム基底を取り出して表示する (実機でも一般的な処理)。
    lea  rsi, [rel msg_cr3]
    call print_str
    mov  rax, cr3
    and  rax, r15              ; PML4 の物理アドレス = 0x1000
    mov  r12, rax              ; ウォークの起点として退避
    call print_hex64
    call print_crlf

    ; --- 2. PML4[0] (物理 0x1000): 次層 PDPT を指す ---
    lea  rsi, [rel msg_pml4]
    call print_str
    mov  rsi, 0x1000
    mov  rax, [rsi]            ; boot 構築値 0x2003 (+ 実行中に立った A/D)
    and  rax, r13              ; A/D を除いた構築値を表示する
    call print_hex64
    mov  rdx, rax
    call print_prwus           ; " (P=n RW=n US=n"
    mov  rax, rdx
    and  rax, r15              ; 次層テーブル = 0x2000
    mov  rdx, rax
    lea  rsi, [rel msg_next_pdpt]
    call print_str
    mov  rax, rdx
    mov  ecx, 4
    call print_hex_w
    lea  rsi, [rel msg_rparen]
    call print_str
    call print_crlf

    ; --- 3. PDPT[0] (物理 0x2000): 次層 PD を指す ---
    lea  rsi, [rel msg_pdpt]
    call print_str
    mov  rsi, 0x2000
    mov  rax, [rsi]            ; boot 構築値 0x3003 (+ A/D)
    and  rax, r13
    call print_hex64
    mov  rdx, rax
    call print_prwus           ; " (P=n RW=n US=n"
    mov  rax, rdx
    and  rax, r15              ; 次層テーブル = 0x3000
    mov  rdx, rax
    lea  rsi, [rel msg_next_pd]
    call print_str
    mov  rax, rdx
    mov  ecx, 4
    call print_hex_w
    lea  rsi, [rel msg_rparen]
    call print_str
    call print_crlf

    ; --- 4. PD[0], PD[1] (物理 0x3000): PS=1 の 2MB ページ ---
    ; PD エントリは bits 51:21 にページ物理アドレスを持ち、PT は参照しない。
    ; PD[0] はコード (0x8000) やスタック (0x90000)、テーブル自身 (0x1000-0x3FFF)
    ; を含む 2MB 領域なので実行中に A/D が立つ。PD[1] は未アクセスで生値のまま。
    lea  rsi, [rel msg_pd0]
    call print_str
    mov  rsi, 0x3000
    mov  rax, [rsi]            ; boot 構築値 0x0083 (+ A/D)
    and  rax, r13
    call print_hex64
    mov  rdx, rax
    call print_prwus           ; " (P=n RW=n US=n"
    call print_ps2mb           ; " PS=n 2MB@0xnnnnnn"
    lea  rsi, [rel msg_rparen]
    call print_str
    call print_crlf

    lea  rsi, [rel msg_pd1]
    call print_str
    mov  rsi, 0x3008
    mov  rax, [rsi]            ; boot 構築値 0x00200083 (未アクセスで A/D なし)
    and  rax, r13
    call print_hex64
    mov  rdx, rax
    call print_prwus           ; " (P=n RW=n US=n"
    call print_ps2mb           ; " PS=n 2MB@0xnnnnnn"
    lea  rsi, [rel msg_rparen]
    call print_str
    call print_crlf

    ; --- 5. 手計算の 3 段ウォーク: VA 0x004123456 → PA ---
    ; PML4 index = VA bits 47:39 = 0 → PML4[0] (= CR3 が指すテーブル)
    ; PDPT index = VA bits 38:30 = 0 → PDPT[0] (= 物理 0x2000)
    ; PD index   = VA bits 29:21 = 32 → PD[32] (物理 0x3000 + 32*8 = 0x3100)
    ; PD[32] は PS=1 → 2MB ページ: PA = (PD[32] & MASK_2MB) + (VA & 0x1FFFFF)
    ;             = 0x04000000 + 0x123456 = 0x04123456 (= VA: identity map)
    mov  rdi, r12              ; 第 4 段の起点 = CR3 が指す PML4 (0x1000)
    mov  rax, [rdi]            ; PML4[0]
    mov  rdi, rax
    and  rdi, r15              ; → 0x2000
    mov  rax, [rdi]            ; 第 3 段: PDPT[0]
    mov  rdi, rax
    and  rdi, r15              ; → 0x3000
    mov  rcx, VA_WALK
    shr  rcx, 21               ; PD index = 32
    and  rcx, 0x1FF
    shl  rcx, 3                ; エントリサイズ 8 バイト → オフセット 0x100
    add  rdi, rcx              ; PD[32] のアドレス = 0x3100
    mov  rax, [rdi]            ; 第 2 段: PD[32] = 0x0000000004000083
    and  rax, r14              ; ページ物理アドレス = 0x04000000 (PS=1 なので PT なし)
    mov  rcx, VA_WALK
    and  rcx, 0x1FFFFF         ; ページ内オフセット = 0x123456
    add  rax, rcx              ; PA = 0x04123456

    ; 変換結果を表示し、VA == PA (identity) を確認する
    mov  rdx, rax              ; PA を退避 (print_str が AL を壊すため)
    lea  rsi, [rel msg_walk]
    call print_str
    mov  rax, VA_WALK
    mov  ecx, 9
    call print_hex_w
    lea  rsi, [rel msg_arrow]
    call print_str
    mov  rax, rdx
    mov  ecx, 9
    call print_hex_w
    mov  rcx, VA_WALK
    cmp  rdx, rcx              ; PA == VA ?
    jne  .mismatch
    lea  rsi, [rel msg_identity]
    call print_str
    jmp  .walk_done
.mismatch:
    lea  rsi, [rel msg_mismatch]
    call print_str
.walk_done:
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

; print_hex64: RAX を 16 桁の 16 進数字で表示
print_hex64:
    push    rcx
    mov     ecx, 16
    call    print_hex_w
    pop     rcx
    ret

; print_hex_w: RAX を CL 桁 (1-16) の 16 進で表示 (ゼロ埋め、上位桁から)
; 対象フィールドを最上位へローテートしてからニブルごとに取り出す。
; 回転は RDX のコピーに対して行う (uart_putc へ渡す AL への文字設定が
; RAX の未出力ニブルを壊さないようにするため)
print_hex_w:
    push    rax
    push    rcx
    push    rdx
    push    rbx
    mov     rdx, rax          ; RDX = 表示中の作業コピー
    mov     rbx, rcx
    shl     rbx, 2            ; RBX = 桁数 x 4 (出力ビット数)
    mov     rcx, 64
    sub     rcx, rbx          ; 対象フィールドが最上位へ来るローテート数
    rol     rdx, cl           ; rol r64, cl
    mov     rcx, rbx
    shr     rcx, 2            ; ループ回数 = 桁数
.wloop:
    rol     rdx, 4            ; 上位ニブルが下位へ回る
    mov     al, dl
    and     al, 0x0F
    add     al, '0'
    cmp     al, '9'
    jle     .p
    add     al, 7             ; 'A' - '9' - 1
.p:
    call    uart_putc
    dec     rcx
    jnz     .wloop
    pop     rbx
    pop     rdx
    pop     rcx
    pop     rax
    ret

; print_bit: RAX の CL ビットを '0' / '1' で表示
print_bit:
    push    rax
    push    rcx
    shr     rax, cl
    and     al, 1
    add     al, '0'
    call    uart_putc
    pop     rcx
    pop     rax
    ret

; print_prwus: RAX = テーブルエントリ → " (P=n RW=n US=n" を表示
; bits 0/1/2 = P / RW / US。RAX を保存復元する。
print_prwus:
    push    rax
    push    rcx
    push    r9
    mov     r9, rax
    lea     rsi, [rel s_p]
    call    print_str             ; " (P="
    mov     rax, r9
    mov     cl, 0
    call    print_bit             ; P  (bit 0)
    lea     rsi, [rel s_rw]
    call    print_str             ; " RW="
    mov     rax, r9
    mov     cl, 1
    call    print_bit             ; RW (bit 1)
    lea     rsi, [rel s_us]
    call    print_str             ; " US="
    mov     rax, r9
    mov     cl, 2
    call    print_bit             ; US (bit 2)
    pop     r9
    pop     rcx
    pop     rax
    ret

; print_ps2mb: RAX = PD エントリ → " PS=n 2MB@0xnnnnnn" を表示
; bits 7 = PS (大ページ)。物理アドレス部 (bits 51:21) を 6 桁で出す。
; R14 には _start で設定した MASK_2MB が入っている前提。
print_ps2mb:
    push    rax
    push    rcx
    push    r9
    mov     r9, rax
    lea     rsi, [rel s_ps]
    call    print_str             ; " PS="
    mov     rax, r9
    mov     cl, 7
    call    print_bit             ; PS (bit 7)
    lea     rsi, [rel s_2mb]
    call    print_str             ; " 2MB@0x"
    mov     rax, r9
    and     rax, r14
    mov     ecx, 6
    call    print_hex_w
    pop     r9
    pop     rcx
    pop     rax
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
msg_cr3       db "CR3          = 0x", 0
msg_pml4      db "PML4[0]      = 0x", 0
msg_pdpt      db "PDPT[0]      = 0x", 0
msg_pd0       db "PD[0]        = 0x", 0
msg_pd1       db "PD[1]        = 0x", 0
msg_walk      db "walk 0x", 0
msg_arrow     db " -> 0x", 0
msg_identity  db " (identity)", 0
msg_mismatch  db " (MISMATCH!)", 0
msg_rparen    db ")", 0
msg_next_pdpt db " -> PDPT@0x", 0
msg_next_pd   db " -> PD@0x", 0
msg_done      db 13, 10, "Paging done!", 13, 10, 0

; デコード用の断片文字列
s_p    db " (P=", 0
s_rw   db " RW=", 0
s_us   db " US=", 0
s_ps   db " PS=", 0
s_2mb  db " 2MB@0x", 0

scenario_halt equ _start.halt

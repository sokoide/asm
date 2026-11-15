; s07_subroutines.asm - Scenario 7: サブルーチン (64-bit ロングモード)
; ================================================
; Learning objectives:
;   - CALL: 戻りアドレス (8 バイト) をスタックに退避してラベルへジャンプ
;   - RET: 戻りアドレスをスタックから復帰して呼び出し元へ戻る
;   - レジスタによる引数渡しと戻り値 (System V AMD64: RDI/RSI → RAX)
;   - ネストしたサブルーチン呼び出し
;   - System V AMD64 のスタックアラインメント:
;       CALL 直前の RSP は 16 の倍数 (0x90000 は既にアライン済み)
;       関数入口では RSP % 16 == 8 (CALL が 8 バイトの戻りアドレスを PUSH するため)
;       PUSH が奇数個になったら and rsp, -16 や sub rsp, 8 で揃え直す
;     これは PUSH 命令のハードウェア要件ではなく呼び出し規約上の約束事。
;     守らないと movaps のような 16 バイトアラインを要求する SSE 命令が
;     スタック上のデータを触った瞬間に #GP で落ちる。
;   - callee-saved (RBX/RBP/R12-R15) は使う関数が保存する責任を持つ。
;     caller-saved (RAX/RCX/RDX/RSI/RDI/R8-R11) は呼び出し側が退避する。
;   - red zone (RSP 直下 128 バイトの signal safe 領域) は本教材では使わない
;
; 移行スタブ (boot.asm) が DS をフラットセグメントに設定し、RSP = 0x90000
; (スタックトップ、16 の倍数) に初期化済み。ロングモードでは常に CPL=0 で
; 動作するため、特別な設定なしにスタックが使える。CALL は 64-bit モードでは
; 8 バイトの戻りアドレス (RIP) をスタックに PUSH し、RET がそれを POP する。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- スタックアラインメントの観察 ---
    ; _start の時点で RSP = 0x90000 (16 の倍数)。CALL 直前の RSP が
    ; 16 の倍数という規約は、スタブ初期値のままで既に満たされている。
    lea  rsi, [rel msg_rsp0]
    call print_str              ; この呼び出しも CALL 直前 RSP%16 == 0
    mov  rax, rsp               ; 現在の RSP (= 0x90000) を表示
    call print_hex64
    call print_crlf

    ; 関数入口では CALL が戻りアドレスを PUSH 済み → RSP % 16 == 8
    lea  rsi, [rel msg_ent]
    call print_str
    call show_entry_rsp         ; 入口 RSP = 0x8FFF8 を表示
    call print_crlf

    ; PUSH が奇数個あると規約が崩れる。まず崩れた場合を実測:
    lea  rsi, [rel msg_un]
    call print_str
    push rax                    ; ダミーで 1 つ PUSH → CALL 直前 RSP%16 == 8 (違反)
    call show_entry_rsp         ; 入口 RSP = 0x8FFF0 を表示 (規約違反の状態)
    pop  rax                    ; 本環境では壊れないが、movaps を使う関数では #GP で落ちる
    call print_crlf

    ; sub rsp, 8 で CALL 直前の RSP%16 == 0 を作り直せば規約どおり:
    lea  rsi, [rel msg_fix]
    call print_str
    push rax                    ; ダミー PUSH (RSP%16 == 8)
    sub  rsp, 8                 ; 8 バイト調整 → CALL 直前 RSP%16 == 0
    call show_entry_rsp         ; 入口 RSP = 0x8FFE8 を表示 (規約どおり)
    add  rsp, 8                 ; 調整を戻す
    pop  rax
    call print_crlf

    ; --- 呼び出し 1: 文字列を出力 ---
    lea  rsi, [rel msg1]              ; 引数: RSI = 文字列へのポインタ
    call print_str
    call print_crlf

    ; --- 呼び出し 2: 値を 16 桁の 16 進で出力 ---
    lea  rsi, [rel msg2]
    call print_str
    mov  rax, 0xDEADBEEF        ; 引数: RAX = 表示する値 (0x00000000DEADBEEF。
                                ; NASM は 32-bit 値をゼロ拡張する mov eax,imm32 短縮形
                                ; を選ぶ。真の imm64 は s02 の mov rax,0x1234567890ABCDEF)
    call print_hex64
    call print_crlf

    lea  rsi, [rel msg3]
    call print_str
    mov  rax, 0x00C0FFEE        ; 上位 48 ビットの 0 も 16 桁すべて出力される
    call print_hex64
    call print_crlf

    ; --- 呼び出し 3: ネストした呼び出し (print_dots が uart_putc を呼ぶ) ---
    lea  rsi, [rel msg4]
    call print_str
    mov  ecx, 5                 ; 引数: RCX = 個数 (64-bit の LOOP は RCX を減らす)
    call print_dots
    call print_crlf

    ; --- 呼び出し 4: 計算して表示 (add_values) ---
    mov  ebx, 0x5A5A            ; RBX = callee-saved の実験値 (呼び出しをまたいで無傷か?)
    mov  edi, 42                ; 引数: RDI = 第 1 オペランド (SysV 第 1 引数)
    mov  esi, 13                ; 引数: RSI = 第 2 オペランド (SysV 第 2 引数)
    call add_values             ; 戻り値: RAX = RDI + RSI
    lea  rsi, [rel msg5]
    call print_str              ; print_str は使ったレジスタを退避する (RAX は無傷)
    call print_hex64            ; RAX = 42 + 13 = 55 = 0x37 を出力
    call print_crlf

    ; --- callee-saved の観察: RBX は一連の呼び出しをまたいで無傷 ---
    ; 本教材のルーチンは RBX を使わないため自然に保存される。
    ; RBX/RBP/R12-R15 を使う関数は入口で PUSH、出口で POP して返す義務がある。
    lea  rsi, [rel msg_rbx]
    call print_str              ; この呼び出しをまたいでも RBX は変化しないはず
    mov  rax, rbx
    call print_hex64            ; 0x5A5A のまま → callee-saved 規約どおり
    call print_crlf

    lea  rsi, [rel msg_done]
    call print_str

.halt:
    cli                         ; 割り込み禁止
    hlt                         ; CPU 停止
    jmp  .halt                  ; NMI で再開しても再度停止

; ---- サブルーチン ----
; 共通ルール: 関数入口では RSP%16==8。何か PUSH したまま他を呼ぶときは
; PUSH が奇数個にならないように (奇数個なら sub rsp, 8 で調整) CALL 直前の
; RSP%16==0 を保つ。red zone は使わない。

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push rdx
    push rax
    mov  dx, 0x3FD              ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20               ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8              ; THR (送信保持レジスタ)
    pop  rax
    out  dx, al
    pop  rdx
    ret

; show_entry_rsp: 関数入口の RSP 値を表示 (アラインメント観察用の実測関数)
show_entry_rsp:
    mov  rax, rsp               ; 入口直後の RSP を記録 (まだ何も PUSH していない)
    sub  rsp, 8                 ; 入口は RSP%16==8 → 呼び出しのために 0 へ調整
    call print_hex64            ; RAX を 16 桁で表示 (RAX は保存される)
    add  rsp, 8
    ret

; add_values: 2 つの値を加算して返す (System V AMD64 風のレジスタ渡し)
;   引数:   RDI = 第 1 オペランド, RSI = 第 2 オペランド
;   戻り値: RAX = RDI + RSI
add_values:
    mov  rax, rdi
    add  rax, rsi
    ret

; print_dots: '.' を RCX 個出力 (ネストした呼び出し)
print_dots:
    sub  rsp, 8                 ; 入口 RSP%16==8 → 呼び出しのために調整
.loop:
    mov  al, '.'
    call uart_putc              ; ネストした呼び出し
    loop .loop                  ; LOOP: RCX を減算し 0 でなければ .loop へ
    add  rsp, 8
    ret

; print_str: RSI の NULL 終端文字列を出力
;   厳密には System V AMD64 で退避義務があるのは callee-saved (RBX/RBP/R12-R15)
;   だけ。ここでは教材として x86_32 版と同じく使う全レジスタを退避し、
;   呼び出し側から見てすべてのレジスタを無傷にする。
;   入口 RSP%16==8 から PUSH 5 個 (奇数) で RSP%16==0 → 内部の呼び出しも
;   アラインメントを保つ。
print_str:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
.loop:
    lodsb                       ; AL = [DS:RSI], RSI++ (DF = 0 なので正向き)
    or   al, al                 ; NULL 終端?
    jz   .done
    call uart_putc
    jmp  .loop
.done:
    pop  rdi
    pop  rsi
    pop  rdx
    pop  rcx
    pop  rax
    ret

; print_hex64: RAX を 16 桁の 16 進数字として出力 (RAX を保存)
;   入口 RSP%16==8、呼び出し時点の active PUSH は rax/rcx/ループ内 rax の
;   3 個 (奇数) → RSP%16==0 で print_nibble を呼べる
print_hex64:
    push rax
    push rcx
    mov  rcx, 16                ; 出力するニブル数 = 16
.nibble:
    rol  rax, 4                 ; 最上位ニブルを下位 4 ビットへ回転
    push rax                    ; マスク前の値を退避 (次のニブルのため)
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
    add  al, 7                  ; 'A'-'F' のため '9' との隙間 (7) を詰める
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
msg_rsp0 db "RSP at _start: 0x", 0
msg_ent  db "show_entry_rsp entry: 0x", 0
msg_un   db "PUSH 1x then CALL:   0x", 0
msg_fix  db "PUSH + sub rsp,8:    0x", 0
msg1     db "Hello from subroutine!", 0
msg2     db "Hex: 0x", 0
msg3     db "Hex: 0x", 0
msg4     db "Loading", 0
msg5     db "42+13=0x", 0
msg_rbx  db "RBX still: 0x", 0
msg_done db 13, 10, "Subroutines done!", 0

scenario_halt equ _start.halt

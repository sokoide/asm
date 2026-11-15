; s103_syscall.asm - Scenario 103: SYSCALL / SYSRET (CPL=0 ↔ CPL=3 の高速切替)
; =========================================================
; Learning objectives:
;   - SYSCALL 機能の CPUID 確認 (leaf 0x80000001, EDX bit 11) と EFER.SCE 有効化
;   - STAR / LSTAR / FMASK MSR の設定と STAR に埋め込むセレクタ配置
;     (SYSCALL: CS=STAR[47:32], SS=STAR[47:32]+8 /
;      SYSRET:  CS=STAR[63:48]+16|RPL3, SS=STAR[63:48]+8|RPL3)
;   - ユーザコード・データ GDT エントリの追記 (DPL=3, L=1)
;   - 4 段ページング全階層と 2MB リーフへの U/S (bit 2) 設定と CR3 再書込
;   - IRETQ による特権降格 (CPL 0 → 3) と専用ユーザスタック (0x200000)
;   - SYSCALL は RSP を切替えない: 入口でユーザ RSP を保存しカーネルスタックへ
;   - RCX (戻り RIP) と R11 (RFLAGS) が SYSCALL で破壊されること
;   - SYSRETQ の復帰点 (RIP ← RCX) と canonical アドレス
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。既存 GDT (null + 0x08/0x10/0x18) にユーザ用
; エントリを追記してから IRETQ で CPL=3 へ降格する。
; IDT 未構築のため IF=0 のまま (ユーザモードでも割り込みなし)。
; CPL=3 からは UART I/O を行わない (出力はすべてカーネル側)。
;
; 簡略化: U/S=1 は PML4[0]/PDPT[0]/PD[0]/PD[1] すべてに立てるため、
; カーネル (.text) やページテーブルを含む先頭 2MB も CPL=3 から
; アクセス可能。CPL 遷移の実演が目的であり、権限分離の実現例では
; ない (実際の OS はユーザ領域のページだけ U/S=1 にする)。
;
; 動作: ユーザコードが RAX=1..5 を渡して 5 回 syscall し、最後に RAX=0xFF
; (終了マーカ) を渡す。ハンドラはマーカを受けたら SYSRET せずカーネル側で
; 「syscall count = 5, last value = 5」を表示して停止する。
;
; 注: NASM に sysretq ニーモニックはないため o64 sysret (48 0F 07) を使う。

cpu x64
bits 64
default abs                 ; [] は絶対参照 (NASM 3 の暗黙 ABS 非推奨警告を回避)。
                            ;   参照先はすべて canonical な下位アドレス (< 4GB)
global _start, scenario_halt

section .text
_start:
    ; --- 1. CPUID: SYSCALL 拡張機能の確認 (leaf 0x80000001, EDX bit 11) ---
    mov  eax, 0x80000001
    cpuid                       ; EDX bit 11 = syscall 機能 (qemu64 では有効)
    test edx, 1 << 11
    jz   .cpuid_no              ; 機能がなければ表示して停止
    lea  rsi, [rel msg_cpuid_yes]
    call print_str
    call print_crlf

    ; --- 2. EFER.SCE = 1 (bit 0): SYSCALL/SYSRET 命令の有効化 ---
    mov  ecx, 0xC0000080        ; IA32_EFER
    rdmsr                       ; EDX:EAX = EFER
    or   eax, 1                 ; SCE = bit 0
    wrmsr
    mov  ecx, 0xC0000080
    rdmsr                       ; 読み戻して設定を確認
    test eax, 1
    jz   .sce_fail
    lea  rsi, [rel msg_sce_on]
    call print_str
    call print_crlf

    ; --- 3. GDT へユーザエントリ 3 件を追記して lgdt ---
    ; 既存 GDT (base=0x7EF0): 0x00 null / 0x08 32-bit code / 0x10 data /
    ; 0x18 64-bit code (現在の CS)。これに続きを足す (メモリ内容は無傷なので
    ; 現在の CS=0x18 の記述子キャッシュもそのまま有効)。
    sgdt [gdtr]                 ; GDTR を読み出し (limit @ gdtr, base @ gdtr+2)
    mov  rdi, [gdtr+2]          ; RDI = GDT ベース線形アドレス (0x7EF0)
    mov  rax, 0x0020FA0000000000 ; ユーザコード: P=1 DPL=3 S=1 Type=1100 (0xFA),
    mov  [rdi+0x20], rax        ;   L=1 (flags=0x20) — limit/base は L=1 では無視
    mov  rax, 0x00CFF2000000FFFF ; ユーザデータ: P=1 DPL=3 S=1 Type=0010 (0xF2),
    mov  [rdi+0x28], rax        ;   G=1 B=1 limit=4G (0x00CF...)
    mov  rax, 0x0020FA0000000000 ; 同じユーザコードをもう 1 スロット:
    mov  [rdi+0x30], rax        ;   SYSRET の CS = STAR[63:48]+16 (0x33) 用
    mov  word [gdtr], 0x37      ; リミットを 7 エントリ (0x00..0x30) 分へ拡張
    lgdt [gdtr]
    ; セレクタの対応 (STAR[63:48]=0x0020 を U とする):
    ;   IRETQ   : CS=0x23 (GDT[0x20] 実ロード) / SS=0x2B (GDT[0x28] 実ロード)
    ;   SYSCALL : CS=0x08 / SS=0x10 (Intel SDM: CS=STAR[47:32], SS=STAR[47:32]+8。
    ;             隠し部はフラット 64-bit の固定値で GDT を参照しない)
    ;   SYSRETQ : CS=0x33 / SS=0x2B (CS=STAR[63:48]+16|RPL3, SS=STAR[63:48]+8|RPL3。
    ;             隠し部は DPL=3 の固定値, GDT 不参照)
    ; 実測 (gdb): SYSCALL 後 SS=0x10 / SYSRETQ 後 CS=0x33・SS=0x2B は
    ; いずれもマニュアル仕様どおり (QEMU 11.1 TCG で確認)。

    ; --- 4. ページテーブルへ U/S (bit 2) を設定 — 全階層と 2MB リーフ ---
    or  dword [0x1000], 0x04    ; PML4[0]  0x00002003 → 0x00002007
    or  dword [0x2000], 0x04    ; PDPT[0]  0x00003003 → 0x00003007
    or  dword [0x3000], 0x04    ; PD[0]    0x00000083 → 0x00000087
                                ;   0x000000-0x1FFFFF: コード/GDT/カーネル領域
    or  dword [0x3008], 0x04    ; PD[1]    0x00200083 → 0x00200087
                                ;   0x200000-0x3FFFFF: ユーザスタック領域
    mov  rax, cr3
    mov  cr3, rax               ; CR3 再書込で TLB 全消去 (PTE 変更を確実に反映)

    ; --- 5. STAR / LSTAR / FMASK の設定 ---
    ; STAR: [63:48]=0x0020 (ユーザ CS ベース), [47:32]=0x0008 (カーネル CS)
    ; bits 47:32 は EDX/EAX の境界にまたがるため:
    ;   EDX = STAR[63:32] = 0x0020_0008, EAX = STAR[31:0] = 0
    mov  edx, 0x00200008
    xor  eax, eax
    mov  ecx, 0xC0000081        ; IA32_STAR
    wrmsr
    ; LSTAR: SYSCALL の飛び先 = ハンドラの線形アドレス (< 4GB なので EDX=0)
    lea  rax, [rel syscall_handler]
    xor  edx, edx
    mov  ecx, 0xC0000082        ; IA32_LSTAR
    wrmsr
    ; FMASK: SYSCALL 時の RFLAGS マスク = 0 (MSTAR は本教材では使わない)
    xor  edx, edx
    xor  eax, eax
    mov  ecx, 0xC0000084        ; IA32_FMASK
    wrmsr
    ; STAR を読み戻して表示 (MSR に書き込んだ値の確認)
    mov  ecx, 0xC0000081
    rdmsr
    shl  rdx, 32
    or   rax, rdx               ; RAX = STAR 全 64 ビット
    lea  rsi, [rel msg_star]
    call print_str
    call print_hex64
    call print_crlf

    ; --- 6. IRETQ で CPL=3 へ降格 ---
    lea  rsi, [rel msg_enter]
    call print_str
    call print_crlf
    mov  rax, 0x2B              ; ユーザ SS = 0x28 | RPL3
    push rax
    mov  rax, 0x200000          ; 専用ユーザスタック (identity map の RAM)
    push rax
    mov  rax, 0x2               ; RFLAGS: IF=0 — IDT 未構築のため割り込み不可のまま
    push rax
    mov  rax, 0x23              ; ユーザ CS = 0x20 | RPL3
    push rax
    lea  rax, [rel user_start]  ; ユーザ RIP (canonical な下位アドレス)
    push rax
    iretq                       ; CPL 0 → 3: SS/RSP/RFLAGS/CS/RIP を一括復帰
                                ;   (以後このカーネル側へは SYSCALL でのみ戻る)

; ---- カーネル後段 (.done は handler から jmp で到達 / 異常系 / 停止) ----
.done:
    lea  rsi, [rel msg_done]
    call print_str
    mov  rax, [sys_count]
    add  al, '0'                ; 呼出回数 (1 桁前提で ASCII 化)
    call uart_putc
    lea  rsi, [rel msg_last]
    call print_str
    mov  rax, [sys_last]
    add  al, '0'                ; 最後の値 (1 桁前提)
    call uart_putc
    call print_crlf
    jmp  .halt

.cpuid_no:
    lea  rsi, [rel msg_cpuid_no]
    call print_str
    call print_crlf
    jmp  .halt
.sce_fail:
    lea  rsi, [rel msg_sce_fail]
    call print_str
    call print_crlf

.halt:
    cli                         ; 割り込み禁止
    hlt                         ; CPU 停止
    jmp  .halt                  ; NMI で再開しても再度停止

; ==================== ユーザコード (CPL=3, UART I/O 禁止) ====================
user_start:
    mov  eax, 0x2B              ; DS/ES もユーザデータへ。64-bit モードではデータ
    mov  ds, eax                ;   アクセスに DS/ES は使われないが整合させておく
    mov  es, eax
    mov  r9d, 1                 ; ループカウンタ (SYSCALL が壊さないレジスタ)

.user_loop:
    mov  rax, r9                ; 渡す値 (RAX = syscall 引数)
    syscall                     ; CPL3 → CPL0 (LSTAR)。RCX=戻り RIP, R11=RFLAGS
                                ;   に変わるため RCX/R11 には依存できない
.user_ret:
    inc  r9d                    ; (RCX が指す復帰点 = この直前の syscall の次)
    cmp  r9d, 5
    jbe  .user_loop

    ; --- 終了マーカ 0xFF を渡す。ハンドラは SYSRET せずカーネル側で停止 ---
    mov  rax, 0xFF
    syscall
.user_no_return:                ; ここへは戻らない (フォールト時の無限ループも兼ねる)
    jmp  .user_no_return

; ==================== SYSCALL ハンドラ (CPL=0, LSTAR) ====================
; 入口状態: CS=0x08 / SS=0x10 (STAR[47:32] 由来), CPL=0, IF=0
;           RSP=ユーザ RSP のまま (SYSCALL は RSP を切替えない!)
;           RCX=戻り RIP, R11=ユーザ RFLAGS — SYSRET 復帰に使うので保存のこと
syscall_handler:
    mov  [user_rsp_save], rsp   ; 入口でユーザ RSP を保存
    mov  rsp, 0x90000           ; カーネルスタックへ切替 (0x200000 は触らない)
    cmp  rax, 0xFF              ; 終了マーカ?
    je   _start.done            ; SYSRET せずカーネル側の要約表示 → 停止へ
    inc  qword [sys_count]      ; 通常 syscall: 呼出回数を累積
    mov  [sys_last], rax        ; 最後に渡された値を記録
    mov  rsp, [user_rsp_save]   ; ユーザ RSP を復元
    o64 sysret                  ; SYSRETQ (48 0F 07): RIP←RCX, RFLAGS←R11,
                                ;   CS=0x33, SS=0x2B で CPL=3 へ戻る

; ---- サブルーチン ----

; uart_putc: AL の 1 文字を COM1 (16550 UART, I/O 0x3F8) へ出力
; ポート番号と IN/OUT 命令は 16/32-bit 版と同一 (ロングモードでも不変)
uart_putc:
    push    rdx
    push    rax
    mov     dx, 0x3FD           ; LSR (ラインステータスレジスタ)
.wait:
    in      al, dx
    test    al, 0x20            ; bit 5 = THRE (送信保持レジスタ空)
    jz      .wait
    mov     dx, 0x3F8           ; THR (送信保持レジスタ)
    pop     rax
    out     dx, al
    pop     rdx
    ret

; print_str: NULL 終端文字列を RSI から表示 (RSI は文字列末尾へ進む)
print_str:
    lodsb                       ; AL = [RSI], RSI++ (DF = 0 なので正向き)
    or  al, al                  ; NULL 終端?
    jz  .ret
    call uart_putc
    jmp print_str
.ret:
    ret

; print_hex64: RAX を 16 桁の 16 進数字で表示 (上位 32 ビットから)
print_hex64:
    push    rax
    shr     rax, 32             ; 上位 32 ビットを下位へ
    call    print_hex32
    pop     rax
print_hex32:                    ; RAX の下位 32 ビットを 8 桁で表示
    mov     eax, eax            ; 上位 32 ビットを捨てる (EAX 書き込みのゼロ拡張を利用)
    push    rax
    shr     rax, 16             ; bits 16-31 を下位 16 ビットへ
    call    print_hex16
    pop     rax
print_hex16:
    push    rax
    shr     rax, 8              ; bits 8-15 を AL へ
    call    print_hex8
    pop     rax
print_hex8:
    push    rax
    shr     rax, 4              ; 上位ニブル
    call    print_nibble
    pop     rax
print_nibble:
    and     al, 0x0F            ; 下位ニブル
    add     al, '0'
    cmp     al, '9'
    jle     .out
    add     al, 7               ; 'A' - '9' - 1
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
section .data
gdtr:           dw 0             ; sgdt 書き込み先: limit (@ +0)
                dq 0             ;   GDT ベース (@ +2, 64-bit モードでは 8 バイト)
user_rsp_save:  dq 0             ; ハンドラ入口でのユーザ RSP 退避先
sys_count:      dq 0             ; syscall 呼出回数 (終了マーカを除く)
sys_last:       dq 0             ; 最後に渡された値

section .rodata
msg_cpuid_yes db "CPUID syscall = yes", 0
msg_cpuid_no  db "CPUID syscall = no", 0
msg_sce_on    db "EFER.SCE on", 0
msg_sce_fail  db "EFER.SCE off", 0
msg_star      db "STAR = 0x", 0
msg_enter     db "enter CPL=3", 0
msg_done      db "syscall count = ", 0
msg_last      db ", last value = ", 0

scenario_halt equ _start.halt

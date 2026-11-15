; s104_sse.asm - Scenario 104: SSE (XMM レジスタとパック単精度演算) (x86_64 固有)
; ==============================================================================
; Learning objectives:
;   - CPUID leaf 1 EDX bit 25 (SSE) による機能確認 (AVX = ECX bit 28 は不要)
;   - SSE 有効化のための制御レジスタ初期化:
;       CR0.EM (bit 2) / CR0.TS (bit 3) のクリア — EM=1 だと SSE 命令は #UD、
;       TS=1 だと SSE 命令は #NM になるため
;       CR4.OSFXSR (bit 9) / CR4.OSXMMEXCPT (bit 10) のセット — それぞれ
;       「FXSAVE/FXRSTOR で XMM 状態も保存する」「#XF ハンドラを持つ」ことを
;       OS が宣言するビット。0 のままだと SSE 命令 / マスク外 SIMD FP 例外は
;       #UD になる
;   - movaps (aligned) / addps / subps によるパック単精度 float 演算
;   - CVTTSS2SI (SSE1) による float → 整数変換と結果の ASCII 表示
;   - レーン順: メモリの dd 並びの先頭 = レーン 0 (bits 31:0, リトルエンディアン)
;
; movaps の 16 バイトアライン制約:
;   movaps のメモリオペランドは 16 バイト境界に配置されている必要がある。
;   境界から外れていると #GP(0) フォルト (本環境は IDT 未構築のため三重
;   フォルト → リセット扱いで停止)。境界を問わないロード/ストアには movups
;   もあるが、昔の CPU では movaps の方が顕著に速かった (現在はほぼ同等)。
;   本シナリオでは .rodata / .bss とも align 16 / alignb 16 で保証する。
;
; XMM レジスタ:
;   64-bit モードでは XMM0-XMM15 の 16 本 (32-bit モードは 8 本)。各 XMM は
;   128 ビット = 単精度 float 4 レーン。本シナリオは SSE1 命令 (movaps /
;   addps / subps / cvttss2si) のみを使い、SSE2 以降の命令や AVX (CPUID
;   leaf 1 ECX bit 28) には依存しない。
;
; FXSAVE / FXRSTOR (本シナリオでは使用しない):
;   x87 + XMM + MXCSR 状態を 512 バイトのメモリ領域へ一括保存/復元する命令。
;   実 OS はタスク切替時にこの領域で FPU/SIMD コンテキストを保存する
;   (前提知識としてのみ紹介)。
;
; 動作: a={1,2,3,4} + b={4,4,4,4} を addps で計算し "5678"、
;       c={8,7,6,5} - d={1,2,3,4} を subps で計算し "7531" を表示する。
;
; 本シナリオは boot.asm のスタブがロングモード移行を終えた後、
; 0x8000 から実行される。IDT 未構築のため INT は使用不可なので、
; 出力は UART を直接叩く。

cpu x64
bits 64
global _start, scenario_halt

section .text
_start:
    ; --- 1. CPUID leaf 1: EDX bit 25 = SSE サポートの確認 ---
    ; qemu64 のデフォルト CPU モデルでも SSE は有効。AVX (ECX bit 28) は
    ; 本シナリオでは使わないため確認しない。
	mov     eax, 1
    cpuid                       ; EDX = leaf 1 の機能フラグ
	test    edx, 1 << 25           ; bit 25 = SSE
	jz      .no_sse
	lea     rsi, [rel msg_sse_yes]
	call    print_str
	call    print_crlf

    ; --- 2. CR0: EM (bit 2) と TS (bit 3) をクリア ---
    ; EM=1 は「x87 FPU をソフトウェアでエミュレートする」宣言で、SSE 命令は
    ; #UD になる。TS=1 は「タスク切替後に FPU/SIMD 状態を未復帰」の印で、
    ; SSE 命令は #NM (デバイス使用不可) になる。どちらも SSE 命令の実行を
    ; 阻むため、SSE を使う前に明示的に 0 に戻しておく。
	mov     rax, cr0
	and     rax, ~0x0C             ; bits 2 (EM) / 3 (TS) をクリア → #NM/#UD 防止
	mov     cr0, rax

    ; --- 3. CR4: OSFXSR (bit 9) と OSXMMEXCPT (bit 10) をセット ---
    ; OSFXSR=0 のままでは XMM を使う SSE 命令が #UD になり、OSXMMEXCPT=0 の
    ; ままではマスク外 SIMD FP 例外が #XF ではなく #UD になる (どちらも
    ; 「OS が対応していない」前提の保護)。boot 直後の CR4 は PAE (bit 5) のみ
    ; なので、0x600 を OR すると 0x620 になる。
	mov     rax, cr4
	or      rax, 0x600             ; bit 9 = OSFXSR, bit 10 = OSXMMEXCPT
	mov     cr4, rax
	lea     rsi, [rel msg_cr4]
	call    print_str
	mov     rax, cr4               ; 書き込み後の実値を読み戻して表示
	call    print_hex64
	call    print_crlf

    ; --- 4. addps: パック加算 a + b (結果レーン "5678") ---
    movaps xmm0, [rel a]        ; XMM0 = {1.0, 2.0, 3.0, 4.0} (16 バイト境界必須)
    movaps xmm1, [rel b]        ; XMM1 = {4.0, 4.0, 4.0, 4.0}
    addps  xmm1, xmm0           ; XMM1 = XMM1 + XMM0 = {5.0, 6.0, 7.0, 8.0}
                                ;   (dest = src1 演算を全 4 レーンに一括適用)
    movaps [rel buf_add], xmm1  ; 結果を .bss の 16 バイト境界バッファへ

    ; --- 5. subps: パック減算 c - d (結果レーン "7531") ---
    movaps xmm0, [rel c]        ; XMM0 = {8.0, 7.0, 6.0, 5.0}
    movaps xmm1, [rel d]        ; XMM1 = {1.0, 2.0, 3.0, 4.0}
    subps  xmm0, xmm1           ; XMM0 = XMM0 - XMM1 = {7.0, 5.0, 3.0, 1.0}
    movaps [rel buf_sub], xmm0

    ; --- 6. レーン結果の表示 ---
    ; 注意: 各レーンは IEEE754 単精度のビットパターン (例: 5.0 = 0x40A00000、
    ; リトルエンディアンで 00 00 A0 40)。格納バイトをそのまま読んでもどの
    ; 1 バイトも桁数字に一致しないため、SSE1 の CVTTSS2SI で整数へ変換して
    ; から '0' を加えて表示する (1 桁前提)。
	lea     rsi, [rel msg_addps]
	call    print_str
	lea     rsi, [rel buf_add]
	call    print_lanes
	call    print_crlf

	lea     rsi, [rel msg_subps]
	call    print_str
	lea     rsi, [rel buf_sub]
	call    print_lanes
	call    print_crlf

    ; --- 7. XMM レジスタ本数のノート ---
    ; 64-bit モードでは XMM0-XMM15 の 16 本。AVX (CPUID leaf 1 ECX bit 28)
    ; が無くても SSE1 のパック演算は使える — この確認が本シナリオの目的。
	lea     rsi, [rel msg_xmm]
	call    print_str
	call    print_crlf

    ; --- 終了 ---
	lea     rsi, [rel msg_done]
	call    print_str
    jmp  .halt

.no_sse:
	lea     rsi, [rel msg_sse_no]
	call    print_str
	call    print_crlf             ; SSE 非対応: デモは実行せず停止

.halt:
	cli ; 割り込み禁止
	hlt ; CPU 停止
    jmp  .halt                 ; NMI で再開しても再度停止

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

; print_str: NULL 終端文字列を RSI から表示 (RSI と AL を壊す)
print_str:
	lodsb ; AL = [RSI], RSI++ (DF = 0 なので正向き)
	or      al, al                  ; NULL 終端?
	jz      .ret
	call    uart_putc
    jmp print_str
.ret:
	ret

; print_lanes: RSI = float x4 バッファの先頭 → 4 レーンを整数化して連結表示
; レーン rcx の単精度 float を CVTTSS2SI (SSE1, 0 への切り捨て) で 32-bit
; 整数へ変換し、1 桁前提で '0' を加えて出力する。RCX は uart_putc が保存し、
; RSI は [RSI + RCX*4] のベースとして不変。
print_lanes:
	xor     ecx, ecx
.lane:
    cvttss2si eax, [rsi + rcx*4]  ; レーン rcx の float → EAX (SSE1)
	add     al, '0'
	call    uart_putc
	inc     ecx
	cmp     ecx, 4
	jb      .lane
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
section .rodata
msg_sse_yes db "CPUID SSE      = 1", 0
msg_sse_no  db "CPUID SSE      = 0", 0
msg_cr4     db "CR4            = 0x", 0
msg_addps   db "addps lanes    = ", 0
msg_subps   db "subps lanes    = ", 0
msg_xmm     db "XMM0-15        = 16 regs (SSE1 only, AVX not needed)", 0
msg_done    db 13, 10, "SSE done!", 13, 10, 0

; パック単精度の入力 (各 dd が 1 レーン: 先頭 dd = レーン 0 = bits 31:0)。
; movaps は 16 バイト境界必須のため align 16 で配置する。
;   a + b → {5,6,7,8} = "5678" / c - d → {7,5,3,1} = "7531"
align 16
a dd 1.0, 2.0, 3.0, 4.0
b dd 4.0, 4.0, 4.0, 4.0
c dd 8.0, 7.0, 6.0, 5.0
d dd 1.0, 2.0, 3.0, 4.0

section .bss
alignb 16
buf_add resd 4                  ; addps 結果格納先
buf_sub resd 4                  ; subps 結果格納先

scenario_halt equ _start.halt

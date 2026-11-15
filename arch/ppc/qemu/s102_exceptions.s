// s102_exceptions.s - Scenario 102: Exceptions (Book E IVPR/IVOR, PPC440-specific)
// ================================================================================
// PPC440 (Book E) の例外処理を学ぶ。
//   - 例外ベクタは固定アドレスではなく IVPR (64KB 境界) + IVORn (オフセット) で決まる
//     プログラム割り込み (tw トラップ) = IVOR6、システムコール (sc) = IVOR8
//   - 例外発生時: SRR0 = 巻き戻し PC、SRR1 = 例外時の MSR が自動保存される
//     (x86 の割り込みスタック経由ではなくレジスタ 2 本で渡す設計)
//   - ハンドラは rfi で復帰 (SRR0/SRR1 -> PC/MSR)
//
// ハンドラはリンカスクリプトの .handler (0x01000100) / .handler2 (0x01000200)
// セクションに配置する。IVPR = 0x01000000、IVOR6 = 0x0100、IVOR8 = 0x0200。
//
// 観察方法: make trace S=s102_exceptions で例外突入時の NIP (SRR0 相当) と
// MSR の変化が追える。
//
// 注意: tw で例外に入ると SRR0 は tw 自身を指す。rfi で戻ると再実行して
// 無限ループになるため、ハンドラ内で SRR0 += 4 (スキップ) する。
// sc の場合 SRR0 は sc の次の命令を指すためスキップ不要。

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // ---- 例外ベクタの設定 (Book E) ----
    lis     %r3, 0x0100
    mtspr   63, %r3             // IVPR = 0x01000000 (64KB 境界必須)
    li      %r4, 0x0100
    mtspr   406, %r4            // IVOR6 = 0x0100: program interrupt (tw)。SPR 400+n
    li      %r4, 0x0200
    mtspr   408, %r4            // IVOR8 = 0x0200: system call (sc)
    isync

    // ---- Demo 1: tw によるトラップ ----
    lis     %r3, msg_pre@ha
    addi    %r3, %r3, msg_pre@l
    bl      print_str
    bl      print_crlf

    tw      31, %r3, %r3        // TO=31: 条件無しで常にトラップ -> IVOR6 ハンドラへ
                                // ハンドラが SRR0 += 4 するのでここに復帰する

    lis     %r3, msg_post@ha
    addi    %r3, %r3, msg_post@l
    bl      print_str
    bl      print_crlf

    // ---- Demo 2: sc (システムコール) ----
    sc                          // -> IVOR8 ハンドラへ (SRR0 は sc の次の命令)
    lis     %r3, msg_done@ha
    addi    %r3, %r3, msg_done@l
    bl      print_str
    bl      print_crlf

halt:   b       halt

// ---- Print helpers (通常コード用、s07 と同じスタイル) ----

print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r4, %r3
.Lps_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .Lps_done
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1
    b       .Lps_loop
.Lps_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

print_hex32:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 12(%r1)
    mr      %r31, %r3
    addi    %r4, %r0, 28
.Lph_loop:
    srw     %r3, %r31, %r4
    andi.   %r3, %r3, 0xF
    cmpwi   %r3, 9
    ble     .Lph_digit
    addi    %r3, %r3, 7
.Lph_digit:
    addi    %r3, %r3, 0x30
    bl      uart_putc
    addic.  %r4, %r4, -4
    bge     .Lph_loop
    lwz     %r31, 12(%r1)
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

print_crlf:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    li      %r3, 0x0A
    bl      uart_putc
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lup_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .Lup_wait
    stb     %r3, 0(%r8)
    blr

// ---- Data (通常コード用) ----
msg_pre:  .asciz "before tw trap"
msg_post: .asciz "returned from trap handler (rfi)"
msg_done: .asciz "returned from syscall handler (rfi)"

// ================================================================
// プログラム割り込みハンドラ (IVOR6) — 0x01000100 に配置
// 文字列出力は .text の print_str/print_hex32/print_crlf を bl で呼ぶ
// (bl 到達距離 ±32MB 内、LR は各ヘルパが保存復帰する)。
// ヘルパが壊すレジスタ (r3,r4,r5,r8,r9,r10,r11) は入口で退避し出口で復帰。
// 例外スタックフレームは存在しない (SRR0/SRR1 レジスタ渡し)。
// ================================================================
.section .handler, "ax"

prog_handler:
    lis     %r6, hscratch@ha
    addi    %r6, %r6, hscratch@l
    stw     %r3, 0(%r6)
    stw     %r4, 4(%r6)
    stw     %r5, 8(%r6)
    stw     %r8, 12(%r6)
    stw     %r9, 16(%r6)
    stw     %r10, 20(%r6)
    stw     %r11, 24(%r6)

    lis     %r3, msg_prog@ha
    addi    %r3, %r3, msg_prog@l
    bl      print_str
    mfspr   %r3, 26             // SRR0 = トラップした tw のアドレス
    bl      print_hex32
    lis     %r3, msg_srr1@ha
    addi    %r3, %r3, msg_srr1@l
    bl      print_str
    mfspr   %r3, 27             // SRR1 = 例外時の MSR
    bl      print_hex32
    bl      print_crlf

    // tw をスキップして復帰させる (再実行による無限ループ防止)
    mfspr   %r11, 26
    addi    %r11, %r11, 4
    mtspr   26, %r11

    lis     %r6, hscratch@ha
    addi    %r6, %r6, hscratch@l
    lwz     %r3, 0(%r6)
    lwz     %r4, 4(%r6)
    lwz     %r5, 8(%r6)
    lwz     %r8, 12(%r6)
    lwz     %r9, 16(%r6)
    lwz     %r10, 20(%r6)
    lwz     %r11, 24(%r6)
    rfi

msg_prog: .asciz "PROG INT SRR0="
msg_srr1: .asciz " SRR1="
hscratch:  .space 32

// ================================================================
// システムコールハンドラ (IVOR8) — 0x01000200 に配置
// sc の SRR0 は既に次の命令を指すためスキップ不要
// ================================================================
.section .handler2, "ax"

sys_handler:
    lis     %r6, hscratch2@ha
    addi    %r6, %r6, hscratch2@l
    stw     %r3, 0(%r6)
    stw     %r4, 4(%r6)
    stw     %r5, 8(%r6)
    stw     %r8, 12(%r6)
    stw     %r9, 16(%r6)
    stw     %r10, 20(%r6)
    stw     %r11, 24(%r6)

    lis     %r3, msg_sysc@ha
    addi    %r3, %r3, msg_sysc@l
    bl      print_str
    mfspr   %r3, 26             // SRR0 = sc の次の命令
    bl      print_hex32
    bl      print_crlf

    lis     %r6, hscratch2@ha
    addi    %r6, %r6, hscratch2@l
    lwz     %r3, 0(%r6)
    lwz     %r4, 4(%r6)
    lwz     %r5, 8(%r6)
    lwz     %r8, 12(%r6)
    lwz     %r9, 16(%r6)
    lwz     %r10, 20(%r6)
    lwz     %r11, 24(%r6)
    rfi

msg_sysc:  .asciz "SYSCALL SRR0="
hscratch2: .space 32

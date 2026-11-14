// s102_svc.s - Scenario 102: SVC & Exception Vectors (ARM64 specific)
// ================================================================================
// ARM64 特有の「例外ベクタテーブルは VBAR_EL1 が指す 16 エントリの固定構造」
// を学ぶ。
//   - VBAR_EL1: ベクタテーブルのベース (0x800 アライン)
//   - テーブルは 16 エントリ x 0x80 バイト。どのエントリに入るかは
//     (例外元 EL, SP 選択, 例外種別) の組み合わせで決まる
//     SVC 等の同期例外 (同一 EL, SP_ELx 使用) は +0x200 のエントリ
//   - ESR_EL1: 例外の詳細 (EC フィールド = 例外原因。SVC は 0x15)
//   - ELR_EL1: 復帰アドレス。SVC は「retirable」例外なので ELR は既に
//     次の命令を指す (+4 スキップは不要。実機で試すと 1 命令飛ぶ)
//   - x86 の割り込みスタック経由ではなく、ELR/ESR/SPSR のレジスタ渡し
//     (RISC-V の mepc/mcause や PPC の SRR0/SRR1 と同じ思想)
//
// 観察方法: make trace S=s102_svc で例外突入時の PC とレジスタの変化が追える。

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // ---- ベクタテーブルの設定 ----
    ldr     x0, =vectors
    msr     VBAR_EL1, x0
    isb

    // ---- SVC デモ ----
    ldr     x0, =msg_pre
    bl      print_str
    svc     #0                      // 同期例外 -> VBAR_EL1+0x200 エントリ
    ldr     x0, =msg_post
    bl      print_str

    // Exit via semihosting
    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- 例外ベクタテーブル ----
// 16 エントリ x 0x80 バイト。使用する 2 エントリ以外はループにする。
//   +0x000: current EL (SP_EL0) sync   — SPSel=0 の場合にここに入る
//   +0x200: current EL (SP_ELx) sync   — SPSel=1 の場合にここに入る
.balign 0x800
vectors:
    b       sync_handler
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       sync_handler
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors
    .balign 0x80
    b       vectors

// ---- 同期例外ハンドラ ----
sync_handler:
    stp     x0, x1, [sp, #-16]!
    stp     x2, x3, [sp, #-16]!
    mrs     x2, ESR_EL1
    lsr     w2, w2, #26             // EC フィールド (bits 31:26)。SVC = 0x15
    ldr     x0, =msg_ec
    bl      print_str
    mov     w0, w2
    bl      print_hex4
    mrs     x2, ELR_EL1
    ldr     x0, =msg_elr
    bl      print_str
    mov     w0, w2                  // 下位 32 ビットのみ表示 (0x4000xxxx)
    bl      print_hex32
    ldr     x0, =nl
    bl      print_str
    // SVC の ELR は既に次の命令を指すため、ELR の更新は不要
    ldp     x2, x3, [sp], #16
    ldp     x0, x1, [sp], #16
    eret

// ---- Print helpers ----

print_str:
    stp     x29, x30, [sp, #-16]!
    mov     x4, x0
.ps_loop:
    ldrb    w5, [x4]
    cbz     w5, .ps_done
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       .ps_loop
.ps_done:
    ldp     x29, x30, [sp], #16
    ret

// print_hex4: print low 16 bits of w0 as 4 uppercase hex digits
print_hex4:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     w19, w0
    mov     w5, #12
.ph4_loop:
    lsr     w6, w19, w5
    and     w6, w6, #0xf
    cmp     w6, #9
    b.ls    .ph4_digit
    add     w6, w6, #7
.ph4_digit:
    add     w0, w6, #'0'
    bl      uart_putc
    subs    w5, w5, #4
    b.ge    .ph4_loop
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// print_hex32: print low 32 bits of w0 as 8 uppercase hex digits
print_hex32:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     w19, w0
    mov     w5, #28
.ph32_loop:
    lsr     w6, w19, w5
    and     w6, w6, #0xf
    cmp     w6, #9
    b.ls    .ph32_digit
    add     w6, w6, #7
.ph32_digit:
    add     w0, w6, #'0'
    bl      uart_putc
    subs    w5, w5, #4
    b.ge    .ph32_loop
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

uart_putc:
    movz    x8, #0x0900, lsl #16
.up_wait:
    ldr     w9, [x8, #0x18]
    tbnz    w9, #5, .up_wait
    strb    w0, [x8]
    ret

// ---- Data ----
msg_pre:  .asciz "before svc\n"
msg_ec:   .asciz "SVC caught EC=0x"
msg_elr:  .asciz " ELR=0x"
msg_post: .asciz "returned from exception handler (eret)\n"
nl:       .asciz "\n"

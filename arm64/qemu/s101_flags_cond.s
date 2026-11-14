// s101_flags_cond.s - Scenario 101: NZCV & Conditional Instructions (ARM64 specific)
// ================================================================================
// ARM64 特有の「フラグを set する命令と、フラグを消費する命令が独立している」
// 設計を学ぶ。
//   - NZCV フラグ: N (negative) / Z (zero) / C (carry) / V (overflow)
//   - CMP/SUBS/ADDS のみがフラグを set する (x86 とは異なり多くの命令が set しない)
//   - CSEL/CSET/CINC/CNEG: フラグを消費して「分岐せず値を選ぶ」条件実行
//   - MRS NZCV でフラグそのものを読み取れる (x86 には相当命令がない)
//   - LDP/STP: レジスタペアの 1 命令ロード/ストア
//
// 他アーキとの対比:
//   - x86/Z80: 多くの算術命令が FLAGS を set し、条件分岐 (Jcc) で消費
//   - PPC: 比較対象の CR フィールドを 8 個持つ
//   - ARM64: NZCV 1 個 + フラグ消費命令のバリエーション (csel 系) が豊富

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // ---- Demo 1: CSEL — 分岐せずに 2 値から選択 ----
    ldr     x0, =msg_d1
    bl      print_str
    mov     x1, #7
    mov     x2, #3
    cmp     x1, x2
    csel    x3, x1, x2, gt          // 7 > 3 なので x3 = x1 = 7 (max)
    mov     x0, x3
    bl      print_uint
    ldr     x0, =nl
    bl      print_str

    // ---- Demo 2: CSET — 条件を 0/1 に変換 ----
    ldr     x0, =msg_d2
    bl      print_str
    mov     x1, #5
    mov     x2, #5
    cmp     x1, x2
    cset    x3, eq                  // 5 == 5 なので x3 = 1
    mov     x0, x3
    bl      print_uint
    ldr     x0, =nl
    bl      print_str

    // ---- Demo 3: CINC — 条件成立時のみ +1 ----
    ldr     x0, =msg_d3
    bl      print_str
    mov     x3, #40
    mov     x1, #2
    mov     x2, #5
    cmp     x1, x2
    cinc    x3, x3, lt              // 2 < 5 なので x3 = 40 + 1
    mov     x0, x3
    bl      print_uint
    ldr     x0, =nl
    bl      print_str

    // ---- Demo 4: NZCV の直接読み取り ----
    // subs で N/Z/C/V が変化する様子を MRS で観察する
    ldr     x0, =msg_d4
    bl      print_str
    mov     w1, #1
    subs    w2, w1, #2              // 1 - 2: N=1 (負), C=0 (borrow), V=0, Z=0
    mrs     x3, NZCV
    mov     w0, w3
    bl      print_hex32             // 0x80000000
    ldr     x0, =nl
    bl      print_str

    ldr     x0, =msg_d4b
    bl      print_str
    mov     w1, #0x80000000
    adds    w2, w1, w1              // 0x80000000 + 0x80000000: Z=1 (結果 0), C=1, V=1
    mrs     x3, NZCV
    mov     w0, w3
    bl      print_hex32             // 0x70000000
    ldr     x0, =nl
    bl      print_str

    // ---- Demo 5: LDP/STP — ペアロード/ストア ----
    ldr     x0, =msg_d5
    bl      print_str
    mov     x1, #11
    mov     x2, #22
    ldr     x3, =pair
    stp     x1, x2, [x3]            // 2 レジスタを 1 命令でストア
    ldr     x4, =pair
    ldp     x5, x6, [x4]            // 2 レジスタを 1 命令でロード
    add     x0, x5, x6              // 11 + 22 = 33
    bl      print_uint
    ldr     x0, =nl
    bl      print_str

    // Exit via semihosting
    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Print helpers (s05 と同じスタイル) ----

// print_uint: print x0 as decimal (0-99)
print_uint:
    stp     x29, x30, [sp, #-16]!
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0
    cmp     x19, #10
    b.lt    .pu_ones
    mov     x20, #10
    udiv    x3, x19, x20
    add     w0, w3, #'0'
    bl      uart_putc
    msub    x19, x3, x20, x19
.pu_ones:
    add     w0, w19, #'0'
    bl      uart_putc
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

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
msg_d1:  .asciz "csel max(7,3)   = "
msg_d2:  .asciz "cset eq(5,5)    = "
msg_d3:  .asciz "cinc lt(2,5)    = "
msg_d4:  .asciz "NZCV 1-2        = "
msg_d4b: .asciz "NZCV 80000000+ = "
msg_d5:  .asciz "ldp/stp 11+22   = "
nl:      .asciz "\n"
.section .bss
pair:    .space 16

// s101_cr_lr.s - Scenario 101: Condition Register & Branch Control (PPC-specific)
// ================================================================================
// PowerPC 特有の「命令は固定で、状態は CR とリンクレジスタに分離する」設計を学ぶ。
//   - CR (Condition Register): 8 フィールド (CR0-CR7)、各フィールドは LT/GT/EQ/SO
//   - 比較命令の対象フィールドを指定できる (cmpwi cr1, ...)
//   - CR 論理命令 (crand/cror/crxor) で複数フィールドの条件をビット単位で合成
//   - mfcr/mtcrf で CR を GPR に読み書き (マルチタスクのコンテキスト保存)
//   - bdnz はカウンタ分岐 (CTR) — LR を壊さずにループできる
//   - BO/BI で分岐条件をビットで直接指定できる (bc)
//
// 他アーキとの対比:
//   - x86/Z80: フラグレジスタは 1 つで、比較は常に同じ FLAGS を更新
//   - ARM64: 条件コードは NZCV 1 つ + 条件実行 (csel)
//   - PPC: 8 フィールドの CR + 分岐時の BO/BI ビット指定という「分離設計」

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // ---- Demo 1: CR0 での比較と分岐 ----
    // cmpwi は暗黙で CR0 を更新する (LT/GT/EQ/SO)
    lis     %r3, msg_d1@ha
    addi    %r3, %r3, msg_d1@l
    bl      print_str
    li      %r3, 42
    cmpwi   %r3, 42
    lis     %r3, msg_eq@ha
    addi    %r3, %r3, msg_eq@l
    beq     .Ld1        // CR0.EQ が立つ -> 42 == 42
    lis     %r3, msg_ng@ha
    addi    %r3, %r3, msg_ng@l
.Ld1:
    bl      print_str
    bl      print_crlf

    // ---- Demo 2: CR フィールド指定の比較 ----
    // 同じレジスタを CR0 と CR1 で別々に比較できる (x86 には不可能な操作)
    lis     %r3, msg_d2@ha
    addi    %r3, %r3, msg_d2@l
    bl      print_str
    li      %r3, 42
    cmpwi   %r3, 42     // CR0: 42 == 42 -> EQ
    cmpwi   cr1, %r3, 99 // CR1: 42 < 99 -> LT
    blt     cr1, .Ld2_lt
    lis     %r3, msg_ng@ha
    addi    %r3, %r3, msg_ng@l
    b       .Ld2
.Ld2_lt:
    lis     %r3, msg_lt1@ha
    addi    %r3, %r3, msg_lt1@l
.Ld2:
    bl      print_str
    // CR0.EQ は無傷で残っている (cmpwi cr1 は CR0 を壊さない)
    lis     %r3, msg_keep@ha
    addi    %r3, %r3, msg_keep@l
    beq     .Ld2_ok
    lis     %r3, msg_ng@ha
    addi    %r3, %r3, msg_ng@l
.Ld2_ok:
    bl      print_str
    bl      print_crlf

    // ---- Demo 3: CR 論理命令で条件を合成 ----
    // CR のビット番号: CR0=bits 0-3, CR1=bits 4-7 (LT,G T,EQ,SO の順)
    //   CR0.EQ = bit 2, CR1.EQ = bit 6
    // cror 2,2,6: CR0.EQ = CR0.EQ | CR1.EQ
    lis     %r3, msg_d3@ha
    addi    %r3, %r3, msg_d3@l
    bl      print_str
    li      %r3, 7
    cmpwi   %r3, 42     // CR0.EQ = 0 (7 != 42)
    cmpwi   cr1, %r3, 7 // CR1.EQ = 1 (7 == 7)
    cror    2, 2, 6     // CR0.EQ |= CR1.EQ -> 1
    lis     %r3, msg_or@ha
    addi    %r3, %r3, msg_or@l
    beq     .Ld3
    lis     %r3, msg_ng@ha
    addi    %r3, %r3, msg_ng@l
.Ld3:
    bl      print_str
    bl      print_crlf

    // ---- Demo 4: mfcr で CR 全体を読み取り ----
    // CR 全 32 ビット (8 フィールド x LT/GT/EQ/SO) を GPR に取得
    lis     %r3, msg_d4@ha
    addi    %r3, %r3, msg_d4@l
    bl      print_str
    li      %r3, 42
    cmpwi   %r3, 42     // CR0 = 0b0010 (EQ)
    cmpwi   cr1, %r3, 99 // CR1 = 0b1000 (LT)
    mfcr    %r5
    mr      %r3, %r5
    bl      print_hex32
    bl      print_crlf  // CR0=EQ(0b0010), CR1=LT(0b1000) -> 0x28000000

    // ---- Demo 5: mtcrf で CR を書き込み ----
    // CRM マスクでフィールド単位に GPR のビットを CR へ転送
    lis     %r3, msg_d5@ha
    addi    %r3, %r3, msg_d5@l
    bl      print_str
    lis     %r3, 0x4000     // bits 0-3 = 0b0100 (bit1 = GT)
    mtcrf   0x80, %r3       // CRM は MSB 側が CR0 (0x80 = CR0)。CR0 は rS bits 0-3 から
    lis     %r3, msg_gt@ha
    addi    %r3, %r3, msg_gt@l
    bgt     .Ld5            // CR0.GT が立った -> 42 > ? ではなく「CR が GT なら」
    lis     %r3, msg_ng@ha
    addi    %r3, %r3, msg_ng@l
.Ld5:
    bl      print_str
    bl      print_crlf

    // ---- Demo 6: bdnz — LR を壊さないカウンタループ ----
    // bl でサブルーチンに入ると LR は上書きされるが、bdnz は CTR を減らすだけ。
    // ループ中に bl でサブルーチンを呼んでも LR が保存される。
    lis     %r3, msg_d6@ha
    addi    %r3, %r3, msg_d6@l
    bl      print_str
    li      %r3, 3
    mtctr   %r3
    li      %r30, 0        // 合計
.Ld6_loop:
    bl      ten            // ループ内で bl を使う (LR 上書き) でも bdnz は無事
    bdnz    .Ld6_loop
    mr      %r3, %r30
    bl      print_hex32
    bl      print_crlf     // ten() を 3 回 -> 30

halt:   b       halt

// ten: r30 += 10 (leaf function — LR は使わないので bl で安全に呼べる)
ten:
    addi    %r30, %r30, 10
    blr

// ---- Print helpers ----

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

// ---- Data ----
msg_d1:   .asciz "Demo1 CR0 compare: "
msg_d2:   .asciz "Demo2 CR1 compare: "
msg_d3:   .asciz "Demo3 CR logical:  "
msg_d4:   .asciz "Demo4 mfcr:        "
msg_d5:   .asciz "Demo5 mtcrf:       "
msg_d6:   .asciz "Demo6 bdnz+bl:     "
msg_eq:   .asciz "EQ branch taken (42==42)"
msg_lt1:  .asciz "CR1 LT taken (42<99), CR0.EQ kept -> "
msg_keep: .asciz "EQ still set"
msg_or:   .asciz "CR0.EQ |= CR1.EQ -> EQ branch taken"
msg_gt:   .asciz "GT branch taken (CR0 <- 0b0100 via mtcrf)"
msg_ng:   .asciz "FAIL"

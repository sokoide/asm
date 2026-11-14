// s13_copybench.s - Scenario 13: Copy Benchmark (Common Exercise)
// ================================================================
// 共通課題: 100 バイトのメモリコピーとチェックサム検証 (compare/copybench.md 参照)
//
//   - Source: 100 bytes where byte i = i (0..99)
//   - Copy src -> dst byte by byte (LBU/SB loop)
//   - Sum the 100 destination bytes (16-bit)
//   - Expected checksum: 0+1+...+99 = 4950 = 0x1356
//
// RISC-V にはブロック転送命令が無く、ロード/ストアと分岐の素朴な組み合わせに
// なる。これが RISC 流の「同じ簡単な命令の繰り返し」である点が Z80 LDIR /
// x86 REP MOVSB との対比になる。

.section .text
.global _start

_start:
    li      sp, 0x80200000

    // ---- Copy 100 bytes src -> dst ----
    la      s0, src
    la      s1, dst
    li      t2, 100
.cp_loop:
    lbu     t0, 0(s0)
    sb      t0, 0(s1)
    addi    s0, s0, 1
    addi    s1, s1, 1
    addi    t2, t2, -1
    bnez    t2, .cp_loop

    // ---- Sum destination bytes (16-bit) ----
    la      s0, dst
    li      t2, 100
    li      s2, 0
.sum_loop:
    lbu     t0, 0(s0)
    add     s2, s2, t0
    addi    s0, s0, 1
    addi    t2, t2, -1
    bnez    t2, .sum_loop

    // ---- Report: COPY OK|FAIL CHECKSUM=xxxx ----
    la      a0, msg_ok
    li      t0, 4950
    beq     s2, t0, .report
    la      a0, msg_fail
.report:
    jal     ra, print_str
    mv      a0, s2
    jal     ra, print_hex4
    la      a0, newline
    jal     ra, print_str

    // Exit via SiFive test finisher
    // (終了は非同期で処理されるため、直後のコードに落ちないよう無限ループで受ける)
    li      t0, 0x100000
    li      t1, 0x5555
    sw      t1, 0(t0)
.done_wait:
    j       .done_wait

// ---- Print helpers ----

print_str:
    addi    sp, sp, -16
    sw      ra, 8(sp)
    sw      s0, 0(sp)
    mv      s0, a0
.ps_loop:
    lbu     t1, 0(s0)
    beqz    t1, .ps_ret
    mv      a0, t1
    jal     ra, uart_putc
    addi    s0, s0, 1
    j       .ps_loop
.ps_ret:
    lw      s0, 0(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 16
    ret

// print_hex4: print low 16 bits of a0 as 4 uppercase hex digits
print_hex4:
    addi    sp, sp, -32
    sw      ra, 24(sp)
    sw      s3, 16(sp)
    sw      s4, 8(sp)
    mv      s3, a0
    li      s4, 12
.ph_loop:
    srl     t1, s3, s4
    andi    a0, t1, 15
    li      t3, 10
    bltu    a0, t3, .ph_digit
    addi    a0, a0, 7
.ph_digit:
    addi    a0, a0, 48
    jal     ra, uart_putc
    addi    s4, s4, -4
    bgez    s4, .ph_loop
    lw      s4, 8(sp)
    lw      s3, 16(sp)
    lw      ra, 24(sp)
    addi    sp, sp, 32
    ret

uart_putc:
    li      t0, 0x10000000
.wait:
    lbu     t1, 5(t0)
    andi    t1, t1, 0x20
    beqz    t1, .wait
    sb      a0, 0(t0)
    ret

// ---- Data ----
src:    .byte 0,1,2,3,4,5,6,7,8,9
        .byte 10,11,12,13,14,15,16,17,18,19
        .byte 20,21,22,23,24,25,26,27,28,29
        .byte 30,31,32,33,34,35,36,37,38,39
        .byte 40,41,42,43,44,45,46,47,48,49
        .byte 50,51,52,53,54,55,56,57,58,59
        .byte 60,61,62,63,64,65,66,67,68,69
        .byte 70,71,72,73,74,75,76,77,78,79
        .byte 80,81,82,83,84,85,86,87,88,89
        .byte 90,91,92,93,94,95,96,97,98,99
dst:    .space 100
msg_ok:   .asciz "COPY OK CHECKSUM="
msg_fail: .asciz "COPY FAIL CHECKSUM="
newline:  .asciz "\n"

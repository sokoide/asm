// s13_copybench.s - Scenario 13: Copy Benchmark (Common Exercise)
// ================================================================
// 共通課題: 100 バイトのメモリコピーとチェックサム検証 (docs/copybench.md 参照)
//
//   - Source: 100 bytes where byte i = i (0..99)
//   - Copy src -> dst byte by byte (LBZ/STB loop with CTR)
//   - Sum the 100 destination bytes (16-bit)
//   - Expected checksum: 0+1+...+99 = 4950 = 0x1356
//
// PPC にはブロック転送命令が無く、ロード/ストアとカウンタ分岐 (bdnz) の
// 素朴な組み合わせになる。これが RISC (PowerPC) 流の「同じ簡単な命令の
// 繰り返し」である点が Z80 LDIR / x86 REP MOVSB との対比になる。

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // ---- Copy 100 bytes src -> dst ----
    lis     %r6, src@ha
    addi    %r6, %r6, src@l
    lis     %r7, dst@ha
    addi    %r7, %r7, dst@l
    li      %r3, 100
    mtctr   %r3
.Lcopy:
    lbz     %r8, 0(%r6)
    stb     %r8, 0(%r7)
    addi    %r6, %r6, 1
    addi    %r7, %r7, 1
    bdnz    .Lcopy

    // ---- Sum destination bytes (16-bit) ----
    lis     %r6, dst@ha
    addi    %r6, %r6, dst@l
    li      %r31, 0
    li      %r3, 100
    mtctr   %r3
.Lsum:
    lbz     %r8, 0(%r6)
    add     %r31, %r31, %r8
    addi    %r6, %r6, 1
    bdnz    .Lsum

    // ---- Report: COPY OK             | FAIL CHECKSUM=xxxx ----
    lis     %r3, msg_ok@ha
    addi    %r3, %r3, msg_ok@l
    cmpwi   %r31, 4950
    beq     .Lreport
    lis     %r3, msg_fail@ha
    addi    %r3, %r3, msg_fail@l
.Lreport:
    bl      print_str
    mr      %r3, %r31
    bl      print_hex16
    bl      print_crlf

halt:   b       halt

// ---- Print helpers (same style as s07_subroutines) ----

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

// print_hex16: print low 16 bits of r3 as 4 uppercase hex digits
print_hex16:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 12(%r1)
    mr      %r31, %r3
    addi    %r4, %r0, 12
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

// s13_copybench.s - Scenario 13: Copy Benchmark (Common Exercise)
// ================================================================
// 共通課題: 100 バイトのメモリコピーとチェックサム検証 (compare/copybench.md 参照)
//
//   - Source: 100 bytes where byte i = i (0..99)
//   - Copy src -> dst byte by byte (LDRB/STRB loop with writeback)
//   - Sum the 100 destination bytes (16-bit)
//   - Expected checksum: 0+1+...+99 = 4950 = 0x1356
//
// ARM64 にはブロック転送命令が無く、ロード/ストアと分岐の素朴な組み合わせに
// なる。これが RISC 流の「同じ簡単な命令の繰り返し」である点が Z80 LDIR /
// x86 REP MOVSB との対比になる。ポインタの post-index writeback
// (LDRB w, [x], #1) でインクリメントがロードに統合される点が特徴。

.section .text
.global _start

_start:
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // ---- Copy 100 bytes src -> dst ----
    ldr     x0, =src
    ldr     x1, =dst
    mov     w2, #100
.cb_loop:
    ldrb    w3, [x0], #1
    strb    w3, [x1], #1
    subs    w2, w2, #1
    b.ne    .cb_loop

    // ---- Sum destination bytes (16-bit) ----
    ldr     x0, =dst
    mov     w2, #100
    mov     w3, wzr
.sum_loop:
    ldrb    w4, [x0], #1
    add     w3, w3, w4
    subs    w2, w2, #1
    b.ne    .sum_loop

    // ---- Report: COPY OK             | FAIL CHECKSUM=xxxx ----
    ldr     x0, =msg_ok
    mov     w4, #4950
    cmp     w3, w4
    b.eq    .report
    ldr     x0, =msg_fail
.report:
    bl      print_str
    mov     w0, w3
    bl      print_hex4
    ldr     x0, =nl
    bl      print_str

    // Exit via semihosting (SYS_EXIT, ADP_Stopped_ApplicationExit)
    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Print helpers ----

// print_str: x0 = string pointer
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

uart_putc:
    movz    x8, #0x0900, lsl #16
.up_wait:
    ldr     w9, [x8, #0x18]     // PL011 FR: bit 5 = TXFF
    tbnz    w9, #5, .up_wait
    strb    w0, [x8]
    ret

// ---- Data ----
msg_ok:   .asciz "COPY OK CHECKSUM="
msg_fail: .asciz "COPY FAIL CHECKSUM="
nl:       .asciz "\n"
src:      .byte 0,1,2,3,4,5,6,7,8,9
          .byte 10,11,12,13,14,15,16,17,18,19
          .byte 20,21,22,23,24,25,26,27,28,29
          .byte 30,31,32,33,34,35,36,37,38,39
          .byte 40,41,42,43,44,45,46,47,48,49
          .byte 50,51,52,53,54,55,56,57,58,59
          .byte 60,61,62,63,64,65,66,67,68,69
          .byte 70,71,72,73,74,75,76,77,78,79
          .byte 80,81,82,83,84,85,86,87,88,89
          .byte 90,91,92,93,94,95,96,97,98,99
.section .bss
dst:      .space 100

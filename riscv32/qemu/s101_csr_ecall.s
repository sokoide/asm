// s101_csr_ecall.s - Scenario 101: CSR & ECALL (RISC-V specific)
// ================================================================
// RISC-V 特有の「制御はすべて CSR とトラップ機構に集約される」設計を学ぶ。
//   - CSRR/CSRW: 制御・状態レジスタ (CSR) の読み書き (M-mode)
//   - CSRRS/CSRRC: ビット単位の set/clear (アトミックな read-modify-write)
//   - ECALL: 環境呼び出し。M-mode から発行すると mcause = 11 (machine ecall)
//     で mtvec 先のハンドラにトラップする (x86 INT / PPC sc / ARM SVC に相当)
//   - MRET: mepc に復帰するトラップリターン
//
// 他アーキとの対比:
//   - x86: 割り込みベクタテーブルはメモリ上にあり IDT/IVT 経由
//   - PPC: IVPR + IVOR でベクタを合成、状態は SRR0/SRR1
//   - RISC-V: mtvec 1 本 + mcause/mepc/mstatus の CSR 群。モードは M/S/U の
//     3 段階で、例外発生時のモード遷移も mstatus に記録される

.section .text
.global _start

_start:
	li      sp, 0x80200000

    // ---- トラップハンドラの設定 (mtvec, direct mode) ----
	la      t0, trap_handler
	csrw    mtvec, t0

    // ---- Demo 1: misa — 実装している ISA 拡張のビットマップ ----
    // bit 8 = I (integer), bit 12 = M (mul/div), bit 26/62 = U/S など
	la      a0, msg_misa
	jal     ra, print_str
	csrr    a0, misa
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- Demo 2: mhartid — ハート ID ----
	la      a0, msg_hart
	jal     ra, print_str
	csrr    a0, mhartid
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- Demo 3: mstatus の MIE ビットを CSRRC/CSRW で操作 ----
    // csrrc は「クリアしつつ旧値を読む」アトミック操作
	la      a0, msg_mstatus
	jal     ra, print_str
	csrr    a0, mstatus
	jal     ra, print_hex32
	la      a0, msg_arrow
	jal     ra, print_str
	li      t1, 8               // bit 3 = MIE (machine interrupt enable)
	csrrc   t0, mstatus, t1     // MIE をクリア (旧 mstatus は t0 に残る)
	addi    sp, sp, -16
	sw      t0, 0(sp)           // print_hex32 が t0 を壊すため退避
	csrr    a0, mstatus
	jal     ra, print_hex32
	la      a0, msg_arrow
	jal     ra, print_str
	lw      t0, 0(sp)
	addi    sp, sp, 16
	csrw    mstatus, t0         // 元に戻す
	csrr    a0, mstatus
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- Demo 4: ECALL — M-mode から環境呼び出し ----
    // ecall で mcause=11 で trap_handler へトラップし、mepc+4 して mret で復帰
	la      a0, msg_before
	jal     ra, print_str
	ecall
	la      a0, msg_after
	jal     ra, print_str

    // Exit via SiFive test finisher
    // (終了は非同期で処理されるため、直後のコードに落ちないよう無限ループで受ける)
	li      t0, 0x100000
	li      t1, 0x5555
	sw      t1, 0(t0)
.done_wait:
	j       .done_wait

// ---- トラップハンドラ (mtvec 先) ----
// ecall の mcause = 11 (machine ecall)、mepc = ecall 命令のアドレス
trap_handler:
	addi    sp, sp, -32
	sw      ra, 0(sp)
	sw      a0, 8(sp)
	sw      t0, 16(sp)
	sw      t1, 24(sp)
	la      a0, msg_trap
	jal     ra, print_str
	csrr    a0, mcause
	jal     ra, print_hex32
	la      a0, msg_epc
	jal     ra, print_str
	csrr    a0, mepc
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str
	csrr    t0, mepc
	addi    t0, t0, 4           // ecall をスキップして復帰
	csrw    mepc, t0
	lw      t1, 24(sp)
	lw      t0, 16(sp)
	lw      a0, 8(sp)
	lw      ra, 0(sp)
	addi    sp, sp, 32
    mret

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

// print_hex32: print low 32 bits of a0 as 8 uppercase hex digits
print_hex32:
	addi    sp, sp, -32
	sw      ra, 24(sp)
	sw      s3, 16(sp)
	sw      s4, 8(sp)
	mv      s3, a0
	li      s4, 28
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
msg_misa:   .asciz "misa   = 0x"
msg_hart:   .asciz "mhartid= 0x"
msg_mstatus: .asciz "mstatus= 0x"
msg_arrow:  .asciz " -> 0x"
msg_before: .asciz "before ecall\n"
msg_after:  .asciz "returned from trap handler (mret)\n"
msg_trap:   .asciz "ECALL mcause=0x"
msg_epc:    .asciz " mepc=0x"
newline:    .asciz "\n"

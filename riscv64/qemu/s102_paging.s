// s102_paging.s - Scenario 102: S-mode Paging (Sv39)
// ================================================================
// RISC-V 特権アーキテクチャの中核「S-mode 仮想記憶」を学ぶ。
//   - M-mode での初期化: PMP (Physical Memory Protection) を設定しないと、
//     QEMU virt はリセット後 PMP エントリが空で、S-mode からの全アクセスが
//     PMP で拒否される。mret で降下する前に全メモリ+MMIO を NAPOT で許可する
//   - medeleg: ページフォールト (exception 12/13/15) を S-mode に委譲する。
//     委譲しないと M-mode の mtvec に飛んでしまう (interrupts は mideleg だが
//     ページフォールトは例外なので medeleg だけで十分。本シナリオでは割込を
//     使わないため mideleg は設定しない)
//   - Sv39: 39-bit VA / 3 段ページテーブル (4KB ページ)。satp.MODE=8 で有効化。
//     本シナリオでは root テーブル (L2) に直接 leaf PTE を置く leaf-at-level-2
//     (1GB メガページ) で identity map する — 3 段目のテーブルを省略できる。
//     Sv32 (rv32 版, 2 段 + 4MB メガページ + 4KB leaf) との違いはコメント参照。
//     PTE フィールド (V/R/W/X/A/D + PPN) が読み取れる構成にする
//   - sfence.vma: satp 書き換え後の TLB 同期 (RISC-V は古い変換をソフトが無効化)
//   - ページフォールト実演: 未マップ VA への load (scause=13) / store
//     (scause=15)。stvec ハンドラで scause/stval (フォールトアドレス) を表示し、
//     sepc += 4 でフォールト命令をスキップして sret で継続する
//
// Sv32 (rv32) との違い:
//   - satp.MODE: 1 (Sv32) vs 8 (Sv39)、satp は 64-bit (MODE は bits 63:60)
//   - 段数: 2 段 (VA[31:22]/[21:12]) vs 3 段 (VA[38:30]/[29:21]/[20:12])
//   - メガページ: 4MB (L1 leaf) vs 1GB (L2 leaf)。1GB leaf の PPN は
//     0x80000000>>12 = 0x80000 (下位 18 ビット 0 = 1GB アライメントの証)
//   - PTE は 64-bit: PPN[2]/PPN[1]/PPN[0] = PA[55:30]/[29:21]/[20:12]
//
// 他アーキとの対比:
//   - x86: CR3 + 4 段 (x86-64)。ページング有効化は CR0.PG
//   - ARM: TTBR0/TTBR1 + TCR_EL1。例外は VBAR 経由
//   - RISC-V: satp 1 本 (MODE                                    | ASID|PPN) + stvec 1 本。ページテーブル形式は
//     satp.MODE で選択 (rv32 は Sv32 のみ / rv64 は Sv39/Sv48/Sv57)
//
// 実行の流れ: M-mode (PMP/medeleg/mstatus.MPP) --mret--> S-mode (ページテーブル
// 構築 → satp → sfence.vma) → identity アクセス確認 → ページフォールト 2 回
// (load/store) → sret 復帰 → SiFive test で終了

.section .text
.global _start

// ============ M-mode ============

_start:
	li      sp, 0x80200000

    // ---- M-mode トラップの安全網 (悪性トラップ検出用) ----
	la      t0, m_trap_handler
	csrw    mtvec, t0

    // ---- PMP: 物理アドレス空間を 2 つの 2GB NAPOT エントリで許可 ----
    // QEMU virt は PMP エントリなしでリセットされ、S-mode からのアクセス
    // (mret の戻り先 fetch チェックも含む) が PMP で拒否される。 virt の
    // メモリマップに合わせて 2 つの NAPOT エントリで全空間を許可する:
    //   entry0: pmpaddr0 = 0x0fffffff, pmpcfg0[7:0]   = 0x0f (R  | W|X|A=NAPOT)
    //           → 0x00000000-0x7fffffff (MMIO: test/CLINT/PLIC/UART/flash/PCI)
    //   entry1: pmpaddr1 = 0x2fffffff, pmpcfg0[15:8]  = 0x0f
    //           → 0x80000000-0xbfffffff (DRAM)
    // NAPOT では pmpaddr の下位 n+1 ビットの 1 連鎖がサイズ 2^(n+3) バイトを
    // 意味する。rv64 は PA 空間が広いので 4GB NAPOT も可能だが、rv32 版との
    // 統一のため同じ 2 エントリ構成にする
	li      t0, 0x0fffffff
	csrw    pmpaddr0, t0
	li      t0, 0x2fffffff
	csrw    pmpaddr1, t0
	li      t0, 0x0f0f
	csrw    pmpcfg0, t0
	la      a0, msg_pmp
	jal     ra, print_str
	csrr    a0, pmpcfg0
	jal     ra, print_hex32
	la      a0, msg_close
	jal     ra, print_str

    // ---- medeleg: ページフォールトを S-mode へ委譲 ----
    // bit 12 = instruction page fault, bit 13 = load page fault,
    // bit 15 = store/AMO page fault。WARL のため書いて読み戻して確認する
	li      t0, (1 << 12)                                         | (1 << 13) | (1 << 15)
	csrw    medeleg, t0
	la      a0, msg_medeleg
	jal     ra, print_str
	li      t0, (1 << 12)                                         | (1 << 13) | (1 << 15)
	mv      a0, t0
	jal     ra, print_hex32
	la      a0, msg_arrow
	jal     ra, print_str
	csrr    a0, medeleg
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- mstatus.MPP = S (bits 12:11 = 01) ----
    // mret は MPP で指定された特権レベルに復帰する。SPP (bit 8) ではなく
    // MPP が mret の遷移先を決める点に注意
	li      t0, (1 << 11)
    csrs    mstatus, t0            // bit 11 = 1
	li      t0, (1 << 12)
    csrc    mstatus, t0            // bit 12 = 0  (MPP = 01 = S-mode)
	la      a0, msg_mstatus
	jal     ra, print_str
	csrr    a0, mstatus
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- mepc = S-mode エントリ, mret で降下 ----
	la      a0, msg_drop
	jal     ra, print_str
	la      t0, s_main
	csrw    mepc, t0
    mret

// ============ S-mode ============

s_main:
	li      sp, 0x80200000
	la      t0, s_trap_handler
	csrw    stvec, t0

    // ---- ページテーブル構築 (Sv39: 3 段, 4KB ページサイズ) ----
    // VA[38:30] = VPN2 (root, 1GB/entry), VA[29:21] = VPN1, VA[20:12] = VPN0
    // 本シナリオでは root テーブルに直接 leaf PTE を置く leaf-at-level-2:
    //   root[0] = 1GB メガページ leaf @ 0x00000000
    //     — SiFive test 0x100000 / UART 0x10000000 / CLINT / PLIC / flash / PCI
    //   root[2] = 1GB メガページ leaf @ 0x80000000
    //     — コード・データ・スタック sp=0x80200000 (DRAM)
    //   未マップ VA (root[1] = 0) がページフォールト実演の対象
    // (通常の 3 段変換は root[VPN2] に V のみのポインタ PTE を置き、
    //  L1/L2 テーブルを追加する。L2 leaf = 4KB ページ)
	la      t0, root_pt
	li      t1, 4096
	add     t0, t0, t1             // 終端から逆順に 0 クリア (512 entries)
	li      t1, 512
.zero_root:
	addi    t0, t0, -8
	sd      zero, 0(t0)
	addi    t1, t1, -1
	bnez    t1, .zero_root

    // root[0] = PPN 0 << 10                                      | 0xCF  (V|R|W|X|A|D, 1GB-aligned leaf)
	li      t1, 0xCF
	la      t0, root_pt
	sd      t1, 0(t0)
    // root[2] = PPN 0x80000 << 10                                | 0xCF
    //   (PPN = 0x80000000/4096 = 0x80000, 下位 18 ビット 0 = 1GB アライメント)
	li      t1, 0x80000
	slli    t1, t1, 10
	ori     t1, t1, 0xCF
	sd      t1, 16(t0)             // entry 2 * 8 bytes = offset 16

    // サンプル PTE 表示: root[2] = 0x200000CF
    //   (PPN=0x80000, V                                          | R|W|X|A|D — 1GB leaf, 0x80000000 を指す)
	la      a0, msg_pte
	jal     ra, print_str
	la      t0, root_pt
	lw      a0, 16(t0)             // PTE は 64-bit だが下位 32-bit に全情報あり
	jal     ra, print_hex32
	la      a0, newline
	jal     ra, print_str

    // ---- satp 設定: MODE=8 (Sv39, bits 63:60)                  | PPN(root_pt>>12) ----
	la      t0, root_pt
	srli    t0, t0, 12
	li      t1, 8
	slli    t1, t1, 60             // MODE 8 = Sv39
	or      t0, t0, t1
	csrw    satp, t0
    sfence.vma                  // TLB 同期 (satp 変更直後は必須)
	la      a0, msg_satp
	jal     ra, print_str
	csrr    a0, satp
	jal     ra, print_hex64        // satp は 64-bit (MODE が bits 63:60)
	la      a0, newline
	jal     ra, print_str

    // ---- identity map 下で通常アクセスを確認 ----
	la      a0, msg_mapped
	jal     ra, print_str
	li      t0, 0x1234
	la      t1, scratch
	sd      t0, 0(t1)              // MMU 経由のストア
	ld      a0, 0(t1)              // MMU 経由のロード
	jal     ra, print_hex64
	la      a0, msg_ok
	jal     ra, print_str

    // ---- ページフォールト実演 1: 未マップ VA への load ----
    // VA 0x40000000 は root[1] = 0 (V=0) で load page fault
    // scause=13 (0xD), stval=0x40000000 → stvec ハンドラで表示し sepc+=4
	la      a0, msg_load_fault
	jal     ra, print_str
	li      t0, 0x40000000
	ld      t1, 0(t0)
	la      a0, msg_recovered
	jal     ra, print_str

    // ---- ページフォールト実演 2: 未マップ VA への store ----
    // store page fault: scause=15 (0xF), stval=0x40000000
	li      t0, 0x40000000
	li      t1, 0x55
	sd      t1, 0(t0)
	la      a0, msg_store_ok
	jal     ra, print_str

    // Exit via SiFive test finisher
    // (終了は非同期で処理されるため、直後のコードに落ちないよう無限ループで受ける)
	li      t0, 0x100000
	li      t1, 0x5555
	sw      t1, 0(t0)
.done_wait:
	j       .done_wait

// ---- M-mode トラップハンドラ (悪性トラップ検出用) ----
// 正常動作ではトラップはすべて S-mode (stvec) に委譲されるため、ここに来たら
// 異常。mcause/mepc を表示して halt する
m_trap_handler:
	addi    sp, sp, -32
	sd      ra, 0(sp)
	sd      a0, 8(sp)
	sd      t0, 16(sp)
	sd      t1, 24(sp)
	la      a0, msg_mtrap
	jal     ra, print_str
	csrr    a0, mcause
	jal     ra, print_hex32
	la      a0, msg_epc
	jal     ra, print_str
	csrr    a0, mepc
	jal     ra, print_hex64
	la      a0, newline
	jal     ra, print_str
.mhalt:
	j       .mhalt

// ---- S-mode トラップハンドラ (stvec 先) ----
// ページフォールト: scause = 13 (load) / 15 (store)、stval = フォールト VA。
// レジスタ退避はスタック (sp は S-mode でも有効)。sepc += 4 でフォールト
// 命令をスキップし sret で継続する
s_trap_handler:
	addi    sp, sp, -32
	sd      ra, 0(sp)
	sd      a0, 8(sp)
	sd      t0, 16(sp)
	sd      t1, 24(sp)
	la      a0, msg_strap
	jal     ra, print_str
	csrr    a0, scause
	jal     ra, print_hex32
	la      a0, msg_stval
	jal     ra, print_str
	csrr    a0, stval
	jal     ra, print_hex64        // stval は XLEN 幅
	la      a0, msg_sepc
	jal     ra, print_str
	csrr    a0, sepc
	jal     ra, print_hex64
	la      a0, newline
	jal     ra, print_str
	csrr    t0, scause
	li      t1, 13                 // load page fault
	beq     t0, t1, .skip_insn
	li      t1, 15                 // store/AMO page fault
	beq     t0, t1, .skip_insn
    // 予期しない S-mode トラップ → halt
.halt:
	j       .halt
.skip_insn:
	csrr    t0, sepc
	addi    t0, t0, 4              // フォールトした ld/sd をスキップ
	csrw    sepc, t0
	ld      t1, 24(sp)
	ld      t0, 16(sp)
	ld      a0, 8(sp)
	ld      ra, 0(sp)
	addi    sp, sp, 32
    sret

// ---- Print helpers (s101 / s02 と同一) ----

print_str:
	addi    sp, sp, -16
	sd      ra, 8(sp)
	sd      s0, 0(sp)
	mv      s0, a0
.ps_loop:
	lbu     t1, 0(s0)
	beqz    t1, .ps_ret
	mv      a0, t1
	jal     ra, uart_putc
	addi    s0, s0, 1
	j       .ps_loop
.ps_ret:
	ld      s0, 0(sp)
	ld      ra, 8(sp)
	addi    sp, sp, 16
	ret

// print_hex32: print low 32 bits of a0 as 8 uppercase hex digits
print_hex32:
	addi    sp, sp, -32
	sd      ra, 24(sp)
	sd      s3, 16(sp)
	sd      s4, 8(sp)
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
	ld      s4, 8(sp)
	ld      s3, 16(sp)
	ld      ra, 24(sp)
	addi    sp, sp, 32
	ret

// print_hex64: print a0 as 16 uppercase hex digits (s02_registers と同一)
print_hex64:
	addi    sp, sp, -32
	sd      ra, 24(sp)
	sd      s0, 16(sp)
	sd      s1, 8(sp)
	mv      s0, a0
	li      s1, 60
.ph64_loop:
	srl     a0, s0, s1
	andi    a0, a0, 0xF
	li      t0, 9
	bgt     a0, t0, .ph64_alpha
	addi    a0, a0, '0'
	j       .ph64_print
.ph64_alpha:
	addi    a0, a0, ('A' - 10)
.ph64_print:
	jal     ra, uart_putc
	addi    s1, s1, -4
	bgez    s1, .ph64_loop
	ld      s1, 8(sp)
	ld      s0, 16(sp)
	ld      ra, 24(sp)
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
scratch: .dword 0

// ---- Strings ----
msg_pmp:     .asciz "M-mode: PMP pmpaddr1=0x2fffffff pmpcfg0=0x0f0f (readback=0x"
msg_close:   .asciz ")\n"
msg_medeleg: .asciz "M-mode: medeleg wrote=0x"
msg_arrow:   .asciz " -> 0x"
msg_mstatus: .asciz "M-mode: mstatus (MPP=01 S-mode) = 0x"
msg_drop:    .asciz "M-mode: mret -> S-mode\nS-mode: building Sv39 page tables\n"
msg_pte:     .asciz "S-mode: root[2] PTE = 0x"
msg_satp:    .asciz "S-mode: satp (MODE=8 Sv39) = 0x"
msg_mapped:  .asciz "S-mode: identity access OK: 0x"
msg_ok:      .asciz "\n"
msg_load_fault: .asciz "S-mode: triggering load fault at 0x40000000\n"
msg_recovered:  .asciz "S-mode: load fault recovered\n"
msg_store_ok:   .asciz "S-mode: store fault recovered\n"
msg_mtrap:   .asciz "M-TRAP mcause=0x"
msg_strap:   .asciz "PAGE FAULT scause=0x"
msg_stval:   .asciz " stval=0x"
msg_sepc:    .asciz " sepc=0x"
msg_epc:     .asciz " mepc=0x"
newline:     .asciz "\n"

.section .bss
.align 12
root_pt: .space 4096                 // Sv39 root: 512 entries * 8B (1GB region each)

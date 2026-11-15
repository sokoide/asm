// s102_paging.s - Scenario 102: S-mode Paging (Sv32)
// ================================================================
// RISC-V 特権アーキテクチャの中核「S-mode 仮想記憶」を学ぶ。
//   - M-mode での初期化: PMP (Physical Memory Protection) を設定しないと、
//     QEMU virt はリセット後 PMP エントリが空で、S-mode からの全アクセスが
//     PMP で拒否される。mret で降下する前に全メモリ+MMIO を NAPOT で許可する
//   - medeleg: ページフォールト (exception 12/13/15) を S-mode に委譲する。
//     委譲しないと M-mode の mtvec に飛んでしまう (interrupts は mideleg だが
//     ページフォールトは例外なので medeleg だけで十分。本シナリオでは割込を
//     使わないため mideleg は設定しない)
//   - Sv32: 32-bit VA / 2 段ページテーブル。satp.MODE=1 (Sv32) で有効化。
//     4KB ページ (root -> lvl1 -> 4KB leaf) と 4MB メガページ (root 直接 leaf,
//     leaf-at-level-1) を両方使用し、PTE フィールド (V/R/W/X/A/D + PPN) を
//     読み取れる構成にする
//   - sfence.vma: satp 書き換え後の TLB 同期 (RISC-V は古い変換をソフトが無効化)
//   - ページフォールト実演: 未マップ VA への load (scause=13) / store
//     (scause=15)。stvec ハンドラで scause/stval (フォールトアドレス) を表示し、
//     sepc += 4 でフォールト命令をスキップして sret で継続する
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
    // 意味する。注意: rv32 では 4GB (pmpaddr=0x1fffffff) の NAPOT は QEMU の
    // サイズ計算が 32-bit でオーバーフローし、実際にはマッチしないため
    // 2GB ずつの 2 エントリ構成にする (実測: 4GB 構成では S-mode fetch が
    // access fault になる)
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

    // ---- ページテーブル構築 (Sv32: 2 段, 4KB ページサイズ) ----
    // VA[31:22] = VPN1 (root, 4MB/entry), VA[21:12] = VPN0 (4KB/entry)
    // メモリレイアウト:
    //   root[0]   : メガページ leaf @ 0x00000000 (4MB)  — SiFive test 0x100000
    //   root[64]  : メガページ leaf @ 0x10000000 (4MB)  — UART MMIO
    //   root[512] : 非 leaf ポインタ -> lvl1_pt (V のみ, R/W/X=0 がポインタの証)
    //   root[512] は 0x80000000-0x803fffff を 1024 個の 4KB leaf で identity map
    //   (コード・データ・スタック sp=0x80200000 を含む)
    //   未マップ VA (root[256] = 0) がページフォールト実演の対象
    la      t0, root_pt
    li      t1, 4096
    add     t0, t0, t1             // 終端から逆順に 0 クリア (1024 entries)
    li      t1, 1024
.zero_root:
    addi    t0, t0, -4
    sw      zero, 0(t0)
    addi    t1, t1, -1
    bnez    t1, .zero_root

    // root[0] = PPN 0 << 10                                      | 0xCF  (V|R|W|X|A|D, 4MB-aligned leaf)
    li      t1, 0xCF
    la      t0, root_pt
    sw      t1, 0(t0)
    // root[64] = PPN 0x10000 << 10                               | 0xCF  (0x10000000/4096 = 0x10000)
    li      t1, 0x10000
    slli    t1, t1, 10
    ori     t1, t1, 0xCF
    sw      t1, 256(t0)            // entry 64 * 4 bytes = offset 256
    // root[512] = PPN(lvl1_pt) << 10                             | 0x01  (V のみ = 非 leaf ポインタ)
    la      t1, lvl1_pt
    srli    t1, t1, 12
    slli    t1, t1, 10
    ori     t1, t1, 0x01
    li      t2, 2048
    add     t0, t0, t2
    sw      t1, 0(t0)              // entry 512 * 4 bytes = offset 2048

    // lvl1_pt[0..1023]: 4KB identity leaf for 0x80000000 + i*4096
    // PTE = PPN << 10                                            | 0xCF, PPN = (0x80000000/4096) + i = 0x80000 + i
    la      t0, lvl1_pt
    li      t1, 0x80000            // PPN of 0x80000000
    li      t2, 1024
    li      t3, 0xCF
.fill_lvl1:
    slli    t4, t1, 10
    or      t4, t4, t3
    sw      t4, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, 1
    addi    t2, t2, -1
    bnez    t2, .fill_lvl1

    // サンプル PTE 表示: lvl1[0] = 0x200000CF
    //   (PPN=0x80000, V                                          | R|W|X|A|D — 4KB leaf, 0x80000000 を指す)
    la      a0, msg_pte
    jal     ra, print_str
    la      t0, lvl1_pt
    lw      a0, 0(t0)
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // ---- satp 設定: MODE=1 (Sv32)                              | PPN(root_pt>>12) ----
    la      t0, root_pt
    srli    t0, t0, 12
    li      t1, 0x80000000         // bit 31 = MODE 1 = Sv32
    or      t0, t0, t1
    csrw    satp, t0
    sfence.vma                  // TLB 同期 (satp 変更直後は必須)
    la      a0, msg_satp
    jal     ra, print_str
    csrr    a0, satp
    jal     ra, print_hex32
    la      a0, newline
    jal     ra, print_str

    // ---- identity map 下で通常アクセスを確認 ----
    la      a0, msg_mapped
    jal     ra, print_str
    li      t0, 0x1234
    la      t1, scratch
    sw      t0, 0(t1)              // MMU 経由のストア
    lw      a0, 0(t1)              // MMU 経由のロード
    jal     ra, print_hex32
    la      a0, msg_ok
    jal     ra, print_str

    // ---- ページフォールト実演 1: 未マップ VA への load ----
    // VA 0x40000000 は root[256] = 0 (V=0) で load page fault
    // scause=13 (0xD), stval=0x40000000 → stvec ハンドラで表示し sepc+=4
    la      a0, msg_load_fault
    jal     ra, print_str
    li      t0, 0x40000000
    lw      t1, 0(t0)
    la      a0, msg_recovered
    jal     ra, print_str

    // ---- ページフォールト実演 2: 未マップ VA への store ----
    // store page fault: scause=15 (0xF), stval=0x40000000
    li      t0, 0x40000000
    li      t1, 0x55
    sw      t1, 0(t0)
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
    sw      ra, 0(sp)
    sw      a0, 8(sp)
    sw      t0, 16(sp)
    sw      t1, 24(sp)
    la      a0, msg_mtrap
    jal     ra, print_str
    csrr    a0, mcause
    jal     ra, print_hex32
    la      a0, msg_epc
    jal     ra, print_str
    csrr    a0, mepc
    jal     ra, print_hex32
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
    sw      ra, 0(sp)
    sw      a0, 8(sp)
    sw      t0, 16(sp)
    sw      t1, 24(sp)
    la      a0, msg_strap
    jal     ra, print_str
    csrr    a0, scause
    jal     ra, print_hex32
    la      a0, msg_stval
    jal     ra, print_str
    csrr    a0, stval
    jal     ra, print_hex32
    la      a0, msg_sepc
    jal     ra, print_str
    csrr    a0, sepc
    jal     ra, print_hex32
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
    addi    t0, t0, 4              // フォールトした lw/sw をスキップ
    csrw    sepc, t0
    lw      t1, 24(sp)
    lw      t0, 16(sp)
    lw      a0, 8(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 32
    sret

// ---- Print helpers (s101 と同一) ----

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
scratch: .word 0

// ---- Strings ----
msg_pmp:     .asciz "M-mode: PMP pmpaddr1=0x2fffffff pmpcfg0=0x0f0f (readback=0x"
msg_close:   .asciz ")\n"
msg_medeleg: .asciz "M-mode: medeleg wrote=0x"
msg_arrow:   .asciz " -> 0x"
msg_mstatus: .asciz "M-mode: mstatus (MPP=01 S-mode) = 0x"
msg_drop:    .asciz "M-mode: mret -> S-mode\nS-mode: building Sv32 page tables\n"
msg_pte:     .asciz "S-mode: lvl1[0] PTE = 0x"
msg_satp:    .asciz "S-mode: satp (MODE=1 Sv32) = 0x"
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
root_pt: .space 4096                 // Sv32 root: 1024 entries * 4B (4MB region each)
.align 12
lvl1_pt: .space 4096                 // Sv32 2nd level: 1024 entries * 4B (4KB each)

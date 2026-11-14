# RISC-V 32-bit アセンブラ ワークショップ

QEMU virt マシン上で RV32IM アセンブリを 12 のシナリオで段階的に学ぶ。

## 前提条件

| ツール              | 用途                       | インストール例                                 |
| :--- | :--- | :--- |
| clang + ld.lld      | アセンブラ + リンカ        | Xcode Command Line Tools / `brew install llvm` |
| qemu-system-riscv32 | RISC-V 32-bit エミュレータ | `brew install qemu`                            |
| coreutils           | timeout コマンド           | `brew install coreutils`                       |

## ビルドと実行

```bash
# 全シナリオをビルド
make

# 特定のシナリオを実行
make run S=s01_hello

# 全シナリオをビルド + 実行
make runall

# 逆アセンブル
make dump S=s01_hello

# 掃除
make clean
```

## デバッグ

```bash
# QEMU を -S -gdb tcp:127.0.0.1:1234 で起動し gdb を接続（ステップ実行）
make debug S=s01_hello

# 命令ごとの逆アセンブル + CPU 状態を s01_hello.trace に記録して less で閲覧
make trace S=s01_hello

# 実行命令数を集計 (実サイクルは make cycles が unsupported を表示)
make icount S=s01_hello
```

`make debug` では gdb の `si`（1 命令ステップ）/ `c`（続行）/ `b *ADDR`（ブレークポイント）/ `info registers` / `x/5i $pc` で観察する（gdb が必要: `brew install gdb`、ポートは `GDB_PORT` で変更可）。UART 出力はステップ実行の進行に応じて同じターミナルに表示される。`make cycles` は QEMU TCG がサイクル精度のエミュレーションではないため `unsupported` を表示し、実行命令数は `make icount` で計測する。

## ディレクトリ構造

```text
.
├── Makefile
├── linker.ld
├── README.md
├── s01_hello.s          # シナリオ 1: Hello World
├── s02_registers.s      # シナリオ 2: レジスタとデータ転送
├── s03_stack.s          # シナリオ 3: スタック操作
├── s04_loops.s          # シナリオ 4: ループ
├── s05_strings.s        # シナリオ 5: 文字列操作
├── s06_serial_in.s      # シナリオ 6: シリアル入力
├── s07_subroutines.s    # シナリオ 7: サブルーチン
├── s08_hardware.s       # シナリオ 8: ハードウェアアクセス
├── s09_branching.s      # シナリオ 9: 条件分岐
├── s10_bitwise.s        # シナリオ 10: ビット演算
├── s11_memory.s         # シナリオ 11: メモリ操作
├── s12_minishell.s      # シナリオ 12: インタラクティブシェル
├── s13_copybench.s      # シナリオ 13: 共通課題 100 バイトコピー
├── s101_csr_ecall.s     # シナリオ 101: CSR と ECALL
└── s102_paging.s        # シナリオ 102: S-mode ページング (Sv32)
```

## シナリオ一覧

### S01: Hello World

**難易度**: ★☆☆☆☆

最も基本的な RISC-V bare-metal プログラム。UART 経由で文字列を表示して SiFive test device で終了する。

| 学習項目         | 説明                                          |
| :--- | :--- |
| `.section .text` | コードセクションの定義                        |
| `_start`         | エントリポイント                              |
| `la` 疑似命令    | ラベルアドレスのロード                        |
| `lbu` / `sb`     | バイト単位のメモリアクセス                    |
| SiFive test      | `0x100000` に `0x5555` を書き込んで QEMU 終了 |

---

### S02: レジスタとデータ転送

**難易度**: ★☆☆☆☆

RV32I の 32 本レジスタと基本算術命令を学ぶ。

| 学習項目      | 説明                           |
| :--- | :--- |
| `li` / `mv`   | 即値ロード / レジスタ間転送    |
| `add` / `sub` | 加算 / 減算                    |
| `addi`        | 即値加算（INC/DEC に使用）     |
| `print_hex32` | 32ビット16進数出力サブルーチン |

---

### S03: スタック操作

**難易度**: ★★☆☆☆

RISC-V には PUSH/POP 命令がない。`addi sp` + `sw`/`lw` で手動管理する。

| 学習項目              | 説明                               |
| :--- | :--- |
| `addi sp, sp, -4`     | スタックフレーム確保               |
| `sw ra, 0(sp)`        | リターンアドレスの保存             |
| `lw ra, 0(sp)`        | リターンアドレスの復元             |
| LIFO                  | Last In, First Out の理解          |
| callee-saved (s0-s11) | サブルーチン間で保存すべきレジスタ |

---

### S04: ループ

**難易度**: ★★☆☆☆

`addi` と条件分岐を使ったループ制御。

| 学習項目     | 説明                           |
| :--- | :--- |
| `bnez`       | 非ゼロで分岐（カウントダウン） |
| `blt`        | 未満で分岐（カウントアップ）   |
| `addi`       | カウンタの増減                 |
| ループ不変値 | 和の計算など累積パターン       |

---

### S05: 文字列操作

**難易度**: ★★☆☆☆

バイト単位のアクセスで文字列を操作する。

| 学習項目 | 説明                     |
| :--- | :--- |
| `lbu`    | 符号なしバイトロード     |
| `sb`     | バイトストア             |
| `beqz`   | ヌルターミネータ検出     |
| `strlen` | 文字列長の測定           |
| `strcpy` | バイト単位の文字列コピー |

---

### S06: シリアル入力

**難易度**: ★★★☆☆

UART NS16550A からの受信とエコーバック。

| 学習項目  | 説明                                     |
| :--- | :--- |
| LSR bit 0 | Data Ready ビットのポーリング            |
| `lbu`     | RBR (Receiver Buffer Register) の読取    |
| `sb`      | THR (Transmit Holding Register) への書込 |
| 文字分類  | 数字 / 大文字 / 小文字の判定             |

---

### S07: サブルーチン

**難易度**: ★★★☆☆

`jal` / `ret` による関数呼び出しと calling convention。

| 学習項目       | 説明                                   |
| :--- | :--- |
| `jal` / `ret`  | リンクレジスタを使った呼出・復帰       |
| `a0`-`a7`      | 引数渡し用レジスタ                     |
| `ra` (x1)      | リターンアドレスの自動保存             |
| `s0`-`s11`     | callee-saved レジスタの保存・復元      |
| ネスト呼び出し | サブルーチンから別のサブルーチンを呼ぶ |

---

### S08: ハードウェアアクセス

**難易度**: ★★★☆☆

CSR と MMIO を使ったタイマーアクセス。

| 学習項目     | 説明                         |
| :--- | :--- |
| `rdcycle`    | サイクルカウンタ CSR 読取    |
| `rdtime`     | タイムカウンタ CSR 読取      |
| CLINT mtime  | `0x200BFF8` からの直接読取   |
| サイクル測定 | 処理前後の差分でベンチマーク |

---

### S09: 条件分岐

**難易度**: ★★★★☆

符号付き / 符号なし比較とジャンプテーブル。

| 学習項目         | 説明                       |
| :--- | :--- |
| `beq` / `bne`    | 等価 / 非等価分岐          |
| `blt` / `bge`    | 符号付き比較分岐           |
| `bltu` / `bgeu`  | 符号なし比較分岐           |
| `slt` / `slti`   | 比較結果をレジスタにセット |
| ジャンプテーブル | `jalr` による間接分岐      |

---

### S10: ビット演算

**難易度**: ★★★★☆

AND / OR / XOR / シフトを使ったビット単位の操作。

| 学習項目       | 説明                       |
| :--- | :--- |
| `and` / `andi` | マスク（特定ビットの抽出） |
| `or` / `ori`   | ビットの設定               |
| `xor` / `xori` | ビットの反転               |
| `sll` / `slli` | 左シフト（×2 の累乗）      |
| `srl` / `srli` | 論理右シフト（ゼロ埋め）   |
| `sra` / `srai` | 算術右シフト（符号拡張）   |

---

### S11: メモリ操作

**難易度**: ★★★★☆

ワード / バイト単位のメモリアクセスとブロック操作。

| 学習項目    | 説明                            |
| :--- | :--- |
| `sw` / `lw` | 32ビットワードのストア / ロード |
| `sb` / `lb` | バイトのストア / ロード         |
| `memfill`   | 指定値でメモリ領域を埋める      |
| `memcpy`    | バイト単位のブロックコピー      |

---

### S12: インタラクティブシェル

**難易度**: ★★★★★

UART 入出力を使った対話型シェル。全要素の総合演習。

| 学習項目       | 説明                              |
| :--- | :--- |
| `uart_getc`    | LSR DR ビットポーリングによる入力 |
| ラインエディタ | バックスペース対応の入力行編集    |
| `streq`        | 文字列比較によるコマンド解析      |
| ディスパッチ   | コマンドに応じた処理の分岐        |

**コマンド一覧**:

- `hello` — 挨拶メッセージを表示
- `count` — 5 4 3 2 1 のカウントダウン
- `hex` — 00-0F の 16 進数を表示
- `help` — コマンド一覧を表示
- `quit` — 終了

---

### S13: Copy Benchmark（共通課題: 100 バイトコピー）

**難易度**: ★★★☆☆

全アーキ共通の比較課題。100 バイトのメモリコピーを行い、宛先の総和（チェックサム `0x1356`）を検証する。詳細と他アーキとの比較は `compare/copybench.md` を参照。

| 学習項目     | 説明                                            |
| :---         | :---                                            |
| バイトコピー | LBU/SB と分岐の素朴なループ（専用命令は無い）   |
| チェックサム | 宛先 100 バイトの総和でコピーを検証             |

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: `.cp_loop` は `lbu` → `sb` → `addi` × 3 → `bnez` の 6 命令 × 100 回。RISC-V はポインタ更新も自分で書く（writeback アドレッシング無し）点に注目し、ARM64（4 命令/バイト）と比べ何命令多いか予測してから `make icount S=s13_copybench` で総命令数を測る。
- **STEP 2 観察**: `make trace S=s13_copybench` でループが 6 命令 × 100 回回ることを確認する。`bnez` が汎用レジスタを直接テストする点（ARM64 の `subs` + `b.ne` と違い、`addi` はフラグを set しない）も見る。
- **STEP 3 改造**: `lbu`/`sb` → `lw`/`sw`（4 バイト転送）に替えて反復 25 回にしたときの icount を予測してから測る。RISC-V に writeback が無いためポインタ更新が残り、命令数削減が 2 命令/反復どまりである点も確認する。
- **STEP 4 考察**: `compare/copybench.md` を参照。RISC 4 種（PPC/ARM64/RISC-V/m68k はいずれも専用ブロック転送なし）と CISC 2 種（Z80 LDIR / x86 REP MOVSB）の「命令数/バイト」を並べ、命令数とクロック/実行時間の関係を整理する。

---

### S101: CSR と ECALL

**難易度**: ★★★★☆

RISC-V 特有の「制御は CSR とトラップ機構に集約される」設計。M-mode で CSR を読み書きし、ECALL によるトラップ（mcause = 11）と MRET での復帰を実演する。

| 学習項目          | 説明                                                     |
| :---              | :---                                                     |
| CSR 読み書き      | misa / mhartid / mstatus の参照                          |
| CSRRC             | ビット単位のクリア（アトミック read-modify-write）       |
| mtvec             | トラップハンドラの登録（direct mode）                    |
| ECALL / MRET      | 環境呼び出しトラップと mepc + 4 での復帰                 |

観察: `make trace S=s101_csr_ecall` で ecall → mtvec 突入 → mret の流れが追える。

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: Demo 3 の `csrrc t0, mstatus, t1`（t1 = bit3 = MIE）の後、mstatus と t0 の値はどう違うか（CSRRC は旧値を t0 に残す）。`ecall` 実行時に mcause と mepc に何が入るか（11 と ecall 命令のアドレス）も予測する。
- **STEP 2 観察**: `make trace S=s101_csr_ecall` で、`ecall` 実行時に PC が mtvec 先（trap_handler）へジャンプすること、ハンドラ内の `mepc += 4` と `mret` で復帰する流れを追う。`make icount S=s101_csr_ecall` でトラップ 1 回を含む総命令数も確認する。
- **STEP 3 改造**: ハンドラの `mepc += 4` を外すと、mret で ecall 自身に戻り再実行 → 無限トラップになることを予測してから確認する（`make run` で出力が止まり、trace で ecall → handler のループが見える）。試したら必ず戻す。
- **STEP 4 考察**: x86 S102 は IVT（メモリ上）+ スタック渡し、PPC S102 は IVPR+IVOR + SRR0/SRR1、ARM64 S102 は VBAR+0x200 + ELR/ESR。RISC-V は mtvec 1 本 + mcause/mepc/mstatus。4 アーキの「ベクタの決め方」と「状態の渡し方」を表にまとめる。

---

### S102: S-mode ページング (Sv32)

**難易度**: ★★★★☆

M-mode → S-mode 遷移 → S-mode でページテーブル構築 → ページフォールト実演。RISC-V 特権アーキテクチャの中核「satp による仮想記憶」を 1 ファイルで体験する。

| 学習項目        | 説明                                                              |
| :---            | :---                                                              |
| PMP             | S-mode からの物理アクセス許可。設定しないと mret 直後に fetch が access fault |
| medeleg         | ページフォールト (exception 12/13/15) を S-mode へ委譲            |
| mstatus.MPP     | bits 12:11 = 01 (S) で mret の遷移先を S-mode に指定              |
| Sv32            | 2 段ページテーブル (VPN1=VA[31:22], VPN0=VA[21:12])               |
| PTE フィールド  | V/R/W/X/A/D ビット + PPN。非 leaf ポインタは V のみ               |
| メガページ      | root 直接 leaf (leaf-at-level-1) で 4MB マッピング                |
| satp / sfence.vma | MODE=1 \| PPN(root) で有効化、書換後は TLB 同期                 |
| ページフォールト | 未マップ VA へ load (scause=13) / store (scause=15)、stval にフォールト VA |
| sepc += 4 + sret | stvec ハンドラでフォールト命令をスキップして継続               |

**Sv32 の構成**: root[0] と root[64] は 4MB メガページ leaf (0x00000000 / 0x10000000: test デバイスと UART)、root[512] は V のみの非 leaf ポインタで、0x80000000-0x803fffff (コード・データ・スタック) を 1024 個の 4KB leaf で identity map する。

**PMP の必要性**: QEMU virt は PMP エントリなしでリセットされ、S-mode からのアクセスが PMP で拒否される。本シナリオは MMIO 領域 (0x00000000-0x7fffffff) と DRAM (0x80000000-0xbfffffff) を 2 つの 2GB NAPOT エントリ (`pmpcfg0=0x0f0f`, `pmpaddr0=0x0fffffff`, `pmpaddr1=0x2fffffff`) で許可する。

観察: `make run S=s102_paging` で M→S 遷移、satp 読み戻し、`PAGE FAULT scause=... stval=...` の 2 回のフォールトと sret 復帰が追える。

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: `medeleg` の設定を外した場合、S-mode 中のページフォールトはどこに飛ぶか（M-mode の mtvec）。`mstatus.MPP = 01 (S)` を設定しないで `mret` するとどのモードに降りるか。PMP を設定しないと mret 直後の何が fault するか（fetch）も予測する。
- **STEP 2 観察**: `make trace S=s102_paging` で、`mret` による M→S 遷移、`sfence.vma` の位置、未マップ VA への load で stvec ハンドラ（scause=13, stval=フォールト VA）に入ること、`sepc += 4` + `sret` でフォールト命令をスキップして継続する流れを追う。`make run` の `PAGE FAULT` 出力 2 回と対応付ける。
- **STEP 3 改造**: root[0]（0x00000000 のメガページ）の PTE の V ビットを落とすと、test デバイス書き込み（0x100000）の store がフォールトするはず — scause=15 (store) / stval=0x100000 になるか予測してから試す。
- **STEP 4 考察**: x86 は CR3 + ページング有効化は CR0.PG、ARM64 は TTBR0/1 + TCR_EL1、RISC-V は satp 1 本。ページング有効化に「ソフトウェアの TLB 同期」（sfence.vma / invlpg / TLBI）が必要かどうかの違いも含めて、3 方式を比較する。

- [`../CPU.md`](../CPU.md) — RV32IM 命令セット完全リファレンス

## ハードウェア情報

### 出力（UART）

| 項目            | 値         |
| :--- | :--- |
| UART 種別       | NS16550A   |
| ベースアドレス  | 0x10000000 |
| THR (送信)      | base+0     |
| RBR (受信)      | base+0     |
| LSR (状態)      | base+5     |
| THRE (送信可能) | LSR bit 5  |
| DR (データあり) | LSR bit 0  |

### 入力（UART RX）

| 項目            | 値        |
| :--- | :--- |
| RBR (受信)      | base+0    |
| DR (データあり) | LSR bit 0 |

### 終了

| 項目               | 値       |
| :--- | :--- |
| SiFive test device | 0x100000 |
| 終了コード (PASS)  | 0x5555   |

## I/O ルーチン

RISC-V では文字入出力に NS16550A UART（MMIO `0x10000000`）を直接操作する（「ハードウェア情報」の [出力（UART）](#出力uart) / [入力（UART RX）](#入力uart-rx) を参照）。**プログラムの終了は SiFive test device を使用**する。

**定義元**: QEMU `virt` マシンに接続された **`sifive_test` デバイス**（SiFive Test/Finisher device、QEMU が実装）。MMIO アドレス `0x100000` に 32-bit 値をストアすると QEMU が値を解釈して終了/リセットする。OS や BIOS のシステムコールではなく、QEMU 固有の終了デバイス。

**規約**: レジスタ引数なし。`0x100000` に 32-bit 値をストアする。値の **下位 16-bit** が動作コード、**上位 16-bit** が詳細コード（FAIL/RESET の場合）。

**SiFive test device のコード**:

| ストア値（下位 16-bit） | 定数           | 機能                                       | 教材使用   |
| :---                    | :---           | :---                                       | :---       |
| `0x5555`                | FINISHER_PASS  | 正常終了（終了コード 0）                   | **全シナリオ** |
| `0x3333`                | FINISHER_FAIL  | 異常終了（上位 16-bit に終了理由コード）   | 未使用     |
| `0x7777`                | FINISHER_RESET | システムリセット（上位 16-bit にリセット理由） | 未使用  |

**終了の使い方**:

```asm
    li  t0, 0x100000     # SiFive test device アドレス
    li  t1, 0x5555       # FINISHER_PASS
    sw  t1, 0(t0)        # 32-bit ストアで終了
```

**注意**: FAIL/RESET は上位 16-bit に詳細コードを指定できる（例: `0x00013333` = 理由コード 1 で FAIL）。教材は `0x5555`（PASS）のみ使用する。Makefile は SiFive test が呼ばれない場合の安全策として `timeout --foreground 1` で QEMU を強制終了するが、全シナリオは SiFive test で明示的に終了する。

**定義元**: QEMU `sifive_test` デバイス（`hw/misc/sifive_test.c`）。

## ビルドシステム

### ツールチェーン

| ツール         | コマンド               | 用途                       |
| :--- | :--- | :--- |
| アセンブラ     | `clang`                | RISC-V 32-bit クロスアセンブル |
| リンカ         | `ld.lld`               | ELF バイナリ生成           |
| 逆アセンブル   | `llvm-objdump`         | 機械語コードの確認         |
| エミュレータ   | `qemu-system-riscv32`  | RISC-V 32-bit 仮想マシン   |

基本コンパイルフラグ:

```makefile
ASFLAGS = --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib
```

`-march=rv32im` は RV32I（基本整数） + M（乗除算）拡張を有効にする。`-mabi=ilp32` は 32-bit int / long / pointer の ABI を指定。

### アセンブラ疑似命令

| 疑似命令        | 説明                     | 使用例                  |
| :--- | :--- | :--- |
| `.section .text` | コードセクション定義     | `.section .text`        |
| `.global _start` | 外部公開シンボル         | `.global _start`        |
| `.asciz`         | ヌル終端文字列           | `.asciz "Hello\n"`      |
| `.byte`          | 1 バイトデータ定義       | `.byte 0x41`            |
| `.word`          | 32 ビットデータ定義      | `.word 0x12345678`      |
| `.space N`       | N バイトの領域確保       | `.space 256`            |
| `.align N`       | 2^N バイト境界にアライメント | `.align 2`          |

### Makefile 解説

| 変数       | 値                                                              | 説明                                |
| :--- | :--- | :--- |
| `AS`       | `clang`                                                         | アセンブラとして Clang を使用       |
| `LD`       | `ld.lld`                                                        | LLVM リンカ                         |
| `ASFLAGS`  | `--target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -c -nostdlib` | RISC-V 32-bit クロスコンパイル      |
| `LDFLAGS`  | `-T linker.ld -nostdlib`                                        | リンカスクリプト指定、stdlib 無効   |
| `QEMU`     | `qemu-system-riscv32`                                           | RISC-V 32-bit エミュレータ           |
| `QFLAGS`   | `-machine virt -nographic -bios none`                           | virt マシン、GUI 無効、BIOS 無し    |

### リンカスクリプト

`linker.ld` の要点:

- **エントリポイント**: `ENTRY(_start)` — `_start` ラベルから実行開始
- **ロードアドレス**: `0x80000000` — QEMU virt マシンの物理メモリ開始位置
- **セクション配置（先頭から順に）**:
  - `.text` — コード
  - `.rodata` — 読み取り専用データ（文字列定数など）
  - `.data` — 初期化済みデータ
  - `.bss` — ゼロ初期化データ（`__bss_start` / `__bss_end` で境界管理）

## トラブルシューティング

### QEMU が起動しない

| 現象                                               | 原因                  | 解決策                          |
| :--- | :--- | :--- |
| `command not found: qemu-system-riscv32`           | QEMU 未インストール   | `brew install qemu`             |
| `qemu-system-riscv32: -machine virt: unsupported`  | 古い QEMU バージョン  | `brew upgrade qemu`             |
| `Could not open 'xxx.elf'`                         | ビルドが失敗している  | 先に `make` を実行              |

### ビルドエラー

| 現象                                                    | 原因                              | 解決策                                |
| :--- | :--- | :--- |
| `clang: command not found`                              | Clang 未インストール              | Xcode CLT または `brew install llvm`  |
| `clang: error: unknown target 'riscv32-unknown-elf'`    | LLVM に RISC-V バックエンドがない | `brew install llvm` で最新版を取得    |
| `ld.lld: unknown argument: -T`                          | システムの `ld` が呼ばれている    | `brew install llvm` 後、PATH を確認   |
| `undefined reference to '_start'`                       | `_start` シンボル未定義           | `.global _start` と `_start:` の存在確認 |

### UART 出力が出ない

| 現象                 | 原因                   | 解決策                                       |
| :--- | :--- | :--- |
| 何も表示されない     | THRE ビット未チェック  | LSR bit 5 のポーリングループを確認           |
| 文字化けする         | アライメントの問題     | 送信データがバイト単位であることを確認       |
| 途中で停止する       | 無限ループ / 不正アクセス | ループ終了条件とメモリアクセス範囲を確認     |
| 受信が動作しない     | DR ビット未チェック    | LSR bit 0 のポーリングループを確認           |

## 次のステップ

- 各シナリオのソースを開き、コメントを読みながらコードを追う
- `make run S=s02_registers` で順に実行し、出力を観察する
- 値を変更してビルド → 実行し、結果の変化を確認する
- S12 をベースに新しいコマンドを追加してみる
- [`../CPU.md`](../CPU.md) で全命令を調べる

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
└── s12_minishell.s      # シナリオ 12: インタラクティブシェル
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

RV32I の32本レジスタと基本算術命令を学ぶ。

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
- `hex` — 00-0F の16進数を表示
- `help` — コマンド一覧を表示
- `quit` — 終了

---

## 関連ドキュメント

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

### 終了方法

QEMU を正常終了させるには SiFive test device を使用する:

```asm
    li a0, 0x100000     # SiFive test device アドレス
    li a1, 0x5555       # PASS コード
    sw a1, 0(a0)        # 32-bit ストアで終了
```

- `0x5555` = PASS（成功）、`0x3333` = FAIL（失敗）
- Makefile では `timeout --foreground 1` で 1 秒後に強制終了（SiFive test 未使用時の安全策）

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

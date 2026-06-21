# ARM64 (AArch64) ベアメタル アセンブラ ワークショップ

QEMU virt マシン上で動作する ARM64 ベアメタルアセンブリ言語教材。PL011 UART を I/O に使い、12 のシナリオで段階的に学ぶ。

## 前提条件

| ツール       | 用途         | インストール例                  |
| :---         | :---         | :---                            |
| Clang        | アセンブラ   | Xcode Command Line Tools に同梱 |
| ld.lld       | リンカ       | `brew install lld`              |
| llvm-objdump | 逆アセンブラ | `brew install llvm`             |
| QEMU         | エミュレータ | `brew install qemu`             |

## ビルドと実行

```bash
# 全シナリオをビルド
make

# 特定のシナリオを QEMU で実行
make run S=s01_hello

# 全シナリオを連続実行
make runall

# 逆アセンブル
make dump S=s01_hello

# 掃除
make clean
```

## ディレクトリ構造

```text
.
├── linker.ld           # リンカスクリプト（0x40000000 配置）
├── Makefile
├── README.md
├── s01_hello.s         # シナリオ 1: Hello World
├── s02_registers.s     # シナリオ 2: レジスタと算術
├── s03_stack.s         # シナリオ 3: スタック操作
├── s04_loops.s         # シナリオ 4: ループと条件分岐
├── s05_strings.s       # シナリオ 5: 文字列操作
├── s06_serial_in.s     # シナリオ 6: シリアル入力
├── s07_subroutines.s   # シナリオ 7: サブルーチン
├── s08_hardware.s      # シナリオ 8: ハードウェアアクセス（タイマー）
├── s09_branching.s     # シナリオ 9: 条件分岐
├── s10_bitwise.s       # シナリオ 10: ビット演算
├── s11_memory.s        # シナリオ 11: メモリ操作
└── s12_minishell.s     # シナリオ 12: ミニシェル（総合）
```

## シナリオ一覧

### S01: Hello World

**難易度**: ★☆☆☆☆

最も基本的なベアメタルプログラム。PL011 UART に文字列を出力し、セミホスティングで終了する。

| 学習項目                    | 説明                                            |
| :---                        | :---                                            |
| `.section .text`            | コードセクションの宣言                          |
| `.global _start`            | プログラム開始シンボルをエクスポート            |
| `movz x0, #0x4800, lsl #16` | スタックポインタを RAM 末尾（0x48000000）に設定 |
| `mov sp, x0`                | SP レジスタに書き込み                           |
| `ldr x0, =message`          | 文字列アドレスをロード（疑似命令）              |
| `bl print_str`              | サブルーチン呼び出し                            |
| `strb w0, [x8]`             | UART への 1 バイト書き込み（MMIO）              |
| `hlt #0xF000`               | セミホスティングトラップ（QEMU 終了）           |
| `.asciz`                    | ヌル終端文字列の定義                            |

**QEMU 終了方法**: 自動終了（セミホスティング）

---

### S02: レジスタと算術

**難易度**: ★☆☆☆☆

ARM64 の 64 ビット汎用レジスタ（X0-X30）と基本演算を学ぶ。

| 学習項目                    | 説明                                       |
| :---                        | :---                                       |
| `mov x0, #val`              | 即値をレジスタにロード（16-bit まで）      |
| `movz x0, #val, lsl #shift` | 即値をゼロ拡張してロード（最大 64-bit）    |
| `add x0, x1, x2`            | レジスタ間加算：x0 = x1 + x2               |
| `sub x0, x1, x2`            | レジスタ間減算：x0 = x1 - x2               |
| `add x0, x0, #1`            | インクリメント（専用命令はなし）           |
| `sub x0, x0, #1`            | デクリメント                               |
| 16 進数表示                 | `print_hex64` サブルーチン（ニブル→ASCII） |

**ポイント**: ARM64 には `INC` / `DEC` 専用命令がなく、`ADD` / `SUB #1` で代用する。

---

### S03: スタック操作

**難易度**: ★★☆☆☆

スタック（LIFO）の動作を理解し、`STP` / `LDP` によるレジスタペアの一括保存・復元を学ぶ。

| 学習項目                  | 説明                                              |
| :---                      | :---                                              |
| `stp x2, x3, [sp, #-16]!` | レジスタペアをスタックに PUSH（事前デクリメント） |
| `ldp x4, x5, [sp], #16`   | スタックから POP（事後インクリメント）            |
| LIFO                      | Last In, First Out                                |
| スタック成長方向          | 下方成長（SP が減少する）                         |
| `!`（感嘆符）             | 書き込みアドレス更新（pre-index）                 |

---

### S04: ループと条件分岐

**難易度**: ★★☆☆☆

`SUBS` + `B.NE` / `CMP` + `B.LT` / `TST` + `B.EQ` を使った反復処理。

| 学習項目             | 説明                                 |
| :---                 | :---                                 |
| `SUBS x0, x0, #1`    | 減算してフラグ更新（S サフィックス） |
| `B.NE label`         | 非ゼロならジャンプ                   |
| `CMP x0, #val`       | 比較（フラグのみ更新）               |
| `B.LT label`         | より小さい（符号付き）ならジャンプ   |
| `TST w0, #1`         | AND 演算テスト（偶数/奇数判定）      |
| `B.EQ label`         | 等しいならジャンプ                   |
| カウントダウンループ | `SUBS` → `B.NE` の定石パターン       |

---

### S05: 文字列操作

**難易度**: ★★☆☆☆

文字列の長さ測定（strlen）とコピー（strcpy）を実装する。

| 学習項目         | 説明                                          |
| :---             | :---                                          |
| `ldrb w2, [x1]`  | [x1] から 1 バイト読み込み                    |
| `strb w3, [x2]`  | w3 を [x2] に書き込み                         |
| `cbz w2, label`  | w2 が 0 ならジャンプ（比較＋分岐の組合せ）    |
| `sub x0, x1, x0` | アドレス差分で文字数計算                      |
| `bss` セクション | 未初期化データ領域（`.space` で確保）         |
| 10 進数表示      | `print_uint` サブルーチン（UDIV + MSUB 使用） |

---

### S06: シリアル入力

**難易度**: ★★★☆☆

PL011 UART から文字を読み込み、エコーバックと文字種判定を行う対話型プログラム。

| 学習項目               | 説明                                 |
| :---                   | :---                                 |
| `uart_getc`            | UART 受信サブルーチン                |
| `UARTFR` bit 4（RXFE） | 受信 FIFO Empty（0 = データあり）    |
| `tbnz w9, #4, ug_wt`   | bit テスト＋非ゼロ分岐（データ待ち） |
| `ldrb w0, [x8]`        | UARTDR から受信データ読み込み        |
| エコーバック           | 受信文字をそのまま UART に出力       |
| `cmp w0, w9` + `b.lo/b.hi` | 符号なし範囲判定で文字種を分類  |

**入力処理の流れ**:

1. UARTFR（0x09000018）の bit 4（RXFE）をポーリング
2. RXFE = 0 になったら UARTDR（0x09000000）から 1 バイト読み込み

---

### S07: サブルーチン

**難易度**: ★★★☆☆

`BL` / `RET` による関数呼び出しと、レジスタ渡しのパラメータ受け渡しを学ぶ。

| 学習項目                    | 説明                                            |
| :---                        | :---                                            |
| `bl label`                  | サブルーチン呼び出し（LR = X30 に戻りアドレス） |
| `ret`                       | LR（X30）にジャンプして復帰                     |
| `stp x29, x30, [sp, #-16]!` | フレームポインタと LR を保存（関数プロローグ）  |
| `ldp x29, x30, [sp], #16`   | フレームポインタと LR を復元（関数エピローグ）  |
| リーフ関数                  | 他の関数を呼ばない関数（LR 保存不要）           |
| 引数レジスタ                | X0-X7（最大 8 個の引数）                        |
| 戻り値                      | X0                                              |

**ARM64 呼び出し規約**:

| レジスタ | 役割                            | 保存義務 |
| :---     | :---                            | :---     |
| X0-X7    | 引数 / 戻り値                   | なし     |
| X8       | 間接結果レジスタ                | なし     |
| X9-X15   | スクラッチレジスタ              | なし     |
| X16-X17  | intra-procedure-call スクラッチ | なし     |
| X18      | プラットフォーム予約            | —        |
| X19-X28  | 呼び出し保存レジスタ            | あり     |
| X29      | フレームポインタ                | あり     |
| X30 (LR) | リンクレジスタ                  | あり     |
| SP       | スタックポインタ                | —        |

---

### S08: ハードウェアアクセス

**難易度**: ★★★☆☆

ARM ジェネリックタイマー（CNTVCT_EL0）から時刻を読み取る。`MRS` 命令でシステムレジスタにアクセスする。

| 学習項目             | 説明                                         |
| :---                 | :---                                         |
| `mrs x0, CNTVCT_EL0` | システムレジスタからタイマーカウンタ読み出し |
| `mrs x0, CNTFRQ_EL0` | タイマー周波数の読み出し                     |
| システムレジスタ     | 通常のメモリアドレッシングではなく専用命令   |
| ハードウェアタイマー | システム時刻の高精度カウンタ                 |

---

### S09: 条件分岐

**難易度**: ★★★★☆

`CMP` / `TST` で NZCV フラグを設定し、`B.cond` で分岐するデモツリーを学ぶ。

| 学習項目          | 説明                                            |
| :---              | :---                                            |
| `cmp x0, x1`      | 比較（NZCV フラグのみ更新）                     |
| `tst x0, x0`      | AND テスト（符号判定に使用）                    |
| `b.eq` / `b.ne`   | 等しい / 等しくない（Z フラグ）                |
| `b.lt` / `b.gt`   | 符号付き 小さい / 大きい（N ≠ V, N = V）        |
| `b.mi` / `b.pl`   | 負 / 非負（N フラグ）                           |
| `b.lo` / `b.hi`   | 符号なし 未満 / より大きい（C フラグ）          |
| if-else チェーン  | 複数比較を連ねた判定ツリー（small / mid / big） |

---

### S10: ビット演算

**難易度**: ★★★★☆

AND / ORR / EOR / LSL / LSR を使い、ビット単位の操作を理解する。

| 学習項目             | 説明                                   |
| :---                 | :---                                   |
| `and x0, x0, #mask`  | ビット単位の AND（マスク抽出）         |
| `orr x0, x0, #mask`  | ビット単位の OR（ビット設定）          |
| `eor x0, x0, #mask`  | ビット単位の XOR（ビット反転）         |
| `lsl x0, x0, #count` | 左論理シフト（× 2^n）                  |
| `lsr x0, x0, #count` | 右論理シフト（÷ 2^n）                  |
| 2 進数表示           | LSR で 1 ビットずつ桁上げ → ASCII 変換 |

**応用例**:

- AND: 特定ビットの抽出（`and x0, x0, #0xFF`）
- ORR: 特定ビットのセット（`orr x0, x0, #0x80`）
- EOR: ビット反転（`eor x0, x0, #0xFF`）
- LSL: 高速乗算（`lsl x0, x0, #2` = ×4）

---

### S11: メモリ操作

**難易度**: ★★★★☆

メモリへのブロック単位の書き込み（memset）とコピー（memcpy）を実装する。pre-index / post-index アドレッシングも学ぶ。

| 学習項目             | 説明                                                  |
| :---                 | :---                                                  |
| `strb w1, [x3], #1`  | 書き込み後にアドレスをインクリメント（post-index）    |
| `ldrb w4, [x1], #1`  | 読み込み後にアドレスをインクリメント                  |
| `ldrb w0, [x4, #1]!` | アドレスを事前インクリメントして読み込み（pre-index） |
| post-index           | `[Xn], #imm` — アクセス後にポインタ進める             |
| pre-index            | `[Xn, #imm]!` — ポインタ進めてからアクセス            |
| `.space size`        | 未初期化メモリ領域の確保                              |

**memset / memcpy 実装パターン**:

```asm
// my_memset: 指定バイト数だけメモリを特定の値で埋める
my_memset:
    mov     x3, x0              // x3 = 開始アドレス
.ms_lp:
    cbz     x2, .ms_dn           // カウンタ = 0 なら終了
    strb    w1, [x3], #1         // 書き込み + アドレス進める
    subs    x2, x2, #1           // カウンタデクリメント
    b.ne    .ms_lp
.ms_dn:
    ret
```

---

### S12: ミニシェル（総合）

**難易度**: ★★★★★

これまでの全要素を組み合わせた対話型コマンドシェル（REPL）。

| 学習項目             | 説明                                         |
| :---                 | :---                                         |
| REPL                 | Read-Eval-Print Loop（`read_line` + `dispatch`） |
| `read_line`          | 1 行読み込み（エコー・バックスペース・null 終端） |
| `streq`              | 文字列比較によるコマンド解析                  |
| コマンドディスパッチ | 入力に応じた処理の分岐（if-else チェーン）    |
| バナー表示           | 起動時のタイトル表示                         |

**コマンド一覧**:

- `hello` — 挨拶メッセージを表示
- `count` — カウントダウン（5 4 3 2 1）
- `hex` — 0..F の 16 進表示
- `help` — コマンド一覧を表示
- `quit` — シェルを終了

---

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — ARM64 (AArch64) 命令セット完全リファレンス

## ハードウェア情報

### QEMU virt マシン

| 項目           | 値                              |
| :---           | :---                            |
| マシンタイプ   | `virt`                          |
| CPU            | `cortex-a57`                    |
| メモリ         | 128MB (0x40000000 - 0x47FFFFFF) |
| スタック       | 0x48000000（RAM 末尾）          |
| ロードアドレス | 0x40000000                      |
| 終了方法       | セミホスティング                |

### PL011 UART

| オフセット | レジスタ名 | 説明                     | アクセス |
| :---       | :---       | :---                     | :---     |
| `0x000`    | UARTDR     | データレジスタ（送受信） | R/W      |
| `0x018`    | UARTFR     | フラグレジスタ           | RO       |
| `0x024`    | UARTIBRD   | 整数ボーレート           | R/W      |
| `0x028`    | UARTFBRD   | 小数ボーレート           | R/W      |
| `0x030`    | UARTLCR_H  | ライン制御               | R/W      |
| `0x034`    | UARTCR     | 制御レジスタ             | R/W      |
| `0x038`    | UARTIFLS   | 割り込み FIFO レベル     | R/W      |
| `0x03C`    | UARTIMSC   | 割り込みマスク           | R/W      |

**UARTFR フラグビット**:

| ビット | 名前 | 説明                     |
| :---   | :--- | :---                     |
| 5      | TXFF | 送信 FIFO フル（1=満杯） |
| 4      | RXFE | 受信 FIFO 空（1=空）     |

**UART ベースアドレス**: `0x09000000`

**書き込み手順**:

1. UARTFR（0x09000018）の bit 5（TXFF）をチェック
2. TXFF = 0 になるまで待機
3. UARTDR（0x09000000）に文字を書き込み

**読み込み手順**:

1. UARTFR（0x09000018）の bit 4（RXFE）をチェック
2. RXFE = 0 になるまで待機（データ到着）
3. UARTDR（0x09000000）から 1 バイト読み込み

### ARM ジェネリックタイマー

| システムレジスタ | 説明                                    |
| :---             | :---                                    |
| `CNTVCT_EL0`     | 仮想カウンタ値（64-bit タイムスタンプ） |
| `CNTFRQ_EL0`     | タイマー周波数（Hz）                    |

**アクセス方法**:

```asm
mrs x0, CNTVCT_EL0    ; タイマーカウンタ読み出し
mrs x0, CNTFRQ_EL0    ; 周波数読み出し
```

## ビルドシステム

### ツールチェーン

```bash
# macOS (Xcode CLI Tools + Homebrew)
xcode-select --install
brew install lld qemu
```

### アセンブラ疑似命令（GNU as / Clang as）

| 疑似命令           | 動作                              |
| :---               | :---                              |
| `.section .text`   | コードセクション開始              |
| `.section .data`   | 初期化済みデータセクション        |
| `.section .bss`    | 未初期化データセクション          |
| `.section .rodata` | 読み取り専用データセクション      |
| `.global sym`      | シンボルを外部公開                |
| `.asciz "str"`     | ヌル終端文字列の定義              |
| `.byte val`        | 1 バイトデータ定義                |
| `.word val`        | 2 バイトデータ定義                |
| `.dword val`       | 4/8 バイトデータ定義              |
| `.space size`      | 未初期化領域の確保                |
| `.align n`         | 2^n バイトにアライメント          |
| `=label` 疑似      | `ldr xd, =label` でアドレスロード |

### Makefile の仕組み

```makefile
# アセンブラとリンカ
AS      = clang
LD      = ld.lld

# ターゲット（ARM64 ベアメタル）
ASFLAGS = --target=aarch64-none-elf -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib

# QEMU 起動
QEMU  = qemu-system-aarch64
QFLAGS = -machine virt -cpu cortex-a57 -nographic -semihosting
```

### リンカスクリプト (linker.ld)

```c
ENTRY(_start)          // エントリポイントは _start

SECTIONS {
    . = 0x40000000;    // RAM 先頭アドレス

    .text : {          // コードセクション
        *(.text)
    }

    .rodata : {        // 読み取り専用データ
        *(.rodata)
    }

    .data : {          // 初期化済みデータ
        *(.data)
    }

    .bss : {           // 未初期化データ
        *(.bss)
        *(COMMON)
    }
}
```

### セミホスティング終了

ARM64 ベアメタルでは、QEMU を終了するためにセミホスティングを使用する。

```asm
mov     x0, #0x18            // angel_SWIreason_ReportException
ldr     x1, =exit_reason     // { ADP_Stopped_ApplicationExit, 0 }
hlt     #0xF000

exit_reason:
    .dword 0x20026           // ADP_Stopped_ApplicationExit
    .dword 0x0               // subcode
```

## トラブルシューティング

### QEMU で起動しない場合

```bash
# ツールがインストールされているか確認
which clang ld.lld qemu-system-aarch64

# PATH を通す（必要に応じて）
export PATH=/opt/homebrew/opt/llvm/bin:$PATH
```

### ビルドエラー

- `clang: error: unknown argument` → `--target=aarch64-none-elf` が正しいか確認
- `ld.lld: error: unknown argument` → LLD がインストールされているか確認
- `undefined symbol: _start` → リンカスクリプトが正しく配置されているか確認

### UART が動作しない

- `0x09000000` が PL011 UART のベースアドレスか確認
- QEMU の `-machine virt` オプションが指定されているか確認
- 正しい QEMU バージョン（7.0+）を使用しているか確認

## 次のステップ

1. 各シナリオのソースを開き、コメントを読みながらコードを追う
2. `make dump S=s02_registers` で逆アセンブル結果を確認し、各命令の機械語を観察する
3. 即値を変更してビルド → 実行し、結果の変化を確認する
4. PL011 UART の設定レジスタ（UARTIBRD, UARTLCR_H, UARTCR）を操作してボーレートやフォーマットを変更してみる
5. S12 をベースに新しいコマンド（例: `echo`, `timer`）を追加してみる

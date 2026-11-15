# M68000 アセンブラ ワークショップ

M68000 アーキテクチャの bare-metal プログラミングを Goldfish TTY による I/O で学ぶ。共通シナリオ S01-S12 に加え、共通比較課題（s13 帯）と m68k 固有の拡張シナリオ（s101+ 帯）で段階的に実践。

## 前提条件

| ツール           | 用途         | インストール例              |
| :---             | :---         | :---                        |
| m68k-elf-as      | アセンブラ   | `brew install m68k-elf-gcc` |
| m68k-elf-ld      | リンカ       |                             |
| qemu-system-m68k | エミュレータ | `brew install qemu`         |

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

`make debug` は `debug.gdb` を明示的に読み込み、停止時の表示とレジスタ表示マクロを利用できる。

停止ごとのレジスタ・メモリの自動表示やログ保存は、[GDB によるリモートデバッグ](../../README.md#gdb-によるリモートデバッグ-qemu-系)を参照。

例外の観察（S102）: `make trace S=s102_trap` で TRAP #0 発生時の PC ジャンプ（ハンドラ先頭 0x42c）と例外スタックフレーム（SR・PC が SSP に積まれる際の A7 の変化）が命令単位で記録される。

## ディレクトリ構造

```text
.
├── linker.ld           # 共通リンカスクリプト（コードは 0x00000400、ベクタ領域 0x0-0x3FF を空ける）
├── Makefile
├── README.md
├── s01_hello.s        # シナリオ 1: Hello World
├── s02_registers.s    # シナリオ 2: レジスタと算術
├── s03_stack.s        # シナリオ 3: スタック操作
├── s04_loops.s        # シナリオ 4: ループと条件分岐
├── s05_strings.s      # シナリオ 5: 文字列操作
├── s06_serial_in.s    # シナリオ 6: シリアル入力
├── s07_subroutines.s  # シナリオ 7: サブルーチン
├── s08_hardware.s     # シナリオ 8: ハードウェアアクセス (RTC)
├── s09_branching.s    # シナリオ 9: 分岐と条件判断
├── s10_bitwise.s      # シナリオ 10: ビット演算
├── s11_memory.s       # シナリオ 11: メモリ操作
├── s12_minishell.s    # シナリオ 12: ミニシェル（総合）
├── s13_copybench.s    # シナリオ 13: コピー比較ベンチ（全アーキ共通課題）
├── s101_movem.s       # シナリオ 101: MOVEM.L 一括退避
└── s102_trap.s        # シナリオ 102: TRAP #0 と例外フレーム
```

## シナリオ一覧

### S01: Hello World

**難易度**: ★☆☆☆☆

最も基本的な bare-metal プログラム。Goldfish TTY に文字列を出力して無限ループで停止する。

| 学習項目                 | 説明                                               |
| :---                     | :---                                               |
| `.global _start`         | プログラム開始シンボルをエクスポート               |
| `move.l #0x4000, %sp`    | スタックポインタを RAM 先頭に設定                  |
| `lea msg1, %a0`          | メッセージアドレスをアドレスレジスタにロード       |
| `bsr print_str`          | サブルーチン呼び出し（BSR = Branch to SubRoutine） |
| `move.l %d0, 0xff008000` | Goldfish TTY に文字出力（MMIO）                    |
| `bra halt`               | 無条件ジャンプで無限ループ                         |

**QEMU 終了方法**: `Ctrl+C` で QEMU を終了

---

### S02: レジスタと算術

**難易度**: ★☆☆☆☆

データレジスタ（D0-D7）とアドレスレジスタ（A0-A7）の使い方と基本演算を学ぶ。

| 学習項目           | 説明                                               |
| :---               | :---                                               |
| `move.l #val, %d0` | 即値をデータレジスタにロード                       |
| `add.l #val, %d0`  | 即値を加算（加算後にフラグを更新）                 |
| `sub.l #val, %d0`  | 即値を減算                                         |
| `add.l %d1, %d0`   | レジスタ間の加算                                   |
| `mulu.w %d1, %d0`  | 16-bit 符号なし乗算（結果は D0 全体）              |
| `divu.w #div, %d0` | 16-bit 符号なし除算（商は D0 下位16ビット）        |
| `lea addr, %a0`    | 有効アドレスをアドレスレジスタにロード（疑似命令） |

**ポイント**: 除算の結果は、D0 の下位 16 ビットに商、上位 16 ビットに余りが格納される。

---

### S03: スタック操作

**難易度**: ★★☆☆☆

スタック（LIFO）の動作を理解し、MOVEM.L を使ったレジスタの一括保存・復元を学ぶ。

| 学習項目                  | 説明                                                 |
| :---                      | :---                                                 |
| `movem.l %d5-%d7, -(%sp)` | レジスタ群をスタックに PUSH（プレデクリメント）      |
| `movem.l (%sp)+, %d7-%d5` | レジスタ群をスタックから POP（ポストインクリメント） |
| LIFO                      | Last In, First Out（最後に入れたものが最初に出る）   |
| スタック順番              | `movem.l` のリスト順と逆になる（POP時）              |

**ポイント**: POP 時はレジスタリストを逆順に指定することで、正しい順序に復元できる。

---

### S04: ループと条件分岐

**難易度**: ★★☆☆☆

DBRA 命令と CMP + 条件ジャンプを使った反復処理を実装する。

| 学習項目           | 説明                                               |
| :---               | :---                                               |
| `dbra %d1, label`  | D1 をデクリメントし、D1≠0 ならジャンプ（16-bit用） |
| `cmp.l %d1, %d0`   | D0 と D1 を比較（フラグのみ更新）                  |
| `cmpi.l #val, %d0` | 即値と D0 を比較                                   |
| `blt label`        | より小さい（Less Than）ならジャンプ（符号付き）    |
| `bgt label`        | より大きい（Greater Than）ならジャンプ（符号付き）  |
| `beq label`        | 等しい（Equal）ならジャンプ                        |
| `bne label`        | 等しくない（Not Equal）ならジャンプ                |

**ポイント**: m68k の DBRA は CX ではなくデータレジスタを使用する。

---

### S05: 文字列操作

**難易度**: ★★☆☆☆

文字列の長さ測定（strlen）とコピー（strcpy）を実装する。ポインタ演算も学ぶ。

| 学習項目             | 説明                                            |
| :---                 | :---                                            |
| `move.b (%a0)+, %d0` | [A0] から 1 バイト読み込み、A0 をインクリメント |
| `move.b %d0, (%a1)+` | D0 を [A1] に書き込み、A1 をインクリメント      |
| `tst.b (%a0)+`       | [A0] の値をテスト（null チェック）              |
| `sub.l %a1, %a0`     | アドレスレジスタの差分を計算（文字数）          |
| `adda.l #4, %a0`     | A0 に 4 バイトを加算（アドレス演算）            |

**実装例**:

```asm
# strlen: null終端文字列の長さを返す
strlen:
    movem.l %a0, -(%sp)
    move.l  %a0, %a1        # 開始アドレス保存
.Lloop:
    tst.b   (%a0)+          # null までループ
    bne     .Lloop
    sub.l   %a1, %a0        # 終了 - 開始 = 長さ
    move.l  %a0, %d0
    subq.l  #1, %d0         # null 文字を除く
    movem.l (%sp)+, %a0
    rts
```

---

### S06: シリアル入力

**難易度**: ★★★☆☆

Goldfish TTY から文字列を読み込み、エコーバックする対話型プログラム。

| 学習項目              | 説明                                    |
| :---                  | :---                                    |
| Goldfish TTY レジスタ |                                         |
| `0xff008004`          | REG_BYTES_READY: 受信バッファのバイト数 |
| `0xff008008`          | REG_CMD: コマンド（3=読み込み）         |
| `0xff008010`          | REG_DATA_PTR: DMA 書き込み先アドレス    |
| `0xff008014`          | REG_DATA_LEN: 読み込むバイト数          |
| `move.b (%a0), %d0`   | DMA バッファからデータを読み込み        |
| ポーリングループ      | データが来るまで待機するループ          |

**入力処理の流れ**:

1. REG_BYTES_READY をチェックしてデータ有無を確認
2. REG_DATA_PTR にバッファアドレスを設定
3. REG_DATA_LEN に 1 を設定（1 バイト読み込み）
4. REG_CMD に 3 を設定（読み込みコマンド）
5. DMA バッファからデータを読み込む

---

### S07: サブルーチン

**難易度**: ★★★☆☆

BSR/RTS による関数呼び出しと、レジスタ渡しのパラメータ受け渡しを学ぶ。

| 学習項目                  | 説明                                               |
| :---                      | :---                                               |
| `bsr label`               | サブルーチン呼び出し（リターンアドレスを PUSH）    |
| `rts`                     | サブルーチンから復帰（スタックからアドレスを POP） |
| リーフ関数                | 他の関数を呼ばない関数（スタックフレーム不要）     |
| `movem.l %d0/%a0, -(%sp)` | 複数レジスタをスタックに保存                       |
| ネスト呼び出し            | 関数からさらに別の関数を呼び出す                   |

**例**: 関数のチェーン

```asm
# double(add3(5))
move.l #5, %d0      # 引数 5 を D0 に設定
bsr add3           # add3 を呼び出し（結果は D0 に返る）
bsr double_val     # double_val を呼び出し
```

---

### S08: ハードウェアアクセス (RTC)

**難易度**: ★★★☆☆

Goldfish RTC (Real-Time Clock) から時間を読み取る。メモリマップド I/O の実践。

| 学習項目              | 説明                                         |
| :---                  | :---                                         |
| Goldfish RTC レジスタ |                                              |
| `0xff006000`          | TIME_LOW: 32-bit カウンタの下位16ビット      |
| `0xff006004`          | TIME_HIGH: 32-bit カウンタの上位16ビット     |
| `move.l addr, %d0`    | メモリアドレスから値を読み込む               |
| メモリマップド I/O    | メモリアドレス空間にマップされたハードウェア |

**観察ポイント**: TIME_LOW がオーバーフローすると TIME_HIGH がインクリメントされる。遅延ループで時間の経過を確認できる。

---

### S09: 分岐と条件判断

**難易度**: ★★★★☆

様々な条件分岐命令と、複雑な条件式の構築方法を学ぶ。

| 学習項目           | 説明                       | 条件         |
| :---               | :---                       | :---         |
| `cmp.l %d1, %d0`   | 比較命令                   | D0 - D1      |
| `cmpi.l #val, %d0` | 即値比較                   | D0 - val     |
| `beq label`        | 等しい                     | ZF=1         |
| `bne label`        | 等しくない                 | ZF=0         |
| `blt label`        | より小さい（符号付き）     | SF≠OF        |
| `bgt label`        | より大きい（符号付き）     | ZF=0 ∧ SF=OF |
| `bge label`        | 以上（符号付き）           | SF=OF        |
| `ble label`        | 以下（符号付き）           | SF≠OF ∨ ZF=1 |
| `bcc label`        | キャリークリア             | CF=0         |
| `bcs label`        | キャリーセット             | CF=1         |
| `bhi label`        | より大きい（符号なし）     | CF=0 ∧ ZF=0 |
| `bls label`        | 以下（符号なし）           | CF=1 ∨ ZF=1 |
| `bmi label`        | マイナス                   | NF=1         |
| `bpl label`        | プラス                     | NF=0         |
| `tst.l %d0`        | テスト命令（自身との比較） | -            |

**ポイント**: 同じ比較でも符号付きと符号なしで結果が変わる。例えば `-1` は符号付きなら「より小さい」だが、符号なしでは非常に大きな値になる。

---

### S10: ビット演算

**難易度**: ★★★★☆

AND/OR/XOR/NOT とシフト演算を使ったビットレベルの操作を理解する。

| 学習項目            | 説明                              |
| :---                | :---                              |
| `and.l #mask, %d0`  | ビット単位の AND（マスク）        |
| `or.l #mask, %d0`   | ビット単位の OR（ビット設定）     |
| `eor.l #mask, %d0`  | ビット単位の XOR（ビット反転）    |
| `not.l %d0`         | ビット反転                        |
| `lsl.l #count, %d0` | 左シフト（Logical Shift Left）×2  |
| `lsr.l #count, %d0` | 右シフト（Logical Shift Right）÷2 |
| `rol.l #count, %d0` | 左ローテーション                  |
| `ror.l #count, %d0` | 右ローテーション                  |

**応用例**:

- AND: 特定ビットのマスク（`and.l #0xFF, %d0` → 下位 8 ビットだけ抽出）
- OR: 特定ビットのセット（`or.l #0x80, %d0` → 最上位ビットを 1 に）
- XOR: ビット反転（`eor.l #0xFF, %d0` → 下位 8 ビットを反転）

**表示ルーチン**: 16 進数と 2 進数の表示サブルーチンを実装。シフト演算で各ビットを 1 つずつ取り出す。

---

### S11: メモリ操作

**難易度**: ★★★★☆

メモリへのブロック単位の書き込み（memset）とコピー（memcpy）を実装する。

| 学習項目             | 説明                                              |
| :---                 | :---                                              |
| `move.b %d0, (%a0)+` | D0 を [A0] に書き込み、A0 をインクリメント        |
| `move.b (%a1)+, %d0` | [A1] から読み込み、D0 に格納、A1 をインクリメント |
| `post-increment`     | `(%a0)+` のように書き込み後にインクリメント       |
| `pre-decrement`      | `-(%a0)` のように前にインクリメント               |
| `.space size`        | 未初期化メモリ領域を確保                          |
| メモリブロック操作   | 連続したメモリ領域をまとめて操作                  |

**実装例**:

```asm
# my_memcpy: コピー元(a1)からコピー先(a0)へコピー
my_memcpy:
    movem.l %d0/%a0/%a1, -(%sp)
.Lloop:
    move.b  (%a1)+, %d0
    move.b  %d0, (%a0)+
    tst.b   %d0
    bne     .Lloop
    movem.l (%sp)+, %d0/%a0/%a1
    rts
```

---

### S12: ミニシェル（総合）

**難易度**: ★★★★★

これまでの全要素を組み合わせた対話型コマンドシェル。

| 学習項目             | 説明                                              |
| :---                 | :---                                              |
| REPL                 | Read-Eval-Print Loop（読み取り-評価-表示-ループ） |
| `read_line`          | 行入力サブルーチン（バックスペース対応）          |
| `strcmp`             | 文字列比較（a0 と a1 を比較）                     |
| コマンドディスパッチ | 入力文字列に応じて分岐                            |
| コマンド一覧         | `hello`, `help`, `quit`                           |

**コマンド一覧**:

- `hello` — 挨拶メッセージを表示
- `help` — ヘルプメッセージを表示
- `quit` — シェルを終了

**実装のポイント**:

- 入力バッファの管理（バックスペースで文字を消去）
- 文字列比較によるコマンド判定
- 無限ループによる継続的な入力処理

---

### S13: コピー比較ベンチ（全アーキ共通課題）

**難易度**: ★★★☆☆

全アーキテクチャ共通の比較課題。100 バイトのメモリコピーを `MOVE.B (An)+,(An)+` + `DBRA` ループで行い、宛先 100 バイトの 8 ビットずつの総和（チェックサム）を 16 進 4 桁で出力する。QEMU はサイクルを測れないため、コピー本体のサイクル数は 68000 公開タイミング表に基づく手計算でソースコメントに記載している。

| 学習項目                  | 説明                                                              |
| :---                      | :---                                                              |
| `move.b (%a0)+, (%a1)+`   | ポストインクリメントによるバイト転送（メモリ間 12 サイクル）      |
| `dbra`                    | ループカウンタ（分岐 10 / 終了 14 サイクル）                      |
| コピー本体のサイクル手計算 | コピー本体合計 2238 サイクルの内訳をコメント記載                  |
| 16 ビットチェックサム     | 0+1+...+99 = 4950 > 255 のため `add.w` で累算                     |
| 正誤判定                  | 0x1356 と比較し `COPY OK CHECKSUM=1356` / `COPY FAIL CHECKSUM=xxxx` |

**実行出力**: `COPY OK CHECKSUM=1356`（1 行のみ）

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: ソースコメントの手計算（コピー本体 2238 サイクル）の内訳を先に読み、1 バイト当たり `MOVE.B (An)+,(An)+` 12 + `DBRA` 10 = 22 サイクルという数字を自分でも導いてから、`make icount S=s13_copybench` で総命令数を測る（サイクルとは別物である点に注意）。
- **STEP 2 観察**: `make trace S=s13_copybench` で `.Lcopy` ループが `move.b` + `dbra` の 2 命令 × 100 回であることを確認する。`dbra` が比較命令なしでカウンタを減らしながら分岐する点（D2 が -1 になったら抜ける）もトレースで見る。
- **STEP 3 改造**: `MOVE.B` → `MOVE.L` に替えて 4 バイト/反復にする改造を考える（反復 25 回 + 端数）。`MOVE.L (An)+,(An)+` は 16 サイクル/4 バイト = 4 サイクル/バイトと 3 倍速いはず — この論理の落とし穴（アラインメント、端数処理）をソースコメントの記載と突き合わせて考える。
- **STEP 4 考察**: 68000 にもブロック転送命令は無い（PPC/RISC-V/ARM64 と同じ素朴ループ）。`compare/copybench.md` を参照し、手計算サイクル（2238）と実サイクロジック（Z80 LDIR 21T/バイト等）を同じ土俵で比べる練習をする。

---

### S101: MOVEM.L 一括退避

**難易度**: ★★★☆☆

サブルーチン冒頭で `MOVEM.L` により複数レジスタ（D0-D3/A0-A1）を 1 命令で一括退避・復帰する。個別 `MOVE.L` とのコードサイズ・サイクル差をコメントで比較する。

| 学習項目                   | 説明                                                            |
| :---                       | :---                                                            |
| `movem.l %d0-%d3/%a0-%a1, -(%sp)` | 6 レジスタを 1 命令（4 バイト）で退避                     |
| `movem.l (%sp)+, %d0-%d3/%a0-%a1` | 1 命令で復帰（リスト順に関係なく自動的に正しく復元）      |
| コードサイズ比較           | 6 レジスタ: MOVEM 4 バイト vs 個別 MOVE.L 12 バイト（コメント記載） |
| サブルーチン定石           | prologue/epilogue の典型パターン                                |

**実行出力**:

```text
Calling work (clobbers D0-D3/A0-A1)
  work: registers zeroed, then MOVEM restore
After return:
  D0 = 0x11111111
  D1 = 0x22222222
  D2 = 0x33333333
  D3 = 0x44444444
  A1 = 0xAAAA0000
MOVEM OK!
```

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: ソース冒頭の手計算（6 レジスタ退避: MOVEM 4 バイト / 56 サイクル vs 個別 MOVE.L 12 バイト / 48 サイクル）を読み、「MOVEM の方が遅いのに定石」というパラドクスの理由（コードサイズ・フェッチ帯域）を先に書き出す。
- **STEP 2 観察**: `make debug S=s101_movem` で work の入口にブレークを置き（`make dump S=s101_movem` で `work` のアドレスを確認して `b *ADDR`）、`movem.l` 実行前後で `info registers` の SP とレジスタを比べる。ポップ側 `movem.l (%sp)+` がリスト順に関係なく正しく復元することも確認する。
- **STEP 3 改造**: MOVEM を個別 `MOVE.L` × 6 に置き換えて動作を比較する（出力は同一になるはず）。さらに退避リストを `d0-%d3/%a0-%a1` から `d0-%d3/%a1/%a0` の順に替えても復帰が正しいことを予測してから試す。
- **STEP 4 考察**: x86 8086 には 1 命令で複数レジスタを退避する命令が無い（PUSH を並べる）。ARM64 は `STP`/`LDP` のペア転送（`arm64` の S101）、RISC-V は ABI で規約的に何を退避するか決める。レジスタ退避の「命令の粒度」をアーキ間で比べる。

---

### S102: TRAP #0 と例外フレーム

**難易度**: ★★★★☆

`TRAP #0`（例外ベクタ 32 = アドレス 0x80）にハンドラを登録し、例外スタックフレーム（SR と PC が SSP に積まれる）の内容を表示して `RTE` で復帰する。スーパーバイザモード（SR の S ビット）の説明はソースコメントに記載。

| 学習項目             | 説明                                                              |
| :---                 | :---                                                              |
| `trap #0`            | 例外ベクタ 32（アドレス 32×4 = 0x80）へディスパッチ               |
| ベクタ登録           | ハンドラのアドレスを 0x80 に書き込む（スーパーバイザ state で実行） |
| 例外スタックフレーム | SSP+0 に SR、SSP+2 に PC（68000 形式・6 バイト）が積まれる        |
| `rte`                | フレームをポップして復帰（サブルーチンの `rts` との対比）         |
| スーパーバイザモード | SR S ビット（0x2000）。TRAP は必ずスーパーバイザ state に遷移する |

**観察**: `make trace S=s102_trap` で例外発生時の PC ジャンプと A7（SSP）の変化が命令単位で見られる。

**実行出力**:

```text
TRAP #0 exception demo
Before TRAP #0
  [trap0 handler]
  SR = 0x2704
  (S bit = 0x2000: supervisor state)
  PC = 0x00000420
Back after RTE
```

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: 例外フレームは SSP+0 に SR（word）、SSP+2 に PC（longword）の 6 バイト。ハンドラ内でさらに 6 レジスタを `movem.l` 退避したとき、フレームの SR は SP からいくつ先に見えるか（出力では `24(%sp)` を読んでいる — その理由を先に計算する）。
- **STEP 2 観察**: `make trace S=s102_trap` で `trap #0` 実行時の PC ジャンプ（0x80 のベクタ経由でハンドラへ）と A7（SSP）の変化を命令単位で追う。ハンドラの `rte` 実行時に SSP が 6 バイト戻り、`SR = 0x2704` の S ビット（0x2000）が立った状態から復帰することも確認する。
- **STEP 3 改造**: `trap #0` → `trap #7` に変えるとベクタ 39（アドレス 0x9C）に飛ぶ。ハンドラ登録アドレスも 0x80 から 0x9C に替える必要があることを予測してから試す（未登録のベクタに TRAP するとどうなるかも考察する）。
- **STEP 4 考察**: x86 S102 は IVT（メモリ上のベクタテーブル）に CS:IP を積むスタック渡し、RISC-V S101 は mcause/mepc のレジスタ渡し、PPC S102 は SRR0/SRR1。m68k は「ベクタテーブル + スタックフレーム渡し」のハイブリッド。4 方式の情報の渡し方を表にまとめて比べる。

---

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — M68000 命令セット完全リファレンス

## ハードウェア情報

### QEMU virt マシン

| 項目         | 値                             |
| :---         | :---                           |
| マシンタイプ | `virt`                         |
| CPU          | `m68000`                       |
| メモリ       | 16MB (0x00000000 - 0x00FFFFFF) |
| グラフィック | テキストモードなし             |

### Goldfish TTY UART

| アドレス     | レジスタ名      | 用途                   |
| :---         | :---            | :---                   |
| `0xFF008000` | REG_DATA        | 文字出力（PUT_CHAR）   |
| `0xFF008004` | REG_BYTES_READY | 受信バッファのバイト数 |
| `0xFF008008` | REG_CMD         | コマンド（3=読み込み） |
| `0xFF00800C` | REG_STATUS      | ステータス             |
| `0xFF008010` | REG_DATA_PTR    | DMA 書き込み先アドレス |
| `0xFF008014` | REG_DATA_LEN    | 読み込むバイト数       |

**書き込み手順**:

1. `move.l char, 0xFF008000` → 文字を出力

**読み込み手順**:

1. `move.l 0xFF008004, %d0` → バイト数を確認
2. `lea buf, %a0` → バッファアドレスを設定
3. `move.l %a0, 0xFF008010` → DMA 書き込み先を設定
4. `move.l #1, 0xFF008014` → 1 バイト読み込み
5. `move.l #3, 0xFF008008` → 読み込みコマンド
6. `move.b (%a0), %d0` → データを読み込む

### Goldfish RTC (Real-Time Clock)

| アドレス     | レジスタ名 | 説明                          |
| :---         | :---       | :---                          |
| `0xFF006000` | TIME_LOW   | 32-bit カウンタの下位16ビット |
| `0xFF006004` | TIME_HIGH  | 32-bit カウンタの上位16ビット |

---

## ビルドシステム

### ツールチェーン

```bash
# macOS (Homebrew)
brew install m68k-elf-gcc qemu

# Linux (APT)
sudo apt install gcc-m68k-linux-gnu qemu-system-m68k
```

### Makefile の仕組み

```makefile
# アセンブラとリンカ
AS = m68k-elf-as
LD = m68k-elf-ld
OD = m68k-elf-objdump

# フラグ
ASFLAGS = -m68000        # 68000 命令セットを使用
LDFLAGS = -T linker.ld  # リンカスクリプトを使用

# QEMU 起動
QEMU = qemu-system-m68k
QFLAGS = -M virt -cpu m68000 -nographic
```

### リンカスクリプト (linker.ld)

```c
ENTRY(_start)          // エントリーポイントは _start

SECTIONS {
    . = 0x00000400;    // 例外ベクタテーブル領域 (0x0-0x3FF) を空けて配置
    
    .text : {          // コードセクション
        *(.text)
    }
    
    .rodata : {       // 読み取り専用データ
        *(.rodata)
    }
    
    .data : {         // 初期化済みデータ
        *(.data)
    }
    
    .bss : {          // 未初期化データ
        __bss_start = .;
        *(.bss)
        *(COMMON)
        __bss_end = .;
    }
}
```

### アセンブラ疑似命令（GNU as）

| 疑似命令             | 動作                              |
| :---                 | :---                              |
| `.section .text`     | コードセクション開始              |
| `.section .data`     | 初期化済みデータセクション        |
| `.section .bss`      | 未初期化データセクション          |
| `.section .rodata`   | 読み取り専用データセクション      |
| `.global sym`        | シンボルを外部公開                |
| `.asciz "str"`       | ヌル終端文字列の定義              |
| `.ascii "str"`       | 非終端文字列の定義                |
| `.byte val`          | 1 バイトデータ定義                |
| `.word val`          | 2 バイトデータ定義                |
| `.long val`          | 4 バイトデータ定義                |
| `.space size`        | 未初期化領域の確保                |
| `.align n`           | 2^n バイトにアライメント          |
| `.equ sym, val`      | 定数定義                          |

### Makefile ターゲット

| ターゲット | 説明                                        |
| :---       | :---                                        |
| `all`      | 全シナリオをビルド（デフォルトターゲット）  |
| `run`      | 特定シナリオを実行（`make run S=s01_hello`）|
| `runall`   | 全シナリオをビルド + 連続実行               |
| `dump`     | 逆アセンブル（`make dump S=s01_hello`）     |
| `clean`    | 生成ファイルを削除                          |

### 終了方法

M68000 ベアメタルにはプログラム終了の概念がない。QEMU では CPU を無限ループで停止させ、`timeout --foreground 1` で強制終了する。

```asm
halt:
    bra halt          ; 無限ループ（CPU 停止）
```

---

## I/O ルーチン

M68000 ベアメタル（QEMU `virt` マシン）では、**プログラムが呼び出せる外部 I/O コール（BIOS・システムコール・セミホスティング・終了デバイス等）は提供されない**。すべての入出力と時刻取得はハードウェアレジスタ（MMIO）の直接操作、プログラムの終了は CPU の停止（無限ループ）による。

| 操作         | 方法                              | 参照先                                                         |
| :---         | :---                              | :---                                                           |
| 文字出力     | Goldfish TTY MMIO（`0xFF008000`） | [Goldfish TTY UART](#goldfish-tty-uart) の `REG_DATA` へ `move.l` |
| 文字入力     | Goldfish TTY DMA 読込             | 同上の `REG_BYTES_READY` → `REG_DATA_PTR`/`REG_DATA_LEN`/`REG_CMD=3` |
| 時刻取得     | Goldfish RTC MMIO（`0xFF006000`） | [Goldfish RTC (Real-Time Clock)](#goldfish-rtc-real-time-clock) |
| プログラム終了 | 無限ループ（`bra halt`）        | [終了方法](#終了方法)。QEMU を `timeout --foreground 1` で停止 |

**他アーキテクチャとの対比**: ARM64（semihosting）、RISC-V（SiFive test device）、x86（BIOS 割り込み）、6502（cc65 ランタイム）、Z80（CP/M BDOS）のような、QEMU・ROM・OS が提供する終了デバイスやシステムコールは **`virt` マシンでは接続されていない**。Goldfish デバイス自体は終了機能を持たないため、`bra halt` で CPU を停止させた上で外部から QEMU を終了する必要がある。これは教材が選んだ QEMU マシン設定の制約である。

**定義元**: 該当なし（外部コール ABI は存在しない）。I/O は Goldfish TTY / Goldfish RTC の MMIO レジスタ仕様に従う。

---

## トラブルシューティング

### QEMU で起動しない場合

```bash
# ツールがインストールされているか確認
which m68k-elf-as m68k-elf-ld qemu-system-m68k

# PATH を通す（必要に応じて）
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
```

### ビルドエラー

- `m68k-elf-as: command not found` → ツールチェーンがインストールされていない
- `Undefined symbol: _start` → リンカスクリプトが正しくない
- `QEMU: Unable to find VNC display` → `QEMU` の `-nographic` オプションが効いていない

### Goldfish TTY が動作しない

- アドレス `0xFF008000` が正しいことを確認
- QEMU の実行オプションで `-M virt` を指定していることを確認
- 他の virt マシンとハードウェアが競合していないか確認

## 次のステップ

1. **コードを追いながら読む**: 各シナリオのコメントを読みながら実行フローを追う
2. **逆アセンブルしてみる**: `make dump S=s02_registers` で生成される機械語を確認
3. **値を変更する**: 即値を変えてビルド・実行し、結果の変化を観察
4. **デバッグ技**: 特定のアドレスに値を書き込むことで、プログラムの動作を検証
5. **組み合わせる**: S12 を参考に、新しいコマンドを追加してみる（例: `echo`, `time`）

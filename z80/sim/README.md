# Z80 アセンブリ学習教材 (CP/M シミュレータ)

`z80asm` + Go製Z80シミュレータ(`simz80`)によるハンズオン教材。CP/M BDOS呼び出し規約を使用。

## 実行環境

| ツール | 用途 | インストール |
|---|---|---|
| `z80asm` | アセンブラ | `brew install z80asm` |
| `simz80` | Z80+CP/Mシミュレータ (Go) | `go build -o simz80 main.go` |

## ビルド & 実行

```sh
make all      # 全シナリオをビルド
make runall   # 全シナリオをビルド + 実行 (timeout 1秒付き)
make run S=s01_hello   # 個別実行
make cpm      # CP/M互換ファイルをcpm/に生成 (yaze-ag用)
make clean    # 生成物を削除
```

## yaze-ag (CP/M 3.1 エミュレータ) での実行

[yaze-ag](https://github.com/andreasgerlich/yaze-ag) で実際のCP/M環境上で .com を実行できる。

### 準備

```sh
# 1. yaze-ag をインストール
#    macOS:
brew install yaze-ag
#    Termux (proot-debian):
#      see https://github.com/andreasgerlich/yaze-ag — build from source

# 2. yaze-ag ディスクイメージを ~/cpm/ に配置 (初回のみ)
make cpm-setup

# 3. CP/M互換ファイルをビルド (アンダースコアなしファイル名)
make cpm
```

CP/Mのファイル名に `_` は使えないため、`make cpm` はアンダースコアを除去したコピーを `cpm/` に生成する:

| simz80用 | CP/M用 (cpm/) |
|---|---|
| `s01_hello.com` | `s01hello.com` |
| `s02_registers.com` | `s02registers.com` |
| ... | ... |

### .yazerc 設定

`$HOME/cpm/.yazerc` に以下を記述:

```
mount a <yaze-ag-disks>/BOOT_UTILS.ydsk
mount b <yaze-ag-disks>/CPM3_SYS.ydsk
mount c <repo-root>/z80/sim/cpm
go
```

### 実行例

```
$ yaze

A>c:s01
Hello, Z80 World!

A>e
```

| 操作 | コマンド |
|---|---|
| モニタに入る (CP/M→モニタ) | `A>sys` |
| CP/Mに戻る (モニタ→CP/M) | `$>go` |
| ディレクトリをマウント | `$>mount c <path>` |
| リマウント (ファイル変更後) | `$>mount c <path>` |
| yaze-ag終了 | `e` |

## シナリオ一覧

| # | テーマ | 学習内容 |
|---|---|---|
| s01 | Hello World | BDOS fn 2 (文字出力) |
| s02 | レジスタ | LD, ADD, SUB, INC, DEC, レジスタペア |
| s03 | スタック | PUSH/POP, LIFO, ネスト |
| s04 | ループ | DJNZ, JR, カウントダウン/アップ, ネスト |
| s05 | 文字列 | 文字列長, コピー, 大文字変換 |
| s06 | 入力 | BDOS fn 1 (コンソール入力) |
| s07 | サブルーチン | CALL/RET, 引数渡し, スタックフレーム |
| s08 | ハードウェア | BDOS fn 12 (バージョン), I/Oポート読み取り |
| s09 | 条件分岐 | CP, JR/Z/NZ/C/NC, 分岐テーブル |
| s10 | ビット演算 | AND, OR, XOR, CPL, SLA, SRA, SRL, BIT, SET, RES |
| s11 | メモリ | fill, copy, IX/IY インデックスアドレッシング |
| s12 | インタラクティブ | BDOS fn 10 (行入力), コマンド解析, 簡易シェル |
| **s13** | **裏レジスタ** | **EXX, EX AF,AF', ISR コンテキスト保存/復元** |

## s13: 裏レジスタ (Shadow Registers) 解説

### Z80の2組のレジスタ

Z80は「メイン」と「裏(shadow/alternate)」の2組のレジスタを持つ:

```
 メイン:  A   F   B   C   D   E   H   L
   裏:  A'  F'  B'  C'  D'  E'  H'  L'
```

### 入れ替え命令

| 命令 | 動作 | サイクル |
|---|---|---|
| `EXX` | BC↔BC', DE↔DE', HL↔HL' (3ペア同時) | 1 |
| `EX AF,AF'` | AF↔AF' | 1 |

**IX, IY, SPには裏レジスタがない。**

### なぜ裏レジスタがあるのか

主な用途は **割り込みハンドラ(ISR)での高速コンテキスト保存**:

```asm
; ISR開始 — 2命令で全レジスタ退避 (スタック不要!)
exx
ex  af, af'

; ... ISR本体 (BC, DE, HL, A を自由に使用) ...

; ISR終了 — 2命令で全レジスタ復元
exx
ex  af, af'
```

従来のPUSH/POPによる保存と比較:

| 方法 | 命令数 | スタック使用量 | 実行速度 |
|---|---|---|---|
| PUSH/POP × 4 | 8命令 (PUSH×4 + POP×4) | 8バイト | 遅い |
| EXX + EX AF,AF' | **2命令** | **0バイト** | **高速** |

### s13 の実行例

```
=== s13: Shadow Registers ===
--- Step 1: Set main registers ---
Main:       BC=1234  DE=5678  HL=9ABC  A=42

--- Step 2: EXX + EX AF,AF' ---
Shadow:     BC=ABCD  DE=EF01  HL=2345  A=99

--- Step 3: Swap back to main ---
Restored:   BC=1234  DE=5678  HL=9ABC  A=42    ← 元の値が復元!

--- Step 4: ISR context save/restore ---
Pre-ISR:    BC=AAAA  DE=BBBB  HL=CCCC  A=DD
In ISR:     BC=1111  DE=2222  HL=3333  A=44
Post-ISR:   BC=AAAA  DE=BBBB  HL=CCCC  A=DD    ← ISR後も復元!
```

## ファイル構成

```
z80/sim/
├── cmd/simz80/
│   ├── main.go          # Go製 Z80+CP/M シミュレータ
│   └── go.mod           # Go モジュール定義
├── Makefile         # ビルド・実行ルール
├── README.md        # このファイル
├── s01_hello.asm    # Hello World
├── s02_registers.asm
├── s03_stack.asm
├── s04_loops.asm
├── s05_strings.asm
├── s06_serial_in.asm
├── s07_subroutines.asm
├── s08_hardware.asm
├── s09_branching.asm
├── s10_bitwise.asm
├── s11_memory.asm
├── s12_minishell.asm
└── s13_shadow.asm   # 裏レジスタ
```

## CP/M 2.2 BDOS 呼び出し規約

本教材は CP/M の BDOS 関数を `CALL 0x0005` で呼び出す。
**★** = simz80 で実装済み。

### コンソール・文字入出力

| 関数 (C) | 機能 | 入力 | 出力 |
|---|---|---|---|
| ★ 1 | コンソール入力 (待機) | — | A = 文字 |
| ★ 2 | コンソール出力 | E = 文字 | — |
| 3 | リーダ入力 (_auxin) | — | A = 文字 |
| 4 | パンチ出力 (_auxout) | E = 文字 | — |
| 5 | リスト出力 (_printer) | E = 文字 | — |
| 6 | ダイレクトコンソール I/O | E = 0xFF (入力) / 文字 (出力) | A = 文字 (入力時) |
| ★ 9 | 文字列出力 ($終端) | DE = アドレス | — |
| ★ 10 | コンソール行入力 | DE = バッファアドレス | バッファに格納 |
| 11 | コンソールステータス取得 | — | A = 0x00 (なし) / 0xFF (あり) |

### システム・ディスク管理

| 関数 (C) | 機能 | 入力 | 出力 |
|---|---|---|---|
| 0 | システムリセット | — | — |
| ★ 12 | バージョン番号取得 | — | HL = バージョン |
| 13 | ディスクシステムリセット | — | — |
| 14 | ディスク選択 | E = ドライブ番号 | — |
| 24 | ログインベクタ取得 | — | HL = ログインベクタ |
| 25 | カレントディスク取得 | — | A = ドライブ番号 |
| 26 | DMA アドレス設定 | DE = アドレス | — |
| 27 | アロケーションベクタアドレス取得 | — | HL = アドレス |
| 28 | ディスク書き込み保護 | — | — |
| 29 | リードオンリーベクタ取得 | — | HL = ベクタ |
| 31 | ディスクパラメータブロックアドレス | — | HL = DPB アドレス |
| 32 | ユーザーコード取得/設定 | E = 0xFF (取得) / コード (設定) | A = ユーザーコード (取得時) |
| 37 | ドライブリセット | DE = ドライブマップ | A = 0x00 |

### ファイル操作

| 関数 (C) | 機能 | 入力 | 出力 |
|---|---|---|---|
| 15 | ファイルオープン | DE = FCB アドレス | A = ディレクトリコード |
| 16 | ファイルクローズ | DE = FCB アドレス | A = ディレクトリコード |
| 17 | ファイル検索 (先頭) | DE = FCB アドレス | A = ディレクトリコード |
| 18 | ファイル検索 (継続) | — | A = ディレクトリコード |
| 19 | ファイル削除 | DE = FCB アドレス | A = ディレクトリコード |
| 20 | 順次読み込み | DE = FCB アドレス | A = エラーコード |
| 21 | 順次書き込み | DE = FCB アドレス | A = エラーコード |
| 22 | ファイル作成 | DE = FCB アドレス | A = ディレクトリコード |
| 23 | ファイル名変更 | DE = FCB アドレス | A = ディレクトリコード |
| 30 | ファイル属性設定 | DE = FCB アドレス | A = ディレクトリコード |
| 33 | ランダム読み込み | DE = FCB アドレス | A = エラーコード |
| 34 | ランダム書き込み | DE = FCB アドレス | A = エラーコード |
| 35 | ファイルサイズ計算 | DE = FCB アドレス | FCB の r フィールドにレコード数 |
| 36 | ランダムレコード設定 | DE = FCB アドレス | FCB の r フィールドに設定 |
| 40 | ランダム書き込み (ゼロフィル) | DE = FCB アドレス | A = エラーコード |

### I/O バイト

| 関数 (C) | 機能 | 入力 | 出力 |
|---|---|---|---|
| 7 | I/O バイト取得 | — | A = IOBYTE |
| 8 | I/O バイト設定 | E = IOBYTE | — |

### 呼び出し規約

- **呼び出し**: レジスタ C に関数番号、DE に引数をセットして `CALL 0x0005`
- **戻り値**: A (または HL) に結果。A=0x00 は成功、0xFF は失敗を示すことが多い
- **終了**: プログラムは `RET` で終了。SPに積まれた `0x0000` に戻るとシミュレータが停止する

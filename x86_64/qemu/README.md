# x86-64 アセンブラ ワークショップ（QEMU フロッピーブート版）

QEMU フロッピーディスクイメージから SeaBIOS で起動し、16-bit ブートコード → 32-bit 保護モード → 64-bit ロングモードへ移行して、16550 UART (COM1, I/O 0x3F8) を I/O に使う x86-64 ベアメタルアセンブリ言語教材。共通シナリオ S01-S13 で段階的に学ぶ。

> **現状 (Phase 1: ブート基盤)**: S01 のみ実装済み。S02 以降は `docs/x86_64_qemu_plan.md` の Phase 2-4 で追加する。

## 前提条件

| ツール           | 用途                   | インストール例           |
| :---             | :---                   | :---                     |
| NASM             | アセンブラ             | `brew install nasm`      |
| ld.lld           | リンカ                 | `brew install llvm`      |
| QEMU (x86_64)    | エミュレータ           | `brew install qemu`      |
| GNU coreutils    | QEMU プロセス回収 (`timeout`) | `brew install coreutils` |
| gdb              | ステップデバッガ       | `brew install gdb`       |
| ndisasm          | 逆アセンブル (`make dump`) | NASM に同梱          |
| python3          | 出力検証 (`make test`) | —                        |

## ビルドと実行

```bash
make                  # 全シナリオをビルド (bin サイズ検査 + 1.44MB イメージ生成)
make run S=s01_hello  # 特定のシナリオを QEMU で実行 (1 秒のタイムアウト付き)
make test             # シナリオのシリアル出力を期待値と照合
make clean            # 生成物を削除
```

すべてのシナリオは共通の `boot.asm` を経由して起動する。`boot.asm` が 16-bit リアルモードでディスク（セクタ 2 以降の 32KB）を 0x7E00 へロードし、移行スタブが A20 有効化 → GDT → CR0.PE = 1 で保護モードに入り、PML4/PDPT/PD（0x1000-0x3FFF, 2MB ページで下位 1GB を identity map）を構築して CR4.PAE → CR3 → EFER.LME → CR0.PG の順でロングモードを有効化した後、0x8000 に配置されたシナリオの `_start` へジャンプする。シナリオ側のソースは `cpu x64` + `bits 64` で書く。

シナリオの追加は `s*.asm` を置くだけで良い（`SCENARIOS` は wildcard で自動検出する）。

## デバッグ

```bash
# QEMU を -S -gdb tcp:127.0.0.1:1234 で起動し gdb を接続 (ステップ実行)
make debug S=s01_hello

# 命令ごとの逆アセンブル + CPU 状態を s01_hello.trace に記録して less で閲覧
make trace S=s01_hello

# 実行命令数を集計 (実サイクルは make cycles が unsupported を表示)
make icount S=s01_hello

# 逆アセンブル (0x8000 のシナリオ部分のみ、64-bit)
make dump S=s01_hello
```

### make debug

QEMU を `-S`（起動時停止 + gdbstub）でバックグラウンド起動し、gdb をフォアグラウンドで接続する。リモートプロトコルに認証はないため待ち受けは loopback に限定する。

マクロは `debug.gdb` に定義し `-x debug.gdb` で明示ロードする（`.gdbinit` 自動ロードは使わない）。`regs64` マクロで RAX〜RDI、セグメントレジスタ、RIP、EFLAGS（CF/PF/AF/ZF/SF/OF を展開。QEMU の gdbstub は `$rflags` を提供しないため `$eflags` を使用）を表示し、`hook-stop` で毎ストップ時に自動表示する。`_start` 停止時の出力例（s01_hello）:

```text
RAX=0000000080000000 RBX=000000000000fe00 RCX=0000000000000000 RDX=0000000000000000
RSI=0000000000000004 RDI=0000000000008043 RBP=0000000000000000 RSP=0000000000090000
CS=0018 DS=0010 ES=0010 SS=0010 FS=0000 GS=0000
RIP=0000000000008000 EFLAGS=00000046
CF=0 PF=1 AF=0 ZF=1 SF=0 OF=0
```

CS = 0x18（64-bit コードセグメント）で、CR0 は PG + PE、CR4.PAE = 1、CR3 = 0x1000（PML4）になっている。

### make trace / make icount / make cycles / make dump

- `trace` は `-accel tcg,one-insn-per-tb=on -d in_asm,cpu -dfilter 0x8000+0x7e00` でカーネル領域のみ命令単位のログを記録し、`scenario_halt`（HLT 位置）に到達したら打ち切る
- `icount` は同じ起動で `-d cpu` のみのログを集計する。`-d cpu` の RIP 行は `RIP=0000000000008000 RFL=...`（16 桁、実測）なのでそれを終了判定に使う。cli/hlt は除外した値を表示する
- `cycles` は QEMU TCG がサイクル精度でないため unsupported を表示する
- `dump` は `ndisasm -b 64 -o 0x8000 -e 1024` でシナリオ部分のみ 64-bit 逆アセンブルする（先頭 1024 バイトは 16/32/64-bit 混在のブート部のためスキップ）

## ディレクトリ構造

```text
.
├── boot.asm           # ブートセクタ (`.boot`) + ロングモード移行スタブ (`.stub`)
├── linker.ld          # リンカスクリプト（フラットバイナリ出力）
├── linker-debug.ld    # デバッグ用リンカスクリプト（ELF64 出力、同一配置）
├── Makefile
├── README.md
├── debug.gdb          # gdb マクロ（`-x` で明示ロード）
├── count_instructions.py  # icount 集計（RIP 行を終了判定に使用）
├── trace_scenario.py  # トレース記録（上限付き）
├── test_scenarios.py  # シリアル出力の期待値照合
└── s01_hello.asm      # S01: Hello World
```

## CPU と実行環境

- ソースは `cpu x64` + `bits 64`（boot.asm のみ `bits 16`/`bits 32` を含む）、NASM `-f elf64`、リンカは `ld.lld -m elf_x86_64`。
- 実行モードは **64-bit ロングモード、CPL=0**。ページング有効（下位 1GB を 2MB ページで identity map）、IF=0（IDT 未構築のため STI しない）。セグメントはフラット（base=0）。
- スタックは RSP=0x90000 から下方成長。`.bss` は移行スタブの 64-bit 部がリンカシンボル（`__bss_start`/`__bss_end`）を使ってゼロ初期化するため、シナリオ側の初期化は不要。
- QEMU は `qemu-system-x86_64 -machine pc -accel tcg -cpu qemu64`。CPU モデル（qemu64）と命令セット制限（NASM `cpu x64`）は別の概念である: `-cpu qemu64` は QEMU がエミュレートする CPU モデル、`cpu x64` はアセンブラが受け付ける命令の範囲の上限である。
- 終了は `cli; hlt` のループ。QEMU は HLT 後も動き続けるため `timeout` で回収し、`-no-reboot -no-shutdown` で障害時の再起動を抑止する。
- 引数はレジスタ渡しとし、保存対象レジスタを関数ごとに明示する。System V AMD64 呼び出し規約に合わせ、CALL 直前の RSP を 16 の倍数、関数入口は RSP % 16 = 8 とする（S03 で学習）。

`make test` は各シナリオの QEMU シリアル出力の主要な期待文字列を照合する（テストは一時ディレクトリにコピーしたイメージで実行し、ビルド済みの img は書き換えない）。全出力や実機互換性の保証ではない。QEMU の実行時間を実機性能の比較に使わないこと。

## シナリオ一覧

現状 S01 のみ（Phase 2-4 で S02-S13、S101+ を追加）。

### S01: Hello World ★

- ブート → 移行スタブ（16 → 32 → 64）→ `_start` の通電確認
- `lea rsi, [rel message]`（RIP 相対）+ `lodsb` で NULL 終端文字列を送出
- `uart_putc`（16550 ポーリング OUT）で COM1 へ 1 文字ずつ出力

```bash
make run S=s01_hello
# Hello, x86_64 World!
```

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — x86-64 命令セットリファレンス
- [`../../docs/x86_64_qemu_plan.md`](../../docs/x86_64_qemu_plan.md) — 本ディレクトリの整備計画（フェーズと受入条件）
- [`../../compare/copybench.md`](../../compare/copybench.md) — 共通課題 s13（100 バイトコピー）の全アーキ比較
- [`../../README.md`](../../README.md) — リポジトリ全体のガイド（デバッグガイド・シナリオ規約）
- [`../../x86_16/qemu/README.md`](../../x86_16/qemu/README.md) — 16-bit リアルモード版（構成のテンプレート）
- [`../../x86_32/qemu/README.md`](../../x86_32/qemu/README.md) — 32-bit 保護モード版（16 → 32 の移行を学ぶ）

## ハードウェア情報

### QEMU 起動構成

| 項目               | 値                                                              |
| :---               | :---                                                            |
| QEMU バイナリ      | `qemu-system-x86_64`                                            |
| マシン / CPU       | `-machine pc -accel tcg -cpu qemu64`                            |
| 障害時動作         | `-no-reboot -no-shutdown`（トリプルフォルトで QEMU 終了）       |
| フロッピー         | 2880 セクタ（1.44MB）、`dd` で `.bin` を先頭に書き込み          |
| 起動ファームウェア | SeaBIOS（フロッピーからブートセクタを 0000:7C00 へロード）      |
| 終了方法           | `cli; hlt` の停止ループ後、`timeout`（既定 1 秒）で QEMU を回収 |
| 入力（S06/S12）    | `make runall` 時に `printf` でパイプ入力（Phase 2 で使用）      |

### 16550 UART (COM1)

| I/O ポート | レジスタ名 | 説明                                   | アクセス |
| :---       | :---       | :---                                   | :---     |
| `0x3F8`    | THR / RBR  | 送信保持 / 受信バッファ                | W / R    |
| `0x3FD`    | LSR        | ラインステータスレジスタ               | R        |

**LSR フラグビット**:

| ビット | 名前   | 説明                                   |
| :---   | :---   | :---                                   |
| 0      | DR     | Data Ready — 1 = 受信データあり         |
| 5      | THRE   | Transmitter Holding Register Empty — 1 = 送信可能 |

**送信手順**: LSR (0x3FD) の bit 5 (THRE) をポーリングし、1 になったら THR (0x3F8) に文字を書き込む（`in al, dx` → `test al, 0x20` → `jz` → `out dx, al`）。ポート番号は DX レジスタ経由（`mov dx, 0x3FD`）。IN/OUT 命令と DX ポート指定は 16/32-bit 版と同一（ロングモードでも不変）。

### アドレスマップ

| アドレス        | 用途                                                     |
| :---            | :---                                                     |
| `0x1000-0x3FFF` | ページテーブル（PML4 / PDPT / PD、各 4KB）               |
| `0x7C00-0x7DFF` | ブートセクタ（署名 0xAA55 は 0x7DFE）                    |
| `0x7E00-0x7FFF` | ロングモード移行スタブ（最大 512 バイト）                |
| `0x8000-0xFDFF` | シナリオのロード領域（`.text` / `.rodata` / `.data`）    |
| `0x8E000`       | `.bss` 上限（`linker.ld` の ASSERT でスタック予約と非重複を検査） |
| `0x90000`       | スタックトップ（下方成長）                               |
| `0xFE00`        | ロードイメージ終端の上限（0xFE00 - 0x7C00 = 33280 バイト制限に対応） |

ロングモード移行に使う初期ページングは下位 1GB を 512 個の 2MB ページで identity map する（PML4[0] → PDPT[0] → PD[i] = i x 2MB、P | RW | PS = 0x083）。ロングモードの 2MB ページは PML4 → PDPT → PD で解決し PT は参照しない。`.bss` は移行スタブの 64-bit 部が `__bss_start`..`__bss_end` を `rep stosb` でゼロ初期化する。リンカの ASSERT がブートセクタ 512 バイト、スタブ 512 バイト、イメージ上限、`.bss` とスタック予約領域の非重複をビルド時に検査する。

## I/O ルーチン

本教材は文字入出力に 16550 UART（COM1, `0x3F8`）の I/O ポートを直接操作する方針（「ハードウェア情報」の [16550 UART (COM1)](#16550-uart-com1) を参照）。

**BIOS 割り込み (`INT` 命令) の使用範囲**: ブート直後の **16-bit リアルモード区間のみ**。`boot.asm` の INT 13h AH=02h（ディスク読み込み、AH=00h はエラー時のリセット）だけである。ロングモード移行後は IDT が無いため `INT` 命令も使えず、出力はすべて UART の直接ポーリングで行う。

**定義元**: QEMU が読み込む SeaBIOS ROM。

**uart_putc / uart_getc の実装位置**:

| 場所                    | 名前                     | ビット幅 | 使われる場面                     |
| :---                    | :---                     | :---     | :---                             |
| `boot.asm` (`.boot`)    | `uart_putc16`            | 16-bit   | ディスク読み込み失敗時の通知     |
| 各シナリオ `.asm`       | `uart_putc` / `uart_getc` | 64-bit  | シナリオ本体の出力・入力         |

`uart_putc` は LSR bit 5 (THRE) 待ち → THR 書き込み、`uart_getc` は LSR bit 0 (DR) 待ち → RBR 読み込み（Phase 2 の S06 で導入）。いずれもポーリングのみで割り込みは使わない。

## 次のステップ

1. `boot.asm` のコメントを読み、ブート → スタブ（16 → 32 → 64）→ `_start` の流れを追う
2. `make dump S=s01_hello` で 0x8000 以降の 64-bit コードを逆アセンブルし、ソースと突き合わせる（ブート部分は `ndisasm -b 16 -o 0x7C00`、スタブ部分は `ndisasm -b 32 -o 0x7E00 -e 512` で別途観察する）
3. `make debug S=s01_hello` で `_start` に止め、CS = 0x18（64-bit コード）、CR0.PG + PE、CR4.PAE、CR3 = 0x1000、RSP = 0x90000 を `info registers` で確認する
4. メッセージを書き換えて `make run S=s01_hello` と `make test` で確認する
5. S02 以降は `docs/x86_64_qemu_plan.md` の Phase 2-4 の計画に従って追加する

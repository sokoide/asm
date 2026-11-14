# アセンブリ言語学習教材

複数の CPU アーキテクチャに対するアセンブリ言語のハンズオン学習教材です。
各アーキテクチャで同じテーマ（Hello World、レジスタ、スタック、ループ、文字列操作など）を順に学習できる構成になっています。

## 対応アーキテクチャ

| アーキテクチャ   | ディレクトリ      | 実行環境                        | シナリオ数 |
| :---             | :---              | :---                            | :---       |
| **6502**         | `6502/sim65/`     | sim65 シミュレータ (cc65)       | 12         |
| **ARM64**        | `arm64/qemu/`     | QEMU virt マシン (bare-metal)   | 12         |
| **PowerPC**      | `ppc/qemu/`       | QEMU bamboo マシン (bare-metal) | 12         |
| **M68000**       | `m68k/qemu/`      | QEMU virt マシン (bare-metal)   | 12         |
| **Z80**          | `z80/sim/`        | Go製 CP/M シミュレータ          | 13         |
| **x86 (16-bit)** | `x86_16/qemu/`    | QEMU i386 フロッピーブート      | 14         |
| **x86 (16-bit)** | `x86_16/dos/com/` | DOSBox (COM)                    | 1          |
| **x86 (16-bit)** | `x86_16/dos/exe/` | DOSBox (MZ EXE)                 | 14         |
| **x86 (64-bit)** | `x86_64/darwin/`  | macOS ネイティブ                | 1          |
| **x86 (32-bit)** | `i386/darwin/`    | macOS ネイティブ                | 1          |
| **ARM64**        | `arm64/darwin/`   | macOS ネイティブ                | 1          |
| **RISC-V (32-bit)** | `riscv32/qemu/` | QEMU virt マシン (bare-metal)   | 12         |
| **RISC-V (64-bit)** | `riscv64/qemu/` | QEMU virt マシン (bare-metal)   | 12         |

## 出力・入力の仕組み

全 CPU（QEMU/sim65 環境）で **UART/シリアル経由の統一出力** を採用しています。

### 出力の仕組み

| CPU              | UARTハードウェア | レジスタ書き込み命令           | アドレス                |
| :---             | :---             | :---                           | :---                    |
| **ARM64**        | PL011            | `STRB` (MMIOストア)            | `0x09000000` (UARTDR)   |
| **PowerPC**      | 16550            | `STB` (MMIOストア)             | `0xEF600300` (THR)      |
| **M68000**       | Goldfish TTY     | `MOVE.L` (MMIOストア)          | `0xFF008000` (PUT_CHAR) |
| **x86 (16-bit)** | 16550 (COM1)     | `OUT` (I/Oポート)              | `0x3F8` (THR)           |
| **6502**         | —                | sim65 API (`_putchar`/`_puts`) | —                       |
| **Z80**          | —                | CP/M BDOS (`CALL 0x0005`)      | —                       |
| **RISC-V**       | NS16550A         | `SB` (MMIOストア)              | `0x10000000` (THR)      |

ARM64/PPC は MMIO（メモリマップド I/O）で UART レジスタに直接ストア。x86 は I/O ポート命令（`OUT`/`IN`）で COM1 にアクセス。いずれも **OSやドライバを介さず** CPU 命令が直接ハードウェアレジスタを叩きます。

QEMU は `-serial stdio` で UART をホストの標準入出力にマップするため、プログラムの出力がそのままターミナルに表示されます。

### 入力の仕組み（s06, s12）

シリアルポートからの受信も同じ UART レジスタ経由:

- **Data Ready (LSR bit 0)** をポーリング
- **RBR (Receiver Buffer Register)** から文字を読み取り

QEMU の `-serial stdio` により、ホストのキーボード入力がそのままシリアル入力として渡されます。

6502 は cc65 ランタイムの `_getchar` を、Z80 は CP/M BDOS fn 1 を経由して入力を受け取ります。

### なぜBIOS INT 0x10を使わないのか

x86_16 でも BIOS INT 0x10（VGA 出力）を使わず、COM1 シリアル出力を使っています。理由:

- BIOS 起動時に SeaBIOS が `ESC c`（端末フルリセット）を送り、画面がクリアされる
- 他 CPU（ARM64/PPC）と同じ仕組みに統一することで、学習内容を共通化

> **コラム: なぜベアメタルプログラムは終了できないのか──CPU終了方式のバラエティ**
>
> OSがないベアメタル環境では「終了」という概念がない。各アーキテクチャで異なる終了方法を採用している：
>
> | 終了方式 | アーキテクチャ | 仕組み |
> |---|---|---|
> | セミホスティング | ARM64, RISC-V | `HLT #0xF000` やテストデバイス書込でQEMUに終了を伝える |
> | 無限ループ | M68000, PPC | CPU停止後、タイムアウトでQEMU強制終了 |
> | CP/M復帰 | Z80 | RETでCP/MのTPAに戻りシミュレータが停止 |
> | HLT+タイムアウト | x86_16 | HLTでCPU停止、timeoutでQEMU強制終了 |
>
> セミホスティングはデバッグに便利だが実機では使えない。この違いは各環境のエミュレータ最適化方針を反映している。

## 共通シナリオ一覧

s01〜s12 はすべてのアーキテクチャで共通のテーマです。

| #    | テーマ                     | 学習内容                                       |
| :--- | :---                       | :---                                           |
| s01  | Hello World                | UART出力の基本                                 |
| s02  | レジスタ                   | MOV, ADD, SUB, INC, DEC                        |
| s03  | スタック                   | PUSH/POP, LIFOの理解                           |
| s04  | ループ                     | カウントダウン, カウントアップ, 条件付きループ |
| s05  | 文字列                     | 文字列長, コピー, 文字列出力                   |
| s06  | 入力                       | シリアル入力 (UART RX)                         |
| s07  | サブルーチン               | CALL/RET, 引数渡し, ネスト呼び出し             |
| s08  | ハードウェア               | タイマーレジスタ読み取り / 遅延ループ          |
| s09  | 条件分岐                   | CMP, BEQ/BNE, BLT/BGT, 分岐テーブル            |
| s10  | ビット演算                 | AND, OR, XOR, シフト, マスク                   |
| s11  | メモリ                     | fill, copy, インデックスアドレッシング         |
| s12  | インタラクティブ           | 簡易シェル (コマンド解析, 入力ループ)          |

### アーキテクチャ固有シナリオ

| #    | テーマ                     | アーキテクチャ |
| :--- | :---                       | :---           |
| s13  | 裏レジスタ                 | Z80            |
| s13  | ファイルI/O / マルチセクタ | x86_16         |
| s14  | PSP / プロテクトモード     | x86_16         |

### アーキテクチャ固有の補足

- **6502 s08**: sim65 にはハードウェアタイマーがないため、CPU サイクルカウンティング（NOP 遅延ループ）でタイミング概念を学びます。
- **6502**: 全シナリオで `helpers.s` （`print_str`, `print_hex8`, `print_dec` 等）をリンクし、コード重複を回避しています。cc65 C ランタイムの `_putchar` を経由して sim65 の API 呼び出しで出力します（MMIO ではなく）。他アーキテクチャの UART 直接書き込みとは異なる出力メカニズムです。

## アーキテクチャ比較表

同じパターンを各 CPU でどう実装するかを比較することで、アーキテクチャの違いを理解できます。

### Hello World の実装比較

| 要素 | ARM64 | RISC-V | x86_16 | M68K | PPC | 6502 | Z80 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **文字列定義** | `.asciz` | `.asciz` | `db ..., 0` | `.asciz` | `.asciz` | `.asciiz` | `defm ...$` |
| **終端文字** | NUL (0) | NUL (0) | NUL (0) | NUL (0) | NUL (0) | NUL (0) | `$` (CP/M) |
| **文字列出力** | `strb w0, [x8]` | `sb a0, 0(t0)` | `out dx, al` | `move.l d0, 0xff008000` | `stb r3, 0(r8)` | `jsr _putchar` | `call 0x0005` |
| **I/O 方式** | MMIO | MMIO | I/Oポート | MMIO | MMIO | ランタイムAPI | BDOSコール |

### スタック設定の比較

| アーキテクチャ | 命令 | 設定値 | 備考 |
| :--- | :--- | :--- | :--- |
| **ARM64** | `movz x0, #0x4800, lsl #16; mov sp, x0` | `0x48000000` | RAM末尾 |
| **RISC-V** | `li sp, 0x80200000` | `0x80200000` | RAM末尾付近 |
| **x86_16** | `mov sp, 0x7C00` | `0x7C00` | コード直下 |
| **M68K** | `move.l #0x4000, %sp` | `0x4000` | RAM末尾 |
| **PPC** | `lis %r1, 0x0000; ori %r1, %r1, 0x1000` | `0x1000` | RAM末尾 |
| **6502** | (cc65 ランタイム設定) | — | 自動設定 |
| **Z80** | (CP/M TPA末尾) | — | 自動設定 |

### 終了方法の比較

| 方式 | アーキテクチャ | 命令 | 仕組み |
| :--- | :--- | :--- | :--- |
| **セミホスティング** | ARM64 | `hlt #0xF000` | QEMUに終了を伝える |
| **テストデバイス** | RISC-V | `sw t1, 0(t0)` (0x100000に0x5555) | SiFiveテストフィニッシャー |
| **HLT + タイムアウト** | x86_16 | `cli; hlt` | CPU停止、timeoutでQEMU強制終了 |
| **無限ループ + タイムアウト** | M68K, PPC | `bra halt` / `b halt` | CPU停止、timeoutでQEMU強制終了 |
| **ランタイム復帰** | 6502 | `rts` | cc65ランタイムに戻る |
| **CP/M復帰** | Z80 | `ret` | CP/MのTPAに戻る |

### サブルーチン呼び出しの比較

| アーキテクチャ | 呼び出し命令 | リンクレジスタ | 戻り命令 |
| :--- | :--- | :--- | :--- |
| **ARM64** | `bl func` | X30 (LR) | `ret` |
| **RISC-V** | `jal ra, func` | RA (x1) | `ret` (擬似命令) |
| **x86_16** | `call func` | スタック | `ret` |
| **M68K** | `bsr func` | スタック | `rts` |
| **PPC** | `bl func` | LR | `blr` |
| **6502** | `jsr func` | スタック | `rts` |
| **Z80** | `call func` | スタック | `ret` |

## 使い方

### ビルド & 全シナリオ実行

```bash
cd <ディレクトリ>
make      # 全シナリオをビルド
make runall   # 全シナリオをビルド + 実行
```

### 個別実行

```bash
make run S=s01_hello
```

### デバッグ / トレース / サイクル計測

```bash
# 各プラットフォームのディレクトリで
make debug S=s03_stack    # ステップ実行で CPU 状態を観察
make trace S=s03_stack    # 全命令の実行トレース
make cycles S=s04_loops   # サイクル/命令数の集計

# またはトップレベルから（A= でディレクトリを指定）
make debug A=z80/sim S=s03_stack
make trace A=6502/sim65 S=s03_stack
make cycles A=riscv64/qemu S=s01_hello
```

詳細は「デバッグガイド」の「make debug / trace / cycles (統一デバッグインターフェース)」を参照。

### クリーン

```bash
make clean
```

## デバッグガイド

各アーキテクチャのプログラムをデバッグする方法を説明します。

### make debug / trace / cycles (統一デバッグインターフェース)

全アーキテクチャに共通のデバッグ用ターゲット。どの CPU でも同じコマンドでステップ実行・命令トレース・サイクル（命令数）集計ができる。

```bash
# 各プラットフォームのディレクトリで
cd z80/sim && make debug S=s03_stack    # ステップ実行で CPU 状態を観察

# またはトップレベルから A= でディレクトリを指定
make trace A=6502/sim65 S=s03_stack     # 全命令の実行トレース
make cycles A=riscv64/qemu S=s01_hello  # サイクル/命令数の集計
```

**アーキテクチャ別の実装**:

| アーキテクチャ    | 実装                                  | 特記事項                                        |
| :---              | :---                                  | :---                                            |
| Z80               | simz80 対話ステッパー (`-debug`)      | フル対話型。レジスタ差分・フラグ変化・T-states 表示 |
| 6502              | `sim65 --trace` + 差分 awk            | `make debug` はリプレイ型（下記）               |
| QEMU 系 6 dir     | QEMU gdbstub + gdb / `-d in_asm,cpu`  | `make cycles` は実行命令数（下記）              |
| x86_16/dos        | 対象外                                | dosbox-x は gdbstub を持たないため統一インターフェースに載せられない（将来 dosbox-x 内蔵デバッガで対応予定） |
| darwin ネイティブ | 対象外                                | run 未整備のため対象外                          |

QEMU 系は `arm64` / `ppc` / `m68k` / `riscv32` / `riscv64` / `x86_16` の各 `qemu/` ディレクトリ。

**フラグ変化の観察例 (Z80)**: ステッパーは 1 命令ごとに変化したレジスタとフラグを old→new 形式で表示する。`LD A,7Fh` / `ADD A,01h` を実行すると:

```text
  A  7F → 80
  F  00 → 94
  S 0→1  H 0→1  P/V 0→1  (オーバーフロー)
```

7Fh + 01h は符号付き 8-bit で +127 + 1 = -128 となり、S（符号）・H（半キャリー）・P/V（オーバーフロー）が立つ。

**6502 の make debug はリプレイ型**: sim65 に対話ステップ実行はないため、`make debug` は全命令トレースを `$(S).trace` に記録し、less の SPACE/Enter で 1 命令ずつ送って見る方式。実行中のプログラムへのライブ制御ではなく、実行済みトレースの「再生」である点に注意。

#### 6502 のトレース出力の読み方（実行例）

6502 だけ 3 つのコマンドの挙動を具体例で示す。`make trace` の 1 行は左から「命令の通番 / 累積サイクル数 / PC / オペコードバイト / 逆アセンブル / レジスタ (A, X, Y, S) / Flags / SP」で、レジスタ欄は**その命令を実行する前**の値。`▸` 行は `trace-diff.awk` が前の命令で変わったレジスタを差分として挿入したもの。

```bash
cd 6502/sim65
make trace S=s03_stack
```

```text
           0             0  0200  D8        cld               A=00 X=00 Y=00 S=00 Flags=nvdizc    SP=FFFF
           1             2  0201  A2 FF     ldx  #$FF         A=00 X=00 Y=00 S=00 Flags=nvdizc    SP=FFFF
           2             4  0203  9A        txs               A=00 X=FF Y=00 S=00 Flags=Nvdizc    SP=FFFF
        ▸  X: 00→FF  Flags: nvdizc→Nvdizc
           3             6  0204  A9 C0     lda  #$C0         A=00 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
        ▸  S: 00→FF
           4             8  0206  A2 FF     ldx  #$FF         A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
        ▸  A: 00→C0
           5            10  0208  85 06     sta  $06          A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
           6            13  020A  86 07     stx  $07          A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFC0
        ▸  SP: FFFF→FFC0
           7            16  020C  20 B2 03  jsr  $03B2        A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFC0
```

この例の読み方:

- 通番 1 の `ldx #$FF` は X=00 のときに実行され、結果は `▸ X: 00→FF` として**次の行の下**に現れる（差分行は直前の命令の結果を示す）。
- 通番 2 の `txs` で X の値 (FF) がスタックポインタに転送される。直後の命令行の `SP=FFFF` は実行前の値で、`▸ SP: FFFF→FFC0` が転送結果。
- Flags 欄は N（負）V（オーバーフロー）D（10 進）I（割り込み禁止）Z（ゼロ）C（キャリー）の順で、大文字 = 立、小文字 = 落ち。`ldx #$FF` の後、次の命令行で `N` が大文字になり、FF（負の数）をロードしたことで N フラグが立ったことが分かる。
- 差分行は常に「直前の命令の結果」なので、例えばこのサンプルの直後 (`jsr $03B2` の実行後) には `▸ S: FF→FD` が現れ、リターンアドレス 2 バイト分スタックが減ったことが追跡できる。

**make debug (リプレイ再生)**: 同じ内容をページャで 1 命令ずつ送って見る。途中でスペースを連打して歩調を調整でき、`g` で先頭へ戻れる（トレース全体を巻き戻し再生できるのはリプレイ型の利点）。

```bash
make debug S=s03_stack          # SPACE/Enter で 1 命令ずつ、q で終了
PAGER=cat make debug S=s03_stack # ページャなしで全体を流す
```

**make cycles (実サイクル数)**: sim65 は 6502 の命令サイクルを正確にモデル化しているため、Z80 と同様「実サイクル数」が得られる（QEMU 系の命令数代替とは異なる）。

```bash
$ make cycles S=s03_stack
38138 cycles
```

上記のトレースの最終行（通番 11055 の時点）で累積サイクルが 38138 になっており、`make cycles` の値と一致する。1 命令あたりのサイクル数は隣接行の累積値の差で読める（例: 通番 6→7 で 13→16 なので `stx $07` (zero page) は 3 サイクル）。

**QEMU 系の make cycles は実行命令数**: QEMU TCG はサイクル精度のエミュレーションではないため、サイクル数は原理的に取得できない。`make cycles` は `-d in_asm` の記録から数えた実行命令数で代用する。

**QEMU 系の make debug に必要なもの**: `gdb`（`brew install gdb`。Homebrew 版は --enable-targets=all ビルドで、リモートデバッグ専用に使う場合コード署名は不要）。使用する gdb は `GDB` 変数、接続ポートは `GDB_PORT` 変数（既定 1234）で変更できる。トレースの記録時間は `TRACE_SECS` 変数（既定 10 秒）で調整できる。

### QEMU Monitor の使い方

QEMU Monitor にアクセスすると、実行中のプログラムの状態を確認できます。

```bash
# make run 実行中に Ctrl-A C で monitor に切り替え（-nographic のシリアルと
# monitor は同じ stdio に多重化されている）。Ctrl-A C でシリアルに戻る。
# なお x86_16/qemu は -monitor none 固定のため monitor は使えない。
```

> 注: 以前は `make run S=s01_hello QEMU_ARGS="-monitor stdio"` で起動できると説明していたが、`QEMU_ARGS` を実装した Makefile は存在せず、これはサイレント no-op だった。

**よく使うコマンド**:

| コマンド | 説明 |
| :--- | :--- |
| `info registers` | 全レジスタの値を表示 |
| `info registers CPU` | 特定 CPU のレジスタ表示 |
| `x /10i $pc` | PC から 10 命令を逆アセンブル |
| `x /16xb 0x4000000` | メモリを 16 バイト 16 進表示 |
| `x /4xw $sp` | スタックから 4 ワード表示 |
| `stepi` | 1 命令ステップ実行 |
| `continue` | 実行再開 |
| `quit` | QEMU 終了 |

**例（ARM64 のレジスタ確認）**:

```text
(qemu) info registers
x0000000000000048 x01=0000000004000040 ...
```

### GDB によるリモートデバッグ (QEMU 系)

QEMU 系の `make debug` は QEMU を `-S -gdb tcp::1234`（起動時停止 + GDB サーバ）で起動し、gdb を自動接続する。

```bash
# gdb が起動して QEMU (tcp::1234) に接続される
make debug A=arm64/qemu S=s01_hello

# ポートや gdb を変える場合
make debug A=arm64/qemu S=s01_hello GDB_PORT=1234 GDB=aarch64-none-elf-gdb
```

> 注: 以前は `make run S=s01_hello QEMU_ARGS="-s -S"` で GDB サーバ付きで起動できると説明していたが、`QEMU_ARGS` を実装した Makefile は存在せず、これはサイレント no-op だった。QEMU 系の GDB デバッグには `make debug` を使うこと。

**GDB よく使うコマンド**:

| コマンド | 短縮形 | 説明 |
| :--- | :--- | :--- |
| `break _start` | `b _start` | ブレークポイント設定 |
| `continue` | `c` | 実行再開 |
| `stepi` | `si` | 1 命令ステップ実行 |
| `nexti` | `ni` | 1 命令ステップ（コール先に入らない） |
| `info registers` | `i r` | レジスタ表示 |
| `print/x $x0` | `p/x $x0` | レジスタの値を 16 進表示 |
| `x/10i $pc` | — | PC から 10 命令を逆アセンブル |
| `x/16xb $sp` | — | スタックを 16 バイト表示 |
| `layout asm` | — | アセンブリ表示レイアウトに切替 |
| `quit` | `q` | GDB 終了 |

**アーキテクチャ別の設定**:

| アーキテクチャ | GDB アーキテクチャ設定 |
| :--- | :--- |
| ARM64 | `set architecture aarch64` |
| RISC-V 64 | `set architecture riscv:rv64` |
| RISC-V 32 | `set architecture riscv:rv32` |
| x86_16 | `set architecture i8086` |
| M68K | `set architecture m68k` |
| PPC | `set architecture powerpc` |

### 逆アセンブル

ビルド後に逆アセンブル出力を確認できます。

```bash
# 逆アセンブル出力
make dump S=s01_hello

# x86_16 の 32-bit コード（S13/S14 用）
make dump32 S=s14_protected
```

### よくある問題と対処

| 問題 | 原因 | 対処 |
| :--- | :--- | :--- |
| UART 出力が表示されない | アドレス間違い | UART ベースアドレスを確認 |
| QEMU が起動しない | ツール未インストール | `qemu-system-<arch>` の存在確認 |
| ビルドエラー | アセンブラ構文間違い | CPU.md の命令リファレンスを参照 |
| タイムアウトで終了 | プログラムが正常終了していない | 終了方法を確認（上記比較表参照） |
| 文字化け | ボーレート不一致 | UART のボーレート設定を確認 |

## 必要ツール

| ツール                      | 対象                 | インストール                                                                 |
| :---                        | :---                 | :---                                                                         |
| `cc65` / `sim65`            | 6502                 | `brew install cc65`                                                          |
| `clang` + `ld.lld`          | ARM64, PPC, RISC-V   | Xcode Command Line Tools                                                     |
| `m68k-elf-as` `m68k-elf-ld` | M68000               | macOS: `brew install m68k-elf-gcc` / Linux: `apt install gcc-m68k-linux-gnu` |
| `z80asm`                    | Z80                  | `brew install z80asm`                                                        |
| `go`                        | Z80 (シミュレータ)   | `brew install go`                                                            |
| `gdb`                       | QEMU 系の make debug | `brew install gdb`（--enable-targets=all ビルド、リモート専用ならコード署名不要） |
| `qemu-system-aarch64`       | ARM64                | `brew install qemu`                                                          |
| `qemu-system-ppc`           | PPC                  | `brew install qemu`                                                          |
| `qemu-system-m68k`          | M68000               | `brew install qemu`                                                          |
| `qemu-system-i386`          | x86_16               | `brew install qemu`                                                          |
| `nasm`                      | x86_16, x86_64, i386 | `brew install nasm`                                                          |
| `qemu-system-riscv32`       | RISC-V 32-bit        | `brew install qemu`                                                          |
| `qemu-system-riscv64`       | RISC-V 64-bit        | `brew install qemu`                                                          |
| `dosbox`                    | x86_16 DOS           | `brew install dosbox`                                                        |
| `alink`                     | x86_16 DOS EXE       | <http://alink.sourceforge.net/>                                              |
| `coreutils`                 | timeout コマンド     | `brew install coreutils`                                                     |

## ディレクトリ構成

```text
asm/
├── 6502/sim65/          # MOS 6502 アセンブリ (ca65構文) + helpers.s
├── arm64/
│   ├── darwin/          # macOS ARM64 (System ABI)
│   └── qemu/            # ARM64 bare-metal (QEMU virt)
├── m68k/qemu/           # M68000 bare-metal (QEMU virt)
├── z80/sim/             # Z80 + Go製CP/Mシミュレータ (z80asm)
├── ppc/qemu/            # PowerPC bare-metal (QEMU bamboo)
├── x86_16/
│   ├── qemu/            # 16-bit x86 フロッピーブート
│   └── dos/
│       ├── com/         # DOS COM 形式
│       └── exe/         # DOS MZ EXE 形式
├── x86_64/darwin/       # macOS x86_64
├── i386/darwin/         # macOS i386 (32-bit)
├── riscv32/qemu/        # RISC-V 32-bit bare-metal (QEMU virt)
├── riscv64/qemu/        # RISC-V 64-bit bare-metal (QEMU virt)
└── isa/                 # オフライン命令セット・リファレンス CLI 辞書
```

## 命令リファレンス CLI (isa)

オフラインで命令の仕様（動作・アドレッシングモード・消費クロック・フラグ変化・オペコード）を検索できる CLI 辞書。正本データは `isa/data/*.json`、詳細は `isa/README.md` を参照。

```sh
isa DJNZ        # 命令を検索（複数アーキに同名がある場合は一覧）
isa -v DJNZ     # 詳細全文（クロック・オペコード・備考）
isa z80 DJNZ    # アーキを限定
isa             # fzf 対話モード（絞り込み + 詳細プレビュー）
isa build       # isa/data/*.json から isa/build/ を再生成
```

常用する場合は `~/.zshrc` に `alias isa='~/repo/sokoide/asm/isa/isa'` を追加する（fzf は対話モードのみで必須）。

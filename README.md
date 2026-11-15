# アセンブリ言語学習教材

複数の CPU アーキテクチャに対するアセンブリ言語のハンズオン学習教材です。
各アーキテクチャで同じテーマ（Hello World、レジスタ、スタック、ループ、文字列操作など）を順に学習できる構成になっています。

## 対応アーキテクチャ

| アーキテクチャ   | ディレクトリ      | 実行環境                        | シナリオ数 |
| :---             | :---              | :---                            | :---       |
| **6502**         | `arch/6502/sim65/`     | sim65 シミュレータ (cc65)       | 16         |
| **ARM64**        | `arch/arm64/qemu/`     | QEMU virt マシン (bare-metal)   | 15         |
| **PowerPC**      | `arch/ppc/qemu/`       | QEMU bamboo マシン (bare-metal) | 15         |
| **M68000**       | `arch/m68k/qemu/`      | QEMU virt マシン (bare-metal)   | 15         |
| **Z80**          | `arch/z80/sim/`        | Go製 CP/M シミュレータ          | 16         |
| **x86 (16-bit)** | `arch/x86_16/qemu/`    | QEMU i386 フロッピーブート      | 17         |
| **x86 (16-bit)** | `arch/x86_16/dos/com/` | DOSBox (COM)                    | 1          |
| **x86 (16-bit)** | `arch/x86_16/dos/exe/` | DOSBox (MZ EXE)                 | 14         |
| **x86 (32-bit)** | `arch/x86_32/qemu/`    | QEMU i386 フロッピーブート      | 13         |
| **x86 (64-bit)** | `arch/x86_64/qemu/`    | QEMU x86_64 フロッピーブート    | 17         |
| **x86 (64-bit)** | `arch/x86_64/darwin/`  | macOS ネイティブ                | 1          |
| **x86 (32-bit)** | `arch/x86_32/darwin/`  | macOS ネイティブ                | 1          |
| **ARM64**        | `arch/arm64/darwin/`   | macOS ネイティブ                | 1          |
| **RISC-V (32-bit)** | `arch/riscv32/qemu/` | QEMU virt マシン (bare-metal)   | 15         |
| **RISC-V (64-bit)** | `arch/riscv64/qemu/` | QEMU virt マシン (bare-metal)   | 15         |

## 出力・入力の仕組み

全 CPU（QEMU/sim65 環境）で **UART/シリアル経由の統一出力** を採用しています。

### 出力の仕組み

| CPU              | UARTハードウェア | レジスタ書き込み命令           | アドレス                |
| :---             | :---             | :---                           | :---                    |
| **ARM64**        | PL011            | `STRB` (MMIOストア)            | `0x09000000` (UARTDR)   |
| **PowerPC**      | 16550            | `STB` (MMIOストア)             | `0xEF600300` (THR)      |
| **M68000**       | Goldfish TTY     | `MOVE.L` (MMIOストア)          | `0xFF008000` (PUT_CHAR) |
| **x86 (16-bit)** | 16550 (COM1)     | `OUT` (I/Oポート)              | `0x3F8` (THR)           |
| **x86 (32-bit)** | 16550 (COM1)     | `OUT` (I/Oポート)              | `0x3F8` (THR)           |
| **x86 (64-bit)** | 16550 (COM1)     | `OUT` (I/Oポート)              | `0x3F8` (THR)           |
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
> | HLT+タイムアウト | x86_32 | HLTでCPU停止、timeoutでQEMU強制終了 |
> | HLT+タイムアウト | x86_64 | HLTでCPU停止、timeoutでQEMU強制終了 |
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

### シナリオ番号の規約

- `s01`–`s12`: 全アーキ共通の 12 シナリオ
- `s13`–`s99`: 共通課題の拡張。全アーキで同じ番号・同じ名前を使う
- `s101`+: アーキ固有の拡張シナリオ（番号はアーキごとの独立空間）

### 共通課題シナリオ

| #    | テーマ                       | アーキテクチャ |
| :--- | :---                         | :---           |
| s13  | 100 バイトコピー (copybench) | 全アーキ (比較は `docs/copybench.md`) |
| s13  | ファイル I/O（DOS 固有）     | arch/x86_16/dos     |

### アーキテクチャ固有シナリオ

| #    | テーマ                        | アーキテクチャ |
| :--- | :---                          | :---           |
| s101 | 裏レジスタ                    | Z80            |
| s101 | Zero Page / 自己書き換えコード | 6502          |
| s101 | セグメントアドレス            | x86_16         |
| s103 | マルチセクタ読み込み          | arch/x86_16/qemu    |
| s104 | 32 ビットプロテクトモード      | arch/x86_16/qemu    |
| s101 | MOVEM                         | m68k           |
| s101 | CR とリンクレジスタ           | PPC            |
| s101 | CSR と ECALL                  | RISC-V         |
| s101 | NZCV と条件実行               | ARM64          |
| s102 | ベクタ / 例外                 | 6502, x86_16, m68k, PPC, RISC-V, ARM64 |

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
| **HLT + タイムアウト** | x86_16, x86_32, x86_64 | `cli; hlt` | CPU停止、timeoutでQEMU強制終了 |
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
make cycles S=s04_loops   # サイクル数（QEMU は unsupported）

# またはトップレベルから（A= でディレクトリを指定）
make debug A=z80/sim S=s03_stack
make trace A=6502/sim65 S=s03_stack
make icount A=riscv64/qemu S=s01_hello
```

詳細は「デバッグガイド」の「make debug / trace / cycles (統一デバッグインターフェース)」を参照。

### クリーン

```bash
make clean
```

### コード整形 (make format)

アセンブリソース (.s/.asm) は nvim で `:w` したときに走る保存時整形と同一ロジックで整形できる。フォーマッタの実体は nvim 設定の `lua/config/asm.lua`（`~/.config/nvim` は dotfiles リポジトリ `~/repo/sokoide/dotfiles/home/config/nvim` への symlink）:

- 6502 (ca65): `format_ca65` — 命令行をタブインデント、ラベル・疑似命令・コメントは列 0 に
- m68k: `format_m68k` — 命令行をタブインデント + `align_pipe_comments` による `|` コメント整列
- ca65 判定は `.segment` などの疑似命令の有無で行い、6502 の `.s` を GAS と区別する
- その他のアーキ (z80/x86/RISC-V/ARM64 等): `align_pipe_comments` のみ（`|` を持たないファイルは無変更）
- 汎用フォーマッタの asmfmt は使わない（GAS や ca65 のソースを壊すため conform.nvim からは除外済み）

各プラットフォームの Makefile はこの `asm.lua` の autocmd を headless nvim で再実行する（nvim の `:w` と完全に同じ整形になる）:

```bash
# 各プラットフォームのディレクトリで（6502 は ca65 形式、m68k は m68k 形式で整形）
make format

# 全アーキ + Markdown (textlint + markdownlint) をまとめて整形
make -C <repo root> format
```

前提: `nvim` と上記の nvim 設定（`asm.lua`）が存在すること。asm.lua が見つからない場合は `ASM_LUA=...` で別パスを指定できる。

## デバッグガイド

各アーキテクチャのプログラムをデバッグする方法を説明します。

### make debug / trace / cycles (統一デバッグインターフェース)

全アーキテクチャに共通のデバッグ用ターゲット。どの CPU でも同じコマンドでステップ実行・命令トレース・サイクル（命令数）集計ができる。

```bash
# 各プラットフォームのディレクトリで
cd arch/z80/sim && make debug S=s03_stack    # ステップ実行で CPU 状態を観察

# またはトップレベルから A= でディレクトリを指定
make trace A=6502/sim65 S=s03_stack     # 全命令の実行トレース
make icount A=riscv64/qemu S=s01_hello  # 実行命令数の集計
```

**アーキテクチャ別の実装**:

| アーキテクチャ    | 実装                                  | 特記事項                                        |
| :---              | :---                                  | :---                                            |
| Z80               | simz80 対話ステッパー (`-debug`)      | フル対話型。レジスタ差分・フラグ変化・T-states 表示 |
| 6502              | sim65i 対話ステッパー (`-g`)          | フル対話型。レジスタ差分・フラグ変化・サイクル表示（下記） |
| QEMU 系 8 dir     | QEMU gdbstub + gdb / `-d in_asm,cpu`  | `make cycles` は unsupported、命令数は `make icount`              |
| arch/x86_16/dos        | 対象外                                | dosbox-x は gdbstub を持たないため統一インターフェースに載せられない（将来 dosbox-x 内蔵デバッガで対応予定） |
| darwin ネイティブ | 対象外                                | run 未整備のため対象外                          |

QEMU 系は `arm64` / `ppc` / `m68k` / `riscv32` / `riscv64` / `x86_16` / `x86_32` / `x86_64` の各 `qemu/` ディレクトリ。

**フラグ変化の観察例 (Z80)**: ステッパーは 1 命令ごとに変化したレジスタとフラグを old→new 形式で表示する。`LD A,7Fh` / `ADD A,01h` を実行すると:

```text
  A  7F → 80
  F  00 → 94
  S 0→1  H 0→1  P/V 0→1  (オーバーフロー)
```

7Fh + 01h は符号付き 8-bit で +127 + 1 = -128 となり、S（符号）・H（半キャリー）・P/V（オーバーフロー）が立つ。

**6502 の make debug は対話ステッパー**: リポジトリ内ビルドの sim65i (`sim65src/`) に Z80 と同じ操作感の対話ステッパー (`s`/`n`/`c`/`b`/`r`/`d`/`x`/`q`) を組み込んでいる。1 命令ごとに「実行した命令の逆アセンブル行 + 変化したレジスタ（old→new）+ フラグ変化 + 消費サイクル」を表示する。プログラムが入力を読むシナリオ (S06/S12) では `[INPUT]>` プロンプトでゲスト入力も同じ stdin から読める。

#### 6502 のトレース出力の読み方（実行例）

6502 だけ 3 つのコマンドの挙動を具体例で示す。`make trace` の 1 行は左から「命令の通番 / 累積サイクル数 / PC / オペコードバイト / 逆アセンブル / レジスタ (A, X, Y, S) / Flags / SP」で、レジスタ欄は**その命令を実行する前**の値。`trace-diff.awk` は変化のあったレジスタについて `BEFORE:`（実行前値）/ `AFTER:`（実行後値 = 次の行の実行前値）/ `CHANGE:`（old→new の要約）の 3 行セットをその命令の直下に挿入する。

```bash
cd arch/6502/sim65
make trace S=s03_stack
```

```text
           0             0  0200  D8        cld               A=00 X=00 Y=00 S=00 Flags=nvdizc    SP=FFFF
           1             2  0201  A2 FF     ldx  #$FF         A=00 X=00 Y=00 S=00 Flags=nvdizc    SP=FFFF
        BEFORE: X=00
        AFTER:  X=FF
        CHANGE: X 00→FF
        BEFORE: Flags=nvdizc
        AFTER:  Flags=Nvdizc
        CHANGE: Flags nvdizc→Nvdizc
           2             4  0203  9A        txs               A=00 X=FF Y=00 S=00 Flags=Nvdizc    SP=FFFF
        BEFORE: S=00
        AFTER:  S=FF
        CHANGE: S 00→FF
           3             6  0204  A9 C0     lda  #$C0         A=00 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
        BEFORE: A=00
        AFTER:  A=C0
        CHANGE: A 00→C0
           4             8  0206  A2 FF     ldx  #$FF         A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
           5            10  0208  85 06     sta  $06          A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFFF
        BEFORE: SP=FFFF
        AFTER:  SP=FFC0
        CHANGE: SP FFFF→FFC0
           6            13  020A  86 07     stx  $07          A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFC0
           7            16  020C  20 B2 03  jsr  $03B2        A=C0 X=FF Y=00 S=FF Flags=Nvdizc    SP=FFC0
        BEFORE: S=FF
        AFTER:  S=FD
        CHANGE: S FF→FD
```

この例の読み方:

- 差分は**その命令自身の直下**に現れる。通番 1 の `ldx #$FF` の下の `BEFORE: X=00` / `AFTER: X=FF` / `CHANGE: X 00→FF` がその命令の実行結果で、「どの命令が何を変えたか」が 1 箇所で読める（`AFTER:` は次のトレース行の実行前値 = この命令の実行後値）。
- 通番 2 の `txs` の `CHANGE: S 00→FF` は、TXS が X の値 (FF) を **CPU のハードウェアスタックポインタ S** に転送した結果。`SP=` 欄は変化していない。
- 通番 5 の `sta $06` の `CHANGE: SP FFFF→FFC0` は TXS ではなく、cc65 ランタイムのスタートアップコードが**ソフトウェアスタックポインタを初期化**した結果である（ゼロページのランタイム変数 `sp` ($06-$07) に $C0 / $FF を書き込み、16 ビット値として $FFC0 を設定）。
- **`S` と `SP` は別物**: `S` = CPU のハードウェアスタックポインタ（8 ビット。`TXS` / `TSX` / `PHA` / `PLA` / `JSR` / `RTS` が操作し、ハードウェアスタック $0100-$01FF を指す）。`SP` = cc65 ランタイムのソフトウェアスタックポインタ（16 ビット、ゼロページの `sp` 変数。C 関数呼び出しのローカル変数・パラメータ領域で、ランタイムの `pushax` / `popax` などが操作する）。
- Flags 欄は N（負）V（オーバーフロー）D（10 進）I（割り込み禁止）Z（ゼロ）C（キャリー）の順で、大文字 = 立、小文字 = 落ち。通番 1 の `CHANGE: Flags nvdizc→Nvdizc` は、`ldx #$FF` が FF（負の数）をロードして N フラグを立てたことを示す。
- 通番 7 の `jsr $03B2` の `CHANGE: S FF→FD` は、JSR がリターンアドレス 2 バイト分ハードウェアスタックを消費した（S を 2 減らした）ことを示す。

**make replay (リプレイ再生)**: 同じ内容をページャで 1 命令ずつ送って見る。途中でスペースを連打して歩調を調整でき、`g` で先頭へ戻れる（トレース全体を巻き戻し再生できるのはリプレイ型の利点）。

```bash
make replay S=s03_stack          # SPACE/Enter で 1 命令ずつ、q で終了
PAGER=cat make replay S=s03_stack # ページャなしで全体を流す
```

**make cycles (実サイクル数)**: sim65 は 6502 の命令サイクルを正確にモデル化しているため、Z80 と同様「実サイクル数」が得られる（QEMU 系ではサイクル数を取得できない）。

```bash
$ make cycles S=s03_stack
38138 cycles
```

上記のトレースの最終行（通番 11055 の時点）で累積サイクルが 38138 になっており、`make cycles` の値と一致する。1 命令あたりのサイクル数は隣接行の累積値の差で読める（例: 通番 6→7 で 13→16 なので `stx $07` (zero page) は 3 サイクル）。

**QEMU 系の計測**: QEMU TCG はサイクル精度のエミュレーションではないため、`make cycles` は `unsupported` を表示する。実行命令数は別の `make icount` で計測する。

**QEMU 系の make debug に必要なもの**: `gdb`（`brew install gdb`。Homebrew 版は --enable-targets=all ビルドで、リモートデバッグ専用に使う場合コード署名は不要）。使用する gdb は `GDB` 変数、接続ポートは `GDB_PORT` 変数（既定 1234）で変更できる。トレースの記録時間は `TRACE_SECS` 変数（既定 10 秒）で調整できる。

### QEMU Monitor の使い方

QEMU Monitor にアクセスすると、実行中のプログラムの状態を確認できます。

```bash
# make run 実行中に Ctrl-A C で monitor に切り替え（-nographic のシリアルと
# monitor は同じ stdio に多重化されている）。Ctrl-A C でシリアルに戻る。
# なお arch/x86_16/qemu は -monitor none 固定のため monitor は使えない。
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

QEMU 系の `make debug` は QEMU を `-S -gdb tcp:127.0.0.1:1234`（起動時停止 + GDB サーバ）で起動し、gdb を自動接続する。Z80 は独自ステッパー、6502 はトレースのリプレイなので、以下の GDB コマンドは使わない。

QEMU 系の各 `make debug` は、同じディレクトリの `debug.gdb` を `-x` で明示的に読み込み、停止時のレジスタ表示マクロを登録する。

```bash
# gdb が起動して QEMU (127.0.0.1:1234) に接続される
make debug A=arm64/qemu S=s01_hello

# ポートや gdb を変える場合
make debug A=arm64/qemu S=s01_hello GDB_PORT=1234 GDB=aarch64-none-elf-gdb
```

> 注: 以前は `make run S=s01_hello QEMU_ARGS="-s -S"` で GDB サーバ付きで起動できると説明していたが、`QEMU_ARGS` を実装した Makefile は存在せず、これはサイレント no-op だった。QEMU 系の GDB デバッグには `make debug` を使うこと。

**GDB よく使うコマンド**:

| コマンド | 短縮形 | 説明 |
| :--- | :--- | :--- |
| `break *_start` | `b *_start` | `_start` の先頭命令にブレークポイント設定 |
| `continue` | `c` | 実行再開 |
| `stepi` | `si` | 1 命令ステップ実行 |
| `nexti` | `ni` | 1 命令ステップ（コール先に入らない） |
| `info registers` | `i r` | レジスタ表示 |
| `print/x $x0` | `p/x $x0` | レジスタの値を 16 進表示 |
| `x/10i $pc` | — | PC から 10 命令を逆アセンブル |
| `x/16xb $sp` | — | スタックを 16 バイト表示 |
| `tui enable` | — | TUI を有効化 |
| `tui disable` | — | TUI を無効化 |
| `layout asm` | — | 逆アセンブルとコマンドを表示 |
| `layout src` | — | ソースとコマンドを表示 |
| `layout split` | — | ソース・逆アセンブル・コマンドを表示 |
| `layout regs` | — | レジスタとソースまたは逆アセンブルを表示 |
| `layout next` / `layout prev` | — | 次 / 前のレイアウトに切替 |
| `refresh` | `Ctrl+L` | TUI の画面を再描画 |
| `quit` | `q` | GDB 終了 |

`layout` コマンドでも TUI が有効になる。ソース表示には対応するデバッグ情報とソースファイルが必要。`Ctrl+X`、続けて `A` で TUI の有効・無効を切り替えられる。

> **Note — `_start` の停止位置**
>
> `b _start` は関数名として解決され、GDB のプロローグ解析やデバッグ情報によって先頭命令より後にブレークポイントが設定されることがある。例えば RISC-V で `_start` の先頭が `0x80000000` でも、`b _start` が `0x80000010` の `ret` を選ぶ場合がある。`b *_start` はシンボルのアドレスを直接指定し、先頭命令に設定する。表示された設定アドレスを確認すること。すでに先頭を通過している場合はターゲットを再起動し、そこに到達する前に設定する。
>
> 参照: [GDB のアドレス指定](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Address-Locations.html)

#### 停止時にレジスタとメモリを自動表示する

`display` に登録すると、`si` やブレークポイントなどで停止するたびに値を表示する。次は M68K の例で、`make debug A=m68k/qemu S=s01_hello` の `(gdb)` プロンプトで入力する。

```gdb
display/i $pc
display/x $d0
display/x $a0
display/16xb $a0
display/8xh $sp
si
```

`si` の後は命令実行後の値が表示され、`display/i $pc` は次に実行する命令を示す。`$a0` や `$sp` が読み取り可能なメモリを指してからメモリ表示を設定する。レジスタ名は対象や GDB によって異なるため `info registers` で確認する。M68K の A7 は通常 `$sp`、A6 は `$fp`、SR は `$ps` と表示される。ARM64 なら例えば `$x0` を使う。

| 書式 | 意味 |
| :--- | :--- |
| `/x`、`/t` | 値を 16 進、2 進で表示 |
| `/16xb` | メモリを 1 バイトずつ 16 個、16 進で表示 |
| `/8xh` | メモリを 2 バイトずつ 8 個、16 進で表示 |
| `/4xw` | メモリを 4 バイトずつ 4 個、16 進で表示 |
| `/5i` | 命令を 5 個逆アセンブル |

GDB の `h` は 16 ビット、`w` は 32 ビットを表す。68000 の Word（16 ビット）と GDB の `w` は異なる。登録一覧は `info display`、番号を指定した削除は `undisplay 1`、一時停止と再開は `disable display 1` / `enable display 1` を使う。

複数のコマンドを毎回実行する場合は、GDB 上で次のように `hook-stop` を定義できる。`end` まで入力すると定義される。

```gdb
define hook-stop
    info registers
    x/i $pc
    x/8xh $sp
end
```

以後の停止時に実行される。スタックが読み取り可能な状態で使用する。処理を空にするには `define hook-stop` に続けて何も入力せず `end` とする。ファイルに保存した場合は `source m68k.gdb` で読み込める。

GDB の表示をファイルに記録するには、GDB プロンプトで次を実行する。

```gdb
set logging file m68k-trace.log
set logging overwrite on
set logging enabled on
si
set logging enabled off
```

既存の同名ファイルは上書きされる。記録されるのは GDB の表示であり、QEMU の UART 出力や CPU のバスアクセス履歴ではない。変更箇所だけを表示するには Python 対応 GDB の `gdb.events.stop` と状態の比較を利用できるが、メモリの前後比較では書き込み順序は分からない。

x86_16 の `make debug` は `arch/x86_16/qemu/` の `i8086.xml` と `i386-32bit.xml` を使い、gdb 起動時に `-x debug.gdb` でマクロ定義ファイルを明示的に読み込む（`.gdbinit` の自動ロードは使わない）。`debug.gdb` には次の設定と `regs16`/`regs32` マクロが定義されている。

```gdb
set tdesc filename i8086.xml
set architecture i8086
set disassembly-flavor intel
```

ターゲット記述を指定しない場合、GDB 表示は 32 ビットのレジスタ名や逆アセンブルのずれに注意する。命令一覧には `make dump S=<scenario>` も利用できる。スタックのアドレスにもセグメントを考慮する。

**アーキテクチャ別の設定**:

| アーキテクチャ | GDB アーキテクチャ設定 |
| :--- | :--- |
| ARM64 | `set architecture aarch64` |
| RISC-V 64 | `set architecture riscv:rv64` |
| RISC-V 32 | `set architecture riscv:rv32` |
| x86_16 | `set architecture i8086` |
| x86_32 | `set architecture i386` |
| x86_64 | `set architecture i386:x86-64` |
| M68K | `set architecture m68k` |
| PPC | `set architecture powerpc` |

### 逆アセンブル

ビルド後に逆アセンブル出力を確認できます。

```bash
# 逆アセンブル出力
make dump S=s01_hello

# x86_16 の 32-bit コード（S104 用）
make dump32 S=s104_protected
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
| `qemu-system-i386`          | x86_16, x86_32       | `brew install qemu`                                                          |
| `qemu-system-x86_64`        | x86_64               | `brew install qemu`                                                          |
| `nasm`                      | x86_16, x86_64, x86_32 | `brew install nasm`                                                          |
| `qemu-system-riscv32`       | RISC-V 32-bit        | `brew install qemu`                                                          |
| `qemu-system-riscv64`       | RISC-V 64-bit        | `brew install qemu`                                                          |
| `dosbox`                    | x86_16 DOS           | `brew install dosbox`                                                        |
| `alink`                     | x86_16 DOS EXE       | <http://alink.sourceforge.net/>                                              |
| `coreutils`                 | timeout コマンド     | `brew install coreutils`                                                     |

## ディレクトリ構成

```text
asm/
├── arch/                # CPU 別教材
│   ├── 6502/            # sim65
│   ├── arm64/           # QEMU / macOS
│   ├── m68k/            # QEMU
│   ├── ppc/             # QEMU
│   ├── riscv32/         # QEMU
│   ├── riscv64/         # QEMU
│   ├── x86_16/          # QEMU / DOS
│   ├── x86_32/          # QEMU / macOS
│   ├── x86_64/          # QEMU / macOS
│   └── z80/             # CP/M シミュレータ
├── bin/isa/             # オフライン命令セット辞書
├── common/              # 共通コード
└── docs/                 # 比較資料・計画文書
```

## 命令リファレンス CLI (isa)

オフラインで命令の仕様（動作・アドレッシングモード・消費クロック・フラグ変化・オペコード）を検索できる CLI 辞書。正本データは `bin/isa/data/*.json`、詳細は `bin/isa/README.md` を参照。

```sh
isa DJNZ        # 命令を検索（複数アーキに同名がある場合は一覧）
isa -v DJNZ     # 詳細全文（クロック・オペコード・備考）
isa z80 DJNZ    # アーキを限定
isa             # fzf 対話モード（絞り込み + 詳細プレビュー）
isa build       # bin/isa/data/*.json から bin/isa/build/ を再生成
```

常用する場合は `~/.zshrc` に `alias isa='~/repo/sokoide/asm/bin/isa/isa'` を追加する（fzf は対話モードのみで必須）。

# アセンブリ言語学習教材

複数のCPUアーキテクチャに対するアセンブリ言語のハンズオン学習教材です。
各アーキテクチャで同じテーマ（Hello World、レジスタ、スタック、ループ、文字列操作など）を順に学習できる構成になっています。

## 対応アーキテクチャ

| アーキテクチャ | ディレクトリ | 実行環境 | シナリオ数 |
|---|---|---|---|
| **6502** | `6502/sim65/` | sim65 シミュレータ (cc65) | 12 |
| **ARM64** | `arm64/qemu/` | QEMU virt マシン (bare-metal) | 12 |
| **PowerPC** | `ppc/qemu/` | QEMU bamboo マシン (bare-metal) | 12 |
| **M68000** | `m68k/qemu/` | QEMU virt マシン (bare-metal) | 12 |
| **Z80** | `z80/sim/` | Go製 CP/M シミュレータ | 13 |
| **x86 (16-bit)** | `x86_16/qemu/` | QEMU i386 フロッピーブート | 14 |
| **x86 (16-bit)** | `x86_16/dos/exe/` | DOSBox (MZ EXE) | 14 |
| **x86 (64-bit)** | `x86_64/darwin/` | macOS ネイティブ | 1 |
| **x86 (32-bit)** | `i386/darwin/` | macOS ネイティブ | 1 |
| **ARM64** | `arm64/darwin/` | macOS ネイティブ | 1 |

## 出力・入力の仕組み

全CPU（QEMU/sim65環境）で **UART/シリアル経由の統一出力** を採用しています。

### 出力の仕組み

| CPU | UARTハードウェア | レジスタ書き込み命令 | アドレス |
|---|---|---|---|
| **ARM64** | PL011 | `STRB` (MMIOストア) | `0x09000000` (UARTDR) |
| **PowerPC** | 16550 | `STB` (MMIOストア) | `0xEF600300` (THR) |
| **M68000** | Goldfish TTY | `MOVE.L` (MMIOストア) | `0xFF008000` (PUT_CHAR) |
| **x86 (16-bit)** | 16550 (COM1) | `OUT` (I/Oポート) | `0x3F8` (THR) |
| **6502** | — | sim65 API (`_putchar`/`_puts`) | — |
| **Z80** | — | CP/M BDOS (`CALL 0x0005`) | — |

ARM64/PPCはMMIO（メモリマップドI/O）でUARTレジスタに直接ストア。x86はI/Oポート命令（`OUT`/`IN`）でCOM1にアクセス。いずれも **OSやドライバを介さず** CPU命令が直接ハードウェアレジスタを叩きます。

QEMUは `-serial stdio` でUARTをホストの標準入出力にマップするため、プログラムの出力がそのままターミナルに表示されます。

### 入力の仕組み（s06, s12）

シリアルポートからの受信も同じUARTレジスタ経由:

- **Data Ready (LSR bit 0)** をポーリング
- **RBR (Receiver Buffer Register)** から文字を読み取り

QEMUの `-serial stdio` により、ホストのキーボード入力がそのままシリアル入力として渡されます。

6502はcc65ランタイムの `_getchar` を、Z80はCP/M BDOS fn 1を経由して入力を受け取ります。

### なぜBIOS INT 0x10を使わないのか

x86_16でもBIOS INT 0x10（VGA出力）を使わず、COM1シリアル出力を使っています。理由:

- BIOS起動時にSeaBIOSが `ESC c`（端末フルリセット）を送り、画面がクリアされる
- 他CPU（ARM64/PPC）と同じ仕組みに統一することで、学習内容を共通化

## 共通シナリオ一覧

s01〜s12 はすべでのアーキテクチャで共通のテーマです（x86_16 は s13, s14 を追加、Z80 は s13 を追加）。

| # | テーマ | 学習内容 |
|---|---|---|
| s01 | Hello World | UART出力の基本 |
| s02 | レジスタ | MOV, ADD, SUB, INC, DEC |
| s03 | スタック | PUSH/POP, LIFOの理解 |
| s04 | ループ | カウントダウン, カウントアップ, 条件付きループ |
| s05 | 文字列 | 文字列長, コピー, 文字列出力 |
| s06 | 入力 | シリアル入力 (UART RX) |
| s07 | サブルーチン | CALL/RET, 引数渡し, ネスト呼び出し |
| s08 | ハードウェア | タイマーレジスタ読み取り / 遅延ループ |
| s09 | 条件分岐 | CMP, BEQ/BNE, BLT/BGT, 分岐テーブル |
| s10 | ビット演算 | AND, OR, XOR, シフト, マスク |
| s11 | メモリ | fill, copy, インデックスアドレッシング |
| s12 | インタラクティブ | 簡易シェル (コマンド解析, 入力ループ) |
| s13 | 裏レジスタ | EXX, EX AF,AF', ISR コンテキスト保存 (Z80のみ) |
| s13 | ファイルI/O / マルチセクタ | (x86_16のみ) |
| s14 | PSP / プロテクトモード | (x86_16のみ) |

### アーキテクチャ固有の補足

- **6502 s08**: sim65にはハードウェアタイマーがないため、CPUサイクルカウンティング（NOP遅延ループ）でタイミング概念を学びます。
- **6502**: 全シナリオで `helpers.s` （`print_str`, `print_hex8`, `print_dec` 等）をリンクし、コード重複を回避しています。

## 使い方

### ビルド & 全シナリオ実行

```sh
cd <ディレクトリ>
make all      # 全シナリオをビルド
make runall   # 全シナリオをビルド + 実行
```

### 個別実行

```sh
make run S=s01_hello
```

### クリーン

```sh
make clean
```

## 必要ツール

| ツール | 対象 | インストール |
|---|---|---|
| `cc65` / `sim65` | 6502 | `brew install cc65` |
| `clang` + `ld.lld` | ARM64, PPC | Xcode Command Line Tools |
| `m68k-elf-as` `m68k-elf-ld` | M68000 | macOS: `brew install m68k-elf-gcc` / Linux: `apt install gcc-m68k-linux-gnu` |
| `z80asm` | Z80 | `brew install z80asm` |
| `go` | Z80 (シミュレータ) | `brew install go` |
| `qemu-system-aarch64` | ARM64 | `brew install qemu` |
| `qemu-system-ppc` | PPC | `brew install qemu` |
| `qemu-system-m68k` | M68000 | `brew install qemu` |
| `qemu-system-i386` | x86_16 | `brew install qemu` |
| `nasm` | x86_16, x86_64, i386 | `brew install nasm` |
| `dosbox` | x86_16 DOS | `brew install dosbox` |
| `alink` | x86_16 DOS EXE | <http://alink.sourceforge.net/> |
| `coreutils` | timeout コマンド | `brew install coreutils` |

## ディレクトリ構成

```
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
└── i386/darwin/         # macOS i386 (32-bit)
```

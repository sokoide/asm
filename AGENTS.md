# AGENTS.md

このファイルは、このリポジトリでコードを扱う AI コーディングエージェント（Claude Code など）向けのガイダンスを提供する。

## プロジェクト概要

マルチアーキテクチャのアセンブリ言語学習教材。各アーキテクチャが同じ 12 シナリオの段階的カリキュラム（Hello World → レジスタ → スタック → ループ → 文字列 → シリアル I/O → サブルーチン → ハードウェア → 分岐 → ビット演算 → メモリ → ミニシェル）を、QEMU ベアメタルまたはシミュレータ上で実装する。

## アーキテクチャ一覧

| アーキ | ディレクトリ | ツールチェーン | エミュレータ | ソース拡張子 |
| :--- | :--- | :--- | :--- | :--- |
| 6502 | `6502/sim65/` | cc65 (cl65) | sim65 | `.s` |
| ARM64 | `arm64/qemu/` | clang + ld.lld (`--target=aarch64-none-elf`) | qemu-system-aarch64 (`-machine virt -semihosting`) | `.s` |
| PowerPC | `ppc/qemu/` | clang + ld.lld (`--target=powerpc-none-elf`) | qemu-system-ppc (`-machine bamboo`) | `.s` |
| M68000 | `m68k/qemu/` | m68k-elf-as + m68k-elf-ld | qemu-system-m68k (`-machine virt`) | `.s` |
| Z80 | `z80/sim/` | z80asm | Go 製 simz80 (CP/M) | `.asm` |
| x86 16-bit | `x86_16/qemu/` | nasm (`-f elf32`) | qemu-system-i386 (floppy boot) | `.asm` |
| RISC-V 32 | `riscv32/qemu/` | clang + ld.lld (`--target=riscv32-unknown-elf -march=rv32im`) | qemu-system-riscv32 (`-machine virt -bios none`) | `.s` |
| RISC-V 64 | `riscv64/qemu/` | clang + ld.lld (`--target=riscv64-unknown-elf -march=rv64im`) | qemu-system-riscv64 (`-machine virt -bios none`) | `.s` |

## ビルドと実行コマンド

QEMU ベースのアーキテクチャはすべて同じ Makefile ターゲットパターンを共有する:

```bash
cd <arch>/<platform>
make                # 全シナリオをビルド
make run S=s01_hello  # 単一シナリオを実行
make runall         # 全シナリオをビルド + 実行
make dump S=s01_hello # 逆アセンブル
make debug S=s03_stack  # ステップデバッガ (QEMU: gdb / z80: 対話 / 6502: リプレイ)
make trace S=s03_stack  # 1 命令ごとの実行トレース
make cycles S=s04_loops # サイクル/命令数の集計
make clean
```

6502 は `make dump` を持たず、x86_16 は 32-bit プロテクトモード sections 向けに `make dump32` を追加で持つ。`debug`/`trace`/`cycles` ターゲットはリポジトリ全体で存在する（すべてのコアプラットフォームディレクトリ + root Makefile のパススルー: `make debug A=<arch>/<platform> S=<scenario>`）。

注: 6502 の `make debug` はリプレイ型（トレースを記録して less で閲覧 — ライブステップ実行はなし）。QEMU の `make cycles` は実行命令数を報告しサイクル数ではない（TCG はサイクル精度のエミュレーションでない）。x86_16/dos (dosbox-x) と darwin ネイティブディレクトリは統一デバッグインターフェースの対象外。

## 主要パターン

### 12 シナリオ構造

各シナリオはアーキテクチャ間で対応するファイルを持つ:

- ソース: `s01_hello.s` 〜 `s12_minishell.s`
- 難易度: S01-S02 ★、S03-S05 ★★、S06-S08 ★★★、S09-S11 ★★★★、S12 ★★★★★
- S06 と S12 は対話入力が必要（`make runall` では `printf` でパイプされる）

### ファイルペア

各アーキテクチャはアーキルートに `CPU.md`（命令リファレンス）を、プラットフォームサブディレクトリに `README.md` + `Makefile` + `linker.ld` を持つ。

### ISA リファレンス CLI

`isa/` はオフラインの命令セット辞書 CLI（`isa DJNZ`）。正本データは `isa/data/<arch>.json` にある。`isa build`（`python3 isa/tools/generate.py`）を実行すると `isa/build/` を再生成しスキーマを検証する。`isa/build/` を直接編集しないこと。

### ドキュメント規約

- Markdown テーブルは `| :--- |` 配置（`---` の前後にスペース）
- README のセクション順: 前提条件 → ビルドと実行 → ディレクトリ構造 → S01-S12 scenarios → 関連ドキュメント → ハードウェア情報 → 次のステップ
- テキストはすべて日本語

### UART I/O パターン

- ARM64: PL011 @ 0x09000000、semihosting で終了 (`hlt #0xF000`)
- PPC: 16550 @ 0xEF600300、無限ループで停止（timeout が必要）
- M68k: Goldfish TTY @ 0xFF008000、クリーンな終了なし (Ctrl+C)
- RISC-V: NS16550A @ 0x10000000、SiFive test device で終了（0x100000 へ 0x5555 を書き込み）
- x86: 16550 COM1 @ 0x3F8、I/O port 命令 (`OUT`/`IN`) 経由

## 新しいアーキテクチャの追加手順

1. 標準セクション順に従って `<arch>/CPU.md` を作成: レジスタ → データ転送 → 算術 → 論理 → シフト → 比較 → 分岐 → サブルーチン → システム制御 → アドレッシングモード
2. `Makefile`、`linker.ld`、`README.md` を含む `<arch>/qemu/` を作成
3. 同じシナリオテーマと難易度進行に従って s01-s12 を実装
4. トップレベル `README.md` を更新: アーキテクチャテーブル、出力テーブル、ツールテーブル、ディレクトリ一覧

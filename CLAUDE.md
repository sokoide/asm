# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-architecture assembly language learning materials. Each architecture implements the same 12-scenario progressive curriculum (Hello World → Registers → Stack → Loops → Strings → Serial I/O → Subroutines → Hardware → Branching → Bitwise → Memory → Minishell) on QEMU bare-metal or simulators.

## Architecture Matrix

| Arch | Directory | Toolchain | Emulator | Source extension |
|------|-----------|-----------|----------|-----------------|
| 6502 | `6502/sim65/` | cc65 (cl65) | sim65 | `.s` |
| ARM64 | `arm64/qemu/` | clang + ld.lld (`--target=aarch64-none-elf`) | qemu-system-aarch64 (`-machine virt -semihosting`) | `.s` |
| PowerPC | `ppc/qemu/` | clang + ld.lld (`--target=powerpc-none-elf`) | qemu-system-ppc (`-machine bamboo`) | `.s` |
| M68000 | `m68k/qemu/` | m68k-elf-as + m68k-elf-ld | qemu-system-m68k (`-machine virt`) | `.s` |
| Z80 | `z80/sim/` | z80asm | Go製 simz80 (CP/M) | `.asm` |
| x86 16-bit | `x86_16/qemu/` | nasm (`-f elf32`) | qemu-system-i386 (floppy boot) | `.asm` |
| RISC-V 32 | `riscv32/qemu/` | clang + ld.lld (`--target=riscv32-unknown-elf -march=rv32im`) | qemu-system-riscv32 (`-machine virt -bios none`) | `.s` |
| RISC-V 64 | `riscv64/qemu/` | clang + ld.lld (`--target=riscv64-unknown-elf -march=rv64im`) | qemu-system-riscv64 (`-machine virt -bios none`) | `.s` |

## Build & Run Commands

All QEMU-based architectures share the same Makefile target pattern:

```bash
cd <arch>/<platform>
make                # Build all scenarios
make run S=s01_hello  # Run single scenario
make runall         # Build + run all scenarios
make dump S=s01_hello # Disassemble
make debug S=s03_stack  # Step debugger (QEMU: gdb / z80: interactive / 6502: replay)
make trace S=s03_stack  # Per-instruction execution trace
make cycles S=s04_loops # Cycle/instruction count
make clean
```

6502 omits `make dump`; x86_16 adds `make dump32` for 32-bit protected-mode sections. The `debug`/`trace`/`cycles` targets exist repo-wide (all core platform directories, plus a root-Makefile passthrough: `make debug A=<arch>/<platform> S=<scenario>`).

Note: 6502 `make debug` is replay-based (records a trace, views it in less — no live stepping), and QEMU `make cycles` reports executed instruction count, not cycles (TCG is not cycle-accurate). x86_16/dos (dosbox-x) and darwin native dirs are outside the unified debug interface.

## Key Patterns

### 12-Scenario Structure
Each scenario has matching files across architectures:
- Source: `s01_hello.s` through `s12_minishell.s`
- Difficulty: S01-S02 ★, S03-S05 ★★, S06-S08 ★★★, S09-S11 ★★★★, S12 ★★★★★
- S06 and S12 require interactive input (piped via `printf` in `make runall`)

### File Pairs

Each architecture has `CPU.md` (instruction reference) at the arch root and `README.md` + `Makefile` + `linker.ld` in the platform subdirectory.

### ISA Reference CLI

`isa/` is an offline instruction-set dictionary CLI (`isa DJNZ`). Canonical data lives in `isa/data/<arch>.json`; run `isa build` (`python3 isa/tools/generate.py`) to regenerate `isa/build/` and validate the schema. Do not edit `isa/build/` directly.

### Documentation Conventions
- Markdown tables use `| :--- |` alignment (with spaces around `---`)
- README section order: 前提条件 → ビルドと実行 → ディレクトリ構造 → S01-S12 scenarios → 関連ドキュメント → ハードウェア情報 → 次のステップ
- All text in Japanese

### UART I/O Patterns
- ARM64: PL011 at 0x09000000, exits via semihosting (`hlt #0xF000`)
- PPC: 16550 at 0xEF600300, exits via infinite loop (timeout required)
- M68k: Goldfish TTY at 0xFF008000, no clean exit (Ctrl+C)
- RISC-V: NS16550A at 0x10000000, exits via SiFive test device (write 0x5555 to 0x100000)
- x86: 16550 COM1 at 0x3F8 via I/O port instructions (`OUT`/`IN`)

## Adding a New Architecture

1. Create `<arch>/CPU.md` following the standard section order: レジスタ → データ転送 → 算術 → 論理 → シフト → 比較 → 分岐 → サブルーチン → システム制御 → アドレッシングモード
2. Create `<arch>/qemu/` with `Makefile`, `linker.ld`, `README.md`
3. Implement s01-s12 following the same scenario themes and difficulty progression
4. Update top-level `README.md`: architecture table, output table, tools table, directory listing

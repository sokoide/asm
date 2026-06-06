# ARM64 (AArch64) ベアメタルアセンブリ教材

QEMU virt マシン上で動作する ARM64 アセンブリ言語の学習教材です。

## 必要環境

- **ツールチェーン**: Clang (macOS 標準)
- **エミュレータ**: QEMU (`brew install qemu`)
- **リンカ**: ld.lld (Clang に付属)

## 使い方

```bash
# 全ビルド
make

# 個別実行
make run S=s01_hello

# 逆アセンブル
make dump S=s01_hello

# 全テスト実行
make test

# クリーン
make clean
```

## シナリオ一覧

| #    | ファイル          | テーマ           | 難易度 | 学習内容                                    |
| :--- | :---              | :---             | :---   | :---                                        |
| s01  | s01_hello.s       | Hello World      | ★☆☆☆☆  | UART出力、MOVZ、STRB、セミホスティング終了  |
| s02  | s02_registers.s   | レジスタと算術   | ★☆☆☆☆  | ADD/SUB/MOV、16進表示サブルーチン           |
| s03  | s03_stack.s       | スタック操作     | ★★☆☆☆  | STP/LDP、LIFOの確認                         |
| s04  | s04_loops.s       | ループと分岐     | ★★☆☆☆  | SUBS+B.NE、CMP+B.LT、TST+B.EQ               |
| s05  | s05_strings.s     | 文字列操作       | ★★☆☆☆  | strlen、strcpy、LDRB/STRB                   |
| s06  | s06_serial_in.s   | シリアル入力     | ★★★☆☆  | UART受信 (RXFE)、エコーバック               |
| s07  | s07_subroutines.s | サブルーチン     | ★★★☆☆  | BL/RET、パラメータ渡し (X0-X7)、ネスト呼出  |
| s08  | s08_hardware.s    | ハードウェア     | ★★★☆☆  | MRS命令、ジェネリックタイマー (CNTVCT_EL0)  |
| s09  | s09_branching.s   | メニュー分岐     | ★★★★☆  | CMP+B.EQ、ディスパッチパターン              |
| s10  | s10_bitwise.s     | ビット演算       | ★★★★☆  | AND/ORR/EOR/LSL/LSR、2進表示                |
| s11  | s11_memory.s      | メモリ操作       | ★★★★☆  | memset/memcpy、pre/post-indexアドレッシング |
| s12  | s12_minishell.s   | 総合プロジェクト | ★★★★★  | コマンド解析、文字列比較、全概念の統合      |

## 技術仕様

- **ターゲット**: `aarch64-none-elf`
- **QEMU**: `qemu-system-aarch64 -machine virt -cpu cortex-a57 -nographic -semihosting`
- **UART**: PL011 @ 0x09000000 (UARTDR), 0x09000018 (UARTFR)
- **ロードアドレス**: 0x40000000
- **スタックポインタ**: 0x48000000 (RAM 末尾)
- **終了方法**: セミホスティング (HLT #0xF000)

## ARM64 命令リファレンス

### データ転送

- `MOVZ Xd, #imm, LSL #shift` — 定数ロード
- `LDR Xd, =label` — アドレスロード (疑似命令)
- `LDRB Wd, [Xn]` — バイト読み出し
- `STRB Wd, [Xn]` — バイト書き込み
- `STP Xt1, Xt2, [Sp, #-16]!` — レジスタペア push
- `LDP Xt1, Xt2, [Sp], #16` — レジスタペア pop

### 算術・論理

- `ADD/SUB Xd, Xn, #imm` — 加算/減算
- `AND/ORR/EOR Xd, Xn, #imm` — ビット演算
- `LSL/LSR Xd, Xn, #shift` — シフト
- `SUBS` — 減算 + フラグ更新

### 分岐

- `B label` — 無条件分岐
- `BL label` — リンク付き分岐 (サブルーチン呼出)
- `RET` — リンクレジスタへ復帰
- `B.EQ/B.NE/B.LT/B.HI/B.PL` — 条件分岐
- `CBZ/CBNZ Xn, label` — 比較+分岐
- `TBNZ/TBZ Xn, #bit, label` — テスト+分岐

### システム

- `MRS Xd, <sysreg>` — システムレジスタ読出
- `HLT #0xF000` — セミホスティングトラップ

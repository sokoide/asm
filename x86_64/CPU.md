# x86_64 (AMD64) 命令リファレンス

AMD64 / Intel 64 アーキテクチャの 64-bit モード命令セット（Long Mode）。16-bit / 32-bit からの拡張で、64-bit レジスタ、RIP 相対アドレッシング、追加レジスタ（R8-R15）を特徴とする。

## レジスタ

### 汎用レジスタ（64-bit）

| レジスタ    | 名称          | 役割                                           |
| :---        | :---          | :---                                           |
| `RAX`       | Accumulator   | 算術演算・戻り値・システムコール番号           |
| `RBX`       | Base          | 呼び出し保存レジスタ                           |
| `RCX`       | Counter       | 第4引数・シフトカウンタ                        |
| `RDX`       | Data          | 第3引数・乗除算の補助                          |
| `RSI`       | Source Index  | 第2引数（syscall/関数）                        |
| `RDI`       | Destination   | 第1引数（syscall/関数）                        |
| `RBP`       | Base Pointer  | フレームポインタ（呼び出し保存）               |
| `RSP`       | Stack Pointer | スタックポインタ                               |
| `R8`        | —             | 第5引数、スクラッチ                            |
| `R9`        | —             | 第6引数、スクラッチ                            |
| `R10`-`R15` | —             | スクラッチ（R10-R11）、呼び出し保存（R12-R15） |

### 部分レジスタ

```text
RAX (64-bit)
├── EAX (32-bit)
│   ├── AX (16-bit)
│   │   ├── AH (8-bit) ── 上位
│   │   └── AL (8-bit) ── 下位
│   └── 上位 16-bit（直接アクセス不可）
└── 上位 32-bit（直接アクセス不可）
```

R8-R15 も同様に R8W（16-bit）、R8B（8-bit）で部分アクセス可能。

### フラグレジスタ (RFLAGS)

| ビット | フラグ | 名称            | 説明                   |
| :---   | :---   | :---            | :---                   |
| 0      | CF     | Carry Flag      | 繰り上がり/繰り下がり  |
| 2      | PF     | Parity Flag     | 結果のパリティ（偶数） |
| 4      | AF     | Auxiliary Carry | BCD 演算用補助         |
| 6      | ZF     | Zero Flag       | 結果がゼロ             |
| 7      | SF     | Sign Flag       | 結果が負               |
| 8      | TF     | Trap Flag       | シングルステップ       |
| 9      | IF     | Interrupt Flag  | 割り込み許可           |
| 10     | DF     | Direction Flag  | 文字列操作の方向       |
| 11     | OF     | Overflow Flag   | 符号付きオーバーフロー |

## データ転送命令

| 命令               | 動作                               |
| :---               | :---                               |
| `mov dst, src`     | dst ← src                          |
| `movzx dst, src`   | dst ← ZeroExtend(src)              |
| `movsx dst, src`   | dst ← SignExtend(src)              |
| `movsxd dst, src`  | dst ← SignExtend(src)（32→64-bit） |
| `xchg a, b`        | a ↔ b                              |
| `push src`         | RSP -= 8, [RSP] ← src              |
| `pop dst`          | dst ← [RSP], RSP += 8              |
| `pushfq` / `popfq` | RFLAGS の保存・復元                |
| `lea reg, [mem]`   | 実効アドレスを reg に格納          |

## 算術命令

| 命令                  | 動作                            |
| :---                  | :---                            |
| `add dst, src`        | dst += src                      |
| `adc dst, src`        | dst += src + CF                 |
| `sub dst, src`        | dst -= src                      |
| `sbb dst, src`        | dst = dst - src - CF            |
| `inc dst`             | dst++                           |
| `dec dst`             | dst--                           |
| `neg dst`             | dst = -dst                      |
| `mul src`             | RDX:RAX = RAX × src（符号なし） |
| `imul src`            | 同上（符号付き）                |
| `imul dst, src, #imm` | dst = src × imm                 |
| `div src`             | RAX = RDX:RAX ÷ src, RDX = 余り |
| `idiv src`            | 同上（符号付き）                |

## 論理命令

| 命令          | 動作                      |
| :---          | :---                      |
| `and dst, src` | dst &= src              |
| `or dst, src`  | dst \|= src             |
| `xor dst, src` | dst ^= src              |
| `not dst`      | dst = ~dst              |

## シフト命令

| 命令             | 動作                       |
| :---             | :---                       |
| `shl dst, count` | 左論理シフト（×2）         |
| `shr dst, count` | 右論理シフト（÷2）         |
| `sal dst, count` | 左算術シフト（SHL と同じ） |
| `sar dst, count` | 算術右シフト（符号維持）   |
| `rol dst, count` | 左ローテート               |
| `ror dst, count` | 右ローテート               |
| `rcl dst, count` | CF を含む左ローテート      |
| `rcr dst, count` | CF を含む右ローテート      |

`count` は即値または `CL` レジスタ。

## 比較命令

| 命令          | 動作                      |
| :---          | :---                      |
| `cmp a, b`    | a - b（フラグのみ更新）   |
| `test a, b`   | a AND b（フラグのみ更新） |

## 分岐命令

| 命令          | 動作                   | 条件              |
| :---          | :---                   | :---              |
| `jmp label`   | 無条件ジャンプ         | —                 |
| `je` / `jz`   | 等しい                 | ZF=1              |
| `jne` / `jnz` | 等しくない             | ZF=0              |
| `jl` / `jnge` | より小さい（符号付き） | SF≠OF             |
| `jle` / `jng` | 以下（符号付き）       | ZF=1 または SF≠OF |
| `jg` / `jnle` | より大きい（符号付き） | ZF=0 かつ SF=OF   |
| `jge` / `jnl` | 以上（符号付き）       | SF=OF             |
| `jb` / `jnae` | より小さい（符号なし） | CF=1              |
| `jbe` / `jna` | 以下（符号なし）       | CF=1 または ZF=1  |
| `ja` / `jnbe` | より大きい（符号なし） | CF=0 かつ ZF=0    |
| `jae` / `jnb` | 以上（符号なし）       | CF=0              |
| `js`          | 符号あり（負）         | SF=1              |
| `jns`         | 符号なし（正）         | SF=0              |
| `jo`          | オーバーフロー         | OF=1              |
| `jno`         | オーバーフローなし     | OF=0              |
| `jc`          | キャリーあり           | CF=1              |
| `jnc`         | キャリーなし           | CF=0              |
| `jp` / `jpe`  | パリティ偶数           | PF=1              |
| `jnp` / `jpo` | パリティ奇数           | PF=0              |
| `loop label`  | RCX--, RCX≠0 なら分岐  | —                 |
| `jrcxz label` | RCX=0 なら分岐         | —                 |

## サブルーチン命令

| 命令        | 動作                             |
| :---        | :---                             |
| `call label` | サブルーチン呼び出し             |
| `ret`        | サブルーチン復帰                 |
| `syscall`    | システムコール呼び出し           |
| `sysret`     | システムコールからの復帰（特権） |
| `sysenter`   | 高速システムコール呼び出し       |
| `sysexit`    | 高速システムコールからの復帰     |

## 文字列操作命令

| 命令    | 動作                           |
| :---    | :---                           |
| `LODSB` | AL ← [RSI], RSI++              |
| `LODSQ` | RAX ← [RSI], RSI+=8            |
| `STOSB` | [RDI] ← AL, RDI++              |
| `MOVSB` | [RDI] ← [RSI], RSI++, RDI++    |
| `SCASB` | CMP AL, [RDI]; RDI++           |
| `CMPSB` | CMP [RSI], [RDI]; RSI++, RDI++ |
| `REP`   | RCX > 0 の間繰り返す           |
| `REPE`  | RCX > 0 かつ ZF=1 の間繰り返す |
| `REPNE` | RCX > 0 かつ ZF=0 の間繰り返す |
| `CLD`   | DF=0                           |
| `STD`   | DF=1                           |

## システム制御命令

| 命令      | 動作                             |
| :---      | :---                             |
| `cli`     | 割り込み禁止                     |
| `sti`     | 割り込み許可                     |
| `hlt`     | CPU 停止                         |
| `nop`     | 何もしない                       |
| `cpuid`   | CPU 情報の取得                   |
| `rdtsc`   | タイムスタンプカウンタ読み込み   |

## アドレッシングモード（64-bit モード）

`[base + index * scale + displacement]` の形式に加え、RIP 相対が基本：

| モード                         | 例                                            |
| :---                           | :---                                          |
| 即値                           | `mov rax, 42`                                 |
| レジスタ                       | `mov rax, rbx`                                |
| 間接（レジスタ Only）          | `mov rax, [rbx]`                              |
| ベース + 変位                  | `mov rax, [rbx + 8]`                          |
| ベース + インデックス          | `mov rax, [rbx + rsi]`                        |
| インデックス * スケール + 変位 | `mov rax, [rsi * 8 + 16]`                     |
| RIP 相対（推奨）               | `mov rax, [rel msg]`                          |
| RIP 相対（暗黙）               | `lea rsi, [msg]`（NASM の 64-bit デフォルト） |

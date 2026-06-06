# 6502 (MOS Technology 6502) 命令リファレンス

8-bit マイクロプロセッサ。アキュムレータ（A）ベースのアーキテクチャで、X/Y インデックスレジスタを持つ。ハードウェアスタック（$0100-$01FF）とゼロページ（$00-$FF）の高速アクセスが特徴。

## レジスタ

| レジスタ | サイズ | 名称             | 説明                           |
| :---     | :---   | :---             | :---                           |
| `A`      | 8-bit  | Accumulator      | 算術・論理演算の中心           |
| `X`      | 8-bit  | Index Register X | インデックス・カウンタ         |
| `Y`      | 8-bit  | Index Register Y | インデックス                   |
| `PC`     | 16-bit | Program Counter  | プログラムカウンタ             |
| `S`      | 8-bit  | Stack Pointer    | スタックポインタ（$0100 基準） |
| `P`      | 8-bit  | Processor Status | フラグレジスタ                 |

### フラグレジスタ (P)

| ビット | フラグ | 名称              | 説明                      |
| :---   | :---   | :---              | :---                      |
| 7      | N      | Negative          | 結果が負（bit 7 が 1）    |
| 6      | V      | Overflow          | 符号付きオーバーフロー    |
| 5      | —      | 常に 1            | —                         |
| 4      | B      | Break             | BRK 命令による割り込み    |
| 3      | D      | Decimal Mode      | BCD 演算モード（ADC/SBC） |
| 2      | I      | Interrupt Disable | 割り込み禁止              |
| 1      | Z      | Zero              | 結果がゼロ                |
| 0      | C      | Carry             | 繰り上がり                |

## データ転送命令

| 命令       | 動作                              |
| :---       | :---                              |
| `LDA #val` | A ← 即値                          |
| `LDA addr` | A ← メモリ                        |
| `LDX #val` | X ← 即値                          |
| `LDX addr` | X ← メモリ                        |
| `LDY #val` | Y ← 即値                          |
| `LDY addr` | Y ← メモリ                        |
| `STA addr` | メモリ ← A                        |
| `STX addr` | メモリ ← X                        |
| `STY addr` | メモリ ← Y                        |
| `TAX`      | X ← A                             |
| `TXA`      | A ← X                             |
| `TAY`      | Y ← A                             |
| `TYA`      | A ← Y                             |
| `TSX`      | X ← S（スタックポインタ読取）     |
| `TXS`      | S ← X（スタックポインタ設定）     |
| `PHA`      | A をスタックに PUSH               |
| `PLA`      | スタックから POP → A              |
| `PHP`      | フラグレジスタを PUSH             |
| `PLP`      | スタックから POP → フラグレジスタ |

## 算術命令

| 命令       | 動作                   |
| :---       | :---                   |
| `ADC #val` | A ← A + val + C        |
| `ADC addr` | A ← A + [addr] + C     |
| `SBC #val` | A ← A - val - (1-C)    |
| `SBC addr` | A ← A - [addr] - (1-C) |
| `INC addr` | メモリ ← メモリ + 1    |
| `DEC addr` | メモリ ← メモリ - 1    |
| `INX`      | X++                    |
| `DEX`      | X--                    |
| `INY`      | Y++                    |
| `DEY`      | Y--                    |

**BCD モード（D=1）時**: ADC / SBC は 10 進演算を行う。

## 論理命令

| 命令       | 動作                                 |
| :---       | :---                                 |
| `AND #val` | A ← A & val                          |
| `ORA #val` | A ← A \| val                         |
| `EOR #val` | A ← A ^ val                          |
| `BIT addr` | A & [addr]（フラグのみ、N/V も設定） |

## シフト・ローテート命令

| 命令       | 動作                             |
| :---       | :---                             |
| `ASL A`    | A ← A << 1（C ← bit 7）          |
| `ASL addr` | メモリ ← メモリ << 1             |
| `LSR A`    | A ← A >> 1（bit 0 → C）          |
| `LSR addr` | メモリ ← メモリ >> 1             |
| `ROL A`    | A ← (A << 1) \| C（C を LSB へ） |
| `ROL addr` | メモリ ← メモリ << 1 \| C        |
| `ROR A`    | A ← (A >> 1) \| (C << 7)         |
| `ROR addr` | メモリ ← メモリ >> 1 \| (C << 7) |

## 比較命令

| 命令       | 動作                     |
| :---       | :---                     |
| `CMP #val` | A - val（フラグのみ）    |
| `CMP addr` | A - [addr]（フラグのみ） |
| `CPX #val` | X - val（フラグのみ）    |
| `CPX addr` | X - [addr]（フラグのみ） |
| `CPY #val` | Y - val（フラグのみ）    |
| `CPY addr` | Y - [addr]（フラグのみ） |

## 分岐命令

全条件分岐は **相対アドレッシング** で、-128〜+127 バイトの範囲。

| 命令        | 分岐条件           | テストフラグ |
| :---        | :---               | :---         |
| `BEQ label` | 等しい             | Z=1          |
| `BNE label` | 等しくない         | Z=0          |
| `BCS label` | Carry セット       | C=1          |
| `BCC label` | Carry クリア       | C=0          |
| `BMI label` | マイナス（負）     | N=1          |
| `BPL label` | プラス（正/ゼロ）  | N=0          |
| `BVS label` | オーバーフロー     | V=1          |
| `BVC label` | オーバーフローなし | V=0          |

## サブルーチン命令

| 命令       | 動作                                |
| :---       | :---                                |
| `JMP addr` | PC ← addr（絶対/間接）              |
| `JSR addr` | PC+2 → スタック, PC ← addr          |
| `RTS`      | PC ← スタック（+1）                 |
| `RTI`      | P ← スタック, PC ← スタック         |
| `BRK`      | 強制割り込み（B=1 で PC, P を保存） |

## システム制御命令

| 命令  | 動作                    |
| :---  | :---                    |
| `CLC` | C = 0                   |
| `SEC` | C = 1                   |
| `CLD` | D = 0（BCD モード解除） |
| `SED` | D = 1（BCD モード設定） |
| `CLI` | I = 0（割り込み許可）   |
| `SEI` | I = 1（割り込み禁止）   |
| `CLV` | V = 0                   |
| `NOP` | 何もしない              |

## アドレッシングモード

6502 は 13 のアドレッシングモードを持つ：

| モード                     | 構文      | 例                        |
| :---                       | :---      | :---                      |
| 即値（Immediate）          | `#val`    | `LDA #$42`                |
| ゼロページ（Zero Page）    | `$NN`     | `LDA $20`                 |
| ゼロページ,X（ZP,X）       | `$NN,X`   | `LDA $20,X`               |
| ゼロページ,Y（ZP,Y）       | `$NN,Y`   | `LDX $20,Y`               |
| 絶対（Absolute）           | `$NNNN`   | `LDA $1234`               |
| 絶対,X（Absolute,X）       | `$NNNN,X` | `LDA $1234,X`             |
| 絶対,Y（Absolute,Y）       | `$NNNN,Y` | `LDA $1234,Y`             |
| 間接（Indirect、JMP のみ） | `($NNNN)` | `JMP ($1234)`             |
| インデックス間接事前加算   | `($NN,X)` | `LDA ($20,X)`             |
| インデックス間接事後加算   | `($NN),Y` | `LDA ($20),Y`             |
| アキュムレータ             | `A`       | `ASL A`                   |
| インプライド               | （暗黙）  | `TAX`, `CLC`              |
| 相対（分岐のみ）           | `label`   | `BEQ label`（-128〜+127） |

### Indexed Indirect vs Indirect Indexed

```text
($NN,X) — Indexed Indirect:
   アドレス = ZeroPage[($NN + X) mod 256] から取得した 16-bit アドレス
   「X でインデックス → 間接参照」

($NN),Y — Indirect Indexed:
   アドレス = ZeroPage[$NN] から取得した 16-bit アドレス + Y
   「間接参照 → Y でインデックス」
```

# RISC-V 32-bit (RV32IM) 命令リファレンス

RISC-V はオープンアーキテクチャの ISA。RV32I は32ビットの基本整数命令セット（47命令）。本教材では実用性のため乗除算拡張（M）を含む RV32IM を使用。

## レジスタ

| レジスタ | ABI名  | 用途                            |
| :---     | :---   | :---                            |
| x0       | zero   | 常にゼロ（書き込み無視）        |
| x1       | ra     | リターンアドレス                |
| x2       | sp     | スタックポインタ                |
| x3       | gp     | グローバルポインタ              |
| x4       | tp     | スレッドポインタ                |
| x5–x7    | t0–t2  | 一時レジスタ（caller-saved）    |
| x8       | s0/fp  | 保存レジスタ / フレームポインタ |
| x9       | s1     | 保存レジスタ（callee-saved）    |
| x10–x11  | a0–a1  | 関数引数 / 戻り値               |
| x12–x17  | a2–a7  | 関数引数（caller-saved）        |
| x18–x27  | s2–s11 | 保存レジスタ（callee-saved）    |
| x28–x31  | t3–t6  | 一時レジスタ（caller-saved）    |

## データ転送命令

| 命令                  | 動作                                          |
| :---                  | :---                                          |
| `lw rd, offset(rs1)`  | rd ← メモリ[rs1+offset]（32ビット）           |
| `lh rd, offset(rs1)`  | rd ← メモリ[rs1+offset]（16ビット、符号拡張） |
| `lhu rd, offset(rs1)` | rd ← メモリ[rs1+offset]（16ビット、ゼロ拡張） |
| `lb rd, offset(rs1)`  | rd ← メモリ[rs1+offset]（8ビット、符号拡張）  |
| `lbu rd, offset(rs1)` | rd ← メモリ[rs1+offset]（8ビット、ゼロ拡張）  |
| `sw rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（32ビット）          |
| `sh rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（16ビット）          |
| `sb rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（8ビット）           |
| `lui rd, imm`         | rd ← imm << 12（上位20ビット即値）            |
| `auipc rd, imm`       | rd ← PC + (imm << 12)                         |

## 算術命令

| 命令                | 動作                           |
| :---                | :---                           |
| `add rd, rs1, rs2`  | rd ← rs1 + rs2                 |
| `sub rd, rs1, rs2`  | rd ← rs1 - rs2                 |
| `addi rd, rs1, imm` | rd ← rs1 + imm                 |
| `mul rd, rs1, rs2`  | rd ← rs1 × rs2（下位32ビット） |
| `div rd, rs1, rs2`  | rd ← rs1 ÷ rs2（符号付き）     |
| `divu rd, rs1, rs2` | rd ← rs1 ÷ rs2（符号なし）     |
| `rem rd, rs1, rs2`  | rd ← rs1 % rs2（符号付き）     |
| `remu rd, rs1, rs2` | rd ← rs1 % rs2（符号なし）     |

## 論理命令

| 命令                | 動作             |
| :---                | :---             |
| `and rd, rs1, rs2`  | rd ← rs1 AND rs2 |
| `or rd, rs1, rs2`   | rd ← rs1 OR rs2  |
| `xor rd, rs1, rs2`  | rd ← rs1 XOR rs2 |
| `andi rd, rs1, imm` | rd ← rs1 AND imm |
| `ori rd, rs1, imm`  | rd ← rs1 OR imm  |
| `xori rd, rs1, imm` | rd ← rs1 XOR imm |

## シフト・ローテート命令

| 命令                | 動作                            |
| :---                | :---                            |
| `sll rd, rs1, rs2`  | rd ← rs1 << rs2（論理左シフト） |
| `srl rd, rs1, rs2`  | rd ← rs1 >> rs2（論理右シフト） |
| `sra rd, rs1, rs2`  | rd ← rs1 >> rs2（算術右シフト） |
| `slli rd, rs1, imm` | rd ← rs1 << imm                 |
| `srli rd, rs1, imm` | rd ← rs1 >> imm（論理）         |
| `srai rd, rs1, imm` | rd ← rs1 >> imm（算術）         |

## 比較命令

| 命令                 | 動作                                 |
| :---                 | :---                                 |
| `slt rd, rs1, rs2`   | rd ← (rs1 < rs2) ? 1 : 0（符号付き） |
| `sltu rd, rs1, rs2`  | rd ← (rs1 < rs2) ? 1 : 0（符号なし） |
| `slti rd, rs1, imm`  | rd ← (rs1 < imm) ? 1 : 0（符号付き） |
| `sltiu rd, rs1, imm` | rd ← (rs1 < imm) ? 1 : 0（符号なし） |

## 分岐命令

| 命令                    | 動作                                        |
| :---                    | :---                                        |
| `beq rs1, rs2, offset`  | if rs1 == rs2 then PC += offset             |
| `bne rs1, rs2, offset`  | if rs1 != rs2 then PC += offset             |
| `blt rs1, rs2, offset`  | if rs1 < rs2 then PC += offset（符号付き）  |
| `bge rs1, rs2, offset`  | if rs1 >= rs2 then PC += offset（符号付き） |
| `bltu rs1, rs2, offset` | if rs1 < rs2 then PC += offset（符号なし）  |
| `bgeu rs1, rs2, offset` | if rs1 >= rs2 then PC += offset（符号なし） |

## サブルーチン命令

| 命令                   | 動作                       |
| :---                   | :---                       |
| `jal rd, offset`       | rd ← PC+4, PC ← PC+offset  |
| `jalr rd, offset(rs1)` | rd ← PC+4, PC ← rs1+offset |

`ret` は `jalr x0, 0(ra)` の疑似命令。

## システム制御命令

| 命令     | 動作                                       |
| :---     | :---                                       |
| `ecall`  | 環境コール（OS/Runtimeへのシステムコール） |
| `ebreak` | デバッグブレークポイント                   |
| `fence`  | メモリアクセスの順序付け                   |

CSR 読取疑似命令:

| 疑似命令       | 対応CSR  | 動作                 |
| :---           | :---     | :---                 |
| `rdcycle rd`   | mcycle   | サイクルカウンタ読取 |
| `rdtime rd`    | time     | タイムカウンタ読取   |
| `rdinstret rd` | minstret | 命令完了数読取       |

## アドレッシングモード

RISC-V のメモリアクセスは即値オフセット1種類のみ:

| 形式                        | 例             | 動作          |
| :---                        | :---           | :---          |
| ベース + オフセット         | `lw t0, 4(sp)` | addr = sp + 4 |
| レジスタ間接（オフセット0） | `lw t0, 0(a0)` | addr = a0     |

より複雑なアドレッシングは命令の組み合わせで実現:
- インデックス付き: `add t0, a0, t1` → `lw t2, 0(t0)`
- 絶対アドレス: `lui t0, %hi(addr)` → `lw t1, %lo(addr)(t0)`

## 主な疑似命令

| 疑似命令          | 展開                               |
| :---              | :---                               |
| `li rd, imm`      | `lui` + `addi`（即値ロード）       |
| `la rd, label`    | `auipc` + `addi`（アドレスロード） |
| `mv rd, rs`       | `addi rd, rs, 0`                   |
| `nop`             | `addi x0, x0, 0`                   |
| `j offset`        | `jal x0, offset`                   |
| `ret`             | `jalr x0, 0(ra)`                   |
| `bnez rs, offset` | `bne rs, x0, offset`               |
| `beqz rs, offset` | `beq rs, x0, offset`               |
| `not rd, rs`      | `xori rd, rs, -1`                  |
| `neg rd, rs`      | `sub rd, x0, rs`                   |

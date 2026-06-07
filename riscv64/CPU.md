# RISC-V 64-bit (RV64IM) 命令リファレンス

RISC-V はオープンアーキテクチャの ISA。RV64I は64ビットの基本整数命令セット。RV32I の全命令に加え、64ビット専用命令を含む。本教材では乗除算拡張（M）を含む RV64IM を使用。

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

全レジスタが64ビット幅。

## データ転送命令

| 命令                  | 動作                                 |
| :---                  | :---                                 |
| `ld rd, offset(rs1)`  | rd ← メモリ[rs1+offset]（64ビット）  |
| `lw rd, offset(rs1)`  | rd ← signext(メモリ[rs1+offset], 32) |
| `lwu rd, offset(rs1)` | rd ← zeroext(メモリ[rs1+offset], 32) |
| `lh rd, offset(rs1)`  | rd ← signext(メモリ[rs1+offset], 16) |
| `lhu rd, offset(rs1)` | rd ← zeroext(メモリ[rs1+offset], 16) |
| `lb rd, offset(rs1)`  | rd ← signext(メモリ[rs1+offset], 8)  |
| `lbu rd, offset(rs1)` | rd ← zeroext(メモリ[rs1+offset], 8)  |
| `sd rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（64ビット） |
| `sw rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（32ビット） |
| `sh rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（16ビット） |
| `sb rs2, offset(rs1)` | メモリ[rs1+offset] ← rs2（8ビット）  |
| `lui rd, imm`         | rd ← imm << 12                       |
| `auipc rd, imm`       | rd ← PC + (imm << 12)                |

## 算術命令

| 命令                 | 動作                            |
| :---                 | :---                            |
| `add rd, rs1, rs2`   | rd ← rs1 + rs2（64ビット）      |
| `sub rd, rs1, rs2`   | rd ← rs1 - rs2（64ビット）      |
| `addi rd, rs1, imm`  | rd ← rs1 + imm（64ビット）      |
| `addw rd, rs1, rs2`  | rd ← signext((rs1 + rs2)[31:0]) |
| `subw rd, rs1, rs2`  | rd ← signext((rs1 - rs2)[31:0]) |
| `addiw rd, rs1, imm` | rd ← signext((rs1 + imm)[31:0]) |
| `mul rd, rs1, rs2`   | rd ← rs1 × rs2（下位64ビット）  |
| `div rd, rs1, rs2`   | rd ← rs1 ÷ rs2（符号付き）      |
| `divu rd, rs1, rs2`  | rd ← rs1 ÷ rs2（符号なし）      |
| `rem rd, rs1, rs2`   | rd ← rs1 % rs2（符号付き）      |
| `remu rd, rs1, rs2`  | rd ← rs1 % rs2（符号なし）      |

## 論理命令

| 命令                | 動作             |
| :---                | :---             |
| `and rd, rs1, rs2`  | rd ← rs1 AND rs2 |
| `or rd, rs1, rs2`   | rd ← rs1 OR rs2  |
| `xor rd, rs1, rs2`  | rd ← rs1 XOR rs2 |
| `andi rd, rs1, imm` | rd ← rs1 AND imm |
| `ori rd, rs1, imm`  | rd ← rs1 OR imm  |
| `xori rd, rs1, imm` | rd ← rs1 XOR imm |

## シフト命令

| 命令                 | 動作                                   |
| :---                 | :---                                   |
| `sll rd, rs1, rs2`   | rd ← rs1 << rs2（論理左シフト）        |
| `srl rd, rs1, rs2`   | rd ← rs1 >> rs2（論理右シフト）        |
| `sra rd, rs1, rs2`   | rd ← rs1 >> rs2（算術右シフト）        |
| `slli rd, rs1, imm`  | rd ← rs1 << imm                        |
| `srli rd, rs1, imm`  | rd ← rs1 >> imm（論理）                |
| `srai rd, rs1, imm`  | rd ← rs1 >> imm（算術）                |
| `sllw rd, rs1, rs2`  | rd ← signext((rs1[31:0] << rs2[4:0]))  |
| `srlw rd, rs1, rs2`  | rd ← signext((rs1[31:0] >> rs2[4:0]))  |
| `sraw rd, rs1, rs2`  | rd ← signext((rs1[31:0] >>> rs2[4:0])) |
| `slliw rd, rs1, imm` | rd ← signext((rs1[31:0] << imm))       |
| `srliw rd, rs1, imm` | rd ← signext((rs1[31:0] >> imm))       |
| `sraiw rd, rs1, imm` | rd ← signext((rs1[31:0] >>> imm))      |

> レジスタ指定シフトでは `rs2` の下位6ビット（RV64）のみを使用。即値シフトの `imm` 範囲は 0〜63（RV64）。ワード幅シフト（`sllw`/`srlw`/`sraw`）では即値範囲 0〜31、レジスタ指定は下位5ビット。

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
| ベース + オフセット         | `ld t0, 8(sp)` | addr = sp + 8 |
| レジスタ間接（オフセット0） | `ld t0, 0(a0)` | addr = a0     |

より複雑なアドレッシングは命令の組み合わせで実現:
- インデックス付き: `add t0, a0, t1` → `ld t2, 0(t0)`
- 絶対アドレス: `lui t0, %hi(addr)` → `ld t1, %lo(addr)(t0)`
- 64ビットアドレス: `auipc t0, %pcrel_hi(addr)` → `ld t1, %pcrel_lo(addr)(t0)`

## RV64I 追加命令（RV32Iとの差分）

| 命令                        | 説明                                         |
| :---                        | :---                                         |
| `ld` / `sd`                 | 64ビットメモリアクセス                       |
| `lwu`                       | 32ビットゼロ拡張ロード                       |
| `addw` / `subw` / `addiw`   | 32ビット算術（結果を符号拡張して64ビットに） |
| `sllw` / `srlw` / `sraw`    | 32ビットシフト（結果を符号拡張）             |
| `slliw` / `srliw` / `sraiw` | 32ビット即値シフト                           |
| `mulw` / `divw` / `remw`    | 32ビット乗除算                               |

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

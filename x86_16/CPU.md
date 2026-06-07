# 8086 / 80186 / 80286 命令リファレンス

x86 16-bit リアルモード（8086 / 80186 / 80286）の命令セット。後に i386 で 32-bit に拡張された。

## レジスタ

### 汎用レジスタ（16-bit）

| レジスタ | 名称        | 役割                             |
| :---     | :---        | :---                             |
| `AX`     | Accumulator | 算術演算・I/O・戻り値            |
| `BX`     | Base        | ベースアドレス・データ           |
| `CX`     | Counter     | ループカウンタ・シフトカウンタ   |
| `DX`     | Data        | I/O ポートアドレス・乗除算の補助 |

**部分レジスタ**（AX の場合）:

```text
AH (上位8-bit)  AL (下位8-bit)
├───────────────┴───────────────┤
              AX (16-bit)
```

BX → BH / BL、CX → CH / CL、DX → DH / DL。

### ポインタ・インデックスレジスタ

| レジスタ | 名称              | 役割                     |
| :---     | :---              | :---                     |
| `SP`     | Stack Pointer     | スタックのトップ         |
| `BP`     | Base Pointer      | スタックフレームのベース |
| `SI`     | Source Index      | 文字列操作の送信元       |
| `DI`     | Destination Index | 文字列操作の送信先       |

### セグメントレジスタ

| レジスタ | 名称          | 役割               |
| :---     | :---          | :---               |
| `CS`     | Code Segment  | コードの位置       |
| `DS`     | Data Segment  | データの位置       |
| `SS`     | Stack Segment | スタックの位置     |
| `ES`     | Extra Segment | 汎用拡張セグメント |

### フラグレジスタ

| ビット | フラグ | 名称            | 説明                     |
| :---   | :---   | :---            | :---                     |
| 0      | CF     | Carry Flag      | 繰り上がり/繰り下がり    |
| 2      | PF     | Parity Flag     | 結果のパリティ（偶数）   |
| 4      | AF     | Auxiliary Carry | BCD 演算用の補助キャリー |
| 6      | ZF     | Zero Flag       | 結果がゼロ               |
| 7      | SF     | Sign Flag       | 結果が負                 |
| 8      | TF     | Trap Flag       | シングルステップ         |
| 9      | IF     | Interrupt Flag  | 割り込み許可             |
| 10     | DF     | Direction Flag  | 文字列操作の方向         |
| 11     | OF     | Overflow Flag   | 符号付きオーバーフロー   |

## メモリモデル

リアルモードのアドレス計算:

```text
物理アドレス = セグメント×16 + オフセット
例: CS=0x07C0, IP=0x0000 → 物理アドレス 0x7C00
```

| セグメント | デフォルトオフセット | 主な用途       |
| :---       | :---                 | :---           |
| CS         | IP                   | コードフェッチ |
| DS         | BX, SI, DI           | データアクセス |
| SS         | SP, BP               | スタック       |
| ES         | DI（文字列操作時）   | 文字列の送信先 |

> **コラム: なぜx86のセグメントレジスタは4つなのか──Intel 8086の20ビットアドレスへの挑戦**
>
> 8086は16ビットCPUだが20ビットのアドレス空間（1MB）を必要とした。
> セグメント×16＋オフセット方式で16ビットレジスタだけでは扱えないアドレスを表現している。
> CS（コード）、DS（データ）、SS（スタック）、ES（拡張）の4つに分かれた理由は、
> 各メモリアクセスにデフォルトセグメントを決めることで命令サイズを小さく保つためである。
> 例えばコードフェッチは暗黙的にCS:IPを使うので、毎回セグメントを指定する必要がない。
> この設計は後にプロテクトモードのリングプロテクションへと進化する。

## データ転送命令

| 命令           | 動作                                             |
| :---           | :---                                             |
| `MOV dst, src` | dst ← src                                        |
| `MOVSB`        | [ES:DI] ← [DS:SI], SI++, DI++                    |
| `MOVSW`        | 同上、ワード単位                                 |
| `XCHG a, b`    | a ↔ b                                            |
| `LEA reg, mem` | reg ← mem の実効アドレス                         |
| `LDS reg, mem` | reg ← [mem], DS ← [mem+2]                        |
| `LES reg, mem` | reg ← [mem], ES ← [mem+2]                        |
| `PUSH src`     | SP -= 2, [SS:SP] ← src                           |
| `POP dst`      | dst ← [SS:SP], SP += 2                           |
| `PUSHF`        | フラグレジスタを PUSH                            |
| `POPF`         | フラグレジスタを POP                             |
| `PUSHA`        | AX, CX, DX, BX, SP, BP, SI, DI を PUSH（80186+） |
| `POPA`         | 上記を POP（80186+）                             |

## 算術命令

| 命令           | 動作                                  |
| :---           | :---                                  |
| `ADD dst, src` | dst += src                            |
| `ADC dst, src` | dst += src + CF                       |
| `SUB dst, src` | dst -= src                            |
| `SBB dst, src` | dst = dst - src - CF                  |
| `INC dst`      | dst++                                 |
| `DEC dst`      | dst--                                 |
| `NEG dst`      | dst = -dst                            |
| `MUL src`      | AX = AL × src（8-bit）                |
| `MUL src`      | DX:AX = AX × src（16-bit）            |
| `IMUL src`     | 同上、符号付き乗算                    |
| `DIV src`      | AL = AX ÷ src, AH = 余り（8-bit）     |
| `DIV src`      | AX = DX:AX ÷ src, DX = 余り（16-bit） |
| `IDIV src`     | 同上、符号付き除算                    |
| `CBW`          | AL → AX（符号拡張、8→16-bit）         |
| `CWD`          | AX → DX:AX（符号拡張、16→32-bit）     |
| `AAA` / `DAA`  | ASCII / 10 進加算補正                 |
| `AAS` / `DAS`  | ASCII / 10 進減算補正                 |

## 論理命令

| 命令           | 動作        |
| :---           | :---        |
| `AND dst, src` | dst &= src  |
| `OR dst, src`  | dst \|= src |
| `XOR dst, src` | dst ^= src  |
| `NOT dst`      | dst = ~dst  |

## シフト命令

| 命令             | 動作                       |
| :---             | :---                       |
| `SHL dst, count` | 左論理シフト（×2）         |
| `SHR dst, count` | 右論理シフト（÷2）         |
| `SAL dst, count` | 左算術シフト（SHL と同じ） |
| `SAR dst, count` | 算術右シフト（符号維持）   |
| `ROL dst, count` | 左ローテート               |
| `ROR dst, count` | 右ローテート               |
| `RCL dst, count` | CF を含む左ローテート      |
| `RCR dst, count` | CF を含む右ローテート      |

`count` は即値 `1` または `CL` レジスタ（8086 では即値は 1 のみ、80186+ で即値 n 対応）。

## 比較命令

| 命令        | 動作                      |
| :---        | :---                      |
| `CMP a, b`  | a - b（フラグのみ更新）   |
| `TEST a, b` | a AND b（フラグのみ更新） |

## 分岐命令

### 無条件分岐

| 命令        | 動作                             |
| :---        | :---                             |
| `JMP label` | 無条件ジャンプ（short/near/far） |
| `JMP reg`   | レジスタ間接ジャンプ             |

### 条件分岐

| 命令                | 動作                   | 条件              |
| :---                | :---                   | :---              |
| `JE` / `JZ`         | 等しい                 | ZF=1              |
| `JNE` / `JNZ`       | 等しくない             | ZF=0              |
| `JL` / `JNGE`       | より小さい（符号付き） | SF≠OF             |
| `JLE` / `JNG`       | 以下（符号付き）       | ZF=1 または SF≠OF |
| `JG` / `JNLE`       | より大きい（符号付き） | ZF=0 かつ SF=OF   |
| `JGE` / `JNL`       | 以上（符号付き）       | SF=OF             |
| `JB` / `JNAE`       | より小さい（符号なし） | CF=1              |
| `JBE` / `JNA`       | 以下（符号なし）       | CF=1 または ZF=1  |
| `JA` / `JNBE`       | より大きい（符号なし） | CF=0 かつ ZF=0    |
| `JAE` / `JNB`       | 以上（符号なし）       | CF=0              |
| `JS`                | 符号あり（負）         | SF=1              |
| `JNS`               | 符号なし（正）         | SF=0              |
| `JO`                | オーバーフロー         | OF=1              |
| `JNO`               | オーバーフローなし     | OF=0              |
| `JP` / `JPE`        | パリティ偶数           | PF=1              |
| `JNP` / `JPO`       | パリティ奇数           | PF=0              |
| `JC`                | キャリーあり           | CF=1              |
| `JNC`               | キャリーなし           | CF=0              |
| `LOOP label`        | CX--, CX≠0 なら分岐    | —                 |
| `LOOPE` / `LOOPZ`   | CX--, CX≠0 かつ ZF=1   | —                 |
| `LOOPNE` / `LOOPNZ` | CX--, CX≠0 かつ ZF=0   | —                 |
| `JCXZ label`        | CX=0 なら分岐          | —                 |

## サブルーチン命令

| 命令         | 動作                    |
| :---         | :---                    |
| `CALL label` | PUSH IP(/CS), JMP label |
| `RET`        | POP IP(/CS)             |
| `RETF`       | far リターン            |
| `INT n`      | ソフトウェア割り込み    |
| `IRET`       | 割り込みからの復帰      |

## 文字列操作命令

| 命令              | 動作                                |
| :---              | :---                                |
| `LODSB`           | AL ← [DS:SI], SI++                  |
| `LODSW`           | AX ← [DS:SI], SI+=2                 |
| `STOSB`           | [ES:DI] ← AL, DI++                  |
| `STOSW`           | [ES:DI] ← AX, DI+=2                 |
| `MOVSB`           | [ES:DI] ← [DS:SI], SI++, DI++       |
| `MOVSW`           | [ES:DI] ← [DS:SI], SI+=2, DI+=2     |
| `SCASB`           | CMP AL, [ES:DI]; DI++               |
| `SCASW`           | CMP AX, [ES:DI]; DI+=2              |
| `CMPSB`           | CMP [DS:SI], [ES:DI]; SI++, DI++    |
| `CMPSW`           | CMP [DS:SI], [ES:DI]; SI+=2, DI+=2  |
| `REP`             | CX>0 の間、次の文字列命令を繰り返す |
| `REPE` / `REPZ`   | CX>0 かつ ZF=1 の間繰り返す         |
| `REPNE` / `REPNZ` | CX>0 かつ ZF=0 の間繰り返す         |
| `CLD`             | DF=0（SI/DI 増加方向）              |
| `STD`             | DF=1（SI/DI 減少方向）              |

## システム制御命令

| 命令   | 動作                           |
| :---   | :---                           |
| `CLC`  | CF = 0                         |
| `STC`  | CF = 1                         |
| `CMC`  | CF を反転                      |
| `CLI`  | IF = 0（割り込み禁止）         |
| `STI`  | IF = 1（割り込み許可）         |
| `HLT`  | CPU 停止（外部割り込み待ち）   |
| `NOP`  | 何もしない                     |
| `WAIT` | 外部割り込みまたはリセット待ち |
| `LOCK` | バスロックプレフィックス       |

## I/O 命令

| 命令           | 動作                       |
| :---           | :---                       |
| `IN AL, port`  | port から 1 バイト読み込み |
| `IN AL, DX`    | DX ポートから読み込み      |
| `OUT port, AL` | port に 1 バイト書き込み   |
| `OUT DX, AL`   | DX ポートに書き込み        |

## アドレッシングモード

8086 は以下のアドレッシングモードを持つ：

| モード                       | 例                   |
| :---                         | :---                 |
| 即値                         | `MOV AX, 42`         |
| レジスタ                     | `MOV AX, BX`         |
| 直接                         | `MOV AX, [1234h]`    |
| レジスタ間接                 | `MOV AX, [BX]`       |
| ベース + 変位                | `MOV AX, [BX+4]`     |
| インデックス + 変位          | `MOV AX, [SI+8]`     |
| ベース + インデックス        | `MOV AX, [BX+SI]`    |
| ベース + インデックス + 変位 | `MOV AX, [BX+SI+16]` |
| セグメントオーバーライド     | `MOV AX, ES:[BX]`    |

## プロテクトモード関連（80286+）

| 命令         | 動作                                      |
| :---         | :---                                      |
| `LGDT [mem]` | GDT の位置とサイズを GDTR にロード        |
| `SGDT [mem]` | GDTR の内容を保存                         |
| `LIDT [mem]` | IDT をロード                              |
| `SIDT [mem]` | IDTR を保存                               |
| `LMSW src`   | CR0 の低 16-bit（MSW）に書き込み          |
| `SMSW dst`   | MSW を読み込み                            |
| `CLTS`       | CR0.TS ビットをクリア（タスク切り替え後） |
| `LAR`        | アクセス権の読み込み                      |
| `LSL`        | セグメントリミットの読み込み              |
| `ARPL`       | 要求元特権レベルの調整                    |
| `VERR`       | 読み取り可能か検証                        |
| `VERW`       | 書き込み可能か検証                        |

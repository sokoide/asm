# Z80 (Zilog Z80) 命令リファレンス

8-bit マイクロプロセッサ。8080 の上位互換で、IX/IY インデックスレジスタ、裏レジスタ（shadow）、ビット操作命令など 8080 にない拡張を持つ。

## レジスタ

### メインレジスタ

| レジスタ | サイズ | ペア | 説明               |
| :---     | :---   | :--- | :---               |
| `A`      | 8-bit  | —    | アキュムレータ     |
| `F`      | 8-bit  | —    | フラグレジスタ     |
| `B`      | 8-bit  | BC   | カウンタ・データ   |
| `C`      | 8-bit  | —    | I/O ポートアドレス |
| `D`      | 8-bit  | DE   | データ             |
| `E`      | 8-bit  | —    | データ             |
| `H`      | 8-bit  | HL   | メモリアドレス     |
| `L`      | 8-bit  | —    | メモリアドレス     |

### 裏レジスタ（Shadow / Alternate）

| レジスタ  | ペア | 説明               |
| :---      | :--- | :---               |
| `A'`      | —    | アキュムレータの裏 |
| `F'`      | —    | フラグレジスタの裏 |
| `B'` `C'` | BC'  | BC の裏            |
| `D'` `E'` | DE'  | DE の裏            |
| `H'` `L'` | HL'  | HL の裏            |

裏レジスタは `EXX` と `EX AF, AF'` で高速切り替え可能。

> **コラム: なぜZ80に「裏レジスタ」という異形の機能があるのか──1970年代の割り込み処理の現実**
>
> 裏レジスタはわずか2命令（EXX + EX AF,AF'）で4組8本のレジスタ（BC/DE/HL/AF）をすべて入れ替えられる。
> これは割り込みハンドラでレジスタを8回PUSH/POPするレイテンシを避けるためのハードウェア的解決策である。
> ただしIX, IY, SPには裏がないという半端さが、コストと性能のバランスを追求した設計判断を感じさせる。

### 特殊レジスタ

| レジスタ | サイズ | 説明                         |
| :---     | :---   | :---                         |
| `IX`     | 16-bit | インデックスレジスタ X       |
| `IY`     | 16-bit | インデックスレジスタ Y       |
| `SP`     | 16-bit | スタックポインタ             |
| `PC`     | 16-bit | プログラムカウンタ           |
| `I`      | 8-bit  | 割り込みベクタベースアドレス |
| `R`      | 8-bit  | メモリリフレッシュカウンタ   |

### フラグレジスタ (F)

| ビット | フラグ | 名称            | 説明                         |
| :---   | :---   | :---            | :---                         |
| 7      | S      | Sign            | 結果が負                     |
| 6      | Z      | Zero            | 結果が 0                     |
| 5      | Y      | （非公開）    | 演算結果の bit 5 のコピー           |
| 4      | H      | Half Carry      | BCD 演算の補助キャリー       |
| 3      | X      | （非公開）    | 演算結果の bit 3 のコピー           |
| 2      | P/V    | Parity/Overflow | パリティまたはオーバーフロー |
| 1      | N      | Add/Subtract    | 直前の演算が減算             |
| 0      | C      | Carry           | 繰り上がり                   |

## データ転送命令

### 8-bit ロード

| 命令           | 動作                          |
| :---           | :---                          |
| `LD r1, r2`    | r1 ← r2（レジスタ間）         |
| `LD r, n`      | r ← n（即値）                 |
| `LD r, (HL)`   | r ← [HL]                      |
| `LD r, (IX+d)` | r ← [IX + d]                  |
| `LD r, (IY+d)` | r ← [IY + d]                  |
| `LD (HL), r`   | [HL] ← r                      |
| `LD (IX+d), r` | [IX + d] ← r                  |
| `LD (IY+d), r` | [IY + d] ← r                  |
| `LD (HL), n`   | [HL] ← n                      |
| `LD A, (BC)`   | A ← [BC]                      |
| `LD A, (DE)`   | A ← [DE]                      |
| `LD A, (addr)` | A ← [addr]                    |
| `LD (BC), A`   | [BC] ← A                      |
| `LD (DE), A`   | [DE] ← A                      |
| `LD (addr), A` | [addr] ← A                    |
| `LD A, I`      | A ← I（割り込みベクタ）       |
| `LD A, R`      | A ← R（リフレッシュカウンタ） |
| `LD I, A`      | I ← A                         |
| `LD R, A`      | R ← A                         |

### 16-bit ロード

| 命令        | 動作                              |
| :---        | :---                              |
| `LD dd, nn` | dd ← nn（BC/DE/HL/SP に即値）     |
| `LD IX, nn` | IX ← nn                           |
| `LD IY, nn` | IY ← nn                           |
| `LD SP, HL` | SP ← HL                           |
| `LD SP, IX` | SP ← IX                           |
| `LD SP, IY` | SP ← IY                           |
| `PUSH qq`   | SP -= 2, [SP] ← qq（BC/DE/HL/AF） |
| `PUSH IX`   | SP -= 2, [SP] ← IX                |
| `PUSH IY`   | SP -= 2, [SP] ← IY                |
| `POP qq`    | qq ← [SP], SP += 2                |
| `POP IX`    | IX ← [SP], SP += 2                |
| `POP IY`    | IY ← [SP], SP += 2                |

### 交換命令

| 命令          | 動作                         |
| :---          | :---                         |
| `EX DE, HL`   | DE ↔ HL                      |
| `EX AF, AF'`  | AF ↔ AF'（裏アキュムレータ） |
| `EXX`         | BC ↔ BC', DE ↔ DE', HL ↔ HL' |
| `EX (SP), HL` | HL ↔ [SP]                    |
| `EX (SP), IX` | IX ↔ [SP]                    |
| `EX (SP), IY` | IY ↔ [SP]                    |

### ブロック転送

| 命令   | 動作                          |
| :---   | :---                          |
| `LDI`  | [DE] ← [HL], DE++, HL++, BC-- |
| `LDIR` | BC > 0 の間 LDI を繰り返す    |
| `LDD`  | [DE] ← [HL], DE--, HL--, BC-- |
| `LDDR` | BC > 0 の間 LDD を繰り返す    |
| `CPI`  | A - [HL], HL++, BC--          |
| `CPIR` | BC > 0 の間 CPI を繰り返す    |
| `CPD`  | A - [HL], HL--, BC--          |
| `CPDR` | BC > 0 の間 CPD を繰り返す    |

## 算術命令

### 8-bit 算術

| 命令            | 動作                              |
| :---            | :---                              |
| `ADD A, r`      | A ← A + r                         |
| `ADD A, n`      | A ← A + n                         |
| `ADD A, (HL)`   | A ← A + [HL]                      |
| `ADD A, (IX+d)` | A ← A + [IX + d]                  |
| `ADC A, s`      | A ← A + s + C                     |
| `SUB r`         | A ← A - r                         |
| `SUB n`         | A ← A - n                         |
| `SUB (HL)`      | A ← A - [HL]                      |
| `SBC A, s`      | A ← A - s - C（C=1 は前回演算のボローを示す。多倍長減算用） |
| `INC r`         | r++                               |
| `INC (HL)`      | [HL]++                            |
| `INC (IX+d)`    | [IX+d]++                          |
| `DEC r`         | r--                               |
| `DEC (HL)`      | [HL]--                            |
| `DEC (IX+d)`    | [IX+d]--                          |

### 16-bit 算術

| 命令         | 動作                        |
| :---         | :---                        |
| `ADD HL, ss` | HL ← HL + ss（BC/DE/HL/SP） |
| `ADC HL, ss` | HL ← HL + ss + C            |
| `SBC HL, ss` | HL ← HL - ss - C            |
| `ADD IX, pp` | IX ← IX + pp（BC/DE/IX/SP） |
| `ADD IY, rr` | IY ← IY + rr（BC/DE/IY/SP） |
| `INC ss`     | ss++（BC/DE/HL/SP）         |
| `DEC ss`     | ss--                        |

## 論理命令

| 命令       | 動作          |
| :---       | :---          |
| `AND r`    | A ← A & r     |
| `AND n`    | A ← A & n     |
| `AND (HL)` | A ← A & [HL]  |
| `OR r`     | A ← A \| r    |
| `OR n`     | A ← A \| n    |
| `OR (HL)`  | A ← A \| [HL] |
| `XOR r`    | A ← A ^ r     |
| `XOR n`    | A ← A ^ n     |
| `XOR (HL)` | A ← A ^ [HL]  |
| `CPL`      | A ← ~A        |

## シフト・ローテート命令

| 命令       | 動作                                  |
| :---       | :---                                  |
| `RLCA`     | A を左ローテート（bit 7 → C → bit 0） |
| `RLA`      | A を C 含む左ローテート               |
| `RRCA`     | A を右ローテート（bit 0 → C → bit 7） |
| `RRA`      | A を C 含む右ローテート               |
| `RLC r`    | r を左ローテート                      |
| `RLC (HL)` | [HL] を左ローテート                   |
| `RL r`     | r を C 含む左ローテート               |
| `RRC r`    | r を右ローテート                      |
| `RR r`     | r を C 含む右ローテート               |
| `SLA r`    | r を左算術シフト（bit 7 → C, LSB=0）  |
| `SRA r`    | r を算術右シフト（MSB維持）           |
| `SRL r`    | r を論理右シフト（MSB=0）             |

上記はすべて `(IX+d)` / `(IY+d)` でも使用可能（例：`SLA (IX+3)`）。

## ビット操作命令

| 命令            | 動作                            |
| :---            | :---                            |
| `BIT n, r`      | r の bit n をテスト（Z フラグ） |
| `BIT n, (HL)`   | [HL] の bit n をテスト          |
| `BIT n, (IX+d)` | [IX+d] の bit n をテスト        |
| `SET n, r`      | r の bit n を 1 に              |
| `SET n, (HL)`   | [HL] の bit n を 1 に           |
| `RES n, r`      | r の bit n を 0 に              |
| `RES n, (HL)`   | [HL] の bit n を 0 に           |

`n` は 0-7。`(IX+d)` / `(IY+d)` でも使用可能。

## 比較命令

| 命令        | 動作                |
| :---        | :---                |
| `CP r`      | A - r（フラグのみ） |
| `CP n`      | A - n               |
| `CP (HL)`   | A - [HL]            |
| `CP (IX+d)` | A - [IX+d]          |

## 分岐命令

### 無条件分岐

| 命令        | 動作                                 |
| :---        | :---                                 |
| `JP addr`   | PC ← addr（絶対）                    |
| `JP (HL)`   | PC ← HL（間接）                      |
| `JP (IX)`   | PC ← IX                              |
| `JP (IY)`   | PC ← IY                              |
| `JR offset` | PC ← PC + offset（相対。命令長2バイトのため有効範囲は PC-126〜PC+129） |

### 条件分岐

| 命令            | 分岐条件              | テストフラグ |
| :---            | :---                  | :---         |
| `JP cc, addr`   | 条件 cc で絶対分岐    | 下表参照     |
| `JR C, offset`  | Carry なら相対分岐    | C=1          |
| `JR NC, offset` | Carry なしで相対      | C=0          |
| `JR Z, offset`  | ゼロで相対分岐        | Z=1          |
| `JR NZ, offset` | 非ゼロで相対分岐      | Z=0          |
| `DJNZ offset`   | B--; B≠0 なら相対分岐 | —            |

### 条件コード

| cc   | 条件         | フラグ |
| :--- | :---         | :---   |
| `NZ` | 非ゼロ       | Z=0    |
| `Z`  | ゼロ         | Z=1    |
| `NC` | Carry なし   | C=0    |
| `C`  | Carry あり   | C=1    |
| `PO` | パリティ奇数 | P/V=0  |
| `PE` | パリティ偶数 | P/V=1  |
| `P`  | プラス       | S=0    |
| `M`  | マイナス     | S=1    |

## サブルーチン命令

| 命令            | 動作                              |
| :---            | :---                              |
| `CALL addr`     | SP ← SP-2, [SP] ← PC+3, PC ← addr |
| `CALL cc, addr` | 条件成立時に CALL                 |
| `RET`           | PC ← [SP]                         |
| `RET cc`        | 条件成立時に RET                  |
| `RETI`          | 割り込みハンドラからの復帰        |
| `RETN`          | 非マスカブル割り込みからの復帰    |
| `RST n`         | 再起動命令（PC → スタック、n へ） |

`RST n` の飛び先アドレスは `00h`, `08h`, `10h`, `18h`, `20h`, `28h`, `30h`, `38h` の 8 通り。

## 入出力命令

| 命令         | 動作                         |
| :---         | :---                         |
| `IN A, (n)`  | A ← [ポート n]               |
| `IN r, (C)`  | r ← [ポート C]               |
| `INI`        | [HL] ← [ポート C], HL++, B-- |
| `INIR`       | B > 0 の間 INI を繰り返す    |
| `IND`        | [HL] ← [ポート C], HL--, B-- |
| `INDR`       | B > 0 の間 IND を繰り返す    |
| `OUT (n), A` | [ポート n] ← A               |
| `OUT (C), r` | [ポート C] ← r               |
| `OUTI`       | [ポート C] ← [HL], HL++, B-- |
| `OTIR`       | B > 0 の間 OUTI を繰り返す   |
| `OUTD`       | [ポート C] ← [HL], HL--, B-- |
| `OTDR`       | B > 0 の間 OUTD を繰り返す   |

## システム制御命令

| 命令   | 動作                              |
| :---   | :---                              |
| `NOP`  | 何もしない（4 サイクル）          |
| `HALT` | CPU 停止（割り込み/リセット待ち） |
| `DI`   | 割り込み禁止                      |
| `EI`   | 割り込み許可（1命令遅延）         |
| `IM 0` | 割り込みモード 0（8080 互換）     |
| `IM 1` | 割り込みモード 1（RST 38h 固定）  |
| `IM 2` | 割り込みモード 2（ベクタ間接）    |

## アドレッシングモード

| モード                      | 例                  |
| :---                        | :---                |
| 即値                        | `LD A, 42`          |
| 即値拡張（16-bit）          | `LD BC, 1234h`      |
| レジスタ                    | `LD A, B`           |
| レジスタ間接（HL/BC/DE）    | `LD A, (HL)`        |
| インデックス（IX+d / IY+d） | `LD A, (IX+3)`      |
| 絶対                        | `LD A, (1234h)`     |
| 相対（JR）                  | `JR label`          |
| 暗黙                        | `RRA`, `CPL`, `NOP` |
| ビット                      | `BIT 3, (HL)`       |

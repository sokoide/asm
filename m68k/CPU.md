# M68000 (MC68000) 命令リファレンス

Motorola 68000 アーキテクチャ。16-bit 外部データバス・32-bit 内部レジスタの CISC プロセッサ。8 本のデータレジスタと 8 本のアドレスレジスタを持ち、豊富なアドレッシングモードが特徴。

## レジスタ

### データレジスタ（32-bit）

| レジスタ  | 役割               |
| :---      | :---               |
| `D0`      | 汎用・算術・戻り値 |
| `D1`-`D7` | 汎用（スクラッチ） |

部分アクセス：`D0.L`（32-bit）、`D0.W`（16-bit）、`D0.B`（8-bit）。

### アドレスレジスタ（32-bit）

| レジスタ  | 役割                              |
| :---      | :---                              |
| `A0`-`A5` | 汎用アドレスレジスタ              |
| `A6`      | フレームポインタ（慣例的に `FP`） |
| `A7`      | スタックポインタ（`SP`）          |

### ステータスレジスタ (SR)

| ビット | フラグ | 名称           | 説明                              |
| :---   | :---   | :---           | :---                              |
| 15-13  | —      | 割り込み優先度 | 割り込みマスクレベル              |
| 12-10  | —      | 特権状態       | S=1 でスーパーバイザ              |
| 4      | X      | Extend Flag    | 延長キャリ（シフト/加減算で使用） |
| 3      | N      | Negative Flag  | 結果が負                          |
| 2      | Z      | Zero Flag      | 結果が 0                          |
| 1      | V      | Overflow Flag  | 符号付きオーバーフロー            |
| 0      | C      | Carry Flag     | 繰り上がり                        |

### プログラムカウンタ (PC)

32-bit プログラムカウンタ。命令サイズに応じて自動インクリメントされる。

## データ転送命令

| 命令                   | 動作                                 |
| :---                   | :---                                 |
| `move.l src, dst`      | src → dst（32-bit / 16-bit / 8-bit） |
| `move.w src, dst`      | 同上（16-bit）                       |
| `move.b src, dst`      | 同上（8-bit）                        |
| `movea.l src, ay`      | アドレスレジスタへの move            |
| `moveq #imm, d0`       | 即値（-128〜127）をロード（高速）    |
| `lea addr, ay`         | 実効アドレスをアドレスレジスタに     |
| `pea addr`             | 実効アドレスをスタックに PUSH        |
| `movem.l list, -(%sp)` | レジスタ群をスタックに保存           |
| `movem.l (%sp)+, list` | スタックからレジスタ群を復元         |
| `exg rx, ry`           | レジスタ同士の交換                   |
| `swap dn`              | データレジスタの上位/下位ワード交換  |
| `ext.l dn`             | 符号拡張（ワード→ロング）            |
| `ext.w dn`             | 符号拡張（バイト→ワード）            |

## 算術命令

| 命令                  | 動作                             |
| :---                  | :---                             |
| `add.l src, dst`      | dst += src                       |
| `addi.l #val, dst`    | dst += val（即値）               |
| `addq.l #val, dst`    | dst += val（即値、1-8 を高速に） |
| `addx.l src, dst`     | dst += src + X（拡張加算）       |
| `sub.l src, dst`      | dst -= src                       |
| `subi.l #val, dst`    | dst -= val（即値）               |
| `subq.l #val, dst`    | dst -= val（即値、1-8 を高速に） |
| `subx.l src, dst`     | dst -= src - X（拡張減算）       |
| `neg.l dst`           | dst = -dst                       |
| `negx.l dst`          | dst = -dst - X（拡張 neg）       |
| `mulu.w src, dn`      | dn = dn × src（符号なし 16-bit） |
| `muls.w src, dn`      | dn = dn × src（符号付き 16-bit） |
| `divu.w src, dn`      | dn = dn ÷ src（符号なし）        |
| `divs.w src, dn`      | dn = dn ÷ src（符号付き）        |
| `clr.l dst`           | dst = 0                          |
| `cmp.l src, dst`      | dst - src（フラグのみ）          |
| `cmpi.l #val, dst`    | dst - val（フラグのみ）          |
| `cmpm.l (ay)+, (ax)+` | メモリ同士の比較（文字列比較用） |
| `tst.l dst`           | dst - 0（フラグのみ）            |

## 論理命令

| 命令               | 動作                |
| :---               | :---                |
| `and.l src, dst`   | dst &= src          |
| `andi.l #val, dst` | dst &= val（即値）  |
| `andi #val, %sr`   | SR のビットクリア   |
| `or.l src, dst`    | dst \|= src         |
| `ori.l #val, dst`  | dst \|= val（即値） |
| `ori #val, %sr`    | SR のビットセット   |
| `eor.l src, dst`   | dst ^= src          |
| `eori.l #val, dst` | dst ^= val（即値）  |
| `not.l dst`        | dst = ~dst          |

## シフト・ローテート命令

| 命令                | 動作                       |
| :---                | :---                       |
| `lsl.l #count, dn`  | 左論理シフト（×2^n）       |
| `lsr.l #count, dn`  | 右論理シフト（÷2^n）       |
| `asl.l #count, dn`  | 左算術シフト               |
| `asr.l #count, dn`  | 算術右シフト（符号維持）   |
| `rol.l #count, dn`  | 左ローテート               |
| `ror.l #count, dn`  | 右ローテート               |
| `roxl.l #count, dn` | X フラグを含む左ローテート |
| `roxr.l #count, dn` | X フラグを含む右ローテート |

`count` は即値（1-8）またはレジスタ指定（`D0` など）。

## 分岐命令

### 無条件分岐

| 命令          | 動作                               |
| :---          | :---                               |
| `bra label`   | 無条件分岐                         |
| `bsr label`   | サブルーチン呼び出し               |
| `jsr addr`    | 絶対アドレスへサブルーチン呼び出し |
| `rts`         | サブルーチンから復帰               |
| `rtd #offset` | スタックフレームを解放して復帰     |
| `jmp addr`    | 絶対アドレスへジャンプ             |
| `nop`         | 何もしない                         |

### 条件分岐

| 命令           | 動作                     | 条件      |
| :---           | :---                     | :---      |
| `beq`          | 等しい                   | Z=1       |
| `bne`          | 等しくない               | Z=0       |
| `bgt`          | より大（符号付き）       | Z=0 ∧ N=V |
| `bge`          | 以上（符号付き）         | N=V       |
| `blt`          | より小（符号付き）       | N≠V       |
| `ble`          | 以下（符号付き）         | Z=1 ∨ N≠V |
| `bhi`          | より大（符号なし）       | C=0 ∧ Z=0 |
| `bcc` / `bhs`  | 以上（符号なし）         | C=0       |
| `bls`          | 以下（符号なし）         | C=1 ∨ Z=1 |
| `bcs` / `blo`  | より小（符号なし）       | C=1       |
| `bmi`          | マイナス                 | N=1       |
| `bpl`          | プラス                   | N=0       |
| `bvs`          | オーバーフロー           | V=1       |
| `bvc`          | オーバーフローなし       | V=0       |
| `dbra` / `dbf` | デクリメント＋非ゼロ分岐 | —         |

### DBCC 命令

DBRA / DBF は条件分岐とループカウンタの組み合わせ命令。

```asm
dbra dn, label    ; dn--, dn≠-1 なら label へ
```

条件付きバリエーション：

```asm
dbeq dn, label    ; dn--, dn≠-1 かつ条件成立なら label へ
dbne dn, label
dbgt dn, label
...
```

## サブルーチン命令

| 命令                   | 動作                                      |
| :---                   | :---                                      |
| `bsr label`            | PC → スタック、PC = label                 |
| `jsr addr`             | PC → スタック、PC = addr                  |
| `rts`                  | PC ← スタック                             |
| `rtd #offset`          | SP += offset; PC ← スタック               |
| `link ay, #offset`     | SP -= 4, (SP) ← ay; ay = SP; SP += offset |
| `unlk ay`              | SP = ay; ay ← (SP)+                       |
| `movem.l list, -(%sp)` | レジスタ群をスタックに PUSH               |
| `movem.l (%sp)+, list` | スタックから POP                          |

## システム制御命令

| 命令            | 動作                                 |
| :---            | :---                                 |
| `trap #vector`  | トラップ例外（ソフトウェア割り込み） |
| `trapv`         | V=1 でトラップ                       |
| `chk.w src, dn` | 範囲チェック（範囲外で例外）         |
| `illegal`       | 不正命令例外を発生                   |
| `reset`         | 外部リセット信号出力                 |
| `stop #val`     | 全処理停止（割り込み待ち）           |
| `rte`           | 例外からの復帰                       |

## アドレッシングモード

M68000 は 14 のアドレッシングモードを持つ：

| モード                        | 構文                 | 例                     |
| :---                          | :---                 | :---                   |
| 即値                          | `#val`               | `move.l #100, d0`      |
| レジスタ直接                  | `dn` / `ay`          | `move.l d0, d1`        |
| 間接 (An)                     | `(ay)`               | `move.l (a0), d0`      |
| ポストインクリメント          | `(ay)+`              | `move.b (a0)+, d0`     |
| プレデクリメント              | `-(ay)`              | `move.b d0, -(a0)`     |
| 間接 + 変位                   | `disp(ay)`           | `move.l 4(a0), d0`     |
| インデックス間接 + 変位       | `disp(ay, rx)`       | `move.l 4(a0,d0), d1`  |
| インデックス間接 + 8-bit 変位 | `disp(ay, rx.SIZE)`  | `move.l (a0,d0.w), d1` |
| 絶対 Short                    | `addr.W`             | `move.l $4000.W, d0`   |
| 絶対 Long                     | `addr.L`             | `move.l $FF008000, d0` |
| PC 相対 + 変位                | `disp(PC)`           | `lea 8(PC), a0`        |
| PC 相対 + インデックス        | `disp(PC, rx)`       | `move.l (PC,d0), d0`   |
| インプライド                  | （暗黙のオペランド） | `rts`, `nop`           |

## 即値のサイズ指定

m68k では命令にサイズを明示する：

| サフィックス | サイズ | 例                |
| :---         | :---   | :---              |
| `.b`         | 8-bit  | `move.b d0, (a0)` |
| `.w`         | 16-bit | `move.w d0, (a0)` |
| `.l`         | 32-bit | `move.l d0, (a0)` |

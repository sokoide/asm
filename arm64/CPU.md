# ARM64 (AArch64) 命令リファレンス

ARMv8-A アーキテクチャの 64-bit 実行モード。31 本の 64-bit 汎用レジスタと、ロード/ストアアーキテクチャ（メモリアクセスは専用命令のみ）を特徴とする。

## レジスタ

### 汎用レジスタ

| レジスタ      | 役割                            | 呼び出し保存 |
| :---          | :---                            | :---         |
| `X0` - `X7`   | 引数・戻り値（スクラッチ）      | なし         |
| `X8`          | 間接結果レジスタ                | なし         |
| `X9` - `X15`  | スクラッチ                      | なし         |
| `X16` - `X17` | intra-procedure-call スクラッチ | なし         |
| `X18`         | プラットフォーム予約            | —            |
| `X19` - `X28` | 呼び出し保存レジスタ            | あり         |
| `X29` (FP)    | フレームポインタ                | あり         |
| `X30` (LR)    | リンクレジスタ                  | あり         |

**W レジスタ**: X0-X30 の下位 32-bit は `W0`-`W30` としてアクセス可能（ゼロ拡張）。

### 特殊レジスタ

| レジスタ | 名称            | 説明                                   |
| :---     | :---            | :---                                   |
| `SP`     | Stack Pointer   | スタックポインタ                       |
| `PC`     | Program Counter | プログラムカウンタ（直接書き込み不可） |
| `XZR`    | Zero Register   | 常に 0 を返す（読み取り専用）          |
| `NZCV`   | 条件フラグ      | PSTATE の N, Z, C, V ビット            |

### 条件フラグ（PSTATE.NZCV）

| フラグ | 名称     | 説明                                 |
| :---   | :---     | :---                                 |
| N      | Negative | 結果が負（最上位ビットが 1）         |
| Z      | Zero     | 結果が 0                             |
| C      | Carry    | 繰り上がり（符号なしオーバーフロー） |
| V      | oVerflow | 符号付きオーバーフロー               |

`SUBS`, `ADDS`, `CMP`, `CMN`, `TST` などの **S サフィックス付き** 命令のみがフラグを更新する。

## データ転送命令

### 即値ロード

| 命令                        | 動作                                 |
| :---                        | :---                                 |
| `mov xd, #imm`              | xd ← imm16（16-bit 即値をゼロ拡張）  |
| `movz xd, #imm, lsl #shift` | xd ← ZeroExtend(imm << shift)        |
| `movn xd, #imm, lsl #shift` | xd ← NOT(ZeroExtend(imm << shift))   |
| `movk xd, #imm, lsl #shift` | xd の 16-bit フィールドを imm で置換 |

`shift` は 0, 16, 32, 48 のいずれか。`movz` で 64-bit 定数を組み立てる。

```asm
movz x0, #0x1234, lsl #16    ; X0 = 0x12340000
movk x0, #0x5678              ; X0 = 0x12345678
```

### レジスタ間移動

| 命令         | 動作                   |
| :---         | :---                   |
| `mov xd, xn` | xd ← xn                |
| `mvn xd, xn` | xd ← ~xn（ビット反転） |

### メモリアクセス（ロード/ストア）

| 命令                        | 動作                               |
| :---                        | :---                               |
| `ldr xd, [xn]`              | xd ← [xn]（64-bit）                |
| `ldr wd, [xn]`              | wd ← [xn]（32-bit、ゼロ拡張）      |
| `ldrb wd, [xn]`             | wd ← ZeroExtend([xn])（バイト）    |
| `ldrh wd, [xn]`             | wd ← ZeroExtend([xn])（16-bit）    |
| `ldrsb wd, [xn]`            | wd ← SignExtend([xn])（バイト）    |
| `ldrsh wd, [xn]`            | wd ← SignExtend([xn])（16-bit）    |
| `ldrsw xd, [xn]`            | xd ← SignExtend([xn])（32-bit）    |
| `str xd, [xn]`              | [xn] ← xd（64-bit）                |
| `str wd, [xn]`              | [xn] ← wd（32-bit）                |
| `strb wd, [xn]`             | [xn] ← wd（バイト）                |
| `strh wd, [xn]`             | [xn] ← wd（16-bit）                |
| `stp xt1, xt2, [sp, #-16]!` | レジスタペアを PUSH                |
| `ldp xt1, xt2, [sp], #16`   | レジスタペアを POP                 |
| `ldr xd, =label`            | 疑似命令：label のアドレスをロード |

`ldr =label` はアセンブラがリテラルプールを使って展開する疑似命令。

## 算術命令

| 命令                  | 動作                                 |
| :---                  | :---                                 |
| `add xd, xn, #imm`    | xd = xn + imm（即値加算）            |
| `add xd, xn, xm`      | xd = xn + xm（レジスタ加算）         |
| `adds xd, xn, #imm`   | 加算 + フラグ更新                    |
| `adc xd, xn, xm`      | xd = xn + xm + C（繰り上がり加算）   |
| `sub xd, xn, #imm`    | xd = xn - imm                        |
| `sub xd, xn, xm`      | xd = xn - xm                         |
| `subs xd, xn, #imm`   | 減算 + フラグ更新                    |
| `sbc xd, xn, xm`      | xd = xn + xm - C（繰り下がり減算）   |
| `neg xd, xn`          | xd = -xn                             |
| `cmp xn, #imm`        | xn - imm（フラグのみ、`subs` 相当）  |
| `cmp xn, xm`          | xn - xm（フラグのみ）                |
| `cmn xn, xm`          | xn + xm（フラグのみ）                |
| `mul xd, xn, xm`      | xd = xn × xm                         |
| `mneg xd, xn, xm`     | xd = -(xn × xm)                      |
| `smull xd, wn, wm`    | xd = SignExtend(wn) × SignExtend(wm) |
| `umull xd, wn, wm`    | xd = ZeroExtend(wn) × ZeroExtend(wm) |
| `udiv xd, xn, xm`     | xd = xn ÷ xm（符号なし）             |
| `sdiv xd, xn, xm`     | xd = xn ÷ xm（符号付き）             |
| `msub xd, xn, xm, xa` | xd = xa - (xn × xm)                  |
| `madd xd, xn, xm, xa` | xd = xa + (xn × xm)                  |

## 論理命令

| 命令                 | 動作                                 |
| :---                 | :---                                 |
| `and xd, xn, #mask`  | xd = xn & mask                       |
| `and xd, xn, xm`     | xd = xn & xm                         |
| `ands xd, xn, #mask` | AND + フラグ更新                     |
| `orr xd, xn, #mask`  | xd = xn \| mask                      |
| `orr xd, xn, xm`     | xd = xn \| xm                        |
| `eor xd, xn, #mask`  | xd = xn ^ mask                       |
| `eor xd, xn, xm`     | xd = xn ^ xm                         |
| `bic xd, xn, xm`     | xd = xn & ~xm（ビットクリア）        |
| `orn xd, xn, xm`     | xd = xn \| ~xm                       |
| `eon xd, xn, xm`     | xd = xn ^ ~xm                        |
| `tst xn, #mask`      | xn & mask（フラグのみ、`ands` 相当） |

## シフト・ローテート命令

| 命令                 | 動作                             |
| :---                 | :---                             |
| `lsl xd, xn, #shift` | 左論理シフト（×2^n）             |
| `lsr xd, xn, #shift` | 右論理シフト（÷2^n）             |
| `asr xd, xn, #shift` | 算術右シフト（符号維持）         |
| `ror xd, xn, #shift` | 右ローテート                     |
| `lsl xd, xn, xm`     | 可変左論理シフト（レジスタ指定） |
| `lsr xd, xn, xm`     | 可変右論理シフト                 |

`#shift` は 0-63（64-bit の場合）。

## 比較・条件分岐命令

| 命令                         | 動作                    |
| :---                         | :---                    |
| `cmp xn, #imm`               | xn - imm（フラグ更新）  |
| `cmp xn, xm`                 | xn - xm（フラグ更新）   |
| `cmn xn, xm`                 | xn + xm（フラグ更新）   |
| `tst xn, #mask`              | xn & mask（フラグ更新） |
| `ccmp xn, #imm, #nzcv, cond` | 条件付き比較            |

### 条件分岐

| 命令         | 動作                      | 条件フラグ     |
| :---         | :---                      | :---           |
| `b label`    | 無条件分岐                | —              |
| `bl label`   | リンク付き分岐（LR 保存） | —              |
| `ret`        | LR に復帰                 | —              |
| `b.eq label` | 等しい                    | Z=1            |
| `b.ne label` | 等しくない                | Z=0            |
| `b.lt label` | より小さい（符号付き）    | N≠V            |
| `b.le label` | 以下（符号付き）          | Z=1 または N≠V |
| `b.gt label` | より大きい（符号付き）    | Z=0 かつ N=V   |
| `b.ge label` | 以上（符号付き）          | N=V            |
| `b.hi label` | より大きい（符号なし）    | C=1 かつ Z=0   |
| `b.hs label` | 以上（符号なし）          | C=1            |
| `b.lo label` | より小さい（符号なし）    | C=0            |
| `b.ls label` | 以下（符号なし）          | C=0 または Z=1 |
| `b.mi label` | マイナス（負）            | N=1            |
| `b.pl label` | プラス（正/ゼロ）         | N=0            |
| `b.vs label` | オーバーフロー            | V=1            |
| `b.vc label` | オーバーフローなし        | V=0            |

### 比較+分岐（即値比較不要）

| 命令                   | 動作                    |
| :---                   | :---                    |
| `cbz xn, label`        | xn == 0 なら分岐        |
| `cbnz xn, label`       | xn != 0 なら分岐        |
| `tbz xn, #bit, label`  | xn の bit が 0 なら分岐 |
| `tbnz xn, #bit, label` | xn の bit が 1 なら分岐 |

## 条件選択命令

| 命令                     | 動作                               |
| :---                     | :---                               |
| `csel xd, xn, xm, cond`  | 条件が真なら xd=xn、偽なら xd=xm   |
| `csinc xd, xn, xm, cond` | 条件が真なら xd=xn、偽なら xd=xm+1 |
| `csinv xd, xn, xm, cond` | 条件が真なら xd=xn、偽なら xd=~xm  |
| `csneg xd, xn, xm, cond` | 条件が真なら xd=xn、偽なら xd=-xm  |
| `cset xd, cond`          | 条件が真なら xd=1、偽なら xd=0     |
| `csetm xd, cond`         | 条件が真なら xd=-1、偽なら xd=0    |

`csel` で条件分岐なしの三項演算が可能：

```asm
cmp x0, #0
csel x0, x1, x2, eq    ; if (x0 == 0) x0 = x1 else x0 = x2
```

## サブルーチン命令

| 命令                        | 動作                                  |
| :---                        | :---                                  |
| `bl label`                  | LR = PC+4; PC = label（関数呼び出し） |
| `blr xn`                    | LR = PC+4; PC = xn（間接呼び出し）    |
| `ret`                       | PC = LR（復帰）                       |
| `ret xn`                    | PC = xn                               |
| `stp x29, x30, [sp, #-16]!` | 関数プロローグ（FP, LR 保存）         |
| `ldp x29, x30, [sp], #16`   | 関数エピローグ（FP, LR 復元）         |

### 関数プロローグ/エピローグの定石

```asm
my_func:
    stp     x29, x30, [sp, #-16]!   ; FP, LR を保存
    mov     x29, sp                 ; FP = SP（フレーム設定）

    ; ... 本体処理 ...

    ldp     x29, x30, [sp], #16     ; FP, LR を復元
    ret                             ; LR に戻る
```

## システム制御命令

| 命令             | 動作                                   |
| :---             | :---                                   |
| `mrs xd, sysreg` | システムレジスタ → xd                  |
| `msr sysreg, xn` | xn → システムレジスタ                  |
| `nop`            | 何もしない                             |
| `hlt #imm`       | セミホスティング/デバッグトラップ      |
| `svc #imm`       | スーパーバイザコール（システムコール） |
| `wfi`            | 割り込み待ち                           |
| `wfe`            | イベント待ち                           |

### 主なシステムレジスタ

| レジスタ     | 説明                             |
| :---         | :---                             |
| `CNTVCT_EL0` | 仮想タイマーカウンタ値（64-bit） |
| `CNTFRQ_EL0` | タイマー周波数（Hz）             |
| `NZCV`       | 条件フラグレジスタ               |
| `TPIDR_EL0`  | スレッドポインタ                 |
| `FPCR`       | 浮動小数点制御レジスタ           |
| `FPSR`       | 浮動小数点ステータスレジスタ     |

## アドレッシングモード

| モード                       | 例                         |
| :---                         | :---                       |
| ベースレジスタ Only          | `ldr x0, [x1]`             |
| 即値オフセット               | `ldr x0, [x1, #8]`         |
| レジスタオフセット           | `ldr x0, [x1, x2]`         |
| 拡張オフセット               | `ldr x0, [x1, x2, lsl #3]` |
| Pre-index（更新後アクセス）  | `ldr x0, [x1, #8]!`        |
| Post-index（アクセス後更新） | `ldr x0, [x1], #8`         |
| PC 相対                      | `adr x0, label`            |
| PC 相対（大域）              | `adrp x0, label@PAGE`      |

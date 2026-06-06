# PowerPC (32-bit) 命令リファレンス

PowerPC アーキテクチャ（32-bit バリアント）。RISC ベースで、32 本の汎用レジスタと豊富な条件レジスタ（CR）操作が特徴。ロード/ストアアーキテクチャを採用し、メモリアクセスは専用命令のみ。

## レジスタ

### 汎用レジスタ（32-bit）

| レジスタ    | 役割                                                                  |
| :---        | :---                                                                  |
| `R0`        | RA フィールド指定時に限り 0 として扱われる（RB/RS/RD では通常の GPR） |
| `R1`        | スタックポインタ（慣例的に SP）                                       |
| `R2`        | 小規模定数用即値（TOC ポインタ）                                      |
| `R3`-`R10`  | 引数・戻り値（R3 が第1引数・戻り値）                                  |
| `R11`-`R12` | スクラッチ                                                            |
| `R13`-`R31` | 呼び出し保存レジスタ                                                  |

### 特殊レジスタ

| レジスタ | 名称                      | 説明                        |
| :---     | :---                      | :---                        |
| `CR`     | Condition Register        | 8 個の 4-bit 条件フィールド |
| `LR`     | Link Register             | サブルーチンの戻り先        |
| `CTR`    | Count Register            | ループカウンタ              |
| `XER`    | Fixed-Point Exception Reg | キャリー・オーバーフロー    |
| `MSR`    | Machine State Register    | 制御ステータス              |
| `TB`     | Time Base                 | タイマーカウンタ            |

### 条件レジスタ (CR)

CR は 8 つの 4-bit フィールド（CR0-CR7）に分かれる。各フィールドは比較結果を保持：

| ビット | フラグ | 意味               |
| :---   | :---   | :---               |
| 3      | LT     | Less Than（負）    |
| 2      | GT     | Greater Than（正） |
| 1      | EQ     | Equal（ゼロ）      |
| 0      | SO     | Summary Overflow   |

整数比較命令（`cmpw` / `cmpi`）はデフォルトで CR0 を設定する。

## データ転送命令

### 即値ロード

| 命令                 | 動作                                  |
| :---                 | :---                                  |
| `li rd, imm16`       | rd = imm16（16-bit 符号拡張即値）     |
| `lis rd, imm16`      | rd = imm16 << 16（上位 16-bit 設定）  |
| `addi rd, ra, imm16` | rd = ra + imm16（即値加算で定数生成） |

PowerPC では 32-bit 定数を `lis` + `ori`（または `addi`）で組み立てる。

```asm
lis r3, 0x1234       ; r3 = 0x12340000
ori r3, r3, 0x5678   ; r3 = 0x12345678
; または簡略:
lis r3, 0x1234
addi r3, r3, 0x5678  ; ただし 0x5678 が符号付き16-bit範囲のときのみ
```

### メモリアクセス（ロード/ストア）

| 命令             | 動作                                         |
| :---             | :---                                         |
| `lbz rd, d(ra)`  | rd = ZeroExtend([ra + d])（バイト読込）      |
| `lhz rd, d(ra)`  | rd = ZeroExtend([ra + d])（16-bit 読込）     |
| `lwz rd, d(ra)`  | rd = [ra + d]（32-bit 読込）                 |
| `lha rd, d(ra)`  | rd = SignExtend([ra + d])（16-bit 符号拡張） |
| `stb rs, d(ra)`  | [ra + d] = rs（バイト書込）                  |
| `sth rs, d(ra)`  | [ra + d] = rs（16-bit 書込）                 |
| `stw rs, d(ra)`  | [ra + d] = rs（32-bit 書込）                 |
| `lbzu rd, d(ra)` | rd = [ra + d]; ra += d（読込 + 更新）        |
| `stbu rs, d(ra)` | [ra + d] = rs; ra += d（書込 + 更新）        |
| `lwzu rd, d(ra)` | 同上（32-bit）                               |
| `stwu rs, d(ra)` | 同上（32-bit）                               |

### レジスタ間移動

| 命令        | 動作                        |
| :---        | :---                        |
| `mr rd, rs` | rd = rs（疑似命令）         |
| `mfcr rd`   | rd = CR（条件レジスタ→GPR） |
| `mtcr rs`   | CR = rs（GPR→条件レジスタ） |
| `mflr rd`   | rd = LR                     |
| `mtlr rs`   | LR = rs                     |
| `mfctr rd`  | rd = CTR                    |
| `mtctr rs`  | CTR = rs                    |
| `mfxer rd`  | rd = XER                    |
| `mtxer rs`  | XER = rs                    |

## 算術命令

| 命令                 | 動作                                |
| :---                 | :---                                |
| `add rd, ra, rb`     | rd = ra + rb                        |
| `addi rd, ra, imm`   | rd = ra + imm（即値）               |
| `addic rd, ra, imm`  | rd = ra + imm（CA フラグ更新）      |
| `addic. rd, ra, imm` | 同上 + CR0 更新                     |
| `addis rd, ra, imm`  | rd = ra + (imm << 16)               |
| `subf rd, ra, rb`    | rd = rb - ra（注意：逆順）          |
| `subfic rd, ra, imm` | rd = imm - ra                       |
| `mullw rd, ra, rb`   | rd = ra × rb（32-bit 乗算）         |
| `mulhw rd, ra, rb`   | rd = (ra × rb) >> 32（上位 32-bit） |
| `divw rd, ra, rb`    | rd = ra ÷ rb（32-bit 除算）         |
| `divwu rd, ra, rb`   | rd = ra ÷ rb（符号なし）            |
| `neg rd, ra`         | rd = -ra                            |
| `addze rd, ra`       | rd = ra + CA（CA 付き加算）         |
| `subfze rd, ra`      | rd = CA - ra                        |

## 論理命令

| 命令                | 動作                                |
| :---                | :---                                |
| `and rd, ra, rb`    | rd = ra & rb                        |
| `andi. rd, ra, imm` | rd = ra & imm（CR0 更新）           |
| `andc rd, ra, rb`   | rd = ra & ~rb（ビットクリア）       |
| `or rd, ra, rb`     | rd = ra \| rb                       |
| `ori rd, ra, imm`   | rd = ra \| imm                      |
| `orc rd, ra, rb`    | rd = ra \| ~rb                      |
| `xor rd, ra, rb`    | rd = ra ^ rb                        |
| `xori rd, ra, imm`  | rd = ra ^ imm                       |
| `nand rd, ra, rb`   | rd = ~(ra & rb)                     |
| `nor rd, ra, rb`    | rd = ~(ra \| rb)                    |
| `not rd, ra`        | rd = ~ra（`nor rd, ra, ra` の別名） |

## シフト・ローテート命令

| 命令                        | 動作                                      |
| :---                        | :---                                      |
| `slw rd, ra, rb`            | rd = ra << rb（左論理シフト）             |
| `slwi rd, ra, sh`           | rd = ra << sh（即値左シフト）             |
| `srw rd, ra, rb`            | rd = ra >> rb（右論理シフト）             |
| `srwi rd, ra, sh`           | rd = ra >> sh（即値右シフト）             |
| `sraw rd, ra, rb`           | rd = ra >> rb（算術右シフト）             |
| `srawi rd, ra, sh`          | rd = ra >> sh（即値算術右シフト）         |
| `rlwinm rd, ra, sh, mb, me` | 回転 + マスク抽出（ビットフィールド操作） |

`rlwinm` は強力なビット操作命令：

```asm
rlwinm r3, r4, 4, 0, 27    ; r3 = (r4 << 4) & 0xFFFFFFF0
```

## 比較命令

| 命令                | 動作                                  |
| :---                | :---                                  |
| `cmpw ra, rb`       | ra - rb（符号付き、CR0 設定）         |
| `cmpwi ra, imm`     | ra - imm（符号付き）                  |
| `cmplw ra, rb`      | ra - rb（符号なし）                   |
| `cmplwi ra, imm`    | ra - imm（符号なし）                  |
| `cmpw crf, ra, rb`  | ra - rb、結果を CR の指定フィールドに |
| `cmplw crf, ra, rb` | 同上（符号なし）                      |

## 分岐命令

### 無条件分岐

| 命令       | 動作                                  |
| :---       | :---                                  |
| `b label`  | 無条件分岐                            |
| `bl label` | LR = 戻り先; 分岐（サブルーチン呼出） |
| `blr`      | LR に分岐（復帰）                     |
| `bctr`     | CTR に分岐（テーブルジャンプ）        |
| `bctrl`    | LR = 戻り先; CTR に分岐（間接呼出）   |

### 条件分岐

| 命令             | 動作                     | CR 条件                  |
| :---             | :---                     | :---                     |
| `beq label`      | 等しい                   | CR0.EQ=1                 |
| `bne label`      | 等しくない               | CR0.EQ=0                 |
| `blt label`      | より小さい（符号付き）   | CR0.LT=1                 |
| `ble label`      | 以下（符号付き）         | CR0.EQ=1 または CR0.LT=1 |
| `bgt label`      | より大きい（符号付き）   | CR0.GT=1                 |
| `bge label`      | 以上（符号付き）         | CR0.EQ=1 または CR0.GT=1 |
| `bdz label`      | CTR=0 なら分岐           | —                        |
| `bdnz label`     | CTR--; CTR≠0 なら分岐    | —                        |
| `blt crf, label` | 指定 CR フィールドで分岐 | —                        |

分岐は条件付きで LR 保存や CTR デクリメントを組み合わせられる：

```asm
beq label      ; 等しい場合のみ分岐
beqlr          ; 等しい場合、LR に復帰
bdnz label     ; CTR--, CTR≠0 なら分岐
```

## スタック操作

| 命令             | 動作                    |
| :---             | :---                    |
| `stwu rs, d(r1)` | [R1+d] = rs; R1 += d    |
| `lwz rd, d(r1)`  | rd = [R1 + d]           |
| `addi r1, r1, d` | R1 += d（スタック調整） |

標準的な関数プロローグ/エピローグ：

```asm
my_func:
    stwu    r1, -32(r1)     ; スタックフレーム確保（32 バイト）
    mflr    r0              ; LR を保存
    stw     r0, 36(r1)      ; 保存した LR をフレームに退避
    stw     r31, 28(r1)     ; 呼び出し保存レジスタを退避

    ; ... 本体処理 ...

    lwz     r0, 36(r1)      ; LR を復元
    mtlr    r0
    lwz     r31, 28(r1)     ; R31 を復元
    addi    r1, r1, 32      ; スタックフレーム解放
    blr                     ; 復帰
```

## システム制御命令

| 命令          | 動作                             |
| :---          | :---                             |
| `nop`         | 何もしない                       |
| `sc`          | システムコール                   |
| `rfi`         | 割り込みからの復帰               |
| `sync`        | メモリバリア                     |
| `isync`       | 命令同期                         |
| `eieio`       | ストア順序の保証                 |
| `tw ra, rb`   | トリップ（条件付きトラップ）     |
| `twi ra, imm` | 即値トリップ                     |
| `mftb rd`     | Time Base の下位 32-bit 読み込み |
| `mftbu rd`    | Time Base の上位 32-bit 読み込み |

## アドレッシングモード

PowerPC のアドレッシングは 2 つの基本形式：

| モード                      | 構文     | 例                |
| :---                        | :---     | :---              |
| レジスタ間接 + 変位         | `d(ra)`  | `lwz r3, 8(r4)`   |
| レジスタ間接 + インデックス | `ra, rb` | `lwzx r3, r4, r5` |
| 即値（算術）                | `imm`    | `addi r3, r4, 42` |
| 絶対                        | —        | 主に分岐で使用    |

ロード/ストア更新命令（`lwzu` / `stwu`）はアクセス後にベースレジスタを更新する。

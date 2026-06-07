# i386 (Intel 80386) 命令リファレンス

IA-32 アーキテクチャの 32-bit モード命令セット。x86 の 16-bit 時代（8086）からの拡張で、32-bit レジスタと多彩なアドレッシングモードを持つ。

## レジスタ

### 汎用レジスタ（32-bit）

| レジスタ | 名称              | 役割                                 |
| :---     | :---              | :---                                 |
| `EAX`    | Accumulator       | 算術演算・戻り値・システムコール番号 |
| `ECX`    | Counter           | ループカウンタ・シフトカウンタ       |
| `EDX`    | Data              | I/O ポートアドレス・乗除算の補助     |
| `EBX`    | Base              | ベースアドレス                       |
| `ESP`    | Stack Pointer     | スタックトップ                       |
| `EBP`    | Base Pointer      | スタックフレームベース               |
| `ESI`    | Source Index      | 文字列操作の送信元                   |
| `EDI`    | Destination Index | 文字列操作の送信先                   |

### 下位互換の部分レジスタ

```text
EAX (32-bit)
├── AX (16-bit)
│   ├── AH (8-bit) ── 上位
│   └── AL (8-bit) ── 下位
```

ECX → CX / CH / CL、EDX → DX / DH / DL、EBX → BX / BH / BL。
ESP → SP、EBP → BP、ESI → SI、EDI → DI（下位 16-bit のみ）。

### セグメントレジスタ

| レジスタ | 役割               |
| :---     | :---               |
| `CS`     | コードセグメント   |
| `DS`     | データセグメント   |
| `ES`     | 拡張セグメント     |
| `SS`     | スタックセグメント |
| `FS`     | 汎用セグメント     |
| `GS`     | 汎用セグメント     |

### フラグレジスタ (EFLAGS)

| ビット | フラグ | 名称                 | 説明                              |
| :---   | :---   | :---                 | :---                              |
| 0      | CF     | Carry Flag           | 繰り上がり・繰り下がり            |
| 2      | PF     | Parity Flag          | 結果の下位1バイトの1の個数が偶数  |
| 4      | AF     | Auxiliary Carry Flag | BCD 演算用の補助キャリー          |
| 6      | ZF     | Zero Flag            | 結果がゼロ                        |
| 7      | SF     | Sign Flag            | 結果が負（最上位ビット）          |
| 8      | TF     | Trap Flag            | シングルステップ                  |
| 9      | IF     | Interrupt Flag       | 割り込み許可                      |
| 10     | DF     | Direction Flag       | 文字列操作の方向（0=増加,1=減少） |
| 11     | OF     | Overflow Flag        | 符号付きオーバーフロー            |

## データ転送命令

| 命令               | 動作                                  |
| :---               | :---                                  |
| `mov dst, src`     | dst ← src（即値・レジスタ・メモリ。ただし mem→mem 不可） |
| `movzx dst, src`   | dst ← ZeroExtend(src)（ゼロ拡張）     |
| `movsx dst, src`   | dst ← SignExtend(src)（符号拡張）     |
| `xchg a, b`        | a ↔ b（交換）                         |
| `push src`         | ESP -= 4, [ESP] ← src                 |
| `pop dst`          | dst ← [ESP], ESP += 4                 |
| `pusha` / `popa`   | 全汎用レジスタの一括保存・復元        |
| `pushfd` / `popfd` | EFLAGS の保存・復元                   |
| `lea reg, [mem]`   | 実効アドレスを reg に格納             |

## 算術命令

| 命令           | 動作                                        |
| :---           | :---                                        |
| `add dst, src` | dst += src                                  |
| `adc dst, src` | dst += src + CF                             |
| `sub dst, src` | dst -= src                                  |
| `sbb dst, src` | dst = dst - src - CF                        |
| `inc dst`      | dst++                                       |
| `dec dst`      | dst--                                       |
| `neg dst`      | dst = -dst（2 の補数）                      |
| `mul src`      | EDX:EAX = EAX × src（符号なし）             |
| `imul src`     | EDX:EAX = EAX × src（符号付き）             |
| `div src`      | EAX = EDX:EAX ÷ src, EDX = 余り（符号なし） |
| `idiv src`     | 同上（符号付き）                            |

## 論理命令

| 命令           | 動作        |
| :---           | :---        |
| `and dst, src` | dst &= src  |
| `or dst, src`  | dst \|= src |
| `xor dst, src` | dst ^= src  |
| `not dst`      | dst = ~dst  |

## シフト命令

| 命令             | 動作                           |
| :---             | :---                           |
| `shl dst, count` | 左論理シフト（×2^n）           |
| `sal dst, count` | 左算術シフト（SHL と同じ）     |
| `shr dst, count` | 右論理シフト（÷2^n）           |
| `sar dst, count` | 算術右シフト（符号ビット維持） |
| `rol dst, count` | 左ローテート                   |
| `ror dst, count` | 右ローテート                   |
| `rcl dst, count` | CF を含む左ローテート          |
| `rcr dst, count` | CF を含む右ローテート          |

`count` には即値（1-31）または `CL` レジスタを指定する。

## 比較命令

| 命令        | 動作                      |
| :---        | :---                      |
| `cmp a, b`  | a - b（フラグのみ更新）   |
| `test a, b` | a AND b（フラグのみ更新） |

## 分岐命令

| 命令           | 動作                   | 条件（EFLAGS）    |
| :---           | :---                   | :---              |
| `jmp label`    | 無条件ジャンプ         | —                 |
| `je` / `jz`    | 等しい                 | ZF=1              |
| `jne` / `jnz`  | 等しくない             | ZF=0              |
| `jl` / `jnge`  | より小さい（符号付き） | SF≠OF             |
| `jle` / `jng`  | 以下（符号付き）       | ZF=1 または SF≠OF |
| `jg` / `jnle`  | より大きい（符号付き） | ZF=0 かつ SF=OF   |
| `jge` / `jnl`  | 以上（符号付き）       | SF=OF             |
| `jb` / `jnae`  | より小さい（符号なし） | CF=1              |
| `jbe` / `jna`  | 以下（符号なし）       | CF=1 または ZF=1  |
| `ja` / `jnbe`  | より大きい（符号なし） | CF=0 かつ ZF=0    |
| `jae` / `jnb`  | 以上（符号なし）       | CF=0              |
| `js`           | 符号あり（負）         | SF=1              |
| `jns`          | 符号なし（正）         | SF=0              |
| `jo`           | オーバーフロー         | OF=1              |
| `jno`          | オーバーフローなし     | OF=0              |
| `jp` / `jpe`   | パリティ偶数           | PF=1              |
| `jnp` / `jpo`  | パリティ奇数           | PF=0              |
| `jc`           | キャリーあり           | CF=1              |
| `jnc`          | キャリーなし           | CF=0              |
| `loop label`   | ECX--, ECX≠0なら分岐   | —                 |
| `loope label`  | ECX--, ECX≠0かつZF=1   | —                 |
| `loopne label` | ECX--, ECX≠0かつZF=0   | —                 |
| `jecxz label`  | ECX=0なら分岐          | —                 |

## サブルーチン命令

| 命令         | 動作                          |
| :---         | :---                          |
| `call label` | サブルーチン呼び出し          |
| `ret`        | サブルーチン復帰              |
| `int n`      | ソフトウェア割り込み n を発生 |
| `iret`       | 割り込みからの復帰            |

## 文字列操作命令

| 命令    | 動作                                   |
| :---    | :---                                   |
| `lodsb` | AL ← [DS:ESI], ESI++（バイト）         |
| `lodsw` | AX ← [DS:ESI], ESI+=2（ワード）        |
| `lodsd` | EAX ← [DS:ESI], ESI+=4（dword）        |
| `stosb` | [ES:EDI] ← AL, EDI++                   |
| `movsb` | [ES:EDI] ← [DS:ESI], ESI++, EDI++      |
| `scasb` | CMP AL, [ES:EDI]; EDI++                |
| `cmpsb` | CMP [DS:ESI], [ES:EDI]; ESI++, EDI++   |
| `rep`   | ECX > 0 の間、次の文字列命令を繰り返す |
| `repe`  | ECX > 0 かつ ZF=1 の間繰り返す         |
| `repne` | ECX > 0 かつ ZF=0 の間繰り返す         |
| `cld`   | DF=0（ESI/EDI 増加方向）               |
| `std`   | DF=1（ESI/EDI 減少方向）               |

## システム制御命令

| 命令    | 動作                             |
| :---    | :---                             |
| `into`  | OF=1 の場合、割り込み 4 を発生   |
| `cli`   | IF=0（割り込み禁止）             |
| `sti`   | IF=1（割り込み許可）             |
| `hlt`   | CPU 停止                         |
| `nop`   | 何もしない                       |
| `cpuid` | CPU 情報の取得                   |
| `rdtsc` | タイムスタンプカウンタの読み取り |

## I/O 命令

| 命令         | 動作                            |
| :---         | :---                            |
| `in al, dx`  | I/O ポートから 1 バイト読み込み |
| `out dx, al` | I/O ポートに 1 バイト書き込み   |

## アドレッシングモード

i386 のアドレッシングは `[base + index * scale + displacement]` の形式：

| モード                                  | 例                             |
| :---                                    | :---                           |
| 即値                                    | `mov eax, 42`                  |
| レジスタ                                | `mov eax, ebx`                 |
| 間接（レジスタ Only）                   | `mov eax, [ebx]`               |
| ベース + 変位                           | `mov eax, [ebx + 4]`           |
| ベース + インデックス                   | `mov eax, [ebx + esi]`         |
| ベース + インデックス * スケール        | `mov eax, [ebx + esi * 4]`     |
| ベース + インデックス * スケール + 変位 | `mov eax, [ebx + esi * 4 + 8]` |

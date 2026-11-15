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
│   └── 上位 16-bit（独立したレジスタ名なし）
└── 上位 32-bit（独立したレジスタ名なし）
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

## ロングモード移行

16-bit リアルモード → 32-bit 保護モード → 64-bit ロングモード（IA-32e モード）への移行に使う命令と、本リポジトリの `arch/x86_64/qemu/boot.asm`（移行スタブ）が実装する手順の要点。設計は `doc/x86_64_qemu_plan.md` の「ブート方式の設計」に基づく。移行後の実行環境は CPL=0、ページング有効（先頭 1GB を identity map）、IF=0 である。

### 関連指令/命令

| 命令                            | 動作                                                             |
| :---                            | :---                                                             |
| `lgdt [mem]`                    | GDT の位置とサイズを GDTR にロード                               |
| `mov eax, cr0` / `mov cr0, eax` | CR0 の読み書き（bit 0 = PE、bit 31 = PG）                        |
| `mov eax, cr4` / `mov cr4, eax` | CR4 の読み書き（bit 5 = PAE）                                    |
| `mov eax, cr3` / `mov cr3, eax` | CR3 の読み書き（ページテーブル階層 PML4 の物理アドレス）         |
| `rdmsr` / `wrmsr`               | MSR の読み書き（ECX = MSR アドレス、値は EDX:EAX の 64 ビット）  |
| `jmp 0x0018:label`              | ファージャンプ: CS にセレクタをロードし、プリフェッチキューをフラッシュ |
| `in al, 0x92` / `out 0x92, al`  | A20 ゲートの制御（Fast Gate、port 0x92）                         |

これらはすべてロングモードへ入る **前** の 16-bit / 32-bit コードで実行する。ロングモード自体にモード移行専用の命令はなく、移行後は通常の命令セットだけを使う。

### 移行手順（boot.asm の移行スタブ）

ブートセクタ（0x7C00、16-bit）が移行スタブを 0x7E00 へロード済み。スタブは 16-bit で開始し、次の順で 64-bit へ遷移する。

1. **A20 有効化**: port 0x92 の bit 1 (A20 enable) を立てる（bit 0 のファストリセットビットは立てない）
2. **`cli`**: 割り込み禁止。IDT を構築しないため以後 STI しない
3. **`lgdt [gdt_descriptor]`**: GDT をロード
4. **CR0.PE = 1**: 保護モードを有効化
5. **`jmp 0x08:stub_32`**: ファージャンプで 32-bit コードセグメントへ切替
6. **32-bit での準備**: DS/ES/SS にデータセレクタ 0x10 を設定し ESP を初期化。PML4 @0x1000 / PDPT @0x2000 / PD @0x3000 の計 12KB をゼロ初期化し、上位 32 ビットを含む 64 ビットエントリを書き込む。PML4[0] → PDPT、PDPT[0] → PD（P|RW）、PD[0..511] に 2MB ページ 512 個（P|RW|PS）で先頭 1GB を identity map
7. **CR4.PAE = 1**: 物理アドレス拡張を有効化（4 段ページングの前提）
8. **CR3 = 0x1000**: PML4 を指定
9. **EFER.LME = 1**: `rdmsr`/`wrmsr` で MSR `0xC0000080` の bit 8 を立てる（ロングモードイネーブル。LMA は PG 有効化時に CPU が自動で立てる）
10. **CR0.PG = 1**: ページングを有効化（IA-32e モードの互換サブモードで動作）
11. **`jmp 0x18:stub_64`**: L=1 の 64-bit コードセグメントへのファージャンプで 64-bit モードへ
12. **64-bit での初期化**: DS/ES/SS に 0x10 を設定、RSP = 0x90000、`cld`（DF = 0）
13. **`.bss` のゼロ初期化**: リンカが定義する `.bss` 範囲をゼロで埋める
14. **`jmp _start`**: 0x8000 に配置されたシナリオのエントリへ

手順 7〜9（CR4.PAE、CR3、EFER.LME）は **CR0.PG = 0 の間に** 実施する必要がある。ページング有効化後にこれらを変更すると一般保護違反や不定動作になるため、この順序を守る。

### GDT

| セレクタ | 内容                                                                        |
| :---     | :---                                                                        |
| `0x00`   | null ディスクリプタ（CPU の要求で必須）                                     |
| `0x08`   | 32-bit コード: base=0、limit=4GB、G=1、D=1（32-bit）、L=0、P=1、実行/読出   |
| `0x10`   | データ: base=0、limit=4GB、G=1、B=1、P=1、読出/書込                         |
| `0x18`   | 64-bit コード: base=0、limit=4GB、G=1、L=1、D=0、P=1、実行/読出             |

- **L ビット（bit 53）**: CS にロードしたとき 1 なら 64-bit コードセグメントとして 64-bit モードで実行する。L=1 の場合 D ビットは 0 でなければならない
- **D/B ビット（bit 22）**: L=0 のセグメントでの既定オペランド・アドレスサイズを決める（コードで D=1 なら 32-bit、データで B=1 なら SS にロード時に ESP を使う）

### 4 段ページングの構造

CR4.PAE = 1 のロングモードでは CR3 が指す階層を 4 段でたどる。各テーブルは 8 バイトエントリ × 512 個（計 4KB）。

| 段 | テーブル            | VA のインデックスビット | 本ブートでの使い方                             |
| :--- | :---              | :---                    | :---                                           |
| 1  | PML4（CR3 が指す） | 47:39（9bit）           | エントリ 0 が PDPT @0x2000 を指す（P\|RW）      |
| 2  | PDPT               | 38:30（9bit）           | エントリ 0 が PD @0x3000 を指す（P\|RW）        |
| 3  | PD                 | 29:21（9bit）           | 512 エントリすべてが 2MB ページ（P\|RW\|PS）    |
| —  | PT                 | 20:12（9bit）           | **参照されない**（PD の PS=1 で探索が終端）    |

2MB ページでの仮想アドレスのビット分解:

```text
63..48 : 未使用（bit 47 の符号拡張。canonical アドレス）
47..39 : PML4 インデックス   (9bit)
38..30 : PDPT インデックス   (9bit)
29..21 : PD インデックス     (9bit)
20..0  : ページ内オフセット  (21bit、2MB ページ)
```

4KB ページ（PS=0）の場合は 20..12 が PT のインデックス、11..0 がオフセットになるが、本ブートでは使わない。canonical アドレス規則ではビット 63:47 がすべてビット 47 と同じ値（符号拡張）でなければならず、違反は #GP。

### ブートメモリマップ

| アドレス        | 用途                                                                       |
| :---            | :---                                                                       |
| `0x1000–0x3FFF` | ページテーブル（PML4 @0x1000 / PDPT @0x2000 / PD @0x3000、計 12KB）        |
| `0x7C00`        | ブートセクタ（末尾に 0x55AA 署名）                                         |
| `0x7E00`        | 移行スタブ（最大 512 バイト）                                              |
| `0x8000–0xFDFF` | シナリオのコード・データ（`_start` は 0x8000。ロード上限は 0xFE00 未満）   |
| `0x90000`       | スタックトップ（下向きに成長）                                             |

実行フローは `0x7C00` (ブート) → `0x7E00` (スタブ、ここで 16→32→64 に遷移) → `jmp _start` で `0x8000` (シナリオ、64-bit) の順。

### 初期状態

- **CPL=0**: 特権レベル 0 で動作
- **IF=0**: IDT を設定しないため `sti` しない（割り込みは禁止のまま）
- **DF=0**: `cld` 済み（文字列操作は順方向）
- **MSR**: GSBase / KernelGSBase / Star / LStar / FMask などは初期値のまま（s103_syscall で `wrmsr` により設定する）

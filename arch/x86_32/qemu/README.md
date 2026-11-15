# 80386 アセンブラ ワークショップ（QEMU フロッピーブート版）

QEMU フロッピーディスクイメージから SeaBIOS で起動し、16-bit ブートコードから 32-bit 保護モードへ移行して、16550 UART (COM1, I/O 0x3F8) を I/O に使う x86 32-bit ベアメタルアセンブリ言語教材。共通シナリオ S01-S13 で段階的に学ぶ。`common/c` の C ソースを clang でアセンブリに変換して観察する C シナリオ（c01+）もある。

## 前提条件

| ツール           | 用途                   | インストール例           |
| :---             | :---                   | :---                     |
| NASM             | アセンブラ             | `brew install nasm`      |
| ld.lld           | リンカ                 | `brew install llvm`      |
| QEMU (i386)      | エミュレータ           | `brew install qemu`      |
| GNU coreutils    | QEMU プロセス回収 (`timeout`) | `brew install coreutils` |
| gdb              | ステップデバッガ       | `brew install gdb`       |
| ndisasm          | 逆アセンブル (`make dump`) | NASM に同梱          |
| python3          | 出力検証 (`make test`) | —                        |

## ビルドと実行

```bash
make                  # 全シナリオをビルド (bin サイズ検査 + 1.44MB イメージ生成)
make run S=s01_hello  # 特定のシナリオを QEMU で実行 (1 秒のタイムアウト付き)
make runall           # 全シナリオを連続実行（S06/S12 は printf で入力自動送信）
make test             # 全シナリオのシリアル出力を期待値と照合
make clean            # 生成物を削除
```

すべてのシナリオは共通の `boot.asm` を経由して起動する。`boot.asm` が 16-bit リアルモードでディスク（セクタ 2 以降の 32KB）を 0x7E00 へロードし、A20 有効化 → GDT ロード → CR0.PE = 1 で 32-bit 保護モードへ移行した後、0x8000 に配置されたシナリオの `_start` へジャンプする。シナリオ側のソースは `cpu 386` + `bits 32` で書く。

シナリオの追加は `s*.asm` を置くだけで良い（`SCENARIOS` は wildcard で自動検出する）。

## デバッグ

```bash
# QEMU を -S -gdb tcp:127.0.0.1:1234 で起動し gdb を接続 (ステップ実行)
make debug S=s01_hello

# C シナリオ: common/c/c01.c を clang -S でアセンブリ生成してからステップ実行
# (-g 付きのため _start 到達後は break main / list / step で C ソース行が見える)
make debug S=c01

# 命令ごとの逆アセンブル + CPU 状態を s01_hello.trace に記録して less で閲覧
make trace S=s01_hello

# 実行命令数を集計 (実サイクルは make cycles が unsupported を表示)
make icount S=s01_hello

# 逆アセンブル (0x8000 のシナリオ部分のみ、32-bit)
make dump S=s01_hello
```

### make debug

QEMU を `-S`（起動時停止 + gdbstub）でバックグラウンド起動し、gdb をフォアグラウンドで接続する。リモートプロトコルに認証はないため待ち受けは loopback に限定する。

マクロは `debug.gdb` に定義し `-x debug.gdb` で明示ロードする（`.gdbinit` 自動ロードは使わない）。`regs32` マクロで EAX〜EDI、セグメントレジスタ、EIP、EFLAGS（CF/PF/AF/ZF/SF/OF を展開）を表示し、`hook-stop` で毎ストップ時に自動表示する。`_start` 停止時の出力例（s01_hello）:

```text
EAX=00000000 EBX=0000fe00 ECX=00000000 EDX=00000100
ESI=00000004 EDI=0000803e EBP=00000000 ESP=00090000
CS=0008 DS=0010 ES=0010 SS=0010 FS=0000 GS=0000
EIP=00008000 EFLAGS=00000046
CF=0 PF=1 AF=0 ZF=1 SF=0 OF=0
```

CS = 0x08（32-bit コードセグメント）、ESP = 0x90000 で保護モード移行が完了していることが確認できる。`info registers cr0` で CR0.PE = 1 も確認できる。

**ブレークポイントは `hbreak *_start`（ハードウェアブレーク）を使う**: gdb への接続はリセット直後（0xFFF0 実行中）に行われるため、ロード前に置いたソフトウェアブレークポイント（メモリ上の命令を INT 3 に書き換える）は、その後の INT 13h ディスク読み込みが同じアドレスのメモリを上書きして消えてしまう。ハードウェアブレークは CPU のデバッグレジスタでアドレス照合するため、ロード後の 0x8000 の `_start` で確実に止まる。

gdb の操作: `si` = 1 命令実行 / `c` = continue / `b *ADDR` / `info registers` / `x/5i $pc` / `Ctrl-D` で終了。セッション例:

```gdb
(gdb) hbreak *_start
(gdb) c
Breakpoint 1, _start () at s01_hello.asm:20
20	    mov  esi, message          ; ESI = 文字列へのポインタ
(gdb) si
0x00008005 in .print_loop () at s01_hello.asm:22
(gdb) x/5i $pc
=> 0x8005 <.print_loop+0>:	lodsb   al, ptr ds:[esi]
   0x8006 <.print_loop+1>:	or      al,al
   0x8008 <.print_loop+3>:	jz      0x8011 <_start+17>
   0x800a <.print_loop+5>:	call    0x8015 <uart_putc>
   0x800f <.print_loop+10>:	jmp    0x8005 <.print_loop>
```

UART 出力はステップ実行の進行に応じて同じターミナルに表示される。ポートは `GDB_PORT`、gdb は `GDB` 変数で変更できる。デバッグ用 ELF (`$(S).elf`) は `linker-debug.ld` で `.bin` と同一のセクション配置 (`OUTPUT_FORMAT("elf32-i386")`) を持ち、シンボル名とソース行がそのまま使える。

### make trace / make icount / make cycles / make dump

- `make trace S=` は QEMU を `-accel tcg,one-insn-per-tb=on`（1 TB = 1 命令）で起動し、1 命令ごとの逆アセンブルとレジスタを `$(S).trace` に記録する。記録先は `-dfilter` でカーネル領域（0x8000 以降）に限定し、`scenario_halt` への到達で完了する。ログ上限（既定 32MB、`TRACE_MAX_BYTES`）・タイムアウト（`TRACE_SECS`）・QEMU 異常終了では不完全なログを残し、非ゼロ終了する。
- `make icount S=` は実行命令数を報告する。集計は `-dfilter` によりシナリオ本体（0x8000 以降）に限定し、終了ループの `cli`/`hlt` を除外する。`scenario_halt` のアドレスへの到達を検出し、到達前の命令数を表示する。時間切れや異常終了で未到達の場合は失敗を返す。
- `make cycles S=` は `unsupported` を表示する。QEMU TCG はサイクル精度のエミュレーションではないため実サイクル数は求められず、命令数は `make icount` で計測する。
- `make dump S=` は `ndisasm -b 32 -o 0x8000 -e 1024 $(S).bin` でシナリオ部分（0x8000 以降）を 32-bit で逆アセンブルする（`-e 1024` でブートセクタ 512 + 移行スタブ 512 バイトを読み飛ばす）。ブート部分は 16-bit コードなので対象外であり、観察する場合は `ndisasm -b 16 -o 0x7C00` を別に実行する。

## ディレクトリ構造

```text
.
├── boot.asm           # ブートセクタ (`.boot`) + 保護モード移行スタブ (`.stub`)
├── crt0.asm           # C シナリオ共通のスタートアップ（boot.asm 移行済みの環境で main を呼ぶ）
├── linker.ld          # リンカスクリプト（フラットバイナリ出力）
├── linker-debug.ld    # デバッグ用リンカスクリプト（ELF32 出力、同一配置）
├── Makefile
├── README.md
├── debug.gdb          # gdb マクロ（`-x` で明示ロード）
├── test_scenarios.py  # シリアル出力の期待値照合 (make test)
├── count_instructions.py # 実行命令数計測 (make icount。scenario_halt 到達で完走判定)
├── trace_scenario.py  # トレース記録 (make trace)
├── s01_hello.asm      # S01: Hello World
├── s02_registers.asm  # S02: レジスタと算術
├── s03_stack.asm      # S03: スタック操作
├── s04_loops.asm      # S04: ループと条件分岐
├── s05_strings.asm    # S05: 文字列操作
├── s06_serial_in.asm  # S06: シリアル入力
├── s07_subroutines.asm # S07: サブルーチン
├── s08_hardware.asm   # S08: ハードウェアアクセス（8254 PIT）
├── s09_branching.asm  # S09: 条件分岐
├── s10_bitwise.asm    # S10: ビット演算
├── s11_memory.asm     # S11: メモリとブロック操作
├── s12_minishell.asm  # S12: ミニシェル（総合）
└── s13_copybench.asm  # S13: コピー比較ベンチ（全アーキ共通課題）
```

## CPU と実行環境

- ソースは `cpu 386` + `bits 32`（ブート部のみ `bits 16`）、NASM `-f elf32`、リンカは `ld.lld -m elf_i386`。
- 実行モードは **32-bit 保護モード、CPL=0**。ページング無効、IF=0（IDT 未構築のため STI しない）。セグメントはフラット（base=0、limit=4G）。
- スタックは ESP=0x90000 から下方成長。`.bss` は移行スタブがリンカシンボル（`__bss_start`/`__bss_end`）を使ってゼロ初期化するため、シナリオ側の初期化は不要。
- QEMU は `qemu-system-i386 -machine pc -accel tcg -cpu 486`。CPU モデル（486）と命令セット制限（NASM `cpu 386`）は別の概念である: `-cpu 486` は QEMU がエミュレートする CPU の型番であり、`cpu 386` はアセンブラが受け付ける命令の範囲の上限である。ソースを `cpu 386` に限定することで、教材が 80386 の命令セットに収まることをビルド時に保証する。
- 終了は `cli; hlt` のループ。QEMU は HLT 後も動き続けるため `timeout` で回収し、`-no-reboot -no-shutdown` で障害時の再起動を抑止する。
- 引数はレジスタ渡しとし、保存対象レジスタを関数ごとに明示する。

`make test` は各シナリオの QEMU シリアル出力の主要な期待文字列を照合し、`scenario_halt` への到達を `-d cpu` ログで検証する（期待出力後の不正命令・無限ループを失敗にする。テストは一時ディレクトリにコピーしたイメージで実行し、ビルド済みの img は書き換えない）。S08 の PIT 変動値は照合せず、全出力や実機互換性の保証ではない。QEMU の実行時間を実機性能の比較に使わないこと。

## シナリオ一覧

| 番号 | ソース               | テーマ                     | 難易度   |
| :--- | :---                 | :---                       | :---     |
| S01  | `s01_hello.asm`      | Hello World                | ★☆☆☆☆ |
| S02  | `s02_registers.asm`  | レジスタと算術             | ★☆☆☆☆ |
| S03  | `s03_stack.asm`      | スタック操作               | ★★☆☆☆ |
| S04  | `s04_loops.asm`      | ループと条件分岐           | ★★☆☆☆ |
| S05  | `s05_strings.asm`    | 文字列操作                 | ★★☆☆☆ |
| S06  | `s06_serial_in.asm`  | シリアル入力               | ★★★☆☆ |
| S07  | `s07_subroutines.asm`| サブルーチン               | ★★★☆☆ |
| S08  | `s08_hardware.asm`   | ハードウェアアクセス (8254 PIT) | ★★★☆☆ |
| S09  | `s09_branching.asm`  | 条件分岐                   | ★★★★☆ |
| S10  | `s10_bitwise.asm`    | ビット演算                 | ★★★★☆ |
| S11  | `s11_memory.asm`     | メモリとブロック操作       | ★★★★☆ |
| S12  | `s12_minishell.asm`  | ミニシェル（総合）         | ★★★★★ |
| S13  | `s13_copybench.asm`  | コピー比較ベンチ（全アーキ共通課題） | ★★★☆☆ |

---

### S01: Hello World

**難易度**: ★☆☆☆☆

保護モード到達と UART 出力の確認。`boot.asm` が INT 13h でシナリオを 0x8000 へロードし、A20/GDT/CR0.PE で保護モードへ移行した後、`_start` が COM1 に `"Hello, 80386 World!"` を出力して停止する。

| 学習項目                  | 説明                                                     |
| :---                      | :---                                                     |
| ブート → スタブ → `_start` | 0x7C00 → 0x7E00 → 0x8000 の実行フロー                  |
| 32-bit レジスタ           | ESI/EAX を使う文字列出力                                 |
| `lodsb`                   | `[DS:ESI]` から 1 バイト読み込み、ESI をインクリメント   |
| `uart_putc`（16550 ポーリング） | LSR (0x3FD) bit 5 (THRE) 待ち → THR (0x3F8) に書込み |
| `cli` + `hlt`             | 割り込み禁止 → CPU 停止（タイムアウトで QEMU 終了）      |

---

### S02: レジスタと算術

**難易度**: ★☆☆☆☆

EAX〜EDI の 32-bit 汎用レジスタと基本算術を体験する。16-bit 版 (x86_16) の 0x1234 に対して 32-bit 版では 0x12345678 を使う。

| 学習項目                          | 説明                                                     |
| :---                              | :---                                                     |
| `mov`, `add`, `sub`, `inc`, `dec` | 基本算術命令（32-bit オペランド）                        |
| 部分レジスタ                      | AL/AX への書き込みは EAX の下位ビットだけ変更（上位は保持） |
| `print_hex32`                     | EAX を 8 桁の 16 進で表示（ニブル単位の ASCII 変換）     |
| `uart_putc`                       | COM1 への 1 文字出力                                     |

**ポイント**: `mov al, 0xFF` の後でも EAX の bit 31-8 は変化しない。部分レジスタ書き込みが 32-bit 値の残りを壊さないことを `print_hex32` で確認する。

---

### S03: スタック操作

**難易度**: ★★☆☆☆

スタック（LIFO）の動作を理解する。32-bit では 1 回の PUSH/POP が 4 バイト動く点が 16-bit 版との主な違い。

| 学習項目             | 説明                                                     |
| :---                 | :---                                                     |
| `push` / `pop`       | スタックへの保存・復元（ESP が ±4、32-bit 単位）         |
| ESP の 4 バイトステップ | PUSH で ESP: 0x90000 → 0x8FFFC → 0x8FFF8              |
| LIFO                 | 最後に入れたものが最初に出る（POP は PUSH の逆順）       |
| SS/ESP 設定不要      | 移行スタブが SS=フラット、ESP=0x90000 に初期化済み       |
| レジスタ保存パターン | `push eax` → 作業 → `pop eax` で値を保護                 |

**ポイント**: PUSH と POP が対になれば ESP は開始値 (0x90000) に戻る。`print_hex32` で ESP の値を表示して確認する。

---

### S04: ループと条件分岐

**難易度**: ★★☆☆☆

`LOOP` 命令と `CMP` + 条件ジャンプを使った反復処理。`TEST` 命令による偶数/奇数判定も学ぶ。

| 学習項目      | 説明                                              |
| :---          | :---                                              |
| `loop`        | ECX をデクリメントし、ECX≠0 ならジャンプ          |
| ループ後の ECX | ループ終了後は 0（32 ビット全体がクリア）         |
| `cmp` + `jle` | 比較 → 条件付きジャンプ（カウントアップループ）   |
| `test` + `jz` | AND を実行せずフラグだけ更新（偶数/奇数判定）     |

**ポイント**: `loop` は ECX をデクリメントしてから判定する。ECX=1 のときは 0 になってジャンプしない。16-bit 版の CX に対し、32-bit 版では ECX 全体が減っていく。

---

### S05: 文字列操作

**難易度**: ★★☆☆☆

文字列命令群と `REP` プレフィックスを学ぶ。16-bit では暗黙レジスタが SI/DI だったものが、32-bit では ESI/EDI になる（命令の動作は同じ、ポインタ幅が 32-bit になっただけ）。

| 学習項目        | 説明                                            |
| :---            | :---                                            |
| `lodsb`         | `[DS:ESI]` → AL、ESI++                          |
| `stosb`         | AL → `[ES:EDI]`、EDI++                          |
| `scasb`         | AL と `[ES:EDI]` を比較、EDI++                  |
| `rep` / `repne` | ECX 回繰り返し（等しい/等しくない間）           |
| `cld` / `std`   | ディレクションフラグ（ESI/EDI の増加/減少方向） |
| `repne scasb`   | null 検索で文字列長を測定                       |
| `rep movsb`     | ECX バイトを一括コピー                          |

**ポイント**: ワーキングバッファは `.bss` に置く。移行スタブが `__bss_start`..`__bss_end` をゼロ初期化済みなので、シナリオ側のバッファ初期化は不要。

---

### S06: シリアル入力

**難易度**: ★★★☆☆

16550 UART から文字を読み込み、エコーバックする対話型プログラム。Enter キーで終了する。`make runall` では `printf 'q\n'` がパイプ入力される。

| 学習項目              | 説明                                         |
| :---                  | :---                                         |
| `uart_getc`           | UART 受信サブルーチン                        |
| LSR (0x3FD) bit 0     | Data Ready — 1 = 受信データあり              |
| RBR (0x3F8) 読み込み  | `in al, dx` で受信データ取得                 |
| ポーリングループ      | `in` → `test al, 0x01` → `jz` でデータ待ち  |
| エコーバック          | 受信文字をそのまま `uart_putc` で出力        |
| Enter (CR/LF) 判定    | `cmp al, 13` / `cmp al, 10` で入力終了判定   |

**ポイント**: IDT 未構築のため割り込み駆動は使えず、LSR のポーリングで入力を待つ。送信 (THRE, bit 5) と受信 (DR, bit 0) の対称性を S01 の `uart_putc` と対比する。

---

### S07: サブルーチン

**難易度**: ★★★☆☆

`CALL` / `RET` による関数呼び出しと、レジスタ経由のパラメータ渡しを学ぶ。

| 学習項目         | 説明                                                |
| :---             | :---                                                |
| `call` / `ret`   | 32-bit の戻りアドレス（4 バイト）をスタックに保存・復元 |
| パラメータ渡し   | 呼び出し前にレジスタ（EAX, ESI 等）に値を設定       |
| `push` / `pop`   | 使用するレジスタを個別に保存・復元                  |
| ネスト呼び出し   | サブルーチンからさらに `call` で別の関数を呼ぶ      |
| スタック利用     | CPL=0 のため特別な設定なしにスタックが使える        |

**ポイント**: CALL が積む戻りアドレスは 32-bit（4 バイト）。S03 で学んだ PUSH/POP の 4 バイトステップと同じ単位である。

---

### S08: ハードウェアアクセス（8254 PIT）

**難易度**: ★★★☆☆

Intel 8254 PIT (Programmable Interval Timer) のカウンタ値を I/O ポート経由で読み取る。

| 学習項目               | 説明                                              |
| :---                   | :---                                              |
| PIT カウンタ 0         | I/O ポート 0x40（16-bit カウンタ値）              |
| PIT 制御レジスタ       | I/O ポート 0x43（カウンタラッチ指示）             |
| `out` でラッチ         | 制御レジスタに `0x00` を書き込みカウンタ凍結      |
| `in` の読み取り順序    | ローバイト → ハイバイトの順に読む                 |
| `movzx`                | 16-bit → 32-bit のゼロ拡張（386 で新設された命令）|
| カウンタの変動         | 1.193182 MHz / 65536 ≈ 18.2 Hz でカウントダウン中、値は実行のたびに変わる |

**ポイント**: IN/OUT は IOPL > CPL のとき許される特権命令だが、本環境は CPL=0（最高特権）なので IOPL の値に関係なく実行できる。

---

### S09: 条件分岐

**難易度**: ★★★★☆

`CMP` + 条件ジャンプのうち、符号付き比較（JL/JG、SF/OF 判定）と符号なし比較（JB/JA、CF/ZF 判定）の違いを学ぶ。

| 学習項目           | 説明                                              |
| :---               | :---                                              |
| `cmp`              | 減算結果でフラグのみ更新（オペランドは変更しない）|
| `je` / `jne`       | ZF=1 で等しい / ZF=0 で等しくない                 |
| `jl` / `jg`（符号付き） | SF≠OF / ZF=0 かつ SF=OF でジャンプ           |
| `jb` / `ja`（符号なし） | CF=1 / CF=0 かつ ZF=0 でジャンプ              |
| 判定チェーン       | `cmp` → 分岐の if-else 構築                       |

**ポイント**: 同じビットパターン `0xFFFFFFFF` と `1` の `cmp` で、`jl` は「-1 < 1」で成立し、`ja` は「4294967295 > 1」で成立する。フラグは同じでも解釈する条件コードが異なる。なお `print_str` 内の `or` がフラグを壊すため、`cmp` は分岐の直前に置く。

---

### S10: ビット演算

**難易度**: ★★★★☆

AND / OR / XOR / SHL / SHR / ROR を 32 ビット幅で使い、ビット単位の操作を理解する。32 桁の 2 進表示サブルーチンも実装する。

| 学習項目             | 説明                                                  |
| :---                 | :---                                                  |
| `and`                | マスク抽出（`0x5A5A5A5A AND 0x0F0F0F0F`）             |
| `or` / `xor`         | ビット結合 / トグル・レジスタのゼロ化                 |
| `shl` / `shr`        | 32 ビットの論理シフト（bit 31 の繰り出し・繰り入り）  |
| `ror`                | 32 ビットの回転（はみ出したビットは反対側へ戻る）     |
| `print_bin32`        | 32 桁の 2 進表示                                      |

**ポイント**: `shl 0x40000000, 1` は bit 31 に繰り上がって `0x80000000` になり、さらにシフトすると bit 31 が失われる（16-bit では表現できなかった桁）。`ror eax, 8` は `0x12345678` → `0x78123456` で、下位 8 ビットが最上位へ回り込む。

---

### S11: メモリとブロック操作

**難易度**: ★★★★☆

メモリへのブロック単位の書き込み・コピーと、386 のアドレッシングモード（base + index × scale）を学ぶ。

| 学習項目             | 説明                                                  |
| :---                 | :---                                                  |
| `rep stosb`          | メモリブロックのフィル（`.` で 20 バイト埋める）      |
| `rep movsb`          | メモリブロックのコピー（`"Hello"` → バッファ）        |
| `[即値オフセット]`   | `mov byte [display+3], 'L'` でインデックス指定        |
| `[EBX+ESI*1]`        | ベース + インデックスアドレッシング                   |
| `[EDI+ESI*4]`        | スケール 4 = dword 配列 `table[i]` が 1 命令（386 の機能） |
| `movzx`              | バイト読み込み後の上位ビットを 0 埋め                 |

**ポイント**: 16-bit にはない「ベース + インデックス × スケール」が 32-bit の学習ポイント。スケールは 1/2/4/8 が使え、`[EBX+ESI*4]` で `table[i]` のアドレス計算が 1 命令で済む。バッファは `.bss`（スタブがゼロ初期化済み）に置き、スタック (ESP=0x90000) とは離れた配置になる。

---

### S12: ミニシェル（総合）

**難易度**: ★★★★★

これまでの全要素（UART 入出力、文字列比較、分岐、サブルーチン）を組み合わせた対話型コマンドシェル。`make runall` では `printf 'help\nquit\n'` がパイプ入力される。

| 学習項目        | 説明                                              |
| :---            | :---                                              |
| REPL            | プロンプト表示 → 行入力 → 判定・実行のループ      |
| `uart_getc`     | シリアル受信（S06 と同様）                        |
| `read_line`     | ラインエディタ（バッファ入力 + バックスペース対応）|
| `strcmp`        | 1 バイトずつ比較して文字列一致を判定（ZF で戻る） |
| コマンド分岐    | `strcmp` → `je` で各コマンド処理へ分岐            |
| バックスペース  | BS (`0x08`) → スペース → BS で文字を消去          |

**コマンド一覧**:

| コマンド | 動作                                  |
| :---     | :---                                  |
| `hello`  | `"Hello, 80386!"` と表示              |
| `help`   | コマンド一覧を表示                    |
| `quit`   | シェル終了 → `"Bye!"` を表示          |

**空行入力**: 何も表示せずプロンプトに戻る。不明なコマンドは `Unknown command` を表示する。

---

### S13: コピー比較ベンチ（全アーキ共通課題）

**難易度**: ★★★☆☆

全アーキテクチャ共通の比較課題。100 バイトのメモリコピーを `REP MOVSB` で行い、宛先 100 バイトの 8 ビットずつの総和（チェックサム）を 16 進 4 桁で出力する。

| 学習項目                  | 説明                                                         |
| :---                      | :---                                                         |
| `rep movsb`               | 1 命令で ECX バイトを一括コピー（ESI/EDI/ECX の 32-bit ブロック転送） |
| チェックサム              | 0+1+...+99 = 4950 = 0x1356                                   |
| 正誤判定                  | 0x1356 と比較し `COPY OK CHECKSUM=1356` / `COPY FAIL CHECKSUM=xxxx` |

**実行出力**: `COPY OK CHECKSUM=1356`（1 行のみ）

**ポイント**: QEMU TCG はサイクル精度ではないため実サイクルは測れない。REP MOVSB の手計算サイクル内訳（8086: 9+17n = 17.09 クロック/バイト）は [`../../../docs/copybench.md`](../../../docs/copybench.md) と x86_16 版に記載しており、386 のブロック転送タイミングは比較表の対象外である。

---

### C01/C02: C → アセンブリ (clang -S)

**難易度**: ★☆☆☆☆

リポジトリ root の `common/c/` にある C ソースを `clang -g -O0 -S`（i386 向け、-cpu 486 で動く 386 ベースライン）でアセンブリに変換し、crt0.asm と一緒にアセンブル・リンクして qemu + gdb で観察する。C01 は `main` だけの最小構成、C02 は関数呼び出し `add()` とローカル変数を含む。生成された `common/c/c01.s` は学習対象なのでビルド後に残り、`make clean` で削除される。

| 学習項目                     | 説明                                                            |
| :---                         | :---                                                            |
| `clang --target=i386-pc-none-elf -g -O0 -S` | 最適化なし・DWARF 付きで 386 用アセンブリを生成（486 で実行可能） |
| `pushl %ebp` / `movl %esp, %ebp` / `subl $24, %esp` | -O0 の関数プロローグ（フレームポインタ EBP + ローカル領域） |
| スタック渡し ABI (cdecl)     | 引数はスタック（callee では `8(%ebp)`, `12(%ebp)`）、戻り値は EAX。呼び出し側が `movl $1, (%esp)` で積み、`addl $N, %esp` で後始末 |
| crt0.asm                     | boot.asm のスタブがモード移行・ESP=0x90000・.bss クリアまで済ませるため、`call main` + hlt だけ |
| DWARF デバッグ情報           | `hbreak *_start` 到達後は `break main` / `list` / `step` で C ソース行単位のステップ実行 |

**使い方**:

```bash
make run S=c01        # QEMU で実行（UART 出力なし、HLT 到達で timeout 回収）
make dump S=c01       # crt0 + clang 生成コードの逆アセンブル (0x8000〜)
make debug S=c01      # qemu + gdb でステップ実行（C ソース行が見える）
make clean            # 生成物とともに common/c/c*.s を削除
```

**ポイント**: x86_32 の cdecl は引数スタック渡し（戻り値のみ EAX）で、m68k 版の gcc ABI と同じ方式。同じ `common/c/c02.c` から生成した x86_64 版・RISC-V 版（引数レジスタ渡し）と `common/c/c02.s` を見比べると、ABI の違いが同じ C ソースから読み取れる。crt0 は UART 出力を持たず main 復帰後に `cli/hlt` で停止するため、C シナリオは runall に含めない（`trace`/`icount` は他シナリオと同じく `scenario_halt` シンボルで完走判定する）。

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: `common/c/c01.s` を開き、`main` のプロローグ（`pushl %ebp` / `movl %esp, %ebp` / `subl $N, %esp`）、`movl $0, -4(%ebp)`、エピローグ（`addl $N, %esp` / `popl %ebp` / `retl`）がそれぞれ何をするか先に予測する。
- **STEP 2 観察**: `make debug S=c01` で `hbreak *_start` 到達後に `break main` → `step` → main 復帰後 EAX=0・ESP が 0x90000 側に戻ることを確認する。`make debug S=c02` では `break add` の 1 回目 `a=1 b=1`、2 回目 `a=20 b=20`、`break scenario_halt` で EAX=0（c-42）を見る。`make dump S=c02` で cdecl の引数積み（`movl $1, (%esp)` など `pushl` ではなく mov で置く点）と callee 側の `8(%ebp)`/`12(%ebp)` 参照も確認する。
- **STEP 3 改造**: `common/c/c01.c` にグローバル変数や配列を追加して再ビルドし、boot.asm スタブの .bss クリア（`rep stosb`）が実行される様子を `make debug` で観察する。
- **STEP 4 考察**: `make build-c S=c01 CFLAGS='--target=i386-pc-none-elf -g -O2 -fno-asynchronous-unwind-tables'` で最適化を変えてビルドし、`make dump S=c01` / `make icount S=c01` で命令数を -O0 と比べる（フレームポインタの保持・消失も x86_64 版と同じ条件で確認する）。

---

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — 80386 命令セットリファレンス（末尾に保護モード関連の補足あり）
- [`../../../docs/x86_32_qemu_plan.md`](../../../docs/x86_32_qemu_plan.md) — 本ディレクトリの整備計画（フェーズと受入条件）
- [`../../../docs/copybench.md`](../../../docs/copybench.md) — 共通課題 s13（100 バイトコピー）の全アーキ比較
- [`../../../README.md`](../../../README.md) — リポジトリ全体のガイド（デバッグガイド・シナリオ規約）
- [`../darwin/README.md`](../darwin/README.md) — macOS ネイティブ版（Mach-O とホスト ABI）
- [`../../x86_16/qemu/README.md`](../../x86_16/qemu/README.md) — 16-bit リアルモード版（本教材の対照）

## ハードウェア情報

### QEMU 起動構成

| 項目               | 値                                                              |
| :---               | :---                                                            |
| QEMU バイナリ      | `qemu-system-i386`                                              |
| マシン / CPU       | `-machine pc -accel tcg -cpu 486`                               |
| 障害時動作         | `-no-reboot -no-shutdown`（トリプルフォルトで QEMU 終了）       |
| フロッピー         | 2880 セクタ（1.44MB）、`dd` で `.bin` を先頭に書き込み          |
| 起動ファームウェア | SeaBIOS（フロッピーからブートセクタを 0000:7C00 へロード）      |
| 終了方法           | `cli; hlt` の停止ループ後、`timeout`（既定 1 秒）で QEMU を回収 |
| 入力（S06/S12）    | `make runall` 時に `printf` でパイプ入力（S06 は `q`+改行、S12 は `help`+`quit`+改行） |

### 16550 UART (COM1)

| I/O ポート | レジスタ名 | 説明                                   | アクセス |
| :---       | :---       | :---                                   | :---     |
| `0x3F8`    | THR / RBR  | 送信保持 / 受信バッファ                | W / R    |
| `0x3FD`    | LSR        | ラインステータスレジスタ               | R        |

**LSR フラグビット**:

| ビット | 名前   | 説明                                   |
| :---   | :---   | :---                                   |
| 0      | DR     | Data Ready — 1 = 受信データあり         |
| 5      | THRE   | Transmitter Holding Register Empty — 1 = 送信可能 |

**送信手順**: LSR (0x3FD) の bit 5 (THRE) をポーリングし、1 になったら THR (0x3F8) に文字を書き込む（`in al, dx` → `test al, 0x20` → `jz` → `out dx, al`）。

**受信手順**: LSR (0x3FD) の bit 0 (DR) をポーリングし、1 になったら RBR (0x3F8) から 1 バイト読み込む（`in al, dx` → `test al, 0x01` → `jz` → `in al, dx`）。

### Intel 8254 PIT (S08 で使用)

| I/O ポート | 用途                            |
| :---       | :---                            |
| `0x40`     | カウンタ 0（16-bit 値）         |
| `0x43`     | 制御レジスタ（`0x00` でラッチ） |

カウンタ 0 の入力クロックは 1.193182 MHz。BIOS が分周比 65536 で初期化するため約 18.2 Hz（周期約 55 ms）でカウントダウンし、ラッチした値は実行のたびに変わる。特権命令の IN/OUT は通常 IOPL > CPL が必要だが、本環境は CPL=0 なのでポートアクセスに制限がない。

### アドレスマップ

| アドレス        | 用途                                                     |
| :---            | :---                                                     |
| `0x7C00-0x7DFF` | ブートセクタ（署名 0xAA55 は 0x7DFE）                    |
| `0x7E00-0x7FFF` | 移行スタブ（A20/GDT/保護モード移行、最大 512 バイト）    |
| `0x8000-0xFDFF` | シナリオのロード領域（`.text` / `.rodata` / `.data`）    |
| `0x8E000`       | `.bss` 上限（`linker.ld` の ASSERT でスタック予約と非重複を検査） |
| `0x90000`       | スタックトップ（下方成長）                               |
| `0xFE00`        | ロードイメージ終端の上限（0xFE00 - 0x7C00 = 33280 バイト制限に対応） |

`.bss` は移行スタブが `__bss_start`..`__bss_end` を `rep stosb` でゼロ初期化する。リンカの ASSERT がブートセクタ 512 バイト、スタブ 512 バイト、イメージ上限、`.bss` とスタック予約領域の非重複をビルド時に検査する。

## I/O ルーチン

本教材は文字入出力に 16550 UART（COM1, `0x3F8`）の I/O ポートを直接操作する方針（「ハードウェア情報」の [16550 UART (COM1)](#16550-uart-com1) を参照）。

**BIOS 割り込み (`INT` 命令) の使用範囲**: ブート直後の **16-bit リアルモード区間のみ**。`boot.asm` の INT 13h AH=02h（ディスク読み込み、AH=00h はエラー時のリセット）だけである。保護モード移行後は IDT が無いため `INT` 命令も使えず、出力はすべて UART の直接ポーリングで行う。x86_16 版のシナリオは BIOS INT 呼び出し（INT 13h ディスク読み込み等）をシナリオ自身が使う場合があるが、本アーキのシナリオ（32-bit 保護モード）は一切 BIOS を使わない。

**定義元**: QEMU が読み込む SeaBIOS ROM。

**uart_putc / uart_getc の実装位置**:

| 場所                    | 名前                     | ビット幅 | 使われる場面                     |
| :---                    | :---                     | :---     | :---                             |
| `boot.asm` (`.boot`)    | `uart_putc16`            | 16-bit   | ディスク読み込み失敗時の通知     |
| 各シナリオ `.asm`       | `uart_putc` / `uart_getc` | 32-bit  | シナリオ本体の出力・入力         |

`uart_putc` は LSR bit 5 (THRE) 待ち → THR 書き込み、`uart_getc` は LSR bit 0 (DR) 待ち → RBR 読み込み。いずれもポーリングのみで割り込みは使わない。

**INT 13h ディスク読み込み（boot.asm）**:

```asm
mov  ah, 0x02        ; 機能: セクタ読み込み
mov  al, 1           ; 読込セクタ数（毎回 1 セクタ）
mov  ch, <cyl>       ; シリンダ (0 始まり) = LBA / 36
mov  cl, <sec>       ; セクタ (1 始まり)   = LBA % 18 + 1
mov  dh, <head>      ; ヘッド = (LBA / 18) % 2
mov  dl, [boot_drive]; ドライブ番号（起動時に DL から保存）
mov  bx, <offset>    ; ES:BX = 転送先 (0000:7E00 から 512 バイトずつ)
int  0x13            ; CF = 1 ならエラー → AH=0 でリセットして再試行
```

ジオメトリは 18 sectors/track、2 heads（1.44MB フロッピー）。セクタ 2 から 64 セクタ（32KB）を 1 セクタずつ読み、エラー時はリセット + 再試行 3 回、それでも失敗したら COM1 に `DISK LOAD ERROR` を出力して停止する。

## 次のステップ

1. `boot.asm` のコメントを読み、ブート → スタブ → `_start` の流れを追う
2. `make dump S=s01_hello` で 0x8000 以降の 32-bit コードを逆アセンブルし、ソースと突き合わせる（ブート部分は `ndisasm -b 16 -o 0x7C00` で別途観察する）
3. `make debug S=s01_hello` で `_start` に止め、`info registers cr0` で CR0.PE = 1 と CS = 0x08 を確認する
4. S03 で `print_hex32` を使って ESP の 4 バイトステップを観察し、16-bit 版（x86_16、SP の 2 バイトステップ）と対比する
5. メッセージやテスト値を書き換えて `make run S=...` と `make test` で確認する
6. リアルモードの基本（セグメント計算、IVT）は [`../../x86_16/qemu/README.md`](../../x86_16/qemu/README.md) から、ホスト ABI は [`../darwin/README.md`](../darwin/README.md) から入る。x86_64 QEMU 版は `docs/x86_64_qemu_plan.md` に整備計画がある

# x86_64 (AMD64) ワークショップ（QEMU フロッピーブート版）

QEMU フロッピーディスクイメージから SeaBIOS で起動し、16-bit ブートコード → 32-bit 保護モード → 64-bit ロングモードへ移行して、16550 UART (COM1, I/O 0x3F8) を I/O に使う x86-64 ベアメタルアセンブリ言語教材。共通シナリオ S01-S13 に加え、x86_64 固有の拡張シナリオ（s101+ 帯）で段階的に学ぶ。`common/c` の C ソースを clang でアセンブリに変換して観察する C シナリオ（c01+）もある。

## 前提条件

| ツール           | 用途                   | インストール例           |
| :---             | :---                   | :---                     |
| NASM             | アセンブラ             | `brew install nasm`      |
| ld.lld           | リンカ                 | `brew install llvm`      |
| QEMU (x86_64)    | エミュレータ           | `brew install qemu`      |
| GNU coreutils    | QEMU プロセス回収 (`timeout`) | `brew install coreutils` |
| gdb              | ステップデバッガ       | `brew install gdb`       |
| nc               | gdb ポートの待ち合わせ (`make debug`) | macOS に標準搭載 |
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

すべてのシナリオは共通の `boot.asm` を経由して起動する。`boot.asm` が 16-bit リアルモードでディスク（セクタ 2 以降の 32KB）を 0x7E00 へロードし、移行スタブが A20 有効化 → GDT ロード → CR0.PE = 1 で保護モードに入った後、ページテーブル 3 枚（PML4 @ 0x1000 / PDPT @ 0x2000 / PD @ 0x3000、先頭 1GB を 2MB ページで identity map）を構築して CR4.PAE → CR3 → EFER.LME → CR0.PG の順でロングモードを有効化し、0x8000 に配置されたシナリオの `_start` へジャンプする。シナリオ側のソースは純粋な `bits 64` コードで書く（モード切替はスタブ側で完結する）。

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
make icount S=s04_loops

# 逆アセンブル (0x8000 のシナリオ部分のみ、64-bit)
make dump S=s01_hello
```

### make debug

QEMU を `-S`（起動時停止 + gdbstub）でバックグラウンド起動し、gdb をフォアグラウンドで接続する。リモートプロトコルに認証はないため待ち受けは loopback に限定する。`make debug` は gdb 接続の前に `nc -z` で gdbstub ポート（`GDB_PORT`、既定 1234）が開くまで待ってから gdb を起動する。起動前にポートが使用中なら失敗し、待機中は QEMU プロセスの生存を確認する。事前確認から QEMU の待ち受け開始までに別プロセスが同じポートを取得する可能性があるため、接続先の同一性を厳密に保証するものではない。

マクロは `debug.gdb` に定義し `-x debug.gdb` で明示ロードする（`.gdbinit` 自動ロードは使わない）。`regs64` マクロで RAX〜RDI、セグメントレジスタ、RIP、EFLAGS（CF/PF/AF/ZF/SF/OF を展開）を表示し、`hook-stop` で毎ストップ時に自動表示する。EFLAGS は QEMU の gdbstub が `$rflags` を提供しないため `$eflags`（下位 32 ビット）を使用する — RFLAGS の上位 32 ビットは予約（0）で、CF/PF/AF/ZF/SF/OF は下位 32 ビットにある。`_start` 停止時の出力例（s01_hello、実測）:

```text
RAX=0000000080000000 RBX=000000000000fe00 RCX=0000000000000000 RDX=0000000000000000
RSI=0000000000000004 RDI=0000000000008043 RBP=0000000000000000 RSP=0000000000090000
CS=0018 DS=0010 ES=0010 SS=0010 FS=0000 GS=0000
RIP=0000000000008000 EFLAGS=00000046
CF=0 PF=1 AF=0 ZF=1 SF=0 OF=0
```

CS = 0x18（64-bit コードセグメント）、RSP = 0x90000 でロングモード移行が完了していることが確認できる。`info registers cr0 cr3 cr4` で CR0 は PG + PE、CR4.PAE = 1、CR3 = 0x1000（PML4）も確認できる。

**ブレークポイントは `hbreak *_start`（ハードウェアブレーク）を使う**: gdb への接続はリセット直後（0xFFF0 実行中）に行われるため、ロード前に置いたソフトウェアブレークポイント（メモリ上の命令を INT 3 に書き換える）は、その後の INT 13h ディスク読み込みが同じアドレスのメモリを上書きして消えてしまう。ハードウェアブレークは CPU のデバッグレジスタでアドレス照合するため、ロード後の 0x8000 の `_start` で確実に止まる。

gdb の操作: `si` = 1 命令実行 / `c` = continue / `b *ADDR` / `info registers` / `x/5i $pc` / `Ctrl-D` で終了。セッション例（s01_hello）:

```gdb
(gdb) hbreak *_start
(gdb) c
Breakpoint 1, _start () at s01_hello.asm:20
20	    lea  rsi, [rel message]    ; RSI = 文字列へのポインタ (RIP 相対)
(gdb) si
_start.print_loop () at s01_hello.asm:22
22	    lodsb                      ; AL = [DS:RSI], RSI++ (DF = 0 なので正向き)
(gdb) x/5i $pc
=> 0x8007 <_start.print_loop>:	lods   al,BYTE PTR [rsi]
   0x8008 <_start.print_loop+1>:	or     al,al
   0x800a <_start.print_loop+3>:	je     0x8013 <scenario_halt>
   0x800c <_start.print_loop+5>:	call   0x8017 <uart_putc>
   0x8011 <_start.print_loop+10>:	jmp    0x8007 <_start.print_loop>
```

UART 出力はステップ実行の進行に応じて同じターミナルに表示される。ポートは `GDB_PORT`、gdb は `GDB` 変数で変更できる。デバッグ用 ELF (`$(S).elf`) は `linker-debug.ld` で `.bin` と同一のセクション配置 (`OUTPUT_FORMAT("elf64-x86-64")`) を持ち、シンボル名とソース行がそのまま使える。

### make trace / make icount / make cycles / make dump

- `make trace S=` は QEMU を `-accel tcg,one-insn-per-tb=on`（1 TB = 1 命令）で起動し、1 命令ごとの逆アセンブルとレジスタを `$(S).trace` に記録する。記録先は `-dfilter 0x8000+0x7e00` でカーネル領域（0x8000 以降）に限定し（指定がないと SeaBIOS 部分も記録され 1 秒で数十万行になる）、`scenario_halt` への到達で完了する。ログ上限（既定 32MB、`TRACE_MAX_BYTES`）・タイムアウト（`TRACE_SECS`）・QEMU 異常終了では不完全なログを残し、非ゼロ終了する。
- `make icount S=` は実行命令数を報告する。集計は `-dfilter` によりシナリオ本体（0x8000 以降）に限定し、終了ループの `cli`/`hlt` を除外する。`scenario_halt` のアドレス（RIP 行 `RIP=0000000000008000` 形式）への到達を検出し、到達前の命令数を表示する（例: s04_loops で 1824 命令）。時間切れや異常終了で未到達の場合は失敗を返す。
- `make cycles S=` は `unsupported` を表示する。QEMU TCG はサイクル精度のエミュレーションではないため実サイクル数は求められず、命令数は `make icount` で計測する。
- `make dump S=` は `ndisasm -b 64 -o 0x8000 -e 1024 $(S).bin` でシナリオ部分（0x8000 以降）を 64-bit で逆アセンブルする（`-e 1024` でブートセクタ 512 + 移行スタブ 512 バイトを読み飛ばす）。先頭 1024 バイトは 16/32/64-bit 混在のため対象外であり、観察する場合は `ndisasm -b 16 -o 0x7C00`（ブート）と `ndisasm -b 32 -o <32-bit 部の開始アドレス>`（スタブの保護モード部）を別に実行する。

## ディレクトリ構造

```text
.
├── boot.asm           # ブートセクタ (`.boot`) + ロングモード移行スタブ (`.stub`)
├── crt0.asm           # C シナリオ共通のスタートアップ（boot.asm 移行済みの環境で main を呼ぶ）
├── linker.ld          # リンカスクリプト（フラットバイナリ出力）
├── linker-debug.ld    # デバッグ用リンカスクリプト（ELF64 出力、同一配置）
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
├── s13_copybench.asm  # S13: コピー比較ベンチ（全アーキ共通課題）
├── s101_riprel.asm    # S101: RIP 相対アドレッシング（x86_64 固有）
├── s102_paging.asm    # S102: 4 段ページングと 2MB ページ（x86_64 固有）
├── s103_syscall.asm   # S103: SYSCALL / SYSRET（x86_64 固有）
└── s104_sse.asm       # S104: SSE（XMM とパック単精度演算、x86_64 固有）
```

## CPU と実行環境

- ソースは `cpu x64` + `bits 64`（boot.asm のみ `bits 16`/`bits 32` を含む）、NASM `-f elf64`、リンカは `ld.lld -m elf_x86_64`。なお NASM の CPU 指令は `cpu x64` が正しく、`cpu 64` はエラーになる（`unknown CPU type or flag '64'`）。
- 実行モードは **64-bit ロングモード、CPL=0**。ページング有効（下位 1GB を 2MB ページで identity map）、IF=0（IDT 未構築のため STI しない）。セグメントはフラット（base=0）。
- スタックは RSP=0x90000 から下方成長。`.bss` は移行スタブの 64-bit 部がリンカシンボル（`__bss_start`/`__bss_end`）を使ってゼロ初期化するため、シナリオ側の初期化は不要。
- QEMU は `qemu-system-x86_64 -machine pc -accel tcg -cpu qemu64`。CPU モデル（qemu64）と命令セット制限（NASM `cpu x64`）は別の概念である: `-cpu qemu64` は QEMU がエミュレートする CPU の型番であり、`cpu x64` はアセンブラが受け付ける命令の範囲の上限である。ソースを `cpu x64` に限定することで、教材が X86-64 基命令セット（SSE1 まで）に収まることをビルド時に保証する。
- 終了は `cli; hlt` のループ。QEMU は HLT 後も動き続けるため `timeout` で回収し、`-no-reboot -no-shutdown` で障害時の再起動を抑止する。
- 引数はレジスタ渡しとし、保存対象レジスタを関数ごとに明示する。System V AMD64 呼び出し規約に合わせ、CALL 直前の RSP を 16 の倍数、関数入口は RSP % 16 = 8 とする（S07 で学習）。

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
| S101 | `s101_riprel.asm`    | RIP 相対アドレッシング（x86_64 固有） | ★★★☆☆ |
| S102 | `s102_paging.asm`    | 4 段ページングと 2MB ページ（x86_64 固有） | ★★★★☆ |
| S103 | `s103_syscall.asm`   | SYSCALL / SYSRET（x86_64 固有） | ★★★★★ |
| S104 | `s104_sse.asm`       | SSE（XMM とパック単精度演算、x86_64 固有） | ★★★★☆ |

---

### S01: Hello World

**難易度**: ★☆☆☆☆

ロングモード到達と UART 出力の確認。`boot.asm` が INT 13h でシナリオを 0x8000 へロードし、A20/GDT/CR0.PE で保護モードに入った後、ページテーブル構築と EFER.LME → CR0.PG でロングモードへ移行し、`_start` が COM1 に `"Hello, x86_64 World!"` を出力して停止する。

| 学習項目                  | 説明                                                     |
| :---                      | :---                                                     |
| ブート → スタブ → `_start` | 0x7C00 → 0x7E00 → 0x8000 の実行フロー（16 → 32 → 64） |
| 64-bit レジスタ           | RSI/RDX/RAX を使う文字列出力                             |
| `lea rsi, [rel message]`  | RIP 相対でアドレスを取得（ロングモードの標準的な書き方） |
| `lodsb`                   | `[DS:RSI]` から 1 バイト読み込み、RSI をインクリメント   |
| `uart_putc`（16550 ポーリング） | LSR (0x3FD) bit 5 (THRE) 待ち → THR (0x3F8) に書込み |
| `cli` + `hlt`             | 割り込み禁止 → CPU 停止（タイムアウトで QEMU 終了）      |

---

### S02: レジスタと算術

**難易度**: ★☆☆☆☆

RAX〜RDI と拡張レジスタ R8-R15、64-bit 演算を体験する。64-bit 固有の学習ポイントは部分レジスタ書き込みの 3 挙動の対比と `mov r64, imm64` 形式。

| 学習項目                          | 説明                                                     |
| :---                              | :---                                                     |
| `mov`, `add`, `sub`, `inc`, `dec` | 基本算術命令（64-bit オペランド）                        |
| 部分レジスタ (AL/AX)              | AL/AX への書き込みは下位ビットだけ変更し上位は保持       |
| 部分レジスタ (EAX)                | **EAX への書き込みは上位 32 ビットをゼロクリア**（ロングモード固有。Intel SDM Vol.1 3.4.1.1「32-bit オペランド書込みは上位 32 ビットをゼロにする」） |
| `mov r64, imm64`                  | ロングモード固有の形式（32-bit では即値は 32-bit まで）  |
| R8-R15                            | ロングモードで追加された 8 本の 64-bit レジスタ（REX プレフィックスでエンコード） |
| `print_hex64` / `print_hex32`     | RAX を 16 桁 / 8 桁の 16 進で表示（ニブル単位の ASCII 変換） |

**ポイント**: 同じ RAX = 0x1234567890ABCDEF に対して `mov al, 0xFF` は上位 56 ビットを保持し（0x1234567890ABCDFF）、`mov ax, 0xBEEF` も上位 48 ビットを保持する（0x1234567890ABBEEF）が、`mov eax, 0x90ABCDEF` は RAX 全体が 0x0000000090ABCDEF になる。AL/AX は「保持」、EAX は「ゼロ拡張」という 3 つの挙動の対比が 64-bit の核心。`mov r9, 0x1122334455667788` で imm64 ロードも確認する。

---

### S03: スタック操作

**難易度**: ★★☆☆☆

スタック（LIFO）の動作を理解する。64-bit では 1 回の PUSH/POP が 8 バイト動く点が 32-bit 版との主な違い。

| 学習項目             | 説明                                                     |
| :---                 | :---                                                     |
| `push` / `pop`       | スタックへの保存・復元（RSP が ±8、64-bit 単位）         |
| RSP の 8 バイトステップ | PUSH で RSP: 0x90000 → 0x8FFF8 → 0x8FFF0              |
| LIFO                 | 最後に入れたものが最初に出る（POP は PUSH の逆順）       |
| SS/RSP 設定不要      | 移行スタブが SS=フラット、RSP=0x90000 に初期化済み       |
| レジスタ保存パターン | `push rax` → 作業 → `pop rax` で値を保護                 |

**ポイント**: PUSH は RSP を −8 して 64 ビット値を [RSP] に格納する。PUSH と POP が対になれば RSP は開始値 (0x90000) に戻る。0x90000 は 16 の倍数なので `_start` 直後の RSP は既に 16-byte アライン済みであり、System V AMD64 規約の「CALL 直前 RSP ≡ 0 (mod 16)」がスタブ初期値のままで満たされている（規約の詳細は S07）。

---

### S04: ループと条件分岐

**難易度**: ★★☆☆☆

`LOOP` 命令と `CMP` + 条件ジャンプを使った反復処理。`TEST` 命令による偶数/奇数判定も学ぶ。

| 学習項目      | 説明                                              |
| :---          | :---                                              |
| `loop`        | RCX をデクリメントし、RCX≠0 ならジャンプ          |
| ループ後の RCX | ループ終了後は 0（64 ビット全体がクリア）         |
| `cmp` + `jle` | 比較 → 条件付きジャンプ（カウントアップループ）   |
| `test` + `jz` | AND を実行せずフラグだけ更新（偶数/奇数判定）     |

**ポイント**: `LOOP` が使うカウンタはアドレスサイズに従うため、16-bit モードでは CX、32-bit モードでは ECX、**ロングモードでは RCX** になる。ECX=1 のときは RCX=0 になってジャンプしない点も同じ。32-bit 版の ECX 全体ではなく RCX 全体（16 桁）が減っていくことを `print_hex64` で確認する。

---

### S05: 文字列操作

**難易度**: ★★☆☆☆

文字列命令群と `REP` プレフィックスを学ぶ。16-bit では暗黙レジスタが SI/DI だったものが、32-bit では ESI/EDI、**64-bit では RSI/RDI** になる（命令の動作は同じ、ポインタ幅が 64-bit になっただけ）。

| 学習項目        | 説明                                            |
| :---            | :---                                            |
| `lodsb`         | `[DS:RSI]` → AL、RSI++                          |
| `stosb`         | AL → `[ES:RDI]`、RDI++                          |
| `scasb`         | AL と `[ES:RDI]` を比較、RDI++                  |
| `rep` / `repne` | RCX 回繰り返し（等しい/等しくない間）           |
| `cld` / `std`   | ディレクションフラグ（RSI/RDI の増加/減少方向） |
| `repne scasb`   | null 検索で文字列長を測定                       |
| `rep movsb`     | RCX バイトを一括コピー                          |

**ポイント**: 繰り返しカウンタが RCX に変わるため、`REPNE SCASB` の探索上限に RCX = -1 = 0xFFFFFFFFFFFFFFFF（アドレス空間全体）を指定できるのが 64-bit ならではの学習ポイント。ワーキングバッファは `.bss` に置く。移行スタブが `__bss_start`..`__bss_end` をゼロ初期化済みなので、シナリオ側のバッファ初期化は不要。

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

**ポイント**: IDT 未構築のため割り込み駆動は使えず、LSR のポーリングで入力を待つ。送信 (THRE, bit 5) と受信 (DR, bit 0) の対称性を S01 の `uart_putc` と対比する。IN/OUT 命令と DX ポート指定は 16/32-bit 版と同一で、ロングモードでも不変である。

---

### S07: サブルーチン

**難易度**: ★★★☆☆

`CALL` / `RET` による関数呼び出しに加え、**System V AMD64 呼び出し規約のスタックアラインメント**を実測しながら学ぶ。64-bit では CALL が積む戻りアドレスが 8 バイトになり、アラインメント規約が実用上の必須知識になる。

| 学習項目         | 説明                                                |
| :---             | :---                                                |
| `call` / `ret`   | 64-bit の戻りアドレス（8 バイト = RIP）をスタックに保存・復元 |
| スタックアラインメント | CALL 直前の RSP ≡ 0 (mod 16)、関数入口では RSP % 16 = 8（CALL が 8 バイトの戻りアドレスを PUSH するため） |
| アラインメントの崩れと修復 | PUSH が奇数個になると CALL 直前 RSP % 16 = 8 になる（規約違反）。`sub rsp, 8` で作り直す |
| パラメータ渡し   | System V AMD64 風にレジスタで渡す（RDI/RSI → 戻り値 RAX） |
| callee-saved     | RBX/RBP/R12-R15 は使う関数が保存する責任を持つ。caller-saved（RAX/RCX/RDX/RSI/RDI/R8-R11）は呼び出し側が退避 |
| ネスト呼び出し   | サブルーチンからさらに `call` で別の関数を呼ぶ      |

**ポイント**: RSP の実測 4 行 — `RSP at _start: 0x0000000000090000`（≡0）、`show_entry_rsp entry: 0x000000000008FFF8`（入口 ≡8）、`PUSH 1x then CALL: 0x000000000008FFF0`（≡8 で規約違反）、`PUSH + sub rsp,8: 0x000000000008FFE8`（≡0 に修復）。アラインメントは PUSH 命令のハードウェア要件ではなく呼び出し規約上の約束事だが、守らないと `movaps` のような 16 バイトアラインを要求する SSE 命令がスタック上のデータを触った瞬間に #GP で落ちる（S104 と接続）。red zone（RSP 直下 128 バイト）は本教材では使わない。本教材のルーチンは RBX を壊さないため、RBX が一連の呼び出しをまたいで無傷であることも観察できる。

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
| `movzx`                | 16-bit → 32-bit のゼロ拡張。64-bit モードでは EAX 書込みで上位 32 ビットも 0 になるため RAX 全体が 16-bit 値になる |
| カウンタの変動         | 1.193182 MHz / 65536 ≈ 18.2 Hz でカウントダウン中、値は実行のたびに変わる |

**ポイント**: IN/OUT は CPL ≤ IOPL のとき許される特権命令だが、本環境はロングモードで CPL=0（最高特権）なので IOPL の値に関係なく実行できる。PORT I/O の方法（DX 経由）は 16/32-bit 版とまったく同じで、モードが変わっても変わらない部分であることを確認する。

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

**ポイント**: 同じビットパターン `0xFFFFFFFFFFFFFFFF` と `1` の `cmp` で、`jl` は「-1 < 1」で成立し、`ja` は「2^64-1 = 18446744073709551615 > 1」で成立する。フラグは同じでも解釈する条件コードが異なる。64-bit では bit 63 が符号ビットになるため、32-bit 版の `0xFFFFFFFF` 対比が 64-bit 幅に拡大しただけの構図。なお `print_str` 内の `or` がフラグを壊すため、`cmp` は分岐の直前に置く。

---

### S10: ビット演算

**難易度**: ★★★★☆

AND / OR / XOR / SHL / SHR / ROR を 64 ビット幅で使い、ビット単位の操作を理解する。64 桁の 2 進表示サブルーチンも実装する。

| 学習項目             | 説明                                                  |
| :---                 | :---                                                  |
| `and`                | マスク抽出（`0x5A5A5A5A5A5A5A5A AND 0x0F0F0F0F0F0F0F0F`） |
| `or` / `xor`         | ビット結合 / トグル・レジスタのゼロ化                 |
| `shl` / `shr`        | 64 ビットの論理シフト（bit 63 の繰り出し・繰り入り）  |
| `ror`                | 64 ビットの回転（はみ出したビットは反対側へ戻る）     |
| `print_bin64`        | 64 桁の 2 進表示                                      |

**ポイント**: **AND/OR/XOR には imm64 形式がない**（即値は imm32 の符号拡張まで）。64 ビットのマスク定数は `mov r64, imm64` でレジスタに置いてから `and rax, rcx` のように使う。`shl 0x4000000000000000, 1` は bit 63 に繰り上がって `0x8000000000000000` になり、`shr` 1 で bit 63 が落ちて `0x4000000000000000` に戻る — bit 63 を跨ぐシフトが 64-bit ならではの観察点。`ror rax, 8` は `0x123456789ABCDEF0` → `0xF0123456789ABCDE` で、下位 8 ビットが bit 63..56 へ回り込む（32-bit 版では bit 31..24 だった）。

---

### S11: メモリとブロック操作

**難易度**: ★★★★☆

メモリへのブロック単位の書き込み・コピーと、64-bit のアドレッシングモード（base + index × scale）を学ぶ。

| 学習項目             | 説明                                                  |
| :---                 | :---                                                  |
| `rep stosb`          | メモリブロックのフィル（`.` で 20 バイト埋める）      |
| `rep movsb`          | メモリブロックのコピー（`"Hello"` → バッファ）        |
| `[即値オフセット]`   | `mov byte [rel display+3], 'L'` でインデックス指定    |
| `[RBX+RSI*1]`        | ベース + インデックスアドレッシング                   |
| `[RBX+RSI*8]`        | スケール 8 = **qword 配列** `table[i]` が 1 命令（64-bit の学習ポイント） |
| `movzx`              | バイト読み込み後の上位ビットを 0 埋め                 |

**ポイント**: スケールは 1/2/4/8 が使え、64-bit では `[RBX+RSI*8]` で qword 配列 `table[i]` のアドレス計算（base + i × 8）を 1 命令で済ませられる。qword（8 バイト）の読み込みは MOVZX 不要 — 転送幅 = レジスタ幅ならそのままロードできる（転送幅 < レジスタ幅のバイト読み込みでは MOVZX が依然必要）。バッファは `.bss`（スタブがゼロ初期化済み）に置き、スタック (RSP=0x90000) とは離れた配置になる。

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
| `hello`  | `"Hello, x86_64!"` と表示             |
| `help`   | コマンド一覧を表示                    |
| `quit`   | シェル終了 → `"Bye!"` を表示          |

**空行入力**: 何も表示せずプロンプトに戻る。不明なコマンドは `Unknown command` を表示する。

---

### S13: コピー比較ベンチ（全アーキ共通課題）

**難易度**: ★★★☆☆

全アーキテクチャ共通の比較課題。100 バイトのメモリコピーを `REP MOVSB` で行い、宛先 100 バイトの 8 ビットずつの総和（チェックサム）を 16 進 4 桁で出力する。

| 学習項目                  | 説明                                                         |
| :---                      | :---                                                         |
| `rep movsb`               | 1 命令で RCX バイトを一括コピー（RSI/RDI/RCX の 64-bit ブロック転送） |
| チェックサム              | 0+1+...+99 = 4950 = 0x1356                                   |
| 正誤判定                  | 0x1356 と比較し `COPY OK CHECKSUM=1356` / `COPY FAIL CHECKSUM=xxxx` |

**実行出力**: `COPY OK CHECKSUM=1356`（1 行のみ）

**ポイント**: 32-bit 版 (x86_32) との対比でレジスタ幅（ESI/EDI/ECX → RSI/RDI/RCX）だけが変わることが分かる。QEMU TCG はサイクル精度ではないため実サイクルは測れない。REP MOVSB の手計算サイクル内訳（8086: 9+17n = 17.09 クロック/バイト）は [`../../../docs/copybench.md`](../../../docs/copybench.md) と x86_16 版に記載しており、x86_64 のブロック転送タイミングは比較表の対象外である（386 と同様）。

---

### S101: RIP 相対アドレッシング（x86_64 固有）

**難易度**: ★★★☆☆

ロングモードの標準的なデータ参照方式である RIP 相対アドレッシング（NASM 記法 `[rel]`）を実演する。絶対即値（`mov rax, imm64`）との対比で「位置独立性（PIC）」の本質を学ぶ。

| 学習項目             | 説明                                                           |
| :---                 | :---                                                           |
| `lea rax, [rel label]` | RIP 相対でアドレスを取得。基準は「命令の次のアドレス」        |
| `mov rax, [rel value64]` | RIP 相対でデータを読む（rodata 上の 64-bit 値）            |
| 2 サイトの lea       | 同じラベルを 2 か所から lea しても結果（リニアアドレス）は一致 = 位置独立 |
| disp32 の直接読み出し | `lea r64, [rel label]` は REX + 8D + ModRM + disp32 の 7 バイト。命令先頭 +3 バイトから disp32 を読むと「RIP との距離」がそのまま見える |
| 絶対即値との対比     | `mov rax, imm64` はアドレスを機械語に埋め込むため位置依存。RIP 相対は disp32 が自動補正されるため位置独立 |

**実行出力**（実測）:

```text
lea  [rel msg]    = 0x00000000000081C2
lea2 [rel msg]    = 0x00000000000081C2
mov  [rel value]  = 0x1122334455667788
res diff          = 0x0000000000000000
disp diff         = 0x000000000000000A
RIP-relative done!
```

**ポイント**: 2 つの lea の間には `lea` 7 バイト + `nop` 3 バイトの距離があるため、disp32 の差 = **0xA**（10 バイト）= サイト間距離そのもの。それでも lea 結果（`res diff`）は 0 に一致する — 「命令の場所が違えば disp32 が変わり、計算結果は一致する」が RIP 相対の定義。

---

### S102: 4 段ページングと 2MB ページ（x86_64 固有）

**難易度**: ★★★★☆

`boot.asm` が構築した実ページテーブルをダンプし、CR3 を起点に手計算のウォークで VA → PA 変換を確認する。ロングモードのアドレス変換は PML4 → PDPT → PD → PT の 4 段（各テーブル 512 エントリ × 8 バイト）。

| 学習項目             | 説明                                                           |
| :---                 | :---                                                           |
| CR3                  | 第 4 段（PML4）の物理アドレス（bits 51:12）。実測 0x1000       |
| 実ウォーク           | CR3 → PML4[0] (0x2003) → PDPT@0x2000 → PDPT[0] (0x3003) → PD@0x3000 → PD[i] |
| 2MB ページ (PS=1)    | PD エントリがページ物理アドレス (bits 51:21) を直接持ち、**PT 層は参照しない**。4KB ページ（PML4 → PDPT → PD → PT の 4 段参照）との違い |
| フラグビット         | P (bit 0) / RW (bit 1) / US (bit 2) / PS (bit 7)。実測 PD[i] = (i << 21) \| 0x083 |
| A/D ビット (bit 5/6) | Accessed/Dirty は **CPU が変換に使ったときに自動で立てる**ため、構築値を表示する際はマスクしてから出力する（PD[1] は未アクセスのため生値のまま） |
| 手計算ウォーク       | VA 0x004123456: PD index = bits 29:21 = 32 → PD[32] → PA = 0x04000000 + 0x123456 = 0x04123456（identity map で VA == PA） |

**実行出力**（実測）:

```text
CR3          = 0x0000000000001000
PML4[0]      = 0x0000000000002003 (P=1 RW=1 US=0 -> PDPT@0x2000)
PDPT[0]      = 0x0000000000003003 (P=1 RW=1 US=0 -> PD@0x3000)
PD[0]        = 0x0000000000000083 (P=1 RW=1 US=0 PS=1 2MB@0x000000)
PD[1]        = 0x0000000000200083 (P=1 RW=1 US=0 PS=1 2MB@0x200000)
walk 0x004123456 -> 0x004123456 (identity)
Paging done!
```

**ポイント**: 2MB ページは PML4 → PDPT → PD の 3 段で解決し PT を参照しない（4KB ページは PML4 → PDPT → PD → PT の 4 段）。A/D は表示時にマスクする実務上の配慮も学ぶ。データ参照は `[rel]` (RIP 相対) かレジスタ経由が本教材の規約。絶対アドレス自体はロングモードでもエンコード可能だが（SIB を用いた disp32 絶対。s103 では `default abs` の下で `or dword [0x1000], 0x04` を使用）、位置独立コードの観点から s102 では `mov rsi, 0x1000` → `mov rax, [rsi]` のレジスタ経由を使う。

---

### S103: SYSCALL / SYSRET（x86_64 固有）

**難易度**: ★★★★★

CPL=3 のユーザコードから `SYSCALL` でカーネルのハンドラに入り、`SYSRET` で戻る高速な特権切替を実装する。MSR 設定、GDT 拡張、ページ権限、IRETQ による降格まで含む本教材最大のシナリオ。

| 学習項目             | 説明                                                           |
| :---                 | :---                                                           |
| 機能確認             | CPUID leaf 0x80000001 EDX bit 11（SYSCALL 拡張、qemu64 では有効） |
| EFER.SCE (bit 0)     | MSR 0xC0000080 に立てて SYSCALL/SYSRET 命令を有効化            |
| STAR                 | `0x0020000800000000`（EDX=0x00200008 / EAX=0 を wrmsr）。STAR[47:32]=0x0008（カーネル CS）、STAR[63:48]=0x0020（ユーザ CS ベース） |
| セレクタ導出         | SYSCALL: CS = STAR[47:32] = 0x08 / SS = STAR[47:32]+8 = 0x10。SYSRET: CS = STAR[63:48]+16\|3 = 0x33 / SS = STAR[63:48]+8\|3 = 0x2B |
| LSTAR / FMASK        | LSTAR = ハンドラの線形アドレス、FMASK = 0                      |
| GDT 拡張             | DPL=3 のユーザコード (0x20/0x30) とユーザデータ (0x28) を追記して lgdt |
| U/S=1                | ページ階層全段（PML4/PDPT/PD）と 2MB リーフに bit 2 を設定し CR3 再書込（TLB 全消去） |
| IRETQ による降格     | SS/RSP/RFLAGS/CS/RIP を一括復帰して CPL 0 → 3（専用ユーザスタック 0x200000） |
| SYSCALL の挙動       | **RSP は自動切替されない**（入口でユーザ RSP を保存しカーネルスタック 0x90000 へ切替）。**RCX = 戻り RIP、R11 = RFLAGS に破壊される** |
| SYSRET の復帰点      | RIP ← RCX。NASM に `sysretq` ニーモニックはないため `o64 sysret`（48 0F 07）を使う |

**CPL 遷移の実測**（gdb、QEMU TCG）: カーネル (CS=0x18) で IRETQ を実行してユーザコードへ降格（CS=0x23 / SS=0x2B）、ユーザコードの SYSCALL でカーネルへ入る（CS=0x08 / SS=0x10 — STAR[47:32] 由来）、ハンドラの `o64 sysret` でユーザへ復帰（CS=0x33 / SS=0x2B — STAR[63:48]+16\|3 と +8\|3）。SYSRET 復帰の CS が IRETQ 降格の CS (0x23) と違う 0x33 になるのは、SYSRET が STAR[63:48]+16 を使い、GDT[0x20] ではなく GDT[0x30] の記述子を指すためである。

**実行出力**（実測）:

```text
CPUID syscall = yes
EFER.SCE on
STAR = 0x0020000800000000
enter CPL=3
syscall count = 5, last value = 5
```

**ポイント**: ユーザコードは RAX=1..5 を渡して 5 回 syscall し、最後に RAX=0xFF（終了マーカ）を渡すとハンドラは SYSRET せずカーネル側で要約を表示して停止する。IDT 未構築のため IF=0 のまま（ユーザモードでも割り込みなし）、CPL=3 からは UART I/O を行わない（出力はすべてカーネル側）。なお簡略化として U/S=1 は PML4[0]/PDPT[0]/PD[0]/PD[1] のすべてに立てており、カーネル (.text) やページテーブルを含む先頭 2MB も CPL=3 からアクセス可能 — CPL 遷移の実演が目的で、権限分離を実現する例ではない（実際の OS はユーザ領域のページだけ U/S=1 にする）。

---

### S104: SSE（XMM とパック単精度演算、x86_64 固有）

**難易度**: ★★★★☆

SSE を有効化してから XMM レジスタのパック単精度 float 演算を 1 命令で 4 レーン同時に実行する。AVX を使わず SSE1 のみで完結する。

| 学習項目             | 説明                                                           |
| :---                 | :---                                                           |
| 機能確認             | CPUID leaf 1 EDX bit 25（SSE）。AVX（ECX bit 28）は不要        |
| CR0.EM (bit 2) / TS (bit 3) クリア | EM=1 だと SSE 命令は #UD、TS=1 だと #NM になるため     |
| CR4.OSFXSR (bit 9) / OSXMMEXCPT (bit 10) | それぞれ「FXSAVE で XMM 状態も保存」「#XF ハンドラを持つ」の OS 宣言。0 のままだと SSE 命令は #UD。実測 CR4 = 0x620（boot 直後の PAE (bit 5) + 0x600） |
| `movaps`             | メモリオペランドは **16 バイト境界必須**。外れると #GP(0)（IDT 未構築のため三重フォルトで停止）。`.rodata` は `align 16`、`.bss` は `alignb 16` で保証 |
| `addps` / `subps`    | 4 レーンのパック単精度加算/減算。a={1,2,3,4}+b={4,4,4,4} → "5678"、c={8,7,6,5}-d={1,2,3,4} → "7531" |
| `cvttss2si`          | SSE1 の float → 整数変換（0 へ切り捨て）でレーン結果を表示     |
| レーン順             | メモリの dd 並びの先頭 = レーン 0 (bits 31:0、リトルエンディアン) |

**実行出力**（実測）:

```text
CPUID SSE      = 1
CR4            = 0x0000000000000620
addps lanes    = 5678
subps lanes    = 7531
XMM0-15        = 16 regs (SSE1 only, AVX not needed)
SSE done!
```

**ポイント**: レーン結果の表示では、各レーンが IEEE754 単精度のビットパターン（例: 5.0 = 0x40A00000、リトルエンディアンで 00 00 A0 40）のため、格納バイトをそのまま読んでもどの 1 バイトも桁数字に一致しない。CVTTSS2SI で整数化してから `'0'` を加えて表示する（生バイト + '0' は不可）。64-bit モードでは XMM0-XMM15 の 16 本が使える。

---

### C01/C02: C → アセンブリ (clang -S)

**難易度**: ★☆☆☆☆

リポジトリ root の `common/c/` にある C ソースを `clang -g -O0 -S`（x86-64 向け）でアセンブリに変換し、crt0.asm と一緒にアセンブル・リンクして qemu + gdb で観察する。C01 は `main` だけの最小構成、C02 は関数呼び出し `add()` とローカル変数を含む。生成された `build/x86_64/c01.s` は学習対象なのでビルド後に残り、`make clean` で削除される。

| 学習項目                     | 説明                                                            |
| :---                         | :---                                                            |
| `clang --target=x86_64-pc-none-elf -mno-red-zone -g -O0 -S` | 最適化なし・DWARF 付きで x86-64 用アセンブリを生成 |
| `pushq %rbp` / `movq %rsp, %rbp` / `popq %rbp` | -O0 の関数プロローグ/エピローグ（フレームポインタ RBP） |
| レジスタ渡し ABI             | System V AMD64 呼び出し規約: 引数は RDI/RSI、戻り値は RAX      |
| crt0.asm                     | boot.asm のスタブがモード移行・RSP=0x90000・.bss クリアまで済ませるため、`call main` + hlt だけ |
| DWARF デバッグ情報           | `hbreak *_start` 到達後は `break main` / `list` / `step` で C ソース行単位のステップ実行 |

**使い方**:

```bash
make run S=c01        # QEMU で実行（UART 出力なし、HLT 到達で timeout 回収）
make dump S=c01       # crt0 + clang 生成コードの逆アセンブル (0x8000〜)
make debug S=c01      # qemu + gdb でステップ実行（C ソース行が見える）
make clean            # 生成物とともに build/x86_64/ を削除
```

**ポイント**: ここはレジスタ渡し ABI（引数 RDI/RSI、戻り値 RAX）で、RISC-V（a0/a1、戻り値 a0）と同じ方式。同じ `common/c/c02.c` から生成した `build/m68k/c02.s`・`build/x86_32/c02.s`（引数スタック渡し）が `build/x86_64/c02.s` と共存するので見比べると、ABI の違いが同じ C ソースから読み取れる。crt0 は UART 出力を持たず main 復帰後に `cli/hlt` で停止するため、C シナリオは runall に含めない（`trace`/`icount` は他シナリオと同じく `scenario_halt` シンボルで完走判定する）。

**学習カード（予測 → 観察 → 改造 → 考察）**:

- **STEP 1 予測**: `build/x86_64/c01.s` を開き、`main` のプロローグ（`pushq %rbp` / `movq %rsp, %rbp`）、`movl $0, -4(%rbp)`、エピローグ（`popq %rbp` / `retq`）がそれぞれ何をするか先に予測する。
- **STEP 2 観察**: `make debug S=c01` で `hbreak *_start` 到達後に `break main` → `step` → main 復帰後 RAX=0・RSP が 0x90000 側に戻ることを確認する。`make debug S=c02` では `break add` の 1 回目 `a=1 b=1`、2 回目 `a=20 b=20`、`break scenario_halt` で RAX=0（c-42）を見る。
- **STEP 3 改造**: `common/c/c01.c` にグローバル変数や配列を追加して再ビルドし、boot.asm スタブの .bss クリア（`rep stosb`）が実行される様子を `make debug` で観察する。
- **STEP 4 考察**: `make build-c S=c01 CFLAGS='--target=x86_64-pc-none-elf -mno-red-zone -g -O2 -fno-asynchronous-unwind-tables'` で最適化を変えてビルドし、`make dump S=c01` / `make icount S=c01` で命令数を -O0 と比べる。この clang は -O2 でもフレームポインタ（`pushq %rbp`/`popq %rbp`）を保持するため、`-fomit-frame-pointer` を追加すると `xorl %eax, %eax` + `retq` だけになる（RISC-V 版は -g 付きでもフレームが消える、の対比）。

---

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — x86-64 命令セットリファレンス（末尾にロングモード移行セクションあり。boot.asm の移行手順とページング構造の要点を解説）
- [`../../../docs/x86_64_qemu_plan.md`](../../../docs/x86_64_qemu_plan.md) — 本ディレクトリの整備計画（フェーズと受入条件）
- [`../../../docs/copybench.md`](../../../docs/copybench.md) — 共通課題 s13（100 バイトコピー）の全アーキ比較
- [`../../../README.md`](../../../README.md) — リポジトリ全体のガイド（デバッグガイド・シナリオ規約）
- [`../darwin/README.md`](../darwin/README.md) — macOS ネイティブ版（Mach-O とホスト ABI）
- [`../../x86_32/qemu/README.md`](../../x86_32/qemu/README.md) — 32-bit 保護モード版（本教材の直接の対照。16 → 32 の移行を学ぶ）
- [`../../x86_16/qemu/README.md`](../../x86_16/qemu/README.md) — 16-bit リアルモード版（構成のテンプレート）

## ハードウェア情報

### QEMU 起動構成

| 項目               | 値                                                              |
| :---               | :---                                                            |
| QEMU バイナリ      | `qemu-system-x86_64`                                            |
| マシン / CPU       | `-machine pc -accel tcg -cpu qemu64`                            |
| trace / icount 用  | `-accel tcg,one-insn-per-tb=on` + `-dfilter 0x8000+0x7e00`（1 TB = 1 命令、カーネル領域のみ記録） |
| 障害時動作         | `-no-reboot -no-shutdown`（トリプルフォルトで QEMU 終了）       |
| フロッピー         | 2880 セクタ（1.44MB）、`dd` で `.bin` を先頭に書き込み          |
| 起動ファームウェア | SeaBIOS（フロッピーからブートセクタを 0000:7C00 へロード）      |
| 終了方法           | `cli; hlt` の停止ループ後、`timeout`（既定 1 秒）で QEMU を回収。異常停止（トリプルフォルト等）でも timeout までは終了コード 124（正常扱い）になるため、成否の受入は `make test` で行う |
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

**送信手順**: LSR (0x3FD) の bit 5 (THRE) をポーリングし、1 になったら THR (0x3F8) に文字を書き込む（`in al, dx` → `test al, 0x20` → `jz` → `out dx, al`）。ポート番号は DX レジスタ経由（`mov dx, 0x3FD`）。IN/OUT 命令と DX ポート指定は 16/32-bit 版と同一（ロングモードでも不変）。

**受信手順**: LSR (0x3FD) の bit 0 (DR) をポーリングし、1 になったら RBR (0x3F8) から 1 バイト読み込む（`in al, dx` → `test al, 0x01` → `jz` → `in al, dx`）。

### Intel 8254 PIT (S08 で使用)

| I/O ポート | 用途                            |
| :---       | :---                            |
| `0x40`     | カウンタ 0（16-bit 値）         |
| `0x43`     | 制御レジスタ（`0x00` でラッチ） |

カウンタ 0 の入力クロックは 1.193182 MHz。BIOS が分周比 65536 で初期化するため約 18.2 Hz（周期約 55 ms）でカウントダウンし、ラッチした値は実行のたびに変わる。特権命令の IN/OUT は通常 CPL ≤ IOPL が必要だが、本環境は CPL=0 なのでポートアクセスに制限がない。

### アドレスマップ

| アドレス        | 用途                                                     |
| :---            | :---                                                     |
| `0x1000-0x3FFF` | ページテーブル（PML4 @ 0x1000 / PDPT @ 0x2000 / PD @ 0x3000、各 4KB） |
| `0x7C00-0x7DFF` | ブートセクタ（署名 0xAA55 は 0x7DFE）                    |
| `0x7E00-0x7FFF` | ロングモード移行スタブ（最大 512 バイト）                |
| `0x8000-0xFDFF` | シナリオのロード領域（`.text` / `.rodata` / `.data`）    |
| `0x8E000`       | `.bss` 上限（`linker.ld` の ASSERT でスタック予約と非重複を検査） |
| `0x90000`       | スタックトップ（下方成長）                               |
| `0xFE00`        | ロードイメージ終端の上限（0xFE00 - 0x7C00 = 33280 バイト制限に対応） |

ロングモード移行に使う初期ページングは下位 1GB を 512 個の 2MB ページで identity map する（PML4[0] → PDPT[0] → PD[i] = i × 2MB、P \| RW \| PS = 0x083）。ロングモードの 2MB ページは PML4 → PDPT → PD で解決し PT は参照しない。`.bss` は移行スタブの 64-bit 部が `__bss_start`..`__bss_end` を `rep stosb` でゼロ初期化する。リンカの ASSERT がブートセクタ 512 バイト、スタブ 512 バイト、イメージ上限、`.bss` とスタック予約領域の非重複をビルド時に検査する。

## I/O ルーチン

本教材は文字入出力に 16550 UART（COM1, `0x3F8`）の I/O ポートを直接操作する方針（「ハードウェア情報」の [16550 UART (COM1)](#16550-uart-com1) を参照）。

**BIOS 割り込み (`INT` 命令) の使用範囲**: ブート直後の **16-bit リアルモード区間のみ**。`boot.asm` の INT 13h AH=02h（ディスク読み込み、AH=00h はエラー時のリセット）だけである。ロングモード移行後は IDT が無いため `INT` 命令も使えず、出力はすべて UART の直接ポーリングで行う。x86_16 版のシナリオは BIOS INT 呼び出し（INT 13h ディスク読み込み等）をシナリオ自身が使う場合があるが、本アーキのシナリオ（64-bit ロングモード）は一切 BIOS を使わない。

**定義元**: QEMU が読み込む SeaBIOS ROM。

**uart_putc / uart_getc の実装位置**:

| 場所                    | 名前                     | ビット幅 | 使われる場面                     |
| :---                    | :---                     | :---     | :---                             |
| `boot.asm` (`.boot`)    | `uart_putc16`            | 16-bit   | ディスク読み込み失敗時の通知     |
| 各シナリオ `.asm`       | `uart_putc` / `uart_getc` | 64-bit  | シナリオ本体の出力・入力         |

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

1. `boot.asm` のコメントを読み、ブート → スタブ（16 → 32 → 64）→ `_start` の流れを追う
2. `make dump S=s01_hello` で 0x8000 以降の 64-bit コードを逆アセンブルし、ソースと突き合わせる（ブート部分は `ndisasm -b 16 -o 0x7C00`、スタブ部分は `ndisasm -b 32 -o <32-bit 部の開始アドレス>` で別途観察する）
3. `make debug S=s01_hello` で `_start` に止め、CS = 0x18（64-bit コード）、CR0.PG + PE、CR4.PAE、CR3 = 0x1000、RSP = 0x90000 を `info registers cr0 cr3 cr4` で確認する
4. S03 で RSP の 8 バイトステップを観察し、16-bit 版（SP の 2 バイトステップ）と 32-bit 版（ESP の 4 バイトステップ）と対比する
5. メッセージやテスト値を書き換えて `make run S=...` と `make test` で確認する
6. リアルモードの基礎は [`../../x86_16/qemu/README.md`](../../x86_16/qemu/README.md) から、保護モード移行は [`../../x86_32/qemu/README.md`](../../x86_32/qemu/README.md) から、ホスト ABI（System V AMD64 の実践）は [`../darwin/README.md`](../darwin/README.md) から入る。S104 を足がかりに AVX（YMM/ZMM、CPUID leaf 1 ECX bit 28）への拡張も自然な次の一歩である

# x86_64 QEMU 版整備計画

作成日: 2026-11-15 / 状態: 計画 (未実装)

## 実装順序

[x86_32 QEMU 版整備計画](x86_32_qemu_plan.md) を先に完了し、32-bit 保護モードまでのブート・配置・UART・検証の実測結果を引き継ぐ。以下はその後に実装する計画。

## 目的と方針

arch/x86_16/qemu と同じ構成・カリキュラム・統一デバッグインターフェースで、`arch/x86_64/qemu/` に 64-bit ロングモード版のベアメタル学習環境を作る。

- **シナリオ**: s01-s13 の共通 13 テーマ + x86_64 固有の s101+
- **出力・入力**: 16550 UART COM1 (`0x3F8`) を `OUT`/`IN` の I/O ポート命令で (x86_16 と同一。ロングモードでも I/O 命令は不変)
- **終了**: `cli; hlt; jmp` スピン + `timeout` で QEMU を刈り取る (x86_16 と同一)
- **ツールチェーン**: nasm (`-f elf64`) + ld.lld (`-m elf_x86_64`)。x86_16 と同じく ld.lld を使う (Apple Silicon のシステム ld は ELF を出せない)
- **テキスト**: すべて日本語、README セクション順・テーブル表記 (`| :--- |`) はリポジトリ規約どおり

## 既存資産との関係

| 資産 | 状況 | 本計画での扱い |
| :--- | :--- | :--- |
| `arch/x86_64/CPU.md` | 汎用レジスタ〜アドレッシングモードまで標準セクション構成で存在 | そのまま流用し、「ロングモード移行」セクションを追加 (arch/x86_16/CPU.md の「プロテクトモード関連」に相当) |
| `arch/x86_64/darwin/` | macOS ネイティブ hello のみ | 変更しない |
| `arch/x86_16/qemu/` | ブートセクタ + SINGLE/MULTI 2 方式のビルド、.gdbinit、test_scenarios.py | 構成のテンプレート。s104_protected (16→32) の延長として 16→32→64 を実装 |
| ルート README / AGENTS.md / Makefile | アーキテーブル・CORE_DIRS に arch/x86_64/qemu が未登録 | Phase 3 で追加 |

## ブート方式の設計

x86_16 の「SeaBIOS が 0x7C00 へブートセクタをロード」を起点とし、共有ブートスタブで 64-bit へ移行してからシナリオコードへジャンプする。GRUB / multiboot / UEFI は使わない (ツール依存を増やさず、モード遷移自体を教材化する)。

### ブートチェーン (共有 `boot.asm`)

1. **ブートセクタ (16-bit、0x7C00)**: CS を既知の値へ正規化し、DS/ES/SS/SP と DF を初期化。BIOS の DL を保存し、sector 2 以降の固定 64 セクタを ES:BX = 0000:7E00 へ 1 セクタずつロードする。CHS を更新し、CF エラー時はリセット・有限回再試行後に UART へ失敗を表示して停止する。
2. **移行スタブ (0x7E00)**: A20 を port 0x92 で有効化（リセットビットを立てない）。`cli`、`lgdt`、CR0.PE 設定、**32-bit code セレクタへの far jump** で保護モードへ入る。GDT は null / 32-bit code (D=1,L=0、0x08) / data (0x10) / 64-bit code (D=0,L=1、0x18) を持つ。
3. **32-bit**: DS/ES/SS と ESP を設定し、PML4@0x1000 / PDPT@0x2000 / PD@0x3000 の全 12KB をゼロ初期化。上位 32 ビットも含む 64 ビットエントリを書き、先頭 1GB を 512 個の 2MB ページで identity map する。初期マッピングは supervisor / writable。
4. **64-bit 移行**: CR0.PG=0 の状態で CR4.PAE、CR3、EFER.LME を設定し、CR0.PG を有効化。0x18 への far jump で 64-bit コードへ入る。
5. **64-bit**: DS/ES/SS、RSP=0x90000、DF=0 を設定。リンカが定義する `.bss` 範囲をゼロ初期化し、0x8000 のシナリオ `_start` へジャンプする。初期状態は CPL=0、IF=0。IDT 未設定のため割り込みを有効化しない。

### メモリマップ

| アドレス | 用途 |
| :--- | :--- |
| `0x1000–0x3FFF` | ページテーブル（12KB） |
| `0x7C00–0x7DFF` | ブートセクタ、末尾に 0x55AA |
| `0x7E00–0x7FFF` | ロードされる移行スタブ（最大 512B） |
| `0x8000–0xFDFF` | シナリオのコード・データ（ロード領域の残り） |
| `0x90000` | スタックトップ（下向きに成長） |

スタブとカーネルの合計を 64 セクタ以内に制限する。`.bss` はディスクに格納せず、ロード領域とは別にメモリ終端を検査してスタック用予約領域と重ならないようにする。

### シナリオファイルの純度

各シナリオ `.asm` は `bits 64` の `_start` だけを書く。ブートスタブは `boot.asm` として別オブジェクト化し、リンクで結合する (x86_16 の SINGLE 方式の踏襲。s104 の「1 ファイルに全モード混在」とは変え、教育対象を 64-bit コードに集中させる)。UART の `uart_putc`/`uart_getc` サブルーチンは x86_16 慣例どおり各シナリオにインラインで持たせる。

## ビルド方式

arch/x86_16/qemu の SINGLE 方式を 64-bit に置き換えたもの:

```bash
nasm -f elf64 -l boot.lst -o boot.o boot.asm
nasm -f elf64 -l $(S).lst -o $(S).o $(S).asm
ld.lld -m elf_x86_64 -T linker.ld -o $(S).bin boot.o $(S).o     # OUTPUT_FORMAT("binary")
dd if=/dev/zero of=$(S).img bs=512 count=2880
dd if=$(S).bin of=$(S).img conv=notrunc
```

- `linker.ld`: `OUTPUT_FORMAT("binary")`。`. = 0x7C00` に `.boot` (boot.o)、`. = 0x7E00` に `.transition`、`. = 0x8000` に `.kernel` (シナリオ)。リンカ ASSERT でブート署名を除く 510B、移行スタブ 512B、ロード領域上限を検査する
- `linker-debug.ld`: 同一配置で `OUTPUT_FORMAT("elf64-x86-64")`。`make debug` 用の `$(S).elf` 生成 (x86_16 の 2 スクリプト方式と同一)
- ロードセクタ数は固定 64 セクタ（移行スタブを含む 32KB）。Makefile は全 bin サイズが 512 + 32768 バイト以下であることを検査し、残りをゼロ埋めした 1.44MB イメージを作る
- INT 0x13 はトラック境界 (18 sectors/track) をまたげないため、セクタ単位ループでロード (18 sectors/track、2 heads の CHS を明示的に更新し、ES:BX の 64KB 境界を越えない配置に固定)

## シナリオ一覧

### 共通 s01-s13 (難易度は他アーキと同じ ★ 基準)

| # | テーマ | 64-bit ならではの要点 |
| :--- | :--- | :--- |
| s01_hello | Hello World | ブートチェーンの通電確認、`OUT` による UART 出力 |
| s02_registers | レジスタ | RAX/R8-R15、部分レジスタ (AL/AX/EAX)、`mov r64, imm64` |
| s03_stack | スタック | 64-bit push/pop、**16-byte スタックアラインメント** |
| s04_loops | ループ | `loop` (RCX)、CMP + 条件ジャンプ |
| s05_strings | 文字列 | LODSB/STOSB の RSI/RDI、`rep` 接頭辞 |
| s06_serial_in | シリアル入力 | LSR bit 0 (DR) ポーリング、echo、Enter で終了 |
| s07_subroutines | サブルーチン | call/ret、レジスタ渡し、呼び出し規約とアラインメント |
| s08_hardware | ハードウェア | Intel 8254 PIT (`0x40-0x43`) — x86_16 と同一デバイス |
| s09_branching | 分岐 | 符号付き/符号なし条件分岐の対比 |
| s10_bitwise | ビット演算 | 64-bit シフト、`ror rax, imm` |
| s11_memory | メモリ | `rep movsb`、`[base+index]`、アドレス計算の 64-bit 化 |
| s12_minishell | ミニシェル | 対話入力、コマンドディスパッチ |
| s13_copybench | 共通ベンチ | 100 バイトコピー checksum `0x1356` (`doc/copybench.md` 仕様) |

s06/s12 の `runall`/`trace` 入力は x86_16 と同じ `printf 'q\n'` / `printf 'quit\n'` パイプ。

### アーキ固有 s101+ (x86_64 独自の番号空間)

| # | テーマ | 内容 |
| :--- | :--- | :--- |
| s101_riprel | RIP 相対アドレッシング | `lea rax, [rel msg]`、`mov rax, [rel value]`、位置独立コードの基礎。64-bit モードでも絶対参照は可能だが、RIP 相対参照は位置独立性を得られる。NASM では `[rel msg]` を使う（`[rip+X]` をソース構文として使わない） |
| s102_paging | 4 段形式と 2MB ページ | CR3 が指す PML4 → PDPT → PD の実ウォーク。boot が構築した実テーブルをダンプし、2MB ページの構造 (P/RW/PS ビット) を観察 |
| s103_syscall | SYSCALL/SYSRET | EFER.SCE 有効化 (`wrmsr`)、STAR/LSTAR/FMASK 設定。ユーザコード・データ用 GDT、U/S=1 の全階層とリーフ、専用ユーザスタックを追加し IRETQ で CPL=3 へ移行する。SYSCALL は RSP を切り替えないため、入口でユーザ RSP を保存してカーネルスタックへ切替える。RCX/R11 の破壊、SYSRETQ のセレクタ配置・canonical RIP/RSP を確認し、安全な固定復帰先のみ使用する。MSTAR は本教材の 64-bit 呼び出しでは使わない。CPL=3 から UART I/O は行わない |
| s104_sse (候補) | SSE | XMM0-15、`movaps`/`addps`、16-byte アライン制約。qemu64 のデフォルト CPU 機能で動くか実測してから採否 |

## Makefile ターゲット設計

統一デバッグインターフェース (ルート Makefile パススルー対応) を完全実装:

| ターゲット | 実装 |
| :--- | :--- |
| `make` / `make all` | boot.o + 全シナリオをビルドし img 化 |
| `make run S=` | `timeout --foreground $(TIMEOUT_SECS) qemu-system-x86_64 -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none` |
| `make runall` | 全シナリオ + s06/s12 への入力パイプ (x86_16 と同一レシピ) |
| `make debug S=` | QEMU を `-S -gdb tcp:127.0.0.1:1234` でバックグラウンド起動し、`gdb -q $(S).elf` で接続 (`hbreak *_start` 相当のカーネル先頭から)。`debug.gdb` を `-x` で明示ロードし、`regs64` マクロ + RFLAGS デコード (CF/PF/AF/ZF/SF/OF。m68k/x86_16 の flags 拡張と同形式) を定義。マクロ方式は全 x86 で `debug.gdb` に統一 (x86_32 計画の「gdb マクロ方式」参照) |
| `make trace S=` | `-accel tcg,one-insn-per-tb=on -d in_asm,cpu -dfilter 0x8000+0x7e00` で `.trace` に記録しページャ表示 |
| `make cycles S=` | `unsupported` メッセージ (TCG はサイクル非対応。x86_16 と同一) |
| `make icount S=` | trace と同じ起動で `-d cpu` のみ、`RIP=` 行を実測で確認して集計。対象は `.text` のアドレス範囲のみとし、BIOS・移行処理・停止ループを除外する。ログ上限や時間切れで途中終了した計測は不完全と表示し、完走の数値と区別する |
| `make dump S=` | `ndisasm -b 64 -o 0x8000 -e 1024 $(S).bin` (dump32 相当を 64-bit に。ブートセクタと移行スタブをスキップ) |
| `make clean` | `*.bin *.img *.o *.lst *.trace *.elf` 削除 |

QEMU 起動フラグは共通の QFLAGS (`-machine pc -accel tcg -cpu qemu64 -no-reboot -no-shutdown`) に集約し、全ターゲットで同一にする (CPU モデル・アクセラレータの明示による再現性確保。必須条件の `-cpu qemu64` 統一と同じ趣旨)。trace と icount では `-accel` を `-accel tcg,one-insn-per-tb=on` に差し替える。

x86_16 にある `make test` (test_scenarios.py) は x86_64 版を Phase 1 で s01 用に導入し、Phase 2 で s02〜s12、Phase 3 で s13 に拡張する (期待シリアル出力の自動チェック)。

## ドキュメント更新

1. **`arch/x86_64/CPU.md`**: 「ロングモード移行」セクション追加 — GDT の L ビット、CR0/CR4、EFER MSR、4 段ページング構造、16→32→64 の遷移手順
2. **`arch/x86_64/qemu/README.md`**: x86_16 README 構成準拠 (前提条件 → ビルドと実行 → デバッグ → ディレクトリ構造 → CPU と実行環境 → シナリオ一覧 → 関連ドキュメント → ハードウェア情報 (QEMU 起動構成 / 16550 / 8254 / アドレスマップ) → I/O ルーチン → 次のステップ)
3. **ルート `README.md`**: アーキテーブルに `arch/x86_64/qemu/` 行、出力テーブル (16550 / `OUT` / `0x3F8`)、終了方法テーブル (HLT+タイムアウト)、ツールテーブル (`qemu-system-x86_64`)、ディレクトリツリー
4. **ルート `AGENTS.md`**: アーキテーブルに行追加: `x86_64 | arch/x86_64/qemu/ | nasm (-f elf64) + ld.lld | qemu-system-x86_64 (floppy boot) | .asm`
5. **ルート `Makefile`**: `CORE_DIRS` に `arch/x86_64/qemu` を追加

## フェーズ分割

| Phase | 内容 | 完了条件 |
| :--- | :--- | :--- |
| **1: ブート基盤** | `boot.asm`、`linker.ld`/`linker-debug.ld`、Makefile 骨格 (all/run/test/debug/clean)、`debug.gdb`、`test_scenarios.py`、`s01_hello.asm`、README 骨格 | `make run S=s01_hello` で "Hello" がシリアル出力され hlt。`make test` で s01 の期待出力を照合。`make debug` で 0x8000 以降の 64-bit コードをステップ可能 |
| **2: 共通シナリオ** | s02-s12 (11 本) | `make runall` 全シナリオ OK、s06/s12 のパイプ入力が動く |
| **3: 統合と計測** | s13_copybench、debug/trace/cycles/icount/dump 検証、test_scenarios.py、ルート 4 ファイル更新 (README/AGENTS/Makefile/CPU.md) | `make trace A=x86_64/qemu S=...` 等のルートパススルーが動く。copybench checksum `0x1356` 一致。ルート `make runall` に x86_64 が含まれる |
| **4: アーキ固有** | s101_riprel、s102_paging、s103_syscall (+s104_sse は実測後に採否) | 各シナリオの期待出力と README 学習カード (予測→観察→改造→考察) が揃う |

## 検証計画

- **Phase 1**: img を `ndisasm -b 16/-b 64` でダンプしブートチェーンの各段 (0x7C00/0x7E00) を目視確認。gdb で CR0/CR4/EFER の遷移をレジスタ観察
- **Phase 2**: 全共通シナリオの期待出力テストを通す。runall の終了コードだけで合格にしない
- **Phase 3**: `make icount` の数値が `grep -c` で安定して取れること (RIP= の実測)。`make debug` で `debug.gdb` の regs64/flags が正しく表示されること
- **Phase 4**: copybench は checksum 一致が必須。s102 はページテーブルの実値と QEMU の `info tlb` 系の出力突き合わせ (可能な範囲)

## リスクと未決事項

1. **QEMU `-d cpu` のレジスタ行表記**: 64-bit モードで `RIP=` か `EIP=` か要実測 (`icount` の grep パターンが決まる)
2. **qemu64 デフォルト CPU の機能**: SSE/AVX と SYSCALL (EFER.SCE) の可用性は実測。だめなら `-cpu max` への変更を検討
3. **カーネルサイズ上限**: 移行スタブを含む 64 セクタ。増量時は CHS、64KB 境界、メモリマップとリンク検査を再設計する
4. **gdb のアーキテクチャ切替**: 16-bit ブート部と 64-bit カーネル部で gdb の解釈が変わる点。x86_16 の i8086.xml/i386-32bit.xml 相当の対応が必要か実測 (x86_64 は gdb ネイティブサポートのため基本不要、`break` をカーネル先頭に置く運用で回避)
5. **s12_minishell の行編集**: x86_16 版をほぼそのまま移植 (バックスペース程度)。x86_64 固有の拡張はしない

## 実装時の必須条件（レビュー反映）

- 16-byte アラインメントは本教材で採用する System V AMD64 の呼び出し規約として説明する。CALL 直前の RSP を 16 の倍数、関数入口を RSP % 16 = 8 とし、callee-saved レジスタと red zone 不使用を明記する。PUSH のハードウェア要件とは区別する。
- ロングモードの 2MB ページでは PML4 → PDPT → PD で解決し、PT は参照しない。S102 はこの違いを観察する。
- SSE 候補では CPUID 確認に加え CR0.EM/TS と CR4.OSFXSR/OSXMMEXCPT の初期化を定義する。CPU モデルは `-machine pc -accel tcg -cpu qemu64` を全ターゲットで統一し、変更時は機能と再現性を再検証する。
- `make debug` は起動時の実行前ブレークを明示し、_start のソフトウェアブレークがロード時の上書きで失われないようハードウェアブレークを利用する。64-bit 部には i8086.xml を適用しない。ローカル .gdbinit の自動ロード許可に依存せず、必要なマクロを `-x` で明示的に読み込む。
- bin とデバッグ ELF の配置一致をリンカシンボル・セクションアドレスで検査する。16/32-bit スタブからの ELF64 再配置が NASM/lld で成立することを Phase 1 で最初に確認する。
- ビルド各工程は失敗時に即座に非ゼロ終了する。QEMU はタイムアウト 124 と起動失敗を区別し、子プロセスを回収する。トリプルフォルトの再起動による成功誤認を防ぐため `-no-reboot -no-shutdown` を使う。
- Phase 1 から期待シリアル出力を照合する test を用意し、Phase 2 で全シナリオへ拡張する。`runall` の 0/124 は機能の成功条件ではない。テストは一時イメージで実行し、欠落出力・QEMU 起動失敗・不正命令を失敗として扱う。
- ルート Makefile の all/runall は現状エラーをスキップするため、受入判定は `make -C arch/x86_64/qemu test` の終了コードで行う。

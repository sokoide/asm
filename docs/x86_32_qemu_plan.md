# x86_32 QEMU 版整備計画

作成日: 2026-11-15 / 状態: 計画（未実装）

## 目的と実装順序

既存の `x86_32/CPU.md` と `x86_32/darwin/` に対応する `x86_32/qemu/` を作る。ディレクトリ名は x86_16 / x86_32 / x86_64 に統一する。x86_64 より先に32ビット保護モード版を完成させ、ブート、UART、デバッグ、出力検証の基盤を実証する。既存の x86_16 教材は独立したまま維持する。

## 対象環境

- NASM `cpu 386`、シナリオは `bits 32`、`-f elf32`。リンカは `ld.lld -m elf_i386`。
- QEMU は `qemu-system-i386 -machine pc -accel tcg -cpu 486`。CPU モデルと命令セット制限を区別する。QEMU の提供モデルは実装開始時に確認する。
- SeaBIOS のフロッピーブート、16550 COM1（0x3F8）入出力。GRUB、UEFI、ホスト OS のシステムコールには依存しない。
- CPL=0、ページング無効、IF=0。終了は `cli; hlt` のループ。QEMU 回収には timeout を使い、`-no-reboot -no-shutdown` で障害時の再起動を抑止する。

## ブートと配置

1. 0x7C00 の16ビットブートセクタで CS、DS、ES、SS、SP、DF を初期化し、BIOS の DL を保存する。
2. INT 13h で sector 2 から固定64セクタを 0000:7E00 へ1セクタずつロードする。18 sectors/track、2 heads の CHS を更新する。CF エラーは有限回再試行し、最終失敗を UART 出力して停止する。
3. 0x7E00 の移行スタブで A20 を有効化し、GDT（null、32-bit code=0x08、data=0x10）をロードする。CLI、CR0.PE、far jump の順で保護モードへ移行する。
4. DS/ES/SS を設定し、ESP=0x90000、DF=0、`.bss` をゼロ初期化して 0x8000 の `_start` へジャンプする。IDT を構築するまでは STI を使わない。

| アドレス | 用途 |
| :--- | :--- |
| 0x7C00–0x7DFF | ブートセクタ（署名 0x55AA） |
| 0x7E00–0x7FFF | 移行スタブ（最大512バイト） |
| 0x8000–0xFDFF | シナリオのロード領域 |
| 0x90000 | スタックトップ |

リンカ ASSERT とビルド検査で、ブートコード510バイト、移行スタブ512バイト、全ロードイメージ33280バイトの上限を検査する。`.bss` のメモリ終端とスタック予約範囲の非重複も検査する。

## ファイルとビルド

- `boot.asm`、`linker.ld`、`linker-debug.ld`、`Makefile`、`debug.gdb`、`test_scenarios.py`、`README.md`、シナリオ別 `.asm` を用意する。
- boot とシナリオを別オブジェクトとしてリンクする。bin とデバッグ ELF は同一セクション配置とし、シンボルとロード領域の一致を検査する。
- 1.44MB のイメージをゼロ埋めし bin を書き込む。AS、LD、サイズ検査、イメージ生成の失敗は即座に非ゼロ終了する。
- スタック規約は教材内で明示する。引数はレジスタ渡しから始め、保存対象レジスタを関数ごとに定義する。外部 ABI への準拠は別項目として説明する。

## 共通シナリオ

| 番号 | テーマ | 要点 |
| :--- | :--- | :--- |
| s01_hello | Hello World | 保護モード到達と UART |
| s02_registers | レジスタ | EAX〜EDI、部分レジスタ |
| s03_stack | スタック | PUSH/POP、ESP の4バイト変化 |
| s04_loops | ループ | ECX、LOOP、条件分岐 |
| s05_strings | 文字列 | ESI/EDI、LODSB/STOSB、DF |
| s06_serial_in | シリアル入力 | Enter までエコー |
| s07_subroutines | サブルーチン | CALL/RET、保存規約 |
| s08_hardware | ハードウェア | PIT の読み取り（値は変動） |
| s09_branching | 分岐 | 符号付き・符号なし |
| s10_bitwise | ビット演算 | 32ビットシフト・マスク |
| s11_memory | メモリ | fill/copy、base+index*scale |
| s12_minishell | ミニシェル | hello/help/quit、行入力 |
| s13_copybench | 共通コピー課題 | 100バイト、checksum=0x1356 |

固有シナリオは共通版完成後に設計する。ページングや例外・割り込みを追加する場合は IDT、例外フレーム、復帰手順を別途規定し、共通版の完了条件に含めない。

## ターゲットと成功判定

| ターゲット | 内容 |
| :--- | :--- |
| all | 全シナリオのビルド・サイズ検査・イメージ生成 |
| run / runall | 出力の観察。入力は s06 に q 改行、s12 に quit 改行 |
| test | 一時ディスクコピーで QEMU を実行し、主要な期待シリアル出力を照合 |
| debug | loopback gdbstub に接続し、ELF シンボル付きで `_start` にハードウェアブレーク。i386 / Intel 表示、マクロは `-x debug.gdb` で明示ロード |
| dump | 0x8000 のシナリオを32ビット逆アセンブル。ブートは別に16ビットで観察 |
| trace | one-insn-per-tb で命令と状態を記録。ログ上限・時間切れを明示 |
| cycles | unsupported |
| icount | シナリオ `.text` のみを集計。BIOS、移行処理、終了ループを除外し、完走と打切りを区別 |
| clean | 生成物だけを削除 |

タイムアウトは HLT 後も QEMU が動作するため許容するが、期待出力欠落は失敗とする。QEMU 起動失敗とビルド失敗の注入でも非ゼロ終了することを確認する。ルート all/runall は失敗をスキップする既存動作のため、受入判定には個別ディレクトリの test を使う。

## フェーズと受入条件

1. **ブート基盤**: s01、build/run/test/debug を実装。署名・ロード範囲・CR0.PE・CS 属性・32ビット命令のステップ・UART 出力を確認する。bin/ELF の配置一致を確認する。
2. **共通教材**: s02〜s12 を実装し、入力・期待出力のテストを追加する。全12件が成功する。
3. **比較と統合**: s13、dump/trace/icount/cycles、README、CPU.md の補足を実装する。全13件と失敗注入を確認する。ルート README/AGENTS.md/Makefile の CORE_DIRS と compare/copybench.md に追加する。
4. **x86_64 への移行**: 実測済みのロード、GDT、配置、UART、テストの仕様を x86_64 計画に反映する。コード共有は実装の重複と差分を確認して判断し、先に汎用化しない。

QEMU の実行確認は80386実機互換性や実サイクル数の証明にしない。TCG の実行時間をアーキテクチャ性能比較に用いない。

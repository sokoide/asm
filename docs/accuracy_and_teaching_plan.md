# 教材正確性修正と学習サイクル改善プラン

作成日: 2026-11-14 / 状態: 実装済み

## 実施状況 (2026-11-14)

- **1-1**: isa `x86_16.json` の MOVS を 9+17n に修正し `src: book` に昇格（8086マシン語秘伝の書(1990) 三の章ニモニック表「18 OR 9+17 N」で裏取り、isa build 再生成）。`s13_copybench.asm` の内訳を 1709（セットアップ込み 1723、17.09 クロック/バイト）に修正。`compare/copybench.md` に「命令数 ≠ サイクル数 ≠ 実行時間」節と実行時間列（6502 約1.60ms / Z80 約0.65ms / 8086 約0.34ms / 68000 約0.28ms @基準クロック）を追加
- **1-2**: tstates.go を UM0080 準拠に修正（DJNZ base 5→8・taken 8→13、LD r,(HL)/LD (HL),r 4→7、ALU A,(HL) 4→7、BIT b,(HL) 15→12。全行照合の結果、不正はこの 4 箇所のみ）。テスト期待値を出典コメント付きで更新。再計測: z80 s13 16,012→16,486 T、s101_blockops 30,961→32,623 T（LDI 26T/バイト・LDIR 2095T は不変）
- **1-3**: setFlagsSub に非オーバーフロー時の PF クリア、setFlagsInc/Dec をオーバーフロー P/V に修正。指定 4 ケース + AND パリティ対比の 5 テスト追加
- **1-4**: trace-diff.awk を BEFORE/AFTER/CHANGE 形式に（2 パス化）。root README の TXS と `SP: FFFF→FFC0` の誤結合を修正 — `SP` は cc65 ランタイムのソフトウェア SP（ゼロページ $06-$07 の `sp` 変数、`sta $06` で初期化される）で、TXS が書くのはハードウェア `S` のみ
- **2-1**: s102_interrupts を RETI に変更（RETN/RETI の違いを記載）、simz80 に EI ディレイ（割り込み Window）を実装しテスト追加
- **2-2**: `make icount` を追加し `make cycles` と分離（QEMU 系 cycles = unsupported、6502 = sim65i トレース実測、Z80 = 命令数/T-state 分離）。ppc/m68k の完走値・打ち切り値の区分を表示に明記（m68k は halt 検出で通常完走値になる実測に基づき plan の区分を訂正）。6502 s13 の icount 4,771 を copybench 表に反映
- **2-3**: QEMU 系 6 Makefile の gdb を `tcp:127.0.0.1:` に限定
- **P2**: 学習カード（予測→観察→改造→考察）を 8 アーキの拡張シナリオ節に追加（計 24 枚）、ppc s101_cr_lr に 6 デモの入口ラベル + 観察ポイント・break アドレス表
- 検証: 全 8 アーキ runall PASS、z80 make test PASS、markdownlint / textlint 0 エラー。riscv 系 icount は終了デバイスの非同期処理で数命令の実行間差があるため copybench 表に注記

## 再レビュー指摘への対応 (2026-11-14 第 2 次)

- **P0-1 isa MOVS**: 初回の修正スクリプトがメモリ上の辞書のみを書き換えファイルに書き出していなかった（generate.py と CLI 確認が未変更のファイルを参照して見逃した）。ファイル書き出し → isa build 再生成 → `isa/build/x86_16/MOVS.txt` に `9+17n` 反映を再確認。原因は検証対象がメモリ内データだったこと
- **P0-2 BIT b,(IX/IY+d)**: tstatesHere の DD CB パスを op 依存に修正（BIT = 20T、rotate/SET/RES = 23T。op は DD CB d の 3 バイト先）
- **P0-2 DD 76**: tstatesIX(0x76) を 4 → 8 T（プレフィックス フェッチ 4T + HALT 4T）
- **P1 icount の物理量分離**: simz80 に cpuInsns / bdosCalls / intAccepts カウンタを導入。`make icount` は CPU 命令のみ（instrCount はデバッガの通番 = イベント数として維持）。z80 s13 は 2,344 → 2,280（BDOS 64 回を除外）。テストに intAccepts/cpuInsns の検証を追加
- **P1 6502 icount**: 空トレース時に 1 を出すバグを修正（found ガード → unsupported 表示）。トレース番号は 0 起点のため最終番号 +1 が正しい命令数である点も確認
- **P1 学習カード**: 6502 s101/s13 のカードの「make cycles でループ単位の実測」という誤記述を修正（make cycles はプログラム全体。ループ単位は trace の累積 T-state で入口・出口の差分を取る）。6 アーキのカードは全量 icount を正しく説明していたため無変更。**z80 の学習カード 4 枚（S13/S101×2/S102）が未追加だった**ため追加
- 将来改善（未実施、記録）: `make measure S=... START=<label> END=<label>` の区間計測機能、計測コマンドの `|| true` 遮蔽の見直し、ppc/m68k halt 検出の明示的マーカー化

## 0. 指摘事項の検証結果（実コード・一次資料で裏付け済み）

| 指摘 | 検証結果 |
| :--- | :--- |
| 1-1 8086 REP MOVSB | **誤りを確認**。`isa/data/x86_16.json` の MOVS エントリ自体が `17+4n`（`src: knowledge`）で、`s13_copybench.asm` と `compare/copybench.md` に波及。正しくは 8086 で **9+17n**（iAPX 86/88 User's Manual 210201 Table 2-21、Abrash Zen of Assembly Appendix A も同値）。物理的裏付け: 8086 のバスサイクルは 4 クロックで、read+write だけで最低 8 クロック/バイト → 4.17 クロック/バイトは不可能 |
| 1-2 Z80 T-state | **誤りを確認**。`tstatesMain`: DJNZ base=5（正: 8）、x==1 が LD r,(HL)/LD (HL),r をまとめて 4（正: 7）、x==2 が ALU A,(HL) を 4（正: 7）、`tstatesCB` が BIT b,(HL) を 15（正: 12）。`simz80_test.go` の `{"DJNZ base", tstatesMain(0x10), 5}` も誤期待値。LDIR 21/16 と 2095T は正しい |
| 1-3 P/V フラグ | **誤りを確認**。`setFlagsSub` はオーバーフロー時に PF を立てるが非オーバーフロー時に `szpFlags` 由来のパリティをクリアしていない。`setFlagsInc`/`setFlagsDec` はパリティのまま（`setFlagsAdd` は既に修正済み） |
| 1-4 6502 トレース | **確認**。root README が TXS と `▸ SP: FFFF→FFC0` を結びつけているが、トレースの `SP=` は cc65 ランタイムのソフトウェア SP（ゼロページ SPAddr の 16 ビット値）、TXS が書くのは CPU のハードウェア S（8 ビット）で別物。trace-diff.awk は「実行前値の連鎖」表示 |

## 1. P0: 正確性の修正

### 1-1. 8086 REP MOVSB サイクル数

- `isa/data/x86_16.json`: MOVS の cycles を `{REP 時 1回ごと: 9+17n}` に修正。22_Library の 8086 書籍（秘伝の書/ハンドブック）で Table 2-21 を照合し、確認できたら `src` を `knowledge` → `book` に昇格。MOVSW（9+25n と予想 — 実装時に照合）も合わせて確認。`isa build` で再生成
- `x86_16/qemu/s13_copybench.asm`: コメントの内訳を修正（REP MOVSB 100 バイト = 1709、cld/mov×3 のセットアップ 14 込み = **1723**、17.09 クロック/バイト）
- `compare/copybench.md`:
  - 8086 行を修正
  - **実行時間の列を追加**: サイクル数 ÷ 基準クロック周波数（µs/100 バイト）。基準は明示的に仮定として書く（6502 1MHz / Z80 4MHz / 8086 5MHz / 68000 8MHz / PPC440 はコア依存のため除外）
  - 読みどころを書き直す: Z80 LDIR は 5.25µs/バイト（21T÷4MHz）、8086 REP MOVSB は 3.42µs/バイト（17.09÷5MHz）→「命令 1 回の強さ」と「クロック当たりの仕事」を区別する比較に
- 「命令数 ≠ サイクル数 ≠ 実行時間」の説明を compare 文書の冒頭に移動・強化

### 1-2. Z80 T-state 表

- `tstates.go` 修正（Zilog UM0080 との照合で不正 4 行のみ、他は監査済みで一致）:
  - DJNZ: base 5 → **8**、`conditionalDelta` の DJNZ delta 3 → **5**（taken = 13）
  - x==1: `op == 0x76`（HALT = 4）を先に判定し、`y==6 || z==6` → **7**（LD r,(HL) / LD (HL),r）
  - x==2: ALU A,(HL) → **7**
  - `tstatesCB`: x==0（rotate/shift 系、(HL)）= 15、x==1（BIT）で (HL) = **12**、SET/RES (HL) = 15 を区別
- `simz80_test.go`: **期待値を Zilog UM0080 の命令表から作り直す**（出典をテストコメントに記載）。`{"DJNZ base", 5}` を 8 に修正し、LD A,(HL)=7、ADD A,(HL)=7、BIT 0,(HL)=12 を追加。tstatesIX/ED の既存値も表照合の監査結果をコメント化
- **掲載済み計測値の再計測**: 修正後に z80 シナリオを `make cycles` で再計測し、`compare/copybench.md` の Z80 行（16,012T 等）と z80 README の数値を更新。s101_blockops の LDIR 2095T は変化しないことを確認

### 1-3. Z80 P/V フラグ

- `setFlagsSub`: オーバーフローなしのとき `f &^= PF`（パリティ残留の除去）
- `setFlagsInc`/`setFlagsDec`: P/V をオーバーフローに変更（INC は a==0x7F、DEC は a==0x80 で V=1、それ以外はクリア）
- テスト 4 件（指示どおり）: `0x00-0x01=0xFF → V=0` / `0x7F+1=0x80 → V=1` / `INC 0x7F → V=1` / `DEC 0x80 → V=1`。P/V の意味が命令ごとに変わる点をシナリオコメントにも追記（Z80 の特徴として）

### 1-4. 6502 トレース表示と S/SP の区別

- `trace-diff.awk`: 差分行を BEFORE / AFTER / CHANGE 形式に変更

  ```text
  0202  TXS           A=00 X=FF ...
        BEFORE: S=FF
        AFTER:  S=FC
        CHANGE: S FF→FC
  ```

- README 修正:
  - root README: TXS と `SP: FFFF→FFC0` を結びつけている説明を修正。**`S` = CPU のハードウェアスタックポインタ（8 ビット、TXS/TSX/PHA 等が操作）、`SP` = cc65 ランタイムのソフトウェアスタックポインタ（16 ビット、ゼロページ SPAddr）**を明記
  - 6502 README: トレースの読み方節を新形式に更新、`TXS`/`TSX` の説明行に「ハードウェア S の操作」と追記

## 2. P1: 構造的な改善

### 2-1. RETI/RETN の区別と EI ディレイ

- `z80/sim/s102_interrupts.asm`: マスク可能割り込み（IM 0/1/2）のハンドラを **RETI** に変更。RETN は NMI 復帰用で、RETI は外部デバイス（デイジーチェーン）への割り込み終了通知を持つ点をシナリオヘッダと README に記載（simz80 はデイジーチェーンをエミュレートしないため動作は同一だが、教材としては正しい命令を選ぶ）
- simz80: **EI ディレイを実装**（EI の次の 1 命令までは割り込み不許可 — 実機の割り込み Window）。テスト追加。既知簡略化リストから「EI ディレイなし」を削除

### 2-2. icount と cycles の分離

- 8 Makefile + root Makefile パススルー:
  - **`make icount`**: 実行命令数（QEMU 系は現行の cycles 実装をここへ改名）
  - **`make cycles`**: 実サイクル。6502 = sim65/sim65i 実測、Z80 = simz80 T-state 実測、**QEMU 系 = `unsupported`（TCG はサイクル非対応）とだけ表示し代替値を出さない**
  - 6502 の icount: sim65i の `-t` トレースの命令番号から集計（任意実装、不可なら unsupported）
- ppc/m68k の終了判定: 同一 PC 3 連続ヒューリスティックは維持するが、意味を明確化して表示に区別する
  - ppc: `halt` ループ突入まで = **完走値**（halt ループ自体は除外）
  - m68k: TRACE_SECS 打ち切り = **打ち切り値**（最後まで実行していない）
  - 将来の改善として明示的な halt マーカー（例: 特定の illegal 命令 2 連続）の導入を「次のステップ」に記載
- 全 README の `make cycles` 記述を新体系に更新

### 2-3. gdb stub を loopback に限定

- 6 QEMU Makefile（m68k/ppc/riscv32/riscv64/arm64/x86_16）: `-gdb tcp::$(GDB_PORT)` → `-gdb tcp:127.0.0.1:$(GDB_PORT)`

## 3. P2: 学習サイクル（予測 → 観察 → 改造 → 考察）

- 拡張シナリオ（s13_copybench / s101+ / s102+ / s103_irq_nmi）の各 README 節に学習カードを追加。形式:
  - **STEP 1 予測**: 命令長・サイクル差などを先に予想させる設問
  - **STEP 2 観察**: 使うコマンド（`make trace` / `make debug` / `make icount`）と見るべき場所
  - **STEP 3 改造**: 具体的な変更例（ループ回数、アドレッシングモードの差し替え）
  - **STEP 4 考察**: 他アーキとの対比（compare/copybench.md やアーキ間の参照）
- 1 ファイル多デモのシナリオには分割せず以下を用意:
  - ppc `s101_cr_lr`: デモ入口に分かりやすいグローバルラベル（`demo1_cr0_compare:` 等）を付与し、README に各デモの観察ポイントと `make debug` での break 先アドレスを記載
  - z80 `s102_interrupts` / 6502 `s103_irq_nmi` / x86_16 `s101_segments` も同様に各デモの観察ポイントを追記

## 4. 検証

- z80 `make test`（新期待値で全 PASS）、`go vet` / `gofmt`
- 全 8 アーキ `make runall`（既存出力の変化は z80 の計測値を含むドキュメント数値のみ。トレース表示形式変更は runall 出力に影響しない）
- `isa build` 再生成（724 命令、index 一致）と `isa MOVS` の確認
- 再計測値のドキュメント反映漏れチェック（grep で旧数値を検索）
- markdownlint / textlint

## 5. 実装順序と分担（2 sub agent + main）

1. **main**: 1-1（isa データ + copybench 文書 + 実行時間列）、1-3（P/V フラグ）、1-2（T-state 表 + テスト書き換え + 再計測）— 数値の正確性が絡むため本体が一貫して担当
2. **agent 1**: 1-4（trace-diff.awk + README の S/SP 修正）、2-1（RETI/EI ディレイ）、2-3（gdb loopback）
3. **agent 2**: 2-2（icount/cycles 分離、8 Makefile + root）、3（学習カード: 8 アーキの README 節 + ppc デモラベル）
4. **main（仕上げ）**: 再計測値の最終反映、全体検証、commit

## 参照

- Intel iAPX 86/88 User's Manual（オーダー 210201）の命令タイミング表 — REP MOVSB = 9+17n。bitsavers にスキャンあり。ユーザー指摘の「8086 Family User's Manual Table 2-21（p.2-61、inf.pucrs.br ミラー）」と同系の一次資料。実装時に 22_Library の 8086 書籍で二重照合する
- [Abrash, Zen of Assembly Language Appendix A](https://www.jagregory.com/abrash-zen-of-asm/) — MOVS = 18、REP 系 9+17 の交差検証
- Zilog Z80 CPU User Manual (UM0080) — 命令タイミング表（DJNZ 13/8、LD r,(HL) 7、ALU A,(HL) 7、BIT b,(HL) 12）と割り込み応答（IM 0/1 = 13T、IM 2 = 19T）
- 22_Library の 8086 書籍（isa CLI の元資料）— REP MOVSB 行の照合用

# isa — オフライン命令セット・リファレンス（CLI 辞書）

ISA = Instruction Set Architecture（命令セットアーキテクチャ）。CPU が実行できる命令の仕様一覧のことで、この CLI は収録アーキの ISA を引く辞書。

ネットワークなしで命令の仕様（動作・アドレッシングモード・消費クロック・フラグ変化・オペコード）を引ける CLI 辞書。正本データは `data/*.json`、検索に使う索引と命令ページは `isa build` で `build/` に生成する。

## 対応アーキテクチャ

| Arch | data | 対象 |
| :--- | :--- | :--- |
| 6502 | `data/6502.json` | 公式命令セット全 56 ニーモニック |
| z80 | `data/z80.json` | 8080 上位 + DD/CB プレフィックス含む 67 エントリ |
| m68k | `data/m68k.json` | MC68000 コア 82 エントリ |
| ppc | `data/ppc.json` | クラシック PowerPC + PPC440（Book E）125 命令 + 拡張ニーモニック 120 = 245 エントリ |
| x86_16 | `data/x86_16.json` | 8086/8088 実モード 83 エントリ |
| i386 | `data/i386.json` | 80386 32ビットプロテクトモード |
| x86_64 | `data/x86_64.json` | x86-64 コア整数命令 |
| riscv32 | `data/riscv32.json` | RV32I + M 拡張 |
| riscv64 | `data/riscv64.json` | RV64I + M 拡張 |
| arm64 | `data/arm64.json` | A64 コア整数命令の実用サブセット |

ppc は QEMU `bamboo`（PPC440）を想定し、クラシック PowerPC 命令と PPC440（Book E）命令を両方収録。MAC 系（MACC/MACHHW/MACLHW）は参照資料にニーモニック単位の記載がないため収録対象外。クラシック専用の lmw/stmw は Book E 非サポートを、sync/eieio は 440 での対応（msync/mbar）を notes に記載。

ppc は拡張ニーモニック（`blr` → `bclr 0x14, 0` のような固定オペランド形式）を `aliases` として収録する。定義は "equivalent to" 形式で、32 ビット実装の分のみ（64 ビット専用の cmpd/clrldi 系と、POWER 由来の古いニーモニック a/ae/cal 系は対象外）。一覧にも通常のエントリとして載り（riscv の疑似命令と同じ方針）、ページは元命令の内容 + 詳細欄に「拡張形式」として等価形式を表示する。

## 使い方

```sh
isa DJNZ          # 全アーキから検索（コンパクト表示。大文字小文字は同一視）
isa -v DJNZ       # 詳細全文（消費クロック・オペコード・備考）
isa blr           # 拡張ニーモニックも検索可（ppc: blr → bclr のページ + 詳細欄に「拡張形式」）
isa z80 DJNZ      # アーキを限定（isa -a z80 DJNZ と同じ）
isa LSR           # 複数アーキに同名ニーモニックがある場合は一覧 + 絞り込みヒント
isa z80           # アーキ内の命令一覧（カテゴリごとにグループ表示）
isa z80 -c 分岐    # カテゴリで絞り込み（部分一致。isa -c 分岐 で全アーキ横断の比較一覧）
isa cats          # カテゴリの一覧 + 件数（isa z80 cats / isa -a z80 cats）
isa arch          # サポートしているアーキの一覧（命令数つき）
isa               # fzf 対話モード（絞り込み + 右ペインに詳細プレビュー）
                  #   alt-1: ARCH / alt-2: ニーモニック / alt-3: カテゴリ を
                  #   第1キーに並べ替え（既定: ARCH→ニーモニック、絞り込み維持）
                  #   pgup/pgdn: ページ / ctrl-b・ctrl-f: 半ページ / alt-k・alt-j: 行
                  #   で詳細欄をスクロール
isa build         # data/*.json から build/ を再生成
```

fzf は対話モードのみで必要。未導入でも `isa MNEMONIC`・`isa <arch>` は動作する。

エイリアス登録の例（~/.zshrc）:

```sh
alias isa='~/repo/sokoide/asm/bin/isa/isa'
```

## JSON スキーマ（data/*.json）

```json
{
  "arch": "z80",
  "flagNames": ["S", "Z", "H", "P/V", "N", "C"],
  "aliases": [
    {
      "mnemonic": "bdnz",
      "operands": "addr",
      "target": "BC",
      "equivalent": "bc 0x10, 0, addr",
      "summary": "減算後のCTRが非ゼロのとき分岐（Branch if Decremented CTR is Not Zero）",
      "notes": "補足（省略可）"
    }
  ],
  "instructions": [
    {
      "mnemonic": "DJNZ",
      "operands": "d",
      "category": "分岐",
      "summary": "B を 1 減算し、0 でなければ相対分岐する",
      "addressing": ["相対分岐"],
      "flags": ["-", "-", "-", "-", "-", "-"],
      "cycles": [{"cond": "分岐成立", "cycles": 13}, {"cond": "不成立", "cycles": 8}],
      "encodings": [{"syntax": "DJNZ d", "opcode": "10 dd", "bytes": 2}],
      "notes": "補足（複数行可）",
      "src": "book"
    }
  ]
}
```

- `mnemonic` は 1 ファイル内でユニーク。先頭は大文字で英数字可 (`REV16` 等)、条件接尾 `cc`（m68k）や `.cond`（arm64）のみ小文字を許可、記録接尾 `.`（ppc `STWCX.`）と副接尾 `.I`（`FENCE.I`）も可。バリエーションは 1 エントリに統合し `operands`/`encodings`/`notes` で説明する。ただし文字列命令のサイズ別ニーモニック（`LODSB`/`LODSW`/`LODSD` 等）はサイズごとに別エントリとする（全 x86 アーチで共通方針）
- `aliases` は任意の拡張ニーモニック一覧（PowerPC の `blr`/`li` 等）。`mnemonic` は小文字で基本命令と重複不可、`target` は `instructions` の `mnemonic` を指す。一覧には通常エントリと同じく載り（riscv の疑似命令と同じ方針）、ページは元命令の内容 + 詳細欄に「拡張形式」（`equivalent` と等価）を出力する
- `flagNames` / `flags` は同長の配列。RISC-V のようにフラグレジスタがないアーキは両方 `[]`（`flags` 欄を省略して出力する）
- `cycles` は非空。`cycles` の値は数値または `"70〜77"` のような範囲文字列。実装依存のアーキ（RISC-V/ARM64）は cond にその旨を書く
- `encodings` は任意。不確実なオペコードは載せない
- `src` は任意の根拠タグ: `book`（参照書籍で確認）/ `note`（Knowledge ノートで確認）/ `knowledge`（未確認・AI 知識。現行 data では不使用）。根拠の書籍名・場所は公開リポジトリに書かず、非公開の参照記録で管理する

## フラグ記号の凡例

| 記号 | 意味 |
| :--- | :--- |
| `-` | 変化しない |
| `0` / `1` | クリア / セットされる |
| `‡` | 演算結果に依存する |
| `U` | 未定義（機種・実装で異なる。主に 8086 の乗算・除算系） |

## データ追加の手順

1. `<arch>/CPU.md`（リポジトリ内）を一次情報にし、手元の参照書籍で確認する
2. 確認したら `src: book` にする。根拠の書籍名・章は非公開の参照記録に残す（公開リポジトリには書かない）。Knowledge ノートで確認した場合のみ `src: note` にする
3. `isa data/<arch>.json` を書いたら `isa build` で検証（スキーマ違反はエラーで止まる）し、`isa <arch>` で目視確認する

## 実装メモ

- `tools/generate.py`（python3 標準ライブラリのみ）がスキーマ検証 + `build/` 生成を担う。`build/` はコミット済みなので、クエリ時は zsh + cat + fzf だけで動く（生成環境不要）
- 生成ページは `─ 詳細 ─` の区切り線より前がコンパクト表示、以降が詳細。`isa MNEMONIC` は前者のみ、`-v` は全文を出す
- 拡張ニーモニック（ppc `aliases`）は index.tsv に通常行として入るため、一覧・fzf・命令数は基本命令と区別なく扱う

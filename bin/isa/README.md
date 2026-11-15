# isa — オフライン命令セット・リファレンス（CLI 辞書）

ISA = Instruction Set Architecture（命令セットアーキテクチャ）。CPU が実行できる命令の仕様一覧のことで、この CLI は収録アーキの ISA を引く辞書。

ネットワークなしで命令の仕様（動作・アドレッシングモード・消費クロック・フラグ変化・オペコード）を引ける CLI 辞書。正本データは `data/*.json`、検索に使う索引と命令ページは `isa build` で `build/` に生成する。

## 対応アーキテクチャ

| Arch | data | 対象 |
| :--- | :--- | :--- |
| 6502 | `data/6502.json` | 公式命令セット全 56 ニーモニック |
| z80 | `data/z80.json` | 8080 上位 + DD/CB プレフィックス含む 67 エントリ |
| m68k | `data/m68k.json` | MC68000 コア 71 エントリ |
| ppc | `data/ppc.json` | クラシック PowerPC + PPC440（Book E）96 エントリ |
| x86_16 | `data/x86_16.json` | 8086/8088 実モード 61 エントリ |
| i386 | `data/i386.json` | 80386 32ビットプロテクトモード |
| x86_64 | `data/x86_64.json` | x86-64 コア整数命令 |
| riscv32 | `data/riscv32.json` | RV32I + M 拡張 |
| riscv64 | `data/riscv64.json` | RV64I + M 拡張 |
| arm64 | `data/arm64.json` | A64 コア整数命令の実用サブセット |

ppc の根拠は `22_Library` の Optimizing PowerPC Code(1995)（クラシック部分）と PowerPC 440 プログラミングモデル(2001)（Book E・キャッシュ管理・440 コアのサイクル数）。QEMU `bamboo`（PPC440）を想定し、クラシック命令と 440 固有命令（MAC 系は知識ベース）を両方収録。クラシック専用の lmw/stmw は Book E 非サポートを notes に記載。

## 使い方

```sh
isa DJNZ          # 全アーキから検索（コンパクト表示。大文字小文字は同一視）
isa -v DJNZ       # 詳細全文（消費クロック・オペコード・備考）
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
  "instructions": [
    {
      "mnemonic": "DJNZ",
      "operands": "d",
      "category": "分岐",
      "summary": "B を 1 減算し、0 でなければ相対分岐する",
      "addressing": ["相対分岐"],
      "flags": ["-", "-", "-", "-", "-", "-"],
      "cycles": [{"cond": "分岐成立", "cycles": 13}, {"cond": "不成立", "cycles": 8}],
      "encodings": [{"syntax": "DJNZ d", "opcode": "18 dd", "bytes": 2}],
      "notes": "補足（複数行可）",
      "src": "knowledge"
    }
  ]
}
```

- `mnemonic` は 1 ファイル内でユニーク。条件接尾 `cc`（m68k）や `.cond`（arm64）のみ小文字を許可。バリエーションは 1 エントリに統合し `operands`/`encodings`/`notes` で説明する
- `flagNames` / `flags` は同長の配列。RISC-V のようにフラグレジスタがないアーキは両方 `[]`（`flags` 欄を省略して出力する）
- `cycles` は非空。`cycles` の値は数値または `"70〜77"` のような範囲文字列。実装依存のアーキ（RISC-V/ARM64）は cond にその旨を書く
- `encodings` は任意。不確実なオペコードは載せない
- `src` は任意の根拠タグ: `book`（22_Library の書籍で確認）/ `note`（21_Knowledge で確認）/ `knowledge`（未確認・AI 知識）

## フラグ記号の凡例

| 記号 | 意味 |
| :--- | :--- |
| `-` | 変化しない |
| `0` / `1` | クリア / セットされる |
| `‡` | 演算結果に依存する |
| `U` | 未定義（機種・実装で異なる。主に 8086 の乗算・除算系） |

## データ追加の手順

1. `<arch>/CPU.md`（リポジトリ内）と Obsidian `21_Knowledge` の対応ノートを一次情報にする
2. 不確実なクロック数・オペコードだけ `22_Library` の該当書籍で確認し `src` に記録する
3. `isa data/<arch>.json` を書いたら `isa build` で検証（スキーマ違反はエラーで止まる）し、`isa <arch>` で目視確認する

## 実装メモ

- `tools/generate.py`（python3 標準ライブラリのみ）がスキーマ検証 + `build/` 生成を担う。`build/` はコミット済みなので、クエリ時は zsh + cat + fzf だけで動く（生成環境不要）
- 生成ページは `─ 詳細 ─` の区切り線より前がコンパクト表示、以降が詳細。`isa MNEMONIC` は前者のみ、`-v` は全文を出す

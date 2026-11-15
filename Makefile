# Multi-architecture assembly learning materials
# トップレベル便利 Makefile。各アーキテクチャのビルド/実行/掃除を一括で行います。
# 個別アーキテクチャの詳細制御は各ディレクトリ (`cd arm64/qemu && make ...`) で行ってください。

# 全シナリオ（s01〜s12/13/14）を実装するコアアーキテクチャ: all / runall / clean を持つ
CORE_DIRS := 6502/sim65 arm64/qemu ppc/qemu m68k/qemu z80/sim \
             x86_16/qemu x86_32/qemu x86_64/qemu x86_16/dos/exe riscv32/qemu riscv64/qemu

# Hello World のみの最小アーキテクチャ: all / clean を持つ（runall は非対応）
HELLO_DIRS := x86_16/dos/com

# macOS(darwin) ネイティブバイナリ（Mach-O）。darwin ツールチェーンが必要なため
# macOS(Darwin) でのみビルド対象に含める。それ以外の OS では make しない。
DARWIN_DIRS := arm64/darwin x86_64/darwin x86_32/darwin
ifeq ($(shell uname -s),Darwin)
ALL_DIRS := $(CORE_DIRS) $(HELLO_DIRS) $(DARWIN_DIRS)
else
ALL_DIRS := $(CORE_DIRS) $(HELLO_DIRS)
endif

.PHONY: all build runall clean debug trace cycles icount lint format help
.default: all

# 全アーキテクチャをビルド（ツール未インストールの環境では該当ディレクトリをスキップ）
all build:
	@for d in $(ALL_DIRS); do \
	  echo "── ビルド: $$d ──"; \
	  $(MAKE) --no-print-directory -C $$d all || echo "  (スキップ: $$d)"; \
	done

# 全シナリオを順に実行（コアアーキテクチャのみ。入力は各 Makefile がパイプ処理）
runall:
	@for d in $(CORE_DIRS); do \
	  echo ""; \
	  echo "═══ 実行: $$d ═══"; \
	  $(MAKE) --no-print-directory -C $$d runall || echo "  (スキップ: $$d)"; \
	done

# 全アーキテクチャのビルド成果物を掃除
clean:
	@for d in $(ALL_DIRS); do \
	  $(MAKE) --no-print-directory -C $$d clean 2>/dev/null || true; \
	done

# 任意アーキテクチャのデバッグ/トレース/サイクル・命令数計測へ横断
# cycles は実サイクル (QEMU 系は unsupported)、icount は実行命令数
# (例: make debug A=z80/sim S=s03_stack / make icount A=riscv64/qemu S=s01_hello)
debug trace cycles icount:
	@test -n "$(A)" && test -n "$(S)" || { echo "usage: make $@ A=<arch/platform> S=<scenario>  例: make debug A=z80/sim S=s03_stack"; exit 1; }
	$(MAKE) --no-print-directory -C $(A) $@ S=$(S)

# Markdown リンター（pnpm があれば pnpm、なければ npx）
RUNNER := $(shell command -v pnpm >/dev/null 2>&1 && echo "pnpm dlx" || echo "npx")
EXEC   := $(shell command -v pnpm >/dev/null 2>&1 && echo "pnpm exec" || echo "npx")
MD_LINT_IGNORES := --ignore "CLAUDE.md" --ignore "node_modules/**" \
                   --ignore ".omc/**" --ignore ".serena/**"

# Markdown を textlint でチェック（修正しない）
lint:
	$(EXEC) textlint "**/*.md"

# 各アーキテクチャの .s/.asm を整形し、Markdown も整形
# （サブディレクトリの format は nvim 保存時整形と同一ロジック。root README の
#   「コード整形 (make format)」セクション参照）
format:
	@for d in $(ALL_DIRS); do \
	  echo "── format: $$d ──"; \
	  $(MAKE) --no-print-directory -C $$d format || echo "  (スキップ: $$d)"; \
	done
	@echo "Formatting markdown files using $(RUNNER)..."
	$(RUNNER) markdownlint-cli "**/*.md" $(MD_LINT_IGNORES) --fix
	$(EXEC) textlint --fix "**/*.md"

help:
	@echo "ターゲット一覧:"
	@echo "  make            全アーキテクチャをビルド"
	@echo "  make runall     全シナリオを順に実行（コアアーキテクチャのみ）"
	@echo "  make clean      全アーキテクチャのビルド成果物を削除"
	@echo "  make debug/trace/cycles/icount  任意アーキのデバッグ/トレース/サイクル・命令数計測（A= と S= が必須）"
	@echo "  make lint       Markdown を textlint でチェック"
	@echo "  make format     全アーキの .s/.asm を asmfmt で整形 + Markdown を textlint + markdownlint で整形"
	@echo ""
	@echo "個別アーキテクチャは各ディレクトリで実行してください。例:"
	@echo "  cd arm64/qemu && make runall   # 全シナリオ実行"
	@echo "  cd arm64/qemu && make run S=s01_hello"

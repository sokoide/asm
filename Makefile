# Multi-architecture assembly learning materials
# トップレベル便利 Makefile。各アーキテクチャのビルド/実行/掃除を一括で行います。
# 個別アーキテクチャの詳細制御は各ディレクトリ (`cd arm64/qemu && make ...`) で行ってください。

# 全シナリオ（s01〜s12/13/14）を実装するコアアーキテクチャ: all / runall / clean を持つ
CORE_DIRS := 6502/sim65 arm64/qemu ppc/qemu m68k/qemu z80/sim \
             x86_16/qemu x86_16/dos/exe riscv32/qemu riscv64/qemu

# Hello World のみの最小アーキテクチャ: all / clean を持つ（runall は非対応）
HELLO_DIRS := arm64/darwin x86_64/darwin i386/darwin x86_16/dos/com

ALL_DIRS := $(CORE_DIRS) $(HELLO_DIRS)

.PHONY: all build runall clean lint format help
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

# Markdown リンター（pnpm があれば pnpm、なければ npx）
RUNNER := $(shell command -v pnpm >/dev/null 2>&1 && echo "pnpm dlx" || echo "npx")
EXEC   := $(shell command -v pnpm >/dev/null 2>&1 && echo "pnpm exec" || echo "npx")
MD_LINT_IGNORES := --ignore "CLAUDE.md" --ignore "node_modules/**" \
                   --ignore ".omc/**" --ignore ".serena/**"

# Markdown を textlint でチェック（修正しない）
lint:
	$(EXEC) textlint "**/*.md"

# Markdown を textlint + markdownlint で自動整形
format:
	@echo "Formatting markdown files using $(RUNNER)..."
	$(RUNNER) markdownlint-cli "**/*.md" $(MD_LINT_IGNORES) --fix
	$(EXEC) textlint --fix "**/*.md"

help:
	@echo "ターゲット一覧:"
	@echo "  make            全アーキテクチャをビルド"
	@echo "  make runall     全シナリオを順に実行（コアアーキテクチャのみ）"
	@echo "  make clean      全アーキテクチャのビルド成果物を削除"
	@echo "  make lint       Markdown を textlint でチェック"
	@echo "  make format     Markdown を textlint + markdownlint で整形"
	@echo ""
	@echo "個別アーキテクチャは各ディレクトリで実行してください。例:"
	@echo "  cd arm64/qemu && make runall   # 全シナリオ実行"
	@echo "  cd arm64/qemu && make run S=s01_hello"

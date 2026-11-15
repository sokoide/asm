SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_serial_in s07_subroutines s08_hardware \
            s09_branching s10_bitwise s11_memory s12_minishell \
            s13_copybench s101_zeropage s102_selfmod s103_irq_nmi

HELPERS = helpers.s
HELPER_OBJS = $(HELPERS:.s=.o)
HELPER_LST = $(HELPERS:.s=.lst)

# C シナリオ: リポジトリ root の _common/c/c*.c を cc65 で _common/c/c*.s に
# 生成してから cl65 でアセンブル・リンクする (make run S=c01 / make debug S=c01 等)。
# カスタム crt0 は不要 (cl65 が cc65 のスタートアップを自動リンクし、sp 設定 →
# _main 呼び出し → main の戻り値で _exit を担う)。sim65 は main の戻り値
# (A レジスタ) を終了コードにするため UART 出力はなく、runall には含めない。
COMMON_C = ../../_common/c
CSOURCES = $(notdir $(basename $(wildcard $(COMMON_C)/c*.c)))

# C シナリオ用: cc65 は -S オプションを持たず、常にアセンブリ (ca65 構文の .s) を
# 出力する。-o で出力先を指定できる。cc65 に -O0 は無く、「-O 無指定 = 最適化なし」
# で運用する。-g は生成 .s に .dbg 行 (C ソース行番号 / 変数のスタックオフセット) を
# 含めるオプション (コード生成には影響しない)。
CC65    = cc65
CFLAGS  = -t sim6502 -g

# sim65i: リポジトリ内 sim65 ビルド (IRQ/NMI 対応拡張)。
# cc65 V2.19 以降の sim65 ソースを sim65src/ にベンダリングし、
# 割り込みトリガ MMIO ($FFCC=IRQ, $FFCE=NMI) を memory.c に追加したもの。
# 既存シナリオはシステム sim65 とサイクル数まで同一の挙動。
SIM65I = sim65src/sim65i
SIM65I_SRCS = sim65src/simmain.c sim65src/6502.c sim65src/memory.c \
              sim65src/paravirt.c sim65src/error.c sim65src/trace.c \
              sim65src/debugger.c sim65src/peripherals.c sim65src/compat/compat.c

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# feed_input / icount で使うタイムアウトコマンド。GNU coreutils の timeout。
# (未定義だと $(TIMEOUT) が空展開され、タイムアウトなしで実行される)
TIMEOUT ?= timeout --foreground $(TIMEOUT_SECS)

.PHONY: all run runall debug replay trace cycles icount clean sim65i format build build-s build-c

# アセンブリソースを nvim の保存時整形と同一ロジックで整形
# （asm.lua の autocmd を headless nvim で再実行 = :w と同じ整形。
#   設定の場所はリポジトリ root README の「コード整形 (make format)」参照）
ASM_SRC := $(wildcard *.s) $(wildcard *.asm)
ASM_LUA ?= $(HOME)/.config/nvim/lua/config/asm.lua
format:
	@command -v nvim >/dev/null 2>&1 || { echo "nvim がありません"; exit 1; }
	@test -f "$(ASM_LUA)" || { echo "整形設定 asm.lua がありません: $(ASM_LUA)"; exit 1; }
	@test -n "$(ASM_SRC)" || { echo "format: 対象の .s/.asm がありません"; exit 0; }
	@for f in $(ASM_SRC); do \
	  nvim --headless --clean +"luafile $(ASM_LUA)" +"e $$f" +w +qa! || { echo "format 失敗: $$f"; exit 1; }; \
	done

all: sim65i
	@echo "=== helpers ==="; \
	cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS) && echo "  OK" || echo "  FAIL"; \
	for s in $(SCENARIOS) $(CSOURCES); do \
		echo "=== $$s ==="; \
		if [ -f $(COMMON_C)/$$s.c ]; then \
			$(MAKE) --no-print-directory build-c S=$$s && echo "  OK" || echo "  FAIL"; \
		else \
			cl65 -t sim6502 -c -l $$s.lst -o $$s.o $$s.s && \
			cl65 -t sim6502 -o $$s --mapfile $$s.map $$s.o $(HELPER_OBJS) && echo "  OK" || echo "  FAIL"; \
		fi; \
	done

# 1シナリオ分をビルドしてバイナリ名を返す共通レシピ
# (--mapfile: シンボル表。sim65i の b/d/x で `b _main` のように指定できる)
define build_one
cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS)
cl65 -t sim6502 -c -l $(1).lst -o $(1).o $(1).s
cl65 -t sim6502 -o $(1) --mapfile $(1).map $(1).o $(HELPER_OBJS)
endef

# 共通ビルド: S=s01_hello 等は build-s (既存の cl65 ビルド)、S=c01 等
# $(COMMON_C) に .c があるシナリオは build-c (cc65 での .s 生成 + cl65 リンク) に振り分ける
build:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
		$(MAKE) --no-print-directory build-c S=$(S); \
	else \
		$(MAKE) --no-print-directory build-s S=$(S); \
	fi

# アセンブリシナリオ: $(S).s -> $(S) + $(S).map (既存の build_one と同じ)
build-s:
	$(call build_one,$(S))

# C シナリオ: $(COMMON_C)/$(S).c -cc65-> $(COMMON_C)/$(S).s -cl65-> $(S) + $(S).map
# cc65 -o で _common/c/$(S).s へ直接出力する (生成 .s は学習対象なので残す)。
# cl65 は .s を ca65 でアセンブルし、cc65 のスタートアップ + ランタイム
# (lib/sim6502.lib) を自動リンクする。c01/c02 は helpers.s の print_str を
# 使わないため helpers.o は結合しない
build-c:
	$(CC65) $(CFLAGS) -o $(COMMON_C)/$(S).s $(COMMON_C)/$(S).c
	cl65 -t sim6502 -o $(S) --mapfile $(S).map $(COMMON_C)/$(S).s

# s103_irq_nmi は割り込みトリガが必要なため sim65i を使う
# (sim65 は main の戻り値 = A レジスタを終了コードにする。C シナリオ c01/c02 は return 0)
run: build
	@if [ "$(S)" = "s103_irq_nmi" ]; then \
		$(SIM65I) $(S); \
	else \
		sim65 $(S); \
	fi

# s06/s12 は入力を読むため、runall と同じ標準入力を与える
define feed_input
if [ "$(S)" = "s12_minishell" ]; then printf 'help\nquit\n' | $(TIMEOUT) $(1) 2>/dev/null || true; \
elif [ "$(S)" = "s06_serial_in" ]; then printf 'q\n' | $(TIMEOUT) $(1) 2>/dev/null || true; \
else $(TIMEOUT) $(1) 2>/dev/null || true; \
fi
endef

# s103_irq_nmi 用のシミュレータ選択 (debug/trace/cycles でも割り込みが必要)
define pick_sim
if [ "$(S)" = "s103_irq_nmi" ]; then echo "$(SIM65I)"; else echo "sim65"; fi
endef

# 対話ステップデバッガ: make debug S=s03_stack
# z80/sim の simz80 -debug と同じ操作感 (s/n/c/b/r/d/x/q)。
# すべてのシナリオで sim65i を使う (sim65i の非デバッグ実行はシステム sim65 と同一挙動)。
debug: sim65i build
	$(SIM65I) -g $(S)

# リプレイ型ステップ表示: make replay S=s03_stack
# 全トレースを記録してからページャで1命令ずつ送って見る「再生」
# (停止・巻き戻しは自由)。実行中へのライブ制御は make debug を使う。
# sim65 --trace は stdout に出力するため、プログラム本体の出力も
# トレース行の間に混ざって記録される。
replay: build
	@SIM=$$($(call pick_sim)); \
	$(call feed_input,$$SIM --trace $(S)) >$(S).trace
	@echo "── リプレイ: SPACE/Enter で1命令ずつ、q で終了 ($(S).trace に保存済み)"
	@awk -f trace-diff.awk $(S).trace | $${PAGER:-less -R}

# 実行トレース: make trace S=s03_stack (差分付きで標準出力へ)
trace: build
	@SIM=$$($(call pick_sim)); \
	$(call feed_input,$$SIM --trace $(S)) >$(S).trace
	@awk -f trace-diff.awk $(S).trace

# 実サイクル数: make cycles S=s04_loops (最終行に合計サイクル)
# 6502 はシミュレータがクロックサイクルを正確に計上するため「実サイクル」の実測値。
cycles: build
	@SIM=$$($(call pick_sim)); \
	$(call feed_input,$$SIM -c $(S)); \
	echo "(実サイクル: sim65 が計上した 6502 クロックサイクルの実測値)"

# 実行命令数: make icount S=s04_loops
# sim65i -t トレースの 1 フィールド目 (命令番号) の最大値 + 1 を命令数とする。
# トレースはプログラム出力と混在するため、命令番号/サイクル/PC の並びを持つ
# 行だけを集計対象にする。割り込みが必要な s103_irq_nmi も sim65i でそのまま動く。
# icount: 実行命令数 (sim65i トレースの最終命令番号 + 1)。
# 完走・打ち切り・計測不能を終了コードで区別して表示する
# (GNU timeout の慣例 + sim65i の終了コード):
#   0   = 正常終了 (完走値)
#   124 = GNU timeout による打ち切り
#   125 = timeout 自体の失敗
#   126 = コマンドを起動できない / 127 = コマンドが見つからない
#   254 = sim65i のサイクル上限到達 (-x 指定時。SIM65_ERROR_TIMEOUT=-2 が
#         exit(-2) としてシェルに 254 で渡る。現在のレシピでは -x 未使用)。
#         注意: ゲストプログラム自身が 254 を返した場合も 254 になるため、
#         -x を使う将来の拡張時には両者の区別が必要
#   その他 = 異常終了またはプログラムが返した終了コード (完走と即断しない)
# 計測不能 (有効なトレース行なし) は数値の代わりに unsupported を出す。
icount: sim65i build
	@rm -f $(S).icount.trace
	@if [ "$(S)" = "s06_serial_in" ]; then printf 'q\n' | $(TIMEOUT) $(SIM65I) -t $(S) >$(S).icount.trace 2>/dev/null; st=$$?; \
	elif [ "$(S)" = "s12_minishell" ]; then printf 'help\nquit\n' | $(TIMEOUT) $(SIM65I) -t $(S) >$(S).icount.trace 2>/dev/null; st=$$?; \
	else $(TIMEOUT) $(SIM65I) -t $(S) >$(S).icount.trace 2>/dev/null; st=$$?; fi; \
	n=$$(awk '/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9A-Fa-f]+[[:space:]]/ { m = $$1+0; found=1 } END { if (found) print m+1 }' $(S).icount.trace); \
	if [ -z "$$n" ]; then \
		echo "実行命令数: unsupported (有効なトレース行なし。異常終了の可能性)"; \
	elif [ $$st -eq 0 ]; then \
		echo "実行命令数: $$n (完走値: sim65i トレース実測)"; \
	elif [ $$st -eq 124 ]; then \
		echo "実行命令数: $$n (打ち切り値: TIMEOUT_SECS で強制終了。最後まで実行していない)"; \
	elif [ $$st -eq 125 ]; then \
		echo "実行命令数: unsupported (timeout 自体が失敗。終了コード 125)"; \
	elif [ $$st -eq 126 ]; then \
		echo "実行命令数: unsupported (sim65i を起動できない。終了コード 126)"; \
	elif [ $$st -eq 127 ]; then \
		echo "実行命令数: unsupported (sim65i が見つからない。終了コード 127)"; \
	elif [ $$st -eq 254 ]; then \
		echo "実行命令数: $$n (打ち切り値: サイクル上限で終了)"; \
	else \
		echo "実行命令数: $$n (参考値: 終了コード $$st — 完走とは限らない)"; \
	fi

runall: all
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		if [ "$$s" = "s103_irq_nmi" ]; then \
			timeout --foreground $(TIMEOUT_SECS) $(SIM65I) $$s 2>/dev/null || true; \
		elif [ "$$s" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		elif [ "$$s" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		else \
			timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		fi; \
		echo ""; \
	done

sim65i:
	clang -O2 -Wall -Isim65src -Isim65src/compat -o $(SIM65I) $(SIM65I_SRCS)

clean:
	rm -f $(SCENARIOS) $(HELPER_OBJS) $(SCENARIOS:=.o) $(SCENARIOS:=.lst) $(HELPER_LST) $(SCENARIOS:=.trace) $(SCENARIOS:=.icount.trace) $(SCENARIOS:=.map)
	rm -f $(CSOURCES) $(CSOURCES:=.map) $(CSOURCES:=.trace) $(CSOURCES:=.icount.trace)
	rm -f $(COMMON_C)/c*.s

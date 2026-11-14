SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_serial_in s07_subroutines s08_hardware \
            s09_branching s10_bitwise s11_memory s12_minishell \
            s13_copybench s101_zeropage s102_selfmod

HELPERS = helpers.s
HELPER_OBJS = $(HELPERS:.s=.o)
HELPER_LST = $(HELPERS:.s=.lst)

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

.PHONY: all run runall debug trace cycles clean

all:
	@echo "=== helpers ==="; \
	cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS) && echo "  OK" || echo "  FAIL"; \
	for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		cl65 -t sim6502 -c -l $$s.lst -o $$s.o $$s.s && \
		cl65 -t sim6502 -o $$s $$s.o $(HELPER_OBJS) && echo "  OK" || echo "  FAIL"; \
	done

# 1シナリオ分をビルドしてバイナリ名を返す共通レシピ
define build_one
cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS)
cl65 -t sim6502 -c -l $(1).lst -o $(1).o $(1).s
cl65 -t sim6502 -o $(1) $(1).o $(HELPER_OBJS)
endef

run:
	$(call build_one,$(S))
	sim65 $(S)

# s06/s12 は入力を読むため、runall と同じ標準入力を与える
define feed_input
if [ "$(S)" = "s12_minishell" ]; then printf 'help\nquit\n' | $(TIMEOUT) $(1) 2>/dev/null || true; \
elif [ "$(S)" = "s06_serial_in" ]; then printf 'q\n' | $(TIMEOUT) $(1) 2>/dev/null || true; \
else $(TIMEOUT) $(1) 2>/dev/null || true; \
fi
endef

# リプレイ型ステップ表示: make debug S=s03_stack
# 注意: sim65 には対話ステップ実行がないため、全トレースを記録してから
# ページャで1命令ずつ送って見る「再生」になる (停止・巻き戻しは自由)。
# sim65 --trace は stdout に出力するため、プログラム本体の出力も
# トレース行の間に混ざって記録される。
debug:
	$(call build_one,$(S))
	@$(call feed_input,sim65 --trace $(S)) >$(S).trace
	@echo "── リプレイ: SPACE/Enter で1命令ずつ、q で終了 ($(S).trace に保存済み)"
	@awk -f trace-diff.awk $(S).trace | $${PAGER:-less -R}

# 実行トレース: make trace S=s03_stack (差分付きで標準出力へ)
trace:
	$(call build_one,$(S))
	@$(call feed_input,sim65 --trace $(S)) >$(S).trace
	@awk -f trace-diff.awk $(S).trace

# サイクル数: make cycles S=s04_loops (最終行に合計サイクル)
cycles:
	$(call build_one,$(S))
	@$(call feed_input,sim65 -c $(S))

runall: all
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		if [ "$$s" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		elif [ "$$s" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		else \
			timeout --foreground $(TIMEOUT_SECS) sim65 $$s 2>/dev/null || true; \
		fi; \
		echo ""; \
	done

clean:
	rm -f $(SCENARIOS) $(HELPER_OBJS) $(SCENARIOS:=.o) $(SCENARIOS:=.lst) $(HELPER_LST) $(SCENARIOS:=.trace)

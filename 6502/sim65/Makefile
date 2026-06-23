SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_serial_in s07_subroutines s08_hardware \
            s09_branching s10_bitwise s11_memory s12_minishell

HELPERS = helpers.s
HELPER_OBJS = $(HELPERS:.s=.o)
HELPER_LST = $(HELPERS:.s=.lst)

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

.PHONY: all run runall clean

all:
	@echo "=== helpers ==="; \
	cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS) && echo "  OK" || echo "  FAIL"; \
	for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		cl65 -t sim6502 -c -l $$s.lst -o $$s.o $$s.s && \
		cl65 -t sim6502 -o $$s $$s.o $(HELPER_OBJS) && echo "  OK" || echo "  FAIL"; \
	done

run:
	cl65 -t sim6502 -c -l $(HELPER_LST) -o $(HELPER_OBJS) $(HELPERS)
	cl65 -t sim6502 -c -l $(S).lst -o $(S).o $(S).s
	cl65 -t sim6502 -o $(S) $(S).o $(HELPER_OBJS)
	sim65 $(S)

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
	rm -f $(SCENARIOS) $(HELPER_OBJS) $(SCENARIOS:=.o) $(SCENARIOS:=.lst) $(HELPER_LST)

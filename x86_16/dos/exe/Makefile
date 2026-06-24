SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_keyboard s07_subroutines s08_vram \
            s09_branching s10_bitwise s11_memory s12_minishell \
            s13_fileio s14_psp

AS      = nasm
LK      = jwlink
ASFLAGS = -f obj
# jwlink(Open Watcom wlink 互換): OMF -> DOS .EXE。start ラベルをエントリに指定。
LKFLAGS = format dos op start=start

# シナリオ名 sNN_xxx を DOS 8.3 形式 SNN.EXE に変換するヘルパー
#   make run S=s01_hello  ->  S01.EXE
EXE = S$(patsubst s%,%,$(firstword $(subst _, ,$(S)))).EXE

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

.PHONY: all run runall dump clean

all:
	@for name in $(SCENARIOS); do \
		num=$${name#s}; num=$${num%%_*}; exe=S$${num}.EXE; \
		echo "=== $$name ($$exe) ==="; \
		$(AS) $(ASFLAGS) -o $$name.o $$name.asm && \
		$(LK) $(LKFLAGS) file $$name.o name $$exe && \
		rm -f $$name.o && \
		echo "  OK ($$(wc -c < $$exe) bytes)"; \
	done

# Run: make run S=s01_hello  (-> S01.EXE を DOSBox で実行)
run:
	$(AS) $(ASFLAGS) -o $(S).o $(S).asm
	$(LK) $(LKFLAGS) file $(S).o name $(EXE)
	rm -f $(S).o
	dosbox -c "MOUNT C ." -c "C:" -c "$(EXE)" -c "EXIT"

# Run all scenarios through DOSBox
runall: all
	@for name in $(SCENARIOS); do \
		num=$${name#s}; num=$${num%%_*}; exe=S$${num}.EXE; \
		echo ""; \
		echo "=== $$name ($$exe) ==="; \
		if [ "$$name" = "s06_keyboard" ] || [ "$$name" = "s12_minishell" ]; then \
			timeout --foreground $(TIMEOUT_SECS) dosbox -c "MOUNT C ." -c "C:" -c "$$exe" -c "EXIT" 2>/dev/null || true; \
		else \
			dosbox -c "MOUNT C ." -c "C:" -c "$$exe" -c "EXIT" || true; \
		fi; \
		echo ""; \
	done

# Disassemble (MZ ヘッダサイズは可変なのでヘッダの e_cparhdr から自動判別)
dump:
	@hdr=$$(od -An -tu2 -j8 -N2 $(EXE) | tr -d ' '); \
	ndisasm -b 16 -e $$(($$hdr * 16)) $(EXE)

clean:
	rm -f *.exe *.EXE *.o *.map

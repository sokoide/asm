# Z80 assembly for simz80 simulator (CP/M BDOS calling convention)
# Toolchain: z80asm + simz80 (Go)
# Note: z80asm (Bas Wijnen v1.8) writes the listing to stderr, so we
#       redirect 2> to capture it into a .lst file.

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell \
          s13_copybench s101_blockops s101_shadow s102_interrupts

AS      = z80asm
SIM     = ./simz80
# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1
TIMEOUT = timeout --foreground $(TIMEOUT_SECS)
GODIR   = cmd/simz80

CPMDIR   = cpm
YAZERC   = $(HOME)/cpm/.yazerc
CPMPATH  = $(abspath $(CPMDIR))
YAZEDISK = $(or $(wildcard /usr/local/lib/yaze/disks),$(wildcard /usr/share/yaze-ag/disks))

# CP/M 8.3 filename mapping (name must be ≤8 chars)
CPM_NAMES = s01_hello=S01HELLO s02_registers=S02REGS s03_stack=S03STACK \
            s04_loops=S04LOOPS s05_strings=S05STRS s06_serial_in=S06SERIN \
            s07_subroutines=S07SUBS s08_hardware=S08HARD s09_branching=S09BRNCH \
            s10_bitwise=S10BITS s11_memory=S11MEM s12_minishell=S12MSHL \
            s13_copybench=S13COPY s101_blockops=S101BLK s101_shadow=S101SHAD \
            s102_interrupts=S102INTR

.PHONY: all run runall dump debug trace cycles icount test cpm cpm-setup clean format

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

all: $(SIM)
	@for name in $(SOURCES); do \
		echo "=== $$name ==="; \
		$(AS) -l --label=$$name.lbl -o $$name.com $$name.asm 2>$$name.lst && echo "  OK ($$(wc -c < $$name.com) bytes)" || { echo "  FAIL"; cat $$name.lst; rm -f $$name.lst; }; \
	done

$(SIM): $(wildcard $(GODIR)/*.go) $(GODIR)/go.mod
	cd $(GODIR) && go build -o ../../simz80 .

# Run: make run S=s01_hello
run: $(SIM)
	$(AS) -l --label=$(S).lbl -o $(S).com $(S).asm 2>$(S).lst
	$(TIMEOUT) $(SIM) $(S).com

# Step debugger: make debug S=s03_stack
# Commands: s=step n=next(call) c=continue b ADDR r=regs d [ADDR] x ADDR q=quit
debug: $(SIM)
	$(AS) -l --label=$(S).lbl -o $(S).com $(S).asm 2>$(S).lst
	$(SIM) -debug $(S).com

# Instruction trace: make trace S=s03_stack (pipe to less / a file as needed)
trace: $(SIM)
	$(AS) -l --label=$(S).lbl -o $(S).com $(S).asm 2>$(S).lst
	$(TIMEOUT) $(SIM) -trace $(S).com

# T-state summary: make cycles S=s04_loops
# simz80 が計上する Z80 T-state の実測値を出す。命令数は make icount を使用。
# (simz80 -cycles は instructions と T-states を両方出すため、ここでは
#  T-states 側のみを表示して cycles と icount を分離する)
cycles: $(SIM)
	$(AS) -l --label=$(S).lbl -o $(S).com $(S).asm 2>$(S).lst
	@$(TIMEOUT) $(SIM) -cycles $(S).com | awk '{ if ($$0 ~ /^instructions:/) next; print }'; \
	echo "(実サイクル: simz80 が計上した Z80 T-state の実測値)"

# 命令数: make icount S=s04_loops (simz80 の実行命令数)
icount: $(SIM)
	$(AS) -l --label=$(S).lbl -o $(S).com $(S).asm 2>$(S).lst
	@$(TIMEOUT) $(SIM) -cycles $(S).com | awk '/^instructions:/ { print "実行命令数: " $$2 " (simz80 実測 / CPU 命令のみ。BDOS 呼び出し・割り込み受付は含まない)"; found=1 } END { if (!found) print "実行命令数: unsupported (simz80 がサマリを出力せず終了。タイムアウト等で計測不能)" }'

# Unit tests for the simulator core (flags, T-states, .lst parser)
test:
	cd $(GODIR) && go test ./...

# Run all scenarios (timeout 1s to prevent hangs)
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ] || [ "$$name" = "s12_minishell" ]; then \
			$(TIMEOUT) $(SIM) $$name.com 'quit' || true; \
		else \
			$(TIMEOUT) $(SIM) $$name.com || true; \
		fi; \
		echo ""; \
	done

# Disassemble (hex dump)
dump:
	hexdump -C $(S).com

# Build CP/M-compatible copies (8.3 filenames) for yaze-ag
cpm: all
	@rm -rf $(CPMDIR)
	@mkdir -p $(CPMDIR)
	@for mapping in $(CPM_NAMES); do \
		name=$${mapping%%=*}; \
		cpmname=$${mapping##*=}; \
		cp $$name.com $(CPMDIR)/$$cpmname.com; \
	done
	@echo "CP/M files ready in $(CPMDIR)/"
	@# Ensure .ydsk files exist in ~/cpm/ for yaze-ag
	@if [ -n "$(YAZEDISK)" ] && [ -d "$(YAZEDISK)" ]; then \
		changed=0; \
		for ydsk in $(YAZEDISK)/*.ydsk; do \
			base=$$(basename $$ydsk); \
			if [ ! -f $(HOME)/cpm/$$base ]; then \
				cp $$ydsk $(HOME)/cpm/; \
				changed=1; \
				echo "Copied $$base -> $(HOME)/cpm/"; \
			fi; \
		done; \
		if [ "$$changed" -eq 0 ]; then \
			echo "~/cpm/ disk images OK"; \
		fi; \
	fi
	@# Update .yazerc: add/update mount c line before 'go'
	@if [ -f $(YAZERC) ]; then \
		awk 'BEGIN{m=0} /^mount c /{print "mount c $(CPMPATH)";m=1;next} /^go$$/{if(!m){print "mount c $(CPMPATH)"}m=1} {print}' $(YAZERC) > $(YAZERC).tmp && mv $(YAZERC).tmp $(YAZERC); \
		echo "Updated $(YAZERC)"; \
	else \
		mkdir -p $$(dirname $(YAZERC)); \
		printf 'mount c $(CPMPATH)\ngo\n' > $(YAZERC); \
		echo "Created $(YAZERC)"; \
	fi

clean:
	rm -f *.com *.bin *.sym *.lbl *.lst *.lis *.err $(SIM)
	rm -rf $(CPMDIR)

# One-time setup: copy yaze-ag disk images to ~/cpm/
cpm-setup:
	@if [ -n "$(YAZEDISK)" ] && [ -d "$(YAZEDISK)" ]; then \
		mkdir -p $(HOME)/cpm; \
		for ydsk in $(YAZEDISK)/*.ydsk; do \
			cp -n $$ydsk $(HOME)/cpm/; \
		done; \
		echo "Copied disk images to $(HOME)/cpm/"; \
	else \
		echo "yaze-ag disk images not found (expected at /usr/local/lib/yaze/disks/)"; \
		echo "Install yaze-ag first: https://github.com/andreasgerlich/yaze-ag"; \
	fi

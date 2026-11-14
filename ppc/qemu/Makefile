# PPC bare-metal assembly for QEMU bamboo machine
# Toolchain: Clang (--target=powerpc-none-elf)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell \
          s13_copybench s101_cr_lr s102_exceptions

AS      = clang
LD      = ld.lld
ASFLAGS = --target=powerpc-none-elf -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib

QEMU    = qemu-system-ppc
QFLAGS  = -machine bamboo -nographic

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# デバッグ/トレース用変数
GDB        ?= gdb
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。halt ループ(b halt)で無限スピンするため
# QEMU はタイムアウトまで走り続ける(全サンプルに halt ラベルあり)。
TRACE_SECS ?= 10

.PHONY: all run runall dump debug trace cycles icount clean

all:
	@for name in $(SOURCES); do \
		echo "=== $$name ==="; \
		$(AS) $(ASFLAGS) -o $$name.o $$name.s && \
		$(LD) $(LDFLAGS) -o $$name.elf $$name.o && \
		rm -f $$name.o && \
		echo "  OK"; \
	done

# Run: make run S=s01_hello
run:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf || true

# Run all scenarios through QEMU (PPC uses infinite-loop halt, timeout required)
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		else \
			timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		fi; \
		echo ""; \
	done

# Disassemble
dump:
	llvm-objdump -d $(S).elf

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp:127.0.0.1:PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb リモートプロトコルは認証を持たないため loopback (127.0.0.1) に限定する。
# gdb をフォアグラウンドで接続する。UART出力は gdb プロンプトに混ざって表示される。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
debug:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@$(QEMU) $(QFLAGS) -kernel $(S).elf -S -gdb tcp:127.0.0.1:$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null' EXIT INT TERM; \
	  sleep 0.3; \
	  $(GDB) -q $(S).elf \
	    -ex 'set pagination off' \
	    -ex 'target remote :$(GDB_PORT)' \
	    -ex 'set disassemble-next-line on' \
	    -ex 'printf "\n--- si: ステップ / c: continue / info registers / x/5i $$pc ---\n"'; \
	  kill $$QPID 2>/dev/null || true

# 実行トレース: make trace S=s01_hello
# one-insn-per-tb (旧 -singlestep、QEMU 8.1 で置換) で1TB=1命令とし、
# -d in_asm,cpu で命令ごとの逆アセンブルと CPU 状態を $(S).trace に記録して
# less で表示する。halt ループ(b halt)は無限に再実行されるため、同じ PC の
# ダンプが3回連続した時点で awk がログの書き出しを打ち切る(halt 突入までの記録)。
# さらに s06/s12 が quits 条件に達しないとポーリングループから抜けない場合に
# 備え、ログを head -c 32MB でも打ち切る。QEMU は SIGPIPE を無視するため
# 打ち切り後も TRACE_SECS 秒まで QEMU は動き続ける。
trace:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^NIP /{p=$$2; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
	elif [ "$(S)" = "s12_minishell" ]; then \
		printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^NIP /{p=$$2; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^NIP /{p=$$2; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
	fi
	@if [ -t 1 ]; then less $(S).trace; else cat $(S).trace; fi

# 実サイクル数: make cycles S=s01_hello
# QEMU TCG はサイクル精度のエミュレーションを行わないため実サイクル数は
# 取得できない。代替値を出さず unsupported を表示する。実行命令数の計測は
# make icount を使用。
cycles:
	@echo "unsupported: QEMU TCG はサイクル非対応のため実サイクル数は計測できません (実行命令数は make icount)"

# 実行命令数: make icount S=s01_hello
# one-insn-per-tb で命令ごとに CPU 状態ダンプ (-d cpu) を出し、halt ループ
# (b halt) は無限に再実行されるため、同じ PC のダンプが3回連続したら halt
# 突入とみなし、それまでの実行命令数を数える(ループ反復は含まれる正確な値)。
# 全サンプルは halt ループに到達するため完走値 (halt ループ自体は含まない)。
# 検出後も QEMU は TRACE_SECS 秒まで動き続ける(SIGPIPE 無視のため)。
# ログはファイル化せずパイプで直接集計する。
icount:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@if [ "$(S)" = "s06_serial_in" ]; then \
		n=$$(printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^NIP /{p=$$2; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	elif [ "$(S)" = "s12_minishell" ]; then \
		n=$$(printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^NIP /{p=$$2; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	else \
		n=$$(timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^NIP /{p=$$2; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	fi; \
	echo "実行命令数: $$n (halt ループ突入まで = 完走値。halt ループ自体は含まない)"

clean:
	rm -f *.elf *.o *.bin *.trace

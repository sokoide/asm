# RISC-V 32-bit bare-metal assembly for QEMU virt machine
# Toolchain: Clang (--target=riscv32-unknown-elf)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell \
          s13_copybench s101_csr_ecall s102_paging

AS      = clang
LD      = ld.lld
ASFLAGS = --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib

QEMU    = qemu-system-riscv32
QFLAGS  = -machine virt -nographic -bios none

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# デバッグ/トレース用変数
GDB        ?= gdb
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。プログラムが自己終了(test finisher)するため
# 通常はタイムアウト前に QEMU が抜ける。延長は export TRACE_SECS=20 等で可能。
TRACE_SECS ?= 10

.PHONY: all run runall dump debug trace cycles clean

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

# Run all scenarios through QEMU
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		else \
			$(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		fi; \
		echo ""; \
	done

# Disassemble
dump:
	llvm-objdump -d $(S).elf

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp::PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb をフォアグラウンドで接続する。UART出力は gdb プロンプトに混ざって表示される。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
debug:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@$(QEMU) $(QFLAGS) -kernel $(S).elf -S -gdb tcp::$(GDB_PORT) & \
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
# less で表示する。test finisher で自己終了するサンプルはログが完走し、
# 終了しないサンプル(s06/s12 で入力が quits 条件に達しない場合等)は
# TRACE_SECS 秒で打ち切られる。
trace:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	elif [ "$(S)" = "s12_minishell" ]; then \
		printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	fi
	@if [ -t 1 ]; then less $(S).trace; else cat $(S).trace; fi

# 実行命令数: make cycles S=s01_hello
# 注意: QEMU TCG はサイクル精度のエミュレーションでないため、CPUサイクル数では
# なく実行命令数を報告する。one-insn-per-tb で命令ごとに CPU 状態ダンプ
# (-d cpu) が記録されるので、その行数=実行命令数(ループ反復を含む正確な値)。
# test finisher で自己終了するサンプルは完走値、終了しないサンプルは
# TRACE_SECS 秒時点までの値。
cycles:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu -D $(S).trace >/dev/null 2>&1 || true; \
	elif [ "$(S)" = "s12_minishell" ]; then \
		printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu -D $(S).trace >/dev/null 2>&1 || true; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu -D $(S).trace >/dev/null 2>&1 || true; \
	fi
	@n=$$(grep -c '^ pc' $(S).trace 2>/dev/null || true); \
	[ -n "$$n" ] || n=0; \
	echo "実行命令数: $$n (QEMU TCG はサイクル非対応のため命令数で代替)"; \
	echo "詳細: $(S).trace"

clean:
	rm -f *.elf *.o *.bin *.trace

# RISC-V 32-bit bare-metal assembly for QEMU virt machine
# Toolchain: Clang (--target=riscv32-unknown-elf)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell \
          s13_copybench s101_csr_ecall s102_paging

# C シナリオ: リポジトリ root の common/c/c*.c を clang -S で common/c/c*.s に
# 生成してから crt0.s と一緒にアセンブル・リンクする (make debug S=c01 等)。
# UART 出力しない (main の戻り値は a0 で確認) ため runall には含めない。
COMMON_C = ../../../common/c
CSOURCES = $(notdir $(basename $(wildcard $(COMMON_C)/c*.c)))

AS      = clang
LD      = ld.lld
CC      = clang
ASFLAGS = --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -c -nostdlib
# C シナリオ用: ASFLAGS と同じターゲット設定で -S 生成 (-c/-nostdlib は除外)
CFLAGS  = --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -g -O0
LDFLAGS = -T linker.ld -nostdlib

QEMU    = qemu-system-riscv32
QFLAGS  = -machine virt -nographic -bios none

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# デバッグ/トレース用変数
GDB ?= $(shell command -v gdb-multiarch >/dev/null 2>&1 && echo gdb-multiarch || echo gdb)
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。プログラムが自己終了(test finisher)するため
# 通常はタイムアウト前に QEMU が抜ける。延長は export TRACE_SECS=20 等で可能。
TRACE_SECS ?= 10

.PHONY: all run runall dump debug trace cycles icount clean format build build-s build-c

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

# 共通ビルド: S=s01_hello 等はカレントの .s を、S=c01 等 $(COMMON_C) に .c が
# あるシナリオは clang -S での .s 生成を挟む C ビルドを行う
build:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	else \
	  $(MAKE) --no-print-directory build-s S=$(S); \
	fi

# アセンブリシナリオ: $(S).s -> $(S).elf
build-s:
	$(AS) $(ASFLAGS) -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o

# C シナリオ: $(COMMON_C)/$(S).c -clang -S-> $(COMMON_C)/$(S).s + crt0.s -> $(S).elf
# clang -S の出力 (c01.s 等) は学習対象なので $(COMMON_C)/ に残す (make clean で削除)
build-c:
	$(CC) $(CFLAGS) -S $(COMMON_C)/$(S).c -o $(COMMON_C)/$(S).s
	$(AS) $(ASFLAGS) -o crt0.o crt0.s
	$(AS) $(ASFLAGS) -o $(S).o $(COMMON_C)/$(S).s
	$(LD) $(LDFLAGS) -o $(S).elf crt0.o $(S).o
	rm -f crt0.o $(S).o

all:
	@for name in $(SOURCES) $(CSOURCES); do \
		echo "=== $$name ==="; \
		$(MAKE) --no-print-directory build S=$$name && echo "  OK" || exit 1; \
	done

# Run: make run S=s01_hello
run: build
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
# QEMU を -S -gdb tcp:127.0.0.1:PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb リモートプロトコルは認証を持たないため loopback (127.0.0.1) に限定する。
# gdb をフォアグラウンドで接続する。UART出力は gdb プロンプトに混ざって表示される。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
# C シナリオ (S=c01) は clang -g 付きでビルドするため list/step で C ソース行も見える
debug: build
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@$(QEMU) $(QFLAGS) -kernel $(S).elf -S -gdb tcp:127.0.0.1:$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null' EXIT INT TERM; \
	  sleep 0.3; \
	  $(GDB) -q $(S).elf \
	    -x debug.gdb \
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
trace: build
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	elif [ "$(S)" = "s12_minishell" ]; then \
		printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu -D $(S).trace >/dev/null 2>&1 || true; \
	fi
	@if [ -t 1 ]; then less $(S).trace; else cat $(S).trace; fi

# 実サイクル数: make cycles S=s01_hello
# QEMU TCG はサイクル精度のエミュレーションを行わないため実サイクル数は
# 取得できない。代替値を出さず unsupported を表示する。実行命令数の計測は
# make icount を使用。
cycles:
	@echo "unsupported: QEMU TCG はサイクル非対応のため実サイクル数は計測できません (実行命令数は make icount)"

# 実行命令数: make icount S=s01_hello
# one-insn-per-tb で命令ごとに CPU 状態ダンプ (-d cpu) が記録されるので、
# その行数=実行命令数(ループ反復を含む正確な値)。
# test finisher で自己終了するサンプルは完走値、終了しないサンプルは
# TRACE_SECS 秒時点までの値。
icount: build
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
	echo "実行命令数: $$n (QEMU 実行命令数の実測。自己終了するサンプルは完走値、打ち切られた場合は打ち切り値)"; \
	echo "詳細: $(S).trace"

clean:
	rm -f *.elf *.o *.bin *.trace
	rm -f $(COMMON_C)/c*.s

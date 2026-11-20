# m68k bare-metal assembly for QEMU virt machine
# Toolchain: m68k-elf-* (macOS: brew install m68k-elf-gcc)
#            m68k-linux-gnu-* (Linux: apt install gcc-m68k-linux-gnu)
# Goldfish TTY at 0xff008000

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell \
          s13_copybench s101_movem s102_trap

# C シナリオ: リポジトリ root の common/c/c*.c を gcc -S で build/m68k/c*.s に
# 生成してから crt0.s と一緒にアセンブル・リンクする (make debug S=c01 等)。
# UART 出力しない (main の戻り値は d0 で確認) ため runall には含めない。
COMMON_C = ../../../common/c
CSOURCES = $(notdir $(basename $(wildcard $(COMMON_C)/c*.c)))
# 生成 .s の出力先 (並行ビルドでの共通ファイル上書きを防ぐ)
CTAG    = m68k
BUILD_C = ../../../build/$(CTAG)

AS      = $(shell which m68k-elf-as m68k-linux-gnu-as 2>/dev/null | head -1)
LD      = $(shell which m68k-elf-ld m68k-linux-gnu-ld 2>/dev/null | head -1)
OD      = $(shell which m68k-elf-objdump m68k-linux-gnu-objdump 2>/dev/null | head -1)
CC      = $(shell which m68k-elf-gcc m68k-linux-gnu-gcc 2>/dev/null | head -1)
# -g: DWARF 行情報を生成 (gdb の TUI layout src / list で .s ソースを表示するため)
ASFLAGS = -m68000 -g
# C シナリオ用: -m68000 は QEMU (-cpu m68000) の命令セットに合わせるため
CFLAGS  = -g -O0 -m68000
LDFLAGS = -T linker.ld

QEMU    = qemu-system-m68k
QFLAGS  = -M virt -cpu m68000 -nographic

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# デバッグ/トレース用変数
GDB ?= $(shell command -v gdb-multiarch >/dev/null 2>&1 && echo gdb-multiarch || echo gdb)
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。halt ループ(bra halt)で無限スピンするため
# QEMU はタイムアウトまで走り続ける(全サンプルに halt ラベルあり)。
TRACE_SECS ?= 10

# 既定ターゲット (format 定義がファイル先頭にあるため明示指定)
.DEFAULT_GOAL := all

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
# あるシナリオは gcc -S での .s 生成を挟む C ビルドを行う
build:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	else \
	  $(MAKE) --no-print-directory build-s S=$(S); \
	fi

# アセンブリシナリオ: $(S).s -> $(S).elf
build-s:
	$(AS) $(ASFLAGS) -al=$(S).lst -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o

# C シナリオ: $(COMMON_C)/$(S).c -gcc -S-> $(BUILD_C)/$(S).s + crt0.s -> $(S).elf
# gcc -S の出力 (c01.s 等) は学習対象なので $(BUILD_C)/ に残す (make clean で削除)
build-c:
	@test -n "$(CC)" || { echo "m68k gcc が見つかりません: brew install m68k-elf-gcc"; exit 1; }
	@mkdir -p $(BUILD_C)
	$(CC) $(CFLAGS) -S $(COMMON_C)/$(S).c -o $(BUILD_C)/$(S).s
	$(AS) $(ASFLAGS) -o crt0.o crt0.s
	$(AS) $(ASFLAGS) -al=$(S).lst -o $(S).o $(BUILD_C)/$(S).s
	$(LD) $(LDFLAGS) -o $(S).elf crt0.o $(S).o
	rm -f crt0.o $(S).o

all:
	@for name in $(SOURCES) $(CSOURCES); do \
		echo "=== $$name ==="; \
		$(MAKE) --no-print-directory build S=$$name && echo "  OK" || exit 1; \
	done

# Run: make run S=s01_hello
run: build
	@timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf; status=$$?; \
	  if [ $$status -eq 0 ] || [ $$status -eq 124 ]; then exit 0; fi; exit $$status

# 各シナリオの終了コードを確認する（無限ループで停止する機種は timeout を許容）。
runall: all
	@for name in $(SOURCES); do \
		echo ""; echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf; \
		else \
			timeout --foreground $(TIMEOUT_SECS) $(QEMU) $(QFLAGS) -kernel $$name.elf; \
		fi; status=$$?; \
		if [ $$status -ne 0 ] && [ $$status -ne 124 ]; then echo "ERROR: $$name (終了コード $$status)"; exit $$status; fi; \
	done

# Disassemble
dump:
	$(OD) -d $(S).elf

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp:127.0.0.1:PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb リモートプロトコルは認証を持たないため loopback (127.0.0.1) に限定する。
# gdb をフォアグラウンドで接続する。UART出力は gdb プロンプトに混ざって表示される。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
# C シナリオ (S=c01) は gcc -g 付きでビルドするため list/step で C ソース行も見える
debug: build
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@command -v nc >/dev/null 2>&1 || { echo "nc が見つかりません"; exit 1; }
	@if nc -z 127.0.0.1 $(GDB_PORT) 2>/dev/null; then \
	  echo "ERROR: ポート $(GDB_PORT) が使用中"; exit 1; fi
	@$(QEMU) $(QFLAGS) -kernel $(S).elf -S -gdb tcp:127.0.0.1:$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null || true; wait $$QPID 2>/dev/null || true' EXIT INT TERM; \
	  ready=0; i=0; while [ $$i -lt 50 ]; do \
	    if ! kill -0 $$QPID 2>/dev/null; then echo "ERROR: QEMU の起動に失敗"; exit 1; fi; \
	    if nc -z 127.0.0.1 $(GDB_PORT) 2>/dev/null; then ready=1; break; fi; \
	    sleep 0.1; i=$$((i+1)); done; \
	  if [ $$ready -ne 1 ] || ! kill -0 $$QPID 2>/dev/null; then \
	    echo "ERROR: QEMU の gdbstub に接続できません"; exit 1; fi; \
	  $(GDB) -q -tui $(S).elf \
	    -x debug.gdb \
	    -ex 'set pagination off' \
	    -ex 'target remote 127.0.0.1:$(GDB_PORT)' \
	    -ex 'set disassemble-next-line on' \
	    -ex 'layout src' \
	    -ex 'layout regs' \
	    -ex 'focus cmd' \
	    -ex 'printf "\n--- si: ステップ / c: continue / info registers / x/5i $$pc / layout asm ---\n"'; \
	  status=$$?; exit $$status

# 実行トレース: make trace S=s01_hello
# one-insn-per-tb (旧 -singlestep、QEMU 8.1 で置換) で1TB=1命令とし、
# -d in_asm,cpu で命令ごとの逆アセンブルと CPU 状態を $(S).trace に記録して
# less で表示する。halt ループ(bra halt)は無限に再実行されるため、同じ PC の
# ダンプが3回連続した時点で awk がログの書き出しを打ち切る(halt 突入までの記録)。
# さらに s06/s12 が quits 条件に達しないとポーリングループから抜けない場合に
# 備え、ログを head -c 32MB でも打ち切る。QEMU は SIGPIPE を無視するため
# 打ち切り後も TRACE_SECS 秒まで QEMU は動き続ける。
trace: build
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^PC = /{p=$$3; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
	elif [ "$(S)" = "s12_minishell" ]; then \
		printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^PC = /{p=$$3; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d in_asm,cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} {print} /^PC = /{p=$$3; if(p==a&&a==b) exit; b=a; a=p}' | head -c 33554432 > $(S).trace; \
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
# (bra halt) 突入または TRACE_SECS 打ち切りまでの行数を数える。
# ループ反復を打ち切らずに数えた値だが、TRACE_SECS で打ち切った場合は
# 最後まで実行していない点に注意(打ち切り値)。
# 検出後も QEMU は TRACE_SECS 秒まで動き続ける(SIGPIPE 無視のため)。
# ログはファイル化せずパイプで直接集計する。
icount: build
	@if [ "$(S)" = "s06_serial_in" ]; then \
		n=$$(printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^PC = /{p=$$3; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	elif [ "$(S)" = "s12_minishell" ]; then \
		n=$$(printf 'help\nquit\n' | timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^PC = /{p=$$3; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	else \
		n=$$(timeout --foreground $(TRACE_SECS) $(QEMU) $(QFLAGS) -kernel $(S).elf -accel tcg,one-insn-per-tb=on -d cpu 2>&1 >/dev/null | awk 'BEGIN{a="_";b="_"} /^PC = /{p=$$3; if(p==a&&a==b){n-=2; exit} b=a; a=p; n++} END{print n+0}'); \
	fi; \
	echo "実行命令数: $$n (halt ループ突入まで = 完走値。halt ループ自体は含まない。halt を検出できず TRACE_SECS 秒で打ち切った場合は打ち切り値 = 最後まで実行していない)"

clean:
	rm -f *.elf *.o *.lst *.trace
	rm -rf $(BUILD_C)

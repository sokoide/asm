# --- 全シナリオ (ELF32 経由: nasm -f elf32 → ld.lld -T linker.ld → .bin) ---
# s00 は学習用の自由課題ファイル (番号規約外)。debug でソース表示するため登録。
# s103/s104 はマルチセクタ (2 セクタ = 1024 バイト) だが同じ ELF 経由でビルドする。
#   セクタ 2 は .text 内オフセット 512 (= 0x7E00) に times パディングで置かれ、
#   旧 -f bin (ORG 指定) 方式とバイト同一の .bin が生成される。
SCENARIOS = s00 s01_hello s02_registers s03_stack s04_loops \
         s05_strings s06_serial_in s07_subroutines s08_hardware \
         s09_branching s10_bitwise s11_memory s12_minishell \
         s13_copybench s101_segments s102_vectors s103_multisector s104_protected

AS      = nasm
# リンカ: LLVM lld を使用。brainux(ARM ホスト) のシステム ld は elf_i386 を扱えず
# (armelf_* しかサポートしない) エラーになるため、マルチアーキ対応の lld に統一。
# arm64/ppc/riscv も同じく lld を使用。
LK      = ld.lld
# 旧定義(参考): x86 クロスリンカ -> システム ld の順でフォールバックしていたが、
#   ARM ホストではクロスリンカが無くシステム ld が選ばれ、下記エラーで失敗:
#     ld: unrecognized emulation mode: elf_i386
#   LK = $(shell command -v x86_64-elf-ld 2>/dev/null || command -v x86_64-linux-gnu-ld 2>/dev/null || echo ld)
ASFLAGS = -f elf32
# 入力(nasm -f elf32 -> i386 ELF) と整合するよう 32-bit i386 を指定。lld は -m elf_i386 可。
LKFLAGS = -m elf_i386 -T linker.ld

QEMU    = qemu-system-i386
QFLAGS  = -drive file=$(1).img,format=raw,if=floppy -serial stdio -display none -monitor none

# 実行タイムアウト(秒)。環境変数 TIMEOUT_SECS が設定されていればその値を使用。
# (例: brainux 等の遅いエミュレーション環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1

# デバッグ/トレース用変数
# gdb-multiarch があれば優先し、なければ gdb を使用
GDB ?= $(shell command -v gdb-multiarch >/dev/null 2>&1 && echo gdb-multiarch || echo gdb)
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。ブート後は cli/hlt で CPU が停止するため、
# ログは停止時点で伸びなくなる(タイムアウトは QEMU プロセス回収用)。
TRACE_SECS ?= 10

# --- C シナリオ: リポジトリ root の common/c/c*.c を clang -m16 で build/x86_16/c*.s に
# 生成してから crt0.asm と一緒にアセンブル・リンクする (make debug S=c01 等)。
# UART 出力しない (main の戻り値は AX で確認) ため runall には含めない。
COMMON_C   = ../../../common/c
CSCENARIOS := $(notdir $(basename $(wildcard $(COMMON_C)/c*.c)))
# 生成 .s の出力先 (並行ビルドでの共通ファイル上書きを防ぐ)
CTAG       = x86_16
BUILD_C    = ../../../build/$(CTAG)
CC         = clang
# -m16: .code16 (16-bit real mode) のコードを生成。386 以降の命令を含むため
# QEMU 既定 CPU (qemu32) では動くが実 8086 では動かない (crt0.asm の注意参照)。
# -fno-asynchronous-unwind-tables: .eh_frame を出させない (orphan セクションが
# linker.ld の .text の前に置かれてイメージが壊れるため)
CFLAGS     = --target=i386-pc-none-elf -m16 -g -O0 -fno-asynchronous-unwind-tables

# 既定ターゲット (format 定義がファイル先頭にあるため明示指定)
.DEFAULT_GOAL := all

.PHONY: all run runall test dump dump32 debug trace cycles icount clean format build-c

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

all:
	@for name in $(SCENARIOS); do \
		echo "=== $$name ==="; \
		$(AS) $(ASFLAGS) -l $$name.lst -o $$name.o $$name.asm || exit 1; \
		$(LK) $(LKFLAGS) -o $$name.bin $$name.o || exit 1; \
		dd if=/dev/zero of=$$name.img bs=512 count=2880 2>/dev/null || exit 1; \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null || exit 1; \
		rm -f $$name.o || exit 1; \
		echo "  OK ($$(wc -c < $$name.bin) bytes)"; \
	done
	@for name in $(CSCENARIOS); do \
		$(MAKE) --no-print-directory build-c S=$$name || exit 1; \
	done

# C シナリオのビルド: make build-c S=c01
# clang -m16 (-g -O0) で build/x86_16/$(S).s を生成し crt0.asm とリンクする。
# .s は学習対象なので $(BUILD_C)/ に残す (make clean で削除)。
# ブート署名 (0xAA55 @ 510) はリンク後に Makefile 側で追記する (ELF リンクでは
# イメージ末尾位置が確定しないため)。510 バイト = 512 バイト - 署名 2 バイト。
build-c:
	@set -e; \
	echo "=== $(S) [C] ==="; \
	mkdir -p $(BUILD_C); \
	$(CC) $(CFLAGS) -S $(COMMON_C)/$(S).c -o $(BUILD_C)/$(S).s; \
	$(AS) $(ASFLAGS) -g -F dwarf -l crt0.lst -o crt0.o crt0.asm; \
	$(CC) --target=i386-pc-none-elf -m16 -c -o $(S).o $(BUILD_C)/$(S).s; \
	$(LK) $(LKFLAGS) -o $(S).bin crt0.o $(S).o; \
	$(LK) -m elf_i386 -T linker-debug.ld -o $(S).elf crt0.o $(S).o; \
	rm -f crt0.o $(S).o; \
	sz=$$(wc -c < $(S).bin | tr -d ' '); \
	if [ "$$sz" -gt 510 ]; then \
		echo "ERROR: $(S).bin が $$sz バイト (ブートセクタ上限 510 バイト)"; exit 1; \
	fi; \
	dd if=/dev/zero of=$(S).bin bs=1 seek=$$sz count=$$((510 - sz)) conv=notrunc 2>/dev/null; \
	printf '\125\252' >> $(S).bin; \
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null; \
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null; \
	echo "  OK ($$sz bytes)"

# Run: make run S=s01_hello  OR  make run S=s104_protected
run:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	elif echo "$(SCENARIOS)" | grep -qw "$(S)"; then \
	  $(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm && \
	  $(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
	  rm -f $(S).o; \
	else \
	  $(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi || exit 1
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none || true

# Run all scenarios through QEMU
runall: all
	@for name in $(SCENARIOS); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ] || [ "$$name" = "s12_minishell" ]; then \
			printf '%s\n' "$$( [ "$$name" = s12_minishell ] && echo quit || echo q )" | timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none; status=$$?; \
		else \
			timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none; status=$$?; \
		fi; \
		if [ $$status -ne 0 ] && [ $$status -ne 124 ]; then exit $$status; fi; \
		echo ""; \
	done

test: all
	python3 test_scenarios.py --qemu $(QEMU) --timeout $(TIMEOUT_SECS)

# Disassemble 16-bit code (single-sector examples)
dump:
	ndisasm -b 16 $(S).bin

# Disassemble 32-bit code starting at sector 2 (multi-sector examples)
dump32:
	ndisasm -b 32 -o 0x7E00 -e 512 $(S).bin

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp:127.0.0.1:PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb リモートプロトコルは認証を持たないため loopback (127.0.0.1) に限定する。
# gdb をフォアグラウンドで接続する。シリアル出力は gdb プロンプトに混ざって表示される。
# 接続後に 16bit 用ターゲット記述と Intel 構文を設定し、BIOS を飛ばして
# ブートセクタ先頭 (0x7C00) で break する。命令一覧には make dump も使える。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
debug:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	elif echo "$(SCENARIOS)" | grep -qw "$(S)"; then \
	  $(AS) $(ASFLAGS) -g -F dwarf -l $(S).lst \
        -o $(S).o $(S).asm && \
	  $(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
	  $(LK) -m elf_i386 -T linker-debug.ld \
        -o $(S).elf $(S).o && \
	  rm -f $(S).o; \
	else \
	  $(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi || exit 1
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@if nc -z 127.0.0.1 $(GDB_PORT) 2>/dev/null; then \
		echo "ERROR: ポート $(GDB_PORT) が使用中 (既存サーバーへの誤接続を防ぐため起動しません)"; exit 1; \
	fi
	@$(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -S -gdb tcp:127.0.0.1:$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null' EXIT INT TERM; \
	  i=0; while [ $$i -lt 50 ] && ! nc -z 127.0.0.1 $(GDB_PORT) 2>/dev/null; do \
	    if ! kill -0 $$QPID 2>/dev/null; then \
	      echo "ERROR: QEMU が gdbstub を開く前に終了した (起動失敗)"; exit 1; \
	    fi; \
	    sleep 0.1; i=$$((i+1)); done; \
	  if ! kill -0 $$QPID 2>/dev/null; then \
	    echo "ERROR: QEMU が終了している (gdbstub に接続できません)"; exit 1; \
	  fi; \
	  $(GDB) -q -tui $(S).elf \
	    -x debug.gdb \
	    -ex 'set pagination off' \
	    -ex 'target remote 127.0.0.1:$(GDB_PORT)' \
	    -ex 'set disassembly-flavor intel' \
	    -ex 'break *0x7c00' \
	    -ex 'continue' \
	    -ex 'set disassemble-next-line on' \
	    -ex 'layout src' \
	    -ex 'layout regs' \
	    -ex 'focus cmd' \
	    -ex 'printf "\n--- si: ステップ / c: continue / info registers / x/5i $$pc / regs16 / layout asm ---\n"'; status=$$?; \
	  kill $$QPID 2>/dev/null || true; exit $$status

# 実行トレース: make trace S=s01_hello
# one-insn-per-tb () で1TB=1命令とし、
# -d in_asm,cpu で命令ごとの逆アセンブルと CPU 状態を $(S).trace に記録して
# less で表示する。-dfilter でブートセクタ以降のコード領域 (0x7C00+) に限定し、
# BIOS (ROM 側) の命令を除外する。ブート後は cli/hlt で停止するためログは有限。
# ただし s06/s12 は入力が quits 条件に達しないと読み込みループから抜けないため、
# ログを head -c 32MB で打ち切る(QEMU は SIGPIPE を無視するため
# 打ち切り後も TRACE_SECS 秒まで QEMU は動き続ける)。
trace:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	elif echo "$(SCENARIOS)" | grep -qw "$(S)"; then \
	  $(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm && \
	  $(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
	  rm -f $(S).o; \
	else \
	  $(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi || exit 1
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ] || [ "$(S)" = "s12_minishell" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -accel tcg,one-insn-per-tb=on -d in_asm,cpu -dfilter 0x7c00+0x8000 2>&1 >/dev/null | head -c 33554432 > $(S).trace; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -accel tcg,one-insn-per-tb=on -d in_asm,cpu -dfilter 0x7c00+0x8000 2>&1 >/dev/null | head -c 33554432 > $(S).trace; \
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
# -dfilter でブートセクタ以降 (0x7C00+) に限定し BIOS 側の命令数を除外。
# ブート後は cli/hlt で CPU が停止するため halt スピンによる水増しは発生しない。
# ただし s06/s12 は入力が quits 条件に達しないと読み込みループから抜けないため、
# 集計対象のログを head -c 32MB で打ち切る(打ち切り後も TRACE_SECS 秒まで
# QEMU は動き続ける)。
icount:
	@if [ -f $(COMMON_C)/$(S).c ]; then \
	  $(MAKE) --no-print-directory build-c S=$(S); \
	elif echo "$(SCENARIOS)" | grep -qw "$(S)"; then \
	  $(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm && \
	  $(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
	  rm -f $(S).o; \
	else \
	  $(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi || exit 1
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	@rm -f $(S).trace
	@if [ "$(S)" = "s06_serial_in" ] || [ "$(S)" = "s12_minishell" ]; then \
		printf 'q\n' | timeout --foreground $(TRACE_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -accel tcg,one-insn-per-tb=on -d cpu -dfilter 0x7c00+0x8000 2>&1 >/dev/null | head -c 33554432 > $(S).trace; \
	else \
		timeout --foreground $(TRACE_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -accel tcg,one-insn-per-tb=on -d cpu -dfilter 0x7c00+0x8000 2>&1 >/dev/null | head -c 33554432 > $(S).trace; \
	fi
	@n=$$(grep -c '^EIP=' $(S).trace 2>/dev/null || true); \
	[ -n "$$n" ] || n=0; \
	echo "実行命令数: $$n (QEMU 実行命令数の実測 / BIOS部分は除外)"; \
	echo "詳細: $(S).trace"

clean:
	rm -f *.bin *.img *.o *.lst *.elf *.trace
	rm -rf $(BUILD_C)

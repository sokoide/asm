# --- シナリオ一覧: s*.asm から boot.asm を除いたものを自動検出 ---
# (シナリオファイル追加時に Makefile 編集は不要。sort で番号順を安定させる)
SCENARIOS := $(sort $(patsubst %.asm,%,$(filter-out boot.asm,$(wildcard s*.asm))))

AS       = nasm
# リンカ: x86_16 と同じく LLVM lld を使用 (ld.lld は elf_i386 と
# OUTPUT_FORMAT("binary") を扱える)
LK       = ld.lld
ASFLAGS  = -f elf32
LKFLAGS  = -m elf_i386 -T linker.ld
IMG_SECS = 2880                  # 1.44MB フロッピー = 512B x 2880 セクタ
BIN_MAX  = 33280                 # ロードイメージ上限 (0xFE00 - 0x7C00 = 65 セクタ)

QEMU        = qemu-system-i386
QFLAGS      = -machine pc -accel tcg -cpu 486 -no-reboot -no-shutdown
# trace / icount 用: 1 TB = 1 命令で実行し、命令単位のログを取る
# (-accel の二重指定は不可のため、tcg を one-insn-per-tb 付きに差し替える)
INSN_QFLAGS = -machine pc -accel tcg,one-insn-per-tb=on -cpu 486 -no-reboot -no-shutdown
# trace / icount のログをカーネル領域 (0x8000-) に限定する
# (-dfilter がないと SeaBIOS 部分も記録され、1 秒で数十万行になる)
DFILTER     = -dfilter 0x8000+0x7e00
# 実行タイムアウト(秒)。HLT 後も QEMU は終了しないため timeout で回収する。
# (例: 遅い環境では export TIMEOUT_SECS=10 等で延長)
TIMEOUT_SECS ?= 1
TIMEOUT      ?= timeout --foreground $(TIMEOUT_SECS)
# icount の HLT 到達待ち上限(秒)。シリアル出力が変動しなくなったら
# HLT ループに到達したとみなして回収する (完走)。
ICOUNT_SECS  ?= 5
GDB          ?= gdb
GDB_PORT     ?= 1234

.PHONY: all run runall test debug trace icount cycles dump clean

# 注意: all を先頭ターゲットにする (boot.o ルールは末尾に定義)
all: boot.o
	@set -e; \
	for name in $(SCENARIOS); do \
		echo "=== $$name ==="; \
		$(AS) $(ASFLAGS) -l $$name.lst -o $$name.o $$name.asm; \
		$(LK) $(LKFLAGS) -o $$name.bin boot.o $$name.o; \
		sz=$$(wc -c < $$name.bin | tr -d ' '); \
		if [ "$$sz" -gt $(BIN_MAX) ]; then \
			echo "ERROR: $$name.bin が $$sz バイト (上限 $(BIN_MAX) バイト)"; exit 1; \
		fi; \
		dd if=/dev/zero of=$$name.img bs=512 count=$(IMG_SECS) 2>/dev/null; \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null; \
		rm -f $$name.o; \
		echo "  OK ($$sz bytes)"; \
	done

# Run: make run S=s01_hello
run: boot.o
	@set -e; \
	$(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm; \
	$(LK) $(LKFLAGS) -o $(S).bin boot.o $(S).o; \
	sz=$$(wc -c < $(S).bin | tr -d ' '); \
	if [ "$$sz" -gt $(BIN_MAX) ]; then \
		echo "ERROR: $(S).bin が $$sz バイト (上限 $(BIN_MAX) バイト)"; exit 1; \
	fi; \
	dd if=/dev/zero of=$(S).img bs=512 count=$(IMG_SECS) 2>/dev/null; \
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null; \
	rm -f $(S).o
	@$(TIMEOUT) $(QEMU) $(QFLAGS) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none; status=$$?; \
	if [ $$status -ne 0 ] && [ $$status -ne 124 ]; then exit $$status; fi

test: all
	python3 test_scenarios.py --qemu $(QEMU) --timeout $(TIMEOUT_SECS)

# 全シナリオを連続実行: make runall
# s06/s12 は対話シナリオのため runall / trace と同じ入力を与える。
# HLT 後も QEMU は終了しないため timeout で回収し、終了コード 0/124 を正常とする。
runall: all
	@for name in $(SCENARIOS); do \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | $(TIMEOUT) $(QEMU) $(QFLAGS) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none 2>/dev/null; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | $(TIMEOUT) $(QEMU) $(QFLAGS) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none 2>/dev/null; \
		else \
			$(TIMEOUT) $(QEMU) $(QFLAGS) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none 2>/dev/null; \
		fi; \
		status=$$?; \
		if [ $$status -ne 0 ] && [ $$status -ne 124 ]; then exit $$status; fi; \
		echo ""; \
	done

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp:127.0.0.1:PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb をフォアグラウンドで接続する。gdb リモートプロトコルに認証はないため
# 待ち受けは loopback (127.0.0.1) に限定する。
# マクロは debug.gdb に定義し -x で明示ロードする (.gdbinit 自動ロードは使わない)。
# 接続はリセット直後に行われるため、INT 13h のロード後にメモリが書き換わる
# ソフトウェアブレークは使えない。hbreak (ハードウェアブレーク) で
# 0x8000 の _start で止める。
debug: boot.o
	@set -e; \
	$(AS) $(ASFLAGS) -g -F dwarf -l $(S).lst -o $(S).o $(S).asm; \
	$(LK) $(LKFLAGS) -o $(S).bin boot.o $(S).o; \
	$(LK) -m elf_i386 -T linker-debug.ld -o $(S).elf boot.o $(S).o; \
	sz=$$(wc -c < $(S).bin | tr -d ' '); \
	if [ "$$sz" -gt $(BIN_MAX) ]; then \
		echo "ERROR: $(S).bin が $$sz バイト (上限 $(BIN_MAX) バイト)"; exit 1; \
	fi; \
	dd if=/dev/zero of=$(S).img bs=512 count=$(IMG_SECS) 2>/dev/null; \
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null; \
	rm -f $(S).o
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@$(QEMU) $(QFLAGS) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -S -gdb tcp:127.0.0.1:$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null' EXIT INT TERM; \
	  sleep 0.3; \
	  $(GDB) -q $(S).elf \
	    -x debug.gdb \
	    -ex 'set pagination off' \
	    -ex 'target remote 127.0.0.1:$(GDB_PORT)' \
	    -ex 'hbreak *_start' \
	    -ex 'continue' \
	    -ex 'set disassembly-flavor intel' \
	    -ex 'set disassemble-next-line on'; status=$$?; \
	  kill $$QPID 2>/dev/null || true; exit $$status

# 実行トレース: make trace S=s04_loops
# one-insn-per-tb で 1 命令ごとに逆アセンブル + CPU 状態を記録する。
# -dfilter でカーネル領域のみ記録 (BIOS 部分は対象外)。ログ上限は 32MB。
# 対話シナリオは runall と同じ入力を与える。
TRACE_SECS ?= 10
TRACE_MAX_BYTES ?= 33554432
trace: all
	@$(AS) $(ASFLAGS) -o $(S).o $(S).asm
	@$(LK) -m elf_i386 -T linker-debug.ld -o $(S).elf boot.o $(S).o
	@rm -f $(S).o
	@python3 trace_scenario.py --qemu $(QEMU) --scenario $(S) --timeout $(TRACE_SECS) --max-bytes $(TRACE_MAX_BYTES)
	@if [ -t 1 ]; then less $(S).trace; else cat $(S).trace; fi

# 実行命令数: 終了位置の EIP を検出し、それ以前の命令だけを集計する。
icount: all
	@$(AS) $(ASFLAGS) -o $(S).o $(S).asm
	@$(LK) -m elf_i386 -T linker-debug.ld -o $(S).elf boot.o $(S).o
	@rm -f $(S).o
	@python3 count_instructions.py --qemu $(QEMU) --scenario $(S) --timeout $(ICOUNT_SECS)

# 実サイクル数: make cycles S=s01_loops → unsupported
# QEMU TCG はサイクル精度のエミュレーションではないため実サイクル数は計測不可。
cycles:
	@echo "unsupported: QEMU TCG はサイクル非対応のため実サイクル数は計測できません (実行命令数は make icount)"

# 逆アセンブル: make dump S=s01_hello
# シナリオ本体 (0x8000〜) を 32-bit で逆アセンブルする。
# ブートセクタ + 移行スタブ (先頭 1024 バイト) は 16-bit / 32-bit 混在のため
# 対象外。観察する場合は ndisasm -b 16 -o 0x7C00 (ブート) / -b 32 -o 0x7E00 (スタブ) を使う。
dump:
	@set -e; \
	$(MAKE) --no-print-directory all; \
	ndisasm -b 32 -o 0x8000 -e 1024 $(S).bin

clean:
	rm -f *.bin *.img *.o *.lst *.elf *.trace *.icount.trace

# boot.o は全シナリオで共通のブートセクタ + 移行スタブ
boot.o: boot.asm
	$(AS) $(ASFLAGS) -l boot.lst -o boot.o boot.asm

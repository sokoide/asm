# --- Single-sector examples (ELF32 + linker, 512 bytes) ---
SINGLE = s01_hello s02_registers s03_stack s04_loops \
         s05_strings s06_serial_in s07_subroutines s08_hardware \
         s09_branching s10_bitwise s11_memory s12_minishell

# --- Multi-sector examples (flat binary, -f bin) ---
MULTI = s13_multisector s14_protected

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
GDB        ?= gdb
GDB_PORT   ?= 1234
# trace/cycles 用タイムアウト(秒)。ブート後は cli/hlt で CPU が停止するため、
# ログは停止時点で伸びなくなる(タイムアウトは QEMU プロセス回収用)。
TRACE_SECS ?= 10

.PHONY: all run runall dump dump32 debug trace cycles clean

all:
	@for name in $(SINGLE); do \
		echo "=== $$name [1 sector] ==="; \
		$(AS) $(ASFLAGS) -l $$name.lst -o $$name.o $$name.asm && \
		$(LK) $(LKFLAGS) -o $$name.bin $$name.o && \
		dd if=/dev/zero of=$$name.img bs=512 count=2880 2>/dev/null && \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null && \
		rm -f $$name.o && \
		echo "  OK ($$(wc -c < $$name.bin) bytes)"; \
	done
	@for name in $(MULTI); do \
		echo "=== $$name [multi] ==="; \
		$(AS) -f bin -l $$name.lst -o $$name.bin $$name.asm && \
		dd if=/dev/zero of=$$name.img bs=512 count=2880 2>/dev/null && \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null && \
		echo "  OK ($$(wc -c < $$name.bin) bytes)"; \
	done

# Run: make run S=s01_hello  OR  make run S=s14_protected
run:
	@echo "$(SINGLE)" | grep -qw "$(S)" && MODE=single || MODE=multi; \
	if [ "$$MODE" = "single" ]; then \
		$(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm && \
		$(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
		rm -f $(S).o; \
	else \
		$(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none || true

# Run all scenarios through QEMU
runall: all
	@for name in $(SINGLE) $(MULTI); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ] || [ "$$name" = "s12_minishell" ]; then \
			printf 'q\n' | timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none 2>/dev/null || true; \
		else \
			timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$$name.img,format=raw,if=floppy -serial stdio -display none -monitor none 2>/dev/null || true; \
		fi; \
		echo ""; \
	done

# Disassemble 16-bit code (single-sector examples)
dump:
	ndisasm -b 16 $(S).bin

# Disassemble 32-bit code starting at sector 2 (multi-sector examples)
dump32:
	ndisasm -b 32 -o 0x7E00 -e 512 $(S).bin

# ステップデバッガ: make debug S=s01_hello
# QEMU を -S -gdb tcp::PORT (起動時停止 + gdbstub) でバックグラウンド起動し、
# gdb をフォアグラウンドで接続する。シリアル出力は gdb プロンプトに混ざって表示される。
# ELF/シンボルが無いため set architecture i8086 を明示し、BIOS を飛ばして
# ブートセクタ先頭 (0x7C00) で break する。
# 注意: QEMU の gdbstub は常に 32bit (i386) のターゲット記述を返すため、gdb の
# 逆アセンブル表示はレジスタ名が 32bit 表記 (eax/esp 等) になり、即値を持つ
# 命令の「表示」が後続行でずれることがある。si 実行後の PC は常に命令境界なので
# x/5i $pc の再実行で先頭行は常に正しく表示される。正確な 16bit リストは make dump (ndisasm) を併用。
# gdb: si=1命令実行 / c=continue / b *ADDR / info registers / x/5i $pc / Ctrl-D で終了
debug:
	@echo "$(SINGLE)" | grep -qw "$(S)" && MODE=single || MODE=multi; \
	if [ "$$MODE" = "single" ]; then \
		$(AS) $(ASFLAGS) -l $(S).lst -o $(S).o $(S).asm && \
		$(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
		rm -f $(S).o; \
	else \
		$(AS) -f bin -l $(S).lst -o $(S).bin $(S).asm; \
	fi || exit 1
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	@command -v $(GDB) >/dev/null 2>&1 || { echo "gdb が見つかりません: brew install gdb"; exit 1; }
	@$(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none -S -gdb tcp::$(GDB_PORT) & \
	  QPID=$$!; \
	  trap 'kill $$QPID 2>/dev/null' EXIT INT TERM; \
	  sleep 0.3; \
	  $(GDB) -q \
	    -ex 'set pagination off' \
	    -ex 'set architecture i8086' \
	    -ex 'target remote :$(GDB_PORT)' \
	    -ex 'break *0x7c00' \
	    -ex 'continue' \
	    -ex 'set disassemble-next-line on' \
	    -ex 'printf "\n--- si: ステップ / c: continue / info registers / x/5i $$pc (表示がずれたら PC から再実行 / 16bitリストは make dump) ---\n"'; \
	  kill $$QPID 2>/dev/null || true

# 実行トレース: make trace S=s01_hello
# one-insn-per-tb (旧 -singlestep、QEMU 8.1 で置換) で1TB=1命令とし、
# -d in_asm,cpu で命令ごとの逆アセンブルと CPU 状態を $(S).trace に記録して
# less で表示する。-dfilter でブートセクタ以降のコード領域 (0x7C00+) に限定し、
# BIOS (ROM 側) の命令を除外する。ブート後は cli/hlt で停止するためログは有限。
# ただし s06/s12 は入力が quits 条件に達しないと読み込みループから抜けないため、
# ログを head -c 32MB で打ち切る(QEMU は SIGPIPE を無視するため
# 打ち切り後も TRACE_SECS 秒まで QEMU は動き続ける)。
trace:
	@echo "$(SINGLE)" | grep -qw "$(S)" && MODE=single || MODE=multi; \
	if [ "$$MODE" = "single" ]; then \
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

# 実行命令数: make cycles S=s01_hello
# 注意: QEMU TCG はサイクル精度のエミュレーションでないため、CPUサイクル数では
# なく実行命令数を報告する。one-insn-per-tb で命令ごとに CPU 状態ダンプ
# (-d cpu) が記録されるので、その行数=実行命令数(ループ反復を含む正確な値)。
# -dfilter でブートセクタ以降 (0x7C00+) に限定し BIOS 側の命令数を除外。
# ブート後は cli/hlt で CPU が停止するため halt スピンによる水増しは発生しない。
# ただし s06/s12 は入力が quits 条件に達しないと読み込みループから抜けないため、
# 集計対象のログを head -c 32MB で打ち切る(打ち切り後も TRACE_SECS 秒まで
# QEMU は動き続ける)。
cycles:
	@echo "$(SINGLE)" | grep -qw "$(S)" && MODE=single || MODE=multi; \
	if [ "$$MODE" = "single" ]; then \
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
	echo "実行命令数: $$n (QEMU TCG はサイクル非対応のため命令数で代替 / BIOS部分は除外)"; \
	echo "詳細: $(S).trace"

clean:
	rm -f *.bin *.img *.o *.lst *.trace

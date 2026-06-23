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

# エミュレータ切替: qemu(既定) | bochs
# brainux(ARMv5, PXA270) は QEMU の TCG が ARMv5 非対応で起動時に
# "TCG: ARMv5 is unsupported; exiting" となるため、pure interpreter の Bochs を使用:
#   make run S=s01_hello EMULATOR=bochs
EMULATOR ?= qemu

# Bochs 用 BIOS / VGA-BIOS パス(ディストリ依存、存在する候補を優先)
BOCHS_BIOS    = $(firstword $(wildcard /usr/share/bochs/BIOS-bochs-latest /usr/share/bochs/BIOS-bochs-legacy /usr/share/seabios/bios.bin))
BOCHS_VGABIOS = $(firstword $(wildcard /usr/share/bochs/VGABIOS-lgpl-latest /usr/share/seabios/vgabios.bin))
# Bochs 設定ファイルテンプレート(printf の %s に <name>, <name> を埋める)
BOCHSRC_TPL = megs: 32\ndisplay_library: dummy\nromimage: file=$(BOCHS_BIOS)\nvgaromimage: file=$(BOCHS_VGABIOS)\nfloppya: 1_44=%s.img, status=inserted\nboot: floppy\ncom1: enabled=1, mode=file, dev=.bochs_serial.%s.out\nclock: sync=none\n

.PHONY: all run runall dump dump32 clean

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
	@if [ "$(EMULATOR)" = "bochs" ]; then \
		printf '$(BOCHSRC_TPL)' $(S) $(S) > .bochsrc.$(S); \
		rm -f .bochs_serial.$(S).out; \
		timeout --foreground $(TIMEOUT_SECS) bochs -q -f .bochsrc.$(S) 2>/dev/null || true; \
		cat .bochs_serial.$(S).out 2>/dev/null; \
	else \
		timeout --foreground $(TIMEOUT_SECS) $(QEMU) -drive file=$(S).img,format=raw,if=floppy -serial stdio -display none -monitor none || true; \
	fi

# Run all scenarios through QEMU
runall: all
	@for name in $(SINGLE) $(MULTI); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$(EMULATOR)" = "bochs" ]; then \
			printf '$(BOCHSRC_TPL)' $$name $$name > .bochsrc.$$name; \
			rm -f .bochs_serial.$$name.out; \
			timeout --foreground $(TIMEOUT_SECS) bochs -q -f .bochsrc.$$name 2>/dev/null || true; \
			cat .bochs_serial.$$name.out 2>/dev/null; \
		elif [ "$$name" = "s06_serial_in" ] || [ "$$name" = "s12_minishell" ]; then \
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

clean:
	rm -f *.bin *.img *.o *.lst .bochsrc.* .bochs_serial.*

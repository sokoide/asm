# --- Single-sector examples (ELF32 + linker, 512 bytes) ---
SINGLE = s01_hello s02_registers s03_stack s04_loops \
         s05_strings s06_keyboard s07_subroutines s08_vram \
         s09_branching s10_bitwise s11_memory s12_minishell

# --- Multi-sector examples (flat binary, -f bin) ---
MULTI = s13_multisector s14_protected

AS      = nasm
LK      = $(shell command -v x86_64-elf-ld 2>/dev/null || command -v x86_64-linux-gnu-ld 2>/dev/null || echo ld)
ASFLAGS = -f elf32
LKFLAGS = -m elf_i386 -T linker.ld

.PHONY: all run dump dump32 clean

all:
	@for name in $(SINGLE); do \
		echo "=== $$name [1 sector] ==="; \
		$(AS) $(ASFLAGS) -o $$name.o $$name.asm && \
		$(LK) $(LKFLAGS) -o $$name.bin $$name.o && \
		dd if=/dev/zero of=$$name.img bs=512 count=2880 2>/dev/null && \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null && \
		rm -f $$name.o && \
		echo "  OK ($$(wc -c < $$name.bin) bytes)"; \
	done
	@for name in $(MULTI); do \
		echo "=== $$name [multi] ==="; \
		$(AS) -f bin -o $$name.bin $$name.asm && \
		dd if=/dev/zero of=$$name.img bs=512 count=2880 2>/dev/null && \
		dd if=$$name.bin of=$$name.img conv=notrunc 2>/dev/null && \
		echo "  OK ($$(wc -c < $$name.bin) bytes)"; \
	done

# Run: make run S=s01_hello  OR  make run S=s14_protected
run:
	@echo "$(SINGLE)" | grep -qw "$(S)" && MODE=single || MODE=multi; \
	if [ "$$MODE" = "single" ]; then \
		$(AS) $(ASFLAGS) -o $(S).o $(S).asm && \
		$(LK) $(LKFLAGS) -o $(S).bin $(S).o && \
		rm -f $(S).o; \
	else \
		$(AS) -f bin -o $(S).bin $(S).asm; \
	fi
	dd if=/dev/zero of=$(S).img bs=512 count=2880 2>/dev/null
	dd if=$(S).bin of=$(S).img conv=notrunc 2>/dev/null
	qemu-system-i386 -drive file=$(S).img,format=raw,if=floppy -nographic

# Disassemble 16-bit code (single-sector examples)
dump:
	ndisasm -b 16 $(S).bin

# Disassemble 32-bit code starting at sector 2 (multi-sector examples)
dump32:
	ndisasm -b 32 -o 0x7E00 -e 512 $(S).bin

clean:
	rm -f *.bin *.img *.o

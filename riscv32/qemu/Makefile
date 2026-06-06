# RISC-V 32-bit bare-metal assembly for QEMU virt machine
# Toolchain: Clang (--target=riscv32-unknown-elf)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell

AS      = clang
LD      = ld.lld
ASFLAGS = --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib

QEMU    = qemu-system-riscv32
QFLAGS  = -machine virt -nographic -bios none

.PHONY: all run runall dump clean

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
	timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $(S).elf || true

# Run all scenarios through QEMU
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		else \
			$(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		fi; \
		echo ""; \
	done

# Disassemble
dump:
	llvm-objdump -d $(S).elf

clean:
	rm -f *.elf *.o *.bin

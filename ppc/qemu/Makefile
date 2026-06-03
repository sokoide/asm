# PPC bare-metal assembly for QEMU bamboo machine
# Toolchain: Clang (--target=powerpc-none-elf)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell

AS      = clang
LD      = ld.lld
ASFLAGS = --target=powerpc-none-elf -c -nostdlib
LDFLAGS = -T linker.ld -nostdlib

QEMU    = qemu-system-ppc
QFLAGS  = -machine bamboo -nographic

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

# Run all scenarios through QEMU (PPC uses infinite-loop halt, timeout required)
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf || true; \
		echo ""; \
	done

# Disassemble
dump:
	llvm-objdump -d $(S).elf

clean:
	rm -f *.elf *.o *.bin

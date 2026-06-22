# m68k bare-metal assembly for QEMU virt machine
# Toolchain: m68k-elf-* (macOS: brew install m68k-elf-gcc)
#            m68k-linux-gnu-* (Linux: apt install gcc-m68k-linux-gnu)
# Goldfish TTY at 0xff008000

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell

AS      = $(shell which m68k-elf-as m68k-linux-gnu-as 2>/dev/null | head -1)
LD      = $(shell which m68k-elf-ld m68k-linux-gnu-ld 2>/dev/null | head -1)
OD      = $(shell which m68k-elf-objdump m68k-linux-gnu-objdump 2>/dev/null | head -1)
ASFLAGS = -m68000
LDFLAGS = -T linker.ld

QEMU    = qemu-system-m68k
QFLAGS  = -M virt -cpu m68000 -nographic

.PHONY: all run runall dump clean

all:
	@for name in $(SOURCES); do \
		echo "=== $$name ==="; \
		$(AS) $(ASFLAGS) -al=$$name.lst -o $$name.o $$name.s && \
		$(LD) $(LDFLAGS) -o $$name.elf $$name.o && \
		rm -f $$name.o && \
		echo "  OK"; \
	done

# Run: make run S=s01_hello
run:
	$(AS) $(ASFLAGS) -al=$(S).lst -o $(S).o $(S).s
	$(LD) $(LDFLAGS) -o $(S).elf $(S).o
	rm -f $(S).o
	timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $(S).elf || true

# Run all scenarios (m68k uses infinite-loop halt, timeout required)
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		elif [ "$$name" = "s12_minishell" ]; then \
			printf 'help\nquit\n' | timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		else \
			timeout --foreground 1 $(QEMU) $(QFLAGS) -kernel $$name.elf 2>/dev/null || true; \
		fi; \
		echo ""; \
	done

# Disassemble
dump:
	$(OD) -d $(S).elf

clean:
	rm -f *.elf *.o *.lst

# Z80 assembly for simz80 simulator (CP/M BDOS calling convention)
# Toolchain: z80asm + simz80 (Go)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell s13_shadow

AS      = z80asm
SIM     = ./simz80
TIMEOUT = timeout --foreground 1

.PHONY: all run runall dump clean

all:
	@for name in $(SOURCES); do \
		echo "=== $$name ==="; \
		$(AS) -o $$name.com $$name.asm && \
		echo "  OK ($$(wc -c < $$name.com) bytes)"; \
	done

# Run: make run S=s01_hello
run:
	$(AS) -o $(S).com $(S).asm
	$(TIMEOUT) $(SIM) $(S).com

# Run all scenarios (timeout 1s to prevent hangs)
runall: all
	@for name in $(SOURCES); do \
		echo ""; \
		echo "=== $$name ==="; \
		if [ "$$name" = "s06_serial_in" ] || [ "$$name" = "s12_minishell" ]; then \
			$(TIMEOUT) $(SIM) $$name.com 'quit' || true; \
		else \
			$(TIMEOUT) $(SIM) $$name.com || true; \
		fi; \
		echo ""; \
	done

# Disassemble (hex dump)
dump:
	hexdump -C $(S).com

clean:
	rm -f *.com *.bin *.sym *.lis *.err

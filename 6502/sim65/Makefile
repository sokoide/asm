SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_serial_in s07_subroutines s08_hardware \
            s09_branching s10_bitwise s11_memory s12_interactive

HELPERS = helpers.s

.PHONY: all run runall clean

all:
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		cl65 -t sim6502 -o $$s $$s.s $(HELPERS) && echo "  OK" || echo "  FAIL"; \
	done

run:
	cl65 -t sim6502 -o $(S) $(S).s $(HELPERS)
	sim65 $(S)

runall: all
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		if [ "$$s" = "s12_interactive" ]; then \
			printf 'help\nquit\n' | timeout --foreground 1 sim65 $$s 2>/dev/null || true; \
		elif [ "$$s" = "s06_serial_in" ]; then \
			printf 'q\n' | timeout --foreground 1 sim65 $$s 2>/dev/null || true; \
		else \
			timeout --foreground 1 sim65 $$s 2>/dev/null || true; \
		fi; \
		echo ""; \
	done

clean:
	rm -f $(SCENARIOS)

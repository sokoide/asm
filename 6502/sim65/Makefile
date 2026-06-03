SCENARIOS = s01_hello s02_registers s03_arithmetic s04_stack \
            s05_loops s06_addressing s07_subroutines s08_zeropage \
            s09_bitwise s10_memory s11_strings s12_interactive

.PHONY: all run runall clean

all:
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		cl65 -t sim6502 -o $$s $$s.s && echo "  OK" || echo "  FAIL"; \
	done

run:
	cl65 -t sim6502 -o $(S) $(S).s
	sim65 $(S)

runall: all
	@for s in $(SCENARIOS); do \
		echo "=== $$s ==="; \
		if [ "$$s" = "s12_interactive" ]; then \
			printf 'help\nquit\n' | timeout --foreground 3 sim65 $$s 2>/dev/null || true; \
		else \
			sim65 $$s; \
		fi; \
		echo ""; \
	done

clean:
	rm -f $(SCENARIOS)

SCENARIOS = s01_hello s02_registers s03_stack s04_loops \
            s05_strings s06_keyboard s07_subroutines s08_vram \
            s09_branching s10_bitwise s11_memory s12_minishell \
            s13_fileio s14_psp

AS      = nasm
LK      = alink
ASFLAGS = -f obj
LKFLAGS = -m -oEXE

.PHONY: all run dump clean

all:
	@for name in $(SCENARIOS); do \
		echo "=== $$name ==="; \
		$(AS) $(ASFLAGS) -o $$name.o $$name.asm && \
		$(LK) $(LKFLAGS) -o $$name.exe $$name.o && \
		rm -f $$name.o && \
		echo "  OK ($$(wc -c < $$name.exe) bytes)"; \
	done

# Run: make run S=s01_hello
run:
	$(AS) $(ASFLAGS) -o $(S).o $(S).asm
	$(LK) $(LKFLAGS) -o $(S).exe $(S).o
	rm -f $(S).o
	dosbox -c "MOUNT C ." -c "C:" -c "$(S).exe" -c "EXIT"

# Disassemble (skip 512-byte EXE header)
dump:
	ndisasm -b 16 -e 512 $(S).exe

clean:
	rm -f *.exe *.o *.map

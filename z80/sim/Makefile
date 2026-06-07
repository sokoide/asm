# Z80 assembly for simz80 simulator (CP/M BDOS calling convention)
# Toolchain: z80asm + simz80 (Go)

SOURCES = s01_hello s02_registers s03_stack s04_loops \
          s05_strings s06_serial_in s07_subroutines s08_hardware \
          s09_branching s10_bitwise s11_memory s12_minishell s13_shadow

AS      = z80asm
SIM     = ./simz80
TIMEOUT = timeout --foreground 1
GODIR   = cmd/simz80

CPMDIR   = cpm
YAZERC   = $(HOME)/cpm/.yazerc
CPMPATH  = $(abspath $(CPMDIR))
YAZEDISK = $(or $(wildcard /usr/local/lib/yaze/disks),$(wildcard /usr/share/yaze-ag/disks))

# CP/M 8.3 filename mapping (name must be ≤8 chars)
CPM_NAMES = s01_hello=S01HELLO s02_registers=S02REGS s03_stack=S03STACK \
            s04_loops=S04LOOPS s05_strings=S05STRS s06_serial_in=S06SERIN \
            s07_subroutines=S07SUBS s08_hardware=S08HARD s09_branching=S09BRNCH \
            s10_bitwise=S10BITS s11_memory=S11MEM s12_minishell=S12MSHL \
            s13_shadow=S13SHAD

.PHONY: all run runall dump cpm cpm-setup clean

all: $(SIM)
	@for name in $(SOURCES); do \
		echo "=== $$name ==="; \
		$(AS) -o $$name.com $$name.asm && \
		echo "  OK ($$(wc -c < $$name.com) bytes)"; \
	done

$(SIM): $(GODIR)/main.go $(GODIR)/go.mod
	cd $(GODIR) && go build -o ../../simz80 .

# Run: make run S=s01_hello
run: $(SIM)
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

# Build CP/M-compatible copies (8.3 filenames) for yaze-ag
cpm: all
	@rm -rf $(CPMDIR)
	@mkdir -p $(CPMDIR)
	@for mapping in $(CPM_NAMES); do \
		name=$${mapping%%=*}; \
		cpmname=$${mapping##*=}; \
		cp $$name.com $(CPMDIR)/$$cpmname.com; \
	done
	@echo "CP/M files ready in $(CPMDIR)/"
	@# Ensure .ydsk files exist in ~/cpm/ for yaze-ag
	@if [ -n "$(YAZEDISK)" ] && [ -d "$(YAZEDISK)" ]; then \
		changed=0; \
		for ydsk in $(YAZEDISK)/*.ydsk; do \
			base=$$(basename $$ydsk); \
			if [ ! -f $(HOME)/cpm/$$base ]; then \
				cp $$ydsk $(HOME)/cpm/; \
				changed=1; \
				echo "Copied $$base -> $(HOME)/cpm/"; \
			fi; \
		done; \
		if [ "$$changed" -eq 0 ]; then \
			echo "~/cpm/ disk images OK"; \
		fi; \
	fi
	@# Update .yazerc: add/update mount c line before 'go'
	@if [ -f $(YAZERC) ]; then \
		awk 'BEGIN{m=0} /^mount c /{print "mount c $(CPMPATH)";m=1;next} /^go$$/{if(!m){print "mount c $(CPMPATH)"}m=1} {print}' $(YAZERC) > $(YAZERC).tmp && mv $(YAZERC).tmp $(YAZERC); \
		echo "Updated $(YAZERC)"; \
	else \
		mkdir -p $$(dirname $(YAZERC)); \
		printf 'mount c $(CPMPATH)\ngo\n' > $(YAZERC); \
		echo "Created $(YAZERC)"; \
	fi

clean:
	rm -f *.com *.bin *.sym *.lis *.err $(SIM)
	rm -rf $(CPMDIR)

# One-time setup: copy yaze-ag disk images to ~/cpm/
cpm-setup:
	@if [ -n "$(YAZEDISK)" ] && [ -d "$(YAZEDISK)" ]; then \
		mkdir -p $(HOME)/cpm; \
		for ydsk in $(YAZEDISK)/*.ydsk; do \
			cp -n $$ydsk $(HOME)/cpm/; \
		done; \
		echo "Copied disk images to $(HOME)/cpm/"; \
	else \
		echo "yaze-ag disk images not found (expected at /usr/local/lib/yaze/disks/)"; \
		echo "Install yaze-ag first: https://github.com/andreasgerlich/yaze-ag"; \
	fi

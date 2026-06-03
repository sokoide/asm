TARGET = hello
SRC    = hello.s

.PHONY: run clean

run: $(TARGET)
	sim65 $(TARGET)

$(TARGET): $(SRC)
	cl65 -t sim6502 -o $@ $<

clean:
	rm -f $(TARGET)

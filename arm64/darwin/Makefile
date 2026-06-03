TARGET = hello
CC = clang

all: $(TARGET)

$(TARGET): hello.o
	ld -e _main -arch arm64 -syslibroot $(shell xcrun --show-sdk-path) -lSystem -o $@ $<

hello.o: hello.asm
	$(CC) -c -arch arm64 -x assembler hello.asm -o $@

clean:
	rm -f $(TARGET) hello.o

.PHONY: all clean

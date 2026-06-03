TARGET = hello

all: $(TARGET)

$(TARGET): hello.o
	ld -e _main -arch i386 -lSystem -o $@ $<

hello.o: hello.asm
	nasm -f macho32 -o $@ $<

clean:
	rm -f $(TARGET) hello.o

.PHONY: all clean

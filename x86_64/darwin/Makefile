TARGET = hello

all: $(TARGET)

$(TARGET): hello.o
	ld -e _main -arch x86_64 -lSystem -o $@ $<

hello.o: hello.asm
	nasm -f macho64 -o $@ $<

clean:
	rm -f $(TARGET) hello.o

.PHONY: all clean

TARGET=hoge
SRCS=hoge.asm\

OBJS = $(SRCS:.asm=.o)

all: $(TARGET)

run : all
	./$(TARGET)

$(TARGET): $(OBJS)
	ld -e _main -macosx_version_min 10.12 -arch x86_64 -lSystem -o $(TARGET) $<

%.o: %.asm
	nasm -f macho64 -o $@ $<

clean:
	rm *.o $(TARGET)




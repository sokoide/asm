PROJECT_NAME	= hello
BINARY = hello

TARGET = hello.com
SRCS = hello.asm
AS = nasm
ASFLAGS = -f bin
INSTALLDIR = ~/tmp

.PHONY: install dump clean

install: $(TARGET)
	mv $(TARGET) $(INSTALLDIR)

$(TARGET): $(SRCS)
	$(AS) -f bin $< -o $@

dump: $(TARGET)
	ndisasm -b 16 $(TARGET)

clean:
	rm -rf $(INSTALLDIR)/$(TARGET)

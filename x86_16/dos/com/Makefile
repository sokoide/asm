PROJECT	= hello
TARGET	= $(PROJECT).com
SRCS	= hello.asm

AS      = nasm
ASFLAGS = -f bin

.PHONY: all run dump clean

# ビルド（他アーキテクチャと同じくカレントディレクトリに成果物を置く）
all: $(TARGET)

$(TARGET): $(SRCS)
	$(AS) $(ASFLAGS) $< -o $@

# DOSBox で実行
run: $(TARGET)
	dosbox -c "MOUNT C ." -c "C:" -c "$(TARGET)" -c "EXIT"

# 逆アセンブル
dump: $(TARGET)
	ndisasm -b 16 $(TARGET)

clean:
	rm -f $(TARGET)

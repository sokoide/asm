PROJECT	= hello
TARGET	= $(PROJECT).com
SRCS	= hello.asm

AS      = nasm
ASFLAGS = -f bin

.PHONY: all run dump clean format

# アセンブリソースを nvim の保存時整形と同一ロジックで整形
# （asm.lua の autocmd を headless nvim で再実行 = :w と同じ整形。
#   設定の場所はリポジトリ root README の「コード整形 (make format)」参照）
ASM_SRC := $(wildcard *.s) $(wildcard *.asm)
ASM_LUA ?= $(HOME)/.config/nvim/lua/config/asm.lua
format:
	@command -v nvim >/dev/null 2>&1 || { echo "nvim がありません"; exit 1; }
	@test -f "$(ASM_LUA)" || { echo "整形設定 asm.lua がありません: $(ASM_LUA)"; exit 1; }
	@test -n "$(ASM_SRC)" || { echo "format: 対象の .s/.asm がありません"; exit 0; }
	@for f in $(ASM_SRC); do \
	  nvim --headless --clean +"luafile $(ASM_LUA)" +"e $$f" +w +qa! || { echo "format 失敗: $$f"; exit 1; }; \
	done

# ビルド（他アーキテクチャと同じくカレントディレクトリに成果物を置く）
all: $(TARGET)

$(TARGET): $(SRCS)
	$(AS) $(ASFLAGS) $< -o $@

# DOSBox で実行
run: $(TARGET)
	dosbox-x -c "MOUNT C ." -c "C:" -c "$(TARGET)" -c "EXIT"

# 逆アセンブル
dump: $(TARGET)
	ndisasm -b 16 $(TARGET)

clean:
	rm -f $(TARGET)

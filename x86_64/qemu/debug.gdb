# debug.gdb - gdb マクロ定義
# マクロは make debug / 手動起動時に -x debug.gdb で明示ロードする。
# (.gdbinit の自動ロードは auto-load safe-path 設定への依存を避けるため使わない)

set architecture i386:x86-64
set disassembly-flavor intel

# 注意: QEMU の gdbstub は $rflags を提供しないため $eflags (unsigned int) を使う。
# RFLAGS の上位 32 ビットは予約 (0) で、CF/PF/AF/ZF/SF/OF は下位 32 ビットにある。

define hook-stop
    regs64
end

define regs64
    printf "RAX=%016lx RBX=%016lx RCX=%016lx RDX=%016lx\n", (unsigned long)$rax, (unsigned long)$rbx, (unsigned long)$rcx, (unsigned long)$rdx
    printf "RSI=%016lx RDI=%016lx RBP=%016lx RSP=%016lx\n", (unsigned long)$rsi, (unsigned long)$rdi, (unsigned long)$rbp, (unsigned long)$rsp
    printf "CS=%04x DS=%04x ES=%04x SS=%04x FS=%04x GS=%04x\n", (unsigned int)$cs, (unsigned int)$ds, (unsigned int)$es, (unsigned int)$ss, (unsigned int)$fs, (unsigned int)$gs
    printf "RIP=%016lx EFLAGS=%08x\n", (unsigned long)$rip, (unsigned int)$eflags
    printf "CF=%d PF=%d AF=%d ZF=%d SF=%d OF=%d\n", \
    ((unsigned int)$eflags >> 0) & 1, \
    ((unsigned int)$eflags >> 2) & 1, \
    ((unsigned int)$eflags >> 4) & 1, \
    ((unsigned int)$eflags >> 6) & 1, \
    ((unsigned int)$eflags >> 7) & 1, \
    ((unsigned int)$eflags >> 11) & 1
end

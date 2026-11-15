# debug.gdb - gdb マクロ定義
# マクロは make debug / 手動起動時に -x debug.gdb で明示ロードする。
# (.gdbinit の自動ロードは auto-load safe-path 設定への依存を避けるため使わない)

set architecture i386
set disassembly-flavor intel

define hook-stop
    regs32
end

define regs32
    printf "EAX=%08x EBX=%08x ECX=%08x EDX=%08x\n", (unsigned int)$eax, (unsigned int)$ebx, (unsigned int)$ecx, (unsigned int)$edx
    printf "ESI=%08x EDI=%08x EBP=%08x ESP=%08x\n", (unsigned int)$esi, (unsigned int)$edi, (unsigned int)$ebp, (unsigned int)$esp
    printf "CS=%04x DS=%04x ES=%04x SS=%04x FS=%04x GS=%04x\n", (unsigned int)$cs, (unsigned int)$ds, (unsigned int)$es, (unsigned int)$ss, (unsigned int)$fs, (unsigned int)$gs
    printf "EIP=%08x EFLAGS=%08x\n", (unsigned int)$eip, (unsigned int)$eflags
    printf "CF=%d PF=%d AF=%d ZF=%d SF=%d OF=%d\n", \
    ((unsigned int)$eflags >> 0) & 1, \
    ((unsigned int)$eflags >> 2) & 1, \
    ((unsigned int)$eflags >> 4) & 1, \
    ((unsigned int)$eflags >> 6) & 1, \
    ((unsigned int)$eflags >> 7) & 1, \
    ((unsigned int)$eflags >> 11) & 1
end

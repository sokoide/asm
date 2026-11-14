define regs16
    printf "AX=%04x BX=%04x CX=%04x DX=%04x\n", (unsigned int)$eax & 0xffff, (unsigned int)$ebx & 0xffff, (unsigned int)$ecx & 0xffff, (unsigned int)$edx & 0xffff
    printf "SI=%04x DI=%04x BP=%04x SP=%04x\n", (unsigned int)$esi & 0xffff, (unsigned int)$edi & 0xffff, (unsigned int)$ebp & 0xffff, (unsigned int)$esp & 0xffff
    printf "CS=%04x DS=%04x ES=%04x SS=%04x\n", (unsigned int)$cs & 0xffff, (unsigned int)$ds & 0xffff, (unsigned int)$es & 0xffff, (unsigned int)$ss & 0xffff
    printf "IP=%04x FLAGS=%04x  ", (unsigned int)$eip & 0xffff, (unsigned int)$eflags & 0xffff
    x/i $pc
end

define regs32
    printf "EAX=%08x EBX=%08x ECX=%08x EDX=%08x\n", (unsigned int)$eax, (unsigned int)$ebx, (unsigned int)$ecx, (unsigned int)$edx
    printf "ESI=%08x EDI=%08x EBP=%08x ESP=%08x\n", (unsigned int)$esi, (unsigned int)$edi, (unsigned int)$ebp, (unsigned int)$esp
    printf "CS=%04x DS=%04x ES=%04x SS=%04x FS=%04x GS=%04x\n", (unsigned int)$cs, (unsigned int)$ds, (unsigned int)$es, (unsigned int)$ss, (unsigned int)$fs, (unsigned int)$gs
    printf "EIP=%08x EFLAGS=%08x  ", (unsigned int)$eip, (unsigned int)$eflags
    x/i $pc
end

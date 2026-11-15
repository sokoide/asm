# AArch64 (ARM64) register display
# QEMU virt / Cortex-A57

set pagination off

define regsarm64
    # General-purpose registers (X0-X30)
    printf "X00=%016llx X01=%016llx X02=%016llx X03=%016llx\n", (unsigned long long)$x0, (unsigned long long)$x1, (unsigned long long)$x2, (unsigned long long)$x3
    printf "X04=%016llx X05=%016llx X06=%016llx X07=%016llx\n", (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6, (unsigned long long)$x7
    printf "X08=%016llx X09=%016llx X10=%016llx X11=%016llx\n", (unsigned long long)$x8, (unsigned long long)$x9, (unsigned long long)$x10, (unsigned long long)$x11
    printf "X12=%016llx X13=%016llx X14=%016llx X15=%016llx\n", (unsigned long long)$x12, (unsigned long long)$x13, (unsigned long long)$x14, (unsigned long long)$x15
    printf "X16=%016llx X17=%016llx X18=%016llx X19=%016llx\n", (unsigned long long)$x16, (unsigned long long)$x17, (unsigned long long)$x18, (unsigned long long)$x19
    printf "X20=%016llx X21=%016llx X22=%016llx X23=%016llx\n", (unsigned long long)$x20, (unsigned long long)$x21, (unsigned long long)$x22, (unsigned long long)$x23
    printf "X24=%016llx X25=%016llx X26=%016llx X27=%016llx\n", (unsigned long long)$x24, (unsigned long long)$x25, (unsigned long long)$x26, (unsigned long long)$x27
    printf "X28=%016llx FP =%016llx LR =%016llx\n", (unsigned long long)$x28, (unsigned long long)$x29, (unsigned long long)$x30

    # Stack pointer and program counter
    printf "SP =%016llx PC =%016llx\n", (unsigned long long)$sp, (unsigned long long)$pc

    # PSTATE / CPSR flags
    # N=bit31 Z=bit30 C=bit29 V=bit28
    printf "CPSR=%08x [N=%d Z=%d C=%d V=%d]\n", (unsigned int)$cpsr, ((unsigned int)$cpsr >> 31) & 1, ((unsigned int)$cpsr >> 30) & 1, ((unsigned int)$cpsr >> 29) & 1, ((unsigned int)$cpsr >> 28) & 1
end

# Display registers after every stop
define hook-stop
    regsarm64
end


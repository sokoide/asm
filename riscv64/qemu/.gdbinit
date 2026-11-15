
# RISC-V RV64 register display

set pagination off

define regs64
    # General Purpose Registers (64-bit)
    printf "zero=%016llx ra=%016llx sp=%016llx gp=%016llx\n", 0ULL, (unsigned long long)$ra, (unsigned long long)$sp, (unsigned long long)$gp
    printf "tp  =%016llx t0=%016llx t1=%016llx t2=%016llx\n", (unsigned long long)$tp, (unsigned long long)$t0, (unsigned long long)$t1, (unsigned long long)$t2
    printf "s0  =%016llx s1=%016llx a0=%016llx a1=%016llx\n", (unsigned long long)$s0, (unsigned long long)$s1, (unsigned long long)$a0, (unsigned long long)$a1
    printf "a2  =%016llx a3=%016llx a4=%016llx a5=%016llx\n", (unsigned long long)$a2, (unsigned long long)$a3, (unsigned long long)$a4, (unsigned long long)$a5
    printf "a6  =%016llx a7=%016llx s2=%016llx s3=%016llx\n", (unsigned long long)$a6, (unsigned long long)$a7, (unsigned long long)$s2, (unsigned long long)$s3
    printf "s4  =%016llx s5=%016llx s6=%016llx s7=%016llx\n", (unsigned long long)$s4, (unsigned long long)$s5, (unsigned long long)$s6, (unsigned long long)$s7
    printf "s8  =%016llx s9=%016llx s10=%016llx s11=%016llx\n", (unsigned long long)$s8, (unsigned long long)$s9, (unsigned long long)$s10, (unsigned long long)$s11
    printf "t3  =%016llx t4=%016llx t5=%016llx t6=%016llx\n", (unsigned long long)$t3, (unsigned long long)$t4, (unsigned long long)$t5, (unsigned long long)$t6

    printf "PC=%016llx\n", (unsigned long long)$pc
end

# Automatically display registers on stop
define hook-stop
    regs64
end


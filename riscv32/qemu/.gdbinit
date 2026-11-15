
# RISC-V RV32 register display

set pagination off

define regs32
    # General Purpose Registers
    printf "zero=%08x ra=%08x sp=%08x gp=%08x\n", 0, (unsigned int)$ra, (unsigned int)$sp, (unsigned int)$gp
    printf "tp  =%08x t0=%08x t1=%08x t2=%08x\n", (unsigned int)$tp, (unsigned int)$t0, (unsigned int)$t1, (unsigned int)$t2
    printf "s0  =%08x s1=%08x a0=%08x a1=%08x\n", (unsigned int)$s0, (unsigned int)$s1, (unsigned int)$a0, (unsigned int)$a1
    printf "a2  =%08x a3=%08x a4=%08x a5=%08x\n", (unsigned int)$a2, (unsigned int)$a3, (unsigned int)$a4, (unsigned int)$a5
    printf "a6  =%08x a7=%08x s2=%08x s3=%08x\n", (unsigned int)$a6, (unsigned int)$a7, (unsigned int)$s2, (unsigned int)$s3
    printf "s4  =%08x s5=%08x s6=%08x s7=%08x\n", (unsigned int)$s4, (unsigned int)$s5, (unsigned int)$s6, (unsigned int)$s7
    printf "s8  =%08x s9=%08x s10=%08x s11=%08x\n", (unsigned int)$s8, (unsigned int)$s9, (unsigned int)$s10, (unsigned int)$s11
    printf "t3  =%08x t4=%08x t5=%08x t6=%08x\n", (unsigned int)$t3, (unsigned int)$t4, (unsigned int)$t5, (unsigned int)$t6

    printf "PC=%08x\n", (unsigned int)$pc
end

# Automatically display registers on stop
define hook-stop
    regs32
end


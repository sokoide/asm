
# PowerPC 32-bit register display
# QEMU bamboo / PPC405

set pagination off

define regsppc
    # General Purpose Registers (32-bit)
    printf "R00=%08x R01=%08x R02=%08x R03=%08x\n", (unsigned int)$r0, (unsigned int)$r1, (unsigned int)$r2, (unsigned int)$r3
    printf "R04=%08x R05=%08x R06=%08x R07=%08x\n", (unsigned int)$r4, (unsigned int)$r5, (unsigned int)$r6, (unsigned int)$r7
    printf "R08=%08x R09=%08x R10=%08x R11=%08x\n", (unsigned int)$r8, (unsigned int)$r9, (unsigned int)$r10, (unsigned int)$r11
    printf "R12=%08x R13=%08x R14=%08x R15=%08x\n", (unsigned int)$r12, (unsigned int)$r13, (unsigned int)$r14, (unsigned int)$r15
    printf "R16=%08x R17=%08x R18=%08x R19=%08x\n", (unsigned int)$r16, (unsigned int)$r17, (unsigned int)$r18, (unsigned int)$r19
    printf "R20=%08x R21=%08x R22=%08x R23=%08x\n", (unsigned int)$r20, (unsigned int)$r21, (unsigned int)$r22, (unsigned int)$r23
    printf "R24=%08x R25=%08x R26=%08x R27=%08x\n", (unsigned int)$r24, (unsigned int)$r25, (unsigned int)$r26, (unsigned int)$r27
    printf "R28=%08x R29=%08x R30=%08x R31=%08x\n", (unsigned int)$r28, (unsigned int)$r29, (unsigned int)$r30, (unsigned int)$r31

    # Special Purpose Registers
    printf "LR=%08x CTR=%08x XER=%08x\n", (unsigned int)$lr, (unsigned int)$ctr, (unsigned int)$xer

    # CR0: LT(bit31), GT(bit30), EQ(bit29), SO(bit28)
    printf "CR=%08x [LT=%d GT=%d EQ=%d SO=%d]\n", (unsigned int)$cr, ((unsigned int)$cr >> 31) & 1, ((unsigned int)$cr >> 30) & 1, ((unsigned int)$cr >> 29) & 1, ((unsigned int)$cr >> 28) & 1

    # XER: SO(bit31), OV(bit30), CA(bit29)
    printf "XER Flags [SO=%d OV=%d CA=%d]\n", ((unsigned int)$xer >> 31) & 1, ((unsigned int)$xer >> 30) & 1, ((unsigned int)$xer >> 29) & 1

    # Program Counter
    printf "PC=%08x\n", (unsigned int)$pc
end

# Automatically display registers after each step
define hook-stop
    regsppc
end


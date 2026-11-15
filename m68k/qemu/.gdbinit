define hook-stop
    regs68k
end

define regs68k
    printf "D0=%08x D1=%08x D2=%08x D3=%08x\n", (unsigned int)$d0, (unsigned int)$d1, (unsigned int)$d2, (unsigned int)$d3
    printf "D4=%08x D5=%08x D6=%08x D7=%08x\n", (unsigned int)$d4, (unsigned int)$d5, (unsigned int)$d6, (unsigned int)$d7

    printf "A0=%08x A1=%08x A2=%08x A3=%08x\n", (unsigned int)$a0, (unsigned int)$a1, (unsigned int)$a2, (unsigned int)$a3
    printf "A4=%08x A5=%08x A6=%08x A7=%08x\n", (unsigned int)$a4, (unsigned int)$a5, (unsigned int)$fp, (unsigned int)$sp

    printf "SR=%04x [X=%d N=%d Z=%d V=%d C=%d]  ", (unsigned int)$ps & 0xffff, ((unsigned int)$ps >> 4) & 1, ((unsigned int)$ps >> 3) & 1, ((unsigned int)$ps >> 2) & 1, ((unsigned int)$ps >> 1) & 1, (unsigned int)$ps & 1
    printf "PC=%08x\n", (unsigned int)$pc
end

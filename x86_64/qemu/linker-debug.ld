OUTPUT_FORMAT("elf64-x86-64")

ENTRY(_start)

SECTIONS
{
    . = 0x7C00;

    .boot : {
        *(.boot)
    }
    ASSERT(SIZEOF(.boot) == 512, "boot sector must be exactly 512 bytes")

    . = 0x7E00;

    .stub : {
        *(.stub)
    }
    ASSERT(SIZEOF(.stub) <= 0x200, "stub must fit in 512 bytes")

    . = 0x8000;

    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }

    __image_end = .;
    ASSERT(__image_end <= 0xFE00, "image exceeds 62 sectors (33280 bytes)")

    __bss_start = .;
    .bss (NOLOAD) : { *(.bss*) *(COMMON) }
    __bss_end = .;
    ASSERT(__bss_end <= 0x8E000, "bss overlaps stack reserve (stack top = 0x90000)")
}

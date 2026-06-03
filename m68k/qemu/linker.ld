/* m68k bare-metal linker script for QEMU virt machine */
/* RAM start: 0x00000000, entry: _start */
ENTRY(_start)

SECTIONS
{
    . = 0x00000000;

    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        *(.data)
    }

    .bss : {
        __bss_start = .;
        *(.bss)
        *(COMMON)
        __bss_end = .;
    }
}

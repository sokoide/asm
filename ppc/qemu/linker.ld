/* PPC bare-metal linker script for QEMU bamboo machine */
/* Load address: 0x00000000 */

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

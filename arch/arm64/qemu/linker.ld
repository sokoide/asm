/* ARM64 bare-metal linker script for QEMU virt machine */
/* Kernel load address: 0x40000000 */

ENTRY(_start)

SECTIONS
{
    . = 0x40000000;

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

    /DISCARD/ : {
        *(.ARM.attributes)
        *(.comment)
    }
}

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

    /* Exception handlers (Book E: IVPR/IVOR). Empty in all scenarios that
       do not define a .handler section. IVPR = 0x01000000 (64KB aligned). */
    .handler 0x01000100 : {
        *(.handler)
    }

    .handler2 0x01000200 : {
        *(.handler2)
    }
}

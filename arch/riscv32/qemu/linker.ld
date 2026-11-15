/* RISC-V 32-bit bare-metal linker script for QEMU virt machine */
/* Load address: 0x80000000 */

ENTRY(_start)

SECTIONS
{
    . = 0x80000000;

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

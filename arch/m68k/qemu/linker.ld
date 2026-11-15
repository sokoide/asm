/* m68k bare-metal linker script for QEMU virt machine */
/* RAM start: 0x00000000, entry: _start */
/* Code starts at 0x400 to keep the exception vector table area (0x0000-0x03FF,
   256 vectors x 4 bytes) free for scenarios that install vectors
   (s102_trap: TRAP #0 = vector 32 at 0x80). */
ENTRY(_start)

SECTIONS
{
    . = 0x00000400;

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

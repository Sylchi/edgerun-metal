/* EdgeRun PE32+ linker script for UEFI EFI application */
OUTPUT_FORMAT(pei-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

__image_base__ = 0x100000;

SECTIONS
{
    . = __image_base__;

    .text : {
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        *(.data)
        *(.data.*)
    }

    __bss_start = .;
    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    }
    __bss_end = .;

    /DISCARD/ : {
        *(.note*)
        *(.comment*)
    }
}

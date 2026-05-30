/* Pi Zero W v1.1 kernel linker script
   Kernel image is loaded by the GPU to 0x8000 and executed directly.
   Output is a raw binary with no ELF headers.
   Separate PT_LOAD segments for text and data to suppress RWX warning. */

PHDRS {
    text PT_LOAD FLAGS(5);   /* PF_R | PF_X */
    data PT_LOAD FLAGS(6);   /* PF_R | PF_W */
}

SECTIONS {
    . = 0x8000;

    .text : {
        *(.text.startup)
        *(.text)
    } :text

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } :data

    .data : {
        *(.data)
    } :data

    .bss : {
        __bss_start = .;
        *(.bss)
        *(COMMON)
        __bss_end = .;
    } :data

    . = ALIGN(4);
    _end = .;
}

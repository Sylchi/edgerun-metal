ENTRY(_start)

SECTIONS
{
    . = 0x8000;
    .text : {
        KEEP(*(.text._start))
        KEEP(*(.text.start))
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}

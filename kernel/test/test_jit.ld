ENTRY(_start)

PHDRS
{
    text PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(7);
}

SECTIONS
{
    . = 0x400000;
    .text : { *(.text*) } :text
    .data : { *(.data*) } :data
    .bss  : { *(.bss*) *(.sbss*) *(COMMON) } :data
}

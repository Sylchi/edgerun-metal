/* EdgeRun x86_64 bare-metal linker script
 * Produces a flat binary loaded at 0x100000 (1 MiB) — the conventional
 * entry point for x86_64 multiboot kernels.
 *
 * Compiled as ELF32 for QEMU multiboot compatibility; the 64-bit code
 * is embedded within the 32-bit ELF container.
 */

OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)

SECTIONS
{
    /* Load address — 1 MiB conventional for x86_64 kernels */
    . = 0x100000;

    .text : ALIGN(4K)
    {
        *(.text._start)
        *(.text.start)
        *(.text*)
    }

    .rodata : ALIGN(4K)
    {
        *(.rodata*)
    }

    .data : ALIGN(4K)
    {
        *(.data*)
    }

    .bss : ALIGN(4K)
    {
        __bss_start = .;
        *(COMMON)
        *(.bss*)
        . = ALIGN(8);
        __bss_end = .;
    }

    /* Discard unnecessary sections */
    /DISCARD/ :
    {
        *(.note*)
        *(.comment*)
        *(.eh_frame*)
        *(.got*)
        *(.plt*)
    }
}

; EdgeRun x86 flat unit-test boot loader.
; BIOS loads this sector at 0x7c00. The loader reads a bounded flat test kernel
; from following disk sectors with int 13h, copies it to 1 MiB, switches to
; protected mode, and jumps to the repo-owned long-mode entry.

%ifndef KERNEL_SECTORS
%error "KERNEL_SECTORS must be defined"
%endif

%if KERNEL_SECTORS > 62
%error "test_x86_flat_boot supports at most 62 kernel sectors"
%endif

KERNEL_LOAD_ADDR equ 0x00100000
READ_BUFFER_ADDR equ 0x00008000
BOOT_STACK_TOP equ 0x7c00
PROT_STACK_TOP equ 0x7000
A20_FAST_PORT equ 0x92
CR0_PE_BIT equ 0x00000001
PROT_CODE_SEL equ 0x08
PROT_DATA_SEL equ 0x10
BIOS_READ_SECTORS equ 0x02
BIOS_DISK_SERVICE equ 0x13
FIRST_KERNEL_SECTOR equ 2
DEBUG_EXIT_PORT equ 0xf4
DEBUG_EXIT_BOOT_FAIL equ 2
SECTOR_BYTES equ 512

[BITS 16]
org 0x7c00

boot_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     ss, ax
    mov     sp, BOOT_STACK_TOP
    mov     [boot_drive], dl

    mov     ax, READ_BUFFER_ADDR >> 4
    mov     es, ax
    xor     bx, bx
    mov     ah, BIOS_READ_SECTORS
    mov     al, KERNEL_SECTORS
    xor     ch, ch
    mov     cl, FIRST_KERNEL_SECTOR
    xor     dh, dh
    mov     dl, [boot_drive]
    sti
    int     BIOS_DISK_SERVICE
    cli
    jc      boot_fail

    in      al, A20_FAST_PORT
    or      al, 0x02
    out     A20_FAST_PORT, al

    lgdt    [gdt_desc]
    mov     eax, cr0
    or      eax, CR0_PE_BIT
    mov     cr0, eax
    jmp     PROT_CODE_SEL:protected_start

boot_fail:
    mov     dx, DEBUG_EXIT_PORT
    mov     eax, DEBUG_EXIT_BOOT_FAIL
    out     dx, eax
.halt:
    hlt
    jmp     .halt

boot_drive: db 0

align 4
gdt_start:
    dq 0
    dq 0x00cf9a000000ffff
    dq 0x00cf92000000ffff
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
protected_start:
    mov     ax, PROT_DATA_SEL
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     esp, PROT_STACK_TOP
    cld
    mov     esi, READ_BUFFER_ADDR
    mov     edi, KERNEL_LOAD_ADDR
    mov     ecx, KERNEL_SECTORS * SECTOR_BYTES
    rep     movsb
    xor     ebx, ebx
    jmp     KERNEL_LOAD_ADDR

times 510 - ($ - $$) db 0
dw 0xaa55

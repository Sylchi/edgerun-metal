; EdgeRun QEMU BIOS loader.
;
; Sector 0 loads the flat kernel payload from following sectors into 0x100000,
; switches to 32-bit protected mode, and jumps to the kernel entry. There is no
; filesystem, Multiboot contract, or ELF loader in this path.

%ifndef KERNEL_SECTORS
%error "KERNEL_SECTORS must be defined"
%endif

KERNEL_LOAD_ADDR equ 0x00100000
READ_BUFFER_ADDR equ 0x00008000
BOOT_STACK_TOP equ 0x7c00
PROT_STACK_TOP equ 0x7000
A20_FAST_PORT equ 0x92
CR0_PE_BIT equ 0x00000001
PROT_CODE_SEL equ 0x08
PROT_DATA_SEL equ 0x10
BIOS_EXT_READ equ 0x42
BIOS_DISK_SERVICE equ 0x13
FIRST_KERNEL_LBA equ 1
SECTOR_BYTES equ 512
DAP_SIZE equ 0x10

[BITS 16]
org 0x7c00

boot_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     ss, ax
    mov     sp, BOOT_STACK_TOP

    mov     ax, READ_BUFFER_ADDR >> 4
    mov     es, ax
    xor     bx, bx
    mov     word [sectors_left], KERNEL_SECTORS
    mov     dword [next_lba], FIRST_KERNEL_LBA
.read_loop:
    cmp     word [sectors_left], 0
    je      .read_done
    mov     [dap_offset], bx
    mov     [dap_segment], es
    mov     eax, [next_lba]
    mov     [dap_lba], eax
    mov     ah, BIOS_EXT_READ
    lea     si, [dap]
    sti
    int     BIOS_DISK_SERVICE
    cli
    jc      boot_fail
    add     bx, SECTOR_BYTES
    jnc     .buffer_ok
    mov     ax, es
    add     ax, 0x1000
    mov     es, ax
.buffer_ok:
    inc     dword [next_lba]
    dec     word [sectors_left]
    jmp     .read_loop
.read_done:

    in      al, A20_FAST_PORT
    or      al, 0x02
    out     A20_FAST_PORT, al
    lgdt    [gdt_desc]
    mov     eax, cr0
    or      eax, CR0_PE_BIT
    mov     cr0, eax
    jmp     PROT_CODE_SEL:protected_start

boot_fail:
    hlt
    jmp     boot_fail

sectors_left: dw 0
next_lba: dd 0

align 4
dap:
    db DAP_SIZE
    db 0
    dw 1
dap_offset:
    dw 0
dap_segment:
    dw 0
dap_lba:
    dq 0

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

; EdgeRun QEMU BIOS loader.
;
; Sector 0 loads the flat kernel payload from following sectors into 0x100000,
; switches to 32-bit protected mode, and jumps to the kernel entry. There is no
; filesystem, Multiboot contract, or ELF loader in this path.

%include "x86_64/macros.inc"

%ifndef KERNEL_SECTORS
%error "KERNEL_SECTORS must be defined"
%endif

KERNEL_LOAD_ADDR equ 0x00100000
KERNEL_LBA_START equ 1
BOOT_STACK_TOP equ 0x7c00
A20_FAST_PORT equ 0x92
CR0_PE_BIT equ 0x00000001
PROT_CODE_SEL equ 0x08
PROT_DATA_SEL equ 0x10
ATA_DATA equ 0x1f0
ATA_SECTOR_COUNT equ 0x1f2
ATA_LBA_LOW equ 0x1f3
ATA_LBA_MID equ 0x1f4
ATA_LBA_HIGH equ 0x1f5
ATA_DRIVE_HEAD equ 0x1f6
ATA_STATUS_COMMAND equ 0x1f7
ATA_STATUS_BSY equ 0x80
ATA_STATUS_DRQ equ 0x08
ATA_CMD_READ_SECTORS equ 0x20
ATA_PRIMARY_MASTER_LBA equ 0xe0
ATA_SECTOR_BYTES equ 512
ATA_SECTOR_WORDS equ 256

[BITS 16]
org 0x7c00

boot_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, BOOT_STACK_TOP

    in      al, A20_FAST_PORT
    or      al, 0x02
    out     A20_FAST_PORT, al
    lgdt    [gdt_desc]
    mov     eax, cr0
    or      eax, CR0_PE_BIT
    mov     cr0, eax
    jmp     PROT_CODE_SEL:protected_start

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
    mov     esp, KERNEL_LOAD_ADDR
    cld
    mov     esi, KERNEL_LBA_START
    mov     edi, KERNEL_LOAD_ADDR
    mov     ebx, KERNEL_SECTORS
.read_loop:
    test    ebx, ebx
    jz      .jump_kernel
    call    ata_read_sector
    inc     esi
    add     edi, ATA_SECTOR_BYTES
    dec     ebx
    jmp     .read_loop
.jump_kernel:
    xor     ebx, ebx
    jmp     KERNEL_LOAD_ADDR

ata_wait_ready:
    mov     dx, ATA_STATUS_COMMAND
.busy:
    in      al, dx
    test    al, ATA_STATUS_BSY
    jnz     .busy
    ret

ata_wait_drq:
    mov     dx, ATA_STATUS_COMMAND
.drq:
    in      al, dx
    test    al, ATA_STATUS_BSY
    jnz     .drq
    test    al, ATA_STATUS_DRQ
    jz      .drq
    ret

ata_read_sector:
    call    ata_wait_ready
    mov     eax, esi
    shr     eax, 24
    and     al, 0x0f
    or      al, ATA_PRIMARY_MASTER_LBA
    mov     dx, ATA_DRIVE_HEAD
    out     dx, al
    mov     dx, ATA_SECTOR_COUNT
    mov     al, 1
    out     dx, al
    mov     eax, esi
    mov     dx, ATA_LBA_LOW
    out     dx, al
    mov     eax, esi
    shr     eax, 8
    mov     dx, ATA_LBA_MID
    out     dx, al
    mov     eax, esi
    shr     eax, 16
    mov     dx, ATA_LBA_HIGH
    out     dx, al
    mov     dx, ATA_STATUS_COMMAND
    mov     al, ATA_CMD_READ_SECTORS
    out     dx, al
    call    ata_wait_drq
    push    ecx
    push    edi
    mov     dx, ATA_DATA
    mov     ecx, ATA_SECTOR_WORDS
    rep     insw
    pop     edi
    pop     ecx
    ret

times 510 - ($ - $$) db 0
dw 0xaa55

; EdgeRun UEFI PE32+ entry point — x86_64 assembly
; System V AMD64 ABI (UEFI Microsoft x64 calling convention).
; Freestanding — no libc, no external dependencies.
;
; Replaces entry.asm for UEFI boot. Starts in 64-bit long mode
; (UEFI provides this). Gets framebuffer from GOP, sets up page
; tables, GDT, BSS, stack, then calls er_kernel_main.

%include "x86_64/macros.inc"

extern __bss_start
extern __bss_end
extern er_bss_zero
extern er_kernel_main

; Stack in .bss (zeroed before use)
SECTION .bss
align 16
_er_stack_bottom:
    resb 16384
_er_stack_top:

; Multiboot info structure pointer (built from UEFI GOP data)
global mb_info_ptr
mb_info_ptr:    resq 1

; Fake multiboot info structure (filled at runtime)
fake_mbinfo:    resb 128

; Saved UEFI handles
saved_handle:   resq 1
saved_systab:   resq 1
gop_pointer:    resq 1

; Framebuffer data (filled from GOP)
fb_addr:        resq 1
fb_width:       resd 1
fb_height:      resd 1
fb_pitch:       resd 1
fb_bpp:         resb 1

; ─── GOP GUID: 9042a9de-23dc-4a38-96fb-7aded080516a ────────────
SECTION .rodata
align 8
gop_guid:  dd 0x9042a9de, 0x23dc, 0x4a38
           db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a

; ─── Boot page tables (identity-map 0–8GB via 1GB huge pages) ──
SECTION .text
align 4096
boot_pml4:
    dq boot_pdpt + 0x07        ; entry 0: present + writable
    times 511 dq 0

boot_pdpt:
    dq 0x0000000000000083      ; [0G, 1G): present + writable + 1G
    dq 0x0000000040000083      ; [1G, 2G)
    dq 0x0000000080000083      ; [2G, 3G)
    dq 0x00000000C0000083      ; [3G, 4G)
    dq 0x0000000100000083      ; [4G, 5G)
    dq 0x0000000140000083      ; [5G, 6G)
    dq 0x0000000180000083      ; [6G, 7G)
    dq 0x00000001C0000083      ; [7G, 8G)
    times 504 dq 0

; ─── Temporary 64-bit GDT ───────────────────────────────────────
align 16
gdt_null:    dq 0
gdt_code64:  dq 0x00AF9A000000FFFF  ; 64-bit code segment
gdt_data64:  dq 0x00AF92000000FFFF  ; 64-bit data segment
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_null - 1
    dq gdt_null

%define SEL_CODE64  0x08
%define SEL_DATA64  0x10

; ─── EFI Entry Point ──────────────────────────────────────────────
; UEFI calling convention (Microsoft x64):
;   rcx = ImageHandle
;   rdx = SystemTable
; Returns: eax = EFI_STATUS (0 = success)
; ──────────────────────────────────────────────────────────────────
global _start
[BITS 64]
_start:
    ; Save UEFI handles
    mov     [saved_handle], rcx
    mov     [saved_systab], rdx

    ; Get framebuffer from UEFI GOP
    call    efi_get_fb

    ; Load GDT
    lgdt    [gdt_descriptor]

    ; Load PML4 address into CR3
    mov     eax, boot_pml4
    mov     cr3, rax

    ; Set PAE and PGE in CR4
    mov     rax, cr4
    or      eax, 0x000000A0        ; PAE + PGE
    mov     cr4, rax

    ; Enable Long Mode in EFER MSR
    mov     ecx, 0xC0000080        ; EFER MSR
    rdmsr
    or      eax, 0x00000100        ; LME = 1
    wrmsr

    ; Enable paging (PG + PE in CR0)
    mov     rax, cr0
    or      eax, 0x80000001        ; PG + PE
    mov     cr0, rax

    ; Load data segment descriptors
    mov     ax, SEL_DATA64
    db      0x8E, 0xD8       ; mov ds, ax (raw encode to suppress YASM seg warning)
    db      0x8E, 0xC0       ; mov es, ax
    mov     fs, ax
    mov     gs, ax
    db      0x8E, 0xD0       ; mov ss, ax

    ; Far jump to reload CS (code segment selector)
    push    SEL_CODE64
    lea     rax, [rel _start.long64]
    push    rax
    retfq

_start.long64:
    ; Save framebuffer data in callee-saved regs before BSS zero
    ; (er_bss_zero preserves rbx, r12-r15)
    mov     r12, [fb_addr]
    mov     r13d, [fb_width]
    mov     r14d, [fb_height]
    mov     r15d, [fb_pitch]
    movzx   ebx, byte [fb_bpp]

    ; Zero BSS
    lea     rdi, [rel __bss_start]
    lea     rsi, [rel __bss_end]
    call    er_bss_zero

    ; Restore framebuffer data from saved registers
    mov     [fb_addr], r12
    mov     [fb_width], r13d
    mov     [fb_height], r14d
    mov     [fb_pitch], r15d
    mov     [fb_bpp], bl

    ; Build fake multiboot info structure with our framebuffer data
    ; Multiboot v1 info structure offsets (32-bit GRUB layout):
    ;   +0x58: framebuffer_addr  (u64)
    ;   +0x60: framebuffer_pitch (u32, bytes per scanline)
    ;   +0x64: framebuffer_width (u32)
    ;   +0x68: framebuffer_height (u32)
    ;   +0x6C: framebuffer_bpp   (u8)
    ;   +0x6D: framebuffer_type  (u8)
    lea     rdi, [rel fake_mbinfo]
    mov     dword [rdi], 1 << 12   ; flags = bit 12 (framebuffer valid)
    mov     rax, [fb_addr]
    mov     [rdi + 0x58], rax      ; framebuffer_addr
    mov     eax, [fb_pitch]
    shl     eax, 2                 ; PixelsPerScanLine * 4 = bytes per scanline
    mov     [rdi + 0x60], eax      ; framebuffer_pitch
    mov     eax, [fb_width]
    mov     [rdi + 0x64], eax      ; framebuffer_width
    mov     eax, [fb_height]
    mov     [rdi + 0x68], eax      ; framebuffer_height
    movzx   eax, byte [fb_bpp]
    mov     [rdi + 0x6C], al       ; framebuffer_bpp
    mov     byte [rdi + 0x6D], 2   ; framebuffer_type = 2 (RGB)

    ; Set mb_info_ptr to our fake structure
    lea     rax, [rel fake_mbinfo]
    mov     [mb_info_ptr], rax

    ; Call kernel main
    call    er_kernel_main

_start.halt:
    cli
    hlt
    jmp     _start.halt

; ==================================================================
; efi_get_fb — Get framebuffer from UEFI GOP protocol
; In:   saved_systab must be set
; Out:  fb_addr, fb_width, fb_height, fb_pitch, fb_bpp filled
;       on success; all zero on failure
; ==================================================================
efi_get_fb:
    er_push r12, r13, r14

    mov     r12, [saved_systab]
    mov     r12, [r12 + 0x60]      ; r12 = BootServices

    ; LocateProtocol
    mov     r13, [r12 + 0x140]     ; LocateProtocol function ptr
    er_check_zero r13, .err

    sub     rsp, 40                ; shadow space (32) + alignment (8)
    lea     rcx, [rel gop_guid]
    xor     edx, edx               ; Registration = NULL
    lea     r8, [rel gop_pointer]
    call    r13
    add     rsp, 40
    er_check_nonzero eax, .err

    ; GOP protocol obtained
    mov     r14, [gop_pointer]
    mov     r14, [r14 + 0x18]      ; r14 = GOP->Mode

    ; FrameBufferBase
    mov     rax, [r14 + 0x18]
    mov     [fb_addr], rax

    ; FrameBufferSize
    mov     rax, [r14 + 0x20]
    ; (not stored, but available for reference)

    ; Mode->Info pointer
    mov     r13, [r14 + 0x08]      ; r13 = GOP->Mode->Info

    ; HorizontalResolution
    mov     eax, [r13 + 0x04]
    mov     [fb_width], eax

    ; VerticalResolution
    mov     eax, [r13 + 0x08]
    mov     [fb_height], eax

    ; PixelsPerScanLine (used as pitch)
    mov     eax, [r13 + 0x20]
    mov     [fb_pitch], eax

    ; BPP: assume 32 bits (4 bytes) per pixel
    mov     byte [fb_bpp], 4

    er_pop_ret r12, r13, r14

.err:
    ; Zero out framebuffer data (no GOP available)
    xor     eax, eax
    mov     [fb_addr], rax
    mov     [fb_width], eax
    mov     [fb_height], eax
    mov     [fb_pitch], eax
    mov     [fb_bpp], al
    er_pop_ret r12, r13, r14

%include "x86_64/entry_common.inc"

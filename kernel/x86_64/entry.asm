; EdgeRun x86_64 kernel entry point.
;
; Phase 1 (32-bit protected mode): page tables, GDT, transition to long mode.
; Phase 2 (64-bit long mode):      stack, BSS zero, er_kernel_main.

%include "x86_64/macros.inc"

extern __bss_start
extern __bss_end
extern er_bss_zero
extern er_kernel_main

; Segment selectors
%define SEL_CODE64  0x08
%define SEL_DATA64  0x10

; Stack in .bss (zeroed by _start before use)
SECTION .bss
align 16
_er_stack_bottom:
%ifdef TEST_FLAT_KERNEL
    resb 1048576
%else
    resb 16384
%endif
_er_stack_top:

; Boot info pointer. The raw QEMU loader passes zero; EFI fills its own record.
global mb_info_ptr
mb_info_ptr:    dq 0

SECTION .text._start
; ─── Phase 1: 32-bit entry ────────────────────────────────────────────
[BITS 32]
global _start
_start:
    ; Save boot info structure pointer. Zero means no boot-info record.
    mov     [mb_info_ptr], ebx

    ; Disable interrupts
    cli

    ; Load GDT
    lgdt [gdt_descriptor]

    ; Set PAE, PGE, OSFXSR, OSXMMEXCPT in CR4
    mov     eax, cr4
    or      eax, 0x000006A0        ; PAE + PGE + OSFXSR + OSXMMEXCPT
    mov     cr4, eax

    ; Load PML4 address into CR3
    mov     eax, boot_pml4
    mov     cr3, eax

    ; Enable Long Mode in EFER MSR
    mov     ecx, 0xC0000080        ; EFER MSR
    rdmsr
    or      eax, 0x00000100        ; LME = 1
    wrmsr

    ; Enable paging (sets PG bit in CR0)
    mov     eax, cr0
    or      eax, 0x80000001        ; PG + PE
    mov     cr0, eax

    ; Far jump to 64-bit code
    jmp     SEL_CODE64:long_mode_entry

; ─── Boot page tables ──────────────────────────────────────────────────
; CPU must support pdpe1gb (AMD Ryzen 7840U does). Identity-map full 8GB.
align 4096
boot_pml4:
    dd boot_pdpt + 0x07           ; entry 0: present + writable
    dd 0
    times 510 dq 0                ; remaining 510 entries
    dd 0, 0                       ; entry 511

boot_pdpt:
    ; 1GB huge pages identity-map 0 – 3GB and 4GB – 8GB
    dd 0x00000083                 ; [0G, 1G): present + writable + 1G page
    dd 0
    dd 0x40000083                 ; [1G, 2G)
    dd 0
    dd 0x80000083                 ; [2G, 3G)
    dd 0
    dd boot_pd_pci + 0x07        ; [3G, 4G): point to PD (2MB pages, no PS bit)
    dd 0
    dd 0x00000083                 ; [4G, 5G): present + writable + 1G page
    dd 0x00000001
    dd 0x40000083                 ; [5G, 6G)
    dd 0x00000001
    dd 0x80000083                 ; [6G, 7G)
    dd 0x00000001
    dd 0xC0000083                 ; [7G, 8G)
    dd 0x00000001
    times 504 dq 0

; Page Directory for [3G, 4G) — 2MB pages so we can mark MMIO as UC
; Most entries are WB (0x83), MMIO entries (IOAPIC at 0xFEC, LAPIC at 0xFEE)
; use UC (0x9B = Present|Writable|PS|PWT|PCD).
align 4096
boot_pd_pci:
    ; Indices 0-501: WB 2MB pages (0xC0000000 – 0xFEBFFFFF)
    %assign i 0
    %rep 502
        dd (0xC0000000 + i * 0x200000) | 0x83
        dd 0
        %assign i i + 1
    %endrep
    ; Index 502: 0xFEC00000 (IOAPIC, HPET, TPM CRB) — UC (bit3=PWT, bit4=PCD)
    dd 0xFEC0009B
    dd 0
    ; Index 503: 0xFEE00000 (LAPIC) — UC
    dd 0xFEE0009B
    dd 0
    times 8 dq 0                  ; indices 504-511 unused

; ─── Temporary 64-bit GDT ─────────────────────────────────────────────
align 16
gdt_null:
    dq 0
gdt_code64:
    dq 0x00AF9A000000FFFF         ; 64-bit code segment
gdt_data64:
    dq 0x00AF92000000FFFF         ; 64-bit data segment
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_null - 1
    dd gdt_null

; ─── Phase 2: 64-bit entry ────────────────────────────────────────────
[BITS 64]
long_mode_entry:
    ; Load data segment descriptor
    mov     ax, SEL_DATA64
    db      0x8E, 0xD8       ; mov ds, ax (raw encode to suppress YASM seg warning)
    db      0x8E, 0xC0       ; mov es, ax
    mov     fs, ax
    mov     gs, ax
    db      0x8E, 0xD0       ; mov ss, ax

    ; Initialize MXCSR (SSE control/status) — default: mask all exceptions
    push    rax
    mov     eax, 0x1F80
    ldmxcsr [rsp]
    pop     rax

    ; Zero BSS using the loader-provided temporary stack.
    lea     rdi, [rel __bss_start]
    lea     rsi, [rel __bss_end]
    call    er_bss_zero

    ; Switch to kernel stack (BSS now zeroed)
    lea     rsp, [rel _er_stack_top]

    ; Call kernel main
    call    er_kernel_main

.halt:
    cli
    hlt
    jmp     .halt

%ifndef TEST_FLAT_KERNEL
%include "x86_64/entry_common.inc"
%endif

; EdgeRun x86_64 kernel entry point with multiboot v1 support.
;
; Phase 1 (32-bit protected mode): multiboot header, page tables, GDT,
;                                transition to 64-bit long mode.
; Phase 2 (64-bit long mode):     stack, BSS zero, er_kernel_main.

%include "x86_64/macros.inc"

extern __bss_start
extern __bss_end
extern er_bss_zero
extern er_kernel_main

; Stack in .bss (zeroed by _start before use)
SECTION .bss
align 16
_er_stack_bottom:
    resb 16384
_er_stack_top:

; Multiboot info structure pointer (saved from ebx at entry)
global mb_info_ptr
mb_info_ptr:    dq 0

; ─── Multiboot v1 header (must be in first 8192 bytes) ────────────────
; Request: align modules, memory info, video mode (linear framebuffer)
SECTION .text._start
align 4
mb_header:
    dd 0x1BADB002
    dd 0x00000007          ; flags: bit0=align, bit1=meminfo, bit2=video
    dd -(0x1BADB002 + 0x00000007)
    dd 0                   ; mode: 0=prefer LFB
    dd 1024                ; width
    dd 768                 ; height
    dd 32                  ; depth

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
    ; Index 502: 0xFEC00000 (IOAPIC, HPET, TPM CRB)
    dd 0xFEC00083
    dd 0
    ; Index 503: 0xFEE00000 (LAPIC)
    dd 0xFEE00083
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

; Segment selectors
%define SEL_CODE64  0x08
%define SEL_DATA64  0x10

; ─── Phase 1: 32-bit entry (multiboot) ────────────────────────────────
[BITS 32]
global _start
_start:
    ; Save multiboot info structure pointer (ebx holds physical address)
    ; Must be saved immediately before anything clobbers ebx
    mov     [mb_info_ptr], ebx

    ; Disable interrupts
    cli

    ; Load GDT
    lgdt [gdt_descriptor]

    ; Set PAE and PGE in CR4
    mov     eax, cr4
    or      eax, 0x000000A0        ; PAE + PGE
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
    jmp     SEL_CODE64:.64bit

; ─── Phase 2: 64-bit entry ────────────────────────────────────────────
[BITS 64]
.64bit:
    ; Load data segment descriptor
    mov     ax, SEL_DATA64
    db      0x8E, 0xD8       ; mov ds, ax (raw encode to suppress YASM seg warning)
    db      0x8E, 0xC0       ; mov es, ax
    mov     fs, ax
    mov     gs, ax
    db      0x8E, 0xD0       ; mov ss, ax

    ; Zero BSS using multiboot-provided stack
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

; ==================================================================
; er_halt — stop execution
; void er_halt(void)
; ==================================================================
er_fn er_halt
    cli
.loop:
    hlt
    jmp     .loop

; ==================================================================
; er_cpu_id — get CPU identification
; uint64_t er_cpu_id(void)
; Returns: CPU signature from CPUID
; ==================================================================
er_fn er_cpu_id
    push    rbx
    xor     eax, eax            ; CPUID function 0
    cpuid
    mov     rax, rax            ; return EAX (vendor/family/model)
    pop     rbx
    ret

; ==================================================================
; er_rdtsc — read timestamp counter
; uint64_t er_rdtsc(void)
; ==================================================================
er_fn er_rdtsc
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

; ==================================================================
; er_mmio_read32 — read 32-bit from MMIO address
; uint32_t er_mmio_read32(uint64_t addr)
; ==================================================================
er_fn er_mmio_read32
    mov     eax, [rdi]          ; 32-bit read from address in rdi
    ret

; ==================================================================
; er_mmio_write32 — write 32-bit to MMIO address
; void er_mmio_write32(uint64_t addr, uint32_t value)
; ==================================================================
er_fn er_mmio_write32
    mov     [rdi], esi          ; 32-bit write to address in rdi
    ret

; ==================================================================
; er_port_in8 — read 8-bit from I/O port
; uint8_t er_port_in8(uint16_t port)
; ==================================================================
er_fn er_port_in8
    mov     dx, di
    in      al, dx
    ret

; ==================================================================
; er_port_out8 — write 8-bit to I/O port
; void er_port_out8(uint16_t port, uint8_t value)
; ==================================================================
er_fn er_port_out8
    mov     dx, di
    mov     al, sil
    out     dx, al
    ret

; ==================================================================
; er_spin_delay — busy-wait loop
; void er_spin_delay(uint32_t iterations)
; ==================================================================
er_fn er_spin_delay
.loop:
    pause
    dec     esi
    jnz     .loop
    ret

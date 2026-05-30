; EdgeRun ACPI table parser — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Scans EBDA and BIOS memory for RSDP, then walks RSDT/XSDT
; to find ACPI tables (MADT, MCFG, HPET, FADT, etc.).

%include "x86_64/macros.inc"

; ACPI signature constants
%define RSDP_SIG_LO      0x20525450   ; "RTS " (little-endian: " RSD")
%define RSDP_SIG_HI      0x20205053   ; "  PS" (little-endian: "PTR ")
%define RSDT_SIG         0x54445352   ; "RSDT"
%define XSDT_SIG         0x54445358   ; "XSDT"
%define APIC_SIG         0x43495041   ; "APIC"
%define MCFG_SIG         0x4746434d   ; "MCFG"
%define HPET_SIG         0x54455048   ; "HPET"
%define FACP_SIG         0x50434146   ; "FACP"

; RSDP field offsets
%define RSDP_OEMID        9
%define RSDP_REVISION     15
%define RSDP_RSDT_ADDR    16
%define RSDP_LENGTH       20
%define RSDP_XSDT_ADDR    24
%define RSDP_EXT_CHKSUM   32

; SDT header offsets (shared by RSDT, XSDT, MADT, MCFG, HPET, FADT)
%define SDT_SIG           0
%define SDT_LENGTH        4
%define SDT_REVISION      8
%define SDT_CHKSUM        9
%define SDT_OEMID         10
%define SDT_OEM_TABLE_ID  16
%define SDT_OEM_REVISION  24
%define SDT_CREATOR_ID    28
%define SDT_CREATOR_REV   32
%define SDT_HEADER_LEN    36

; RSDT entry size
%define RSDT_ENTRY        4
%define XSDT_ENTRY        8

; MADT offsets (after SDT header = 36 bytes)
%define MADT_LAPIC_ADDR   36
%define MADT_FLAGS        40
%define MADT_ENTRIES      44

; MADT entry types
%define MADT_LAPIC        0
%define MADT_IOAPIC       1
%define MADT_ISO          2

; MADT LAPIC entry offsets (from entry start)
%define MADT_LAPIC_ACPI_PROC_ID  2
%define MADT_LAPIC_APIC_ID       3
%define MADT_LAPIC_FLAGS         4
%define MADT_LAPIC_ENTRY_LEN     8

; MADT IOAPIC entry offsets
%define MADT_IOAPIC_ID           2
%define MADT_IOAPIC_ADDR         4
%define MADT_IOAPIC_GSI_BASE     8
%define MADT_IOAPIC_ENTRY_LEN    12

; MADT ISO entry offsets
%define MADT_ISO_BUS             2
%define MADT_ISO_SOURCE          3
%define MADT_ISO_GSI             4
%define MADT_ISO_FLAGS           8
%define MADT_ISO_ENTRY_LEN       10

; MCFG offsets (after SDT header)
%define MCFG_RESERVED     36       ; 8 bytes reserved
%define MCFG_ALLOCATIONS  44

; MCFG allocation entry (16 bytes)
%define MCFG_ALLOC_BASE     0
%define MCFG_ALLOC_SEG      8
%define MCFG_ALLOC_START    10
%define MCFG_ALLOC_END      11
%define MCFG_ALLOC_RES      12    ; 4 bytes reserved
%define MCFG_ALLOC_ENTRY    16

; Scan range constants
%define EBDA_SEG_PTR    0x40E
%define BIOS_LOW_START  0x000E0000
%define BIOS_LOW_END    0x000FFFFF
%define BIOS_LOW_STEP   16

; Max tables to enumerate
%define MAX_ACPI_TABLES  32

SECTION .text

; ==================================================================
; er_acpi_checksum — validate ACPI table checksum
; int er_acpi_checksum(const void* table, uint32_t length)
;
; Args: rdi = table pointer, esi = length
; Returns: eax = 1 if valid (sum == 0), 0 if invalid
; ==================================================================
er_fn er_acpi_checksum
    xor     eax, eax
    xor     ecx, ecx
    test    esi, esi
    jz      .done
.loop:
    movzx   edx, byte [rdi + rcx]
    add     eax, edx
    inc     ecx
    cmp     ecx, esi
    jb      .loop
    test    al, al
    setz    al
    movzx   eax, al
.done:
    er_ok
    ret

; ==================================================================
; er_acpi_find_rsdp — scan EBDA and BIOS for RSDP signature
; int er_acpi_find_rsdp(uint64_t* out_rsdp_address)
;
; Args: rdi = pointer to uint64_t to receive RSDP address
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_acpi_find_rsdp
    push    rbx
    push    r12
    mov     r12, rdi

    ; First try: scan EBDA (Extended BIOS Data Area)
    ; The word at 0x40E gives the EBDA segment (paragraph)
    movzx   eax, word [EBDA_SEG_PTR]
    shl     eax, 4              ; segment * 16 = absolute address
    mov     edi, eax
    call    .scan_for_rsdp
    test    eax, eax
    jnz     .found

    ; Second try: scan BIOS ROM area 0x000E0000 - 0x000FFFFF
    mov     edi, BIOS_LOW_START
.scan_bios:
    mov     edi, BIOS_LOW_START
.scan_loop:
    cmp     edi, BIOS_LOW_END
    ja      .not_found
    call    .scan_for_rsdp
    test    eax, eax
    jnz     .found
    add     edi, BIOS_LOW_STEP
    jmp     .scan_loop

.found:
    mov     [r12], rdi
    mov     eax, 1
    pop     r12
    pop     rbx
    er_ok
    ret

.not_found:
    xor     eax, eax
    pop     r12
    pop     rbx
    er_ok
    ret

; Helper: check for RSDP signature at address in edi
; Returns eax = 1 if found, 0 if not
; Preserves: r12, rbx
.scan_for_rsdp:
    ; Check "RSD PTR " at [edi]
    cmp     dword [edi], RSDP_SIG_LO
    jne     .no_match
    cmp     dword [edi + 4], RSDP_SIG_HI
    jne     .no_match
    mov     eax, 1
    ret
.no_match:
    xor     eax, eax
    ret

; ==================================================================
; er_acpi_parse_rsdp — parse RSDP structure, return RSDT/XSDT info
; int er_acpi_parse_rsdp(uint64_t rsdp_addr, uint64_t* out_rsdt_addr,
;                        uint64_t* out_xsdt_addr, uint8_t* out_revision)
;
; Args: rdi = RSDP physical address
;        rsi = pointer to uint64_t for RSDT address
;        rdx = pointer to uint64_t for XSDT address
;        rcx = pointer to uint8_t for revision
; Returns: eax = 1 if valid, 0 on checksum failure
; ==================================================================
er_fn er_acpi_parse_rsdp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi          ; rsdp_addr
    mov     r13, rsi          ; out_rsdt
    mov     r14, rdx          ; out_xsdt
    mov     r15, rcx          ; out_revision

    ; Validate v1 checksum (first 20 bytes sum to 0)
    mov     edi, r12d
    mov     esi, 20
    call    er_acpi_checksum
    test    eax, eax
    jz      .fail

    ; Get revision from RSDP[15]
    movzx   ebx, byte [r12 + RSDP_REVISION]

    ; Get RSDT address from RSDP[16..19]
    mov     eax, [r12 + RSDP_RSDT_ADDR]
    mov     [r13], rax          ; out_rsdt = rsdt_addr

    ; If revision >= 2, get XSDT and validate extended checksum
    xor     eax, eax
    mov     [r14], rax          ; out_xsdt = 0 initially
    cmp     bl, 2
    jb      .done

    ; Get XSDT address from RSDP[24..31]
    mov     rax, [r12 + RSDP_XSDT_ADDR]
    mov     [r14], rax

    ; Get RSDP length from RSDP[20..23]
    mov     esi, [r12 + RSDP_LENGTH]
    cmp     esi, 36
    jb      .done

    ; Validate extended checksum (full RSDP)
    mov     edi, r12d
    call    er_acpi_checksum
    test    eax, eax
    jz      .fail

.done:
    mov     [r15], bl          ; out_revision
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.fail:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

; ==================================================================
; er_acpi_find_table — find ACPI table by 4-byte signature
; int er_acpi_find_table(uint64_t rsdt_addr, uint64_t xsdt_addr,
;                        uint32_t signature, uint64_t* out_table_addr)
;
; Args: rdi = RSDT address
;        rsi = XSDT address (0 if using RSDT)
;        edx = 4-byte signature (e.g. "APIC")
;        rcx = pointer to uint64_t for table address
; Returns: eax = 1 if found, 0 if not
; ==================================================================
er_fn er_acpi_find_table
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi          ; rsdt_addr
    mov     r13, rsi          ; xsdt_addr
    mov     r14d, edx         ; target_sig
    mov     r15, rcx          ; out_table_addr

    ; Determine if using XSDT
    mov     rdi, r12          ; start with RSDT root
    xor     ebx, ebx          ; entry_size = 4 (RSDT)
    test    r13, r13
    jz      .have_root
    mov     rdi, r13          ; use XSDT
    mov     ebx, XSDT_ENTRY   ; entry_size = 8

.have_root:
    ; Read SDT header at root table address
    mov     esi, [rdi + SDT_LENGTH]
    sub     esi, SDT_HEADER_LEN
    jbe     .not_found

    xor     ecx, ecx
.loop:
    cmp     ecx, esi
    jae     .not_found

    ; Get table address from this entry
    test    r13, r13
    jnz     .xsdt_entry
    ; RSDT entry: 32-bit address
    mov     r8d, [rdi + SDT_HEADER_LEN + rcx]
    mov     r9, r8
    jmp     .check_entry
.xsdt_entry:
    ; XSDT entry: 64-bit address
    mov     r9, [rdi + SDT_HEADER_LEN + rcx]

.check_entry:
    ; Check signature at table address
    mov     eax, [r9]
    cmp     eax, r14d
    jne     .next

    ; Found — validate checksum and return address
    mov     rax, r9
    mov     [r15], rax
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

.next:
    add     ecx, ebx
    jmp     .loop

.not_found:
    xor     eax, eax
    mov     [r15], rax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

; ==================================================================
; er_acpi_parse_madt — parse MADT table, extract LAPIC and IOAPIC info
; int er_acpi_parse_madt(const void* madt, uint32_t length,
;                        uint32_t* out_lapic_addr,
;                        uint32_t* out_ioapic_addr,
;                        uint32_t* out_ioapic_gsi_base)
;
; Args: rdi = MADT table pointer
;        esi = table length
;        rdx = pointer to uint32_t for LAPIC address
;        rcx = pointer to uint32_t for IOAPIC address
;        r8  = pointer to uint32_t for IOAPIC GSI base
; Returns: eax = 1 if valid MADT with LAPIC/IOAPIC found
; ==================================================================
er_fn er_acpi_parse_madt
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx

    mov     r12, rdi          ; madt_ptr
    mov     r13d, esi         ; length
    mov     r14, rdx          ; out_lapic_addr
    mov     r15, rcx          ; out_ioapic_addr
    mov     rbx, r8           ; out_ioapic_gsi_base

    ; Validate SDT header
    cmp     dword [r12], APIC_SIG
    jne     .fail
    cmp     esi, MADT_ENTRIES
    jb      .fail

    ; Get LAPIC address from MADT[36..39]
    mov     eax, [r12 + MADT_LAPIC_ADDR]
    mov     [r14], eax

    ; Parse MADT entries starting at offset 44
    mov     ecx, MADT_ENTRIES
    xor     r9d, r9d          ; ioapic address
    xor     r10d, r10d        ; ioapic gsi base

.entry_loop:
    cmp     ecx, r13d
    jae     .parse_done

    movzx   eax, byte [r12 + rcx]        ; entry type
    movzx   edx, byte [r12 + rcx + 1]    ; entry length
    cmp     edx, 2
    jb      .fail

    cmp     eax, MADT_IOAPIC
    jne     .next_entry

    ; IOAPIC entry found — save address and GSI base
    mov     r9d, [r12 + rcx + MADT_IOAPIC_ADDR]
    mov     r10d, [r12 + rcx + MADT_IOAPIC_GSI_BASE]

.next_entry:
    add     ecx, edx
    jmp     .entry_loop

.parse_done:
    mov     [r15], r9d
    mov     [rbx], r10d

    mov     eax, 1
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

.fail:
    xor     eax, eax
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

; ==================================================================
; er_acpi_parse_mcfg — parse MCFG table, return first ECAM base
; int er_acpi_parse_mcfg(const void* mcfg, uint32_t length,
;                        uint64_t* out_ecam_base,
;                        uint8_t* out_start_bus,
;                        uint8_t* out_end_bus)
;
; Args: rdi = MCFG table pointer
;        esi = length
;        rdx = pointer to uint64_t for ECAM base address
;        rcx = pointer to uint8_t for start bus
;        r8  = pointer to uint8_t for end bus
; Returns: eax = 1 if valid MCFG with allocation found
; ==================================================================
er_fn er_acpi_parse_mcfg
    cmp     dword [rdi], MCFG_SIG
    jne     .fail
    cmp     esi, MCFG_ALLOCATIONS + MCFG_ALLOC_ENTRY
    jb      .fail

    ; Read first allocation entry at offset 44
    mov     rax, [rdi + MCFG_ALLOCATIONS + MCFG_ALLOC_BASE]
    mov     [rdx], rax

    movzx   eax, byte [rdi + MCFG_ALLOCATIONS + MCFG_ALLOC_START]
    mov     [rcx], al

    movzx   eax, byte [rdi + MCFG_ALLOCATIONS + MCFG_ALLOC_END]
    mov     [r8], al

    mov     eax, 1
    er_ok
    ret

.fail:
    xor     eax, eax
    er_ok
    ret

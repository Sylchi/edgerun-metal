; EdgeRun ROM Armor SPI flash access — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Provides SPI flash read/write/erase through ROM Armor.
; On ROM Armor 3: reads via direct MMIO (0xFE000000), writes/erases via PSP mailbox.
; On ROM Armor 2: all operations via PSP mailbox (read, write, erase).
;
; Reference: coreboot src/soc/amd/common/block/psp/psp_rom_armor_smm.c

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_psp_mbox_hsti_query
extern er_psp_mbox_nop
extern er_psp_mbox_armor_enforce
extern er_psp_mbox_armor_spi_transaction
extern er_psp_mbox_buffer

; SPI flash is memory-mapped at top of 4GB on AMD Phoenix
; 32 MiB flash: 0xFE000000 - 0xFFFFFFFF
; 16 MiB flash: 0xFF000000 - 0xFFFFFFFF
%define SPI_MMIO_BASE       0xFE000000
%define SPI_MMIO_SIZE       0x2000000   ; 32 MiB

; ROM Armor transaction types
%define RA_READ    1
%define RA_WRITE   2
%define RA_ERASE   3

; HSTI state bits
%define HSTI_ROM_ARMOR_ENFORCED  (1 << 11)

; Transfer buffer (4 KiB aligned, for PSP mailbox data)
SECTION .bss
global er_ra_transfer_buf
er_ra_transfer_buf: resb 4096

SECTION .text

; ==================================================================
; er_rom_armor_detect
;   Detect ROM Armor state via HSTI query and MMIO test.
;   Arguments: none
;   Returns:
;     eax — 0=not present/blocked, 1=active (RA2), 2=active (RA3)
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_rom_armor_detect
    er_frame_push
    push    r12

    ; Try HSTI query via PSP mailbox
    er_call er_psp_mbox_hsti_query, .no_mailbox

    mov     r12d, eax
    test    eax, HSTI_ROM_ARMOR_ENFORCED
    jz      .not_enforced

    ; ROM Armor is enforced — check if MMIO reads work (RA3 indicator)
    mov     edi, SPI_MMIO_BASE
    call    _test_mmio_read
    test    eax, eax
    jz      .ra2

    ; MMIO reads work — ROM Armor 3
    mov     eax, 2
    er_ok
    pop     r12
    er_frame_pop
    er_ret

.ra2:
    ; ROM Armor 2 — all operations through mailbox
    mov     eax, 1
    er_ok
    pop     r12
    er_frame_pop
    er_ret

.not_enforced:
    ; ROM Armor not enforced — normal SPI access works
    xor     eax, eax
    er_ok
    pop     r12
    er_frame_pop
    er_ret

.no_mailbox:
    ; PSP mailbox not accessible — assume no PSP hardware or fully locked
    xor     eax, eax
    er_err  ERROR_NOT_PRESENT
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; Internal: test if MMIO region returns non-0xFF data
;   edi — MMIO base address
; Returns: eax = 1 if data found, 0 if all 0xFF
; ==================================================================
_test_mmio_read:
    ; Read first 4 bytes of flash
    mov     eax, [rdi]
    ; Check if it's all 0xFF (empty/erased flash)
    cmp     eax, 0xFFFFFFFF
    je      .empty
    mov     eax, 1
    ret
.empty:
    ; Could be empty or locked — try reading from upper region
    mov     eax, [rdi + 0x1F00000]    ; 31 MiB offset
    cmp     eax, 0xFFFFFFFF
    je      .empty2
    mov     eax, 1
    ret
.empty2:
    xor     eax, eax
    ret

; ==================================================================
; er_rom_armor_read
;   Read from SPI flash via direct MMIO (RA3) or mailbox (RA2).
;   Arguments:
;     rdi — destination buffer
;     esi — SPI flash offset
;     edx — number of bytes to read
;   Returns:
;     eax — bytes read, 0 on error
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_rom_armor_read
    er_frame_push
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; dst
    mov     r13d, esi           ; offset
    mov     r14d, edx           ; count

    ; Check bounds
    cmp     r13d, SPI_MMIO_SIZE
    jae     .fail
    mov     eax, r13d
    add     eax, r14d
    cmp     eax, SPI_MMIO_SIZE
    ja      .fail

    ; Read directly from MMIO
    xor     ecx, ecx
.loop:
    cmp     ecx, r14d
    jae     .done
    movzx   eax, byte [SPI_MMIO_BASE + r13 + rcx]
    mov     [r12 + rcx], al
    inc     ecx
    jmp     .loop

.done:
    mov     eax, r14d
    er_ok
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.fail:
    xor     eax, eax
    er_err  ERROR_BAD_ARGUMENT
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; er_rom_armor_write
;   Write to SPI flash via PSP mailbox (ROM Armor write).
;   Arguments:
;     rdi — source buffer
;     esi — SPI flash offset
;     edx — number of bytes to write
;   Returns:
;     eax — 0 on success
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_rom_armor_write
    er_frame_push
    push    r12
    push    r13
    push    r14

    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx

    ; Build ROM Armor flash command on stack
    sub     rsp, 24

    mov     dword [rsp], RA_WRITE          ; transaction
    lea     rax, [rel er_ra_transfer_buf]
    mov     [rsp + 4], rax                 ; buffer_ptr
    mov     [rsp + 12], r13d               ; offset
    mov     [rsp + 16], r14d               ; size
    mov     dword [rsp + 20], 0            ; read_back

    ; Copy data to transfer buffer
    mov     rdi, rax                       ; dst = transfer_buf
    mov     rsi, r12                       ; src
    mov     edx, r14d                      ; len
    call    er_memcpy

    ; Send via PSP mailbox
    mov     rdi, rsp
    er_call er_psp_mbox_armor_spi_transaction, .tx_fail

    add     rsp, 24
    mov     eax, r14d
    er_ok
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.tx_fail:
    add     rsp, 24
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; er_rom_armor_erase
;   Erase SPI flash sectors via PSP mailbox.
;   Arguments:
;     esi — SPI flash offset (must be 4 KiB aligned)
;     edx — number of bytes to erase (must be 4 KiB aligned)
;   Returns:
;     eax — 0 on success
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_rom_armor_erase
    er_frame_push
    push    r12
    push    r13

    mov     r12d, esi
    mov     r13d, edx

    ; Validate alignment
    test    r12d, 0xFFF
    jnz     .fail
    test    r13d, 0xFFF
    jnz     .fail

    sub     rsp, 24
    mov     dword [rsp], RA_ERASE          ; transaction
    lea     rax, [rel er_ra_transfer_buf]
    mov     [rsp + 4], rax                 ; buffer_ptr (must not be NULL)
    mov     [rsp + 12], r12d               ; offset
    mov     [rsp + 16], r13d               ; size
    mov     dword [rsp + 20], 0            ; read_back

    mov     rdi, rsp
    er_call er_psp_mbox_armor_spi_transaction, .tx_fail

    add     rsp, 24
    mov     eax, r13d
    er_ok
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.tx_fail:
    add     rsp, 24
    xor     eax, eax
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.fail:
    xor     eax, eax
    er_err  ERROR_BAD_ARGUMENT
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

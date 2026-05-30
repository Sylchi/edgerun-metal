; EdgeRun AMD PSP Gen2 Mailbox driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Communicates with the Platform Security Processor (PSP) via SMN-accessible
; mailbox registers. Used to query ROM Armor state and perform SPI flash
; operations when the SPI controller is locked.
;
; PSP Gen2 mailbox (SMN):
;   Base:       SMN_PSP_PUBLIC_BASE = 0x3800000
;   CMD reg:    base + 0x10570 (4 bytes)
;   BUF reg:    base + 0x10574 (8 bytes)
;
; Reference: coreboot src/soc/amd/common/block/psp/psp_gen2.c
;            coreboot src/soc/amd/common/block/psp/psp_def.h

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_smn_read32
extern er_smn_write32

; ─── PSP SMN base ─────────────────────────────────────────────────
PSP_SMN_BASE      equ 0x3800000

; ─── Mailbox register offsets (relative to PSP_SMN_BASE) ─────────
PSP_MBOX_CMD      equ 0x10570    ; command/status (4 bytes)
PSP_MBOX_BUF      equ 0x10574    ; buffer pointer (8 bytes)

; ─── Command register bit fields ───────────────────────────────────
MBOX_READY        equ (1 << 31)   ; bit 31: PSP ready for command
MBOX_RECOVERY     equ (1 << 30)   ; bit 30: recovery mode
MBOX_CMD_SHIFT    equ 16          ; bits 16-23: command byte
MBOX_STS_MASK     equ 0xFFFF      ; bits 0-15: response status

; ─── BIOS-to-PSP command codes ────────────────────────────────────
MBOX_CMD_HSTI_QUERY         equ 0x14
MBOX_CMD_ARMOR_ENFORCE      equ 0x50
MBOX_CMD_ARMOR_SPI_TRANS    equ 0x51
MBOX_CMD_NOP                equ 0x09

; ─── HSTI state bits ───────────────────────────────────────────────
HSTI_ROM_ARMOR_ENFORCED     equ (1 << 11)

; ─── ROM Armor transaction types ───────────────────────────────────
RA_READ    equ 1
RA_WRITE   equ 2
RA_ERASE   equ 3

; ─── Timeout (loop iterations) ─────────────────────────────────────
MAILBOX_TIMEOUT     equ 10000000    ; ~3ms at 3 GHz, ~3s on QEMU

; ─── Buffer sizes and offsets ─────────────────────────────────────
MBOX_HDR_SIZE       equ 8
HSTI_BUF_TOTAL      equ 32
ENFORCE_BUF_TOTAL   equ 32
SPI_CMD_TOTAL       equ 32

SPI_CMD_TRANSACTION equ 8
SPI_CMD_BUFPTR      equ 12
SPI_CMD_OFFSET      equ 20
SPI_CMD_SIZE        equ 24
SPI_CMD_READ_BACK   equ 28

SECTION .bss
global er_psp_mbox_buffer
er_psp_mbox_buffer: resb 64    ; 2x 32-byte buffer slots

SECTION .text

; ==================================================================
; Internal: wait for PSP mailbox ready or command-complete
;   r12 — 0 = wait for command-complete, non-zero = wait for ready
; Returns:
;   eax — 0 on success, ERROR_TIMEOUT on timeout
;   rdx — 0 on success, ERROR_TIMEOUT on timeout
; ==================================================================
_psp_mbox_wait:
    push    r12
    mov     r12, rdi           ; save wait mode
    mov     ecx, MAILBOX_TIMEOUT

    ; Quick probe: read the register once. If it reads all-0 or all-1,
    ; the PSP mailbox is not accessible (no hardware or locked).
    mov     edi, PSP_SMN_BASE | PSP_MBOX_CMD
    call    er_smn_read32
    cmp     eax, 0xFFFFFFFF
    je      .no_hw
    test    eax, eax
    jz      .no_hw

    ; Register looks plausible — continue polling
.loop:
    test    r12, r12
    jnz     .wait_ready

    ; Wait for command-complete: command byte (bits 16-23) must be 0
    test     eax, 0x00FF0000
    jz      .done

.wait_ready:
    ; Wait for ready bit (31)
    test    eax, MBOX_READY
    jnz     .done

    mov     edi, PSP_SMN_BASE | PSP_MBOX_CMD
    call    er_smn_read32

    dec     ecx
    jnz     .loop

    mov     eax, ERROR_TIMEOUT
    er_err  ERROR_TIMEOUT
    pop     r12
    ret

.no_hw:
    mov     eax, ERROR_NOT_PRESENT
    er_err  ERROR_NOT_PRESENT
    pop     r12
    ret

.done:
    xor     eax, eax
    er_ok
    pop     r12
    ret

; ==================================================================
; er_psp_mbox_send
;   Send a command to PSP via Gen2 SMN mailbox.
;   Arguments:
;     edi — command code
;   The command buffer at er_psp_mbox_buffer must be filled before call.
; Returns:
;   eax — 0 on success
;   rdx — 0 on success, non-zero error on failure
; ==================================================================
er_fn er_psp_mbox_send
    er_frame_push
    push    r12
    push    r13

    mov     r12d, edi           ; save command
    lea     r13, [rel er_psp_mbox_buffer]

    ; 1. Wait for PSP ready
    mov     rdi, 1
    call    _psp_mbox_wait
    test    edx, edx
    jnz     .fail

    ; 2. Write buffer pointer (low 32 bits)
    mov     edi, PSP_SMN_BASE | PSP_MBOX_BUF
    mov     esi, r13d
    call    er_smn_write32

    ; 3. Write buffer pointer (high 32 bits = 0, fits in 4GB)
    mov     edi, (PSP_SMN_BASE | PSP_MBOX_BUF) + 4
    xor     esi, esi
    call    er_smn_write32

    ; 4. Read current command register to preserve recovery bit
    mov     edi, PSP_SMN_BASE | PSP_MBOX_CMD
    call    er_smn_read32
    and     eax, MBOX_RECOVERY | MBOX_STS_MASK
    mov     ecx, r12d
    shl     ecx, MBOX_CMD_SHIFT
    or      eax, ecx
    and     eax, 0x7FFFFFFF          ; ~MBOX_READY

    ; 5. Write command register
    mov     edi, PSP_SMN_BASE | PSP_MBOX_CMD
    mov     esi, eax
    call    er_smn_write32

    ; 6. Wait for command to complete
    xor     rdi, rdi
    call    _psp_mbox_wait
    test    edx, edx
    jnz     .fail

    ; 7. Read response status
    mov     edi, PSP_SMN_BASE | PSP_MBOX_CMD
    call    er_smn_read32
    and     eax, MBOX_STS_MASK
    test    eax, eax
    jnz     .cmd_err

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.cmd_err:
    er_err  ERROR_IO
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.fail:
    er_err  ERROR_TIMEOUT
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; er_psp_mbox_nop
;   Send NOP — test mailbox access.
; ==================================================================
er_fn er_psp_mbox_nop
    er_frame_push
    lea     r12, [rel er_psp_mbox_buffer]
    mov     dword [r12], HSTI_BUF_TOTAL
    mov     dword [r12 + 4], 0
    mov     edi, MBOX_CMD_NOP
    call    er_psp_mbox_send
    er_frame_pop
    er_ret

; ==================================================================
; er_psp_mbox_hsti_query
;   Query HSTI state — check ROM Armor enforcement.
;   Arguments: none
;   Returns:
;     eax — HSTI state bits (0 on failure)
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_psp_mbox_hsti_query
    er_frame_push
    push    r12

    lea     r12, [rel er_psp_mbox_buffer]
    mov     dword [r12], HSTI_BUF_TOTAL
    mov     dword [r12 + 4], 0

    mov     edi, MBOX_CMD_HSTI_QUERY
    call    er_psp_mbox_send
    test    edx, edx
    jnz     .fail

    mov     eax, [r12 + 8]
    er_ok
    pop     r12
    er_frame_pop
    er_ret

.fail:
    xor     eax, eax
    er_err  ERROR_IO
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; er_psp_mbox_armor_spi_transaction
;   Send a ROM Armor SPI transaction to the PSP.
;   Arguments:
;     rdi — pointer to mbox_rom_armor_flash_command struct
;   Returns:
;     eax — 0 on success
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_psp_mbox_armor_spi_transaction
    er_frame_push
    push    r12
    push    r13

    mov     r13, rdi
    lea     r12, [rel er_psp_mbox_buffer]

    mov     dword [r12], SPI_CMD_TOTAL       ; header.size
    mov     dword [r12 + 4], 0                ; header.status

    ; Copy command struct into buffer
    mov     eax, [r13 + 0]                    ; transaction
    mov     [r12 + SPI_CMD_TRANSACTION], eax
    mov     rax, [r13 + 4]                    ; buffer_ptr
    mov     [r12 + SPI_CMD_BUFPTR], rax
    mov     eax, [r13 + 12]                   ; offset
    mov     [r12 + SPI_CMD_OFFSET], eax
    mov     eax, [r13 + 16]                   ; size
    mov     [r12 + SPI_CMD_SIZE], eax
    mov     eax, [r13 + 20]                   ; read_back
    mov     [r12 + SPI_CMD_READ_BACK], eax

    mov     edi, MBOX_CMD_ARMOR_SPI_TRANS
    call    er_psp_mbox_send
    test    edx, edx
    jnz     .fail

    ; Check buffer status field
    mov     eax, [r12 + 4]
    test    eax, eax
    jnz     .buf_err

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.buf_err:
    er_err  ERROR_IO
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

.fail:
    er_err  ERROR_TIMEOUT
    pop     r13
    pop     r12
    er_frame_pop
    er_ret

; ==================================================================
; er_psp_mbox_armor_enforce
;   Send ARMOR_ENTER_SMM_MODE to enable ROM Armor.
;   Arguments:
;     edi — capsule_update flag (0 or 1)
;   Returns:
;     eax — flash_size (0 on failure)
;     rdx — 0 on success, error code on failure
; ==================================================================
er_fn er_psp_mbox_armor_enforce
    er_frame_push
    push    r12

    lea     r12, [rel er_psp_mbox_buffer]
    mov     dword [r12], ENFORCE_BUF_TOTAL
    mov     dword [r12 + 4], 0
    mov     dword [r12 + 8], 0                 ; flash_size (output)
    mov     [r12 + 12], edi                   ; capsule_update (input)

    mov     edi, MBOX_CMD_ARMOR_ENFORCE
    call    er_psp_mbox_send
    test    edx, edx
    jnz     .fail

    mov     eax, [r12 + 8]                    ; flash_size
    er_ok
    pop     r12
    er_frame_pop
    er_ret

.fail:
    xor     eax, eax
    er_err  ERROR_IO
    pop     r12
    er_frame_pop
    er_ret

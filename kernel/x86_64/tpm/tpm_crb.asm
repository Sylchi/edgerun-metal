; EdgeRun TPM2 CRB (Command Response Buffer) MMIO driver
;
; Talks to TPM 2.0 CRB interface at a fixed MMIO address
; (0xFED40000 for QEMU swtpm with -tpmdev passthrough).

%include "x86_64/macros.inc"

; ─── CRB register offsets (from base) ─────────────────────────────────
%define CRB_BASE                0xFED40000

; CRB register offsets per TCG PTP spec (QEMU hw/acpi/tpm.h layout)
%define CRB_LOC_STATE           0x0000
%define CRB_LOC_CTRL            0x0008
%define CRB_LOC_STS             0x000C
%define CRB_INTF_ID             0x0030
%define CRB_INTF_ID2            0x0034
%define CRB_CTRL_EXT            0x0038
%define CRB_CTRL_REQ            0x0040
%define CRB_CTRL_STS            0x0044
%define CRB_CTRL_CANCEL         0x0048
%define CRB_CTRL_START          0x004C
%define CRB_CTRL_CMD_SIZE       0x0058
%define CRB_CTRL_CMD_LADDR      0x005C
%define CRB_CTRL_CMD_HADDR      0x0060
%define CRB_CTRL_RSP_SIZE       0x0064
%define CRB_CTRL_RSP_ADDR       0x0068
%define CRB_DATA_BUFFER         0x0080

; Bit definitions
%define CRB_LOC_CTRL_REQUEST_ACCESS  0x01
%define CRB_CTRL_REQ_CMD_READY       0x01
%define CRB_CTRL_REQ_GO_IDLE        0x02
%define CRB_CTRL_START_INVOKE       0x01
%define CRB_CTRL_STS_TPM_IDLE       0x02

; ==================================================================
; MMIO read (32-bit) — inline sequence
; =================================================================
%macro crb_mmio_read32 2
    mov     %2, dword [%1]
%endmacro

; ==================================================================
; MMIO write (32-bit) — inline sequence
; =================================================================
%macro crb_mmio_write32 2
    mov     dword [%1], %2
%endmacro

; ==================================================================
; Wait for CRB_CTRL_START bit 0 (INVOKE) to clear (command complete)
; rdi = CRB base address
; Returns: rax = 0 on timeout, 1 on success
; =================================================================
er_fn er_tpm_crb_wait_start
    mov     ecx, 20000000

.loop:
    crb_mmio_read32 rdi + CRB_CTRL_START, eax
    test    eax, CRB_CTRL_START_INVOKE
    jz      .done
    pause
    dec     ecx
    jnz     .loop
    xor     eax, eax
    ret

.done:
    mov     eax, 1
    ret

; ==================================================================
; Send command buffer to CRB and receive response
; rdi = command buffer (source)
; esi = command size
; rdx = response buffer (destination)
; ecx = response buffer max size
; Returns: rax = response size on success, 0 on error
;
; Sequence:
;   1. Request locality 0 (LOC_CTRL ← REQUEST_ACCESS)
;   2. CMD_READY (CTRL_REQ ← CMD_READY)
;   3. Copy command to CRB_DATA_BUFFER (cmdmem is RAM)
;   4. Write command size to CRB_CTRL_CMD_SIZE
;   5. INVOKE (CTRL_START ← INVOKE)
;   6. Wait for completion (CTRL_START bit 0 clears)
;   7. Read response header from cmdmem via rep movsb
;   8. Extract big-endian size from header, copy response
;   9. GO_IDLE (CTRL_REQ ← GO_IDLE)
; =================================================================
er_fn er_tpm_crb_transfer
    er_check_zero rdi, .err
    er_check_zero esi, .err
    er_check_zero rdx, .err
    er_check_zero ecx, .err

    er_push rbx, r12, r13, r14, r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx

    ; Load CRB base into rbx for register-indirect MMIO access
    ; (direct [CRB_BASE + offset] in 64-bit mode sign-extends to a high
    ;  unmapped address due to disp32 sign-extension in long mode)
    mov     ebx, CRB_BASE

    ; Step 1: Request locality 0
    mov     dword [rbx + CRB_LOC_CTRL], CRB_LOC_CTRL_REQUEST_ACCESS

    ; Step 2: CMD_READY
    mov     dword [rbx + CRB_CTRL_REQ], CRB_CTRL_REQ_CMD_READY

    ; Step 3: Copy command to DATA_BUFFER
    lea     rdi, [rbx + CRB_DATA_BUFFER]
    mov     rsi, r12
    mov     rcx, r13
    rep     movsb

    ; Step 4: Write command size
    mov     dword [rbx + CRB_CTRL_CMD_SIZE], r13d

    ; Step 5: INVOKE
    mov     dword [rbx + CRB_CTRL_START], CRB_CTRL_START_INVOKE

    ; Step 6: Wait for completion
    mov     rdi, rbx
    call    er_tpm_crb_wait_start
    er_check_zero eax, .err_pop

    ; Step 7: Read response header from cmdmem via rep movsb
    sub     rsp, 16
    mov     rdi, rsp
    lea     rsi, [rbx + CRB_DATA_BUFFER]
    mov     rcx, 8
    rep     movsb

    ; Step 8: Extract response size from header (big-endian at offset +2)
    xor     edx, edx
    mov     dl, [rsp + 2]
    shl     edx, 8
    mov     dl, [rsp + 3]
    shl     edx, 8
    mov     dl, [rsp + 4]
    shl     edx, 8
    mov     dl, [rsp + 5]
    add     rsp, 16

    er_check_zero edx, .err_pop
    cmp     edx, r15d
    ja      .err_pop

    ; Copy response from DATA_BUFFER to output buffer
    lea     rsi, [rbx + CRB_DATA_BUFFER]
    mov     rdi, r14
    mov     rcx, rdx
    rep     movsb

    ; Step 9: GO_IDLE
    mov     dword [rbx + CRB_CTRL_REQ], CRB_CTRL_REQ_GO_IDLE

    mov     eax, edx

.pop:
    er_pop_ret rbx, r12, r13, r14, r15

.err_pop:
    xor     eax, eax
    jmp     .pop

.err:
    xor     eax, eax
    ret

; ==================================================================
; Check if CRB TPM is present and responsive
; Returns: rax = 1 if CRB interface detected, 0 otherwise
; =================================================================
er_fn er_tpm_crb_present
    mov     edi, CRB_BASE
    mov     eax, [rdi + CRB_INTF_ID]
    er_check_zero eax, .not_found
    test    eax, 0x11
    jz      .not_found
    mov     eax, 1
    ret

.not_found:
    xor     eax, eax
    ret

; ==================================================================
; Simple TPM2 CRB command: build, send, receive in one call
; rdi = command buffer
; esi = command size
; rdx = response buffer
; ecx = response max size
; Returns: rax = response size, 0 on error
; =================================================================
er_fn er_tpm_crb_command
    jmp     er_tpm_crb_transfer

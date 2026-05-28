; EdgeRun TPM2 CRB (Command Response Buffer) MMIO driver
;
; Talks to TPM 2.0 CRB interface at a fixed MMIO address
; (0xFED40000 for QEMU swtpm with -tpmdev passthrough).

%include "x86_64/macros.inc"

; ─── CRB register offsets (from base) ─────────────────────────────────
%define CRB_BASE                0xFED40000

%define CRB_LOC_STATE           0x0000
%define CRB_LOC_CTRL            0x0004
%define CRB_LOC_STS             0x0008
%define CRB_INTF_ID             0x0010
%define CRB_INTF_CTRL           0x0014
%define CRB_INTF_STS            0x0018
%define CRB_CTRL_EXT            0x0020
%define CRB_CTRL_REQ            0x0030
%define CRB_CTRL_CMD_SIZE       0x0034
%define CRB_CTRL_CMD_LPC        0x0038
%define CRB_CTRL_CMD_HPC        0x003C
%define CRB_CTRL_RSP_SIZE       0x0040
%define CRB_CTRL_RSP_ADDR       0x0044
%define CRB_DATA_BUFFER         0x0800

; Bit definitions
%define CRB_CTRL_REQ_CMD_READY  0x01
%define CRB_LOC_CTRL_ACQUIRE    0x01
%define CRB_LOC_STS_GRANTED     0x01
%define CRB_INTF_STS_TPM_IDLE   0x01

; ─── HOSTED_TEST mode ─────────────────────────────────────────────────
%ifdef HOSTED_TEST
; In hosted test mode, CRB operations use a memory shadow instead of MMIO.
section .bss
global er_crb_shadow
er_crb_shadow: resb 4096        ; Simulated CRB register block
%endif

; ==================================================================
; MMIO read (32-bit) — inline sequence since we alias the 64-bit helper
; =================================================================
%macro crb_mmio_read32 2
    mov     rdi, %1
    call    er_mmio_read32
    mov     %2, eax
%endmacro

; ==================================================================
; MMIO write (32-bit) — inline sequence
; =================================================================
%macro crb_mmio_write32 2
    mov     rdi, %1
    mov     esi, %2
    call    er_mmio_write32
%endmacro

; ==================================================================
; Poll CRB_CTRL_REQ until bit 0 clears (timeout = ~10ms @ 2GHz)
; rdi = CRB base address
; Returns: rax = 0 on timeout, 1 on success
; =================================================================
er_fn er_tpm_crb_wait
    mov     ecx, 20000000        ; ~10ms spin budget

.loop:
    crb_mmio_read32 rdi + CRB_CTRL_REQ, eax
    test    eax, CRB_CTRL_REQ_CMD_READY
    jz      .done

    pause
    dec     ecx
    jnz     .loop

    xor     eax, eax             ; timeout
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
; CRB transfer sequence:
;   1. Copy command to CRB_DATA_BUFFER
;   2. Write command size to CRB_CTRL_CMD_SIZE
;   3. Write GO bit to CRB_CTRL_REQ
;   4. Poll CRB_CTRL_REQ until clear
;   5. Read response from CRB_DATA_BUFFER
; =================================================================
er_fn er_tpm_crb_transfer
    ; Validate parameters
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    rdx, rdx
    jz      .err
    test    ecx, ecx
    jz      .err

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi             ; r12 = command buffer
    mov     r13d, esi            ; r13d = command size
    mov     r14, rdx             ; r14 = response buffer
    mov     r15d, ecx            ; r15d = response max size

%ifndef HOSTED_TEST
    mov     rdi, CRB_BASE + CRB_DATA_BUFFER
    mov     rsi, r12
    mov     rcx, r13
    rep     movsb

    ; Write command size to CRB_CTRL_CMD_SIZE
    mov     edi, CRB_BASE + CRB_CTRL_CMD_SIZE
    mov     esi, r13d
    call    er_mmio_write32

    ; Write GO bit to CRB_CTRL_REQ
    mov     edi, CRB_BASE + CRB_CTRL_REQ
    mov     esi, CRB_CTRL_REQ_CMD_READY
    call    er_mmio_write32

    ; Poll for completion
    mov     rdi, CRB_BASE
    call    er_tpm_crb_wait
    test    eax, eax
    jz      .err_pop

    ; Read response size from CRB_CTRL_RSP_SIZE
    mov     edi, CRB_BASE + CRB_CTRL_RSP_SIZE
    call    er_mmio_read32
    mov     ebx, eax

    ; Validate response size
    test    ebx, ebx
    jz      .err_pop
    cmp     ebx, r15d
    ja      .err_pop

    ; Copy response from CRB_DATA_BUFFER to output buffer
    mov     rsi, CRB_BASE + CRB_DATA_BUFFER
    mov     rdi, r14
    mov     rcx, rbx
    rep     movsb

    mov     eax, ebx             ; return response size

%else
    ; HOSTED_TEST: simulate CRB transfer using shadow buffer.
    ; Copy command to shadow DATA_BUFFER, then simulate a response.
    ; For testing, we set up a known response in the shadow buffer
    ; and copy it back.
    push    rdx
    mov     rdi, er_crb_shadow + CRB_DATA_BUFFER
    mov     rsi, r12
    mov     rcx, r13
    rep     movsb
    pop     rdx

    ; Simulate response: copy shadow DATA_BUFFER to output
    ; (the test must pre-fill the shadow response)
    mov     rsi, er_crb_shadow + CRB_DATA_BUFFER
    mov     rdi, r14
    mov     rcx, r15
    rep     movsb

    ; Return response size (from shadow RSP_SIZE or default to max)
    mov     eax, r15d
%endif

.pop:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

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
%ifndef HOSTED_TEST
    ; Read CRB_INTF_ID to check interface
    mov     edi, CRB_BASE + CRB_INTF_ID
    call    er_mmio_read32

    ; CRB_INTF_ID bits:
    ;   [0:3]   = interface version (must be >= 1)
    ;   [4:7]   = interface type (0 = TPM 1.2, 1 = TPM 2.0)
    ;   [16:23] = vendor ID
    test    eax, eax
    jz      .not_found

    ; Check TPM 2.0 (bit 4 = 1)
    test    eax, 0x10
    jz      .not_found

    mov     eax, 1
    ret

.not_found:
    xor     eax, eax
    ret
%else
    ; Hosted test: assume present
    mov     eax, 1
    ret
%endif

; ==================================================================
; Simple TPM2 CRB command: build, send, receive in one call
; rdi = command buffer
; esi = command size
; rdx = response buffer
; ecx = response max size
; Returns: rax = response size, 0 on error
; =================================================================
er_fn er_tpm_crb_command
    ; Delegate to er_tpm_crb_transfer
    jmp     er_tpm_crb_transfer

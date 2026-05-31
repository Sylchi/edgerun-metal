; EdgeRun High Definition Audio controller probe — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "driver/pci_constants.inc"
%include "x86_64/wasm_defines.inc"

extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32
extern er_mmio_write32

%define HDA_CLASS       0x04
%define HDA_SUBCLASS    0x03
%define HDA_PROGIF      0x00

%define HDA_REG_GCAP    0x00
%define HDA_REG_GCTL    0x08
%define HDA_REG_STATESTS_DWORD 0x0C
%define HDA_REG_ICOI    0x60
%define HDA_REG_ICII    0x64
%define HDA_REG_ICIS    0x68
%define HDA_GCTL_CRST   1
%define HDA_ICIS_ICB    1
%define HDA_ICIS_IRV    2
%define HDA_VERB_GET_PARAMETER 0xF00
%define HDA_PARAM_VENDOR_ID    0x00

SECTION .text

; ==================================================================
; er_hda_probe_init — locate and minimally reset an HDA-compatible PCI fn
; int er_hda_probe_init(uint8_t bus, uint8_t dev, uint8_t func,
;                       uint32_t* out_bar0, uint32_t* out_gcap,
;                       uint32_t* out_statests)
; Returns eax=0 when the controller MMIO responds and reset bit sticks.
; ==================================================================
er_fn er_hda_probe_init
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, edi           ; bus
    mov     r13d, esi           ; dev
    mov     r14d, edx           ; func
    mov     r15, rcx            ; out_bar0
    mov     rbx, r8             ; out_gcap
    mov     rbp, r9             ; out_statests
    test    r15, r15
    jz      .bad_arg
    test    rbx, rbx
    jz      .bad_arg
    test    rbp, rbp
    jz      .bad_arg

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .absent

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, 0x08
    call    er_pci_read32
    shr     eax, 8
    movzx   edx, al
    movzx   ecx, ah
    shr     eax, 16
    cmp     al, HDA_CLASS
    jne     .absent
    cmp     cl, HDA_SUBCLASS
    jne     .absent
    cmp     dl, HDA_PROGIF
    jne     .absent

    ; Enable memory decoding and bus mastering before MMIO access.
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_read32
    or      eax, PCI_CMD_MEM_SPACE | PCI_CMD_BUS_MASTER
    mov     r8d, eax
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    and     eax, ~0x0F
    test    eax, eax
    jz      .absent
    mov     [r15], eax

    mov     edi, [r15]
    add     edi, HDA_REG_GCAP
    call    er_mmio_read32
    movzx   eax, ax
    test    eax, eax
    jz      .absent
    mov     [rbx], eax

    ; Bring controller out of reset and wait for CRST to read back as 1.
    mov     edi, [r15]
    add     edi, HDA_REG_GCTL
    mov     esi, HDA_GCTL_CRST
    call    er_mmio_write32
    mov     ecx, 200000
.wait_crst:
    mov     edi, [r15]
    add     edi, HDA_REG_GCTL
    call    er_mmio_read32
    test    eax, HDA_GCTL_CRST
    jnz     .crst_ready
    dec     ecx
    jnz     .wait_crst
    jmp     .timeout
.crst_ready:
    mov     edi, [r15]
    add     edi, HDA_REG_STATESTS_DWORD
    call    er_mmio_read32
    shr     eax, 16
    and     eax, 0x7FFF
    mov     [rbp], eax
    xor     eax, eax
    er_ok
    jmp     .out

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .out
.absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    jmp     .out
.timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.out:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _hda_first_codec — return first codec address present in STATESTS.
; edi=statests. Returns eax=codec address or -1.
_hda_first_codec:
    xor     eax, eax
.fc_loop:
    cmp     eax, 15
    jae     .fc_absent
    mov     edx, edi
    mov     ecx, eax
    shr     edx, cl
    test    edx, 1
    jnz     .fc_found
    inc     eax
    jmp     .fc_loop
.fc_found:
    ret
.fc_absent:
    mov     eax, -1
    ret

; ==================================================================
; er_hda_codec_vendor_id — send immediate GET_PARAMETER(Vendor ID)
; int er_hda_codec_vendor_id(uint32_t bar0, uint32_t statests,
;                            uint32_t* out_vendor_id)
; Uses the first present codec address from STATESTS.
; ==================================================================
er_fn er_hda_codec_vendor_id
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi           ; bar0
    mov     r13d, esi           ; statests
    mov     rbx, rdx            ; out_vendor_id
    test    r12d, r12d
    jz      .cv_bad_arg
    test    r13d, r13d
    jz      .cv_absent
    test    rbx, rbx
    jz      .cv_bad_arg

    mov     edi, r13d
    call    _hda_first_codec
    cmp     eax, -1
    je      .cv_absent

    ; Command: codec address, root node 0, GET_PARAMETER, Vendor ID.
    shl     eax, 28
    mov     ecx, HDA_VERB_GET_PARAMETER
    shl     ecx, 8
    or      eax, ecx
    or      eax, HDA_PARAM_VENDOR_ID
    mov     r13d, eax

    mov     ecx, 200000
.cv_wait_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jz      .cv_idle
    dec     ecx
    jnz     .cv_wait_idle
    jmp     .cv_timeout
.cv_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICOI
    mov     esi, r13d
    call    er_mmio_write32

    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_ICB
    call    er_mmio_write32

    mov     ecx, 200000
.cv_wait_done:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jnz     .cv_spin
    test    eax, HDA_ICIS_IRV
    jnz     .cv_have_response
.cv_spin:
    dec     ecx
    jnz     .cv_wait_done
    jmp     .cv_timeout
.cv_have_response:
    mov     edi, r12d
    add     edi, HDA_REG_ICII
    call    er_mmio_read32
    mov     [rbx], eax
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_IRV
    call    er_mmio_write32
    xor     eax, eax
    er_ok
    jmp     .cv_out

.cv_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .cv_out
.cv_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    jmp     .cv_out
.cv_timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.cv_out:
    pop     r13
    pop     r12
    pop     rbx
    ret

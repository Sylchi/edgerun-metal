; EdgeRun Intel AX210 bring-up scaffold — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/pci_constants.inc"

extern er_pci_find_device
extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32

%define AX210_VENDOR 0x8086
%define AX210_DEVICE 0x2725
%define IWL_HDR_MAGIC0 0x00000000
%define IWL_HDR_MAGIC1 0x0A4C5749    ; "IWL\n" little-endian
%define AX210_FW_MIN_SIZE 64
%define AX210_FW_TLV_OFF  0x50

SECTION .text

; ==================================================================
; er_ax210_probe_init — detect AX210 and perform PCI function enable
; int er_ax210_probe_init(uint8_t* out_bus, uint8_t* out_dev,
;                         uint8_t* out_func, uint64_t* out_bar0)
;
; If present, enables PCI memory space + bus mastering and returns BAR0.
; Returns: eax = 1 if AX210 present, 0 if absent
; ==================================================================
er_fn er_ax210_probe_init
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx

    mov     r12, rdi            ; out_bus
    mov     r13, rsi            ; out_dev
    mov     r14, rdx            ; out_func
    mov     r15, rcx            ; out_bar0

    mov     rdi, AX210_VENDOR
    mov     rsi, AX210_DEVICE
    mov     rdx, r12
    mov     rcx, r13
    mov     r8,  r14
    call    er_pci_find_device
    test    eax, eax
    jz      .absent

    movzx   ebx, byte [r12]     ; bus
    movzx   r10d, byte [r13]    ; dev
    movzx   r11d, byte [r14]    ; func

    ; Enable memory space + bus master for MMIO access/DMA.
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_COMMAND
    call    er_pci_read32
    or      eax, PCI_CMD_MEM_SPACE | PCI_CMD_BUS_MASTER
    mov     r8, rax
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    ; Read BAR0/BAR1 and synthesize masked BAR0 base.
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    mov     r9d, eax
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_BAR1
    call    er_pci_read32
    shl     rax, 32
    mov     r9d, r9d
    or      r9, rax
    and     r9, ~0x0F

    test    r15, r15
    jz      .present
    mov     [r15], r9

.present:
    mov     eax, 1
    er_ok
    jmp     .out

.absent:
    xor     eax, eax
    er_ok

.out:
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_ax210_fw_ingest — register a caller-provided AX210 firmware blob
; int er_ax210_fw_ingest(const void* fw_ptr, uint64_t fw_size)
;
; Performs minimal container validation:
;   - non-null pointer
;   - size >= AX210_FW_MIN_SIZE
;   - dword0 == 0 and dword1 == "IWL\n"
;
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_ax210_fw_ingest
    test    rdi, rdi
    jz      .bad_arg
    cmp     rsi, AX210_FW_MIN_SIZE
    jb      .bad_arg

    mov     eax, dword [rdi]
    cmp     eax, IWL_HDR_MAGIC0
    jne     .bad_blob
    mov     eax, dword [rdi + 4]
    cmp     eax, IWL_HDR_MAGIC1
    jne     .bad_blob

    mov     [ax210_fw_ptr], rdi
    mov     [ax210_fw_size], rsi
    er_ok
    xor     eax, eax
    ret

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.bad_blob:
    er_err  ERROR_CORRUPT
    mov     eax, -1
    ret

; ==================================================================
; er_ax210_fw_get_blob — fetch previously ingested firmware blob
; int er_ax210_fw_get_blob(uint64_t* out_ptr, uint64_t* out_size)
;
; Returns: eax = 0 on success, -1 if blob is not registered.
; ==================================================================
er_fn er_ax210_fw_get_blob
    test    rdi, rdi
    jz      .get_bad_arg
    test    rsi, rsi
    jz      .get_bad_arg
    mov     rax, [ax210_fw_ptr]
    test    rax, rax
    jz      .not_ready
    mov     [rdi], rax
    mov     rax, [ax210_fw_size]
    mov     [rsi], rax
    er_ok
    xor     eax, eax
    ret

.get_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.not_ready:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

; ==================================================================
; er_ax210_fw_prepare_upload — validate and walk firmware TLV records
; int er_ax210_fw_prepare_upload(void)
;
; This is a transport-independent preparation step. It parses TLV headers
; with strict bounds checking and records summary stats for later upload.
;
; Returns: eax = 0 on success, -1 on parse/availability failure
; ==================================================================
er_fn er_ax210_fw_prepare_upload
    mov     r8, [ax210_fw_ptr]
    test    r8, r8
    jz      .prep_not_ready
    mov     r9, [ax210_fw_size]
    cmp     r9, AX210_FW_TLV_OFF + 8
    jb      .prep_bad

    lea     r10, [r8 + AX210_FW_TLV_OFF]    ; cursor
    lea     r11, [r8 + r9]                  ; end
    xor     ecx, ecx                        ; tlv_count

.tlv_loop:
    mov     rax, r11
    sub     rax, r10
    cmp     rax, 8
    jb      .tlv_done

    mov     edx, dword [r10]                ; type
    mov     esi, dword [r10 + 4]            ; len
    mov     [ax210_fw_last_tlv_type], edx
    mov     [ax210_fw_last_tlv_len], esi

    mov     eax, esi
    add     eax, 8
    jc      .prep_bad
    mov     ebx, eax                        ; rec_size

    ; 4-byte alignment padding (common TLV layout)
    add     ebx, 3
    and     ebx, ~3

    mov     rax, r11
    sub     rax, r10
    cmp     rax, rbx
    jb      .prep_bad

    add     r10, rbx
    inc     ecx
    jmp     .tlv_loop

.tlv_done:
    test    ecx, ecx
    jz      .prep_bad
    mov     [ax210_fw_tlv_count], ecx
    er_ok
    xor     eax, eax
    ret

.prep_not_ready:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

.prep_bad:
    er_err  ERROR_CORRUPT
    mov     eax, -1
    ret

; ==================================================================
; er_ax210_fw_get_tlv_stats — read parsed firmware TLV summary
; int er_ax210_fw_get_tlv_stats(uint32_t* out_count, uint32_t* out_last_type,
;                               uint32_t* out_last_len)
; ==================================================================
er_fn er_ax210_fw_get_tlv_stats
    test    rdi, rdi
    jz      .stats_bad
    test    rsi, rsi
    jz      .stats_bad
    test    rdx, rdx
    jz      .stats_bad
    mov     eax, [ax210_fw_tlv_count]
    test    eax, eax
    jz      .stats_bad
    mov     [rdi], eax
    mov     eax, [ax210_fw_last_tlv_type]
    mov     [rsi], eax
    mov     eax, [ax210_fw_last_tlv_len]
    mov     [rdx], eax
    er_ok
    xor     eax, eax
    ret

.stats_bad:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; ==================================================================
; er_ax210_mmio_probe — read a stable MMIO dword as liveness signal
; int er_ax210_mmio_probe(uint64_t bar0, uint32_t* out_val)
;
; Reads BAR0+0x0. Rejects all-zeros or all-ones as invalid probe values.
; Returns: eax = 0 on success, -1 on failure.
; ==================================================================
er_fn er_ax210_mmio_probe
    test    rdi, rdi
    jz      .mmio_bad_arg
    test    rsi, rsi
    jz      .mmio_bad_arg
    call    er_mmio_read32
    cmp     eax, 0
    je      .mmio_bad
    cmp     eax, 0xFFFFFFFF
    je      .mmio_bad
    mov     [rsi], eax
    er_ok
    xor     eax, eax
    ret

.mmio_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.mmio_bad:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

SECTION .bss
ax210_fw_ptr:  resq 1
ax210_fw_size: resq 1
ax210_fw_tlv_count: resd 1
ax210_fw_last_tlv_type: resd 1
ax210_fw_last_tlv_len: resd 1

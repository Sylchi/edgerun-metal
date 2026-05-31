; EdgeRun Intel AX210 bring-up scaffold — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/pci_constants.inc"

extern er_pci_find_device
extern er_pci_read32
extern er_pci_write32

%define AX210_VENDOR 0x8086
%define AX210_DEVICE 0x2725
%define IWL_HDR_MAGIC0 0x00000000
%define IWL_HDR_MAGIC1 0x0A4C5749    ; "IWL\n" little-endian
%define AX210_FW_MIN_SIZE 64

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

SECTION .bss
ax210_fw_ptr:  resq 1
ax210_fw_size: resq 1

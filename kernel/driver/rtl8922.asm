; EdgeRun Realtek RTL8922AE bring-up scaffold — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/pci_constants.inc"

extern er_pci_find_device
extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32

%define RTL8922_VENDOR 0x10EC
%define RTL8922_DEVICE 0x8922
%define RTL8922_FW_MIN_SIZE 256

SECTION .text

; int er_rtl8922_probe_init(uint8_t* out_bus, uint8_t* out_dev,
;                           uint8_t* out_func, uint64_t* out_bar_mmio)
; Returns eax=1 present, eax=0 absent.
er_fn er_rtl8922_probe_init
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    mov     rdi, RTL8922_VENDOR
    mov     rsi, RTL8922_DEVICE
    mov     rdx, r12
    mov     rcx, r13
    mov     r8,  r14
    call    er_pci_find_device
    test    eax, eax
    jz      .absent

    movzx   ebx, byte [r12]
    movzx   r10d, byte [r13]
    movzx   r11d, byte [r14]

    ; Enable io + memory + bus master.
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_COMMAND
    call    er_pci_read32
    or      eax, PCI_CMD_IO_SPACE | PCI_CMD_MEM_SPACE | PCI_CMD_BUS_MASTER
    mov     r8, rax
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    ; RTL8922 exposes MMIO in BAR2 on observed hardware.
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_BAR2
    call    er_pci_read32
    mov     r9d, eax
    mov     rdi, rbx
    mov     rsi, r10
    mov     rdx, r11
    mov     ecx, PCI_BAR2 + 4
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

; int er_rtl8922_mmio_probe(uint64_t bar, uint32_t* out_val)
; Returns eax=0 success, -1 failure.
er_fn er_rtl8922_mmio_probe
    test    rdi, rdi
    jz      .bad_arg
    test    rsi, rsi
    jz      .bad_arg
    call    er_mmio_read32
    cmp     eax, 0
    je      .bad
    cmp     eax, 0xFFFFFFFF
    je      .bad
    mov     [rsi], eax
    er_ok
    xor     eax, eax
    ret

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.bad:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

; int er_rtl8922_fw_ingest(const void* fw_ptr, uint64_t fw_size)
; Minimal validation + register blob for future upload path.
er_fn er_rtl8922_fw_ingest
    test    rdi, rdi
    jz      .fw_bad_arg
    cmp     rsi, RTL8922_FW_MIN_SIZE
    jb      .fw_bad_arg
    mov     [rtl8922_fw_ptr], rdi
    mov     [rtl8922_fw_size], rsi
    er_ok
    xor     eax, eax
    ret

.fw_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; int er_rtl8922_fw_get_blob(uint64_t* out_ptr, uint64_t* out_size)
er_fn er_rtl8922_fw_get_blob
    test    rdi, rdi
    jz      .fwget_bad_arg
    test    rsi, rsi
    jz      .fwget_bad_arg
    mov     rax, [rtl8922_fw_ptr]
    test    rax, rax
    jz      .fwget_missing
    mov     [rdi], rax
    mov     rax, [rtl8922_fw_size]
    mov     [rsi], rax
    er_ok
    xor     eax, eax
    ret

.fwget_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.fwget_missing:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

SECTION .bss
rtl8922_fw_ptr:  resq 1
rtl8922_fw_size: resq 1

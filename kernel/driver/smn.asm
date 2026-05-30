; EdgeRun AMD SMN (System Management Network) access driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; SMN is an internal bus on AMD SoCs (Fabric/Data Fabric). On Phoenix/7840U,
; SMN registers are accessed indirectly via PCI config space on the GNB
; (Bus 0, Device 0, Function 0) using index/data register pair at offsets
; 0xB8 and 0xBC. Access uses PCI IO ports 0xCF8/0xCFC.
;
; Reference: coreboot src/soc/amd/common/block/smn/smn.c

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; PCI IO ports for config access
%define PCI_CONFIG_ADDR   0xCF8
%define PCI_CONFIG_DATA   0xCFC

; GNB (Graphics/Northbridge) BDF: Bus 0, Device 0, Function 0
; Config address = 0x80000000 | (0 << 16) | (0 << 11) | (0 << 8)
;                = 0x80000000
%define GNB_ADDR          0x80000000

; SMN index/data registers in GNB config space
%define SMN_INDEX_ADDR    0xB8
%define SMN_DATA_ADDR     0xBC

SECTION .text

; ==================================================================
; er_smn_read32
;   Read a 32-bit SMN register.
;   Arguments:
;     edi — SMN register address
;   Returns:
;     eax — register value
;     rdx — 0 (always succeeds at the HW level)
; ==================================================================
er_fn er_smn_read32
    er_frame_push

    ; Select SMN index register (config reg 0xB8 on GNB)
    mov     edx, PCI_CONFIG_ADDR
    mov     eax, GNB_ADDR | SMN_INDEX_ADDR
    out     dx, eax

    ; Write SMN address to index register via config data port
    mov     edx, PCI_CONFIG_DATA
    mov     eax, edi
    out     dx, eax

    ; Select SMN data register (config reg 0xBC on GNB)
    mov     edx, PCI_CONFIG_ADDR
    mov     eax, GNB_ADDR | SMN_DATA_ADDR
    out     dx, eax

    ; Read SMN data
    mov     edx, PCI_CONFIG_DATA
    in      eax, dx

    er_ok
    er_frame_pop
    er_ret

; ==================================================================
; er_smn_write32
;   Write a 32-bit SMN register.
;   Arguments:
;     edi — SMN register address
;     esi — value to write
;   Returns:
;     rdx — 0 (always succeeds at the HW level)
; ==================================================================
er_fn er_smn_write32
    er_frame_push

    ; Select SMN index register
    mov     edx, PCI_CONFIG_ADDR
    mov     eax, GNB_ADDR | SMN_INDEX_ADDR
    out     dx, eax

    ; Write SMN address to index
    mov     edx, PCI_CONFIG_DATA
    mov     eax, edi
    out     dx, eax

    ; Select SMN data register
    mov     edx, PCI_CONFIG_ADDR
    mov     eax, GNB_ADDR | SMN_DATA_ADDR
    out     dx, eax

    ; Write value to SMN data
    mov     edx, PCI_CONFIG_DATA
    mov     eax, esi
    out     dx, eax

    er_ok
    er_frame_pop
    er_ret

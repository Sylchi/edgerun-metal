; EdgeRun RTL8125 2.5GbE Ethernet driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putchar
extern er_serial_crlf

; PCI vendor:device
RTL_VENDOR    equ 0x10EC
RTL_DEVICE    equ 0x8125

; PCI config register offsets
PCI_COMMAND   equ 0x04
PCI_BAR0      equ 0x10

; PCI command bits
CMD_BUS_MASTER equ (1 << 2)
CMD_MEM_SPACE  equ (1 << 1)

; RTL8125 MMIO registers (BAR0 offsets)
RTL_IDR0      equ 0x0000       ; MAC address bytes 0-3
RTL_IDR4      equ 0x0004       ; MAC address bytes 4-7 (only 4-5 used)
RTL_PHY_STS   equ 0x00A4       ; PHY status register

; PHY status bits
PHY_LINK_UP   equ (1 << 0)

SECTION .text

; ==================================================================
; er_rtl8125_probe — probe RTL8125 at PCI location
; int er_rtl8125_probe(uint8_t bus, uint8_t dev, uint8_t func,
;                      uint64_t com_port)
;
; Reads BAR0, enables bus mastering, reads MAC address and link status.
; Prints info via serial.
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success, error code on failure
; ==================================================================
er_fn er_rtl8125_probe
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; bus
    mov     r13d, esi       ; dev
    mov     r14d, edx       ; func
    mov     r15, rcx        ; com_port

    ; Verify vendor:device at PCI config offset 0
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .not_found
    movzx   ebx, ax
    shr     eax, 16
    cmp     eax, RTL_VENDOR
    jne     .not_found
    cmp     ebx, RTL_DEVICE
    jne     .not_found

    ; Read BAR0
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    mov     ebx, eax

    test    al, 0x06
    jz      .not_found
    and     ebx, 0xFFFFFFF0

    ; Read BAR1 for high 32 bits (64-bit BAR)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_BAR0 + 4
    call    er_pci_read32
    shl     rax, 32
    or      rbx, rax        ; rbx = full BAR0

    ; Enable bus mastering + memory space
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_read32
    or      eax, CMD_BUS_MASTER | CMD_MEM_SPACE
    mov     r8, rax
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    ; Print "check: rtl8125 "
    mov     rdi, r15
    lea     rsi, [rel .check_str]
    call    er_serial_puts

    ; Read MAC first 4 bytes (IDR0)
    lea     rdi, [rbx + RTL_IDR0]
    call    er_mmio_read32
    push    rax

    ; Read MAC bytes 4-7 (IDR4)
    lea     rdi, [rbx + RTL_IDR4]
    call    er_mmio_read32
    mov     edx, eax
    pop     rax

    ; Print MAC as "xxxxxxxx-xxxxxxxx" (bytes 0-3, bytes 4-7)
    ; Little-endian: byte0 at bit 7:0 in the dword from RTL_IDR0
    ; RTL8125 stores MAC in network order, so IDR0 byte = MAC[0] (MSB)
    ; For display: just print the raw hex of both dwords
    mov     rdi, r15
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, r15
    mov     sil, '-'
    call    er_serial_putchar
    mov     rdi, r15
    mov     esi, edx
    call    er_serial_puthex32

    mov     rdi, r15
    mov     sil, ' '
    call    er_serial_putchar

    ; Check link status via PHY status register
    lea     rdi, [rbx + RTL_PHY_STS]
    call    er_mmio_read32
    test    eax, PHY_LINK_UP
    jz      .link_down

    mov     rdi, r15
    lea     rsi, [rel .link_up_str]
    call    er_serial_puts
    jmp     .done

.link_down:
    mov     rdi, r15
    lea     rsi, [rel .link_down_str]
    call    er_serial_puts

.done:
    mov     rdi, r15
    call    er_serial_crlf
    mov     eax, 0
    xor     edx, edx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.not_found:
    mov     eax, -1
    xor     edx, edx
    er_err  ERROR_NOT_PRESENT
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ─── Data ───────────────────────────────────────────────────────────
.check_str:   db "check: rtl8125 ", 0
.link_up_str: db "link up", 0
.link_down_str:db "link down", 0

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
    ; Save BAR0 for later init/TX/RX use
    lea     rax, [rel rtl_bar0]
    mov     [rax], rbx
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

; ─── RTL8125 register offsets (MMIO via BAR0) ──────────────────────
RTL_TPPOLL       equ 0x00D8   ; Transmit/Receive polling
RTL_IMR          equ 0x00DC   ; Interrupt mask (16-bit)
RTL_ISR          equ 0x00DA   ; Interrupt status (16-bit)
RTL_TXCFG        equ 0x00C0   ; TX config
RTL_RXCFG        equ 0x00C4   ; RX config
RTL_TX_DESC_LO   equ 0x00E0   ; TX descriptor addr low
RTL_TX_DESC_HI   equ 0x00E4   ; TX descriptor addr high
RTL_RX_DESC_LO   equ 0x00E8   ; RX descriptor addr low
RTL_RX_DESC_HI   equ 0x00EC   ; RX descriptor addr high

; TPPoll bits
TPPOLL_NPQ       equ (1 << 0)  ; Normal priority TX polling
TPPOLL_RX        equ (1 << 6)  ; RX polling

; TXCFG bits
TXCFG_HW_VER_MSK equ (0x7C000000)
TXCFG_LOOPBACK   equ (1 << 17)  ; Loopback test mode

; RXCFG bits
RXCFG_ACCEPT_ALL equ (1 << 0)   ; Accept all (promiscuous)
RXCFG_ACCEPT_PHY_MATCH equ (1 << 1)
RXCFG_ACCEPT_BROADCAST equ (1 << 3)  ; Accept broadcast
RXCFG_ACCEPT_MYPHYS equ (1 << 4)     ; Accept physical match
RXCFG_ACCEPT_ERR equ (1 << 7)        ; Accept error packets
RXCFG_ACCEPT_RUNT equ (1 << 8)       ; Accept runt packets

; ISR bits
ISR_SYSTEM_ERR   equ (1 << 0)
ISR_RX_OVW       equ (1 << 1)
ISR_TX_ERR       equ (1 << 2)
ISR_TX_OK        equ (1 << 3)
ISR_RX_OK        equ (1 << 4)
ISR_LINK_CHG     equ (1 << 12)

; ─── TX/RX descriptor constants ────────────────────────────────────
TX_RING_SIZE     equ 4
RX_RING_SIZE     equ 8
TX_BUF_SIZE      equ 2048
RX_BUF_SIZE      equ 2048

; TX descriptor DW2 bits
TDESC_OWN        equ (1 << 15)   ; 1 = NIC owns it (send)
TDESC_FS         equ (1 << 28)   ; First segment
TDESC_LS         equ (1 << 29)   ; Last segment

; RX descriptor DW3 bits
RDESC_OWN        equ (1 << 31)   ; 1 = NIC owns it (fill)

; ─── BSS: descriptor rings and buffers ─────────────────────────────
SECTION .bss
align 256
tx_descs:
    times (TX_RING_SIZE * 16) db 0
tx_bufs:
    times (TX_RING_SIZE * TX_BUF_SIZE) db 0
tx_cur:
    resd 1                       ; current TX index (dword)

align 256
rx_descs:
    times (RX_RING_SIZE * 16) db 0
rx_bufs:
    times (RX_RING_SIZE * RX_BUF_SIZE) db 0
rx_cur:
    resd 1                       ; current RX index (dword)

; Probed BAR0 (saved by init for use by TX/RX functions)
rtl_bar0:
    resq 1

; ─── Code ───────────────────────────────────────────────────────────
SECTION .text

; ==================================================================
; er_rtl8125_init — Initialize TX/RX descriptor rings
; After probing, call this to set up DMA rings and start the NIC.
;
; int er_rtl8125_init(uint64_t bar0)
; Returns: eax = 0 on success, rdx = 0 on success
; ==================================================================
er_fn er_rtl8125_init
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; bar0 (MMIO base for register access)
    lea     r13, [rel rtl_bar0]
    mov     [r13], r12          ; save bar0 for TX/RX functions

    ; ── 1. Stop TX/RX before reconfiguring ──
    ; Read TXCFG, clear TE bit
    lea     rdi, [r12 + RTL_TXCFG]
    call    er_mmio_read32
    and     eax, 0xFFFFFFFE     ; clear bit 0 (TE)
    lea     rdi, [r12 + RTL_TXCFG]
    mov     esi, eax
    call    er_mmio_write32

    ; Read RXCFG, clear RE bit
    lea     rdi, [r12 + RTL_RXCFG]
    call    er_mmio_read32
    and     eax, 0xFFFFFFFE     ; clear bit 0 (RE)
    lea     rdi, [r12 + RTL_RXCFG]
    mov     esi, eax
    call    er_mmio_write32

    ; ── 2. Set TX descriptor base ──
    lea     rax, [rel tx_descs]
    lea     rdi, [r12 + RTL_TX_DESC_LO]
    mov     esi, eax
    call    er_mmio_write32

    lea     rax, [rel tx_descs]
    shr     rax, 32
    lea     rdi, [r12 + RTL_TX_DESC_HI]
    mov     esi, eax
    call    er_mmio_write32

    ; ── 3. Set RX descriptor base ──
    lea     rax, [rel rx_descs]
    lea     rdi, [r12 + RTL_RX_DESC_LO]
    mov     esi, eax
    call    er_mmio_write32

    lea     rax, [rel rx_descs]
    shr     rax, 32
    lea     rdi, [r12 + RTL_RX_DESC_HI]
    mov     esi, eax
    call    er_mmio_write32

    ; ── 4. Initialize RX descriptors ──
    xor     ebx, ebx            ; index
.init_rx_loop:
    cmp     ebx, RX_RING_SIZE
    jae     .init_rx_done

    ; r9 = &rx_descs[index]
    mov     r9d, ebx
    shl     r9d, 4
    lea     r9, [rel rx_descs + r9]

    ; Set buffer address
    lea     rcx, [rel rx_bufs]
    mov     edx, ebx
    imul    edx, RX_BUF_SIZE
    add     rcx, rdx
    mov     [rax], rcx          ; DW0: low 32 bits of address
    shr     rcx, 32
    mov     [rax + 4], ecx      ; DW1: high 32 bits

    ; Set buffer size (DW2)
    mov     dword [rax + 8], RX_BUF_SIZE

    ; Set OWN bit in DW3 (NIC owns it)
    mov     dword [rax + 12], RDESC_OWN

    inc     ebx
    jmp     .init_rx_loop
.init_rx_done:

    ; ── 5. Initialize TX descriptors (mark as owned by driver, all zeros) ──
    ; Already zero from BSS

    ; ── 6. Set TX config (max DMA burst, no loopback) ──
    lea     rdi, [r12 + RTL_TXCFG]
    mov     esi, 0x00000000     ; default TX config (TE = 0 still)
    call    er_mmio_write32

    ; ── 7. Set RX config (accept broadcast + physical match, no error/runt) ──
    mov     esi, RXCFG_ACCEPT_BROADCAST | RXCFG_ACCEPT_MYPHYS
    lea     rdi, [r12 + RTL_RXCFG]
    call    er_mmio_write32

    ; ── 8. Enable RX (set RE bit) ──
    lea     rdi, [r12 + RTL_RXCFG]
    call    er_mmio_read32
    or      eax, 1              ; set RE bit
    mov     esi, eax
    lea     rdi, [r12 + RTL_RXCFG]
    call    er_mmio_write32

    ; ── 9. Enable TX (set TE bit) ──
    lea     rdi, [r12 + RTL_TXCFG]
    call    er_mmio_read32
    or      eax, 1              ; set TE bit
    mov     esi, eax
    lea     rdi, [r12 + RTL_TXCFG]
    call    er_mmio_write32

    ; ── 10. Mask interrupts (polling mode) ──
    lea     rdi, [r12 + RTL_IMR]
    xor     esi, esi            ; no interrupts
    call    er_mmio_write32

    ; ── 11. RX polling kick ──
    lea     rdi, [r12 + RTL_TPPOLL]
    mov     esi, TPPOLL_RX
    call    er_mmio_write32

    ; Reset ring indices
    mov     dword [rel tx_cur], 0
    mov     dword [rel rx_cur], 0

    xor     eax, eax
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

; ==================================================================
; er_rtl8125_transmit — Send a raw Ethernet frame
;
; int er_rtl8125_transmit(const void *data, uint32_t len)
; Returns: eax = 0 on success, -1 on failure (rdx = error code)
; ==================================================================
er_fn er_rtl8125_transmit
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; data pointer
    mov     r13d, esi           ; length
    lea     rbx, [rel rtl_bar0]
    mov     rbx, [rbx]          ; bar0

    cmp     r13d, 60           ; minimum frame size
    jae     .size_ok
    mov     r13d, 60           ; pad to minimum Ethernet frame
.size_ok:
    cmp     r13d, TX_BUF_SIZE
    ja      .tx_too_big

    ; Get current TX index
    lea     rcx, [rel tx_cur]
    mov     eax, [rcx]
    mov     r8d, eax

    ; Compute descriptor address: tx_descs + index * 16
    shl     rax, 4
    lea     r9, [rel tx_descs]
    add     r9, rax             ; r9 = current TX descriptor

    ; Check OWN bit: if NIC still owns it, ring full
    mov     eax, [r9 + 12]      ; DW3
    test    eax, TDESC_OWN
    jnz     .tx_ring_full

    ; Copy data to tx buffer for this slot
    shl     r8, 8               ; no, multiply by buffer size
    ; Actually: index * TX_BUF_SIZE
    mov     eax, r8d
    mov     r10d, TX_BUF_SIZE
    mul     r10d                ; eax = index * TX_BUF_SIZE (low)
    lea     r10, [rel tx_bufs]
    add     r10, rax            ; r10 = destination buffer address

    ; memcpy (data -> tx buffer, r13d bytes)
    cld
    mov     rdi, r10
    mov     rsi, r12
    mov     ecx, r13d
    rep     movsb

    ; Set descriptor buffer address
    mov     [r9], r10d          ; DW0: low 32 of buffer addr
    shr     r10, 32
    mov     [r9 + 4], r10d      ; DW1: high 32

    ; Set DW2: FS + LS + OWN + packet size
    mov     eax, r13d
    and     eax, 0x3FFF         ; size in bits 13:0
    or      eax, TDESC_FS | TDESC_LS | TDESC_OWN
    mov     [r9 + 8], eax

    ; DW3: zero (no checksum offload for now)
    mov     dword [r9 + 12], 0

    ; Update TX index
    mov     eax, r8d
    inc     eax
    xor     edx, edx
    mov     ecx, TX_RING_SIZE
    div     ecx
    mov     [rel tx_cur], edx   ; store new index

    ; Trigger TX polling
    lea     rdi, [rbx + RTL_TPPOLL]
    mov     esi, TPPOLL_NPQ
    call    er_mmio_write32

    xor     eax, eax
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.tx_too_big:
    mov     eax, -1
    xor     edx, edx
    er_err  ERROR_INVALID_PARAM
    pop     r13
    pop     r12
    pop     rbx
    ret

.tx_ring_full:
    mov     eax, -1
    xor     edx, edx
    er_err  ERROR_BUSY
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_rtl8125_receive — Poll for and receive a packet (non-blocking)
;
; int er_rtl8125_receive(void *buf, uint32_t *len)
; buf points to max-size receive buffer, *len set to actual length.
; Returns: eax = 0 on success (packet received)
;          eax = -1 on failure (no packet, rdx = ERROR_NO_DATA)
; ==================================================================
er_fn er_rtl8125_receive
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; output buffer
    mov     r13, rsi            ; pointer to length

    ; Get current RX index
    lea     rcx, [rel rx_cur]
    mov     eax, [rcx]
    mov     r14d, eax

    ; Compute descriptor address: rx_descs + index * 16
    shl     rax, 4
    lea     r9, [rel rx_descs]
    add     r9, rax

    ; Check OWN bit: if NIC still owns it, no packet
    mov     eax, [r9 + 12]      ; DW3
    test    eax, RDESC_OWN
    jnz     .no_packet

    ; Get frame length from bits 13:0 of DW3
    mov     ecx, eax
    and     ecx, 0x3FFF

    ; Copy data from RX buffer to output
    cld
    mov     rdi, r12
    mov     rsi, r10
    ; ecx = length (already set above)
    rep     movsb

    ; Write received length
    mov     eax, [r9 + 12]
    and     eax, 0x3FFF
    mov     [r13], eax

    ; Reinitialize RX descriptor (give buffer back to NIC)
    lea     rbx, [rel rx_descs]
    mov     eax, r14d
    shl     rax, 4
    add     rbx, rax

    ; Buffer address still valid (same buffer), just re-set OWN bit
    mov     dword [rbx + 12], RDESC_OWN

    ; Update RX index (ring size modulo)
    mov     eax, r14d
    inc     eax
    xor     edx, edx
    mov     ecx, RX_RING_SIZE
    div     ecx
    mov     [rel rx_cur], edx

    xor     eax, eax
    xor     edx, edx
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.no_packet:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    xor     edx, edx
    er_err  ERROR_NO_DATA
    ret

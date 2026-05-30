; EdgeRun Virtio PCI transport — x86_64 assembly
; System V AMD64 ABI. Freestanding — no libc, no external dependencies.
;
; Provides legacy (I/O port) Virtio device discovery, feature negotiation,
; and split virtqueue management. Uses BAR0 I/O ports instead of MMIO BAR4,
; because QEMU i440FX does not forward MMIO at 0xFE000000 to the PCI bus.

%include "x86_64/macros.inc"
%include "driver/virtio_constants.inc"

extern er_pci_read32
extern er_pci_write32


SECTION .text

; ==================================================================
; I/O port helpers — register access through legacy I/O BAR
; Arguments: di = port number, value in si/dx/etc.
; ==================================================================

; uint8_t er_virtio_read8(uint64_t port)
er_fn er_virtio_read8
    mov     dx, di
    in      al, dx
    ret

; uint16_t er_virtio_read16(uint64_t port)
er_fn er_virtio_read16
    mov     dx, di
    in      ax, dx
    ret

; uint32_t er_virtio_read32(uint64_t port)
er_fn er_virtio_read32
    mov     dx, di
    in      eax, dx
    ret

; void er_virtio_write8(uint64_t port, uint8_t val)
er_fn er_virtio_write8
    mov     dx, di
    mov     al, sil
    out     dx, al
    ret

; void er_virtio_write16(uint64_t port, uint16_t val)
er_fn er_virtio_write16
    mov     dx, di
    mov     ax, si
    out     dx, ax
    ret

; void er_virtio_write32(uint64_t port, uint32_t val)
er_fn er_virtio_write32
    mov     dx, di
    mov     eax, esi
    out     dx, eax
    ret

; void er_virtio_write64(uint64_t port, uint64_t val)
; Legacy interface: 32-bit I/O ports, write two halves
er_fn er_virtio_write64
    mov     dx, di
    mov     eax, esi
    out     dx, eax
    ; Write high 32 bits to next port
    add     dx, 4
    shr     rsi, 32
    mov     eax, esi
    out     dx, eax
    ret

; ==================================================================
; PCI config 8/16 access via 32-bit read wrapper
; ==================================================================

; uint8_t er_virtio_pci_read8(uint8_t bus, uint8_t dev, uint8_t func, uint16_t offset)
er_fn er_virtio_pci_read8
    push    rcx
    and     ecx, 0xFFFC
    call    er_pci_read32
    pop     rcx
    and     ecx, 3
    shl     ecx, 3
    shr     eax, cl
    and     eax, 0xFF
    ret

; uint16_t er_virtio_pci_read16(uint8_t bus, uint8_t dev, uint8_t func, uint16_t offset)
er_fn er_virtio_pci_read16
    push    rcx
    and     ecx, 0xFFFC
    call    er_pci_read32
    pop     rcx
    and     ecx, 2
    shl     ecx, 3
    shr     eax, cl
    and     eax, 0xFFFF
    ret

; ==================================================================
; er_virtio_find_device — find Virtio PCI device
; int er_virtio_find_device(uint16_t device_id, VIRTIO_DEVICE* dev)
;
; Scans bus 0 for vendor=0x1AF4, device=match.
; Reads capability list to find Virtio modern capabilities.
; Returns: eax = 1 if found, fills *dev; 0 if not found.
; ==================================================================
er_fn er_virtio_find_device
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; device_id
    mov     r15, rsi            ; VIRTIO_DEVICE* out

    xor     ebx, ebx            ; bus = 0
.bus_loop:
    xor     r13d, r13d          ; slot = 0
.slot_loop:
    xor     r14d, r14d          ; func = 0
.func_loop:
    mov     rdi, rbx            ; bus
    mov     rsi, r13            ; slot
    mov     rdx, r14            ; func
    xor     ecx, ecx            ; offset 0
    call    er_pci_read32
    movzx   edi, ax
    cmp     edi, VIRTIO_VENDOR
    jne     .next_func

    mov     rdi, rbx
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, 2
    call    er_virtio_pci_read16
    cmp     eax, r12d
    jne     .next_func

    ; Found matching device — parse capabilities
    push    rbx
    push    r13
    push    r14
    mov     rdi, rbx
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    call    _virtio_read_capabilities
    pop     r14
    pop     r13
    pop     rbx
    test    eax, eax
    jz      .next_func

    mov     byte [r15 + VIRTIO_DEVICE.bus], bl
    mov     byte [r15 + VIRTIO_DEVICE.slot], r13b
    mov     byte [r15 + VIRTIO_DEVICE.func], r14b

    mov     eax, 1
    er_ok
    jmp     .out

.next_func:
    inc     r14b
    cmp     r14b, 8
    jb      .func_loop
    inc     r13b
    cmp     r13b, 32
    jb      .slot_loop
    inc     ebx
    cmp     ebx, 1
    jb      .bus_loop

    xor     eax, eax
    er_ok
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret

; ==================================================================
; _virtio_read_capabilities — traverse PCI cap list for Virtio caps
; int _virtio_read_capabilities(uint8_t bus, uint8_t slot, uint8_t func,
;                               VIRTIO_DEVICE* dev)
;
; For legacy I/O port mode, we still parse capabilities to verify the
; device is transitional (has vendor cap chain) and find BAR0.
; Returns: eax = 1 if at least common+notify found, 0 otherwise.
; ==================================================================
_virtio_read_capabilities:
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_STATUS
    call    er_virtio_pci_read16

    test    eax, PCI_STATUS_CAPABILITIES
    jz      .fail

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_CAP_LIST
    call    er_virtio_pci_read8
    and     eax, 0xFC
    mov     ebp, eax

    ; Zero capability fields
    mov     byte [r15 + VIRTIO_DEVICE.common_bar], 0
    mov     byte [r15 + VIRTIO_DEVICE.notify_bar], 0
    mov     byte [r15 + VIRTIO_DEVICE.device_bar], 0
    mov     byte [r15 + VIRTIO_DEVICE.isr_bar], 0
    mov     dword [r15 + VIRTIO_DEVICE.common_offset], 0
    mov     dword [r15 + VIRTIO_DEVICE.notify_offset], 0
    mov     dword [r15 + VIRTIO_DEVICE.device_offset], 0
    mov     dword [r15 + VIRTIO_DEVICE.isr_offset], 0
    mov     dword [r15 + VIRTIO_DEVICE.notify_off_mult], 0

    xor     ebx, ebx            ; found_common
    xor     r8d, r8d            ; found_notify

.cap_loop:
    cmp     ebp, 0x40
    jb      .cap_done

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, ebp
    call    er_virtio_pci_read8
    cmp     eax, VIRTIO_PCI_CAP_VENDOR
    jne     .cap_next

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 2]
    call    er_virtio_pci_read8
    cmp     eax, 16
    jb      .cap_next

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 3]
    call    er_virtio_pci_read8
    mov     r9d, eax            ; cfg_type

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 4]
    call    er_virtio_pci_read8
    mov     r10b, al            ; bar

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 8]
    call    er_pci_read32
    mov     r11d, eax           ; offset

    cmp     r9b, VIRTIO_PCI_CAP_COMMON_CFG
    je      .set_common
    cmp     r9b, VIRTIO_PCI_CAP_NOTIFY_CFG
    je      .set_notify
    cmp     r9b, VIRTIO_PCI_CAP_ISR_CFG
    je      .set_isr
    cmp     r9b, VIRTIO_PCI_CAP_DEVICE_CFG
    je      .set_device
    jmp     .cap_next

.set_common:
    mov     byte [r15 + VIRTIO_DEVICE.common_bar], r10b
    mov     dword [r15 + VIRTIO_DEVICE.common_offset], r11d
    mov     ebx, 1
    jmp     .cap_next

.set_notify:
    mov     byte [r15 + VIRTIO_DEVICE.notify_bar], r10b
    mov     dword [r15 + VIRTIO_DEVICE.notify_offset], r11d
    mov     r8d, 1
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 16]
    call    er_pci_read32
    mov     dword [r15 + VIRTIO_DEVICE.notify_off_mult], eax
    jmp     .cap_next

.set_isr:
    mov     byte [r15 + VIRTIO_DEVICE.isr_bar], r10b
    mov     dword [r15 + VIRTIO_DEVICE.isr_offset], r11d
    jmp     .cap_next

.set_device:
    mov     byte [r15 + VIRTIO_DEVICE.device_bar], r10b
    mov     dword [r15 + VIRTIO_DEVICE.device_offset], r11d

.cap_next:
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     ecx, [ebp + 1]
    call    er_virtio_pci_read8
    and     eax, 0xFC
    mov     ebp, eax
    test    ebp, ebp
    jnz     .cap_loop

.cap_done:
    test    ebx, ebx
    jz      .fail
    test    r8d, r8d
    jz      .fail
    mov     eax, 1
    jmp     .out
.fail:
    xor     eax, eax
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; _virtio_bar_base — get MMIO or I/O base for a PCI BAR
; uint64_t _virtio_bar_base(uint8_t bus, uint8_t slot, uint8_t func,
;                           uint8_t bar_index)
; Returns: rax = base address (MMIO or I/O), or 0 on error.
; For I/O BARs, the base is the I/O port number (unaltered by type bits).
; ==================================================================
_virtio_bar_base:
    er_frame_push
    push    r12
    push    r13

    mov     r12, rdi            ; bus
    mov     r13, rsi            ; slot
    ; rdx = func, rcx = bar_index

    mov     eax, ecx
    and     eax, 0xFF
    shl     eax, 2
    add     eax, PCI_BAR0
    mov     ecx, eax
    mov     rdi, r12
    mov     rsi, r13
    call    er_pci_read32

    test    eax, eax
    jz      .fail
    cmp     eax, 0xFFFFFFFF
    je      .fail

    test    al, 1               ; I/O BAR?
    jnz     .io_bar

    ; Memory BAR
    mov     ebp, eax
    and     ebp, 0x6
    cmp     ebp, 0x4            ; 64-bit BAR?
    je      .sixtyfour

    ; 32-bit memory BAR
    and     eax, 0xFFFFFFF0
    jmp     .out

.sixtyfour:
    ; 64-bit memory BAR
    and     eax, 0xFFFFFFF0
    mov     r8d, eax
    mov     rdi, r12
    mov     rsi, r13
    ; rdx already = func
    mov     eax, ecx
    add     eax, 4
    mov     ecx, eax
    call    er_pci_read32
    shl     rax, 32
    or      rax, r8
    jmp     .out

.io_bar:
    ; I/O BAR: return port number (upper bits zeroed)
    and     eax, 0xFFFFFFFC
    jmp     .out

.fail:
    xor     eax, eax
.out:
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; er_virtio_map_device — map device BARs to I/O ports (legacy mode)
; void er_virtio_map_device(VIRTIO_DEVICE* dev, VIRTIO_TRANSPORT* tr)
;
; Reads BAR0 to get the I/O port base for the legacy interface.
; The modern MMIO BARs are unused because QEMU i440FX does not
; forward MMIO to BAR4 at 0xFE000000.
; ==================================================================
er_fn er_virtio_map_device
    er_frame_push
    push    r12
    push    r13

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; tr

    ; Copy bus/slot/func
    mov     al, [r12 + VIRTIO_DEVICE.bus]
    mov     [r13 + VIRTIO_TRANSPORT.bus], al
    mov     al, [r12 + VIRTIO_DEVICE.slot]
    mov     [r13 + VIRTIO_TRANSPORT.slot], al
    mov     al, [r12 + VIRTIO_DEVICE.func]
    mov     [r13 + VIRTIO_TRANSPORT.func], al

    ; Read BAR0 (I/O port base)
    movzx   edi, byte [r12 + VIRTIO_DEVICE.bus]
    movzx   esi, byte [r12 + VIRTIO_DEVICE.slot]
    movzx   edx, byte [r12 + VIRTIO_DEVICE.func]
    xor     ecx, ecx            ; bar index 0
    call    _virtio_bar_base
    mov     [r13 + VIRTIO_TRANSPORT.io_base], ax
    add     eax, LEGACY_DEVICE_CFG
    mov     [r13 + VIRTIO_TRANSPORT.device_config], ax

    ; notify_off_mult is unused for legacy, but keep it
    mov     eax, [r12 + VIRTIO_DEVICE.notify_off_mult]
    mov     [r13 + VIRTIO_TRANSPORT.notify_off_mult], eax

    er_ok
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; er_virtio_enable_device — enable PCI bus master (legacy mode)
; void er_virtio_enable_device(VIRTIO_TRANSPORT* tr)
;
; For legacy I/O port mode, we need only bus master (not memory space).
; ==================================================================
er_fn er_virtio_enable_device
    er_frame_push
    push    r12

    mov     r12, rdi

    movzx   edi, byte [r12 + VIRTIO_TRANSPORT.bus]
    movzx   esi, byte [r12 + VIRTIO_TRANSPORT.slot]
    movzx   edx, byte [r12 + VIRTIO_TRANSPORT.func]
    mov     ecx, PCI_COMMAND
    call    er_virtio_pci_read16
    or      eax, PCI_COMMAND_BUS_MASTER

    ; Write back via er_pci_write32 (read-modify-write the dword)
    mov     ecx, PCI_COMMAND
    push    rax
    movzx   edi, byte [r12 + VIRTIO_TRANSPORT.bus]
    movzx   esi, byte [r12 + VIRTIO_TRANSPORT.slot]
    movzx   edx, byte [r12 + VIRTIO_TRANSPORT.func]
    call    er_pci_read32
    and     eax, 0xFFFF0000
    mov     ecx, eax
    pop     rax
    and     eax, 0x0000FFFF
    or      eax, ecx
    mov     r8, rax
    movzx   edi, byte [r12 + VIRTIO_TRANSPORT.bus]
    movzx   esi, byte [r12 + VIRTIO_TRANSPORT.slot]
    movzx   edx, byte [r12 + VIRTIO_TRANSPORT.func]
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    pop     r12
    er_frame_pop
    ret

; ==================================================================
; _virtio_legacy_read_features — read device features (32-bit legacy)
; uint32_t _virtio_legacy_read_features(uint16_t io_base)
; ==================================================================
_virtio_legacy_read_features:
    add     edi, LEGACY_DEVICE_FEATURES
    mov     dx, di
    in      eax, dx
    ret

; ==================================================================
; _virtio_legacy_write_features — write driver features (32-bit legacy)
; void _virtio_legacy_write_features(uint16_t io_base, uint32_t features)
; ==================================================================
_virtio_legacy_write_features:
    add     edi, LEGACY_GUEST_FEATURES
    mov     dx, di
    mov     eax, esi
    out     dx, eax
    ret

; ==================================================================
; er_virtio_negotiate_features — negotiate Virtio features
; int er_virtio_negotiate_features(VIRTIO_TRANSPORT* tr,
;                                  uint64_t supported,
;                                  uint64_t* driver_features_out)
;
; Returns: eax = 1 on success, 0 on failure.
; ==================================================================
er_fn er_virtio_negotiate_features
    er_frame_push
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; tr
    mov     r13, rsi            ; supported features (low 32 bits used)
    mov     r14, rdx            ; out driver_features

    ; 1. Enable PCI bus master
    mov     rdi, r12
    call    er_virtio_enable_device

    ; 2. Reset device (write 0 to device status)
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     esi, 0
    call    er_virtio_write8

    ; 3. Acknowledge + DRIVER
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE
    call    er_virtio_write8

    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
    call    er_virtio_write8

    ; 4. Read device features (32-bit legacy)
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    call    _virtio_legacy_read_features

    ; 5. Driver = device & supported (low 32 bits)
    and     eax, r13d
    push    rax

    ; 6. Write driver features (32-bit legacy)
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    mov     esi, eax
    call    _virtio_legacy_write_features

    ; 7. Set FEATURES_OK
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
    call    er_virtio_write8

    ; 8. Verify FEATURES_OK
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    call    er_virtio_read8
    test    al, VIRTIO_STATUS_FEATURES_OK
    jz      .fail

    ; 9. Store driver features in output
    pop     rax
    mov     [r14], rax

    mov     eax, 1
    er_ok
    jmp     .out

.fail:
    movzx   edi, word [r12 + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     esi, VIRTIO_STATUS_FAILED
    call    er_virtio_write8
    xor     eax, eax
    er_err  ERROR_FEATURE_NEGOTIATION
.out:
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; Queue management helpers (legacy I/O port interface)
; ==================================================================

; void er_virtio_select_queue(VIRTIO_TRANSPORT* tr, uint16_t queue_num)
er_fn er_virtio_select_queue
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_QUEUE_SELECT
    mov     dx, di
    mov     ax, si
    out     dx, ax
    ret

; uint16_t er_virtio_read_queue_size(VIRTIO_TRANSPORT* tr)
er_fn er_virtio_read_queue_size
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_QUEUE_SIZE
    mov     dx, di
    in      ax, dx
    ret

; void er_virtio_set_queue_address(VIRTIO_TRANSPORT* tr, uint32_t addr)
; Legacy: writes the physical address of the descriptor table
er_fn er_virtio_set_queue_address
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_QUEUE_ADDRESS
    mov     dx, di
    mov     eax, esi
    out     dx, eax
    ret

; void er_virtio_set_queue_size(VIRTIO_TRANSPORT* tr, uint16_t size)
er_fn er_virtio_set_queue_size
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_QUEUE_SIZE
    mov     dx, di
    mov     ax, si
    out     dx, ax
    ret

; uint16_t er_virtio_read_queue_notify_off(VIRTIO_TRANSPORT* tr)
; Legacy: always returns 0 (fixed notify port at LEGACY_QUEUE_NOTIFY)
er_fn er_virtio_read_queue_notify_off
    xor     eax, eax
    ret

; void er_virtio_notify_queue(VIRTIO_TRANSPORT* tr, uint16_t queue_num)
; Legacy: writes queue number to fixed notify port
er_fn er_virtio_notify_queue
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_QUEUE_NOTIFY
    mov     dx, di
    mov     ax, si
    out     dx, ax
    ret

; uint8_t er_virtio_read_status(VIRTIO_TRANSPORT* tr)
er_fn er_virtio_read_status
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     dx, di
    in      al, dx
    ret

; void er_virtio_write_status(VIRTIO_TRANSPORT* tr, uint8_t val)
er_fn er_virtio_write_status
    movzx   edi, word [rdi + VIRTIO_TRANSPORT.io_base]
    add     edi, LEGACY_DEVICE_STATUS
    mov     dx, di
    mov     al, sil
    out     dx, al
    ret

; ==================================================================
; Descriptor ring helpers (identical to modern)
; ==================================================================

; void er_virtio_post_descriptor(Avail* avail, uint16_t queue_size,
;                                uint16_t desc_id)
; rdi = avail ptr, rsi = queue_size, rdx = desc_id
er_fn er_virtio_post_descriptor
    movzx   ecx, word [rdi + 2]
    lea     r8d, [rsi - 1]
    and     r8d, ecx
    mov     [rdi + r8*2 + 4], dx
    inc     ecx
    mov     [rdi + 2], cx
    sfence
    ret

; int er_virtio_next_used(Used* used, uint16_t queue_size,
;                         uint16_t* last_used_idx)
; Returns: eax = 1 with rcx=id, r8=len if available; 0 if none.
er_fn er_virtio_next_used
    movzx   ecx, word [rdi + 2]
    mov     r9w, [rdx]
    cmp     cx, r9w
    je      .none

    lea     r10d, [rsi - 1]
    and     r10d, r9d
    lea     r10, [rdi + r10*8 + 4]
    mov     ecx, [r10]
    mov     r8d, [r10 + 4]
    inc     word [rdx]
    mov     eax, 1
    ret
.none:
    xor     eax, eax
    ret

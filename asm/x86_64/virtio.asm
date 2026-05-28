; EdgeRun Virtio PCI transport — x86_64 assembly
; System V AMD64 ABI. Freestanding — no libc, no external dependencies.
;
; Provides modern (PCI MSI-X) Virtio device discovery, MMIO helpers,
; feature negotiation, and split virtqueue management.

%include "x86_64/macros.inc"
%include "x86_64/virtio_constants.inc"

extern er_pci_read32
extern er_pci_write32

SECTION .text

; ==================================================================
; MMIO helpers — volatile memory access through mapped addresses
; ==================================================================

; uint8_t er_virtio_read8(uint64_t addr)
er_fn er_virtio_read8
    mov     al, [rdi]
    ret

; uint16_t er_virtio_read16(uint64_t addr)
er_fn er_virtio_read16
    mov     ax, [rdi]
    ret

; uint32_t er_virtio_read32(uint64_t addr)
er_fn er_virtio_read32
    mov     eax, [rdi]
    ret

; void er_virtio_write8(uint64_t addr, uint8_t val)
er_fn er_virtio_write8
    mov     [rdi], sil
    ret

; void er_virtio_write16(uint64_t addr, uint16_t val)
er_fn er_virtio_write16
    mov     [rdi], si
    ret

; void er_virtio_write32(uint64_t addr, uint32_t val)
er_fn er_virtio_write32
    mov     [rdi], esi
    ret

; void er_virtio_write64(uint64_t addr, uint64_t val)
er_fn er_virtio_write64
    mov     [rdi], rsi
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
; er_virtio_find_device — find Virtio modern PCI device
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
; Returns: eax = 1 if at least common+notify found, 0 otherwise.
; ==================================================================
_virtio_read_capabilities:
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15

    ; Register allocation:
    ; r12 = bus, r13 = slot, r14 = func, r15 = dev
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    ; Check capabilities bit in PCI status
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
; _virtio_bar_base — get MMIO base address for a PCI BAR
; uint64_t _virtio_bar_base(uint8_t bus, uint8_t slot, uint8_t func,
;                           uint8_t bar_index)
; Returns: rax = MMIO base, or 0 on error.
; ==================================================================
_virtio_bar_base:
    er_frame_push
    push    r12
    push    r13

    mov     r12, rdi            ; bus
    mov     r13, rsi            ; slot
    ; rdx = func, rcx = bar_index

    ; Read BAR register
    mov     eax, ecx
    and     eax, 0xFF
    shl     eax, 2
    add     eax, PCI_BAR0
    mov     ecx, eax
    mov     rdi, r12
    mov     rsi, r13
    ; rdx already = func
    call    er_pci_read32

    test    al, 1               ; I/O BAR?
    jnz     .fail
    test    eax, eax
    jz      .fail
    cmp     eax, 0xFFFFFFFF
    je      .fail

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
    mov     r8d, eax            ; save low part
    mov     rdi, r12
    mov     rsi, r13
    ; rdx already = func
    mov     ecx, ecx            ; bar index already in ecx
    add     ecx, 4              ; next dword (bar+1)
    call    er_pci_read32
    shl     rax, 32
    or      rax, r8
    jmp     .out

.fail:
    xor     eax, eax
.out:
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; er_virtio_map_device — map device BARs to MMIO addresses
; void er_virtio_map_device(VIRTIO_DEVICE* dev, VIRTIO_TRANSPORT* tr)
; ==================================================================
er_fn er_virtio_map_device
    er_frame_push
    push    r12
    push    r13

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; tr

    ; Copy bus/slot/func
    mov     eax, [r12 + VIRTIO_DEVICE.bus]     ; byte, but read dword to get all 3
    mov     [r13 + VIRTIO_TRANSPORT.bus], al
    mov     al, [r12 + VIRTIO_DEVICE.slot]
    mov     [r13 + VIRTIO_TRANSPORT.slot], al
    mov     al, [r12 + VIRTIO_DEVICE.func]
    mov     [r13 + VIRTIO_TRANSPORT.func], al

    ; Map common cfg
    movzx   edi, byte [r12 + VIRTIO_DEVICE.bus]
    movzx   esi, byte [r12 + VIRTIO_DEVICE.slot]
    movzx   edx, byte [r12 + VIRTIO_DEVICE.func]
    movzx   ecx, byte [r12 + VIRTIO_DEVICE.common_bar]
    call    _virtio_bar_base
    add     rax, [r12 + VIRTIO_DEVICE.common_offset]
    mov     [r13 + VIRTIO_TRANSPORT.common_cfg], rax

    ; Map notify cfg
    movzx   edi, byte [r12 + VIRTIO_DEVICE.bus]
    movzx   esi, byte [r12 + VIRTIO_DEVICE.slot]
    movzx   edx, byte [r12 + VIRTIO_DEVICE.func]
    movzx   ecx, byte [r12 + VIRTIO_DEVICE.notify_bar]
    call    _virtio_bar_base
    add     rax, [r12 + VIRTIO_DEVICE.notify_offset]
    mov     [r13 + VIRTIO_TRANSPORT.notify_cfg], rax

    ; Map device cfg (optional)
    cmp     byte [r12 + VIRTIO_DEVICE.device_bar], 0
    je      .no_device
    movzx   edi, byte [r12 + VIRTIO_DEVICE.bus]
    movzx   esi, byte [r12 + VIRTIO_DEVICE.slot]
    movzx   edx, byte [r12 + VIRTIO_DEVICE.func]
    movzx   ecx, byte [r12 + VIRTIO_DEVICE.device_bar]
    call    _virtio_bar_base
    add     rax, [r12 + VIRTIO_DEVICE.device_offset]
    mov     [r13 + VIRTIO_TRANSPORT.device_cfg], rax
    jmp     .map_isr
.no_device:
    xor     eax, eax
    mov     [r13 + VIRTIO_TRANSPORT.device_cfg], rax

.map_isr:
    cmp     byte [r12 + VIRTIO_DEVICE.isr_bar], 0
    je      .no_isr
    movzx   edi, byte [r12 + VIRTIO_DEVICE.bus]
    movzx   esi, byte [r12 + VIRTIO_DEVICE.slot]
    movzx   edx, byte [r12 + VIRTIO_DEVICE.func]
    movzx   ecx, byte [r12 + VIRTIO_DEVICE.isr_bar]
    call    _virtio_bar_base
    add     rax, [r12 + VIRTIO_DEVICE.isr_offset]
    mov     [r13 + VIRTIO_TRANSPORT.isr_cfg], rax
    jmp     .done
.no_isr:
    xor     eax, eax
    mov     [r13 + VIRTIO_TRANSPORT.isr_cfg], rax

.done:
    mov     eax, [r12 + VIRTIO_DEVICE.notify_off_mult]
    mov     [r13 + VIRTIO_TRANSPORT.notify_off_mult], eax
    er_ok
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; er_virtio_enable_device — enable PCI memory + bus master
; void er_virtio_enable_device(VIRTIO_TRANSPORT* tr)
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
    or      eax, PCI_COMMAND_MEMORY | PCI_COMMAND_BUS_MASTER

    ; Write back via er_pci_write32 (read-modify-write the dword)
    mov     ecx, PCI_COMMAND
    push    rax
    movzx   edi, byte [r12 + VIRTIO_TRANSPORT.bus]
    movzx   esi, byte [r12 + VIRTIO_TRANSPORT.slot]
    movzx   edx, byte [r12 + VIRTIO_TRANSPORT.func]
    call    er_pci_read32          ; read full dword at offset 0x04
    and     eax, 0xFFFF0000        ; keep upper 16 bits (status)
    mov     ecx, eax
    pop     rax                    ; new command value
    and     eax, 0x0000FFFF        ; keep lower 16 bits
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
; _virtio_read_device_features — read 64-bit features from device
; uint64_t _virtio_read_device_features(uint64_t common_cfg)
; rdi = common_cfg MMIO address
; ==================================================================
_virtio_read_device_features:
    mov     rax, rdi
    ; device_features_sel = 0, read low
    mov     byte [rax + VIRTIO_COMMON_CFG_DEVICE_FEATURES_SEL], 0
    mov     r8d, [rax + VIRTIO_COMMON_CFG_DEVICE_FEATURES]
    ; device_features_sel = 1, read high
    mov     byte [rax + VIRTIO_COMMON_CFG_DEVICE_FEATURES_SEL], 1
    mov     eax, [rax + VIRTIO_COMMON_CFG_DEVICE_FEATURES]
    shl     rax, 32
    or      rax, r8
    ret

; ==================================================================
; _virtio_write_driver_features — write driver features to device
; void _virtio_write_driver_features(uint64_t common_cfg, uint64_t features)
; ==================================================================
_virtio_write_driver_features:
    ; driver_features_sel = 0, write low dword
    mov     byte [rdi + VIRTIO_COMMON_CFG_DRIVER_FEATURES_SEL], 0
    mov     [rdi + VIRTIO_COMMON_CFG_DRIVER_FEATURES], esi
    ; driver_features_sel = 1, write high dword
    mov     byte [rdi + VIRTIO_COMMON_CFG_DRIVER_FEATURES_SEL], 1
    shr     rsi, 32
    mov     [rdi + VIRTIO_COMMON_CFG_DRIVER_FEATURES], esi
    ret

; ==================================================================
; er_virtio_negotiate_features — negotiate Virtio features
; int er_virtio_negotiate_features(VIRTIO_TRANSPORT* tr,
;                                  uint64_t supported, uint64_t* driver_features_out)
;
; Returns: eax = 1 on success, 0 on failure.
; ==================================================================
er_fn er_virtio_negotiate_features
    er_frame_push
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; tr
    mov     r13, rsi            ; supported features
    mov     r14, rdx            ; out driver_features

    ; 1. Enable PCI memory + bus master
    mov     rdi, r12
    call    er_virtio_enable_device

    ; 2. Reset device
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    lea     rdi, [rdi + VIRTIO_COMMON_CFG_DEVICE_STATUS]
    xor     esi, esi
    call    er_virtio_write8

    ; 3. Acknowledge + Driver
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    lea     rdi, [rdi + VIRTIO_COMMON_CFG_DEVICE_STATUS]
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE
    call    er_virtio_write8

    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    lea     rdi, [rdi + VIRTIO_COMMON_CFG_DEVICE_STATUS]
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
    call    er_virtio_write8

    ; 4. Read device features
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    call    _virtio_read_device_features     ; rax = device features

    ; 5. Driver = device & supported
    and     rax, r13
    mov     r13, rax

    ; 6. Must have VIRTIO_F_VERSION_1 (bit 32)
    mov     rax, r13
    shr     rax, 32
    test    al, 1
    jz      .fail

    ; 7. Write driver features
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    mov     rsi, r13
    call    _virtio_write_driver_features

    ; 8. Set FEATURES_OK
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    lea     rdi, [rdi + VIRTIO_COMMON_CFG_DEVICE_STATUS]
    mov     esi, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
    call    er_virtio_write8

    ; 9. Verify features_ok
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    add     rdi, VIRTIO_COMMON_CFG_DEVICE_STATUS
    call    er_virtio_read8
    test    al, VIRTIO_STATUS_FEATURES_OK
    jz      .fail

    ; 10. Store driver features in output
    mov     [r14], r13

    mov     eax, 1
    er_ok
    jmp     .out

.fail:
    mov     rdi, [r12 + VIRTIO_TRANSPORT.common_cfg]
    lea     rdi, [rdi + VIRTIO_COMMON_CFG_DEVICE_STATUS]
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
; Queue management helpers
; ==================================================================

; void er_virtio_select_queue(VIRTIO_TRANSPORT* tr, uint16_t queue_num)
er_fn er_virtio_select_queue
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_SEL], si
    ret

; uint16_t er_virtio_read_queue_size(VIRTIO_TRANSPORT* tr)
er_fn er_virtio_read_queue_size
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    movzx   eax, word [rax + VIRTIO_COMMON_CFG_QUEUE_SIZE]
    ret

; void er_virtio_set_queue_desc(VIRTIO_TRANSPORT* tr, uint64_t addr)
er_fn er_virtio_set_queue_desc
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DESC_LOW], esi
    shr     rsi, 32
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DESC_HIGH], esi
    ret

; void er_virtio_set_queue_avail(VIRTIO_TRANSPORT* tr, uint64_t addr)
er_fn er_virtio_set_queue_avail
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DRIVER_LOW], esi
    shr     rsi, 32
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DRIVER_HIGH], esi
    ret

; void er_virtio_set_queue_used(VIRTIO_TRANSPORT* tr, uint64_t addr)
er_fn er_virtio_set_queue_used
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DEVICE_LOW], esi
    shr     rsi, 32
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_DEVICE_HIGH], esi
    ret

; void er_virtio_set_queue_size(VIRTIO_TRANSPORT* tr, uint16_t size)
er_fn er_virtio_set_queue_size
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_SIZE], si
    ret

; void er_virtio_enable_queue(VIRTIO_TRANSPORT* tr, uint16_t enable)
er_fn er_virtio_enable_queue
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_QUEUE_ENABLE], si
    ret

; uint16_t er_virtio_read_queue_notify_off(VIRTIO_TRANSPORT* tr)
er_fn er_virtio_read_queue_notify_off
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    movzx   eax, word [rax + VIRTIO_COMMON_CFG_QUEUE_NOTIFY_OFF]
    ret

; void er_virtio_notify_queue(VIRTIO_TRANSPORT* tr, uint16_t queue_num)
er_fn er_virtio_notify_queue
    mov     rax, [rdi + VIRTIO_TRANSPORT.notify_cfg]
    mov     r8d, [rdi + VIRTIO_TRANSPORT.notify_off_mult]
    ; notify address = notify_cfg + notify_off * notify_off_multiplier
    mov     eax, esi            ; queue_num as index
    mul     r8d                 ; eax = queue_num * notify_off_mult
    add     rax, [rdi + VIRTIO_TRANSPORT.notify_cfg]
    mov     [rax], si           ; write queue_num to notify register
    ret

; uint8_t er_virtio_read_status(VIRTIO_TRANSPORT* tr)
er_fn er_virtio_read_status
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    movzx   eax, byte [rax + VIRTIO_COMMON_CFG_DEVICE_STATUS]
    ret

; void er_virtio_write_status(VIRTIO_TRANSPORT* tr, uint8_t val)
er_fn er_virtio_write_status
    mov     rax, [rdi + VIRTIO_TRANSPORT.common_cfg]
    mov     [rax + VIRTIO_COMMON_CFG_DEVICE_STATUS], sil
    ret

; ==================================================================
; Descriptor ring helpers
; ==================================================================

; void er_virtio_post_descriptor(Avail* avail, uint16_t queue_size,
;                                uint16_t desc_id)
; rdi = avail ptr, rsi = queue_size, rdx = desc_id
; Avail layout: flags(2) + idx(2) + ring[queue_size](2*qs) + used_event(2)
er_fn er_virtio_post_descriptor
    movzx   ecx, word [rdi + 2]     ; current idx
    lea     r8d, [rsi - 1]          ; mask (power-of-2)
    and     r8d, ecx
    mov     [rdi + r8*2 + 4], dx    ; ring[idx % size] = desc_id
    inc     ecx
    mov     [rdi + 2], cx           ; update idx
    sfence
    ret

; int er_virtio_next_used(Used* used, uint16_t queue_size,
;                         uint16_t* last_used_idx)
; Returns: eax = 1 with rcx=id, r8=len if available; 0 if none.
er_fn er_virtio_next_used
    movzx   ecx, word [rdi + 2]     ; used->idx
    mov     r9w, [rdx]              ; *last_used_idx
    cmp     cx, r9w
    je      .none

    lea     r10d, [rsi - 1]
    and     r10d, r9d
    lea     r10, [rdi + r10*8 + 4]  ; used->ring[last_used_idx % size]
    mov     ecx, [r10]              ; id
    mov     r8d, [r10 + 4]          ; len
    inc     word [rdx]
    mov     eax, 1
    ret
.none:
    xor     eax, eax
    ret

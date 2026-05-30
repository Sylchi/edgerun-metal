; EdgeRun Virtio transport constants
; Included by virtio.asm, virtio_gpu.asm, and kernel consumers.

; Vendor / device
%define VIRTIO_VENDOR               0x1AF4
%define VIRTIO_DEVICE_GPU           0x1050
%define VIRTIO_DEVICE_TYPE_GPU      16

; Legacy I/O port register offsets (relative to BAR0 I/O base)
; The transitional virtio device provides a legacy interface via I/O ports on BAR0.
; QEMU i440FX does not forward MMIO to BAR4 at 0xFE000000 — use legacy I/O instead.
%define LEGACY_DEVICE_FEATURES      0x00  ; read 32-bit
%define LEGACY_GUEST_FEATURES       0x04  ; write 32-bit
%define LEGACY_QUEUE_ADDRESS        0x08  ; write 32-bit
%define LEGACY_QUEUE_SIZE           0x0C  ; read 16-bit
%define LEGACY_QUEUE_SELECT         0x0E  ; write 16-bit
%define LEGACY_QUEUE_NOTIFY         0x10  ; write 16-bit
%define LEGACY_DEVICE_STATUS        0x12  ; read/write 8-bit
%define LEGACY_ISR                  0x13  ; read 8-bit
%define LEGACY_DEVICE_CFG           0x14  ; device-specific config

; PCI capability types (vendor-specific capability for Virtio)
%define VIRTIO_PCI_CAP_VENDOR       0x09
%define VIRTIO_PCI_CAP_COMMON_CFG   1
%define VIRTIO_PCI_CAP_NOTIFY_CFG   2
%define VIRTIO_PCI_CAP_ISR_CFG      3
%define VIRTIO_PCI_CAP_DEVICE_CFG   4

; PCI config space offsets
%define PCI_VID                     0x00
%define PCI_DID                     0x02
%define PCI_COMMAND                 0x04
%define PCI_STATUS                  0x06
%define PCI_HEADER_TYPE             0x0E
%define PCI_BAR0                    0x10
%define PCI_CAP_LIST                0x34
%define PCI_COMMAND_MEMORY          0x0002
%define PCI_COMMAND_BUS_MASTER      0x0004
%define PCI_STATUS_CAPABILITIES     0x0010

; Device status register bits
%define VIRTIO_STATUS_ACKNOWLEDGE   0x01
%define VIRTIO_STATUS_DRIVER        0x02
%define VIRTIO_STATUS_DRIVER_OK     0x04
%define VIRTIO_STATUS_FEATURES_OK   0x08
%define VIRTIO_STATUS_FAILED        0x80

; Feature bits
%define VIRTIO_F_RING_INDIRECT_DESC (1 << 28)

; Virtio GPU feature bits
%define VIRTIO_GPU_F_VIRGL          (1 << 0)
%define VIRTIO_GPU_F_EDID           (1 << 1)
%define VIRTIO_GPU_F_RESOURCE_UUID  (1 << 2)
%define VIRTIO_GPU_F_RESOURCE_BLOB  (1 << 3)
%define VIRTIO_GPU_F_CONTEXT_INIT   (1 << 4)

; Split virtqueue descriptor flags
%define VIRTIO_DESC_F_NEXT          0x0001
%define VIRTIO_DESC_F_WRITE         0x0002
%define VIRTIO_DESC_F_INDIRECT      0x0004

; Queue constants
%define VIRTIO_QUEUE_SIZE           16
%define VIRTIO_DESC_SIZE            16
%define VIRTIO_AVAIL_SIZE           68  ; flags(2) + idx(2) + ring(16*2) + used_event(2)
%define VIRTIO_USED_SIZE            72  ; flags(2) + idx(2) + ring(16*8) + avail_event(2)

; Queue identifiers
%define VIRTIO_GPU_CONTROL_QUEUE    0
%define VIRTIO_GPU_CURSOR_QUEUE     1

%include "x86_64/wasm_defines.inc"

; ==================================================================
; VIRTIO_DEVICE — discovered device info (28 bytes)
; ==================================================================
struc VIRTIO_DEVICE
    .bus:               resb 1
    .slot:              resb 1
    .func:              resb 1
    .pad1:              resb 1
    .common_bar:        resb 1
    .notify_bar:        resb 1
    .device_bar:        resb 1
    .isr_bar:           resb 1
    .common_offset:     resd 1
    .notify_offset:     resd 1
    .device_offset:     resd 1
    .isr_offset:        resd 1
    .notify_off_mult:   resd 1
endstruc

; ==================================================================
; VIRTIO_TRANSPORT — legacy I/O port interface (20 bytes)
; Replaces the previous MMIO-based transport. Uses BAR0 I/O ports.
; ==================================================================
struc VIRTIO_TRANSPORT
    .io_base:           resw 1      ; BAR0 I/O port base (e.g., 0xC000)
    .device_config:     resw 1      ; device config I/O port (io_base + 0x14)
    .bus:               resb 1
    .slot:              resb 1
    .func:              resb 1
                        resb 1
    .notify_off_mult:   resd 1
endstruc

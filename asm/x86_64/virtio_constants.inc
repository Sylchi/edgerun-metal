; EdgeRun Virtio transport constants
; Included by virtio.asm, virtio_gpu.asm, and kernel consumers.

; Vendor / device
%define VIRTIO_VENDOR               0x1AF4
%define VIRTIO_DEVICE_GPU           0x1050
%define VIRTIO_DEVICE_TYPE_GPU      16

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
%define VIRTIO_F_VERSION_1          (1 << 32)
%define VIRTIO_F_RING_INDIRECT_DESC (1 << 28)

; Virtio GPU feature bits
%define VIRTIO_GPU_F_VIRGL          (1 << 0)
%define VIRTIO_GPU_F_EDID           (1 << 1)
%define VIRTIO_GPU_F_RESOURCE_UUID  (1 << 2)
%define VIRTIO_GPU_F_RESOURCE_BLOB  (1 << 3)
%define VIRTIO_GPU_F_CONTEXT_INIT   (1 << 4)

; Common cfg register offsets (relative to common_cfg base)
%define VIRTIO_COMMON_CFG_DEVICE_FEATURES_SEL 0
%define VIRTIO_COMMON_CFG_DEVICE_FEATURES     4
%define VIRTIO_COMMON_CFG_DRIVER_FEATURES_SEL 8
%define VIRTIO_COMMON_CFG_DRIVER_FEATURES     12
%define VIRTIO_COMMON_CFG_NUM_QUEUES          20
%define VIRTIO_COMMON_CFG_DEVICE_STATUS       20  ; same offset
%define VIRTIO_COMMON_CFG_QUEUE_SEL           22
%define VIRTIO_COMMON_CFG_QUEUE_SIZE          24
%define VIRTIO_COMMON_CFG_QUEUE_MSIX_VECTOR   26
%define VIRTIO_COMMON_CFG_QUEUE_ENABLE        28
%define VIRTIO_COMMON_CFG_QUEUE_NOTIFY_OFF    30
%define VIRTIO_COMMON_CFG_QUEUE_DESC_LOW      32
%define VIRTIO_COMMON_CFG_QUEUE_DESC_HIGH     36
%define VIRTIO_COMMON_CFG_QUEUE_DRIVER_LOW    40
%define VIRTIO_COMMON_CFG_QUEUE_DRIVER_HIGH   44
%define VIRTIO_COMMON_CFG_QUEUE_DEVICE_LOW    48
%define VIRTIO_COMMON_CFG_QUEUE_DEVICE_HIGH   52

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

; Error codes (returned in rdx)
%define ERROR_DEVICE_NOT_FOUND      1
%define ERROR_MAP_FAILED            2
%define ERROR_FEATURE_NEGOTIATION   3
%define ERROR_QUEUE_SETUP           4
%define ERROR_INVALID_RESPONSE      5
%define ERROR_INVALID_PARAM         6
%define ERROR_TIMEOUT               7

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
; VIRTIO_TRANSPORT — MMIO addresses and device identifiers (44 bytes)
; ==================================================================
struc VIRTIO_TRANSPORT
    .common_cfg:        resq 1      ; 8
    .notify_cfg:        resq 1      ; 8
    .device_cfg:        resq 1      ; 8
    .isr_cfg:           resq 1      ; 8
    .bus:               resb 1      ; 1
    .slot:              resb 1      ; 1
    .func:              resb 1      ; 1
                        resb 1      ; padding
    .notify_off_mult:   resd 1      ; 4
endstruc

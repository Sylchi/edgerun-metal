; EdgeRun PCI constant definitions — shared across drivers
; Single source for PCI register offsets, class codes, etc.

%ifndef PCI_CONSTANTS_INC
%define PCI_CONSTANTS_INC

; Configuration space register offsets (used by pci.asm, nvme.asm, virtio_constants.inc)
%define PCI_BAR0        0x10
%define PCI_BAR1        0x14
%define PCI_BAR2        0x18
%define PCI_BAR3        0x1C
%define PCI_BAR4        0x20
%define PCI_BAR5        0x24

; Standard PCI config registers
%define PCI_COMMAND                 0x04
%define PCI_STATUS                  0x06
%define PCI_REVISION_ID             0x08
%define PCI_CLASS_CODE              0x09
%define PCI_CACHE_LINE_SIZE         0x0C
%define PCI_LATENCY_TIMER           0x0D
%define PCI_HEADER_TYPE             0x0E
%define PCI_BIST                    0x0F
%define PCI_CAPABILITIES_PTR        0x34
%define PCI_INTERRUPT_LINE          0x3C
%define PCI_INTERRUPT_PIN           0x3D

; Command register bits
%define PCI_CMD_IO_SPACE            (1 << 0)
%define PCI_CMD_MEM_SPACE           (1 << 1)
%define PCI_CMD_BUS_MASTER          (1 << 2)
%define PCI_CMD_MEM_WRITE_INVAL     (1 << 4)

; Class codes
%define PCI_CLASS_STORAGE_NVME      0x0108
%define PCI_CLASS_NET_ETHERNET      0x0200
%define PCI_CLASS_SERIAL_USB_XHCI   0x0C03

; MMIO access flags
%define PCI_BAR_IO                  (1 << 0)
%define PCI_BAR_MEM_64BIT           (1 << 2)
%define PCI_BAR_MEM_PREFETCHABLE    (1 << 3)

%endif ; PCI_CONSTANTS_INC

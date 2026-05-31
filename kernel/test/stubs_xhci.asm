; Stubs for xHCI/PCI/MMIO/serial dependencies used by UVC self-test.

SECTION .text
global er_pci_read32
er_pci_read32:
    xor     eax, eax
    ret

global er_mmio_read32
er_mmio_read32:
    xor     eax, eax
    ret

global er_mmio_write32
er_mmio_write32:
    ret

global er_serial_puts
er_serial_puts:
    ret

global er_serial_puthex32
er_serial_puthex32:
    ret

global er_serial_putdec32
er_serial_putdec32:
    ret

global er_serial_putchar
er_serial_putchar:
    ret

global er_serial_crlf
er_serial_crlf:
    ret

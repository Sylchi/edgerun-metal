# EdgeRun Metal real hardware boot

Status: confirmed boot on real x86 hardware.

Hardware:
- Desktop: MSI X570 + Ryzen 5600X
- GPU: RTX 5060 Ti 16GB
- Laptop netboot host: Arch Linux over eth0
- Server IP: 10.42.0.1
- Client IP: 10.42.0.2

Confirmed:
- DHCP offer/request/ack works
- TFTP RRQ BOOTX64.EFI works
- BOOTX64.EFI loads
- EdgeRun Metal Core starts
- Wasm VM runs
- Wasm VM reports OK on real hardware

Architecture proven:
firmware -> BOOTX64.EFI -> EdgeRun Metal Core -> Wasm VM -> hostcalls

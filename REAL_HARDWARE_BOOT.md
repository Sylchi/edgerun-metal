# EdgeRun Metal real hardware boot

Status:
- x86_64 UEFI: confirmed boot on real hardware.
- Raspberry Pi 4B AArch64 UEFI: build path prepared; hardware boot not yet confirmed.

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

## Raspberry Pi 4B bring-up path

The Pi 4B path uses AArch64 UEFI, not the x86_64 PXE artifact. Build it from
`edgerun-metal/` with:

```bash
make ER_METAL_ARCH=aarch64
```

The generated removable-media boot artifact is:

```text
.build/edgerun-metal/aarch64/esp/EFI/BOOT/BOOTAA64.EFI
```

Copy that file to the FAT EFI system partition at `EFI/BOOT/BOOTAA64.EFI` on
Pi 4B boot media that already has working Raspberry Pi 4 UEFI firmware.

Expected first hardware proof:

- firmware loads `BOOTAA64.EFI`
- `EdgeRun Metal Core v0.2` reaches the UEFI console
- GOP framebuffer path renders the OS UI
- Wasm VM runs the embedded UI counter module

Known remaining Pi 4B work:

- confirm AArch64 EFI calling convention and image load on real firmware
- add a Pi 4B native input path; current production input path is PS/2
- add or select a Pi 4B native network/storage path after the UEFI console/GOP proof
- keep x86 I/O-port access disabled on AArch64; Pi hardware paths must use MMIO/firmware-described devices

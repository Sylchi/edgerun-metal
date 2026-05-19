# EdgeRun Metal real hardware boot

Status:
- x86_64 UEFI: confirmed boot on real hardware.
- Raspberry Pi 4B AArch64 UEFI: build path prepared; hardware boot not yet confirmed.
- Raspberry Pi Zero 2 W AArch64 U-Boot EFI: board profile and payload build
  path prepared; hardware boot not yet confirmed.
- Raspberry Pi Zero W v1.1 ARMv6: board profile and first owned `kernel.img`
  boot tree prepared; hardware boot not yet confirmed.

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

## Raspberry Pi Zero 2 W bring-up path

The Pi Zero 2 W path is tracked in `PI_ZERO_2W_BRINGUP.md`. Build its first
staged boot tree with:

```bash
make -C edgerun-metal pi-zero-2w-boot
```

The generated boot tree is:

```text
.build/edgerun-metal/pi-zero-2w/boot/
```

The intended first boot chain is explicit:

```text
Raspberry Pi firmware -> U-Boot EFI -> BOOTAA64.EFI -> EdgeRun Metal Core
```

The boot tree contains the repo-owned `EFI/BOOT/BOOTAA64.EFI` payload plus
`config.txt`, `startup.nsh`, and `EDGERUN-PI-ZERO-2W-BOOT.txt`. The manifest
names Raspberry Pi firmware and `u-boot.bin` as first-stage board prerequisites
so they are not confused with EdgeRun runtime dependencies.

The Pi Zero 2 W boards are the constrained hardware swarm target for proving
deterministic budgets, identity-routed storage, sealed package replication, and
small-change UI work scaling.

## Raspberry Pi Zero W v1.1 bring-up path

The Pi Zero W v1.1 path is a different board class from Pi Zero 2 W: BCM2835,
ARM11/ARMv6, 32-bit boot, and physical peripherals at `0x20000000`. Build its
first staged boot tree with:

```bash
make -C edgerun-metal pi-zero-w-v1_1-boot
```

The generated boot tree is:

```text
.build/edgerun-metal/pi-zero-w-v1_1/boot/
```

The intended first boot chain is explicit:

```text
Raspberry Pi firmware -> kernel.img
```

This path does not use the Pi Zero 2 W AArch64 EFI artifact. The staged
manifest is `EDGERUN-PI-ZERO-W-V1_1-BOOT.txt`, and the owned payload is the
freestanding ARMv6 `kernel.img`. The manifest also records the mini UART baud,
GPIO pins, expected boot banner, board constants, and first heartbeat line so a
bring-up harness can validate the board without guessing what success means.
Build the repo-owned verifier with `make pi-serial-verify`, then run
`.build/pi-serial-verify` with the staged manifest path and the captured UART
log path.

# Raspberry Pi Zero W v1.1 bring-up

Purpose: support the actual BCM2835 ARMv6 boards as a constrained swarm target
without misusing the Pi Zero 2 W AArch64 EFI path.

## Current Boot Target

Build the staged boot tree with:

```sh
make -C edgerun-metal pi-zero-w-v1_1-boot
```

Output:

```text
.build/edgerun-metal/pi-zero-w-v1_1/boot/
.build/edgerun-metal/pi-zero-w-v1_1/boot/kernel.img
.build/edgerun-metal/pi-zero-w-v1_1/boot/config.txt
.build/edgerun-metal/pi-zero-w-v1_1/boot/startup.nsh
.build/edgerun-metal/pi-zero-w-v1_1/boot/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt
```

The intended first hardware chain is:

```text
Raspberry Pi firmware -> kernel.img
```

The current `kernel.img` is the first repo-owned ARMv6 payload boundary. The
next step is to replace the idle marker payload with serial output, board
capability reporting, and the same SDIO command execution path used by the Pi
radio/storage bring-up code.

## Board Facts Captured In Code

- peripheral physical base: `0x20000000`
- wireless runtime kind: `CYW43438 SDIO`
- Bluetooth runtime kind: `CYW43438 HCI UART`
- boot architecture: `armv6`
- owned boot payload name: `kernel.img`

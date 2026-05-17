# EdgeRun Metal: next core work

The real hardware boot milestone is complete. The next work is no longer PXE plumbing; it is the metal core.

## Proven baseline

- x86_64 UEFI firmware loads `BOOTX64.EFI` from the laptop netboot host.
- EdgeRun Metal Core starts on real hardware.
- The embedded Wasm VM executes on real hardware.
- Hostcall plumbing exists for logging and PCI config-space access.

## Freeze rule

Do not destabilize the working netboot path unless a change is directly required. Networking is now a support path, not the product.

## Core milestones

### M1: Boot profiles

Status: complete.

Build-time profiles exist:

- `smoke`: print boot banner, run test Wasm, halt.
- `pci`: run concise native PCI target scan, halt.
- `quiet`: minimal output, halt.

Default should be `smoke` so real hardware boot remains fast and readable.

### M2: Serial logging

Status: complete.

COM1 serial output mirrors all `er_print` calls.

Reason: screen output is fragile during firmware/core work. Serial gives persistent capture through QEMU and real hardware if connected later.

### M3: PCI target filter

Status: complete in the native `pci` profile.

The scanner targets:

- NVIDIA vendor `0x10de`
- NVMe class `0x0108xx`
- Ethernet class `0x0200xx`

The scanner should print concise device records instead of flooding the screen.

### M4: MMIO map/read hostcalls

Status: in progress.

Current foundation:

- PCI config access is split into `core/er_pci.c`.
- BAR register decode is test-covered.
- read-only MMIO handle/range validation is split into `core/er_mmio.c`.
- Wasm imports exist for `edgerun.mmio.map` and `edgerun.mmio.read32`.
- `mmio` profile maps a fixed 4 KiB NVIDIA BAR0 window read-only and reads a tiny fixed offset set.

Next M4 work:

- boot the `mmio` profile on real hardware and capture BAR0 values
- decide whether to keep fixed-window probing or add guarded BAR size discovery
- move the probe into Wasm once the native path is proven

Do not add MMIO writes yet.

### M5: NVIDIA BAR0 safe probe

Status: not started.

From Wasm:

- find vendor `0x10de`
- read BAR0/BAR1 from PCI config
- map BAR0 read-only
- read a small fixed set of safe offsets
- print values

No firmware loading, no mode setting, no compute yet.

## Current priority

Finish M4 by turning decoded BARs into bounded read-only maps, then add the smallest NVIDIA BAR0 safe probe.

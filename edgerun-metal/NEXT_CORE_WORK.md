# EdgeRun Metal: next core work

The real hardware boot milestone is complete. The next work is no longer PXE plumbing; it is the metal core.

## Proven baseline

- x86_64 UEFI firmware loads `BOOTX64.EFI` from the laptop netboot host.
- EdgeRun Metal Core starts on real hardware.
- The embedded Wasm VM executes on real hardware.
- Hostcall plumbing exists for logging and PCI config-space access.

## Freeze rule

Do not destabilize the working netboot path unless a change is directly required. Networking is now a support path, not the product.

## Immediate core milestones

### M1: Boot profiles

Add one build-time or runtime-selected boot profile:

- `smoke`: print boot banner, run test Wasm, halt.
- `pci`: run PCI scan module, halt.
- `quiet`: minimal output, halt.

Default should be `smoke` so real hardware boot remains fast and readable.

### M2: Serial logging

Add COM1 serial output mirror for all `er_print` calls.

Reason: screen output is fragile during firmware/core work. Serial gives persistent capture through QEMU and real hardware if connected later.

### M3: PCI target filter

Keep the full PCI scanner available, but add a targeted scanner for vendor/device discovery:

- NVIDIA vendor `0x10de`
- NVMe class `0x0108xx`
- Ethernet class `0x0200xx`

The scanner should print concise device records instead of flooding the screen.

### M4: MMIO map/read hostcalls

Add native hostcalls:

- `edgerun.mmio.map(phys, len) -> handle`
- `edgerun.mmio.read32(handle, offset) -> i64`
- `edgerun.mmio.write32(handle, offset, value)` later, guarded

First version should be read-only. Do not write GPU registers yet.

### M5: NVIDIA BAR0 safe probe

From Wasm:

- find vendor `0x10de`
- read BAR0/BAR1 from PCI config
- map BAR0 read-only
- read a small fixed set of safe offsets
- print values

No firmware loading, no mode setting, no compute yet.

## Current priority

Start with M1 and M2. Once boot output is controlled and serial mirroring exists, continue with M3 and M4.

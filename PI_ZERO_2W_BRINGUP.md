# Raspberry Pi Zero 2 W bring-up

Purpose: use six constrained AArch64 boards to prove EdgeRun's deterministic,
budget-based OS model on real, heterogeneous hardware.

Note: Pi Zero W v1.1 is a separate ARMv6 board path. Use
`PI_ZERO_W_V1_1_BRINGUP.md` and `make -C edgerun-metal pi-zero-w-v1_1-boot`
for those boards.

The Pi Zero 2 W target is not a performance excuse. It is the opposite: it is a
hard budget microscope. The UI target remains 4K120-class behavior by work
units, not by repainting every pixel every tick. If a board cannot hit a target,
the system must show exactly which budget was exhausted: layout work, dirty
area, glyph/cache misses, command emission, memory traffic, storage traffic, or
relay traffic.

## Board Role Plan

Use six boards with fixed labels:

```text
erz2w-0  bootstrap identity, package index publisher, serial console first boot
erz2w-1  sealed object storage replica
erz2w-2  relay-only node
erz2w-3  offline/rejoin and failure-injection node
erz2w-4  second sealed object storage replica, replica divergence check
erz2w-5  mobile/observer node, route churn and late admission check
```

Every board must get an explicit device identity before it is allowed to join a
swarm. Path names, hostnames, DHCP leases, and MAC addresses are not authority.

## Current Boot Target

The first Pi Zero 2 W artifact path stages a deterministic boot directory:

```sh
make -C edgerun-metal pi-zero-2w-boot
```

Output:

```text
.build/edgerun-metal/pi-zero-2w/boot/
.build/edgerun-metal/pi-zero-2w/boot/EFI/BOOT/BOOTAA64.EFI
.build/edgerun-metal/pi-zero-2w/boot/config.txt
.build/edgerun-metal/pi-zero-2w/boot/startup.nsh
.build/edgerun-metal/pi-zero-2w/boot/EDGERUN-PI-ZERO-2W-BOOT.txt
```

The intended first hardware chain is:

```text
Raspberry Pi firmware -> U-Boot EFI -> EFI/BOOT/BOOTAA64.EFI -> EdgeRun Metal
```

This is explicit. It is not a claim that the repository already owns the
Raspberry Pi first-stage firmware or U-Boot. Until we own or vendor an audited
first-stage path, those files are board bring-up prerequisites, not EdgeRun
runtime dependencies.

The EFI-only payload is still available when a board already has an EFI boot
environment:

```sh
make -C edgerun-metal pi-zero-2w-uefi
```

## First Boot Proof

Minimum successful boot evidence:

- board label is recorded
- boot media contains `EFI/BOOT/BOOTAA64.EFI`
- firmware reaches the EFI app
- `EdgeRun Metal Core` prints on serial or framebuffer
- AArch64 freestanding build reports the selected board profile
- boot does not require x86 I/O ports
- missing native input, native storage, or native network hardware does not kill
  the UI/VM path

## UI Budget Proof

The Pi bring-up is not complete if it only prints text. It must also produce
work-unit evidence for UI changes:

- full scene load work
- no-change frame work
- one small text change work
- one cursor/focus change work
- dirty region area
- glyph cache hits and misses
- emitted draw command count
- bytes touched in render surfaces

A 4K120-class target is acceptable on small hardware only if misses are
explained by explicit budgets. The invariant is that unchanged pixels do not
create repeated work.

## Swarm Proof

After single-board boot, prove the distributed model:

- six explicit device identities
- signed package index published by `erz2w-0`
- sealed content chunks replicated to `erz2w-1` and `erz2w-4`
- relay traffic through `erz2w-2`
- `erz2w-3` offline during publish, then rejoined by content identity
- `erz2w-5` joins after the first route set is established and must not become
  implicit authority
- package install by hash and signature, not path or label
- storage nodes never receive plaintext app content
- route receipts account for each transfer

## Bring-Up Checklist

- [x] Add explicit `pi-zero-2w` board profile.
- [x] Add deterministic AArch64 EFI payload build target.
- [x] Add repo-owned Pi boot artifact staging tool and generated boot manifest.
- [ ] Confirm `BOOTAA64.EFI` loads through U-Boot EFI on one board.
- [ ] Capture serial boot log from `erz2w-0`.
- [ ] Add a repo-owned serial log checker for Pi boot evidence.
- [ ] Add deterministic six-node identity material generation.
- [ ] Add Pi swarm package index and sealed-object replication tests.
- [ ] Add UI work-unit budget benchmark for no-change and small-change frames.
- [ ] Add native Pi framebuffer/input/storage/network platform boundaries.

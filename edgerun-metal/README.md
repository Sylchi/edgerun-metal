# EdgeRun Metal v0.2

From-scratch x86_64 UEFI metal runtime that boots as `BOOTX64.EFI` and executes embedded Wasm modules with native hostcalls.

## Current status

Real hardware boot is confirmed.

Hardware used for first proof:

- Desktop: MSI X570 + Ryzen 5600X
- GPU: RTX 5060 Ti 16GB
- Laptop netboot host: Arch Linux over `eth0`
- Server IP: `10.42.0.1`
- Client IP: `10.42.0.2`

Confirmed path:

```text
firmware -> BOOTX64.EFI -> EdgeRun Metal Core -> Wasm VM -> hostcalls
```

Confirmed working:

- DHCP offer/request/ack over laptop Ethernet
- TFTP RRQ for `BOOTX64.EFI`
- `BOOTX64.EFI` loads on real hardware
- EdgeRun Metal Core starts
- Wasm VM runs on real hardware
- PCI config-space hostcalls exist
- COM1 serial mirror exists for `er_print`
- Boot profiles exist: `ui`, `native`, `tpm`, `gpu`
- Wasm module headers are generated from tracked WAT sources
- Generated build artifacts are ignored by Git
- GOP and VirtIO GPU UI rendering paths exist for scene-backed app surfaces
- The renderer architecture targets CPU-driven 4K120 from the start; see `docs/metal-renderer-4k120.md`

## Current objective

Netboot is now support infrastructure. Do not keep redesigning it unless it blocks boot.

The real work is the relay core that lets user-authored Wasm apps run with polished UI:

1. Keep the UI runtime and active hardware profiles stable.
2. Use native VirtIO-net as the first EdgeRun Ethernet ingress.
3. Parse incoming erwire packets without firmware networking.
4. Verify admitted render capability work before dispatching it to GOP or VirtIO GPU endpoint adapters.
5. Verify admitted storage work before dispatching it to object storage or VirtIO block endpoint adapters.
6. Move app-authored UI, input, driver, storage, and device work through one erwire relay model.

The cross-project architecture is documented in `../docs/relay-architecture.md`.

## Philosophy

Do not rebuild Linux.

Use existing driver code as source material, but run only extracted/adapted logic inside isolated Wasm modules. Direct hardware hostcalls are bring-up scaffolding. The durable driver ABI is relay packet send/receive through erwire, with endpoint adapters owning the local hardware queue or bus operation.

Bring-up may still use narrow hostcalls while a device endpoint is not proven:

```text
pci.config.read/write
pci.enable.bus_master
pci.bar.info
mmio.map/read/write
dma.alloc/map/sync/free
irq.register/ack
event.wait
time.sleep/log
firmware.blob.get
```

Those calls should collapse behind relay endpoints as each device path becomes real. The goal is hardware control without dragging in a full general-purpose kernel/device model or inventing a second driver RPC path.

## Build dependencies

On Arch Linux:

```bash
sudo pacman -S clang lld qemu-full edk2-ovmf
sudo pacman -S ccache mold wabt
```

`wabt` provides `wat2wasm`, which is used to regenerate embedded Wasm module headers from source WAT files.
`ccache` accelerates repeat local builds. `mold` is used only for hosted Linux
tools and tests; the UEFI binary still links with LLVM `lld`.

## Build profiles

Default build is the interactive `ui` profile:

```bash
make -C edgerun-metal
```

Explicit profiles:

```bash
make -C edgerun-metal wasm-modules
make -C edgerun-metal ui
make -C edgerun-metal native
make -C edgerun-metal tpm
make -C edgerun-metal gpu
```

Profiles:

```text
ui     = VirtIO GPU-backed UI runtime, Wasm UI app, PS/2 input loop
native = QEMU microvm VirtIO-MMIO erwire-over-Ethernet probe
tpm    = QEMU swtpm/TPM2 CRB direct command probe
gpu    = VirtIO GPU/VGA PCI framebuffer probe
```

Output:

```text
edgerun-metal/build/edgerun-metal.efi
edgerun-metal/build/esp/EFI/BOOT/BOOTX64.EFI
```

## Run in QEMU

```bash
make -C edgerun-metal run
```

## Netboot baseline

Netboot should serve the generated EFI from:

```text
/home/ken/edgerun-c/edgerun-metal/build/esp/EFI/BOOT/BOOTX64.EFI
```

The working desktop path is UEFI PXE/TFTP. Current known-good behavior:

```text
DHCPDISCOVER
DHCPOFFER
DHCPREQUEST
DHCPACK
TFTP RRQ BOOTX64.EFI
TFTP DATA
BOOTX64.EFI executes
```

Useful commands:

```bash
make -C edgerun-metal netboot
```

Packet capture:

```bash
sudo tcpdump -i eth0 -n -e -vvv -s0 'udp port 67 or udp port 68 or udp port 69 or udp port 4011 or tcp port 8081 or arp'
```

Expected DHCP options:

```text
Server-ID:       10.42.0.1
Subnet-Mask:     255.255.255.0
Default-Gateway: 10.42.0.1
TFTP server:     10.42.0.1
Bootfile:        BOOTX64.EFI or EFI/BOOT/BOOTX64.EFI
```

## Local next goal

Build and test the default UI profile:

```bash
cd /home/ken/edgerun-c
git pull --ff-only origin main
make -C edgerun-metal ui
```

Expected real-hardware screen output:

```text
EdgeRun Metal Core v0.2
UEFI boot OK
boot profile: ui
ui renderer: init font
ui renderer: render scene
boot services: exiting
```

Retired bring-up profiles are covered by host tests instead of boot targets.

## Bus model

Most high-value desktop devices start at PCI/PCIe discovery:

```text
GPU: PCIe
NVMe: PCIe
Ethernet: PCIe or chipset PCIe
USB/xHCI: PCIe controller
SATA/AHCI: PCIe-visible controller
Audio/HDA: PCIe-visible device
Chipset devices: PCI/PCIe enumerated
```

Other buses/layers to add later:

```text
MMIO: register access after BAR discovery
I/O ports: legacy x86 controls, serial, PCI config CF8/CFC
ACPI: topology, memory, interrupts, timers, power
APIC/MSI/MSI-X: interrupts
USB/xHCI: USB devices behind PCI controller
I2C/SMBus: sensors, SPD, board controllers
SPI/eSPI/LPC: firmware chip, embedded controller, super I/O
```

Hardware bring-up order:

```text
1. PCI config scan
2. BAR discovery
3. Read-only MMIO mapping
4. ACPI table discovery
5. Interrupts
6. DMA
7. Device endpoint adapters
```

These are adapter-enabling steps. They are not the app or driver ABI. Apps and drivers talk through erwire relay packets; endpoint adapters translate admitted packets into local hardware operations.

## Proven bring-up

### PCI target classification

Status: covered by host tests and active VirtIO PCI paths.

- NVIDIA vendor `0x10de`
- NVMe class `0x0108xx`
- Ethernet class `0x0200xx`

### MMIO read-only hostcalls

Status: covered by host tests and used by active native device paths.

```text
edgerun.mmio.map(phys, len) -> handle
edgerun.mmio.read32(handle, offset) -> i64
```

Current limits:

- read-only only
- fixed native handle table
- range and alignment validation before reads
- no Boot Services memory ownership changes

### Native erwire over VirtIO-net

Status: implemented as the first native relay transport proof.

The native profile can bring up VirtIO-net and submit EdgeRun Ethernet frames with EtherType `0x88b5`.

### Native Relay Ingress

Status: host-tested ingress records implemented; admission-defined route verification, native profile loop, and device adapters are next.

`er_native_boot_poll_relay_ingress` accepts native erwire packets and records accepted, malformed, or empty ingress deterministically. The durable path must decode `edgerun-work` records, verify signed admissions, then hand assigned local endpoint adapters only already-admitted work.

### Wasm relay app boundary

Status: bounded relay imports implemented; app-authored UI proof is next.

The Wasm interpreter supports `edgerun.relay/send` and `edgerun.relay/recv` imports through declared inbox/outbox windows. Relay send validates the serialized relay packet, source app node id, admission id, budget token, and packet-byte budget before calling the host relay hook. This is the correct app boundary; direct PCI/MMIO/bus imports remain bring-up scaffolding for drivers until relay device endpoints are proven.

### User-authored UI apps

Status: UI foundations, concurrent local Wasm app contexts, content-addressed app package records, bounded object packet reassembly, package object loading, boot-local package-loaded app launch, admitted storage-source binding, and storage-bound package loading implemented; storage endpoint integration is next.

`edgerun-ui-core`, `varfont`, the GOP renderer, and the VirtIO GPU profile now provide enough scene, text, theme, component, and framebuffer machinery to target real app surfaces instead of diagnostics. The boot UI profile can now keep multiple Wasm UI app runtimes resident at once, each with preallocated memory, presentation identity, scene state, and its own `ui_emit` context. `er_app` can now prepare package manifests from content-addressed app code, manifest, and UI asset object refs without deriving package identity from labels. `er_vfs` can reassemble loaded object packets into bounded memory after validating packet and object hashes, and `er_app` can load those package objects into caller-owned buffers before launch. The boot UI app path now uses the storage-bound package loader and prepares each resident Wasm runtime from persistent per-app loaded module bytes. Saved package sources now bind package ids to admitted storage-retrieve route ids, and storage-bound package loading rejects retrieved packet sets that do not match those route ids. The next proof should connect admitted storage endpoint responses to that loader, let the loaded app emit admitted scene or scene-delta packets, and render the result through an endpoint-owned renderer.

## Next milestones

Use `NEXT_CORE_WORK.md` and `../docs/coherent-system-milestones.md` as the active checklist. In short:

```text
1. Object-only storage and app packaging contract
2. Native relay ingress loop and admission-defined acknowledgement
3. Admission-defined render endpoint capture for app UI scenes
4. Admission-defined storage endpoint capture for app/object payloads
5. User-authored Wasm UI app proof
6. Distributed UI proof
7. Remote driver proof
```

## ExitBootServices policy

Do not call `ExitBootServices` yet.

Stay in UEFI app mode until:

- boot output is stable
- serial mirror is proven
- native erwire ingress works
- admission-defined route verification can hand admitted packets to VirtIO endpoint adapters
- storage and render endpoint proofs exist

Only exit Boot Services when firmware services actively block ownership of hardware.

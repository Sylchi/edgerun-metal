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
- A single OS boot path exists; native VirtIO and TPM code are device capabilities, not separate debug paths
- Wasm module headers are generated from tracked WAT sources
- Generated build artifacts are ignored by Git
- VirtIO GPU UI rendering paths exist for scene-backed app surfaces

## Current objective

Netboot is now support infrastructure. Do not keep redesigning it unless it blocks boot.

The real work is the relay core that lets user-authored Wasm apps run with polished UI:

1. Keep the OS runtime stable.
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

## Build OS Image

Default build is the OS image:

```bash
make -C edgerun-metal
```

Explicit OS build:

```bash
make -C edgerun-metal wasm-modules
make -C edgerun-metal os
```

Boot path:

```text
os = VirtIO GPU-backed UI runtime, Wasm apps, PS/2 input, storage-bound package loading, relay/device endpoints
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

Build and test the OS image:

```bash
cd /home/ken/edgerun-c
git pull --ff-only origin main
make -C edgerun-metal os
```

Expected real-hardware screen output:

```text
EdgeRun Metal Core v0.2
UEFI boot OK
boot path: os
ui renderer: init font
ui renderer: render scene
boot services: exiting
```

Retired bring-up paths are covered by host tests instead of boot targets.

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

The runtime can bring up VirtIO-net and submit EdgeRun Ethernet frames with EtherType `0x88b5`.

### Native Relay Ingress

Status: host-tested ingress records implemented; admission-defined route verification, OS loop integration, and device adapters are next.

`er_native_boot_poll_relay_ingress` accepts native erwire packets and records accepted, malformed, or empty ingress deterministically. The durable path must decode `edgerun-work` records, verify signed admissions, then hand assigned local endpoint adapters only already-admitted work.

### Wasm relay app boundary

Status: bounded relay imports implemented; app-authored UI proof is next.

The Wasm interpreter supports `edgerun.relay/send` and `edgerun.relay/recv` imports through declared inbox/outbox windows. Relay send validates the serialized relay packet, source app node id, admission id, budget token, and packet-byte budget before calling the host relay hook. This is the correct app boundary; direct PCI/MMIO/bus imports remain bring-up scaffolding for drivers until relay device endpoints are proven.

### User-authored UI apps

Status: UI foundations, concurrent local Wasm app contexts, content-addressed app package records, bounded object packet reassembly, package object loading, boot-local package-loaded app launch, admitted storage-source binding, storage endpoint response adaptation, storage-bound package loading, Wasm render capability relay-send proof, render endpoint capture, endpoint-owned scene decode, and OS loop consumption of endpoint-owned app scenes implemented; relay-ingress route integration and VirtIO GPU endpoint submission are next.

`edgerun-ui-core`, `varfont`, and the VirtIO GPU path now provide enough scene, text, theme, component, and framebuffer machinery to target real app surfaces instead of diagnostics. The OS path can keep multiple Wasm UI app runtimes resident at once, each with preallocated memory, presentation identity, scene state, and its own `ui_emit` context. `er_app` can now prepare package manifests from content-addressed app code, manifest, and UI asset object refs without deriving package identity from labels. `er_vfs` can reassemble loaded object packets into bounded memory after validating packet and object hashes, and `er_app` can load those package objects into caller-owned buffers before launch. The boot app path now uses typed storage endpoint responses, the storage-bound package loader, and persistent per-app loaded module bytes before preparing each resident Wasm runtime. Saved package sources now bind package ids to admitted storage-retrieve route ids, and storage-bound package loading rejects endpoint responses that do not match those route ids or expected object identities. Wasm fixtures can now emit render capability invocation packets through `edgerun.relay/send` under the same outbox, admission, token, and packet-byte budget checks as other app relay traffic, and `er_render_endpoint` can capture and decode those packets only after route, channel envelope, source/target, sequence, and scene hash verification. The OS loop now consumes app scenes after the render endpoint capture/decode step instead of decoding `ui_emit` payloads through a parallel path. The next proof should connect this path to relay ingress and make VirtIO GPU submission an explicit endpoint adapter.

## Next milestones

Use `NEXT_CORE_WORK.md` and `../docs/coherent-system-milestones.md` as the active checklist. In short:

```text
1. Object-only storage and app packaging contract
2. Native relay ingress loop and admission-defined acknowledgement
3. Admission-defined render endpoint scene decode and presentation for app UI scenes
4. Admission-defined storage endpoint capture for app/object payloads
5. User-authored Wasm UI app proof
6. Distributed UI proof
7. Remote driver proof
```

## ExitBootServices policy

The OS path should exit Boot Services as soon as the runtime has prepared the memory and device state it needs to keep running. Do not add new firmware-service dependencies to relay, rendering, storage, input, scheduling, or app execution.

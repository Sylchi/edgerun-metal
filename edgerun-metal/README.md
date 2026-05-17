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
- Boot profiles exist: `smoke`, `pci`, `quiet`, `mmio`, `ui`
- Wasm module headers are generated from tracked WAT sources
- Generated build artifacts are ignored by Git
- GOP-backed UI rectangle scene renderer exists for the `ui` profile
- The renderer architecture targets CPU-driven 4K120 from the start; see `docs/metal-renderer-4k120.md`

## Current objective

Netboot is now support infrastructure. Do not keep redesigning it unless it blocks boot.

The real work is the core:

1. Keep `smoke` boot stable.
2. Use `pci` profile for concise device discovery.
3. Add read-only MMIO mapping hostcalls.
4. Probe NVIDIA/NVMe/Ethernet BARs safely.
5. Build the minimal driver-runtime hostcall surface for Wasm driver modules.

## Philosophy

Do not rebuild Linux.

Use existing driver code as source material, but run only extracted/adapted logic inside isolated Wasm modules. EdgeRun provides the minimal hostcalls needed by that driver logic:

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

The goal is hardware control without dragging in a full general-purpose kernel/device model.

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

Default build is `smoke` profile:

```bash
make -C edgerun-metal
```

Explicit profiles:

```bash
make -C edgerun-metal wasm-modules
make -C edgerun-metal smoke
make -C edgerun-metal pci
make -C edgerun-metal quiet
make -C edgerun-metal mmio
make -C edgerun-metal ui
```

Profiles:

```text
smoke = banner + test Wasm only
pci   = concise PCI target scan: NVIDIA / NVMe / Ethernet
quiet = minimal halt-ready boot
mmio  = conservative read-only NVIDIA BAR0 probe
ui    = GOP-backed UI-core component scene
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

Build and test the `pci` profile:

```bash
cd /home/ken/edgerun-c
git pull --ff-only origin main
make -C edgerun-metal pci
```

Expected real-hardware screen output:

```text
EdgeRun Metal Core v0.2
UEFI boot OK
boot profile: pci
PCI target scan: nvidia/nvme/ethernet
  target: nvidia ...
  target: nvme ...
  target: ethernet ...
PCI target scan done
Press any key to halt...
```

If build fails with unused profile functions, the fix is to avoid preprocessor-removing profile calls or mark unused functions intentionally. Current intended code path uses runtime `if`/profile dispatch so all profile functions remain referenced.

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

Practical order:

```text
1. PCI config scan
2. BAR discovery
3. Read-only MMIO mapping
4. ACPI table discovery
5. Interrupts
6. DMA
7. Wasm driver runtime
```

## Next milestones

### M3: concise PCI target scanner

Status: implemented in native core profile `pci`.

Targets:

- NVIDIA vendor `0x10de`
- NVMe class `0x0108xx`
- Ethernet class `0x0200xx`

### M4: MMIO read-only hostcalls

Foundation added:

```text
edgerun.mmio.map(phys, len) -> handle
edgerun.mmio.read32(handle, offset) -> i64
```

Current limits:

- read-only only
- fixed native handle table
- range and alignment validation before reads
- `mmio` profile maps only a fixed 4 KiB BAR0 window
- no Boot Services memory ownership changes
- no MMIO writes yet

### M5: NVIDIA BAR0 safe probe

From the core or Wasm:

- find vendor `0x10de`
- inspect BAR0/BAR1
- map BAR0 read-only
- read a tiny fixed set of safe offsets
- print values

No firmware loading. No mode setting. No compute dispatch yet.

## ExitBootServices policy

Do not call `ExitBootServices` yet.

Stay in UEFI app mode until:

- boot output is stable
- serial mirror is proven
- PCI/BAR discovery works
- read-only MMIO probing works

Only exit Boot Services when firmware services actively block ownership of hardware.

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
- Boot profiles exist: `smoke`, `pci`, `quiet`
- Generated build artifacts are ignored by Git

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
```

## Build profiles

Default build is `smoke` profile:

```bash
make -C edgerun-metal
```

Explicit profiles:

```bash
make -C edgerun-metal smoke
make -C edgerun-metal pci
make -C edgerun-metal quiet
```

Profiles:

```text
smoke = banner + test Wasm only
pci   = concise PCI target scan: NVIDIA / NVMe / Ethernet
quiet = minimal halt-ready boot
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
sudo systemctl restart edgerun-netboot
sudo systemctl restart edgerun-pxe4011 || true
sudo journalctl -u edgerun-netboot -f
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

## Always-on netboot service

Service files:

```text
edgerun-metal/systemd/edgerun-netboot.service
edgerun-metal/systemd/edgerun-pxe4011.service
/etc/edgerun-netboot.env
```

Recommended env:

```text
EDGERUN_NETBOOT_IFACE=eth0
EDGERUN_NETBOOT_MODE=auto
EDGERUN_NETBOOT_ALLOW_MAC=00:d8:61:d7:50:30
EDGERUN_NETBOOT_CLIENT_IP=10.42.0.2
EDGERUN_NETBOOT_MGMT_DHCP=1
EDGERUN_NETBOOT_MGMT_MAC=
EDGERUN_NETBOOT_MGMT_IP=10.42.0.10
EDGERUN_NETBOOT_HTTP_PORT=8081
EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE=0
EDGERUN_NETBOOT_EFI=/home/ken/edgerun-c/edgerun-metal/build/esp/EFI/BOOT/BOOTX64.EFI
```

## Local next goal

Build and test the `pci` profile:

```bash
cd /home/ken/edgerun-c
git pull --ff-only origin main
make -C edgerun-metal pci
sudo systemctl restart edgerun-netboot
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

Add:

```text
edgerun.mmio.map(phys, len) -> handle
edgerun.mmio.read32(handle, offset) -> i64
```

No MMIO writes yet.

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

# Agent next task: Ethernet netlog

We need real hardware boot output without manually reading the screen.

## Goal

Mirror `er_print` output over Ethernet to the laptop while still in UEFI app mode.

Netboot already proves the machine has Ethernet link and firmware network stack during boot. Use UEFI networking, not a custom NIC driver yet.

## Required behavior

- Keep console output working.
- Keep COM1 serial mirror working.
- Add Ethernet log mirror if UEFI networking protocol is available.
- Failure to initialize Ethernet log must not stop boot.
- Log transport: UDP datagrams to laptop.

Defaults:

```text
server/listener IP: 10.42.0.1
server/listener UDP port: 9000
client IP: firmware-assigned or UEFI-managed
```

## Host-side listener

Add a simple listener script:

```text
edgerun-metal/tools/edgerun-log-listen.sh
```

It should run:

```bash
socat -u UDP-RECV:9000,reuseaddr,fork -
```

or fallback to:

```bash
nc -ul 9000
```

## Core-side implementation

Add:

```text
core/er_netlog.c
core/er_netlog.h
```

API:

```c
void er_netlog_init(EFI_SYSTEM_TABLE* st);
void er_netlog_write(const char* s);
```

Wire it into `er_print.c`:

- `er_print_set_system_table(st)` should initialize serial and netlog.
- `er_print(s)` should call `er_netlog_write(s)` after serial write and before/after console output.

## UEFI protocol approach

Preferred: UEFI UDP4 Service Binding + UDP4 Protocol.

Because `EFI_SYSTEM_TABLE->BootServices` is currently typed as `void*`, first extend `er_types.h` with only the Boot Services fields/prototypes needed for:

- LocateHandleBuffer
- HandleProtocol
- CreateEvent if needed by UDP4 transmit completion
- CloseEvent if used

Then define only the minimal UDP4 protocol/service binding types needed for transmit.

Do not implement a full UEFI binding layer.

## Reliability rules

- If any UEFI network call fails, disable netlog and continue boot.
- Do not block boot waiting for network.
- Use small datagrams. Splitting `er_print` chunks is acceptable.
- Add clear console lines:

```text
netlog: init ok 10.42.0.1:9000
```

or:

```text
netlog: unavailable
```

## Build

Update Makefile:

- include `core/er_netlog.c` in `SRCS`
- add `log-listen` target:

```bash
make -C edgerun-metal log-listen
```

## Test sequence

On laptop:

```bash
cd /home/ken/edgerun-c
git pull --ff-only origin main
make -C edgerun-metal smoke
sudo systemctl restart edgerun-netboot
make -C edgerun-metal log-listen
```

Then PXE boot desktop.

Expected laptop output:

```text
EdgeRun Metal Core v0.2
UEFI boot OK
boot profile: smoke
Wasm VM OK
```

After smoke works, run:

```bash
make -C edgerun-metal pci
sudo systemctl restart edgerun-netboot
make -C edgerun-metal log-listen
```

Expected laptop output includes concise PCI target output.

## Do not do yet

- Do not call ExitBootServices.
- Do not write GPU MMIO registers.
- Do not implement a NIC driver.
- Do not depend on Linux after BOOTX64.EFI starts.

This task is only UEFI-era Ethernet logging so real hardware output can be captured automatically.

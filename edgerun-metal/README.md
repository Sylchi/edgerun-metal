# EdgeRun Metal v0.2

This repository is a from-scratch x86_64 UEFI milestone that boots directly as a UEFI application and executes embedded Wasm modules.

## Status
- Current milestone: **M5 PCI scan module (standalone) + regression module**
  - `EdgeRun Metal Core v0.2`
  - `UEFI boot OK`
  - `Wasm module loaded`
  - `Wasm export found: main`
  - `wasm main() returned: 123` (regression module)
  - `PCI scan bus 0..255`
  - PCI discovery output for every discovered function (`bus/dev/func/id/command/status/class/revision/header/cacheline/BAR0-BAR5`)
- No Linux kernel, no GRUB/Limine.
- No external runtime libraries.
- No WASI/module runtime dependency.

## Dependencies
On Arch Linux:

```bash
sudo pacman -S clang lld qemu-full edk2-ovmf
```

If you build with gcc/binutils instead, install the equivalent:
- `base-devel` (or at least gcc, binutils, make)
- `qemu-full`
- `edk2-ovmf`

## Build

```bash
make
```

Produces:
- `build/edgerun-metal.efi`
- `build/esp/EFI/BOOT/BOOTX64.EFI`

## Run in QEMU

```bash
make run
```

The run script boots QEMU with OVMF and a FAT-formatted ESP drive rooted at `build/esp`.

## Netboot helper tool

Build:
```bash
make netboot
```

Run:
```bash
sudo ./build/edgerun-netboot --iface <iface> --efi build/esp/EFI/BOOT/BOOTX64.EFI --http --http-port 8081
```

Optional interface preparation for direct ethernet boot:
```bash
sudo ip link set <iface> down
sudo ip addr flush dev <iface>
sudo ip addr add 10.42.0.1/24 dev <iface>
sudo ip link set <iface> up
```

You can use `--setup-iface` to let the tool run those interface commands automatically.

HTTP mode example:
```bash
sudo ./build/edgerun-netboot --iface <iface> --efi build/esp/EFI/BOOT/BOOTX64.EFI --http --setup-iface --allow-mac 00:d8:61:d7:50:30
```

Fallback TFTP example:
```bash
sudo ./build/edgerun-netboot --iface <iface> --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode tftp
```

Mode options:
- `--http` : force UEFI HTTP boot mode.
- `--tftp` : force legacy TFTP boot mode.
- `--auto` : auto-select mode based on DHCP vendor class (default).
- `--mode auto|http|tftp` : explicit mode selection.
- `--force-http-for-pxe` : send HTTP URL to PXE clients too.
- `--client-ip 10.42.0.2` : fixed lease IP for desktop.
- `--allow-mac <aa:bb:cc:dd:ee:ff>` : only respond to that MAC.
- `--mgmt-dhcp` : answer management DHCP for non-boot clients.
- `--mgmt-ip 10.42.0.10` : management client IP.
- `--mgmt-mac <aa:bb:cc:dd:ee:ff>` : optional management client MAC.

Switch in between:
- Managed switches often send DHCP using their own vendor class e.g. `TL-SG1210MPE`.
- edgerun-netboot ignores clients not reporting `HTTPClient` or `PXEClient` vendor class.
- Restrict to one desktop NIC with `--allow-mac 00:d8:61:d7:50:30`.
- Default behavior now filters non-boot DHCP clients before replying.

For management DHCP on the switch:
```bash
sudo ./build/edgerun-netboot --iface eth0 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode auto --allow-mac 00:d8:61:d7:50:30 --mgmt-dhcp --mgmt-mac b0:19:21:fd:c3:92 --mgmt-ip 10.42.0.10
```

Troubleshooting:
- Disable NetworkManager on that interface if it interferes:
  `nmcli dev set <iface> managed no`
- Re-enable later:
  `nmcli dev set <iface> managed yes`
- Check link:
  `ip link show <iface>`
- Watch packets for debug:
  `sudo tcpdump -i <iface> -n -vvv -s0 'udp port 67 or udp port 68 or udp port 69'`

- Quick checks:
  `ss -ltnp | grep 8080`
  `ss -lunp | grep ':67'`
  `journalctl -u edgerun-netboot -f`

- Test local HTTP serving:
  `curl -v http://10.42.0.1:8081/BOOTX64.EFI -o /tmp/BOOTX64.EFI`
  `cmp build/esp/EFI/BOOT/BOOTX64.EFI /tmp/BOOTX64.EFI`

Exact netboot test matrix:

A. Local HTTP test:
```bash
curl -v http://10.42.0.1:8081/BOOTX64.EFI -o /tmp/BOOTX64.EFI
cmp build/esp/EFI/BOOT/BOOTX64.EFI /tmp/BOOTX64.EFI
```

B. PXE/TFTP boot test:
```bash
sudo ./build/edgerun-netboot --iface eth0 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode tftp --allow-mac 00:d8:61:d7:50:30
```
Select UEFI PXE IPv4 boot on desktop.

C. HTTP boot test:
```bash
sudo ./build/edgerun-netboot --iface eth0 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode http --allow-mac 00:d8:61:d7:50:30
```
Select UEFI HTTP IPv4 boot on desktop.

D. Auto mode test:
```bash
sudo ./build/edgerun-netboot --iface eth0 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode auto --allow-mac 00:d8:61:d7:50:30
```

E. Forced HTTP for PXE:
```bash
sudo ./build/edgerun-netboot --iface eth0 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface --mode auto --force-http-for-pxe --allow-mac 00:d8:61:d7:50:30
```

UEFI HTTP notes:
- If logs show vendor class `PXEClient`, firmware is using PXE mode.
- If logs show vendor class `HTTPClient`, firmware is using HTTP boot mode.
- For PXE clients, use `--tftp` or `--force-http-for-pxe` in auto mode.

- Quick socket checks:
  `ss -ltnp | grep '808[01]'`
  `ss -lunp | grep ':67'`
  `journalctl -u edgerun-netboot -f`

Requirements for desktop boot:
- Desktop firmware should use **UEFI HTTP boot / IPv4 HTTP boot** when using HTTP mode (or UEFI PXE as fallback).
- Secure Boot should be disabled for unsigned test firmware.

## Always-on netboot service

Find your interface:

```bash
ip link
```

Install netboot as a startup service (starts `edgerun-netboot` on boot):

```bash
make install-netboot IFACE=enp4s0
```

This installs:
- `/opt/edgerun-metal` symlink to this repository
- `/etc/edgerun-netboot.env`
- `/etc/systemd/system/edgerun-netboot.service`

Install without prompt:

```bash
FORCE=1 make install-netboot IFACE=enp4s0
```

Check status/logs:

```bash
make status-netboot
make logs-netboot
```

Rebuild only EFI and restart service:

```bash
make
make restart-netboot
```

Uninstall the service:

```bash
make uninstall-netboot
nmcli dev set <iface> managed yes
```

Notes:
- The installer runs `make` and `make netboot`.
- It asks for confirmation unless `FORCE=1` is set.
- The install uses `/opt/edgerun-metal` as a symlink so `make` updates in the repo are picked up for next PXE transfer.
- If `nmcli` exists, installer runs `nmcli dev set <iface> managed no` for the selected interface.
- Service command is:

  ```bash
  /opt/edgerun-metal/build/edgerun-netboot --iface ${EDGERUN_NETBOOT_IFACE} --efi ${EDGERUN_NETBOOT_EFI} --setup-iface --mode ${EDGERUN_NETBOOT_MODE} --http-port ${EDGERUN_NETBOOT_HTTP_PORT} --client-ip ${EDGERUN_NETBOOT_CLIENT_IP} --allow-mac=${EDGERUN_NETBOOT_ALLOW_MAC} --mgmt-dhcp=${EDGERUN_NETBOOT_MGMT_DHCP} --mgmt-mac=${EDGERUN_NETBOOT_MGMT_MAC} --mgmt-ip ${EDGERUN_NETBOOT_MGMT_IP} --force-http-for-pxe=${EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE}
  ```

  with environment file `/etc/edgerun-netboot.env` containing:

  ```
  EDGERUN_NETBOOT_IFACE=<interface>
  EDGERUN_NETBOOT_EFI=/opt/edgerun-metal/build/esp/EFI/BOOT/BOOTX64.EFI
  EDGERUN_NETBOOT_MODE=auto
  EDGERUN_NETBOOT_HTTP_PORT=8081
  EDGERUN_NETBOOT_MGMT_DHCP=0
  EDGERUN_NETBOOT_MGMT_IP=10.42.0.10
  EDGERUN_NETBOOT_MGMT_MAC=
  EDGERUN_NETBOOT_CLIENT_IP=10.42.0.2
  EDGERUN_NETBOOT_ALLOW_MAC=
  EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE=0
  ```

## Always-on development agent

Use `make install-agent` to enable an always-on local sync/test/report loop on this machine.
Use `make install-agent-user` when GitHub credentials should be loaded from the user environment.

```bash
make install-agent
make install-agent-user
```

The service:

- pulls `main` from GitHub
- runs `.edgerun/agent/run.sh`
- collects diagnostics and artifacts
- commits outputs to branch `agent/fw`
- never commits anything to `main`

Useful commands:

```bash
make run-agent
make run-agent-user
make logs-agent
make logs-agent-user
make status-agent
make status-agent-user
```

To stop it:

```bash
make uninstall-agent
make uninstall-agent-user
```

Output layout:

```
agent-output/
  latest/
    summary.txt
    git-status.txt
    build.txt
    netboot-status.txt
    netboot-journal.txt
    network.txt
    sockets.txt
    boot-artifacts.txt
    timestamp.txt
    run.log
  history/
    <timestamp>/
      ...same files as latest...
```

`run.sh` default behavior:

- `make`
- `make netboot`
- call `.edgerun/agent/collect.sh`

To change behavior, edit `.edgerun/agent/run.sh` in `main` and push.
The laptop executes the latest `main` branch script on the next timer run.
Results are committed to branch `agent/fw` (not `main`).

## Network boot later

Serve `build/esp/EFI/BOOT/BOOTX64.EFI` as `BOOTX64.EFI` through an existing PXE/iPXE/UEFI HTTP/TFTP boot chain.

## Layout

```
edgerun-metal/
  Makefile
  README.md
  core/
    efi_main.c
    er_types.h
    er_print.c
    er_print.h
    wasm_vm.c
    wasm_vm.h
    wasm_test_module.h
    wasm_pci_scan_module.h
  modules/
    test_return_123/
      test_return_123.wat
      test_return_123.c
    pci_scan/
      pci_scan.wat
  scripts/
    run-qemu.sh
    clean.sh
  systemd/
    edgerun-netboot.env.example
    edgerun-netboot.service
  tools/
    install-netboot-service.sh
    uninstall-netboot-service.sh
    edgerun-agent/
      README.md
      edgerun-agent.sh
      install-agent-service.sh
      uninstall-agent-service.sh
    edgerun-netboot/
      Makefile
      README.md
      main.c
  .edgerun/
    agent/
      collect.sh
      redact.sh
      README.md
      run.sh
```

## Next milestones

- M1: `ExitBootServices` and own framebuffer.
- M2: memory map copy.
- M3: page allocator.
- M4: PCI config hostcalls. **DONE**
- M5: load Wasm module over serial/network.
- M6: hot-swappable Wasm modules.

## Real hardware test notes

- Copy `build/esp/EFI/BOOT/BOOTX64.EFI` to removable media or ESP and boot as a UEFI application.
- Keep output visible on screen, verify at least:
  - `EdgeRun Metal Core v0.2`
  - `UEFI boot OK`
  - regression `wasm main() returned: 123`
  - PCI scan lines for discovered functions
- For network boot, expose the same path as `BOOTX64.EFI` in your PXE/iPXE/UEFI HTTP or TFTP loader.

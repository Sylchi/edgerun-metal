# edgerun-netboot

Small standalone DHCP+TFTP responder for testing EdgeRun Metal EFI PXE boot.

## Build

```bash
make netboot
```

Or from the tool directory:

```bash
make
```

## Prepare interface (optional)

```bash
sudo ip link set <iface> down
sudo ip addr flush dev <iface>
sudo ip addr add 10.42.0.1/24 dev <iface>
sudo ip link set <iface> up
```

You can use `--setup-iface` instead, which runs the same commands automatically.

## Run

```bash
sudo ./build/edgerun-netboot --iface <iface> --efi build/esp/EFI/BOOT/BOOTX64.EFI
```

Example:

```bash
sudo ./build/edgerun-netboot --iface enp0s31f6 --efi build/esp/EFI/BOOT/BOOTX64.EFI --setup-iface
```

## What it does

- Listens for DHCP over UDP port 67.
- Replies with minimal DHCP options for an edge-net boot topology:
  - `53` DHCP message type
  - `54` server identifier
  - `51` lease time
  - `1` subnet mask
  - `3` router
  - `6` DNS (optional)
  - `66` TFTP server name (optional)
  - `67` boot filename
- Logs vendor options:
  - `60` vendor class
  - `93` client architecture
  - `97` client machine-id
- Serves `BOOTX64.EFI` over TFTP on UDP port 69.
- Supports management DHCP for non-boot clients with:
  - `--mgmt-dhcp` : enable management DHCP lease.
  - `--mgmt-ip` : management IP.
  - `--mgmt-mac` : management MAC (optional).

## Troubleshooting

- If NetworkManager interferes:
  `nmcli dev set <iface> managed no`

  Re-enable after:
  `nmcli dev set <iface> managed yes`

- Inspect packets:
  `sudo tcpdump -i <iface> -n -vvv -s0 'udp port 67 or udp port 68 or udp port 69'`

- Make sure the client firmware is using UEFI network boot and Secure Boot is disabled for test images.

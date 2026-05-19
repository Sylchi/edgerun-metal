# Network Firmware

`firmware/network/` holds explicitly selected device firmware blobs using the
EdgeRun EFI firmware naming convention:

```text
/EFI/firmware/vendorid.deviceid.0
```

The repository path mirrors the final filename without implying that firmware is
compiled into the runtime. Boot configuration must still enable a matching
firmware source for the target PCI device.

## RTL8922AE

- EdgeRun filename: `10ec.8922.0`
- EFI partition filename: `/EFI/firmware/10ec.8922.0`
- Upstream source: `linux-firmware/rtw89/rtw8922a_fw-4.bin`
- Upstream URL: `https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/rtw89/rtw8922a_fw-4.bin`
- SHA-256: `d11927f593c82879bd0437435475d7915a60932374747984b3dc906a23009dea`
- Size: `1849226` bytes
- License: `LICENCE.rtlwifi_firmware.txt`

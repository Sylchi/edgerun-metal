# Raspberry Pi Boot Firmware

Explicit firmware blobs staged for Raspberry Pi Zero-family GPU boot.

| File | Source | Purpose | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `bootcode.bin` | Raspberry Pi firmware `boot/bootcode.bin` | BCM2708 second-stage USB/SD boot firmware | 52624 | `e8b59fe10a4daa3cd2b127479f40b9856cfe3677154e8f24ae2aa70e3bb7c8eb` |
| `start.elf` | Raspberry Pi firmware `boot/start.elf` | VideoCore firmware that loads `kernel.img` | 3026976 | `af01049c3ff11d8970069a1f3453a73fd0963dc5c93906b2f50edf167b32ff27` |
| `fixup.dat` | Raspberry Pi firmware `boot/fixup.dat` | VideoCore memory/config fixup data for `start.elf` | 7370 | `aa242088c3691823e5f2b9f81d4b519ce415ac45b0e6cdf4c27f22cda066050a` |

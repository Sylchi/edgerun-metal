# Network Firmware Manifest

Firmware files in this directory use the EFI boot-loader name
`vendor.device.instance`, where `vendor` and `device` are lowercase PCI IDs and
`instance` is a decimal firmware part number.

| File | Source file | Device | Role | Bytes | SHA-256 |
| --- | --- | --- | --- | ---: | --- |
| `02d0.a9a6.0` | RPi-Distro `debian/config/brcm80211/cypress/cyfmac43430-sdio.bin` | SDIO `02d0:a9a6` | CYW43438/BCM43430 RAM firmware | 399344 | `0717f8e798f3962230e76e9d840385ba127a38d31d6a55acd5c97cf53e4acc9d` |
| `02d0.a9a6.1` | RPi-Distro `debian/config/brcm80211/brcm/brcmfmac43430-sdio.txt` | SDIO `02d0:a9a6` | Pi Zero W CYW43438 NVRAM board parameters | 1121 | `fc3949a4c32f07c18308e7e145c7615be314158e7d714a80e04e4791f16495f9` |
| `02d0.a9a6.2` | RPi-Distro `debian/config/brcm80211/cypress/cyfmac43430-sdio.clm_blob` | SDIO `02d0:a9a6` | CYW43438/BCM43430 CLM regulatory blob | 4733 | `3376b9c9b32d16bf762e21c7fafb665365070ae240d092498d0d1987c22022aa` |
| `10ec.8922.0` | Realtek rtw89 firmware | `10ec:8922` | RTL8922AE firmware | 1849226 | `d11927f593c82879bd0437435475d7915a60932374747984b3dc906a23009dea` |
| `168c.003e.0` | `/lib/firmware/ath10k/QCA6174/hw3.0/firmware-6.bin.zst` | `168c:003e` | QCA6174 hw3.0 firmware | 706360 | `04d3bad5efa3f9fbe3ba53fd3e25fa9b0585ed227eea8111303b4e08861f979d` |
| `168c.003e.1` | `/lib/firmware/ath10k/QCA6174/hw3.0/board-2.bin.zst` | `168c:003e` | QCA6174 board database | 740076 | `66e83dde1c9af535df1fcd17c72971a96a263357300e921b358d35a353227d60` |
| `168c.003e.2` | `/lib/firmware/ath10k/QCA6174/hw3.0/board.bin.zst` | `168c:003e` | QCA6174 fallback board data | 8124 | `1a8d225818b46986fc4f615594fbe448fa820618590d6902c8f844bb37cda667` |
| `14c3.0616.0` | `/lib/firmware/mediatek/WIFI_RAM_CODE_MT7922_1.bin.zst` | `14c3:0616` | MT7922 Wi-Fi RAM code | 1003092 | `1226f5b30531b2f027897a4a499fb77c31f4a39025c98e5a9896769aaa781fda` |
| `14c3.0616.1` | `/lib/firmware/mediatek/WIFI_MT7922_patch_mcu_1_1_hdr.bin.zst` | `14c3:0616` | MT7922 Wi-Fi patch MCU | 137632 | `6d04988f5f44fc41e9404a492291a7a519b38e6aea6369b2f939cd0c70765f5a` |
| `14c3.0616.2` | `/lib/firmware/mediatek/BT_RAM_CODE_MT7922_1_1_hdr.bin.zst` | `14c3:0616` | MT7922 Bluetooth RAM code | 515670 | `b5dbcf0d27439db36a797203cabeb46220a8557ac488ecf69a0cfcb473b2dfa1` |
| `14c3.7603.0` | Wavlink `/lib/firmware/mt7603_e1.bin` | `14c3:7603` | MT7603 firmware E1 | 64132 | `e1d9cabeeb7d1539ea94665f3e7527968166552e9fc28171e0af7dbaa34ac3a5` |
| `14c3.7603.1` | Wavlink `/lib/firmware/mt7603_e2.bin` | `14c3:7603` | MT7603 firmware E2 | 72180 | `1710d02af192d2a274459c76d15d180d84c44bc7811e7e6f3c271245a8bbe5c9` |
| `14c3.7663.0` | Wavlink `/lib/firmware/mediatek/mt7663_n9_rebb.bin` | `14c3:7663` | MT7663 N9 firmware | 346216 | `6bbc60c5c10aed1e53a2f2b0edd7c3b2a517f0cd9be5b3ed2bd66c2587b908ab` |
| `14c3.7663.1` | Wavlink `/lib/firmware/mediatek/mt7663pr2h_rebb.bin` | `14c3:7663` | MT7663 patch firmware | 211518 | `05908e076750abdab4a504a440a5826e467cefa8c2519d229d9d92f7093bc7c4` |
| `8086.2725.0` | `/lib/firmware/intel/iwlwifi/iwlwifi-ty-a0-gf-a0-89.ucode.zst` | `8086:2725` | AX210 ucode | 1678816 | `0dbdd040e9a74be912d338e20931bba5f8389dfbab5d000c7afa276119034f2c` |
| `8086.2725.1` | `/lib/firmware/intel/iwlwifi/iwlwifi-ty-a0-gf-a0.pnvm.zst` | `8086:2725` | AX210 PNVM | 55020 | `451eb38de69ca99c8e18e7618c83d1f2a2c3351db390b1687916f5b2f9479192` |

Observed hardware:

| Host | Target | Device | Notes |
| --- | --- | --- | --- |
| Laptop | Linux PCI | `8086:2725` Intel AX210 | `iwlwifi`, firmware version `89.735b75a4.0 ty-a0-gf-a0-89.ucode`, netdev `wlan0` |
| Surface Go 1 | Linux PCI | `168c:003e` Qualcomm Atheros QCA6174/QCA61x4A | Expected ath10k PCI device. Surface Go reports commonly use subsystem `168c:3370`; Surface Go LTE/Wi-Fi reports may use `168c:3371`. Board selection depends on subsystem data inside `board-2.bin`. |
| Wavlink WS-WN572HP3 4G | OpenWrt `24.10.5`, target `ramips/mt7621`, arch `mipsel_24kc` | `14c3:7603` MediaTek MT7603 | 2.4 GHz radio, driver `mt7603e`, AP-capable |
| Wavlink WS-WN572HP3 4G | OpenWrt `24.10.5`, target `ramips/mt7621`, arch `mipsel_24kc` | `14c3:7663` MediaTek MT7663 | 5 GHz radio, driver `mt7615e`, AP/STA-capable but disabled in the observed config |
| Raspberry Pi Zero W v1.1 | SDIO | `02d0:a9a6` Broadcom/Cypress CYW43438/BCM43430 | Firmware paths map to `brcmfmac43430-sdio.raspberrypi,model-zero-w.*` symlinks in Raspberry Pi OS firmware packaging |

Architecture constraints from the observed set:

- Firmware is not always one file per PCI ID. AX210 needs at least ucode and
  PNVM; MT7922 has separate Wi-Fi RAM, Wi-Fi patch, and Bluetooth RAM blobs.
- Small OpenWrt targets can be MIPS-class systems with limited memory and split
  firmware packaging. The relay model must tolerate a node that advertises only
  high-level radio/link capability instead of acting as a full EdgeRun runtime.
- ESP32-class nodes cannot be assumed to have PCI, MMIO, or enough RAM for large
  Wi-Fi firmware blobs. The public networking model should treat them as
  capability-advertising endpoints with narrow transports, not as peers that
  implement every carrier.
- Raspberry Pi 4B-class nodes are ARM Linux systems with external or SDIO/USB
  radios depending on deployment. The model should keep carrier discovery and
  firmware binding behind per-device manifests rather than compile-time PCI-only
  assumptions.

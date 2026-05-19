#include "test_core_internal.h"

typedef struct {
  const char* expected_path;
  UINT16 expected_path_len;
  const UINT8* bytes;
  UINTN bytes_len;
  UINT8 called;
} Rtw89TestFirmwareReader;

static UINT8 rtw89_test_firmware_read(void* ctx,
                                      const char* path,
                                      UINT16 path_len,
                                      UINT8* out_bytes,
                                      UINTN out_capacity,
                                      UINTN* out_len) {
  Rtw89TestFirmwareReader* reader = (Rtw89TestFirmwareReader*)ctx;

  if (out_len != 0) {
    *out_len = 0u;
  }
  if (reader == 0 || path == 0 || out_bytes == 0 || out_len == 0) {
    return 0u;
  }
  reader->called = 1u;
  if (path_len != reader->expected_path_len ||
      er_mem_equal((const UINT8*)path, (const UINT8*)reader->expected_path, path_len) == 0u ||
      reader->bytes_len > out_capacity) {
    return 0u;
  }

  er_mem_copy(out_bytes, reader->bytes, reader->bytes_len);
  *out_len = reader->bytes_len;
  return 1u;
}

static void test_rtw89_pci_prepare(void) {
  ErPciDeviceSnapshot snapshot;
  ErRtw89PciDevice device;
  ErRtw89BootDevice boot_device;
  ErBootConfig config;
  ErCryptoProvider crypto;
  Rtw89TestFirmwareReader reader;
  UINT8 firmware_bytes[8];
  UINT8 firmware_out[8];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  ErIdentity admission_identity;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  er_pci_clear_snapshot(&snapshot);
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 0;
  }

  check_int64("rtw89 unsupported null id", er_rtw89_pci_id_supported(0xffffffffu), 0);
  check_int64("rtw89 unsupported vendor", er_rtw89_pci_id_supported(0x89228086u), 0);
  check_int64("rtw89 supported rtl8922ae", er_rtw89_pci_id_supported(0x892210ecu), 1);
  check_int64("rtw89 supported rtl8922ae vs", er_rtw89_pci_id_supported(0x892b10ecu), 1);

  device.supported = 99;
  device.bar_index = 99;
  device.device_id = 99;
  device.mmio_base = 99;
  er_rtw89_clear_pci_device(&device);
  check_int64("rtw89 clear supported", device.supported, 0);
  check_int64("rtw89 clear bar", device.bar_index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("rtw89 clear device", device.device_id, 0);
  check_uint64("rtw89 clear mmio", device.mmio_base, 0);

  check_int64("rtw89 prepare reject null snapshot", er_rtw89_prepare_pci_device(0, &device), 0);
  check_int64("rtw89 prepare reject null output", er_rtw89_prepare_pci_device(&snapshot, 0), 0);

  snapshot.present = 1;
  snapshot.id = 0x892210ecu;
  check_int64("rtw89 prepare reject no bar2", er_rtw89_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0x0000c001u;
  check_int64("rtw89 prepare reject io bar2", er_rtw89_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0xfebc0000u;
  check_int64("rtw89 prepare rtl8922ae", er_rtw89_prepare_pci_device(&snapshot, &device), 1);
  check_int64("rtw89 prepare supported", device.supported, 1);
  check_int64("rtw89 prepare bar", device.bar_index, ER_RTW89_PCI_MMIO_BAR_INDEX);
  check_int64("rtw89 prepare device", device.device_id, ER_RTW89_PCI_DEVICE_RTL8922AE);
  check_uint64("rtw89 prepare mmio", device.mmio_base, 0xfebc0000u);

  snapshot.id = 0x892b10ecu;
  check_int64("rtw89 prepare rtl8922ae vs", er_rtw89_prepare_pci_device(&snapshot, &device), 1);
  check_int64("rtw89 prepare vs device", device.device_id, ER_RTW89_PCI_DEVICE_RTL8922AE_VS);

  boot_device.pci.supported = 99u;
  boot_device.pci.bar_index = 99u;
  boot_device.pci.device_id = 99u;
  boot_device.pci.mmio_base = 99u;
  boot_device.firmware.loaded = 99u;
  er_rtw89_clear_boot_device(&boot_device);
  check_int64("rtw89 clear boot pci", boot_device.pci.supported, 0);
  check_int64("rtw89 clear boot firmware", boot_device.firmware.loaded, 0);

  er_boot_config_init(&config);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key), 0x36u);
  test_fill_bytes(firmware_bytes, (UINTN)sizeof(firmware_bytes), 0x72u);
  check_int64("rtw89 boot prepare admission",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_identity),
              1);
  check_int64("rtw89 boot set admission",
              er_boot_config_set_admission_identity(&config, &admission_identity), 1);
  check_int64("rtw89 boot add relay channel",
              er_boot_config_add_channel(&config, ER_CHANNEL_KIND_NATIVE_ETH, "edgerun0", 8u), 1);
  check_int64("rtw89 boot add firmware source",
              er_boot_config_add_efi_firmware_source(&config,
                                                     ER_RTW89_PCI_VENDOR_REALTEK,
                                                     ER_RTW89_PCI_DEVICE_RTL8922AE),
              1);
  config.generation = 1u;

  reader.expected_path = "/EFI/firmware/10ec.8922.0";
  reader.expected_path_len = ER_BOOT_CONFIG_FIRMWARE_PATH_LEN;
  reader.bytes = firmware_bytes;
  reader.bytes_len = (UINTN)sizeof(firmware_bytes);
  reader.called = 0u;
  snapshot.id = 0x892210ecu;
  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0xfebc0000u;
  check_int64("rtw89 boot prepare with firmware",
              er_rtw89_prepare_boot_device(&crypto,
                                           &config,
                                           &snapshot,
                                           rtw89_test_firmware_read,
                                           &reader,
                                           firmware_out,
                                           (UINTN)sizeof(firmware_out),
                                           &boot_device),
              1);
  check_int64("rtw89 boot reader called", reader.called, 1);
  check_int64("rtw89 boot pci supported", boot_device.pci.supported, 1);
  check_int64("rtw89 boot firmware loaded", boot_device.firmware.loaded, 1);
  check_uint64("rtw89 boot mmio", boot_device.pci.mmio_base, 0xfebc0000u);
  check_uint64("rtw89 boot firmware bytes", boot_device.firmware.bytes_len, (UINT64)sizeof(firmware_bytes));
  check_cstr("rtw89 boot firmware path", boot_device.firmware.path, "/EFI/firmware/10ec.8922.0");
  check_int64("rtw89 boot firmware copied",
              er_mem_equal(firmware_out, firmware_bytes, (UINTN)sizeof(firmware_bytes)), 1);
  check_int64("rtw89 boot firmware hash", er_hash_nonzero(&boot_device.firmware.firmware_hash), 1);

  reader.called = 0u;
  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0u;
  check_int64("rtw89 boot reject no bar2",
              er_rtw89_prepare_boot_device(&crypto,
                                           &config,
                                           &snapshot,
                                           rtw89_test_firmware_read,
                                           &reader,
                                           firmware_out,
                                           (UINTN)sizeof(firmware_out),
                                           &boot_device),
              0);
  check_int64("rtw89 boot no bar skips firmware", reader.called, 0);

  reader.called = 0u;
  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0xfebc0000u;
  snapshot.id = 0x892b10ecu;
  check_int64("rtw89 boot reject missing vs firmware",
              er_rtw89_prepare_boot_device(&crypto,
                                           &config,
                                           &snapshot,
                                           rtw89_test_firmware_read,
                                           &reader,
                                           firmware_out,
                                           (UINTN)sizeof(firmware_out),
                                           &boot_device),
              0);
  check_int64("rtw89 boot missing firmware skips reader", reader.called, 0);
}

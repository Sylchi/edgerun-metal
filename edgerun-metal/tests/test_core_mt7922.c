#include "test_core_internal.h"

enum {
  MT7922_TEST_FIRMWARE_LEN = 8u,
  MT7922_TEST_CLEAR_SENTINEL = 99u,
  MT7922_TEST_ADMISSION_FILL = 0x46u,
  MT7922_TEST_FIRMWARE_FILL = 0x82u,
  MT7922_TEST_CONFIG_GENERATION = 1u,
  MT7922_TEST_MMIO_BAR_INDEX = 0u,
  MT7922_TEST_IO_BAR = 0x0000d001u,
  MT7922_TEST_MMIO_BAR = 0xfedc0000u,
  MT7922_TEST_UNSUPPORTED_NULL_ID = 0xffffffffu,
  MT7922_TEST_UNSUPPORTED_VENDOR_ID = 0x061610ecu,
  MT7922_TEST_UNSUPPORTED_MT7921_ID = 0x796114c3u,
  MT7922_TEST_SUPPORTED_RZ616_ID = 0x061614c3u,
  MT7922_TEST_CHANNEL_NAME_LEN = 8u
};

static const char MT7922_TEST_CHANNEL_NAME[] = "edgerun0";
static const char MT7922_TEST_FIRMWARE_PATH[] = "/EFI/firmware/14c3.0616.0";

typedef struct {
  const char* expected_path;
  UINT16 expected_path_len;
  const UINT8* bytes;
  UINTN bytes_len;
  UINT8 called;
} Mt7922TestFirmwareReader;

static UINT8 mt7922_test_firmware_read(void* ctx,
                                       const char* path,
                                       UINT16 path_len,
                                       UINT8* out_bytes,
                                       UINTN out_capacity,
                                       UINTN* out_len) {
  Mt7922TestFirmwareReader* reader = (Mt7922TestFirmwareReader*)ctx;

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

static void test_mt7922_pci_prepare(void) {
  ErPciDeviceSnapshot snapshot;
  ErMt7922PciDevice device;
  ErMt7922BootDevice boot_device;
  ErBootConfig config;
  ErCryptoProvider crypto;
  Mt7922TestFirmwareReader reader;
  UINT8 firmware_bytes[MT7922_TEST_FIRMWARE_LEN];
  UINT8 firmware_out[MT7922_TEST_FIRMWARE_LEN];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  ErIdentity admission_identity;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  er_pci_clear_snapshot(&snapshot);
  for (i = 0u; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 0u;
  }

  check_int64("mt7922 unsupported null id",
              er_mt7922_pci_id_supported(MT7922_TEST_UNSUPPORTED_NULL_ID), 0);
  check_int64("mt7922 unsupported vendor",
              er_mt7922_pci_id_supported(MT7922_TEST_UNSUPPORTED_VENDOR_ID), 0);
  check_int64("mt7922 unsupported mediatek mt7921 id",
              er_mt7922_pci_id_supported(MT7922_TEST_UNSUPPORTED_MT7921_ID), 0);
  check_int64("mt7922 supported rz616",
              er_mt7922_pci_id_supported(MT7922_TEST_SUPPORTED_RZ616_ID), 1);

  device.supported = MT7922_TEST_CLEAR_SENTINEL;
  device.bar_index = MT7922_TEST_CLEAR_SENTINEL;
  device.device_id = MT7922_TEST_CLEAR_SENTINEL;
  device.mmio_base = MT7922_TEST_CLEAR_SENTINEL;
  er_mt7922_clear_pci_device(&device);
  check_int64("mt7922 clear supported", device.supported, 0);
  check_int64("mt7922 clear bar", device.bar_index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("mt7922 clear device", device.device_id, 0);
  check_uint64("mt7922 clear mmio", device.mmio_base, 0u);

  check_int64("mt7922 prepare reject null snapshot",
              er_mt7922_prepare_pci_device(0, &device), 0);
  check_int64("mt7922 prepare reject null output",
              er_mt7922_prepare_pci_device(&snapshot, 0), 0);

  snapshot.present = 1u;
  snapshot.id = MT7922_TEST_SUPPORTED_RZ616_ID;
  check_int64("mt7922 prepare reject no mmio",
              er_mt7922_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[MT7922_TEST_MMIO_BAR_INDEX] = MT7922_TEST_IO_BAR;
  check_int64("mt7922 prepare reject io bar",
              er_mt7922_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[MT7922_TEST_MMIO_BAR_INDEX] = MT7922_TEST_MMIO_BAR;
  check_int64("mt7922 prepare rz616", er_mt7922_prepare_pci_device(&snapshot, &device), 1);
  check_int64("mt7922 prepare supported", device.supported, 1);
  check_int64("mt7922 prepare bar", device.bar_index, MT7922_TEST_MMIO_BAR_INDEX);
  check_int64("mt7922 prepare device", device.device_id, ER_MT7922_PCI_DEVICE_MT7922_RZ616);
  check_uint64("mt7922 prepare mmio", device.mmio_base, MT7922_TEST_MMIO_BAR);

  boot_device.pci.supported = MT7922_TEST_CLEAR_SENTINEL;
  boot_device.pci.bar_index = MT7922_TEST_CLEAR_SENTINEL;
  boot_device.pci.device_id = MT7922_TEST_CLEAR_SENTINEL;
  boot_device.pci.mmio_base = MT7922_TEST_CLEAR_SENTINEL;
  boot_device.firmware.loaded = MT7922_TEST_CLEAR_SENTINEL;
  er_mt7922_clear_boot_device(&boot_device);
  check_int64("mt7922 clear boot pci", boot_device.pci.supported, 0);
  check_int64("mt7922 clear boot firmware", boot_device.firmware.loaded, 0);

  er_boot_config_init(&config);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key), MT7922_TEST_ADMISSION_FILL);
  test_fill_bytes(firmware_bytes, (UINTN)sizeof(firmware_bytes), MT7922_TEST_FIRMWARE_FILL);
  check_int64("mt7922 boot prepare admission",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_identity),
              1);
  check_int64("mt7922 boot set admission",
              er_boot_config_set_admission_identity(&config, &admission_identity), 1);
  check_int64("mt7922 boot add relay channel",
              er_boot_config_add_channel(&config,
                                         ER_CHANNEL_KIND_NATIVE_ETH,
                                         MT7922_TEST_CHANNEL_NAME,
                                         MT7922_TEST_CHANNEL_NAME_LEN),
              1);
  check_int64("mt7922 boot add firmware source",
              er_boot_config_add_efi_firmware_source(&config,
                                                     ER_MT7922_PCI_VENDOR_MEDIATEK,
                                                     ER_MT7922_PCI_DEVICE_MT7922_RZ616),
              1);
  config.generation = MT7922_TEST_CONFIG_GENERATION;

  reader.expected_path = MT7922_TEST_FIRMWARE_PATH;
  reader.expected_path_len = ER_BOOT_CONFIG_FIRMWARE_PATH_LEN;
  reader.bytes = firmware_bytes;
  reader.bytes_len = (UINTN)sizeof(firmware_bytes);
  reader.called = 0u;
  snapshot.id = MT7922_TEST_SUPPORTED_RZ616_ID;
  snapshot.bars[MT7922_TEST_MMIO_BAR_INDEX] = MT7922_TEST_MMIO_BAR;
  check_int64("mt7922 boot prepare with firmware",
              er_mt7922_prepare_boot_device(&crypto,
                                            &config,
                                            &snapshot,
                                            mt7922_test_firmware_read,
                                            &reader,
                                            firmware_out,
                                            (UINTN)sizeof(firmware_out),
                                            &boot_device),
              1);
  check_int64("mt7922 boot reader called", reader.called, 1);
  check_int64("mt7922 boot pci supported", boot_device.pci.supported, 1);
  check_int64("mt7922 boot firmware loaded", boot_device.firmware.loaded, 1);
  check_uint64("mt7922 boot mmio", boot_device.pci.mmio_base, MT7922_TEST_MMIO_BAR);
  check_uint64("mt7922 boot firmware bytes", boot_device.firmware.bytes_len, (UINT64)sizeof(firmware_bytes));
  check_cstr("mt7922 boot firmware path", boot_device.firmware.path, MT7922_TEST_FIRMWARE_PATH);
  check_int64("mt7922 boot firmware copied",
              er_mem_equal(firmware_out, firmware_bytes, (UINTN)sizeof(firmware_bytes)), 1);
  check_int64("mt7922 boot firmware hash", er_hash_nonzero(&boot_device.firmware.firmware_hash), 1);

  reader.called = 0u;
  snapshot.bars[MT7922_TEST_MMIO_BAR_INDEX] = 0u;
  check_int64("mt7922 boot reject no mmio",
              er_mt7922_prepare_boot_device(&crypto,
                                            &config,
                                            &snapshot,
                                            mt7922_test_firmware_read,
                                            &reader,
                                            firmware_out,
                                            (UINTN)sizeof(firmware_out),
                                            &boot_device),
              0);
  check_int64("mt7922 boot no mmio skips firmware", reader.called, 0);

  reader.called = 0u;
  snapshot.id = MT7922_TEST_SUPPORTED_RZ616_ID;
  snapshot.bars[MT7922_TEST_MMIO_BAR_INDEX] = MT7922_TEST_MMIO_BAR;
  er_boot_config_init(&config);
  check_int64("mt7922 boot reject missing firmware",
              er_mt7922_prepare_boot_device(&crypto,
                                            &config,
                                            &snapshot,
                                            mt7922_test_firmware_read,
                                            &reader,
                                            firmware_out,
                                            (UINTN)sizeof(firmware_out),
                                            &boot_device),
              0);
  check_int64("mt7922 boot missing firmware skips reader", reader.called, 0);
}

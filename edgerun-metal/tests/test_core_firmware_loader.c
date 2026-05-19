#include "test_core_internal.h"

typedef struct {
  const char* expected_path;
  UINT16 expected_path_len;
  const UINT8* bytes;
  UINTN bytes_len;
  UINT8 called;
  UINT8 fail;
} TestFirmwareReader;

static UINT8 test_firmware_read(void* ctx,
                                const char* path,
                                UINT16 path_len,
                                UINT8* out_bytes,
                                UINTN out_capacity,
                                UINTN* out_len) {
  TestFirmwareReader* reader = (TestFirmwareReader*)ctx;

  if (out_len != 0) {
    *out_len = 0u;
  }
  if (reader == 0 || path == 0 || out_bytes == 0 || out_len == 0 || reader->fail != 0u) {
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

static void test_firmware_loader(void) {
  ErCryptoProvider crypto;
  ErBootConfig config;
  ErBootFirmwareSourceConfig source;
  ErFirmwareImage image;
  TestFirmwareReader reader;
  UINT8 firmware_bytes[8];
  UINT8 firmware_out[8];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  ErIdentity admission_identity;

  er_crypto_blake3_provider(&crypto);
  er_boot_config_init(&config);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key), 0x24u);
  test_fill_bytes(firmware_bytes, (UINTN)sizeof(firmware_bytes), 0xa0u);
  check_int64("firmware loader prepare admission",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_identity),
              1);
  check_int64("firmware loader set admission",
              er_boot_config_set_admission_identity(&config, &admission_identity), 1);
  check_int64("firmware loader add relay channel",
              er_boot_config_add_channel(&config, ER_CHANNEL_KIND_NATIVE_ETH, "edgerun0", 8u), 1);
  check_int64("firmware loader add source",
              er_boot_config_add_efi_firmware_source(&config, 0x10ecu, 0x8922u), 1);
  config.generation = 1u;
  check_int64("firmware loader config valid", er_boot_config_valid(&config), 1);

  reader.expected_path = "/EFI/firmware/10ec.8922.0";
  reader.expected_path_len = ER_BOOT_CONFIG_FIRMWARE_PATH_LEN;
  reader.bytes = firmware_bytes;
  reader.bytes_len = (UINTN)sizeof(firmware_bytes);
  reader.called = 0u;
  reader.fail = 0u;
  check_int64("firmware loader for pci",
              er_firmware_loader_load_for_pci(&crypto,
                                              &config,
                                              0x10ecu,
                                              0x8922u,
                                              test_firmware_read,
                                              &reader,
                                              firmware_out,
                                              (UINTN)sizeof(firmware_out),
                                              &image),
              1);
  check_int64("firmware loader reader called", reader.called, 1);
  check_int64("firmware loader image loaded", image.loaded, 1);
  check_uint64("firmware loader image bytes", image.bytes_len, (UINT64)sizeof(firmware_bytes));
  check_uint64("firmware loader image vendor", image.pci_vendor_id, 0x10ecu);
  check_uint64("firmware loader image device", image.pci_device_id, 0x8922u);
  check_cstr("firmware loader image path", image.path, "/EFI/firmware/10ec.8922.0");
  check_int64("firmware loader copied bytes",
              er_mem_equal(firmware_out, firmware_bytes, (UINTN)sizeof(firmware_bytes)), 1);
  check_int64("firmware loader hash nonzero", er_hash_nonzero(&image.firmware_hash), 1);

  reader.called = 0u;
  check_int64("firmware loader rejects missing source",
              er_firmware_loader_load_for_pci(&crypto,
                                              &config,
                                              0x10ecu,
                                              0x892bu,
                                              test_firmware_read,
                                              &reader,
                                              firmware_out,
                                              (UINTN)sizeof(firmware_out),
                                              &image),
              0);
  check_int64("firmware loader missing source skips reader", reader.called, 0);

  source = config.firmware_sources[0];
  source.path[source.path_len - 1u] = '1';
  check_int64("firmware loader rejects mutated source",
              er_firmware_loader_load_source(&crypto,
                                             &source,
                                             test_firmware_read,
                                             &reader,
                                             firmware_out,
                                             (UINTN)sizeof(firmware_out),
                                             &image),
              0);

  reader.fail = 1u;
  check_int64("firmware loader rejects read failure",
              er_firmware_loader_load_for_pci(&crypto,
                                              &config,
                                              0x10ecu,
                                              0x8922u,
                                              test_firmware_read,
                                              &reader,
                                              firmware_out,
                                              (UINTN)sizeof(firmware_out),
                                              &image),
              0);
}

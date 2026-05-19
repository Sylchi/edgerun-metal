#include "test_core_internal.h"

typedef struct {
  const char* ucode_path;
  const char* pnvm_path;
  const UINT8* ucode_bytes;
  const UINT8* pnvm_bytes;
  UINTN ucode_len;
  UINTN pnvm_len;
  UINT8 ucode_called;
  UINT8 pnvm_called;
} IwlwifiTestFirmwareReader;

static UINT8 iwlwifi_test_firmware_read(void* ctx,
                                        const char* path,
                                        UINT16 path_len,
                                        UINT8* out_bytes,
                                        UINTN out_capacity,
                                        UINTN* out_len) {
  IwlwifiTestFirmwareReader* reader = (IwlwifiTestFirmwareReader*)ctx;

  if (out_len != 0) {
    *out_len = 0u;
  }
  if (reader == 0 || path == 0 || out_bytes == 0 || out_len == 0 ||
      path_len != ER_BOOT_CONFIG_FIRMWARE_PATH_LEN) {
    return 0u;
  }

  if (er_mem_equal((const UINT8*)path, (const UINT8*)reader->ucode_path, path_len) != 0u) {
    if (reader->ucode_len > out_capacity) {
      return 0u;
    }
    reader->ucode_called = 1u;
    er_mem_copy(out_bytes, reader->ucode_bytes, reader->ucode_len);
    *out_len = reader->ucode_len;
    return 1u;
  }

  if (er_mem_equal((const UINT8*)path, (const UINT8*)reader->pnvm_path, path_len) != 0u) {
    if (reader->pnvm_len > out_capacity) {
      return 0u;
    }
    reader->pnvm_called = 1u;
    er_mem_copy(out_bytes, reader->pnvm_bytes, reader->pnvm_len);
    *out_len = reader->pnvm_len;
    return 1u;
  }

  return 0u;
}

static void test_iwlwifi_pci_prepare(void) {
  ErPciDeviceSnapshot snapshot;
  ErIwlwifiPciDevice device;
  ErIwlwifiBootDevice boot_device;
  ErBootConfig config;
  ErCryptoProvider crypto;
  IwlwifiTestFirmwareReader reader;
  UINT8 ucode_bytes[8];
  UINT8 pnvm_bytes[4];
  UINT8 ucode_out[8];
  UINT8 pnvm_out[4];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  ErIdentity admission_identity;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  er_pci_clear_snapshot(&snapshot);
  for (i = 0u; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 0u;
  }

  check_int64("iwlwifi unsupported null id", er_iwlwifi_pci_id_supported(0xffffffffu), 0);
  check_int64("iwlwifi unsupported vendor", er_iwlwifi_pci_id_supported(0x272514c3u), 0);
  check_int64("iwlwifi supported ax210", er_iwlwifi_pci_id_supported(0x27258086u), 1);

  device.supported = 99u;
  device.bar_index = 99u;
  device.device_id = 99u;
  device.mmio_base = 99u;
  er_iwlwifi_clear_pci_device(&device);
  check_int64("iwlwifi clear supported", device.supported, 0);
  check_int64("iwlwifi clear bar", device.bar_index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("iwlwifi clear device", device.device_id, 0);
  check_uint64("iwlwifi clear mmio", device.mmio_base, 0u);

  check_int64("iwlwifi prepare reject null snapshot",
              er_iwlwifi_prepare_pci_device(0, &device), 0);
  check_int64("iwlwifi prepare reject null output",
              er_iwlwifi_prepare_pci_device(&snapshot, 0), 0);

  snapshot.present = 1u;
  snapshot.id = 0x27258086u;
  check_int64("iwlwifi prepare reject no mmio",
              er_iwlwifi_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[0] = 0x0000c001u;
  check_int64("iwlwifi prepare reject io bar",
              er_iwlwifi_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[0] = 0xfed90000u;
  check_int64("iwlwifi prepare ax210", er_iwlwifi_prepare_pci_device(&snapshot, &device), 1);
  check_int64("iwlwifi prepare supported", device.supported, 1);
  check_int64("iwlwifi prepare bar", device.bar_index, 0u);
  check_int64("iwlwifi prepare device", device.device_id, ER_IWLWIFI_PCI_DEVICE_AX210);
  check_uint64("iwlwifi prepare mmio", device.mmio_base, 0xfed90000u);

  boot_device.pci.supported = 99u;
  boot_device.ucode.loaded = 99u;
  boot_device.pnvm.loaded = 99u;
  er_iwlwifi_clear_boot_device(&boot_device);
  check_int64("iwlwifi clear boot pci", boot_device.pci.supported, 0);
  check_int64("iwlwifi clear boot ucode", boot_device.ucode.loaded, 0);
  check_int64("iwlwifi clear boot pnvm", boot_device.pnvm.loaded, 0);

  er_boot_config_init(&config);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key), 0x55u);
  test_fill_bytes(ucode_bytes, (UINTN)sizeof(ucode_bytes), 0x91u);
  test_fill_bytes(pnvm_bytes, (UINTN)sizeof(pnvm_bytes), 0x19u);
  check_int64("iwlwifi boot prepare admission",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_identity),
              1);
  check_int64("iwlwifi boot set admission",
              er_boot_config_set_admission_identity(&config, &admission_identity), 1);
  check_int64("iwlwifi boot add relay channel",
              er_boot_config_add_channel(&config, ER_CHANNEL_KIND_NATIVE_ETH, "edgerun0", 8u), 1);
  check_int64("iwlwifi boot add ucode source",
              er_boot_config_add_efi_firmware_source_instance(&config,
                                                              ER_IWLWIFI_PCI_VENDOR_INTEL,
                                                              ER_IWLWIFI_PCI_DEVICE_AX210,
                                                              ER_IWLWIFI_FIRMWARE_INSTANCE_UCODE),
              1);
  check_int64("iwlwifi boot add pnvm source",
              er_boot_config_add_efi_firmware_source_instance(&config,
                                                              ER_IWLWIFI_PCI_VENDOR_INTEL,
                                                              ER_IWLWIFI_PCI_DEVICE_AX210,
                                                              ER_IWLWIFI_FIRMWARE_INSTANCE_PNVM),
              1);
  config.generation = 1u;

  reader.ucode_path = "/EFI/firmware/8086.2725.0";
  reader.pnvm_path = "/EFI/firmware/8086.2725.1";
  reader.ucode_bytes = ucode_bytes;
  reader.pnvm_bytes = pnvm_bytes;
  reader.ucode_len = (UINTN)sizeof(ucode_bytes);
  reader.pnvm_len = (UINTN)sizeof(pnvm_bytes);
  reader.ucode_called = 0u;
  reader.pnvm_called = 0u;
  check_int64("iwlwifi boot prepare with firmware",
              er_iwlwifi_prepare_ax210_boot_device(&crypto,
                                                   &config,
                                                   &snapshot,
                                                   iwlwifi_test_firmware_read,
                                                   &reader,
                                                   ucode_out,
                                                   (UINTN)sizeof(ucode_out),
                                                   pnvm_out,
                                                   (UINTN)sizeof(pnvm_out),
                                                   &boot_device),
              1);
  check_int64("iwlwifi boot ucode called", reader.ucode_called, 1);
  check_int64("iwlwifi boot pnvm called", reader.pnvm_called, 1);
  check_int64("iwlwifi boot pci supported", boot_device.pci.supported, 1);
  check_int64("iwlwifi boot ucode loaded", boot_device.ucode.loaded, 1);
  check_int64("iwlwifi boot pnvm loaded", boot_device.pnvm.loaded, 1);
  check_uint64("iwlwifi boot ucode instance", boot_device.ucode.instance, ER_IWLWIFI_FIRMWARE_INSTANCE_UCODE);
  check_uint64("iwlwifi boot pnvm instance", boot_device.pnvm.instance, ER_IWLWIFI_FIRMWARE_INSTANCE_PNVM);
  check_cstr("iwlwifi boot ucode path", boot_device.ucode.path, "/EFI/firmware/8086.2725.0");
  check_cstr("iwlwifi boot pnvm path", boot_device.pnvm.path, "/EFI/firmware/8086.2725.1");
  check_int64("iwlwifi boot ucode copied",
              er_mem_equal(ucode_out, ucode_bytes, (UINTN)sizeof(ucode_bytes)), 1);
  check_int64("iwlwifi boot pnvm copied",
              er_mem_equal(pnvm_out, pnvm_bytes, (UINTN)sizeof(pnvm_bytes)), 1);

  reader.ucode_called = 0u;
  reader.pnvm_called = 0u;
  er_boot_config_init(&config);
  check_int64("iwlwifi boot reject missing sources",
              er_iwlwifi_prepare_ax210_boot_device(&crypto,
                                                   &config,
                                                   &snapshot,
                                                   iwlwifi_test_firmware_read,
                                                   &reader,
                                                   ucode_out,
                                                   (UINTN)sizeof(ucode_out),
                                                   pnvm_out,
                                                   (UINTN)sizeof(pnvm_out),
                                                   &boot_device),
              0);
  check_int64("iwlwifi boot missing sources skips ucode", reader.ucode_called, 0);
  check_int64("iwlwifi boot missing sources skips pnvm", reader.pnvm_called, 0);
}

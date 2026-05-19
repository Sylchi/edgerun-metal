#include "er_firmware_loader.h"
#include "er_mem.h"

static const UINT8 g_er_firmware_loader_hash_domain[] = "edgerun:c:v1:firmware-image";

//@optimizer-ignore-constant UEFI Loaded Image protocol GUID is ABI-defined by firmware
static EFI_GUID g_er_loaded_image_protocol_guid = {
  0x5b1b31a1u,
  0x9562u,
  0x11d2u,
  {0x8eu, 0x3fu, 0x00u, 0xa0u, 0xc9u, 0x69u, 0x72u, 0x3bu}
};

//@optimizer-ignore-constant UEFI Simple File System protocol GUID is ABI-defined by firmware
static EFI_GUID g_er_simple_file_system_protocol_guid = {
  0x0964e5b22u,
  0x6459u,
  0x11d2u,
  {0x8eu, 0x39u, 0x00u, 0xa0u, 0xc9u, 0x69u, 0x72u, 0x3bu}
};

static UINT8 er_firmware_loader_source_valid(const ErBootFirmwareSourceConfig* source) {
  const ErBootFirmwareSourceConfig* found;
  ErBootConfig config;

  if (source == 0) {
    return 0u;
  }

  er_boot_config_init(&config);
  if (er_boot_config_add_efi_firmware_source(&config, source->pci_vendor_id, source->pci_device_id) == 0u) {
    return 0u;
  }

  found = er_boot_config_find_efi_firmware_source(&config, source->pci_vendor_id, source->pci_device_id);
  if (found == 0 ||
      source->enabled != found->enabled ||
      source->source_kind != found->source_kind ||
      source->instance != found->instance ||
      source->reserved != found->reserved ||
      source->pci_vendor_id != found->pci_vendor_id ||
      source->pci_device_id != found->pci_device_id ||
      source->path_len != found->path_len ||
      er_mem_equal((const UINT8*)source->path, (const UINT8*)found->path, found->path_len) == 0u) {
    return 0u;
  }

  return 1u;
}

static UINT8 er_firmware_loader_hash_image(const ErCryptoProvider* crypto,
                                           const UINT8* bytes,
                                           UINTN bytes_len,
                                           ErHash* out_hash) {
  ErByteSpan span;

  if (bytes_len == 0u || bytes == 0 || out_hash == 0) {
    return 0u;
  }

  span.bytes = bytes;
  span.len = bytes_len;
  return er_crypto_hash(crypto,
                        g_er_firmware_loader_hash_domain,
                        (UINTN)(sizeof(g_er_firmware_loader_hash_domain) - 1u),
                        &span,
                        1u,
                        out_hash);
}

static UINT8 er_firmware_loader_ascii_path_to_efi(const char* path,
                                                  UINT16 path_len,
                                                  CHAR16* out_path,
                                                  UINTN out_capacity) {
  UINT16 i;

  if (path == 0 || out_path == 0 ||
      path_len == 0u ||
      (UINTN)path_len + 1u > out_capacity) {
    return 0u;
  }

  for (i = 0u; i < path_len; ++i) {
    switch (path[i]) {
      case '/':
        out_path[i] = (CHAR16)'\\';
        break;
      default:
        out_path[i] = (CHAR16)path[i];
        break;
    }
  }
  out_path[path_len] = 0u;
  return 1u;
}

void er_firmware_loader_clear_image(ErFirmwareImage* image) {
  if (image == 0) {
    return;
  }
  er_mem_zero((UINT8*)image, (UINTN)sizeof(*image));
}

UINT8 er_firmware_loader_load_source(const ErCryptoProvider* crypto,
                                     const ErBootFirmwareSourceConfig* source,
                                     ErFirmwareReadFn read_fn,
                                     void* read_ctx,
                                     UINT8* firmware_bytes,
                                     UINTN firmware_capacity,
                                     ErFirmwareImage* out_image) {
  UINTN bytes_len = 0u;

  er_firmware_loader_clear_image(out_image);
  if (crypto == 0 ||
      source == 0 ||
      read_fn == 0 ||
      firmware_bytes == 0 ||
      firmware_capacity == 0u ||
      firmware_capacity > ER_FIRMWARE_LOADER_MAX_BYTES ||
      out_image == 0 ||
      er_firmware_loader_source_valid(source) == 0u) {
    return 0u;
  }

  if (read_fn(read_ctx, source->path, source->path_len, firmware_bytes, firmware_capacity, &bytes_len) == 0u ||
      bytes_len == 0u ||
      bytes_len > firmware_capacity ||
      er_firmware_loader_hash_image(crypto, firmware_bytes, bytes_len, &out_image->firmware_hash) == 0u) {
    er_firmware_loader_clear_image(out_image);
    return 0u;
  }

  out_image->loaded = 1u;
  out_image->source_kind = source->source_kind;
  out_image->instance = source->instance;
  out_image->pci_vendor_id = source->pci_vendor_id;
  out_image->pci_device_id = source->pci_device_id;
  out_image->path_len = source->path_len;
  out_image->bytes_len = (UINT64)bytes_len;
  er_mem_copy((UINT8*)out_image->path, (const UINT8*)source->path, source->path_len);
  return 1u;
}

UINT8 er_firmware_loader_load_for_pci(const ErCryptoProvider* crypto,
                                      const ErBootConfig* config,
                                      UINT16 pci_vendor_id,
                                      UINT16 pci_device_id,
                                      ErFirmwareReadFn read_fn,
                                      void* read_ctx,
                                      UINT8* firmware_bytes,
                                      UINTN firmware_capacity,
                                      ErFirmwareImage* out_image) {
  const ErBootFirmwareSourceConfig* source;

  er_firmware_loader_clear_image(out_image);
  if (config == 0 || pci_vendor_id == 0u || pci_device_id == 0u) {
    return 0u;
  }

  source = er_boot_config_find_efi_firmware_source(config, pci_vendor_id, pci_device_id);
  if (source == 0) {
    return 0u;
  }

  return er_firmware_loader_load_source(crypto,
                                        source,
                                        read_fn,
                                        read_ctx,
                                        firmware_bytes,
                                        firmware_capacity,
                                        out_image);
}

UINT8 er_firmware_loader_read_efi_partition(EFI_HANDLE image_handle,
                                            EFI_SYSTEM_TABLE* system_table,
                                            const char* path,
                                            UINT16 path_len,
                                            UINT8* out_bytes,
                                            UINTN out_capacity,
                                            UINTN* out_len) {
  EFI_LOADED_IMAGE_PROTOCOL* loaded_image = 0;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* file_system = 0;
  EFI_FILE_PROTOCOL* root = 0;
  EFI_FILE_PROTOCOL* file = 0;
  CHAR16 efi_path[ER_BOOT_CONFIG_FIRMWARE_PATH_MAX + 1u];
  UINT8 extra_byte = 0u;
  UINTN read_len;
  UINTN extra_len;
  EFI_STATUS status;

  if (out_len != 0) {
    *out_len = 0u;
  }
  if (image_handle == 0 ||
      system_table == 0 ||
      system_table->BootServices == 0 ||
      system_table->BootServices->HandleProtocol == 0 ||
      path == 0 ||
      path_len == 0u ||
      out_bytes == 0 ||
      out_capacity == 0u ||
      out_len == 0 ||
      er_firmware_loader_ascii_path_to_efi(path, path_len, efi_path, (UINTN)(ER_BOOT_CONFIG_FIRMWARE_PATH_MAX + 1u)) == 0u) {
    return 0u;
  }

  status = system_table->BootServices->HandleProtocol(image_handle,
                                                      &g_er_loaded_image_protocol_guid,
                                                      (void**)&loaded_image);
  if (status != EFI_SUCCESS || loaded_image == 0 || loaded_image->DeviceHandle == 0) {
    return 0u;
  }

  status = system_table->BootServices->HandleProtocol(loaded_image->DeviceHandle,
                                                      &g_er_simple_file_system_protocol_guid,
                                                      (void**)&file_system);
  if (status != EFI_SUCCESS || file_system == 0 || file_system->OpenVolume == 0) {
    return 0u;
  }

  status = file_system->OpenVolume(file_system, &root);
  if (status != EFI_SUCCESS || root == 0 || root->Open == 0 || root->Close == 0) {
    return 0u;
  }

  status = root->Open(root, &file, efi_path, EFI_FILE_MODE_READ, 0u);
  if (status != EFI_SUCCESS || file == 0 || file->Read == 0 || file->Close == 0) {
    (void)root->Close(root);
    return 0u;
  }

  read_len = out_capacity;
  status = file->Read(file, &read_len, out_bytes);
  if (status != EFI_SUCCESS) {
    (void)file->Close(file);
    (void)root->Close(root);
    return 0u;
  }

  if (read_len == out_capacity) {
    extra_len = 1u;
    status = file->Read(file, &extra_len, &extra_byte);
    if (status != EFI_SUCCESS || extra_len != 0u) {
      (void)file->Close(file);
      (void)root->Close(root);
      return 0u;
    }
  }

  *out_len = read_len;
  status = file->Close(file);
  if (status != EFI_SUCCESS) {
    (void)root->Close(root);
    *out_len = 0u;
    return 0u;
  }

  status = root->Close(root);
  if (status != EFI_SUCCESS) {
    *out_len = 0u;
    return 0u;
  }

  return 1u;
}

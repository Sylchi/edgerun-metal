#ifndef ER_FIRMWARE_LOADER_H
#define ER_FIRMWARE_LOADER_H

/*
 * Purpose: load explicitly enabled device firmware during boot services.
 * Intention: carry firmware bytes into runtime through a bounded, hashed handoff record.
 */

#include "er_boot_config.h"
#include "er_crypto.h"
#include "er_types.h"

#define ER_FIRMWARE_LOADER_MAX_BYTES (2u * 1024u * 1024u)

typedef UINT8 (*ErFirmwareReadFn)(void* ctx,
                                  const char* path,
                                  UINT16 path_len,
                                  UINT8* out_bytes,
                                  UINTN out_capacity,
                                  UINTN* out_len);

typedef struct {
  UINT8 loaded;
  UINT8 source_kind;
  UINT8 instance;
  UINT8 reserved;
  UINT16 pci_vendor_id;
  UINT16 pci_device_id;
  UINT16 path_len;
  UINT64 bytes_len;
  ErHash firmware_hash;
  char path[ER_BOOT_CONFIG_FIRMWARE_PATH_MAX];
} ErFirmwareImage;

void er_firmware_loader_clear_image(ErFirmwareImage* image);
UINT8 er_firmware_loader_load_source(const ErCryptoProvider* crypto,
                                     const ErBootFirmwareSourceConfig* source,
                                     ErFirmwareReadFn read_fn,
                                     void* read_ctx,
                                     UINT8* firmware_bytes,
                                     UINTN firmware_capacity,
                                     ErFirmwareImage* out_image);
UINT8 er_firmware_loader_load_for_pci(const ErCryptoProvider* crypto,
                                      const ErBootConfig* config,
                                      UINT16 pci_vendor_id,
                                      UINT16 pci_device_id,
                                      ErFirmwareReadFn read_fn,
                                      void* read_ctx,
                                      UINT8* firmware_bytes,
                                      UINTN firmware_capacity,
                                      ErFirmwareImage* out_image);
UINT8 er_firmware_loader_read_efi_partition(EFI_HANDLE image_handle,
                                            EFI_SYSTEM_TABLE* system_table,
                                            const char* path,
                                            UINT16 path_len,
                                            UINT8* out_bytes,
                                            UINTN out_capacity,
                                            UINTN* out_len);

#endif

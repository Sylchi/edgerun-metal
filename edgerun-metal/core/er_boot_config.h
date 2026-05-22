#ifndef ER_BOOT_CONFIG_H
#define ER_BOOT_CONFIG_H

/*
 * Purpose: describe EFI-partition boot configuration consumed before runtime entry.
 * Intention: keep mutable relay policy out of TPM storage while preserving explicit admission authority.
 */

#include "er_credential.h"
#include "er_work.h"

#define ER_BOOT_CONFIG_ABI_VERSION 2u
#define ER_BOOT_CONFIG_CHANNEL_CAPACITY 8u
#define ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY 8u
#define ER_BOOT_CONFIG_GENERATION_INVALID 0u
#define ER_BOOT_CONFIG_LABEL_MAX ER_CHANNEL_LABEL_MAX
#define ER_BOOT_CONFIG_WIFI_SSID_MAX 32u
#define ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN 7u
#define ER_BOOT_CONFIG_FIRMWARE_PATH_MAX 32u
#define ER_BOOT_CONFIG_FIRMWARE_PATH_LEN 25u
#define ER_BOOT_CONFIG_FIRMWARE_INSTANCE_MAX 9u

#define ER_BOOT_CONFIG_CHANNEL_DISABLED 0u
#define ER_BOOT_CONFIG_CHANNEL_ENABLED 1u

#define ER_BOOT_CONFIG_WIFI_ROLE_NONE 0u
#define ER_BOOT_CONFIG_WIFI_ROLE_AUTO 1u
#define ER_BOOT_CONFIG_WIFI_ROLE_AP 2u
#define ER_BOOT_CONFIG_WIFI_ROLE_STA 3u

#define ER_BOOT_CONFIG_WIFI_SECURITY_OPEN 1u

#define ER_BOOT_CONFIG_FIRMWARE_SOURCE_DISABLED 0u
#define ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION 1u

typedef struct {
  UINT8 enabled;
  UINT8 channel_kind;
  UINT16 label_len;
  UINT8 wifi_role;
  UINT8 wifi_security;
  UINT16 ssid_len;
  char label[ER_BOOT_CONFIG_LABEL_MAX];
  char ssid[ER_BOOT_CONFIG_WIFI_SSID_MAX];
} ErBootRelayChannelConfig;

typedef struct {
  UINT8 enabled;
  UINT8 source_kind;
  UINT8 instance;
  UINT8 reserved;
  UINT16 pci_vendor_id;
  UINT16 pci_device_id;
  UINT16 path_len;
  char path[ER_BOOT_CONFIG_FIRMWARE_PATH_MAX];
} ErBootFirmwareSourceConfig;

typedef struct {
  UINT16 abi_version;
  UINT16 channel_count;
  UINT16 firmware_source_count;
  UINT16 reserved;
  UINT32 generation;
  ErCredential admission_identity;
  ErBootRelayChannelConfig channels[ER_BOOT_CONFIG_CHANNEL_CAPACITY];
  ErBootFirmwareSourceConfig firmware_sources[ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY];
} ErBootConfig;

void er_boot_config_init(ErBootConfig* config);
UINT8 er_boot_config_set_admission_identity(ErBootConfig* config,
                                            const ErCredential* admission_identity);
UINT8 er_boot_config_add_channel(ErBootConfig* config, UINT8 channel_kind,
                                 const char* label, UINT16 label_len);
UINT8 er_boot_config_add_open_wifi_channel(ErBootConfig* config,
                                           UINT8 wifi_role,
                                           const char* label,
                                           UINT16 label_len);
UINT8 er_boot_config_add_efi_firmware_source(ErBootConfig* config,
                                             UINT16 pci_vendor_id,
                                             UINT16 pci_device_id);
UINT8 er_boot_config_add_efi_firmware_source_instance(ErBootConfig* config,
                                                      UINT16 pci_vendor_id,
                                                      UINT16 pci_device_id,
                                                      UINT8 instance);
const ErBootFirmwareSourceConfig* er_boot_config_find_efi_firmware_source(const ErBootConfig* config,
                                                                          UINT16 pci_vendor_id,
                                                                          UINT16 pci_device_id);
const ErBootFirmwareSourceConfig* er_boot_config_find_efi_firmware_source_instance(const ErBootConfig* config,
                                                                                   UINT16 pci_vendor_id,
                                                                                   UINT16 pci_device_id,
                                                                                   UINT8 instance);
UINT8 er_boot_config_valid(const ErBootConfig* config);
const char* er_boot_config_wifi_fixed_ssid(void);

#endif

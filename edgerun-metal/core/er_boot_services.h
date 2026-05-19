#ifndef ER_BOOT_SERVICES_H
#define ER_BOOT_SERVICES_H

/*
 * Purpose: define the firmware-time boundary before EdgeRun exits UEFI Boot Services.
 * Intention: keep hardware probing, boot trust, authority selection, and runtime launch state explicit.
 */

#include "er_pci.h"
#include "er_tpm.h"
#include "er_boot_admission_record.h"

#define ER_BOOT_AUTHORITY_PROFILE_CAPACITY 8u
#define ER_BOOT_DETECTED_DEVICE_CAPACITY 32u
#define ER_BOOT_AUTHORITY_LABEL_MAX 32u

#define ER_BOOT_AUTHORITY_HANDLE_INVALID 0u
#define ER_BOOT_CONFIG_GENERATION_INVALID 0u
#define ER_BOOT_ONBOARDING_SELECTED_INVALID ER_BOOT_AUTHORITY_PROFILE_CAPACITY
#define ER_BOOT_RUNTIME_CAPABILITY_ABI_VERSION 1u

#define ER_BOOT_LOCAL_STORAGE_KIND_NONE 0u
#define ER_BOOT_LOCAL_STORAGE_KIND_EFI_SYSTEM_PARTITION 1u
#define ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD 2u

#define ER_BOOT_WIFI_KIND_NONE 0u
#define ER_BOOT_WIFI_KIND_OPEN_L2 1u
#define ER_BOOT_WIFI_KIND_CYW43439_SDIO 2u
#define ER_BOOT_WIFI_KIND_CYW43438_SDIO 3u

#define ER_BOOT_BLUETOOTH_KIND_NONE 0u
#define ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART 1u
#define ER_BOOT_BLUETOOTH_KIND_CYW43438_HCI_UART 2u

#define ER_BOOT_UPDATE_READY 0u
#define ER_BOOT_UPDATE_BLOCKED_NO_WIFI 1u
#define ER_BOOT_UPDATE_BLOCKED_NO_WRITABLE_STORAGE 2u
#define ER_BOOT_UPDATE_BLOCKED_NO_ARTIFACT_STORE 3u

typedef enum {
  ER_BOOT_SECURE_BOOT_UNKNOWN = 0,
  ER_BOOT_SECURE_BOOT_DISABLED = 1,
  ER_BOOT_SECURE_BOOT_VERIFIED = 2
} ErBootSecureBootState;

typedef enum {
  ER_BOOT_CONFIG_UNKNOWN = 0,
  ER_BOOT_CONFIG_MISSING = 1,
  ER_BOOT_CONFIG_PRESENT = 2,
  ER_BOOT_CONFIG_INVALID = 3
} ErBootConfigState;

typedef enum {
  ER_BOOT_SERVICES_ACTION_BLOCKED = 0,
  ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY = 1,
  ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY = 2,
  ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME = 3
} ErBootServicesAction;

typedef enum {
  ER_BOOT_ONBOARDING_STATE_FATAL = 0,
  ER_BOOT_ONBOARDING_STATE_CREATE_FIRST_PROFILE = 1,
  ER_BOOT_ONBOARDING_STATE_SELECT_PROFILE = 2,
  ER_BOOT_ONBOARDING_STATE_READY = 3
} ErBootOnboardingState;

typedef struct {
  UINT8 present;
  UINT8 kind;
  UINT16 vendor_id;
  UINT32 bus;
  UINT32 dev;
  UINT32 func;
  UINT32 class_revision;
} ErBootDetectedDevice;

typedef struct {
  UINT8 present;
  UINT8 config_state;
  UINT16 label_len;
  UINT32 tpm_persistent_handle;
  UINT32 boot_config_generation;
  char label[ER_BOOT_AUTHORITY_LABEL_MAX];
} ErBootAuthorityProfile;

typedef struct {
  UINT16 abi_version;
  UINT8 wifi_kind;
  UINT8 wifi_ready;
  UINT8 local_storage_kind;
  UINT8 local_storage_writable;
  UINT8 update_artifact_store_ready;
  UINT8 update_ready;
  UINT8 update_blocked_reason;
  UINT8 wifi_channel;
  UINT8 bluetooth_kind;
  UINT8 bluetooth_ready;
  UINT8 reserved;
  UINT64 local_storage_block_bytes;
  UINT64 local_storage_block_count;
  UINT64 update_artifact_capacity_bytes;
} ErBootRuntimeCapabilities;

typedef struct {
  UINT8 state;
  UINT8 selected_authority;
  UINT16 choice_count;
  ErBootAuthorityProfile choices[ER_BOOT_AUTHORITY_PROFILE_CAPACITY];
} ErBootOnboardingModel;

typedef struct {
  UINT8 tpm_present;
  UINT8 secure_boot_state;
  UINT8 config_state;
  UINT8 selected_authority;
  UINT32 authority_count;
  UINT32 device_count;
  ErTpmNvLimits tpm_nv_limits;
  UINT8 boot_admission_present;
  UINT8 reserved[3];
  ErBootAdmissionRecord boot_admission;
  ErBootRuntimeCapabilities runtime_capabilities;
  ErBootAuthorityProfile authorities[ER_BOOT_AUTHORITY_PROFILE_CAPACITY];
  ErBootDetectedDevice devices[ER_BOOT_DETECTED_DEVICE_CAPACITY];
} ErBootServicesReport;

void er_boot_services_report_init(ErBootServicesReport* report);
UINT8 er_boot_services_authority_label_valid(const char* label,
                                             UINT16 label_len);
UINT8 er_boot_services_probe_secure_boot(EFI_SYSTEM_TABLE* system_table,
                                         ErBootServicesReport* report);
UINT8 er_boot_services_probe_tpm(EFI_SYSTEM_TABLE* system_table,
                                 ErBootServicesReport* report);
UINT8 er_boot_services_set_tpm_limits(ErBootServicesReport* report,
                                      const ErTpmNvLimits* limits);
UINT8 er_boot_services_set_boot_admission(ErBootServicesReport* report,
                                          const ErCryptoProvider* crypto,
                                          const ErBootAdmissionRecord* record);
UINT8 er_boot_services_set_wifi_runtime(ErBootServicesReport* report,
                                        UINT8 wifi_kind,
                                        UINT8 wifi_ready,
                                        UINT8 wifi_channel);
UINT8 er_boot_services_set_bluetooth_runtime(ErBootServicesReport* report,
                                             UINT8 bluetooth_kind,
                                             UINT8 bluetooth_ready);
UINT8 er_boot_services_set_local_storage(ErBootServicesReport* report,
                                         UINT8 storage_kind,
                                         UINT8 writable,
                                         UINT64 block_bytes,
                                         UINT64 block_count);
UINT8 er_boot_services_set_update_artifact_store(ErBootServicesReport* report,
                                                 UINT8 ready,
                                                 UINT64 capacity_bytes);
UINT8 er_boot_services_update_runtime_capabilities(ErBootServicesReport* report);
UINT8 er_boot_services_add_pci_device(ErBootServicesReport* report,
                                      const ErPciDeviceSnapshot* snapshot);
UINT8 er_boot_services_add_authority(ErBootServicesReport* report,
                                     UINT32 tpm_persistent_handle,
                                     UINT32 boot_config_generation,
                                     UINT8 config_state);
UINT8 er_boot_services_add_authority_profile(ErBootServicesReport* report,
                                             UINT32 tpm_persistent_handle,
                                             UINT32 boot_config_generation,
                                             UINT8 config_state,
                                             const char* label,
                                             UINT16 label_len);
UINT8 er_boot_services_select_authority(ErBootServicesReport* report,
                                        UINT32 authority_index);
UINT8 er_boot_services_report_has_ephemeral_admission(const ErBootServicesReport* report);
ErBootServicesAction er_boot_services_decide_action(const ErBootServicesReport* report);
const char* er_boot_services_action_label(ErBootServicesAction action);
void er_boot_services_onboarding_model(const ErBootServicesReport* report,
                                       ErBootOnboardingModel* out_model);
const char* er_boot_services_onboarding_state_label(UINT8 state);
UINT8 er_boot_services_runtime_entry_allowed(const ErBootServicesReport* report);

#endif

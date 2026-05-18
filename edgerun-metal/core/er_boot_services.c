#include "er_boot_services.h"
#include "er_mem.h"

//@optimizer-ignore-constant UEFI global variable GUID bytes are fixed by the UEFI specification
static EFI_GUID g_er_efi_global_variable_guid = {
  0x8be4df61u,
  0x93cau,
  0x11d2u,
  {0xaau, 0x0du, 0x00u, 0xe0u, 0x98u, 0x03u, 0x2bu, 0x8cu}
};

static CHAR16 g_er_efi_secure_boot_name[] = {
  (CHAR16)'S', (CHAR16)'e', (CHAR16)'c', (CHAR16)'u', (CHAR16)'r',
  (CHAR16)'e', (CHAR16)'B', (CHAR16)'o', (CHAR16)'o', (CHAR16)'t', 0u
};

void er_boot_services_report_init(ErBootServicesReport* report) {
  if (report == 0) {
    return;
  }
  er_mem_zero((UINT8*)report, (UINTN)sizeof(*report));
  report->secure_boot_state = ER_BOOT_SECURE_BOOT_UNKNOWN;
  report->config_state = ER_BOOT_CONFIG_UNKNOWN;
  report->selected_authority = ER_BOOT_AUTHORITY_PROFILE_CAPACITY;
}

UINT8 er_boot_services_probe_secure_boot(EFI_SYSTEM_TABLE* system_table,
                                         ErBootServicesReport* report) {
  UINT8 secure_boot;
  UINTN data_size;
  EFI_STATUS status;

  if (system_table == 0 || system_table->RuntimeServices == 0 ||
      system_table->RuntimeServices->GetVariable == 0 || report == 0) {
    return 0u;
  }

  secure_boot = 0u;
  data_size = 1u;
  status = system_table->RuntimeServices->GetVariable(g_er_efi_secure_boot_name,
                                                      &g_er_efi_global_variable_guid,
                                                      0, &data_size, &secure_boot);
  if (status != EFI_SUCCESS || data_size != 1u) {
    report->secure_boot_state = ER_BOOT_SECURE_BOOT_UNKNOWN;
    return 0u;
  }

  switch (secure_boot) {
    case 0u:
      report->secure_boot_state = ER_BOOT_SECURE_BOOT_DISABLED;
      return 1u;
    case 1u:
      report->secure_boot_state = ER_BOOT_SECURE_BOOT_VERIFIED;
      return 1u;
    default:
      report->secure_boot_state = ER_BOOT_SECURE_BOOT_UNKNOWN;
      return 0u;
  }
}

UINT8 er_boot_services_set_tpm_limits(ErBootServicesReport* report,
                                      const ErTpmNvLimits* limits) {
  if (report == 0 || limits == 0 ||
      limits->has_nv_index_max == 0u ||
      limits->has_nv_buffer_max == 0u) {
    return 0u;
  }
  report->tpm_present = 1u;
  report->tpm_nv_limits = *limits;
  return 1u;
}

UINT8 er_boot_services_add_pci_device(ErBootServicesReport* report,
                                      const ErPciDeviceSnapshot* snapshot) {
  ErBootDetectedDevice* device;

  if (report == 0 || snapshot == 0 ||
      snapshot->present == 0u ||
      report->device_count >= ER_BOOT_DETECTED_DEVICE_CAPACITY) {
    return 0u;
  }

  device = &report->devices[report->device_count];
  er_mem_zero((UINT8*)device, (UINTN)sizeof(*device));
  device->present = 1u;
  device->kind = er_pci_classify_target(snapshot->id, snapshot->class_revision);
  device->vendor_id = er_pci_vendor_id(snapshot->id);
  device->bus = snapshot->bus;
  device->dev = snapshot->dev;
  device->func = snapshot->func;
  device->class_revision = snapshot->class_revision;
  report->device_count += 1u;
  return 1u;
}

UINT8 er_boot_services_add_authority(ErBootServicesReport* report,
                                     UINT32 tpm_persistent_handle,
                                     UINT32 boot_config_generation,
                                     UINT8 config_state) {
  ErBootAuthorityProfile* authority;

  if (report == 0 ||
      tpm_persistent_handle == ER_BOOT_AUTHORITY_HANDLE_INVALID ||
      boot_config_generation == ER_BOOT_CONFIG_GENERATION_INVALID ||
      config_state != ER_BOOT_CONFIG_PRESENT ||
      report->authority_count >= ER_BOOT_AUTHORITY_PROFILE_CAPACITY) {
    return 0u;
  }

  authority = &report->authorities[report->authority_count];
  er_mem_zero((UINT8*)authority, (UINTN)sizeof(*authority));
  authority->present = 1u;
  authority->config_state = config_state;
  authority->tpm_persistent_handle = tpm_persistent_handle;
  authority->boot_config_generation = boot_config_generation;
  report->authority_count += 1u;
  if (report->config_state == ER_BOOT_CONFIG_UNKNOWN ||
      report->config_state == ER_BOOT_CONFIG_MISSING) {
    report->config_state = ER_BOOT_CONFIG_PRESENT;
  }
  return 1u;
}

UINT8 er_boot_services_select_authority(ErBootServicesReport* report,
                                        UINT32 authority_index) {
  if (report == 0 ||
      authority_index >= report->authority_count ||
      authority_index >= ER_BOOT_AUTHORITY_PROFILE_CAPACITY ||
      report->authorities[authority_index].present == 0u) {
    return 0u;
  }
  report->selected_authority = (UINT8)authority_index;
  return 1u;
}

ErBootServicesAction er_boot_services_decide_action(const ErBootServicesReport* report) {
  if (report == 0 ||
      report->secure_boot_state != ER_BOOT_SECURE_BOOT_VERIFIED ||
      report->tpm_present == 0u ||
      report->config_state == ER_BOOT_CONFIG_INVALID) {
    return ER_BOOT_SERVICES_ACTION_HALT;
  }

  switch (report->authority_count) {
    case 0u:
      return ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY;
    case 1u:
      if (report->authorities[0].present == 0u ||
          report->authorities[0].config_state != ER_BOOT_CONFIG_PRESENT) {
        return ER_BOOT_SERVICES_ACTION_HALT;
      }
      return ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME;
    default:
      break;
  }

  if (report->selected_authority >= report->authority_count ||
      report->selected_authority >= ER_BOOT_AUTHORITY_PROFILE_CAPACITY) {
    return ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY;
  }
  if (report->authorities[report->selected_authority].present == 0u ||
      report->authorities[report->selected_authority].config_state != ER_BOOT_CONFIG_PRESENT) {
    return ER_BOOT_SERVICES_ACTION_HALT;
  }
  return ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME;
}

const char* er_boot_services_action_label(ErBootServicesAction action) {
  switch (action) {
    case ER_BOOT_SERVICES_ACTION_HALT:
      return "halt";
    case ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY:
      return "configure-authority";
    case ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY:
      return "select-authority";
    case ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME:
      return "enter-runtime";
    default:
      return "invalid";
  }
}

UINT8 er_boot_services_runtime_entry_allowed(const ErBootServicesReport* report) {
  return (UINT8)(er_boot_services_decide_action(report) == ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
}

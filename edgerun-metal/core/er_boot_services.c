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

static const char g_er_boot_authority_default_label[] = {
  'a', 'u', 't', 'h', 'o', 'r', 'i', 't', 'y'
};

#define ER_BOOT_SERVICES_TPM_COMMAND_BYTES 128u
#define ER_BOOT_SERVICES_TPM_RESPONSE_BYTES 512u
#define ER_BOOT_SERVICES_TPM_PROPERTY_COUNT 2u

static UINT8 er_boot_services_authority_profile_ready(const ErBootAuthorityProfile* authority) {
  if (authority == 0 ||
      authority->present == 0u ||
      authority->config_state != ER_BOOT_CONFIG_PRESENT ||
      authority->tpm_persistent_handle == ER_BOOT_AUTHORITY_HANDLE_INVALID ||
      authority->boot_config_generation == ER_BOOT_CONFIG_GENERATION_INVALID ||
      er_boot_services_authority_label_valid(authority->label, authority->label_len) == 0u) {
    return 0u;
  }

  return 1u;
}

void er_boot_services_report_init(ErBootServicesReport* report) {
  if (report == 0) {
    return;
  }
  er_mem_zero((UINT8*)report, (UINTN)sizeof(*report));
  report->secure_boot_state = ER_BOOT_SECURE_BOOT_UNKNOWN;
  report->config_state = ER_BOOT_CONFIG_UNKNOWN;
  report->selected_authority = ER_BOOT_AUTHORITY_PROFILE_CAPACITY;
}

UINT8 er_boot_services_authority_label_valid(const char* label,
                                             UINT16 label_len) {
  UINT16 i;

  if (label == 0 || label_len == 0u || label_len > ER_BOOT_AUTHORITY_LABEL_MAX) {
    return 0u;
  }

  for (i = 0u; i < label_len; ++i) {
    if (label[i] < ' ' || label[i] > '~') {
      return 0u;
    }
  }

  return 1u;
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

UINT8 er_boot_services_probe_tpm(EFI_SYSTEM_TABLE* system_table,
                                 ErBootServicesReport* report) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  ErTpm2Info tpm2;
  ErTpmCrbTransport transport;
  ErTpmNvLimits limits;
  UINT8 command[ER_BOOT_SERVICES_TPM_COMMAND_BYTES];
  UINT8 response[ER_BOOT_SERVICES_TPM_RESPONSE_BYTES];
  UINT32 command_len;
  UINT32 response_len;

  if (system_table == 0 || report == 0 ||
      er_acpi_find_rsdp(system_table, &rsdp) == 0u ||
      er_acpi_enumerate_tables(&rsdp, &tables) == 0u ||
      er_tpm_find_tpm2_table(&tables, &tpm2) == 0u ||
      er_tpm_crb_from_tpm2_info(&tpm2, &transport) == 0u ||
      er_tpm_build_get_capability_command(ER_TPM_CAP_TPM_PROPERTIES,
                                          ER_TPM_PT_NV_INDEX_MAX,
                                          ER_BOOT_SERVICES_TPM_PROPERTY_COUNT,
                                          command,
                                          (UINT32)sizeof(command),
                                          &command_len) == 0u) {
    return 0u;
  }

  if (er_tpm_crb_transact(&transport,
                          command,
                          command_len,
                          response,
                          (UINT32)sizeof(response),
                          &response_len) == 0u ||
      er_tpm_parse_nv_storage_limits_response(response, response_len, &limits) == 0u ||
      er_boot_services_set_tpm_limits(report, &limits) == 0u) {
    return 0u;
  }

  return 1u;
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
  return er_boot_services_add_authority_profile(report,
                                                tpm_persistent_handle,
                                                boot_config_generation,
                                                config_state,
                                                g_er_boot_authority_default_label,
                                                (UINT16)sizeof(g_er_boot_authority_default_label));
}

UINT8 er_boot_services_add_authority_profile(ErBootServicesReport* report,
                                             UINT32 tpm_persistent_handle,
                                             UINT32 boot_config_generation,
                                             UINT8 config_state,
                                             const char* label,
                                             UINT16 label_len) {
  ErBootAuthorityProfile* authority;

  if (report == 0 ||
      tpm_persistent_handle == ER_BOOT_AUTHORITY_HANDLE_INVALID ||
      boot_config_generation == ER_BOOT_CONFIG_GENERATION_INVALID ||
      config_state != ER_BOOT_CONFIG_PRESENT ||
      er_boot_services_authority_label_valid(label, label_len) == 0u ||
      report->authority_count >= ER_BOOT_AUTHORITY_PROFILE_CAPACITY) {
    return 0u;
  }

  authority = &report->authorities[report->authority_count];
  er_mem_zero((UINT8*)authority, (UINTN)sizeof(*authority));
  authority->present = 1u;
  authority->config_state = config_state;
  authority->label_len = label_len;
  authority->tpm_persistent_handle = tpm_persistent_handle;
  authority->boot_config_generation = boot_config_generation;
  er_mem_copy((UINT8*)authority->label, (const UINT8*)label, label_len);
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
      er_boot_services_authority_profile_ready(&report->authorities[authority_index]) == 0u) {
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
    return ER_BOOT_SERVICES_ACTION_BLOCKED;
  }

  switch (report->authority_count) {
    case 0u:
      return ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY;
    case 1u:
      if (er_boot_services_authority_profile_ready(&report->authorities[0]) == 0u) {
        return ER_BOOT_SERVICES_ACTION_BLOCKED;
      }
      return ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME;
    default:
      break;
  }

  if (report->selected_authority >= report->authority_count ||
      report->selected_authority >= ER_BOOT_AUTHORITY_PROFILE_CAPACITY) {
    return ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY;
  }
  if (er_boot_services_authority_profile_ready(&report->authorities[report->selected_authority]) == 0u) {
    return ER_BOOT_SERVICES_ACTION_BLOCKED;
  }
  return ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME;
}

const char* er_boot_services_action_label(ErBootServicesAction action) {
  switch (action) {
    case ER_BOOT_SERVICES_ACTION_BLOCKED:
      return "blocked";
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

void er_boot_services_onboarding_model(const ErBootServicesReport* report,
                                       ErBootOnboardingModel* out_model) {
  UINT32 i;
  ErBootServicesAction action;

  if (out_model == 0) {
    return;
  }

  er_mem_zero((UINT8*)out_model, (UINTN)sizeof(*out_model));
  out_model->state = ER_BOOT_ONBOARDING_STATE_FATAL;
  out_model->selected_authority = ER_BOOT_ONBOARDING_SELECTED_INVALID;

  if (report == 0) {
    return;
  }

  action = er_boot_services_decide_action(report);
  switch (action) {
    case ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY:
      out_model->state = ER_BOOT_ONBOARDING_STATE_CREATE_FIRST_PROFILE;
      break;
    case ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY:
      out_model->state = ER_BOOT_ONBOARDING_STATE_SELECT_PROFILE;
      break;
    case ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME:
      out_model->state = ER_BOOT_ONBOARDING_STATE_READY;
      break;
    case ER_BOOT_SERVICES_ACTION_BLOCKED:
    default:
      out_model->state = ER_BOOT_ONBOARDING_STATE_FATAL;
      break;
  }

  if (report->selected_authority < report->authority_count &&
      report->selected_authority < ER_BOOT_AUTHORITY_PROFILE_CAPACITY) {
    out_model->selected_authority = report->selected_authority;
  }

  for (i = 0u; i < report->authority_count && i < ER_BOOT_AUTHORITY_PROFILE_CAPACITY; ++i) {
    if (er_boot_services_authority_profile_ready(&report->authorities[i]) == 0u) {
      out_model->state = ER_BOOT_ONBOARDING_STATE_FATAL;
      out_model->choice_count = 0u;
      out_model->selected_authority = ER_BOOT_ONBOARDING_SELECTED_INVALID;
      return;
    }
    out_model->choices[out_model->choice_count] = report->authorities[i];
    out_model->choice_count += 1u;
  }
}

const char* er_boot_services_onboarding_state_label(UINT8 state) {
  switch (state) {
    case ER_BOOT_ONBOARDING_STATE_FATAL:
      return "fatal";
    case ER_BOOT_ONBOARDING_STATE_CREATE_FIRST_PROFILE:
      return "create-first-profile";
    case ER_BOOT_ONBOARDING_STATE_SELECT_PROFILE:
      return "select-profile";
    case ER_BOOT_ONBOARDING_STATE_READY:
      return "ready";
    default:
      return "invalid";
  }
}

UINT8 er_boot_services_runtime_entry_allowed(const ErBootServicesReport* report) {
  return (UINT8)(er_boot_services_decide_action(report) == ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
}

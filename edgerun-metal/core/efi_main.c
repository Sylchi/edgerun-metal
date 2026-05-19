#include "efi_boot_internal.h"

void er_run_invalid_boot_path(void) {
  er_print("invalid boot path: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
}

static void er_boot_services_print_report(const ErBootServicesReport* report) {
  if (report == 0) {
    er_println("boot services: report unavailable");
    return;
  }
  er_print("boot services: secure boot state=");
  er_print_u64_dec((UINT64)report->secure_boot_state);
  er_print(" tpm=");
  er_print_u64_dec((UINT64)report->tpm_present);
  er_print(" authorities=");
  er_print_u64_dec((UINT64)report->authority_count);
  er_print(" devices=");
  er_print_u64_dec((UINT64)report->device_count);
  if (report->tpm_present != 0u) {
    er_print(" tpm-nv-index-max=");
    er_print_u64_dec((UINT64)report->tpm_nv_limits.nv_index_max);
    er_print(" tpm-nv-buffer-max=");
    er_print_u64_dec((UINT64)report->tpm_nv_limits.nv_buffer_max);
  }
  er_print(" action=");
  er_print(er_boot_services_action_label(er_boot_services_decide_action(report)));
  er_println("");
}

static void er_boot_services_print_bounded_ascii(const char* text, UINT16 text_len) {
  char out[ER_BOOT_AUTHORITY_LABEL_MAX + 1u];
  UINT16 i;

  if (text == 0 || text_len > ER_BOOT_AUTHORITY_LABEL_MAX) {
    return;
  }
  for (i = 0u; i < text_len; ++i) {
    out[i] = text[i];
  }
  out[text_len] = 0;
  er_print(out);
}

static void er_boot_services_print_onboarding(const ErBootServicesReport* report) {
  ErBootOnboardingModel onboarding;
  UINT16 i;

  er_boot_services_onboarding_model(report, &onboarding);
  er_print("onboarding: state=");
  er_print(er_boot_services_onboarding_state_label(onboarding.state));
  er_print(" choices=");
  er_print_u64_dec((UINT64)onboarding.choice_count);
  er_print(" selected=");
  er_print_u64_dec((UINT64)onboarding.selected_authority);
  er_println("");

  switch (onboarding.state) {
    case ER_BOOT_ONBOARDING_STATE_CREATE_FIRST_PROFILE:
      er_println("onboarding: create first authority profile");
      er_println("onboarding: profile creation persistence is not implemented yet");
      break;
    case ER_BOOT_ONBOARDING_STATE_SELECT_PROFILE:
      er_println("onboarding: select authority profile");
      for (i = 0u; i < onboarding.choice_count; ++i) {
        er_print("  profile ");
        er_print_u64_dec((UINT64)i);
        er_print(": ");
        er_boot_services_print_bounded_ascii(onboarding.choices[i].label,
                                             onboarding.choices[i].label_len);
        er_print(" tpm=");
        er_print_u64_hex((UINT64)onboarding.choices[i].tpm_persistent_handle);
        er_print(" config-generation=");
        er_print_u64_dec((UINT64)onboarding.choices[i].boot_config_generation);
        er_println("");
      }
      break;
    case ER_BOOT_ONBOARDING_STATE_READY:
      er_println("onboarding: selected authority is ready");
      break;
    case ER_BOOT_ONBOARDING_STATE_FATAL:
    default:
      er_println("onboarding: blocked until Secure Boot, TPM, and config are verified");
      break;
  }
}

void er_run_boot_path(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable,
                      const ErBootServicesReport* boot_report) {
  ErBootServicesAction action;

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_OS) {
    action = er_boot_services_decide_action(boot_report);
    switch (action) {
      case ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME:
        er_run_os_path(ImageHandle, SystemTable, boot_report);
        return;
      case ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY:
      case ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY:
        er_print("boot services: onboarding required action=");
        er_print(er_boot_services_action_label(action));
        er_println("");
        er_boot_services_print_onboarding(boot_report);
        return;
      case ER_BOOT_SERVICES_ACTION_BLOCKED:
      default:
        er_print("boot services: blocked action=");
        er_print(er_boot_services_action_label(action));
        er_println("");
        er_boot_services_print_onboarding(boot_report);
        return;
    }
  }

  er_run_invalid_boot_path();
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  ErBootServicesReport boot_report;

  (void)ImageHandle;

  er_boot_services_report_init(&boot_report);
  er_select_large_console(SystemTable);
  er_print_set_system_table(SystemTable);
  er_mmio_reset();
  er_install_hostcalls();

  er_println("EdgeRun Metal Core v0.2");
  er_println("UEFI boot OK");
  er_log_acpi(SystemTable);
  (void)er_pci_configure_mcfg_from_acpi(SystemTable);
  (void)er_boot_services_probe_secure_boot(SystemTable, &boot_report);
  if (er_boot_services_probe_tpm(SystemTable, &boot_report) == 0u) {
    er_println("TPM: discovery unavailable");
  } else {
    er_print("TPM: CRB present nv-index-max=");
    er_print_u64_dec((UINT64)boot_report.tpm_nv_limits.nv_index_max);
    er_print(" nv-buffer-max=");
    er_print_u64_dec((UINT64)boot_report.tpm_nv_limits.nv_buffer_max);
    er_println("");
  }
  er_boot_services_print_report(&boot_report);

  er_run_boot_path(ImageHandle, SystemTable, &boot_report);
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_OS) {
    return EFI_SUCCESS;
  }
  return EFI_SUCCESS;
}

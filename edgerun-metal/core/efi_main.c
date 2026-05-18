#include "efi_boot_internal.h"

void er_run_invalid_boot_path(void) {
  er_print("invalid boot path: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
  er_halt_forever();
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
  er_print(" action=");
  er_print(er_boot_services_action_label(er_boot_services_decide_action(report)));
  er_println("");
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
        er_print("boot services: config mode required action=");
        er_print(er_boot_services_action_label(action));
        er_println("");
        er_halt_forever();
        return;
      case ER_BOOT_SERVICES_ACTION_HALT:
      default:
        er_print("boot services: fatal action=");
        er_print(er_boot_services_action_label(action));
        er_println("");
        er_halt_forever();
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
  er_boot_services_print_report(&boot_report);

  er_run_boot_path(ImageHandle, SystemTable, &boot_report);
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_OS) {
    return EFI_SUCCESS;
  }
  return EFI_SUCCESS;
}

#include "efi_boot_internal.h"

void er_run_invalid_boot_path(void) {
  er_print("invalid boot path: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
  er_halt_forever();
}

void er_run_boot_path(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_OS) {
    er_run_os_path(ImageHandle, SystemTable);
    return;
  }

  er_run_invalid_boot_path();
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  (void)ImageHandle;

  er_select_large_console(SystemTable);
  er_print_set_system_table(SystemTable);
  er_mmio_reset();
  er_install_hostcalls();

  er_println("EdgeRun Metal Core v0.2");
  er_println("UEFI boot OK");
  er_log_acpi(SystemTable);

  er_run_boot_path(ImageHandle, SystemTable);
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_OS) {
    return EFI_SUCCESS;
  }
  return EFI_SUCCESS;
}

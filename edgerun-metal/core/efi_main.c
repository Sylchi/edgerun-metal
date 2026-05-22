#include "internal/efi_boot_internal.h"
#include "er_tpm_acpi.h"
#include "er_tpm_bench.h"

static void er_metal_print_tpm_probe(EFI_SYSTEM_TABLE* SystemTable) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  ErTpm2Info tpm2;
  ErTpmCrbTransport transport;

  if (er_acpi_find_rsdp(SystemTable, &rsdp) == 0u ||
      er_acpi_enumerate_tables(&rsdp, &tables) == 0u) {
    er_println("TPM: ACPI table scan unavailable");
    return;
  }
  if (er_tpm_find_tpm2_table(&tables, &tpm2) == 0u) {
    er_println("TPM: TPM2 table missing");
    return;
  }
  er_print("TPM: TPM2 start-method=");
  er_print_u64_dec((UINT64)tpm2.start_method);
  er_print(" control-area=");
  er_print_u64_hex(tpm2.control_area);
  er_println("");
  if (er_tpm_crb_from_tpm2_info(&tpm2, &transport) == 0u) {
    er_println("TPM: CRB transport unavailable");
    return;
  }
  er_print("TPM: CRB transport control=");
  er_print_u64_hex(transport.control_area);
  er_print(" command=");
  er_print_u64_hex(transport.command_buffer);
  er_print(" command-size=");
  er_print_u64_dec(transport.command_buffer_size);
  er_print(" response=");
  er_print_u64_hex(transport.response_buffer);
  er_print(" response-size=");
  er_print_u64_dec(transport.response_buffer_size);
  er_println("");
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  (void)ImageHandle;

  er_select_large_console(SystemTable);
  (void)er_netlog_init(SystemTable);
  er_print_set_system_table(SystemTable);
  er_mmio_reset();

  er_println("EdgeRun Metal Drivers v0.2");
  er_println("UEFI boot OK");
  er_log_acpi(SystemTable);
  (void)er_pci_configure_mcfg_from_acpi(SystemTable);
  er_metal_print_tpm_probe(SystemTable);
#if ER_TPM_REAL_BENCH_ENABLED
  er_tpm_real_benchmark(SystemTable);
#endif
  er_println("metal: hardware driver boundary reached");
  er_idle_forever();
  return EFI_SUCCESS;
}

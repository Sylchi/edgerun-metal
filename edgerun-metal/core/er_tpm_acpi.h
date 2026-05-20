#ifndef ER_TPM_ACPI_H
#define ER_TPM_ACPI_H

/*
 * Purpose: discover TPM2 hardware through ACPI tables.
 * Intention: keep ACPI discovery outside the TPM command/TLS library boundary.
 */

#include "er_acpi.h"
#include "er_tpm.h"

UINT8 er_tpm_parse_tpm2_table(UINT64 tpm2_address, ErTpm2Info* out_info);
UINT8 er_tpm_find_tpm2_table(const ErAcpiTableList* tables, ErTpm2Info* out_info);

#endif

#ifndef ER_BOOT_EFI_VARS_H
#define ER_BOOT_EFI_VARS_H

/*
 * Purpose: read and write EdgeRun boot records from UEFI variables.
 * Intention: keep NVRAM use tiny, explicit, and fixed-record only.
 */

#include "er_boot_admission_record.h"

#define ER_BOOT_EFI_VAR_ADMISSION_FOUND 1u
#define ER_BOOT_EFI_VAR_ADMISSION_MISSING 2u
#define ER_BOOT_EFI_VAR_ADMISSION_INVALID 3u

UINT8 er_boot_efi_vars_read_admission(EFI_SYSTEM_TABLE* system_table,
                                      const ErCryptoProvider* crypto,
                                      ErBootAdmissionRecord* out_record);
UINT8 er_boot_efi_vars_write_admission(EFI_SYSTEM_TABLE* system_table,
                                       const ErCryptoProvider* crypto,
                                       const ErBootAdmissionRecord* record);
const char* er_boot_efi_vars_admission_read_label(UINT8 state);

#endif

#include "er_boot_efi_vars.h"
#include "er_mem.h"

#define ER_BOOT_EFI_VAR_ADMISSION_ATTRIBUTES \
  (EFI_VARIABLE_NON_VOLATILE | EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS)

//@optimizer-ignore-constant EdgeRun UEFI variable namespace GUID is a fixed protocol identifier
static EFI_GUID g_er_boot_efi_vars_guid = {
  0x7f9f4f4eu,
  0x2f41u,
  0x4d90u,
  {0x9bu, 0x1cu, 0x45u, 0x64u, 0x52u, 0x55u, 0x4eu, 0x01u}
};

static CHAR16 g_er_boot_efi_vars_admission_name[] = {
  (CHAR16)'E', (CHAR16)'d', (CHAR16)'g', (CHAR16)'e',
  (CHAR16)'R', (CHAR16)'u', (CHAR16)'n',
  (CHAR16)'A', (CHAR16)'d', (CHAR16)'m', (CHAR16)'i',
  (CHAR16)'s', (CHAR16)'s', (CHAR16)'i', (CHAR16)'o', (CHAR16)'n',
  0u
};

UINT8 er_boot_efi_vars_read_admission(EFI_SYSTEM_TABLE* system_table,
                                      const ErCryptoProvider* crypto,
                                      ErBootAdmissionRecord* out_record) {
  UINT8 bytes[ER_BOOT_ADMISSION_RECORD_BYTES];
  UINTN data_size;
  UINT32 attributes;
  EFI_STATUS status;
  ErBootAdmissionRecord decoded;

  if (out_record == 0) {
    return ER_BOOT_EFI_VAR_ADMISSION_INVALID;
  }
  er_boot_admission_record_clear(out_record);

  if (system_table == 0 ||
      system_table->RuntimeServices == 0 ||
      system_table->RuntimeServices->GetVariable == 0 ||
      crypto == 0) {
    return ER_BOOT_EFI_VAR_ADMISSION_INVALID;
  }

  er_mem_zero(bytes, (UINTN)sizeof(bytes));
  data_size = (UINTN)sizeof(bytes);
  attributes = 0u;
  status = system_table->RuntimeServices->GetVariable(g_er_boot_efi_vars_admission_name,
                                                      &g_er_boot_efi_vars_guid,
                                                      &attributes,
                                                      &data_size,
                                                      bytes);
  if (status == EFI_NOT_FOUND) {
    return ER_BOOT_EFI_VAR_ADMISSION_MISSING;
  }
  if (status != EFI_SUCCESS ||
      data_size != ER_BOOT_ADMISSION_RECORD_BYTES ||
      (attributes & ER_BOOT_EFI_VAR_ADMISSION_ATTRIBUTES) != ER_BOOT_EFI_VAR_ADMISSION_ATTRIBUTES ||
      er_boot_admission_record_decode(bytes, &decoded) == 0u ||
      er_boot_admission_record_valid(crypto, &decoded) == 0u) {
    return ER_BOOT_EFI_VAR_ADMISSION_INVALID;
  }

  *out_record = decoded;
  return ER_BOOT_EFI_VAR_ADMISSION_FOUND;
}

UINT8 er_boot_efi_vars_write_admission(EFI_SYSTEM_TABLE* system_table,
                                       const ErCryptoProvider* crypto,
                                       const ErBootAdmissionRecord* record) {
  UINT8 bytes[ER_BOOT_ADMISSION_RECORD_BYTES];

  if (system_table == 0 ||
      system_table->RuntimeServices == 0 ||
      system_table->RuntimeServices->SetVariable == 0 ||
      er_boot_admission_record_valid(crypto, record) == 0u ||
      er_boot_admission_record_encode(record, bytes) == 0u) {
    return 0u;
  }

  return (UINT8)(system_table->RuntimeServices->SetVariable(g_er_boot_efi_vars_admission_name,
                                                            &g_er_boot_efi_vars_guid,
                                                            ER_BOOT_EFI_VAR_ADMISSION_ATTRIBUTES,
                                                            (UINTN)sizeof(bytes),
                                                            bytes) == EFI_SUCCESS);
}

const char* er_boot_efi_vars_admission_read_label(UINT8 state) {
  switch (state) {
    case ER_BOOT_EFI_VAR_ADMISSION_FOUND:
      return "found";
    case ER_BOOT_EFI_VAR_ADMISSION_MISSING:
      return "missing";
    case ER_BOOT_EFI_VAR_ADMISSION_INVALID:
      return "invalid";
    default:
      return "unknown";
  }
}

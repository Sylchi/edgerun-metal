#include "er_tpm_acpi.h"

#include "er_mem.h"

/*
 * Purpose: parse ACPI TPM2 discovery tables into TPM transport metadata.
 * Intention: let boot/platform code use ACPI without pulling ACPI into liber_tpm.
 */

enum {
  ER_TPM_ACPI_BYTE0_INDEX = 0u,
  ER_TPM_ACPI_BYTE1_INDEX = 1u,
  ER_TPM_ACPI_BYTE2_INDEX = 2u,
  ER_TPM_ACPI_BYTE3_INDEX = 3u,
  ER_TPM_ACPI_TPM2_PLATFORM_CLASS_OFFSET = 36u,
  ER_TPM_ACPI_TPM2_CONTROL_AREA_OFFSET = 40u,
  ER_TPM_ACPI_TPM2_START_METHOD_OFFSET = 48u,
  ER_TPM_ACPI_TPM2_MIN_LEN = 52u,
  ER_TPM_ACPI_TABLE_LENGTH_OFFSET = 4u,
  ER_TPM_ACPI_BYTE_BITS = 8u,
  ER_TPM_ACPI_U32_MID_BITS = 16u,
  ER_TPM_ACPI_U32_HIGH_BITS = 24u,
  ER_TPM_ACPI_U64_HIGH_BITS = 32u,
  ER_TPM_ACPI_U64_HIGH_OFFSET = 4u
};

static UINT16 er_tpm_acpi_get_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[ER_TPM_ACPI_BYTE0_INDEX] |
                  ((UINT16)bytes[ER_TPM_ACPI_BYTE1_INDEX] << ER_TPM_ACPI_BYTE_BITS));
}

static UINT32 er_tpm_acpi_get_le32(const UINT8* bytes) {
  return (UINT32)((UINT32)bytes[ER_TPM_ACPI_BYTE0_INDEX] |
                  ((UINT32)bytes[ER_TPM_ACPI_BYTE1_INDEX] << ER_TPM_ACPI_BYTE_BITS) |
                  ((UINT32)bytes[ER_TPM_ACPI_BYTE2_INDEX] << ER_TPM_ACPI_U32_MID_BITS) |
                  ((UINT32)bytes[ER_TPM_ACPI_BYTE3_INDEX] << ER_TPM_ACPI_U32_HIGH_BITS));
}

static UINT64 er_tpm_acpi_get_le64(const UINT8* bytes) {
  return (UINT64)er_tpm_acpi_get_le32(bytes) |
         ((UINT64)er_tpm_acpi_get_le32(bytes + ER_TPM_ACPI_U64_HIGH_OFFSET)
          << ER_TPM_ACPI_U64_HIGH_BITS);
}

UINT8 er_tpm_parse_tpm2_table(UINT64 tpm2_address, ErTpm2Info* out_info) {
  const UINT8* table = (const UINT8*)(UINTN)tpm2_address;
  UINT32 length;

  if (tpm2_address == 0u || out_info == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  length = er_tpm_acpi_get_le32(table + ER_TPM_ACPI_TABLE_LENGTH_OFFSET);
  if (length < ER_TPM_ACPI_TPM2_MIN_LEN ||
      er_tpm_acpi_get_le32(table) != er_acpi_signature("TPM2") ||
      er_acpi_checksum_valid(table, (UINTN)length) == 0u) {
    return 0u;
  }

  out_info->found = 1u;
  out_info->checksum_valid = 1u;
  out_info->platform_class =
      er_tpm_acpi_get_le16(table + ER_TPM_ACPI_TPM2_PLATFORM_CLASS_OFFSET);
  out_info->control_area =
      er_tpm_acpi_get_le64(table + ER_TPM_ACPI_TPM2_CONTROL_AREA_OFFSET);
  out_info->start_method =
      er_tpm_acpi_get_le32(table + ER_TPM_ACPI_TPM2_START_METHOD_OFFSET);
  return 1u;
}

UINT8 er_tpm_find_tpm2_table(const ErAcpiTableList* tables, ErTpm2Info* out_info) {
  ErAcpiTableInfo table;

  if (tables == 0 || out_info == 0) {
    return 0u;
  }
  if (er_acpi_find_table(tables, er_acpi_signature("TPM2"), &table) == 0u) {
    er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
    return 0u;
  }
  return er_tpm_parse_tpm2_table(table.address, out_info);
}

#include "er_tpm.h"
#include "er_mem.h"

/*
 * Purpose: implement direct TPM2 CRB command transport and fixed command builders.
 * Intention: keep TPM hardware access explicit, deterministic, and independent of Linux.
 */

enum {
  ER_TPM_SDT_HEADER_LEN = 36u,
  ER_TPM_TPM2_PLATFORM_CLASS_OFFSET = 36u,
  ER_TPM_TPM2_CONTROL_AREA_OFFSET = 40u,
  ER_TPM_TPM2_START_METHOD_OFFSET = 48u,
  ER_TPM_TPM2_MIN_LEN = 52u,
  ER_TPM_CRB_CTRL_REQ_OFFSET = 0x40u,
  ER_TPM_CRB_CTRL_CANCEL_OFFSET = 0x48u,
  ER_TPM_CRB_CTRL_START_OFFSET = 0x4cu,
  ER_TPM_CRB_CTRL_CMD_SIZE_OFFSET = 0x58u,
  ER_TPM_CRB_CTRL_CMD_ADDR_OFFSET = 0x5cu,
  ER_TPM_CRB_CTRL_RSP_SIZE_OFFSET = 0x64u,
  ER_TPM_CRB_CTRL_RSP_ADDR_OFFSET = 0x68u,
  ER_TPM_CRB_CTRL_REQ_CMD_READY = 1u,
  ER_TPM_CRB_CTRL_START = 1u,
  ER_TPM_CRB_MMIO_SPAN_MAX = 0x10000u,
  ER_TPM_BYTE0_INDEX = 0u,
  ER_TPM_BYTE1_INDEX = 1u,
  ER_TPM_BYTE2_INDEX = 2u,
  ER_TPM_BYTE3_INDEX = 3u,
  ER_TPM_U16_BYTES = 2u,
  ER_TPM_U32_BYTES = 4u,
  ER_TPM_U64_HIGH_OFFSET = 4u,
  ER_TPM_BYTE_BITS = 8u,
  ER_TPM_U32_MID_BITS = 16u,
  ER_TPM_U32_HIGH_BITS = 24u,
  ER_TPM_U64_HIGH_BITS = 32u,
  ER_TPM_BYTE_MASK = 0xffu,
  ER_TPM_MMIO_PAGE_MASK = 0xfffu,
  ER_TPM_MMIO_PAGE_BASE_MIN = 0x1000u,
  ER_TPM_ACPI_TABLE_LENGTH_OFFSET = 4u,
  ER_TPM_RESPONSE_CODE_OFFSET = 6u,
  ER_TPM_RESPONSE_SIZE_OFFSET = 2u,
  ER_TPM_TPM2B_LEN_BYTES = 2u,
  ER_TPM_RANDOM_BYTES_OFFSET = 12u,
  ER_TPM_AUTH_VALUE_LEN = 9u,
  ER_TPM_CREATE_PRIMARY_COMMAND_LEN = 65u,
  ER_TPM_CREATE_PRIMARY_PUBLIC_LEN = 24u,
  ER_TPM_CREATE_PRIMARY_PARAMS_LEN = 38u,
  ER_TPM_EMPTY_SENSITIVE_CREATE_LEN = 4u,
  ER_TPM_EMPTY_SENSITIVE_CREATE_FIELD_LEN = 6u,
  ER_TPM_PUBLIC_AUTH_POLICY_OFFSET = 8u,
  ER_TPM_P256_POINT_BYTES = 32u,
  ER_TPM_P256_PUBLIC_MIN_LEN = 24u,
  ER_TPM_TPMT_PUBLIC_FIXED_LEN = 10u,
  ER_TPM_ECC_PARAMS_LEN = 10u,
  ER_TPM_STARTUP_COMMAND_LEN = 12u,
  ER_TPM_GET_RANDOM_COMMAND_LEN = 12u,
  ER_TPM_READ_PUBLIC_COMMAND_LEN = 14u,
  ER_TPM_SIGN_COMMAND_LEN = 73u,
  ER_TPM_FLUSH_CONTEXT_COMMAND_LEN = 14u,
  ER_TPM_SIGNATURE_MAX_COMPONENT_LEN = 32u,
  ER_TPM_PW_AUTH_AREA_LEN = 9u,
  ER_TPM_START_METHOD_CRB = 6u,
  ER_TPM_START_METHOD_CRB_WITH_ACPI = 7u,
  ER_TPM_START_METHOD_CRB_WITH_SMC = 8u,
  ER_TPM_TPMA_OBJECT_FIXED_TPM = 0x00000002u,
  ER_TPM_TPMA_OBJECT_FIXED_PARENT = 0x00000010u,
  ER_TPM_TPMA_OBJECT_SENSITIVE_DATA_ORIGIN = 0x00000020u,
  ER_TPM_TPMA_OBJECT_USER_WITH_AUTH = 0x00000040u,
  ER_TPM_TPMA_OBJECT_NODA = 0x00000400u,
  ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT = 0x00040000u
};

static UINT16 er_tpm_get_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[ER_TPM_BYTE0_INDEX] | ((UINT16)bytes[ER_TPM_BYTE1_INDEX] << ER_TPM_BYTE_BITS));
}

static UINT32 er_tpm_get_le32(const UINT8* bytes) {
  return (UINT32)((UINT32)bytes[ER_TPM_BYTE0_INDEX] | ((UINT32)bytes[ER_TPM_BYTE1_INDEX] << ER_TPM_BYTE_BITS) |
                  ((UINT32)bytes[ER_TPM_BYTE2_INDEX] << ER_TPM_U32_MID_BITS) |
                  ((UINT32)bytes[ER_TPM_BYTE3_INDEX] << ER_TPM_U32_HIGH_BITS));
}

static UINT64 er_tpm_get_le64(const UINT8* bytes) {
  return (UINT64)er_tpm_get_le32(bytes) |
         ((UINT64)er_tpm_get_le32(bytes + ER_TPM_U64_HIGH_OFFSET) << ER_TPM_U64_HIGH_BITS);
}

static UINT16 er_tpm_get_be16(const UINT8* bytes) {
  return (UINT16)(((UINT16)bytes[ER_TPM_BYTE0_INDEX] << ER_TPM_BYTE_BITS) | (UINT16)bytes[ER_TPM_BYTE1_INDEX]);
}

static UINT32 er_tpm_get_be32(const UINT8* bytes) {
  return (UINT32)(((UINT32)bytes[ER_TPM_BYTE0_INDEX] << ER_TPM_U32_HIGH_BITS) |
                  ((UINT32)bytes[ER_TPM_BYTE1_INDEX] << ER_TPM_U32_MID_BITS) |
                  ((UINT32)bytes[ER_TPM_BYTE2_INDEX] << ER_TPM_BYTE_BITS) | (UINT32)bytes[ER_TPM_BYTE3_INDEX]);
}

static void er_tpm_put_be16(UINT8* dst, UINT16 value) {
  dst[ER_TPM_BYTE0_INDEX] = (UINT8)((value >> ER_TPM_BYTE_BITS) & ER_TPM_BYTE_MASK);
  dst[ER_TPM_BYTE1_INDEX] = (UINT8)(value & ER_TPM_BYTE_MASK);
}

static void er_tpm_put_be32(UINT8* dst, UINT32 value) {
  dst[ER_TPM_BYTE0_INDEX] = (UINT8)((value >> ER_TPM_U32_HIGH_BITS) & ER_TPM_BYTE_MASK);
  dst[ER_TPM_BYTE1_INDEX] = (UINT8)((value >> ER_TPM_U32_MID_BITS) & ER_TPM_BYTE_MASK);
  dst[ER_TPM_BYTE2_INDEX] = (UINT8)((value >> ER_TPM_BYTE_BITS) & ER_TPM_BYTE_MASK);
  dst[ER_TPM_BYTE3_INDEX] = (UINT8)(value & ER_TPM_BYTE_MASK);
}

static void er_tpm_write_empty_auth_area(UINT8* out_command, UINT32* offset) {
  er_tpm_put_be32(out_command + *offset, ER_TPM_RS_PW);
  *offset += ER_TPM_U32_BYTES;
  er_tpm_put_be16(out_command + *offset, 0u);
  *offset += ER_TPM_U16_BYTES;
  out_command[*offset] = 0u;
  *offset += 1u;
  er_tpm_put_be16(out_command + *offset, 0u);
  *offset += ER_TPM_U16_BYTES;
}

static UINT32 er_tpm_mmio_read32(UINT64 address) {
  const volatile UINT32* ptr = (const volatile UINT32*)(UINTN)address;
  return *ptr;
}

static void er_tpm_mmio_write32(UINT64 address, UINT32 value) {
  volatile UINT32* ptr = (volatile UINT32*)(UINTN)address;
  *ptr = value;
}

static UINT64 er_tpm_mmio_read64(UINT64 address) {
  UINT64 low = (UINT64)er_tpm_mmio_read32(address);
  UINT64 high = (UINT64)er_tpm_mmio_read32(address + ER_TPM_U32_BYTES);
  return low | (high << 32u);
}

static void er_tpm_mmio_write_bytes(UINT64 address, const UINT8* bytes, UINT32 len) {
  UINT32 i;
  volatile UINT8* dst = (volatile UINT8*)(UINTN)address;

  for (i = 0u; i < len; ++i) {
    dst[i] = bytes[i];
  }
}

static void er_tpm_mmio_read_bytes(UINT64 address, UINT8* bytes, UINT32 len) {
  UINT32 i;
  const volatile UINT8* src = (const volatile UINT8*)(UINTN)address;

  for (i = 0u; i < len; ++i) {
    bytes[i] = src[i];
  }
}

static UINT8 er_tpm_wait_u32_clear(UINT64 address, UINT32 mask, UINT32 polls) {
  UINT32 i;

  for (i = 0u; i < polls; ++i) {
    if ((er_tpm_mmio_read32(address) & mask) == 0u) {
      return 1;
    }
  }
  return 0;
}

static UINT8 er_tpm_crb_sane(const ErTpmCrbTransport* transport) {
  if (transport == 0 || transport->control_area == 0u ||
      transport->command_buffer < ER_TPM_MMIO_PAGE_BASE_MIN ||
      transport->response_buffer < ER_TPM_MMIO_PAGE_BASE_MIN ||
      transport->command_buffer < transport->control_area ||
      transport->response_buffer < transport->control_area ||
      transport->command_buffer - transport->control_area >= ER_TPM_CRB_MMIO_SPAN_MAX ||
      transport->response_buffer - transport->control_area >= ER_TPM_CRB_MMIO_SPAN_MAX ||
      transport->command_buffer_size < ER_TPM_HEADER_LEN ||
      transport->response_buffer_size < ER_TPM_HEADER_LEN ||
      transport->command_buffer_size > ER_TPM_CRB_MAX_BUFFER_SIZE ||
      transport->response_buffer_size > ER_TPM_CRB_MAX_BUFFER_SIZE ||
      transport->command_buffer + transport->command_buffer_size < transport->command_buffer ||
      transport->response_buffer + transport->response_buffer_size < transport->response_buffer) {
    return 0;
  }
  return 1;
}

UINT8 er_tpm_parse_tpm2_table(UINT64 tpm2_address, ErTpm2Info* out_info) {
  const UINT8* table = (const UINT8*)(UINTN)tpm2_address;
  UINT32 length;

  if (tpm2_address == 0u || out_info == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
  length = er_tpm_get_le32(table + ER_TPM_ACPI_TABLE_LENGTH_OFFSET);
  if (length < ER_TPM_TPM2_MIN_LEN ||
      er_tpm_get_le32(table) != er_acpi_signature("TPM2") ||
      er_acpi_checksum_valid(table, (UINTN)length) == 0u) {
    return 0;
  }

  out_info->found = 1;
  out_info->checksum_valid = 1;
  out_info->platform_class = er_tpm_get_le16(table + ER_TPM_TPM2_PLATFORM_CLASS_OFFSET);
  out_info->control_area = er_tpm_get_le64(table + ER_TPM_TPM2_CONTROL_AREA_OFFSET);
  out_info->start_method = er_tpm_get_le32(table + ER_TPM_TPM2_START_METHOD_OFFSET);
  return 1;
}

UINT8 er_tpm_find_tpm2_table(const ErAcpiTableList* tables, ErTpm2Info* out_info) {
  ErAcpiTableInfo table;

  if (tables == 0 || out_info == 0) {
    return 0;
  }
  if (er_acpi_find_table(tables, er_acpi_signature("TPM2"), &table) == 0u) {
    er_mem_zero((UINT8*)out_info, (UINTN)sizeof(*out_info));
    return 0;
  }
  return er_tpm_parse_tpm2_table(table.address, out_info);
}

UINT8 er_tpm2_info_is_crb(const ErTpm2Info* info) {
  if (info == 0 || info->found == 0u || info->control_area == 0u) {
    return 0;
  }
  switch (info->start_method) {
    case ER_TPM_START_METHOD_CRB:
    case ER_TPM_START_METHOD_CRB_WITH_ACPI:
    case ER_TPM_START_METHOD_CRB_WITH_SMC:
      return 1;
    default:
      return 0;
  }
}

UINT8 er_tpm_crb_from_register_base(UINT64 register_base, ErTpmCrbTransport* out_transport) {
  UINT64 command_buffer;
  UINT64 response_buffer;
  UINT32 command_size;
  UINT32 response_size;

  if (register_base == 0u || out_transport == 0) {
    return 0;
  }

  command_size = er_tpm_mmio_read32(register_base + ER_TPM_CRB_CTRL_CMD_SIZE_OFFSET);
  command_buffer = er_tpm_mmio_read64(register_base + ER_TPM_CRB_CTRL_CMD_ADDR_OFFSET);
  response_size = er_tpm_mmio_read32(register_base + ER_TPM_CRB_CTRL_RSP_SIZE_OFFSET);
  response_buffer = er_tpm_mmio_read64(register_base + ER_TPM_CRB_CTRL_RSP_ADDR_OFFSET);

  if (response_buffer == 0u || response_size == 0u) {
    response_buffer = command_buffer;
    response_size = command_size;
  }

  er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  out_transport->control_area = register_base;
  out_transport->command_buffer = command_buffer;
  out_transport->command_buffer_size = command_size;
  out_transport->response_buffer = response_buffer;
  out_transport->response_buffer_size = response_size;
  out_transport->timeout_polls = ER_TPM_DEFAULT_TIMEOUT_POLLS;
  return er_tpm_crb_sane(out_transport);
}

UINT8 er_tpm_crb_from_tpm2_info(const ErTpm2Info* info, ErTpmCrbTransport* out_transport) {
  UINT64 first_base;
  UINT64 second_base;

  if (er_tpm2_info_is_crb(info) == 0u || out_transport == 0) {
    return 0;
  }

  if ((info->control_area & ER_TPM_MMIO_PAGE_MASK) != 0u &&
      info->control_area < ER_TPM_CRB_CTRL_REQ_OFFSET) {
    return 0;
  }
  first_base = ((info->control_area & ER_TPM_MMIO_PAGE_MASK) == 0u) ?
      info->control_area :
      info->control_area - ER_TPM_CRB_CTRL_REQ_OFFSET;
  if (er_tpm_crb_from_register_base(first_base, out_transport) != 0u) {
    return 1;
  }

  if (((info->control_area & ER_TPM_MMIO_PAGE_MASK) == 0u) &&
      info->control_area < ER_TPM_CRB_CTRL_REQ_OFFSET) {
    return 0;
  }
  second_base = ((info->control_area & ER_TPM_MMIO_PAGE_MASK) == 0u) ?
      info->control_area - ER_TPM_CRB_CTRL_REQ_OFFSET :
      info->control_area;
  return er_tpm_crb_from_register_base(second_base, out_transport);
}

UINT8 er_tpm_crb_transact(ErTpmCrbTransport* transport,
                          const UINT8* command, UINT32 command_len,
                          UINT8* response, UINT32 response_capacity,
                          UINT32* out_response_len) {
  UINT8 header[ER_TPM_HEADER_LEN];
  UINT32 response_len;
  UINT32 polls;
  UINT32 poll_index;
  UINT32 poll_limit;

  if (transport == 0 || command == 0 || response == 0 || out_response_len == 0 ||
      er_tpm_crb_sane(transport) == 0u ||
      command_len < ER_TPM_HEADER_LEN ||
      command_len > transport->command_buffer_size ||
      response_capacity < ER_TPM_HEADER_LEN) {
    return 0;
  }

  polls = transport->timeout_polls;
  er_tpm_mmio_write32(transport->control_area + ER_TPM_CRB_CTRL_REQ_OFFSET,
                      ER_TPM_CRB_CTRL_REQ_CMD_READY);
  if (polls != 0u &&
      er_tpm_wait_u32_clear(transport->control_area + ER_TPM_CRB_CTRL_REQ_OFFSET,
                            ER_TPM_CRB_CTRL_REQ_CMD_READY, polls) == 0u) {
    return 0;
  }

  er_tpm_mmio_write_bytes(transport->command_buffer, command, command_len);
  er_tpm_mmio_write32(transport->control_area + ER_TPM_CRB_CTRL_CANCEL_OFFSET, 0u);
  er_tpm_mmio_write32(transport->control_area + ER_TPM_CRB_CTRL_START_OFFSET,
                      ER_TPM_CRB_CTRL_START);
  if (polls != 0u &&
      er_tpm_wait_u32_clear(transport->control_area + ER_TPM_CRB_CTRL_START_OFFSET,
                            ER_TPM_CRB_CTRL_START, polls) == 0u) {
    return 0;
  }

  poll_limit = polls == 0u ? 1u : polls;
  response_len = 0u;
  for (poll_index = 0u; poll_index < poll_limit; ++poll_index) {
    er_tpm_mmio_read_bytes(transport->response_buffer, header, ER_TPM_HEADER_LEN);
    response_len = er_tpm_get_be32(header + ER_TPM_RESPONSE_SIZE_OFFSET);
    if (response_len >= ER_TPM_HEADER_LEN &&
        response_len <= transport->response_buffer_size &&
        response_len <= response_capacity) {
      break;
    }
  }
  if (response_len < ER_TPM_HEADER_LEN ||
      response_len > transport->response_buffer_size ||
      response_len > response_capacity) {
    return 0;
  }

  er_mem_copy(response, header, ER_TPM_HEADER_LEN);
  er_tpm_mmio_read_bytes(transport->response_buffer + ER_TPM_HEADER_LEN,
                         response + ER_TPM_HEADER_LEN,
                         response_len - ER_TPM_HEADER_LEN);
  *out_response_len = response_len;
  return 1;
}

static UINT8 er_tpm_build_header(UINT16 tag, UINT32 size, UINT32 command_code,
                                 UINT8* out_command, UINT32 command_capacity) {
  if (out_command == 0 || command_capacity < size || size < ER_TPM_HEADER_LEN) {
    return 0;
  }
  er_tpm_put_be16(out_command, tag);
  er_tpm_put_be32(out_command + 2u, size);
  er_tpm_put_be32(out_command + 6u, command_code);
  return 1;
}

UINT8 er_tpm_build_startup_command(UINT16 startup_type,
                                   UINT8* out_command, UINT32 command_capacity,
                                   UINT32* out_command_len) {
  if (out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_STARTUP_COMMAND_LEN, ER_TPM_CC_STARTUP,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be16(out_command + ER_TPM_HEADER_LEN, startup_type);
  *out_command_len = ER_TPM_STARTUP_COMMAND_LEN;
  return 1;
}

UINT8 er_tpm_build_create_primary_p256_signing_command(UINT8* out_command,
                                                       UINT32 command_capacity,
                                                       UINT32* out_command_len) {
  UINT32 offset;
  UINT32 object_attributes;

  if (out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_SESSIONS, ER_TPM_CREATE_PRIMARY_COMMAND_LEN,
                          ER_TPM_CC_CREATE_PRIMARY, out_command, command_capacity) == 0u) {
    return 0;
  }

  object_attributes = ER_TPM_TPMA_OBJECT_FIXED_TPM |
                      ER_TPM_TPMA_OBJECT_FIXED_PARENT |
                      ER_TPM_TPMA_OBJECT_SENSITIVE_DATA_ORIGIN |
                      ER_TPM_TPMA_OBJECT_USER_WITH_AUTH |
                      ER_TPM_TPMA_OBJECT_NODA |
                      ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT;

  offset = ER_TPM_HEADER_LEN;
  er_tpm_put_be32(out_command + offset, ER_TPM_RH_OWNER);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_AUTH_VALUE_LEN);
  offset += ER_TPM_U32_BYTES;
  er_tpm_write_empty_auth_area(out_command, &offset);

  er_tpm_put_be16(out_command + offset, ER_TPM_EMPTY_SENSITIVE_CREATE_LEN);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;

  er_tpm_put_be16(out_command + offset, ER_TPM_CREATE_PRIMARY_PUBLIC_LEN);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_ECC);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_SHA256);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be32(out_command + offset, object_attributes);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_NULL);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_ECDSA);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_SHA256);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ECC_NIST_P256);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_NULL);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;

  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be32(out_command + offset, 0u);
  offset += ER_TPM_U32_BYTES;

  if (offset != ER_TPM_CREATE_PRIMARY_COMMAND_LEN) {
    return 0;
  }
  *out_command_len = offset;
  return 1;
}

UINT8 er_tpm_build_get_random_command(UINT16 bytes_requested,
                                      UINT8* out_command, UINT32 command_capacity,
                                      UINT32* out_command_len) {
  if (out_command_len == 0 || bytes_requested == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_GET_RANDOM_COMMAND_LEN, ER_TPM_CC_GET_RANDOM,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be16(out_command + ER_TPM_HEADER_LEN, bytes_requested);
  *out_command_len = ER_TPM_GET_RANDOM_COMMAND_LEN;
  return 1;
}

UINT8 er_tpm_build_read_public_command(UINT32 handle,
                                       UINT8* out_command, UINT32 command_capacity,
                                       UINT32* out_command_len) {
  if (out_command_len == 0 || handle == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_READ_PUBLIC_COMMAND_LEN, ER_TPM_CC_READ_PUBLIC,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be32(out_command + ER_TPM_HEADER_LEN, handle);
  *out_command_len = ER_TPM_READ_PUBLIC_COMMAND_LEN;
  return 1;
}

UINT8 er_tpm_build_sign_p256_sha256_command(UINT32 handle,
                                            const UINT8 digest[32],
                                            UINT8* out_command,
                                            UINT32 command_capacity,
                                            UINT32* out_command_len) {
  UINT32 offset = 0u;

  if (digest == 0 || out_command_len == 0 || handle == 0u ||
      er_tpm_build_header(ER_TPM_ST_SESSIONS, ER_TPM_SIGN_COMMAND_LEN,
                          ER_TPM_CC_SIGN, out_command, command_capacity) == 0u) {
    return 0;
  }

  offset = ER_TPM_HEADER_LEN;
  er_tpm_put_be32(out_command + offset, handle);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_PW_AUTH_AREA_LEN);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_RS_PW);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  out_command[offset] = 0u;
  offset += 1u;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, 32u);
  offset += ER_TPM_U16_BYTES;
  er_mem_copy(out_command + offset, digest, 32u);
  offset += 32u;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_ECDSA);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_SHA256);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ST_HASHCHECK);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_RH_NULL);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be16(out_command + offset, 0u);
  *out_command_len = ER_TPM_SIGN_COMMAND_LEN;
  return 1;
}

UINT8 er_tpm_build_flush_context_command(UINT32 handle,
                                         UINT8* out_command, UINT32 command_capacity,
                                         UINT32* out_command_len) {
  if (out_command_len == 0 || handle == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_FLUSH_CONTEXT_COMMAND_LEN,
                          ER_TPM_CC_FLUSH_CONTEXT, out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be32(out_command + ER_TPM_HEADER_LEN, handle);
  *out_command_len = ER_TPM_FLUSH_CONTEXT_COMMAND_LEN;
  return 1;
}

UINT32 er_tpm_response_code(const UINT8* response, UINT32 response_len) {
  UINT32 claimed_len;

  if (response == 0 || response_len < ER_TPM_HEADER_LEN) {
    return ER_TPM_RC_METAL_PROTOCOL;
  }
  claimed_len = er_tpm_get_be32(response + ER_TPM_RESPONSE_SIZE_OFFSET);
  if (claimed_len != response_len) {
    return ER_TPM_RC_METAL_PROTOCOL;
  }
  return er_tpm_get_be32(response + ER_TPM_RESPONSE_CODE_OFFSET);
}

UINT8 er_tpm_response_success(const UINT8* response, UINT32 response_len) {
  return (UINT8)(er_tpm_response_code(response, response_len) == ER_TPM_RC_SUCCESS);
}

UINT8 er_tpm_parse_get_random_response(const UINT8* response, UINT32 response_len,
                                       UINT8* out_random, UINT32 random_capacity,
                                       UINT32* out_random_len) {
  UINT32 random_len;

  if (response == 0 || out_random == 0 || out_random_len == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_RANDOM_BYTES_OFFSET) {
    return 0;
  }
  random_len = er_tpm_get_be16(response + ER_TPM_HEADER_LEN);
  if (random_len > random_capacity || ER_TPM_RANDOM_BYTES_OFFSET + random_len > response_len) {
    return 0;
  }
  er_mem_copy(out_random, response + ER_TPM_RANDOM_BYTES_OFFSET, random_len);
  *out_random_len = random_len;
  return 1;
}

static UINT8 er_tpm_read_tpm2b_bounds(const UINT8* bytes, UINT32 len, UINT32* cursor,
                                      const UINT8** out_bytes, UINT32* out_len);

static UINT8 er_tpm_parse_p256_public_area(const UINT8* public_area,
                                           UINT32 public_area_len,
                                           UINT8 out_public_key[ER_TPM_P256_PUBLIC_KEY_LEN]) {
  UINT32 cursor;
  UINT32 auth_policy_len;
  UINT32 x_len;
  UINT32 y_len;
  const UINT8* x;
  const UINT8* y;

  if (public_area == 0 || out_public_key == 0 ||
      public_area_len < ER_TPM_P256_PUBLIC_MIN_LEN ||
      er_tpm_get_be16(public_area) != ER_TPM_ALG_ECC ||
      er_tpm_get_be16(public_area + 2u) != ER_TPM_ALG_SHA256) {
    return 0;
  }

  auth_policy_len = er_tpm_get_be16(public_area + ER_TPM_PUBLIC_AUTH_POLICY_OFFSET);
  if (public_area_len < ER_TPM_TPMT_PUBLIC_FIXED_LEN + auth_policy_len +
      ER_TPM_ECC_PARAMS_LEN + ER_TPM_TPM2B_LEN_BYTES + ER_TPM_TPM2B_LEN_BYTES) {
    return 0;
  }

  cursor = ER_TPM_TPMT_PUBLIC_FIXED_LEN + auth_policy_len;
  if (er_tpm_get_be16(public_area + cursor) != ER_TPM_ALG_NULL ||
      er_tpm_get_be16(public_area + cursor + 2u) != ER_TPM_ALG_ECDSA ||
      er_tpm_get_be16(public_area + cursor + 4u) != ER_TPM_ALG_SHA256 ||
      er_tpm_get_be16(public_area + cursor + 6u) != ER_TPM_ECC_NIST_P256 ||
      er_tpm_get_be16(public_area + cursor + 8u) != ER_TPM_ALG_NULL) {
    return 0;
  }
  cursor += ER_TPM_ECC_PARAMS_LEN;

  if (er_tpm_read_tpm2b_bounds(public_area, public_area_len, &cursor, &x, &x_len) == 0u ||
      er_tpm_read_tpm2b_bounds(public_area, public_area_len, &cursor, &y, &y_len) == 0u ||
      cursor != public_area_len ||
      x_len == 0u || y_len == 0u ||
      x_len > ER_TPM_P256_POINT_BYTES || y_len > ER_TPM_P256_POINT_BYTES) {
    return 0;
  }

  er_mem_zero(out_public_key, ER_TPM_P256_PUBLIC_KEY_LEN);
  er_mem_copy(out_public_key + (ER_TPM_P256_POINT_BYTES - x_len), x, x_len);
  er_mem_copy(out_public_key + ER_TPM_P256_POINT_BYTES +
              (ER_TPM_P256_POINT_BYTES - y_len), y, y_len);
  return 1;
}

UINT8 er_tpm_parse_create_primary_p256_response(const UINT8* response,
                                                UINT32 response_len,
                                                ErTpmP256Primary* out_primary) {
  UINT16 tag;
  UINT32 cursor;
  UINT32 parameter_size;
  UINT32 parameter_end;
  const UINT8* public_area;
  UINT32 public_area_len;

  if (response == 0 || out_primary == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_HEADER_LEN + ER_TPM_U32_BYTES + ER_TPM_TPM2B_LEN_BYTES) {
    return 0;
  }

  er_mem_zero((UINT8*)out_primary, (UINTN)sizeof(*out_primary));
  tag = er_tpm_get_be16(response);
  cursor = ER_TPM_HEADER_LEN;
  out_primary->handle = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;

  parameter_end = response_len;
  if (tag == ER_TPM_ST_SESSIONS && response_len - cursor >= ER_TPM_U32_BYTES) {
    parameter_size = er_tpm_get_be32(response + cursor);
    if (parameter_size <= response_len - cursor - ER_TPM_U32_BYTES) {
      cursor += ER_TPM_U32_BYTES;
      parameter_end = cursor + parameter_size;
    }
  }

  if (er_tpm_read_tpm2b_bounds(response, parameter_end, &cursor,
                               &public_area, &public_area_len) == 0u ||
      out_primary->handle == 0u) {
    return 0;
  }
  return er_tpm_parse_p256_public_area(public_area, public_area_len,
                                       out_primary->public_key);
}

static UINT8 er_tpm_read_tpm2b(const UINT8* bytes, UINT32 len, UINT32* cursor,
                               const UINT8** out_bytes, UINT32* out_len) {
  UINT32 item_len;

  if (bytes == 0 || cursor == 0 || out_bytes == 0 || out_len == 0 ||
      *cursor > len ||
      len - *cursor < ER_TPM_TPM2B_LEN_BYTES) {
    return 0;
  }
  item_len = er_tpm_get_be16(bytes + *cursor);
  *cursor += ER_TPM_TPM2B_LEN_BYTES;
  if (len - *cursor < item_len) {
    return 0;
  }
  *out_bytes = bytes + *cursor;
  *out_len = item_len;
  *cursor += item_len;
  return 1;
}

static UINT8 er_tpm_read_tpm2b_bounds(const UINT8* bytes, UINT32 len, UINT32* cursor,
                                      const UINT8** out_bytes, UINT32* out_len) {
  return er_tpm_read_tpm2b(bytes, len, cursor, out_bytes, out_len);
}

UINT8 er_tpm_parse_p256_sha256_signature_response(const UINT8* response,
                                                  UINT32 response_len,
                                                  UINT8 out_signature[64]) {
  UINT16 tag;
  UINT16 scheme;
  UINT16 hash;
  UINT32 cursor;
  UINT32 parameter_end;
  UINT32 parameter_size;
  const UINT8* r;
  const UINT8* s;
  UINT32 r_len;
  UINT32 s_len;

  if (response == 0 || out_signature == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0;
  }
  tag = er_tpm_get_be16(response);
  cursor = ER_TPM_HEADER_LEN;
  parameter_end = response_len;
  if (tag == ER_TPM_ST_SESSIONS) {
    if (response_len - cursor < ER_TPM_U32_BYTES) {
      return 0;
    }
    parameter_size = er_tpm_get_be32(response + cursor);
    cursor += ER_TPM_U32_BYTES;
    if (parameter_size <= response_len - cursor) {
      parameter_end = cursor + parameter_size;
    }
  }
  if (cursor > parameter_end || parameter_end - cursor < 4u) {
    return 0;
  }
  scheme = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_U16_BYTES;
  hash = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_U16_BYTES;
  if (scheme != ER_TPM_ALG_ECDSA || hash != ER_TPM_ALG_SHA256 ||
      er_tpm_read_tpm2b(response, parameter_end, &cursor, &r, &r_len) == 0u ||
      er_tpm_read_tpm2b(response, parameter_end, &cursor, &s, &s_len) == 0u ||
      r_len > ER_TPM_SIGNATURE_MAX_COMPONENT_LEN ||
      s_len > ER_TPM_SIGNATURE_MAX_COMPONENT_LEN ||
      cursor != parameter_end) {
    return 0;
  }

  er_mem_zero(out_signature, 64u);
  er_mem_copy(out_signature + (32u - r_len), r, r_len);
  er_mem_copy(out_signature + 32u + (32u - s_len), s, s_len);
  return 1;
}

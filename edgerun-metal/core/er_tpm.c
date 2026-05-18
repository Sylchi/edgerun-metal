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
  ER_TPM_U16_BYTES = 2u,
  ER_TPM_U32_BYTES = 4u,
  ER_TPM_U64_HIGH_OFFSET = 4u,
  ER_TPM_BYTE_BITS = 8u,
  ER_TPM_BYTE_MASK = 0xffu,
  ER_TPM_RESPONSE_CODE_OFFSET = 6u,
  ER_TPM_RESPONSE_SIZE_OFFSET = 2u,
  ER_TPM_TPM2B_LEN_BYTES = 2u,
  ER_TPM_RANDOM_BYTES_OFFSET = 12u,
  ER_TPM_SIGN_COMMAND_LEN = 73u,
  ER_TPM_SIGNATURE_MAX_COMPONENT_LEN = 32u
};

static UINT16 er_tpm_get_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << ER_TPM_BYTE_BITS));
}

static UINT32 er_tpm_get_le32(const UINT8* bytes) {
  return (UINT32)((UINT32)bytes[0] | ((UINT32)bytes[1] << ER_TPM_BYTE_BITS) |
                  ((UINT32)bytes[2] << 16u) | ((UINT32)bytes[3] << 24u));
}

static UINT64 er_tpm_get_le64(const UINT8* bytes) {
  return (UINT64)er_tpm_get_le32(bytes) |
         ((UINT64)er_tpm_get_le32(bytes + ER_TPM_U64_HIGH_OFFSET) << 32u);
}

static UINT16 er_tpm_get_be16(const UINT8* bytes) {
  return (UINT16)(((UINT16)bytes[0] << ER_TPM_BYTE_BITS) | (UINT16)bytes[1]);
}

static UINT32 er_tpm_get_be32(const UINT8* bytes) {
  return (UINT32)(((UINT32)bytes[0] << 24u) | ((UINT32)bytes[1] << 16u) |
                  ((UINT32)bytes[2] << ER_TPM_BYTE_BITS) | (UINT32)bytes[3]);
}

static void er_tpm_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> ER_TPM_BYTE_BITS) & ER_TPM_BYTE_MASK);
  dst[1] = (UINT8)(value & ER_TPM_BYTE_MASK);
}

static void er_tpm_put_be32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)((value >> 24u) & ER_TPM_BYTE_MASK);
  dst[1] = (UINT8)((value >> 16u) & ER_TPM_BYTE_MASK);
  dst[2] = (UINT8)((value >> ER_TPM_BYTE_BITS) & ER_TPM_BYTE_MASK);
  dst[3] = (UINT8)(value & ER_TPM_BYTE_MASK);
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
      transport->command_buffer < 0x1000u ||
      transport->response_buffer < 0x1000u ||
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
  length = er_tpm_get_le32(table + 4u);
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
    case 6u:
    case 7u:
    case 8u:
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

  if ((info->control_area & 0xfffu) != 0u &&
      info->control_area < ER_TPM_CRB_CTRL_REQ_OFFSET) {
    return 0;
  }
  first_base = ((info->control_area & 0xfffu) == 0u) ?
      info->control_area :
      info->control_area - ER_TPM_CRB_CTRL_REQ_OFFSET;
  if (er_tpm_crb_from_register_base(first_base, out_transport) != 0u) {
    return 1;
  }

  if (((info->control_area & 0xfffu) == 0u) &&
      info->control_area < ER_TPM_CRB_CTRL_REQ_OFFSET) {
    return 0;
  }
  second_base = ((info->control_area & 0xfffu) == 0u) ?
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
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, 12u, ER_TPM_CC_STARTUP,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be16(out_command + ER_TPM_HEADER_LEN, startup_type);
  *out_command_len = 12u;
  return 1;
}

UINT8 er_tpm_build_get_random_command(UINT16 bytes_requested,
                                      UINT8* out_command, UINT32 command_capacity,
                                      UINT32* out_command_len) {
  if (out_command_len == 0 || bytes_requested == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, 12u, ER_TPM_CC_GET_RANDOM,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be16(out_command + ER_TPM_HEADER_LEN, bytes_requested);
  *out_command_len = 12u;
  return 1;
}

UINT8 er_tpm_build_read_public_command(UINT32 handle,
                                       UINT8* out_command, UINT32 command_capacity,
                                       UINT32* out_command_len) {
  if (out_command_len == 0 || handle == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, 14u, ER_TPM_CC_READ_PUBLIC,
                          out_command, command_capacity) == 0u) {
    return 0;
  }
  er_tpm_put_be32(out_command + ER_TPM_HEADER_LEN, handle);
  *out_command_len = 14u;
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
  er_tpm_put_be32(out_command + offset, 9u);
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

UINT8 er_tpm_parse_p256_sha256_signature_response(const UINT8* response,
                                                  UINT32 response_len,
                                                  UINT8 out_signature[64]) {
  UINT16 tag;
  UINT16 scheme;
  UINT16 hash;
  UINT32 cursor;
  const UINT8* r;
  const UINT8* s;
  UINT32 r_len;
  UINT32 s_len;

  if (response == 0 || out_signature == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0;
  }
  tag = er_tpm_get_be16(response);
  cursor = tag == ER_TPM_ST_SESSIONS ? 14u : ER_TPM_HEADER_LEN;
  if (response_len - cursor < 4u) {
    return 0;
  }
  scheme = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_U16_BYTES;
  hash = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_U16_BYTES;
  if (scheme != ER_TPM_ALG_ECDSA || hash != ER_TPM_ALG_SHA256 ||
      er_tpm_read_tpm2b(response, response_len, &cursor, &r, &r_len) == 0u ||
      er_tpm_read_tpm2b(response, response_len, &cursor, &s, &s_len) == 0u ||
      r_len > ER_TPM_SIGNATURE_MAX_COMPONENT_LEN ||
      s_len > ER_TPM_SIGNATURE_MAX_COMPONENT_LEN ||
      cursor != response_len) {
    return 0;
  }

  er_mem_zero(out_signature, 64u);
  er_mem_copy(out_signature + (32u - r_len), r, r_len);
  er_mem_copy(out_signature + 32u + (32u - s_len), s, s_len);
  return 1;
}

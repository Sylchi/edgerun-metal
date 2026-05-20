#include "er_tpm.h"
#include "er_mem.h"

/*
 * Purpose: implement direct TPM2 CRB command transport and fixed command builders.
 * Intention: keep TPM hardware access explicit, deterministic, and independent of Linux.
 */

enum {
  ER_TPM_SDT_HEADER_LEN = 36u,
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
  ER_TPM_BYTE_BITS = 8u,
  ER_TPM_U32_MID_BITS = 16u,
  ER_TPM_U32_HIGH_BITS = 24u,
  ER_TPM_BYTE_MASK = 0xffu,
  ER_TPM_MMIO_PAGE_MASK = 0xfffu,
  ER_TPM_MMIO_PAGE_BASE_MIN = 0x1000u,
  ER_TPM_COMMAND_SIZE_OFFSET = 2u,
  ER_TPM_COMMAND_CODE_OFFSET = 6u,
  ER_TPM_RESPONSE_CODE_OFFSET = 6u,
  ER_TPM_RESPONSE_SIZE_OFFSET = 2u,
  ER_TPM_TPM2B_LEN_BYTES = 2u,
  ER_TPM_TPM2B_MAX_LEN = 0xffffu,
  ER_TPM_RANDOM_BYTES_OFFSET = 12u,
  ER_TPM_CAPABILITY_RESPONSE_BODY_OFFSET = 11u,
  ER_TPM_TAGGED_PROPERTY_LEN = 8u,
  ER_TPM_TAGGED_ALG_PROPERTY_LEN = 6u,
  ER_TPM_TPMA_CC_COMMAND_INDEX_MASK = 0xffffu,
  ER_TPM_AUTH_VALUE_LEN = 9u,
  ER_TPM_CREATE_PRIMARY_COMMAND_LEN = 65u,
  ER_TPM_CREATE_PRIMARY_PUBLIC_LEN = 24u,
  ER_TPM_CREATE_PRIMARY_PARAMS_LEN = 38u,
  ER_TPM_EMPTY_SENSITIVE_CREATE_LEN = 4u,
  ER_TPM_EMPTY_SENSITIVE_CREATE_FIELD_LEN = 6u,
  ER_TPM_PUBLIC_AUTH_POLICY_OFFSET = 8u,
  ER_TPM_PUBLIC_NAME_ALG_OFFSET = 2u,
  ER_TPM_PUBLIC_SYMMETRIC_OFFSET = 0u,
  ER_TPM_PUBLIC_SCHEME_OFFSET = 2u,
  ER_TPM_PUBLIC_SCHEME_HASH_OFFSET = 4u,
  ER_TPM_PUBLIC_CURVE_ID_OFFSET = 6u,
  ER_TPM_PUBLIC_KDF_OFFSET = 8u,
  ER_TPM_P256_POINT_BYTES = 32u,
  ER_TPM_P256_PUBLIC_MIN_LEN = 24u,
  ER_TPM_TPMT_PUBLIC_FIXED_LEN = 10u,
  ER_TPM_ECC_PARAMS_LEN = 10u,
  ER_TPM_STARTUP_COMMAND_LEN = 12u,
  ER_TPM_GET_CAPABILITY_COMMAND_LEN = 22u,
  ER_TPM_GET_RANDOM_COMMAND_LEN = 12u,
  ER_TPM_READ_PUBLIC_COMMAND_LEN = 14u,
  ER_TPM_SIGN_COMMAND_LEN = 73u,
  ER_TPM_VERIFY_P256_SHA256_COMMAND_LEN = 120u,
  ER_TPM_LOAD_EXTERNAL_P256_COMMAND_LEN = 106u,
  ER_TPM_LOAD_EXTERNAL_PUBLIC_AREA_LEN = 88u,
  ER_TPM_LOAD_EXTERNAL_KEYEDHASH_PUBLIC_AREA_LEN = 46u,
  ER_TPM_LOAD_EXTERNAL_SYMCIPHER_PUBLIC_AREA_LEN = 50u,
  ER_TPM_LOAD_EXTERNAL_KEYEDHASH_FIXED_LEN = 104u,
  ER_TPM_LOAD_EXTERNAL_SYMCIPHER_FIXED_LEN = 108u,
  ER_TPM_ENCRYPT_DECRYPT2_COMMAND_FIXED_LEN = 34u,
  ER_TPM_HASH_COMMAND_FIXED_LEN = 18u,
  ER_TPM_HASH_SEQUENCE_START_COMMAND_LEN = 14u,
  ER_TPM_HMAC_COMMAND_FIXED_LEN = 31u,
  ER_TPM_SEQUENCE_COMPLETE_COMMAND_FIXED_LEN = 33u,
  ER_TPM_SEQUENCE_UPDATE_COMMAND_FIXED_LEN = 29u,
  ER_TPM_ECDH_ZGEN_COMMAND_LEN = 97u,
  ER_TPM_P256_POINT_BODY_LEN = 68u,
  ER_TPM_FLUSH_CONTEXT_COMMAND_LEN = 14u,
  ER_TPM_SIGNATURE_MAX_COMPONENT_LEN = 32u,
  ER_TPM_SIGNATURE_SCHEME_AND_HASH_LEN = 4u,
  ER_TPM_PW_AUTH_AREA_LEN = 9u,
  ER_TPM_START_METHOD_CRB = 6u,
  ER_TPM_START_METHOD_CRB_WITH_ACPI = 7u,
  ER_TPM_START_METHOD_CRB_WITH_SMC = 8u,
  ER_TPM_TPMA_OBJECT_FIXED_TPM = 0x00000002u,
  ER_TPM_TPMA_OBJECT_FIXED_PARENT = 0x00000010u,
  ER_TPM_TPMA_OBJECT_SENSITIVE_DATA_ORIGIN = 0x00000020u,
  ER_TPM_TPMA_OBJECT_USER_WITH_AUTH = 0x00000040u,
  ER_TPM_TPMA_OBJECT_NODA = 0x00000400u,
  ER_TPM_TPMA_OBJECT_DECRYPT = 0x00020000u,
  ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT = 0x00040000u,
  ER_TPM_LOAD_EXTERNAL_KEY_AUTH_LEN = 0u,
  ER_TPM_LOAD_EXTERNAL_KEY_SEED_LEN = ER_TPM_SHA256_DIGEST_LEN,
  ER_TPM_LOAD_EXTERNAL_KEY_UNIQUE_LEN = ER_TPM_SHA256_DIGEST_LEN,
  ER_TPM_LOAD_EXTERNAL_HMAC_SENSITIVE_HEADER_LEN = 8u,
  ER_TPM_LOAD_EXTERNAL_AES_SENSITIVE_HEADER_LEN = 8u
};

typedef struct {
  UINT8* bytes;
  UINT32 len;
  UINT32 offset;
} ErTpmWriter;

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

static void er_tpm_writer_init(ErTpmWriter* writer, UINT8* bytes, UINT32 len) {
  writer->bytes = bytes;
  writer->len = len;
  writer->offset = ER_TPM_HEADER_LEN;
}

static UINT8 er_tpm_writer_put_u8(ErTpmWriter* writer, UINT8 value) {
  if (writer == 0 || writer->bytes == 0 || writer->offset >= writer->len) {
    return 0u;
  }
  writer->bytes[writer->offset] = value;
  writer->offset += 1u;
  return 1u;
}

static UINT8 er_tpm_writer_put_u16(ErTpmWriter* writer, UINT16 value) {
  if (writer == 0 || writer->bytes == 0 ||
      writer->len - writer->offset < ER_TPM_U16_BYTES) {
    return 0u;
  }
  er_tpm_put_be16(writer->bytes + writer->offset, value);
  writer->offset += ER_TPM_U16_BYTES;
  return 1u;
}

static UINT8 er_tpm_writer_put_u32(ErTpmWriter* writer, UINT32 value) {
  if (writer == 0 || writer->bytes == 0 ||
      writer->len - writer->offset < ER_TPM_U32_BYTES) {
    return 0u;
  }
  er_tpm_put_be32(writer->bytes + writer->offset, value);
  writer->offset += ER_TPM_U32_BYTES;
  return 1u;
}

static UINT8 er_tpm_writer_put_bytes(ErTpmWriter* writer,
                                     const UINT8* bytes,
                                     UINT32 len) {
  if (writer == 0 || writer->bytes == 0 || bytes == 0 ||
      writer->len - writer->offset < len) {
    return 0u;
  }
  er_mem_copy(writer->bytes + writer->offset, bytes, len);
  writer->offset += len;
  return 1u;
}

static UINT8 er_tpm_writer_put_empty_auth_area(ErTpmWriter* writer) {
  if (er_tpm_writer_put_u32(writer, ER_TPM_RS_PW) == 0u ||
      er_tpm_writer_put_u16(writer, 0u) == 0u ||
      er_tpm_writer_put_u8(writer, 0u) == 0u ||
      er_tpm_writer_put_u16(writer, 0u) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_put_pw_auth_handle(ErTpmWriter* writer, UINT32 handle) {
  if (er_tpm_writer_put_u32(writer, handle) == 0u ||
      er_tpm_writer_put_u32(writer, ER_TPM_PW_AUTH_AREA_LEN) == 0u ||
      er_tpm_writer_put_empty_auth_area(writer) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_put_tpm2b(ErTpmWriter* writer,
                                     const UINT8* bytes,
                                     UINT16 len) {
  if (er_tpm_writer_put_u16(writer, len) == 0u ||
      er_tpm_writer_put_bytes(writer, bytes, len) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_put_p256_point(ErTpmWriter* writer,
                                          const UINT8 point[ER_TPM_P256_PUBLIC_KEY_LEN]) {
  if (er_tpm_writer_put_tpm2b(writer, point, ER_TPM_P256_POINT_BYTES) == 0u ||
      er_tpm_writer_put_tpm2b(writer, point + ER_TPM_P256_POINT_BYTES,
                              ER_TPM_P256_POINT_BYTES) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_put_load_external_sensitive(ErTpmWriter* writer,
                                                       UINT16 sensitive_area_len,
                                                       UINT16 sensitive_type,
                                                       const UINT8* key,
                                                       UINT16 key_len,
                                                       const UINT8 seed[ER_TPM_SHA256_DIGEST_LEN]) {
  if (er_tpm_writer_put_u16(writer, sensitive_area_len) == 0u ||
      er_tpm_writer_put_u16(writer, sensitive_type) == 0u ||
      er_tpm_writer_put_u16(writer, ER_TPM_LOAD_EXTERNAL_KEY_AUTH_LEN) == 0u ||
      er_tpm_writer_put_tpm2b(writer, seed, ER_TPM_LOAD_EXTERNAL_KEY_SEED_LEN) == 0u ||
      er_tpm_writer_put_tpm2b(writer, key, key_len) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_put_load_external_public_prefix(ErTpmWriter* writer,
                                                          UINT16 public_area_len,
                                                          UINT16 public_type) {
  if (er_tpm_writer_put_u16(writer, public_area_len) == 0u ||
      er_tpm_writer_put_u16(writer, public_type) == 0u ||
      er_tpm_writer_put_u16(writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_u32(writer,
                            ER_TPM_TPMA_OBJECT_USER_WITH_AUTH |
                            ER_TPM_TPMA_OBJECT_DECRYPT |
                            ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT) == 0u ||
      er_tpm_writer_put_u16(writer, 0u) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_tpm_writer_finish(ErTpmWriter* writer, UINT32 expected_len,
                                  UINT32* out_command_len) {
  if (writer == 0 || out_command_len == 0 || writer->offset != expected_len) {
    return 0u;
  }
  *out_command_len = writer->offset;
  return 1u;
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
  if (out_command == 0 || command_capacity < size ||
      size < ER_TPM_HEADER_LEN || size > ER_TPM_CRB_MAX_BUFFER_SIZE) {
    return 0;
  }
  er_tpm_put_be16(out_command, tag);
  er_tpm_put_be32(out_command + ER_TPM_COMMAND_SIZE_OFFSET, size);
  er_tpm_put_be32(out_command + ER_TPM_COMMAND_CODE_OFFSET, command_code);
  return 1;
}

static UINT8 er_tpm_build_create_primary_p256_command(UINT16 scheme,
                                                      UINT32 crypto_attribute,
                                                      UINT8* out_command,
                                                      UINT32 command_capacity,
                                                      UINT32* out_command_len);
static UINT8 er_tpm_symmetric_mode_supported(UINT16 mode);
static UINT8 er_tpm_read_tpm2b_bounds(const UINT8* bytes, UINT32 len, UINT32* cursor,
                                      const UINT8** out_bytes, UINT32* out_len);
static UINT8 er_tpm_response_parameter_window(const UINT8* response,
                                              UINT32 response_len,
                                              UINT32* cursor,
                                              UINT32* parameter_end);

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
  return er_tpm_build_create_primary_p256_command(ER_TPM_ALG_ECDSA,
                                                 ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT,
                                                 out_command, command_capacity,
                                                 out_command_len);
}

UINT8 er_tpm_build_create_primary_p256_ecdh_command(UINT8* out_command,
                                                    UINT32 command_capacity,
                                                    UINT32* out_command_len) {
  return er_tpm_build_create_primary_p256_command(ER_TPM_ALG_ECDH,
                                                 ER_TPM_TPMA_OBJECT_DECRYPT,
                                                 out_command, command_capacity,
                                                 out_command_len);
}

static UINT8 er_tpm_build_create_primary_p256_command(UINT16 scheme,
                                                      UINT32 crypto_attribute,
                                                      UINT8* out_command,
                                                      UINT32 command_capacity,
                                                      UINT32* out_command_len) {
  ErTpmWriter writer;
  UINT32 object_attributes;

  if (scheme != ER_TPM_ALG_ECDSA && scheme != ER_TPM_ALG_ECDH) {
    return 0u;
  }
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
                      crypto_attribute;

  er_tpm_writer_init(&writer, out_command, ER_TPM_CREATE_PRIMARY_COMMAND_LEN);
  if (er_tpm_writer_put_u32(&writer, ER_TPM_RH_OWNER) == 0u ||
      er_tpm_writer_put_u32(&writer, ER_TPM_AUTH_VALUE_LEN) == 0u ||
      er_tpm_writer_put_empty_auth_area(&writer) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_EMPTY_SENSITIVE_CREATE_LEN) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_CREATE_PRIMARY_PUBLIC_LEN) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_ECC) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_u32(&writer, object_attributes) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_NULL) == 0u ||
      er_tpm_writer_put_u16(&writer, scheme) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ECC_NIST_P256) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_NULL) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u32(&writer, 0u) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, ER_TPM_CREATE_PRIMARY_COMMAND_LEN,
                              out_command_len);
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

UINT8 er_tpm_build_hash_sha256_command(const UINT8* data, UINT16 data_len,
                                       UINT32 hierarchy,
                                       UINT8* out_command,
                                       UINT32 command_capacity,
                                       UINT32* out_command_len) {
  ErTpmWriter writer;
  UINT32 command_len;

  if (data == 0 || data_len == 0u || out_command_len == 0) {
    return 0u;
  }
  switch (hierarchy) {
    case ER_TPM_RH_OWNER:
    case ER_TPM_RH_ENDORSEMENT:
    case ER_TPM_RH_PLATFORM:
    case ER_TPM_RH_NULL:
      break;
    default:
      return 0u;
  }
  command_len = ER_TPM_HASH_COMMAND_FIXED_LEN + (UINT32)data_len;
  if (er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, command_len, ER_TPM_CC_HASH,
                          out_command, command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_u16(&writer, data_len) == 0u ||
      er_tpm_writer_put_bytes(&writer, data, data_len) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_u32(&writer, hierarchy) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_hmac_sha256_command(UINT32 handle,
                                       const UINT8* data, UINT16 data_len,
                                       UINT8* out_command,
                                       UINT32 command_capacity,
                                       UINT32* out_command_len) {
  ErTpmWriter writer;
  UINT32 command_len;

  if (handle == 0u || data == 0 || data_len == 0u || out_command_len == 0) {
    return 0u;
  }
  command_len = ER_TPM_HMAC_COMMAND_FIXED_LEN + (UINT32)data_len;
  if (er_tpm_build_header(ER_TPM_ST_SESSIONS, command_len, ER_TPM_CC_HMAC,
                          out_command, command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_u16(&writer, data_len) == 0u ||
      er_tpm_writer_put_bytes(&writer, data, data_len) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_hash_sequence_start_sha256_command(UINT8* out_command,
                                                      UINT32 command_capacity,
                                                      UINT32* out_command_len) {
  ErTpmWriter writer;

  if (out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS,
                          ER_TPM_HASH_SEQUENCE_START_COMMAND_LEN,
                          ER_TPM_CC_HASH_SEQUENCE_START,
                          out_command,
                          command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, ER_TPM_HASH_SEQUENCE_START_COMMAND_LEN);
  if (er_tpm_writer_put_u16(&writer, 0u) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, ER_TPM_HASH_SEQUENCE_START_COMMAND_LEN,
                              out_command_len);
}

UINT8 er_tpm_build_sequence_update_command(UINT32 handle,
                                           const UINT8* data, UINT16 data_len,
                                           UINT8* out_command,
                                           UINT32 command_capacity,
                                           UINT32* out_command_len) {
  UINT32 command_len;
  ErTpmWriter writer;

  if (handle == 0u || data == 0 || data_len == 0u || out_command_len == 0) {
    return 0u;
  }
  command_len = ER_TPM_SEQUENCE_UPDATE_COMMAND_FIXED_LEN + (UINT32)data_len;
  if (er_tpm_build_header(ER_TPM_ST_SESSIONS, command_len,
                          ER_TPM_CC_SEQUENCE_UPDATE, out_command,
                          command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_u16(&writer, data_len) == 0u ||
      er_tpm_writer_put_bytes(&writer, data, data_len) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_sequence_complete_command(UINT32 handle,
                                             const UINT8* data, UINT16 data_len,
                                             UINT32 hierarchy,
                                             UINT8* out_command,
                                             UINT32 command_capacity,
                                             UINT32* out_command_len) {
  UINT32 command_len;
  ErTpmWriter writer;

  if (handle == 0u || data == 0 || data_len == 0u || out_command_len == 0) {
    return 0u;
  }
  switch (hierarchy) {
    case ER_TPM_RH_OWNER:
    case ER_TPM_RH_ENDORSEMENT:
    case ER_TPM_RH_PLATFORM:
    case ER_TPM_RH_NULL:
      break;
    default:
      return 0u;
  }
  command_len = ER_TPM_SEQUENCE_COMPLETE_COMMAND_FIXED_LEN + (UINT32)data_len;
  if (er_tpm_build_header(ER_TPM_ST_SESSIONS, command_len,
                          ER_TPM_CC_SEQUENCE_COMPLETE, out_command,
                          command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_u16(&writer, data_len) == 0u ||
      er_tpm_writer_put_bytes(&writer, data, data_len) == 0u ||
      er_tpm_writer_put_u32(&writer, hierarchy) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_get_capability_command(UINT32 capability, UINT32 property,
                                          UINT32 property_count,
                                          UINT8* out_command,
                                          UINT32 command_capacity,
                                          UINT32* out_command_len) {
  UINT32 offset;

  if (out_command_len == 0 || property_count == 0u ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_GET_CAPABILITY_COMMAND_LEN,
                          ER_TPM_CC_GET_CAPABILITY, out_command, command_capacity) == 0u) {
    return 0;
  }
  offset = ER_TPM_HEADER_LEN;
  er_tpm_put_be32(out_command + offset, capability);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be32(out_command + offset, property);
  offset += ER_TPM_U32_BYTES;
  er_tpm_put_be32(out_command + offset, property_count);
  offset += ER_TPM_U32_BYTES;
  if (offset != ER_TPM_GET_CAPABILITY_COMMAND_LEN) {
    return 0;
  }
  *out_command_len = offset;
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

UINT8 er_tpm_build_load_external_p256_verify_key_command(
    const UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len) {
  UINT32 offset;

  if (public_key == 0 || out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_LOAD_EXTERNAL_P256_COMMAND_LEN,
                          ER_TPM_CC_LOAD_EXTERNAL, out_command, command_capacity) == 0u) {
    return 0u;
  }
  offset = ER_TPM_HEADER_LEN;
  er_tpm_put_be16(out_command + offset, 0u);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_LOAD_EXTERNAL_PUBLIC_AREA_LEN);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_ECC);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_ALG_SHA256);
  offset += ER_TPM_U16_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_TPMA_OBJECT_SIGN_ENCRYPT);
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
  er_tpm_put_be16(out_command + offset, ER_TPM_P256_POINT_BYTES);
  offset += ER_TPM_U16_BYTES;
  er_mem_copy(out_command + offset, public_key, ER_TPM_P256_POINT_BYTES);
  offset += ER_TPM_P256_POINT_BYTES;
  er_tpm_put_be16(out_command + offset, ER_TPM_P256_POINT_BYTES);
  offset += ER_TPM_U16_BYTES;
  er_mem_copy(out_command + offset, public_key + ER_TPM_P256_POINT_BYTES,
              ER_TPM_P256_POINT_BYTES);
  offset += ER_TPM_P256_POINT_BYTES;
  er_tpm_put_be32(out_command + offset, ER_TPM_RH_NULL);
  offset += ER_TPM_U32_BYTES;
  if (offset != ER_TPM_LOAD_EXTERNAL_P256_COMMAND_LEN) {
    return 0u;
  }
  *out_command_len = ER_TPM_LOAD_EXTERNAL_P256_COMMAND_LEN;
  return 1u;
}

UINT8 er_tpm_build_load_external_hmac_sha256_key_command(
    const UINT8* key, UINT16 key_len,
    const UINT8 seed[ER_TPM_SHA256_DIGEST_LEN],
    const UINT8 unique[ER_TPM_SHA256_DIGEST_LEN],
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len) {
  UINT32 command_len;
  ErTpmWriter writer;
  UINT16 sensitive_area_len;

  if (key == 0 || seed == 0 || unique == 0 || key_len == 0u || out_command_len == 0 ||
      key_len > ER_TPM_TPM2B_MAX_LEN - ER_TPM_LOAD_EXTERNAL_HMAC_SENSITIVE_HEADER_LEN -
                  ER_TPM_LOAD_EXTERNAL_KEY_SEED_LEN) {
    return 0u;
  }
  sensitive_area_len = (UINT16)(ER_TPM_LOAD_EXTERNAL_HMAC_SENSITIVE_HEADER_LEN +
                                ER_TPM_LOAD_EXTERNAL_KEY_SEED_LEN + key_len);
  command_len = ER_TPM_LOAD_EXTERNAL_KEYEDHASH_FIXED_LEN + (UINT32)key_len;
  if (er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, command_len,
                          ER_TPM_CC_LOAD_EXTERNAL, out_command,
                          command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_load_external_sensitive(&writer, sensitive_area_len,
                                                ER_TPM_ALG_KEYEDHASH, key,
                                                key_len, seed) == 0u ||
      er_tpm_writer_put_load_external_public_prefix(
          &writer, ER_TPM_LOAD_EXTERNAL_KEYEDHASH_PUBLIC_AREA_LEN,
          ER_TPM_ALG_KEYEDHASH) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_NULL) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, unique,
                              ER_TPM_LOAD_EXTERNAL_KEY_UNIQUE_LEN) == 0u ||
      er_tpm_writer_put_u32(&writer, ER_TPM_RH_NULL) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_load_external_aes_key_command(
    const UINT8* key, UINT16 key_len,
    UINT16 key_bits,
    UINT16 mode,
    const UINT8 seed[ER_TPM_SHA256_DIGEST_LEN],
    const UINT8 unique[ER_TPM_SHA256_DIGEST_LEN],
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len) {
  UINT32 command_len;
  ErTpmWriter writer;
  UINT16 sensitive_area_len;

  if (key == 0 || seed == 0 || unique == 0 || out_command_len == 0) {
    return 0u;
  }
  switch (key_bits) {
    case ER_TPM_AES_128_KEY_BITS:
      if (key_len != ER_TPM_AES_128_KEY_LEN) {
        return 0u;
      }
      break;
    case ER_TPM_AES_256_KEY_BITS:
      if (key_len != ER_TPM_AES_256_KEY_LEN) {
        return 0u;
      }
      break;
    default:
      return 0u;
  }
  if (er_tpm_symmetric_mode_supported(mode) == 0u) {
    return 0u;
  }
  sensitive_area_len = (UINT16)(ER_TPM_LOAD_EXTERNAL_AES_SENSITIVE_HEADER_LEN +
                                ER_TPM_LOAD_EXTERNAL_KEY_SEED_LEN + key_len);
  command_len = ER_TPM_LOAD_EXTERNAL_SYMCIPHER_FIXED_LEN + (UINT32)key_len;
  if (er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, command_len,
                          ER_TPM_CC_LOAD_EXTERNAL, out_command,
                          command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_load_external_sensitive(&writer, sensitive_area_len,
                                                ER_TPM_ALG_SYMCIPHER, key,
                                                key_len, seed) == 0u ||
      er_tpm_writer_put_load_external_public_prefix(
          &writer, ER_TPM_LOAD_EXTERNAL_SYMCIPHER_PUBLIC_AREA_LEN,
          ER_TPM_ALG_SYMCIPHER) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_AES) == 0u ||
      er_tpm_writer_put_u16(&writer, key_bits) == 0u ||
      er_tpm_writer_put_u16(&writer, mode) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, unique,
                              ER_TPM_LOAD_EXTERNAL_KEY_UNIQUE_LEN) == 0u ||
      er_tpm_writer_put_u32(&writer, ER_TPM_RH_NULL) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_sign_p256_sha256_command(UINT32 handle,
                                            const UINT8 digest[32],
                                            UINT8* out_command,
                                            UINT32 command_capacity,
                                            UINT32* out_command_len) {
  ErTpmWriter writer;

  if (digest == 0 || out_command_len == 0 || handle == 0u ||
      er_tpm_build_header(ER_TPM_ST_SESSIONS, ER_TPM_SIGN_COMMAND_LEN,
                          ER_TPM_CC_SIGN, out_command, command_capacity) == 0u) {
    return 0;
  }

  er_tpm_writer_init(&writer, out_command, ER_TPM_SIGN_COMMAND_LEN);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, digest, ER_TPM_SHA256_DIGEST_LEN) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_ECDSA) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ST_HASHCHECK) == 0u ||
      er_tpm_writer_put_u32(&writer, ER_TPM_RH_NULL) == 0u ||
      er_tpm_writer_put_u16(&writer, 0u) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, ER_TPM_SIGN_COMMAND_LEN, out_command_len);
}

UINT8 er_tpm_build_verify_p256_sha256_command(UINT32 handle,
                                              const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                              const UINT8 signature[64],
                                              UINT8* out_command,
                                              UINT32 command_capacity,
                                              UINT32* out_command_len) {
  ErTpmWriter writer;

  if (handle == 0u || digest == 0 || signature == 0 || out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_NO_SESSIONS, ER_TPM_VERIFY_P256_SHA256_COMMAND_LEN,
                          ER_TPM_CC_VERIFY_SIGNATURE, out_command, command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, ER_TPM_VERIFY_P256_SHA256_COMMAND_LEN);
  if (er_tpm_writer_put_u32(&writer, handle) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, digest, ER_TPM_SHA256_DIGEST_LEN) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_ECDSA) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_ALG_SHA256) == 0u ||
      er_tpm_writer_put_p256_point(&writer, signature) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, ER_TPM_VERIFY_P256_SHA256_COMMAND_LEN,
                              out_command_len);
}

UINT8 er_tpm_build_encrypt_decrypt2_command(UINT32 handle,
                                            UINT8 decrypt,
                                            UINT16 mode,
                                            const UINT8* iv, UINT16 iv_len,
                                            const UINT8* input, UINT16 input_len,
                                            UINT8* out_command,
                                            UINT32 command_capacity,
                                            UINT32* out_command_len) {
  ErTpmWriter writer;
  UINT32 command_len;

  if (handle == 0u || out_command_len == 0 ||
      decrypt > 1u ||
      er_tpm_symmetric_mode_supported(mode) == 0u ||
      iv == 0 || iv_len == 0u ||
      input == 0 || input_len == 0u) {
    return 0u;
  }
  command_len = ER_TPM_ENCRYPT_DECRYPT2_COMMAND_FIXED_LEN + (UINT32)iv_len + (UINT32)input_len;
  if (er_tpm_build_header(ER_TPM_ST_SESSIONS, command_len, ER_TPM_CC_ENCRYPT_DECRYPT2,
                          out_command, command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, command_len);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, input, input_len) == 0u ||
      er_tpm_writer_put_u8(&writer, decrypt) == 0u ||
      er_tpm_writer_put_u16(&writer, mode) == 0u ||
      er_tpm_writer_put_tpm2b(&writer, iv, iv_len) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, command_len, out_command_len);
}

UINT8 er_tpm_build_ecdh_zgen_p256_command(UINT32 handle,
                                          const UINT8 peer_public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                                          UINT8* out_command,
                                          UINT32 command_capacity,
                                          UINT32* out_command_len) {
  ErTpmWriter writer;

  if (handle == 0u || peer_public_key == 0 || out_command_len == 0 ||
      er_tpm_build_header(ER_TPM_ST_SESSIONS, ER_TPM_ECDH_ZGEN_COMMAND_LEN,
                          ER_TPM_CC_ECDH_ZGEN, out_command, command_capacity) == 0u) {
    return 0u;
  }
  er_tpm_writer_init(&writer, out_command, ER_TPM_ECDH_ZGEN_COMMAND_LEN);
  if (er_tpm_writer_put_pw_auth_handle(&writer, handle) == 0u ||
      er_tpm_writer_put_u16(&writer, ER_TPM_P256_POINT_BODY_LEN) == 0u ||
      er_tpm_writer_put_p256_point(&writer, peer_public_key) == 0u) {
    return 0u;
  }
  return er_tpm_writer_finish(&writer, ER_TPM_ECDH_ZGEN_COMMAND_LEN,
                              out_command_len);
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

static UINT8 er_tpm_response_parameter_window(const UINT8* response,
                                              UINT32 response_len,
                                              UINT32* cursor,
                                              UINT32* parameter_end) {
  UINT16 tag;
  UINT32 parameter_size;

  if (response == 0 || cursor == 0 || parameter_end == 0 ||
      *cursor > response_len) {
    return 0u;
  }
  tag = er_tpm_get_be16(response);
  *parameter_end = response_len;
  if (tag == ER_TPM_ST_SESSIONS) {
    if (response_len - *cursor < ER_TPM_U32_BYTES) {
      return 0u;
    }
    parameter_size = er_tpm_get_be32(response + *cursor);
    *cursor += ER_TPM_U32_BYTES;
    if (parameter_size > response_len - *cursor) {
      return 0u;
    }
    *parameter_end = *cursor + parameter_size;
  }
  return 1u;
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

UINT8 er_tpm_parse_sha256_digest_response(const UINT8* response, UINT32 response_len,
                                          UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT32 cursor;
  UINT32 parameter_end;
  UINT32 digest_len;

  if (response == 0 || out_digest == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0u;
  }
  cursor = ER_TPM_HEADER_LEN;
  if (er_tpm_response_parameter_window(response, response_len,
                                       &cursor, &parameter_end) == 0u) {
    return 0u;
  }
  if (parameter_end - cursor < ER_TPM_TPM2B_LEN_BYTES) {
    return 0u;
  }
  digest_len = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_TPM2B_LEN_BYTES;
  if (digest_len != ER_TPM_SHA256_DIGEST_LEN ||
      parameter_end - cursor < ER_TPM_SHA256_DIGEST_LEN) {
    return 0u;
  }
  er_mem_copy(out_digest, response + cursor, ER_TPM_SHA256_DIGEST_LEN);
  return 1u;
}

UINT8 er_tpm_parse_handle_response(const UINT8* response, UINT32 response_len,
                                   UINT32* out_handle) {
  if (response == 0 || out_handle == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_HEADER_LEN + ER_TPM_U32_BYTES) {
    return 0u;
  }
  *out_handle = er_tpm_get_be32(response + ER_TPM_HEADER_LEN);
  return (UINT8)(*out_handle != 0u);
}

UINT8 er_tpm_parse_verify_ticket_response(const UINT8* response, UINT32 response_len) {
  UINT32 cursor;
  UINT32 digest_len;

  if (response == 0 || er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_HEADER_LEN + ER_TPM_U16_BYTES + ER_TPM_U32_BYTES +
                     ER_TPM_TPM2B_LEN_BYTES) {
    return 0u;
  }
  cursor = ER_TPM_HEADER_LEN;
  if (er_tpm_get_be16(response + cursor) != ER_TPM_ST_HASHCHECK) {
    return 0u;
  }
  cursor += ER_TPM_U16_BYTES;
  cursor += ER_TPM_U32_BYTES;
  digest_len = er_tpm_get_be16(response + cursor);
  cursor += ER_TPM_TPM2B_LEN_BYTES;
  if (digest_len > response_len - cursor || cursor + digest_len != response_len) {
    return 0u;
  }
  return 1u;
}

UINT8 er_tpm_parse_encrypt_decrypt2_response(const UINT8* response, UINT32 response_len,
                                             UINT8* out_data, UINT32 out_data_capacity,
                                             UINT32* out_data_len,
                                             UINT8* out_iv, UINT32 out_iv_capacity,
                                             UINT32* out_iv_len) {
  UINT32 cursor;
  UINT32 parameter_end;
  const UINT8* data;
  const UINT8* iv;
  UINT32 data_len;
  UINT32 iv_len;

  if (response == 0 || out_data == 0 || out_data_len == 0 ||
      out_iv == 0 || out_iv_len == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0u;
  }
  cursor = ER_TPM_HEADER_LEN;
  if (er_tpm_response_parameter_window(response, response_len,
                                       &cursor, &parameter_end) == 0u) {
    return 0u;
  }
  if (er_tpm_read_tpm2b_bounds(response, parameter_end, &cursor, &data, &data_len) == 0u ||
      er_tpm_read_tpm2b_bounds(response, parameter_end, &cursor, &iv, &iv_len) == 0u ||
      cursor != parameter_end ||
      data_len > out_data_capacity ||
      iv_len > out_iv_capacity) {
    return 0u;
  }
  er_mem_copy(out_data, data, data_len);
  er_mem_copy(out_iv, iv, iv_len);
  *out_data_len = data_len;
  *out_iv_len = iv_len;
  return 1u;
}

UINT8 er_tpm_parse_algorithm_profile_response(const UINT8* response,
                                              UINT32 response_len,
                                              ErTpmAlgorithmProfile* out_profile) {
  UINT32 cursor;
  UINT32 capability;
  UINT32 algorithm_count;
  UINT32 algorithm_index;
  UINT16 algorithm;

  if (response == 0 || out_profile == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_CAPABILITY_RESPONSE_BODY_OFFSET + ER_TPM_U32_BYTES +
                     ER_TPM_U32_BYTES) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_profile, (UINTN)sizeof(*out_profile));
  cursor = ER_TPM_HEADER_LEN;
  cursor += 1u;
  capability = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (capability != ER_TPM_CAP_ALGS) {
    return 0u;
  }
  algorithm_count = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (algorithm_count > (response_len - cursor) / ER_TPM_TAGGED_ALG_PROPERTY_LEN) {
    return 0u;
  }

  for (algorithm_index = 0u; algorithm_index < algorithm_count; ++algorithm_index) {
    algorithm = er_tpm_get_be16(response + cursor);
    cursor += ER_TPM_U16_BYTES;
    cursor += ER_TPM_U32_BYTES;

    switch (algorithm) {
      case ER_TPM_ALG_SHA256:
        out_profile->has_sha256 = 1u;
        break;
      case ER_TPM_ALG_HMAC:
        out_profile->has_hmac = 1u;
        break;
      case ER_TPM_ALG_KEYEDHASH:
        out_profile->has_keyedhash = 1u;
        break;
      case ER_TPM_ALG_ECC:
        out_profile->has_ecc = 1u;
        break;
      case ER_TPM_ALG_ECDH:
        out_profile->has_ecdh = 1u;
        break;
      case ER_TPM_ALG_ECDSA:
        out_profile->has_ecdsa = 1u;
        break;
      case ER_TPM_ALG_AES:
        out_profile->has_aes = 1u;
        break;
      case ER_TPM_ALG_SYMCIPHER:
        out_profile->has_symcipher = 1u;
        break;
      case ER_TPM_ALG_CTR:
        out_profile->has_ctr = 1u;
        break;
      case ER_TPM_ALG_OFB:
        out_profile->has_ofb = 1u;
        break;
      case ER_TPM_ALG_CBC:
        out_profile->has_cbc = 1u;
        break;
      case ER_TPM_ALG_CFB:
        out_profile->has_cfb = 1u;
        break;
      case ER_TPM_ALG_ECB:
        out_profile->has_ecb = 1u;
        break;
      default:
        break;
    }
  }

  return (UINT8)(cursor == response_len);
}

UINT8 er_tpm_parse_command_profile_response(const UINT8* response,
                                            UINT32 response_len,
                                            ErTpmCommandProfile* out_profile) {
  UINT32 cursor;
  UINT32 capability;
  UINT32 command_count;
  UINT32 command_index;
  UINT32 command_attributes;
  UINT32 command_code;

  if (response == 0 || out_profile == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_CAPABILITY_RESPONSE_BODY_OFFSET + ER_TPM_U32_BYTES +
                     ER_TPM_U32_BYTES) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_profile, (UINTN)sizeof(*out_profile));
  cursor = ER_TPM_HEADER_LEN;
  cursor += 1u;
  capability = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (capability != ER_TPM_CAP_COMMANDS) {
    return 0u;
  }
  command_count = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (command_count > (response_len - cursor) / ER_TPM_U32_BYTES) {
    return 0u;
  }

  for (command_index = 0u; command_index < command_count; ++command_index) {
    command_attributes = er_tpm_get_be32(response + cursor);
    cursor += ER_TPM_U32_BYTES;
    command_code = command_attributes & ER_TPM_TPMA_CC_COMMAND_INDEX_MASK;

    switch (command_code) {
      case ER_TPM_CC_CREATE_PRIMARY:
        out_profile->has_create_primary = 1u;
        break;
      case ER_TPM_CC_ECDH_ZGEN:
        out_profile->has_ecdh_zgen = 1u;
        break;
      case ER_TPM_CC_ENCRYPT_DECRYPT2:
        out_profile->has_encrypt_decrypt2 = 1u;
        break;
      case ER_TPM_CC_GET_RANDOM:
        out_profile->has_get_random = 1u;
        break;
      case ER_TPM_CC_HASH:
        out_profile->has_hash = 1u;
        break;
      case ER_TPM_CC_HASH_SEQUENCE_START:
        out_profile->has_hash_sequence_start = 1u;
        break;
      case ER_TPM_CC_HMAC:
        out_profile->has_hmac = 1u;
        break;
      case ER_TPM_CC_LOAD_EXTERNAL:
        out_profile->has_load_external = 1u;
        break;
      case ER_TPM_CC_SEQUENCE_COMPLETE:
        out_profile->has_sequence_complete = 1u;
        break;
      case ER_TPM_CC_SEQUENCE_UPDATE:
        out_profile->has_sequence_update = 1u;
        break;
      case ER_TPM_CC_SIGN:
        out_profile->has_sign = 1u;
        break;
      case ER_TPM_CC_VERIFY_SIGNATURE:
        out_profile->has_verify_signature = 1u;
        break;
      default:
        break;
    }
  }

  return (UINT8)(cursor == response_len);
}

UINT8 er_tpm_tls_compat_profile_supported(const ErTpm2Info* info,
                                          const ErTpmAlgorithmProfile* algorithms,
                                          const ErTpmCommandProfile* commands) {
  UINT16 record_mode;

  if (info == 0 || algorithms == 0 || commands == 0 ||
      info->found == 0u ||
      er_tpm2_info_is_crb(info) == 0u ||
      algorithms->has_sha256 == 0u ||
      algorithms->has_hmac == 0u ||
      algorithms->has_keyedhash == 0u ||
      algorithms->has_ecc == 0u ||
      algorithms->has_ecdh == 0u ||
      algorithms->has_ecdsa == 0u ||
      algorithms->has_aes == 0u ||
      algorithms->has_symcipher == 0u ||
      er_tpm_select_record_cipher_mode(algorithms, &record_mode) == 0u ||
      commands->has_create_primary == 0u ||
      commands->has_ecdh_zgen == 0u ||
      commands->has_encrypt_decrypt2 == 0u ||
      commands->has_get_random == 0u ||
      commands->has_hash == 0u ||
      commands->has_hash_sequence_start == 0u ||
      commands->has_hmac == 0u ||
      commands->has_load_external == 0u ||
      commands->has_sequence_complete == 0u ||
      commands->has_sequence_update == 0u ||
      commands->has_sign == 0u ||
      commands->has_verify_signature == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_tpm_select_record_cipher_mode(const ErTpmAlgorithmProfile* algorithms,
                                       UINT16* out_mode) {
  if (algorithms == 0 || out_mode == 0) {
    return 0u;
  }
  *out_mode = ER_TPM_ALG_NULL;
  if (algorithms->has_ctr != 0u) {
    *out_mode = ER_TPM_ALG_CTR;
    return 1u;
  }
  if (algorithms->has_cfb != 0u) {
    *out_mode = ER_TPM_ALG_CFB;
    return 1u;
  }
  if (algorithms->has_cbc != 0u) {
    *out_mode = ER_TPM_ALG_CBC;
    return 1u;
  }
  return 0u;
}

static UINT8 er_tpm_symmetric_mode_supported(UINT16 mode) {
  switch (mode) {
    case ER_TPM_ALG_CTR:
    case ER_TPM_ALG_OFB:
    case ER_TPM_ALG_CBC:
    case ER_TPM_ALG_CFB:
    case ER_TPM_ALG_ECB:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_tpm_parse_nv_storage_limits_response(const UINT8* response,
                                              UINT32 response_len,
                                              ErTpmNvLimits* out_limits) {
  UINT32 cursor;
  UINT32 capability;
  UINT32 property_count;
  UINT32 property_index;
  UINT32 property;
  UINT32 value;

  if (response == 0 || out_limits == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_CAPABILITY_RESPONSE_BODY_OFFSET + ER_TPM_U32_BYTES + ER_TPM_U32_BYTES) {
    return 0;
  }

  er_mem_zero((UINT8*)out_limits, (UINTN)sizeof(*out_limits));
  cursor = ER_TPM_HEADER_LEN;
  cursor += 1u;
  capability = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (capability != ER_TPM_CAP_TPM_PROPERTIES) {
    return 0;
  }
  property_count = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (property_count > (response_len - cursor) / ER_TPM_TAGGED_PROPERTY_LEN) {
    return 0;
  }

  for (property_index = 0u; property_index < property_count; ++property_index) {
    property = er_tpm_get_be32(response + cursor);
    cursor += ER_TPM_U32_BYTES;
    value = er_tpm_get_be32(response + cursor);
    cursor += ER_TPM_U32_BYTES;

    switch (property) {
      case ER_TPM_PT_NV_INDEX_MAX:
        out_limits->has_nv_index_max = 1u;
        out_limits->nv_index_max = value;
        break;
      case ER_TPM_PT_NV_BUFFER_MAX:
        out_limits->has_nv_buffer_max = 1u;
        out_limits->nv_buffer_max = value;
        break;
      default:
        break;
    }
  }

  if (cursor != response_len ||
      out_limits->has_nv_index_max == 0u ||
      out_limits->has_nv_buffer_max == 0u) {
    return 0;
  }
  return 1;
}

static UINT8 er_tpm_read_tpm2b_bounds(const UINT8* bytes, UINT32 len, UINT32* cursor,
                                      const UINT8** out_bytes, UINT32* out_len);

static UINT8 er_tpm_parse_p256_point_wire(const UINT8* point,
                                          UINT32 point_len,
                                          UINT8 out_public_key[ER_TPM_P256_PUBLIC_KEY_LEN]) {
  UINT32 cursor = 0u;
  UINT32 x_len;
  UINT32 y_len;
  const UINT8* x;
  const UINT8* y;

  if (point == 0 || out_public_key == 0 ||
      er_tpm_read_tpm2b_bounds(point, point_len, &cursor, &x, &x_len) == 0u ||
      er_tpm_read_tpm2b_bounds(point, point_len, &cursor, &y, &y_len) == 0u ||
      cursor != point_len ||
      x_len == 0u || y_len == 0u ||
      x_len > ER_TPM_P256_POINT_BYTES || y_len > ER_TPM_P256_POINT_BYTES) {
    return 0u;
  }

  er_mem_zero(out_public_key, ER_TPM_P256_PUBLIC_KEY_LEN);
  er_mem_copy(out_public_key + (ER_TPM_P256_POINT_BYTES - x_len), x, x_len);
  er_mem_copy(out_public_key + ER_TPM_P256_POINT_BYTES +
              (ER_TPM_P256_POINT_BYTES - y_len), y, y_len);
  return 1u;
}

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
      er_tpm_get_be16(public_area + ER_TPM_PUBLIC_NAME_ALG_OFFSET) != ER_TPM_ALG_SHA256) {
    return 0;
  }

  auth_policy_len = er_tpm_get_be16(public_area + ER_TPM_PUBLIC_AUTH_POLICY_OFFSET);
  if (public_area_len < ER_TPM_TPMT_PUBLIC_FIXED_LEN + auth_policy_len +
      ER_TPM_ECC_PARAMS_LEN + ER_TPM_TPM2B_LEN_BYTES + ER_TPM_TPM2B_LEN_BYTES) {
    return 0;
  }

  cursor = ER_TPM_TPMT_PUBLIC_FIXED_LEN + auth_policy_len;
  if (er_tpm_get_be16(public_area + cursor + ER_TPM_PUBLIC_SYMMETRIC_OFFSET) != ER_TPM_ALG_NULL ||
      er_tpm_get_be16(public_area + cursor + ER_TPM_PUBLIC_SCHEME_OFFSET) != ER_TPM_ALG_ECDSA ||
      er_tpm_get_be16(public_area + cursor + ER_TPM_PUBLIC_SCHEME_HASH_OFFSET) != ER_TPM_ALG_SHA256 ||
      er_tpm_get_be16(public_area + cursor + ER_TPM_PUBLIC_CURVE_ID_OFFSET) != ER_TPM_ECC_NIST_P256 ||
      er_tpm_get_be16(public_area + cursor + ER_TPM_PUBLIC_KDF_OFFSET) != ER_TPM_ALG_NULL) {
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

UINT8 er_tpm_parse_p256_point_response(const UINT8* response, UINT32 response_len,
                                       UINT8 out_public_key[ER_TPM_P256_PUBLIC_KEY_LEN]) {
  UINT32 cursor;
  UINT32 parameter_end;
  const UINT8* point;
  UINT32 point_len;

  if (response == 0 || out_public_key == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0u;
  }
  cursor = ER_TPM_HEADER_LEN;
  if (er_tpm_response_parameter_window(response, response_len,
                                       &cursor, &parameter_end) == 0u) {
    return 0u;
  }
  if (er_tpm_read_tpm2b_bounds(response, parameter_end, &cursor, &point, &point_len) == 0u ||
      cursor != parameter_end) {
    return 0u;
  }
  return er_tpm_parse_p256_point_wire(point, point_len, out_public_key);
}

UINT8 er_tpm_parse_create_primary_p256_response(const UINT8* response,
                                                UINT32 response_len,
                                                ErTpmP256Primary* out_primary) {
  UINT32 cursor;
  UINT32 parameter_end;
  const UINT8* public_area;
  UINT32 public_area_len;

  if (response == 0 || out_primary == 0 ||
      er_tpm_response_success(response, response_len) == 0u ||
      response_len < ER_TPM_HEADER_LEN + ER_TPM_U32_BYTES + ER_TPM_TPM2B_LEN_BYTES) {
    return 0;
  }

  er_mem_zero((UINT8*)out_primary, (UINTN)sizeof(*out_primary));
  cursor = ER_TPM_HEADER_LEN;
  out_primary->handle = er_tpm_get_be32(response + cursor);
  cursor += ER_TPM_U32_BYTES;
  if (er_tpm_response_parameter_window(response, response_len,
                                       &cursor, &parameter_end) == 0u) {
    return 0u;
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
  UINT16 scheme;
  UINT16 hash;
  UINT32 cursor;
  UINT32 parameter_end;
  const UINT8* r;
  const UINT8* s;
  UINT32 r_len;
  UINT32 s_len;

  if (response == 0 || out_signature == 0 ||
      er_tpm_response_success(response, response_len) == 0u) {
    return 0;
  }
  cursor = ER_TPM_HEADER_LEN;
  if (er_tpm_response_parameter_window(response, response_len,
                                       &cursor, &parameter_end) == 0u) {
    return 0u;
  }
  if (cursor > parameter_end || parameter_end - cursor < ER_TPM_SIGNATURE_SCHEME_AND_HASH_LEN) {
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

#include "er_object.h"

#include "er_blake3.h"
#include "er_clock.h"

enum {
  ER_OBJECT_U16_BYTES = 2u,
  ER_OBJECT_U32_BYTES = 4u,
  ER_OBJECT_U64_BYTES = 8u,
  ER_OBJECT_BYTE_SHIFT = 8u,
  ER_OBJECT_U32_BYTE0 = 0u,
  ER_OBJECT_U32_BYTE1 = 1u,
  ER_OBJECT_U32_BYTE2 = 2u,
  ER_OBJECT_U32_BYTE3 = 3u,
  ER_OBJECT_MAGIC_BYTE0 = 0u,
  ER_OBJECT_MAGIC_BYTE1 = 1u,
  ER_OBJECT_MAGIC_BYTE2 = 2u,
  ER_OBJECT_MAGIC_BYTE3 = 3u,
  ER_OBJECT_MAGIC_BYTE4 = 4u,
  ER_OBJECT_MAGIC_BYTE5 = 5u,
  ER_OBJECT_MAGIC_BYTE6 = 6u,
  ER_OBJECT_MAGIC_BYTE7 = 7u,
  ER_OBJECT_HEADER_SIZE = 148u,
  ER_OBJECT_REQUIREMENTS_SIZE = 28u,
  ER_OBJECT_OWNER_SIZE = 36u,
  ER_OBJECT_ENVELOPE_SIZE = 76u,
  ER_OBJECT_CHILD_SIZE = 84u,
  ER_OBJECT_MAGIC0 = 'E',
  ER_OBJECT_MAGIC1 = 'R',
  ER_OBJECT_MAGIC2 = 'O',
  ER_OBJECT_MAGIC3 = 'B',
  ER_OBJECT_MAGIC4 = 'J',
  ER_OBJECT_MAGIC5 = '0',
  ER_OBJECT_MAGIC6 = '0',
  ER_OBJECT_MAGIC7 = '1',
  ER_OBJECT_HEADER_VERSION_OFF = 8u,
  ER_OBJECT_HEADER_KIND_OFF = 10u,
  ER_OBJECT_HEADER_FLAGS_OFF = 12u,
  ER_OBJECT_HEADER_LOGICAL_LEN_OFF = 16u,
  ER_OBJECT_HEADER_OWNER_COUNT_OFF = 24u,
  ER_OBJECT_HEADER_ENVELOPE_COUNT_OFF = 26u,
  ER_OBJECT_HEADER_CHILD_COUNT_OFF = 28u,
  ER_OBJECT_HEADER_BODY_LEN_OFF = 32u,
  ER_OBJECT_HEADER_EPOCH_OFF = 40u,
  ER_OBJECT_HEADER_REQUIREMENTS_OFF = 104u,
  ER_OBJECT_HEADER_RESERVED_OFF = 132u,
  ER_OBJECT_HEADER_RESERVED_SIZE = 16u,
  ER_OBJECT_EPOCH_SIZE = 64u,
  ER_OBJECT_EPOCH_KEEPER_ID_OFF = 0u,
  ER_OBJECT_EPOCH_TICK_OFF = 32u,
  ER_OBJECT_EPOCH_SLOT_OFF = 40u,
  ER_OBJECT_EPOCH_EPOCH_OFF = 48u,
  ER_OBJECT_EPOCH_ERA_OFF = 56u,
  ER_OBJECT_REQUIREMENTS_DURABILITY_OFF = 0u,
  ER_OBJECT_REQUIREMENTS_CONFIDENTIALITY_OFF = 4u,
  ER_OBJECT_REQUIREMENTS_PORTABILITY_OFF = 8u,
  ER_OBJECT_REQUIREMENTS_INTEGRITY_OFF = 12u,
  ER_OBJECT_REQUIREMENTS_LIFETIME_OFF = 16u,
  ER_OBJECT_REQUIREMENTS_VISIBILITY_OFF = 20u,
  ER_OBJECT_REQUIREMENTS_ACCESS_COST_OFF = 24u,
  ER_OBJECT_ENVELOPE_KIND_OFF = 0u,
  ER_OBJECT_ENVELOPE_OWNER_INDEX_OFF = 4u,
  ER_OBJECT_ENVELOPE_ALGORITHM_OFF = 6u,
  ER_OBJECT_ENVELOPE_FLAGS_OFF = 8u,
  ER_OBJECT_ENVELOPE_KEY_ID_OFF = 12u,
  ER_OBJECT_ENVELOPE_METADATA_HASH_OFF = 44u,
  ER_OBJECT_CHILD_OBJECT_ID_OFF = 0u,
  ER_OBJECT_CHILD_LOGICAL_OFFSET_OFF = 32u,
  ER_OBJECT_CHILD_LOGICAL_LEN_OFF = 40u,
  ER_OBJECT_CHILD_KIND_OFF = 48u,
  ER_OBJECT_CHILD_RESERVED_OFF = 50u,
  ER_OBJECT_CHILD_REQUIREMENTS_HASH_OFF = 52u,
  ER_SIZE_MAX_U64 = 0xffffffffffffffffull
};

static void er_object_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static void er_object_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

//@optimizer-ignore-function canonical identifiers are fixed-size protocol byte arrays
static int er_object_bytes_nonzero(const uint8_t* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (bytes[i] != 0u) {
      return 1;
    }
  }
  return 0;
}

//@optimizer-ignore-function canonical identifiers are fixed-size protocol byte arrays
static int er_object_bytes_zero(const uint8_t* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (bytes[i] != 0u) {
      return 0;
    }
  }
  return 1;
}

static void er_object_store16(uint8_t* out, uint16_t value) {
  out[ER_OBJECT_U32_BYTE0] = (uint8_t)value;
  out[ER_OBJECT_U32_BYTE1] = (uint8_t)(value >> ER_OBJECT_BYTE_SHIFT);
}

static void er_object_store32(uint8_t* out, uint32_t value) {
  out[ER_OBJECT_U32_BYTE0] = (uint8_t)value;
  out[ER_OBJECT_U32_BYTE1] = (uint8_t)(value >> ER_OBJECT_BYTE_SHIFT);
  out[ER_OBJECT_U32_BYTE2] = (uint8_t)(value >> (ER_OBJECT_BYTE_SHIFT * ER_OBJECT_U16_BYTES));
  out[ER_OBJECT_U32_BYTE3] = (uint8_t)(value >> (ER_OBJECT_BYTE_SHIFT * ER_OBJECT_U32_BYTE3));
}

static void er_object_store64(uint8_t* out, uint64_t value) {
  er_object_store32(out, (uint32_t)value);
  er_object_store32(&out[ER_OBJECT_U32_BYTES], (uint32_t)(value >> 32u));
}

static uint16_t er_object_load16(const uint8_t* in) {
  return (uint16_t)((uint16_t)in[ER_OBJECT_U32_BYTE0] |
                    ((uint16_t)in[ER_OBJECT_U32_BYTE1] << ER_OBJECT_BYTE_SHIFT));
}

static uint32_t er_object_load32(const uint8_t* in) {
  return (uint32_t)in[ER_OBJECT_U32_BYTE0] |
         ((uint32_t)in[ER_OBJECT_U32_BYTE1] << ER_OBJECT_BYTE_SHIFT) |
         ((uint32_t)in[ER_OBJECT_U32_BYTE2] << (ER_OBJECT_BYTE_SHIFT * ER_OBJECT_U16_BYTES)) |
         ((uint32_t)in[ER_OBJECT_U32_BYTE3] << (ER_OBJECT_BYTE_SHIFT * ER_OBJECT_U32_BYTE3));
}

static uint64_t er_object_load64(const uint8_t* in) {
  return (uint64_t)er_object_load32(in) |
         ((uint64_t)er_object_load32(&in[ER_OBJECT_U32_BYTES]) << (ER_OBJECT_BYTE_SHIFT * ER_OBJECT_U32_BYTES));
}

static void er_object_epoch_write(er_clock_epoch_stamp_t epoch,
                                  uint8_t out[ER_OBJECT_EPOCH_SIZE]) {
  er_object_copy(&out[ER_OBJECT_EPOCH_KEEPER_ID_OFF],
                 epoch.keeper_id.bytes,
                 ER_CLOCK_KEEPER_ID_SIZE);
  er_object_store64(&out[ER_OBJECT_EPOCH_TICK_OFF], epoch.tick);
  er_object_store64(&out[ER_OBJECT_EPOCH_SLOT_OFF], epoch.slot);
  er_object_store64(&out[ER_OBJECT_EPOCH_EPOCH_OFF], epoch.epoch);
  er_object_store64(&out[ER_OBJECT_EPOCH_ERA_OFF], epoch.era);
}

static er_clock_epoch_stamp_t er_object_epoch_read(const uint8_t in[ER_OBJECT_EPOCH_SIZE]) {
  er_clock_epoch_stamp_t epoch;

  er_object_copy(epoch.keeper_id.bytes,
                 &in[ER_OBJECT_EPOCH_KEEPER_ID_OFF],
                 ER_CLOCK_KEEPER_ID_SIZE);
  epoch.tick = er_object_load64(&in[ER_OBJECT_EPOCH_TICK_OFF]);
  epoch.slot = er_object_load64(&in[ER_OBJECT_EPOCH_SLOT_OFF]);
  epoch.epoch = er_object_load64(&in[ER_OBJECT_EPOCH_EPOCH_OFF]);
  epoch.era = er_object_load64(&in[ER_OBJECT_EPOCH_ERA_OFF]);
  return epoch;
}

static int er_object_add_size(size_t a, size_t b, size_t* out) {
  if (out == (size_t*)0 || a > ((size_t)-1) - b) {
    return ER_OBJECT_ERR_TOOBIG;
  }
  *out = a + b;
  return ER_OBJECT_OK;
}

static int er_object_mul_size(size_t a, size_t b, size_t* out) {
  if (out == (size_t*)0 || (a != 0u && b > ((size_t)-1) / a)) {
    return ER_OBJECT_ERR_TOOBIG;
  }
  *out = a * b;
  return ER_OBJECT_OK;
}

static int er_object_kind_valid(uint16_t node_kind) {
  switch (node_kind) {
    case ER_OBJECT_KIND_BYTES:
    case ER_OBJECT_KIND_TREE:
    case ER_OBJECT_KIND_RECEIPT:
      return 1;
    default:
      return 0;
  }
}

static int er_object_owner_kind_valid(uint32_t owner_kind) {
  switch (owner_kind) {
    case ER_OBJECT_OWNER_DEVICE:
    case ER_OBJECT_OWNER_STORAGE:
    case ER_OBJECT_OWNER_APP:
    case ER_OBJECT_OWNER_USER:
      return 1;
    default:
      return 0;
  }
}

static int er_object_envelope_kind_valid(uint32_t envelope_kind) {
  switch (envelope_kind) {
    case ER_OBJECT_ENVELOPE_NONE:
    case ER_OBJECT_ENVELOPE_DEVICE:
    case ER_OBJECT_ENVELOPE_STORAGE:
    case ER_OBJECT_ENVELOPE_APP:
    case ER_OBJECT_ENVELOPE_USER:
    case ER_OBJECT_ENVELOPE_SIGNATURE:
      return 1;
    default:
      return 0;
  }
}

static int er_object_algorithm_valid(uint16_t algorithm) {
  switch (algorithm) {
    case ER_OBJECT_ALGORITHM_NONE:
    case ER_OBJECT_ALGORITHM_BLAKE3:
    case ER_OBJECT_ALGORITHM_AES_GCM_256:
    case ER_OBJECT_ALGORITHM_XCHACHA20_POLY1305:
    case ER_OBJECT_ALGORITHM_ED25519:
      return 1;
    default:
      return 0;
  }
}

static int er_object_envelope_owner_matches(uint32_t envelope_kind,
                                            uint32_t owner_kind) {
  switch (envelope_kind) {
    case ER_OBJECT_ENVELOPE_NONE:
    case ER_OBJECT_ENVELOPE_SIGNATURE:
      return 1;
    case ER_OBJECT_ENVELOPE_DEVICE:
      return owner_kind == ER_OBJECT_OWNER_DEVICE;
    case ER_OBJECT_ENVELOPE_STORAGE:
      return owner_kind == ER_OBJECT_OWNER_STORAGE;
    case ER_OBJECT_ENVELOPE_APP:
      return owner_kind == ER_OBJECT_OWNER_APP;
    case ER_OBJECT_ENVELOPE_USER:
      return owner_kind == ER_OBJECT_OWNER_USER;
    default:
      return 0;
  }
}

static int er_object_envelope_algorithm_matches(uint32_t envelope_kind,
                                                uint16_t algorithm) {
  switch (envelope_kind) {
    case ER_OBJECT_ENVELOPE_NONE:
      return algorithm == ER_OBJECT_ALGORITHM_NONE;
    case ER_OBJECT_ENVELOPE_SIGNATURE:
      return algorithm == ER_OBJECT_ALGORITHM_ED25519;
    case ER_OBJECT_ENVELOPE_DEVICE:
    case ER_OBJECT_ENVELOPE_STORAGE:
    case ER_OBJECT_ENVELOPE_APP:
    case ER_OBJECT_ENVELOPE_USER:
      return algorithm == ER_OBJECT_ALGORITHM_AES_GCM_256 ||
             algorithm == ER_OBJECT_ALGORITHM_XCHACHA20_POLY1305;
    default:
      return 0;
  }
}

static int er_object_envelope_valid(uint32_t envelope_kind,
                                    uint32_t owner_kind,
                                    uint16_t algorithm,
                                    const uint8_t key_id[ER_OBJECT_ID_SIZE],
                                    const uint8_t metadata_hash[ER_OBJECT_ID_SIZE]) {
  if (er_object_envelope_kind_valid(envelope_kind) == 0 ||
      er_object_algorithm_valid(algorithm) == 0 ||
      er_object_envelope_owner_matches(envelope_kind, owner_kind) == 0 ||
      er_object_envelope_algorithm_matches(envelope_kind, algorithm) == 0) {
    return 0;
  }
  if (envelope_kind == ER_OBJECT_ENVELOPE_NONE) {
    return er_object_bytes_zero(key_id, ER_OBJECT_ID_SIZE) != 0 &&
           er_object_bytes_zero(metadata_hash, ER_OBJECT_ID_SIZE) != 0;
  }
  return er_object_bytes_nonzero(key_id, ER_OBJECT_ID_SIZE) != 0 &&
         er_object_bytes_nonzero(metadata_hash, ER_OBJECT_ID_SIZE) != 0;
}

static int er_object_requirements_write(const er_object_requirements_t* requirements,
                                        uint8_t out[ER_OBJECT_REQUIREMENTS_SIZE]) {
  if (er_object_requirements_valid(requirements) == 0) {
    return ER_OBJECT_ERR_BADARG;
  }
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_DURABILITY_OFF], requirements->durability);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_CONFIDENTIALITY_OFF], requirements->confidentiality);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_PORTABILITY_OFF], requirements->portability);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_INTEGRITY_OFF], requirements->integrity);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_LIFETIME_OFF], requirements->lifetime);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_VISIBILITY_OFF], requirements->visibility);
  er_object_store32(&out[ER_OBJECT_REQUIREMENTS_ACCESS_COST_OFF], requirements->access_cost);
  return ER_OBJECT_OK;
}

static void er_object_requirements_read(const uint8_t in[ER_OBJECT_REQUIREMENTS_SIZE],
                                        er_object_requirements_t* out) {
  out->durability = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_DURABILITY_OFF]);
  out->confidentiality = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_CONFIDENTIALITY_OFF]);
  out->portability = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_PORTABILITY_OFF]);
  out->integrity = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_INTEGRITY_OFF]);
  out->lifetime = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_LIFETIME_OFF]);
  out->visibility = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_VISIBILITY_OFF]);
  out->access_cost = er_object_load32(&in[ER_OBJECT_REQUIREMENTS_ACCESS_COST_OFF]);
}

int er_object_requirements_valid(const er_object_requirements_t* requirements) {
  if (requirements == (const er_object_requirements_t*)0) {
    return 0;
  }
  switch (requirements->durability) {
    case ER_OBJECT_DURABILITY_MEMORY:
    case ER_OBJECT_DURABILITY_DURABLE:
    case ER_OBJECT_DURABILITY_REPLICATED:
      break;
    default:
      return 0;
  }
  switch (requirements->confidentiality) {
    case ER_OBJECT_CONFIDENTIALITY_PUBLIC:
    case ER_OBJECT_CONFIDENTIALITY_INTEGRITY_ONLY:
    case ER_OBJECT_CONFIDENTIALITY_APP_PRIVATE:
    case ER_OBJECT_CONFIDENTIALITY_USER_PRIVATE:
    case ER_OBJECT_CONFIDENTIALITY_USER_APP_PRIVATE:
    case ER_OBJECT_CONFIDENTIALITY_DEVICE_PRIVATE:
    case ER_OBJECT_CONFIDENTIALITY_LAYERED:
      break;
    default:
      return 0;
  }
  switch (requirements->portability) {
    case ER_OBJECT_PORTABILITY_MACHINE_BOUND:
    case ER_OBJECT_PORTABILITY_USER_PORTABLE:
    case ER_OBJECT_PORTABILITY_APP_PORTABLE:
    case ER_OBJECT_PORTABILITY_PUBLIC_PORTABLE:
      break;
    default:
      return 0;
  }
  switch (requirements->integrity) {
    case ER_OBJECT_INTEGRITY_HASH_ONLY:
    case ER_OBJECT_INTEGRITY_SIGNED:
    case ER_OBJECT_INTEGRITY_SEALED:
      break;
    default:
      return 0;
  }
  switch (requirements->lifetime) {
    case ER_OBJECT_LIFETIME_TRANSIENT:
    case ER_OBJECT_LIFETIME_SESSION:
    case ER_OBJECT_LIFETIME_CACHE:
    case ER_OBJECT_LIFETIME_RETAINED:
    case ER_OBJECT_LIFETIME_PINNED:
      break;
    default:
      return 0;
  }
  switch (requirements->visibility) {
    case ER_OBJECT_VISIBILITY_PRIVATE:
    case ER_OBJECT_VISIBILITY_APP_NAMESPACE:
    case ER_OBJECT_VISIBILITY_USER_NAMESPACE:
    case ER_OBJECT_VISIBILITY_PUBLIC:
      break;
    default:
      return 0;
  }
  switch (requirements->access_cost) {
    case ER_OBJECT_ACCESS_EXPLICIT_IO:
    case ER_OBJECT_ACCESS_HOT_MEMORY_ALLOWED:
      return 1;
    default:
      return 0;
  }
}

int er_object_requirements_hash(const er_object_requirements_t* requirements,
                                uint8_t out_hash[ER_OBJECT_ID_SIZE]) {
  uint8_t bytes[ER_OBJECT_REQUIREMENTS_SIZE];

  if (out_hash == (uint8_t*)0 ||
      er_object_requirements_write(requirements, bytes) != ER_OBJECT_OK) {
    return ER_OBJECT_ERR_BADARG;
  }
  return er_blake3_hash_bytes(bytes, sizeof(bytes), out_hash) != 0u
             ? ER_OBJECT_OK
             : ER_OBJECT_ERR_CORRUPT;
}

int er_object_canonical_size(uint16_t node_kind, size_t body_len,
                             uint16_t owner_count, uint16_t envelope_count,
                             uint32_t child_count, size_t* out_len) {
  size_t total = ER_OBJECT_HEADER_SIZE;
  size_t bytes;

  if (out_len == (size_t*)0 || er_object_kind_valid(node_kind) == 0 ||
      owner_count > ER_OBJECT_MAX_OWNERS ||
      envelope_count > ER_OBJECT_MAX_ENVELOPES ||
      child_count > ER_OBJECT_MAX_CHILDREN ||
      ((node_kind == ER_OBJECT_KIND_BYTES || node_kind == ER_OBJECT_KIND_RECEIPT) &&
       child_count != 0u) ||
      (node_kind == ER_OBJECT_KIND_TREE && body_len != 0u)) {
    return ER_OBJECT_ERR_BADARG;
  }
  if (er_object_mul_size((size_t)owner_count, ER_OBJECT_OWNER_SIZE, &bytes) != ER_OBJECT_OK ||
      er_object_add_size(total, bytes, &total) != ER_OBJECT_OK ||
      er_object_mul_size((size_t)envelope_count, ER_OBJECT_ENVELOPE_SIZE, &bytes) != ER_OBJECT_OK ||
      er_object_add_size(total, bytes, &total) != ER_OBJECT_OK ||
      er_object_mul_size((size_t)child_count, ER_OBJECT_CHILD_SIZE, &bytes) != ER_OBJECT_OK ||
      er_object_add_size(total, bytes, &total) != ER_OBJECT_OK ||
      er_object_add_size(total, body_len, &total) != ER_OBJECT_OK) {
    return ER_OBJECT_ERR_TOOBIG;
  }
  *out_len = total;
  return ER_OBJECT_OK;
}

int er_object_id(const void* canonical, size_t len,
                 uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  if (canonical == (const void*)0 || out_id == (uint8_t*)0 || len == 0u) {
    return ER_OBJECT_ERR_BADARG;
  }
  return er_blake3_hash_bytes((const uint8_t*)canonical, len, out_id) != 0u
             ? ER_OBJECT_OK
             : ER_OBJECT_ERR_CORRUPT;
}

int er_object_build_node(uint16_t node_kind, uint32_t flags,
                         const er_object_requirements_t* requirements,
                         er_clock_epoch_stamp_t epoch,
                         const er_object_owner_t* owners, uint16_t owner_count,
                         const er_object_envelope_t* envelopes, uint16_t envelope_count,
                         const er_object_child_ref_t* children, uint32_t child_count,
                         const void* body, size_t body_len,
                         void* out, size_t out_cap, size_t* out_len,
                         uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  uint8_t* bytes = (uint8_t*)out;
  uint8_t* cursor;
  size_t total;
  uint64_t logical_len = 0u; //@optimizer-ignore canonical object lengths are 64-bit fields
  uint32_t i;

  if (out == (void*)0 || out_len == (size_t*)0 ||
      out_id == (uint8_t*)0 ||
      er_clock_stamp_valid(epoch) == 0 ||
      (owner_count != 0u && owners == (const er_object_owner_t*)0) ||
      (envelope_count != 0u && envelopes == (const er_object_envelope_t*)0) ||
      (child_count != 0u && children == (const er_object_child_ref_t*)0) ||
      (body_len != 0u && body == (const void*)0)) {
    return ER_OBJECT_ERR_BADARG;
  }
  {
    int size_status = er_object_canonical_size(node_kind, body_len, owner_count,
                                               envelope_count, child_count, &total);
    if (size_status != ER_OBJECT_OK) {
      return size_status;
    }
  }
  if (total > out_cap) {
    return ER_OBJECT_ERR_TOOBIG;
  }
  er_object_zero(out, total);
  bytes[ER_OBJECT_MAGIC_BYTE0] = ER_OBJECT_MAGIC0;
  bytes[ER_OBJECT_MAGIC_BYTE1] = ER_OBJECT_MAGIC1;
  bytes[ER_OBJECT_MAGIC_BYTE2] = ER_OBJECT_MAGIC2;
  bytes[ER_OBJECT_MAGIC_BYTE3] = ER_OBJECT_MAGIC3;
  bytes[ER_OBJECT_MAGIC_BYTE4] = ER_OBJECT_MAGIC4;
  bytes[ER_OBJECT_MAGIC_BYTE5] = ER_OBJECT_MAGIC5;
  bytes[ER_OBJECT_MAGIC_BYTE6] = ER_OBJECT_MAGIC6;
  bytes[ER_OBJECT_MAGIC_BYTE7] = ER_OBJECT_MAGIC7;
  er_object_store16(&bytes[ER_OBJECT_HEADER_VERSION_OFF], ER_OBJECT_ABI_VERSION);
  er_object_store16(&bytes[ER_OBJECT_HEADER_KIND_OFF], node_kind);
  er_object_store32(&bytes[ER_OBJECT_HEADER_FLAGS_OFF], flags);
  if (node_kind == ER_OBJECT_KIND_BYTES || node_kind == ER_OBJECT_KIND_RECEIPT) {
    logical_len = (uint64_t)body_len;
    if ((size_t)logical_len != body_len) {
      return ER_OBJECT_ERR_TOOBIG;
    }
  }
  er_object_store64(&bytes[ER_OBJECT_HEADER_LOGICAL_LEN_OFF], logical_len);
  er_object_store16(&bytes[ER_OBJECT_HEADER_OWNER_COUNT_OFF], owner_count);
  er_object_store16(&bytes[ER_OBJECT_HEADER_ENVELOPE_COUNT_OFF], envelope_count);
  er_object_store32(&bytes[ER_OBJECT_HEADER_CHILD_COUNT_OFF], child_count);
  er_object_store64(&bytes[ER_OBJECT_HEADER_BODY_LEN_OFF], (uint64_t)body_len);
  er_object_epoch_write(epoch, &bytes[ER_OBJECT_HEADER_EPOCH_OFF]);
  if ((size_t)(uint64_t)body_len != body_len ||
      er_object_requirements_write(requirements, &bytes[ER_OBJECT_HEADER_REQUIREMENTS_OFF]) != ER_OBJECT_OK) {
    return ER_OBJECT_ERR_BADARG;
  }
  er_object_zero(&bytes[ER_OBJECT_HEADER_RESERVED_OFF], ER_OBJECT_HEADER_RESERVED_SIZE);
  cursor = &bytes[ER_OBJECT_HEADER_SIZE];
  for (i = 0u; i < owner_count; ++i) {
    if (er_object_owner_kind_valid(owners[i].owner_kind) == 0 ||
        er_object_bytes_nonzero(owners[i].node_id, ER_OBJECT_ID_SIZE) == 0) {
      return ER_OBJECT_ERR_BADARG;
    }
    er_object_store32(cursor, owners[i].owner_kind);
    er_object_copy(&cursor[ER_OBJECT_U32_BYTES], owners[i].node_id, ER_OBJECT_ID_SIZE);
    cursor += ER_OBJECT_OWNER_SIZE;
  }
  for (i = 0u; i < envelope_count; ++i) {
    if (envelopes[i].owner_index >= owner_count ||
        er_object_envelope_valid(envelopes[i].envelope_kind,
                                 owners[envelopes[i].owner_index].owner_kind,
                                 envelopes[i].algorithm,
                                 envelopes[i].key_id,
                                 envelopes[i].metadata_hash) == 0) {
      return ER_OBJECT_ERR_BADARG;
    }
    er_object_store32(&cursor[ER_OBJECT_ENVELOPE_KIND_OFF], envelopes[i].envelope_kind);
    er_object_store16(&cursor[ER_OBJECT_ENVELOPE_OWNER_INDEX_OFF], envelopes[i].owner_index);
    er_object_store16(&cursor[ER_OBJECT_ENVELOPE_ALGORITHM_OFF], envelopes[i].algorithm);
    er_object_store32(&cursor[ER_OBJECT_ENVELOPE_FLAGS_OFF], envelopes[i].flags);
    er_object_copy(&cursor[ER_OBJECT_ENVELOPE_KEY_ID_OFF],
                   envelopes[i].key_id,
                   ER_OBJECT_ID_SIZE);
    er_object_copy(&cursor[ER_OBJECT_ENVELOPE_METADATA_HASH_OFF],
                   envelopes[i].metadata_hash,
                   ER_OBJECT_ID_SIZE);
    cursor += ER_OBJECT_ENVELOPE_SIZE;
  }
  for (i = 0u; i < child_count; ++i) {
    if (children[i].logical_offset != logical_len ||
        children[i].logical_len > ER_SIZE_MAX_U64 - logical_len) {
      return ER_OBJECT_ERR_BADARG;
    }
    if (er_object_kind_valid(children[i].node_kind) == 0 ||
        children[i].reserved != 0u ||
        children[i].logical_len == 0u ||
        er_object_bytes_nonzero(children[i].object_id, ER_OBJECT_ID_SIZE) == 0 ||
        er_object_bytes_nonzero(children[i].requirements_hash, ER_OBJECT_ID_SIZE) == 0) {
      return ER_OBJECT_ERR_BADARG;
    }
    logical_len += children[i].logical_len;
    er_object_copy(&cursor[ER_OBJECT_CHILD_OBJECT_ID_OFF], children[i].object_id, ER_OBJECT_ID_SIZE);
    er_object_store64(&cursor[ER_OBJECT_CHILD_LOGICAL_OFFSET_OFF], children[i].logical_offset);
    er_object_store64(&cursor[ER_OBJECT_CHILD_LOGICAL_LEN_OFF], children[i].logical_len);
    er_object_store16(&cursor[ER_OBJECT_CHILD_KIND_OFF], children[i].node_kind);
    er_object_store16(&cursor[ER_OBJECT_CHILD_RESERVED_OFF], children[i].reserved);
    er_object_copy(&cursor[ER_OBJECT_CHILD_REQUIREMENTS_HASH_OFF],
                   children[i].requirements_hash,
                   ER_OBJECT_ID_SIZE);
    cursor += ER_OBJECT_CHILD_SIZE;
  }
  if (child_count != 0u) {
    er_object_store64(&bytes[ER_OBJECT_HEADER_LOGICAL_LEN_OFF], logical_len);
  }
  if (body_len != 0u) {
    er_object_copy(cursor, body, body_len);
  }
  *out_len = total;
  return er_object_id(out, total, out_id);
}

static int er_object_magic_valid(const uint8_t* bytes) {
  return bytes[ER_OBJECT_MAGIC_BYTE0] == ER_OBJECT_MAGIC0 &&
         bytes[ER_OBJECT_MAGIC_BYTE1] == ER_OBJECT_MAGIC1 &&
         bytes[ER_OBJECT_MAGIC_BYTE2] == ER_OBJECT_MAGIC2 &&
         bytes[ER_OBJECT_MAGIC_BYTE3] == ER_OBJECT_MAGIC3 &&
         bytes[ER_OBJECT_MAGIC_BYTE4] == ER_OBJECT_MAGIC4 &&
         bytes[ER_OBJECT_MAGIC_BYTE5] == ER_OBJECT_MAGIC5 &&
         bytes[ER_OBJECT_MAGIC_BYTE6] == ER_OBJECT_MAGIC6 &&
         bytes[ER_OBJECT_MAGIC_BYTE7] == ER_OBJECT_MAGIC7;
}

int er_object_verify(const void* canonical, size_t len,
                     er_object_info_t* out_info) {
  const uint8_t* bytes = (const uint8_t*)canonical;
  const uint8_t* cursor;
  const uint8_t* owners_start;
  er_object_requirements_t requirements;
  uint16_t node_kind;
  uint16_t owner_count;
  uint16_t envelope_count;
  uint32_t child_count;
  uint64_t body_len; //@optimizer-ignore canonical object body lengths are 64-bit fields
  uint64_t logical_len; //@optimizer-ignore canonical object logical lengths are 64-bit fields
  er_clock_epoch_stamp_t epoch;
  uint64_t child_end = 0u;
  size_t expected_len;
  uint32_t i;

  if (canonical == (const void*)0 || len < ER_OBJECT_HEADER_SIZE) {
    return ER_OBJECT_ERR_BADARG;
  }
  if (er_object_magic_valid(bytes) == 0 ||
      er_object_load16(&bytes[ER_OBJECT_HEADER_VERSION_OFF]) != ER_OBJECT_ABI_VERSION) {
    return ER_OBJECT_ERR_CORRUPT;
  }
  node_kind = er_object_load16(&bytes[ER_OBJECT_HEADER_KIND_OFF]);
  owner_count = er_object_load16(&bytes[ER_OBJECT_HEADER_OWNER_COUNT_OFF]);
  envelope_count = er_object_load16(&bytes[ER_OBJECT_HEADER_ENVELOPE_COUNT_OFF]);
  child_count = er_object_load32(&bytes[ER_OBJECT_HEADER_CHILD_COUNT_OFF]);
  body_len = er_object_load64(&bytes[ER_OBJECT_HEADER_BODY_LEN_OFF]);
  logical_len = er_object_load64(&bytes[ER_OBJECT_HEADER_LOGICAL_LEN_OFF]);
  epoch = er_object_epoch_read(&bytes[ER_OBJECT_HEADER_EPOCH_OFF]);
  if ((size_t)body_len != body_len) {
    return ER_OBJECT_ERR_TOOBIG;
  }
  er_object_requirements_read(&bytes[ER_OBJECT_HEADER_REQUIREMENTS_OFF], &requirements);
  if (er_object_requirements_valid(&requirements) == 0 ||
      er_clock_stamp_valid(epoch) == 0 ||
      er_object_canonical_size(node_kind, (size_t)body_len, owner_count,
                               envelope_count, child_count, &expected_len) != ER_OBJECT_OK ||
      expected_len != len) {
    return ER_OBJECT_ERR_CORRUPT;
  }
  owners_start = &bytes[ER_OBJECT_HEADER_SIZE];
  cursor = owners_start;
  for (i = 0u; i < owner_count; ++i) {
    if (er_object_owner_kind_valid(er_object_load32(cursor)) == 0 ||
        er_object_bytes_nonzero(&cursor[ER_OBJECT_U32_BYTES], ER_OBJECT_ID_SIZE) == 0) {
      return ER_OBJECT_ERR_CORRUPT;
    }
    cursor += ER_OBJECT_OWNER_SIZE;
  }
  for (i = 0u; i < envelope_count; ++i) {
    uint16_t owner_index = er_object_load16(&cursor[ER_OBJECT_ENVELOPE_OWNER_INDEX_OFF]);
    uint32_t owner_kind;

    if (owner_index >= owner_count) {
      return ER_OBJECT_ERR_CORRUPT;
    }
    owner_kind = er_object_load32(&owners_start[(size_t)owner_index * ER_OBJECT_OWNER_SIZE]);
    if (er_object_envelope_valid(er_object_load32(cursor),
                                 owner_kind,
                                 er_object_load16(&cursor[ER_OBJECT_ENVELOPE_ALGORITHM_OFF]),
                                 &cursor[ER_OBJECT_ENVELOPE_KEY_ID_OFF],
                                 &cursor[ER_OBJECT_ENVELOPE_METADATA_HASH_OFF]) == 0) {
      return ER_OBJECT_ERR_CORRUPT;
    }
    cursor += ER_OBJECT_ENVELOPE_SIZE;
  }
  for (i = 0u; i < child_count; ++i) {
    if (er_object_load64(&cursor[ER_OBJECT_CHILD_LOGICAL_OFFSET_OFF]) != child_end ||
        er_object_load64(&cursor[ER_OBJECT_CHILD_LOGICAL_LEN_OFF]) > ER_SIZE_MAX_U64 - child_end ||
        er_object_kind_valid(er_object_load16(&cursor[ER_OBJECT_CHILD_KIND_OFF])) == 0 ||
        er_object_load16(&cursor[ER_OBJECT_CHILD_RESERVED_OFF]) != 0u ||
        er_object_load64(&cursor[ER_OBJECT_CHILD_LOGICAL_LEN_OFF]) == 0u ||
        er_object_bytes_nonzero(cursor, ER_OBJECT_ID_SIZE) == 0 ||
        er_object_bytes_nonzero(&cursor[ER_OBJECT_CHILD_REQUIREMENTS_HASH_OFF], ER_OBJECT_ID_SIZE) == 0) {
      return ER_OBJECT_ERR_CORRUPT;
    }
    child_end += er_object_load64(&cursor[ER_OBJECT_CHILD_LOGICAL_LEN_OFF]);
    cursor += ER_OBJECT_CHILD_SIZE;
  }
  if ((node_kind == ER_OBJECT_KIND_TREE && child_end != logical_len) ||
      (node_kind != ER_OBJECT_KIND_TREE && body_len != logical_len)) {
    return ER_OBJECT_ERR_CORRUPT;
  }
  if (out_info != (er_object_info_t*)0) {
    out_info->node_kind = node_kind;
    out_info->flags = er_object_load32(&bytes[ER_OBJECT_HEADER_FLAGS_OFF]);
    out_info->owner_count = owner_count;
    out_info->envelope_count = envelope_count;
    out_info->child_count = child_count;
    out_info->logical_len = er_object_load64(&bytes[ER_OBJECT_HEADER_LOGICAL_LEN_OFF]);
    out_info->body_len = body_len;
    out_info->epoch = epoch;
    out_info->requirements = requirements;
    out_info->body = &bytes[len - (size_t)body_len];
    if (er_object_id(canonical, len, out_info->object_id) != ER_OBJECT_OK) {
      return ER_OBJECT_ERR_CORRUPT;
    }
  }
  return ER_OBJECT_OK;
}

int er_object_owner_at(const void* canonical, size_t len, uint16_t index,
                       er_object_owner_t* out_owner) {
  const uint8_t* bytes = (const uint8_t*)canonical;
  const uint8_t* owner;
  er_object_info_t info;

  if (out_owner == (er_object_owner_t*)0 ||
      er_object_verify(canonical, len, &info) != ER_OBJECT_OK ||
      index >= info.owner_count) {
    return ER_OBJECT_ERR_BADARG;
  }
  owner = &bytes[ER_OBJECT_HEADER_SIZE + ((size_t)index * ER_OBJECT_OWNER_SIZE)];
  out_owner->owner_kind = er_object_load32(owner);
  er_object_copy(out_owner->node_id, &owner[ER_OBJECT_U32_BYTES], ER_OBJECT_ID_SIZE);
  return ER_OBJECT_OK;
}

int er_object_envelope_at(const void* canonical, size_t len, uint16_t index,
                          er_object_envelope_t* out_envelope) {
  const uint8_t* bytes = (const uint8_t*)canonical;
  const uint8_t* envelope;
  er_object_info_t info;
  size_t offset;

  if (out_envelope == (er_object_envelope_t*)0 ||
      er_object_verify(canonical, len, &info) != ER_OBJECT_OK ||
      index >= info.envelope_count) {
    return ER_OBJECT_ERR_BADARG;
  }
  offset = ER_OBJECT_HEADER_SIZE +
           ((size_t)info.owner_count * ER_OBJECT_OWNER_SIZE) +
           ((size_t)index * ER_OBJECT_ENVELOPE_SIZE);
  envelope = &bytes[offset];
  out_envelope->envelope_kind = er_object_load32(envelope);
  out_envelope->owner_index = er_object_load16(&envelope[ER_OBJECT_ENVELOPE_OWNER_INDEX_OFF]);
  out_envelope->algorithm = er_object_load16(&envelope[ER_OBJECT_ENVELOPE_ALGORITHM_OFF]);
  out_envelope->flags = er_object_load32(&envelope[ER_OBJECT_ENVELOPE_FLAGS_OFF]);
  er_object_copy(out_envelope->key_id,
                 &envelope[ER_OBJECT_ENVELOPE_KEY_ID_OFF],
                 ER_OBJECT_ID_SIZE);
  er_object_copy(out_envelope->metadata_hash,
                 &envelope[ER_OBJECT_ENVELOPE_METADATA_HASH_OFF],
                 ER_OBJECT_ID_SIZE);
  return ER_OBJECT_OK;
}

int er_object_child_at(const void* canonical, size_t len, uint32_t index,
                       er_object_child_ref_t* out_child) {
  const uint8_t* bytes = (const uint8_t*)canonical;
  const uint8_t* child;
  er_object_info_t info;
  size_t offset;

  if (out_child == (er_object_child_ref_t*)0 ||
      er_object_verify(canonical, len, &info) != ER_OBJECT_OK ||
      index >= info.child_count) {
    return ER_OBJECT_ERR_BADARG;
  }
  offset = ER_OBJECT_HEADER_SIZE +
           ((size_t)info.owner_count * ER_OBJECT_OWNER_SIZE) +
           ((size_t)info.envelope_count * ER_OBJECT_ENVELOPE_SIZE) +
           ((size_t)index * ER_OBJECT_CHILD_SIZE);
  child = &bytes[offset];
  er_object_copy(out_child->object_id, &child[ER_OBJECT_CHILD_OBJECT_ID_OFF], ER_OBJECT_ID_SIZE);
  out_child->logical_offset = er_object_load64(&child[ER_OBJECT_CHILD_LOGICAL_OFFSET_OFF]);
  out_child->logical_len = er_object_load64(&child[ER_OBJECT_CHILD_LOGICAL_LEN_OFF]);
  out_child->node_kind = er_object_load16(&child[ER_OBJECT_CHILD_KIND_OFF]);
  out_child->reserved = er_object_load16(&child[ER_OBJECT_CHILD_RESERVED_OFF]);
  er_object_copy(out_child->requirements_hash,
                 &child[ER_OBJECT_CHILD_REQUIREMENTS_HASH_OFF],
                 ER_OBJECT_ID_SIZE);
  return ER_OBJECT_OK;
}

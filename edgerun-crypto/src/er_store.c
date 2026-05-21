//@optimizer-ignore single-file storage engine keeps the append log, replay, and indexes together
#include "er_store.h"

#include "er_blake3.h"
#include "er_math.h"

/*
 * Format:
 *   All integers are manually encoded little-endian. Offset zero contains a
 *   ER_STORE_SUPERBLOCK_SIZE bytes. Records start at log_start and append:
 *
 *     ER_STORE_RECORD_HEADER_SIZE bytes followed by payload bytes
 *
 *   The header CRC covers ER_STORE_RECORD_CRC_SIZE bytes. payload_hash uses
 *   ER_HASH_SIZE BLAKE3 bytes over the raw payload. prev_record_hash chains to
 *   the previous valid header hash, where the first record uses all zero bytes.
 *
 * Recovery:
 *   open never trusts superblock log_end. It scans from log_start, validates
 *   header magic, CRC, payload hash, sequence continuity, and previous-record
 *   hash, then stops at the first incomplete or invalid record. The underlying
 *   IO is truncated back to the last valid end offset and indexes are rebuilt
 *   from the valid prefix. The log is the source of truth; indexes only
 *   accelerate lookups after replay.
 */

enum {
  ER_STORE_SUPERBLOCK_SIZE = 68u,
  ER_STORE_RECORD_HEADER_SIZE = 92u,
  ER_STORE_RECORD_CRC_SIZE = 88u,
  ER_STORE_VERSION = 1u,
  ER_STORE_RECORD_VERSION = 1u,
  ER_STORE_MAGIC_SIZE = 8u,
  ER_STORE_MAGIC_0 = 'E',
  ER_STORE_MAGIC_1 = 'R',
  ER_STORE_MAGIC_2 = 'S',
  ER_STORE_MAGIC_3 = 'T',
  ER_STORE_MAGIC_4 = 'O',
  ER_STORE_MAGIC_5 = 'R',
  ER_STORE_MAGIC_6 = 'E',
  ER_STORE_MAGIC_7 = 0u,
  ER_STORE_SUPER_VERSION_OFF = 8u,
  ER_STORE_SUPER_HEADER_SIZE_OFF = 12u,
  ER_STORE_SUPER_LOG_START_OFF = 16u,
  ER_STORE_SUPER_LOG_END_OFF = 24u,
  ER_STORE_SUPER_ROOT_HASH_OFF = 32u,
  ER_STORE_SUPER_CRC_OFF = 64u,
  ER_STORE_RECORD_MAGIC = 0x45525331u,
  ER_STORE_HEADER_MAGIC_OFF = 0u,
  ER_STORE_HEADER_VERSION_OFF = 4u,
  ER_STORE_HEADER_TYPE_OFF = 6u,
  ER_STORE_HEADER_SEQ_OFF = 8u,
  ER_STORE_HEADER_PAYLOAD_LEN_OFF = 16u,
  ER_STORE_HEADER_PAYLOAD_HASH_OFF = 24u,
  ER_STORE_HEADER_PREV_HASH_OFF = 56u,
  ER_STORE_HEADER_CRC_OFF = 88u,
  ER_STORE_TYPE_PAYLOAD_SIZE = 4u + ER_HASH_SIZE,
  ER_STORE_TYPE_HASH_OFF = 4u,
  ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE = 6u,
  ER_STORE_DEFINE_NAME_LEN_OFF = 4u,
  ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE = 10u,
  ER_STORE_INDEX_DEFINE_CONTENT_TYPE_OFF = 4u,
  ER_STORE_INDEX_DEFINE_NAME_LEN_OFF = 8u,
  ER_STORE_INDEX_ID_SIZE = 4u,
  ER_STORE_OBJECT_TOTAL_SIZE_OFF = 0u,
  ER_STORE_OBJECT_CHUNK_SIZE_OFF = 8u,
  ER_STORE_OBJECT_CHUNK_COUNT_OFF = 16u,
  ER_STORE_OBJECT_FIRST_HASH_OFF = 20u,
  ER_STORE_PROJECT_INDEX_ID_OFF = 0u,
  ER_STORE_PROJECT_VALUE_KIND_OFF = 4u,
  ER_STORE_PROJECT_CONTENT_TYPE_OFF = 8u,
  ER_STORE_PROJECT_VALUE_SIZE_OFF = 12u,
  ER_STORE_PROJECT_KEY_LEN_OFF = 20u,
  ER_STORE_PROJECT_KEY_OFF = 22u,
  ER_STORE_PROJECT_FIXED_PAYLOAD_SIZE = ER_STORE_PROJECT_KEY_OFF + ER_HASH_SIZE,
  ER_STORE_INDEX_KEY_LEN_SIZE = 2u,
  ER_STORE_INDEX_PAYLOAD_OVERHEAD = ER_STORE_INDEX_ID_SIZE + ER_STORE_INDEX_KEY_LEN_SIZE + ER_HASH_SIZE,
  ER_STORE_INDEX_OLD_PAYLOAD_OVERHEAD = ER_STORE_INDEX_KEY_LEN_SIZE + ER_HASH_SIZE,
  ER_STORE_ALIGN = 8u,
  ER_REC_BLOB = 1u,
  ER_REC_INDEX_PUT = 2u,
  ER_REC_TOMBSTONE = 3u,
  ER_REC_BLOB_TYPE = 4u,
  ER_REC_CONTENT_TYPE_DEFINE = 5u,
  ER_REC_INDEX_DEFINE = 6u,
  ER_REC_OBJECT_INDEX_PUT = 7u,
  ER_CRC_INIT = 0xffffffffu,
  ER_CRC_XOR_OUT = 0xffffffffu,
  ER_CRC_POLY = 0xedb88320u,
  ER_BYTE_BITS = 8u,
  ER_BYTE0 = 0u,
  ER_BYTE1 = 1u,
  ER_BYTE2 = 2u,
  ER_BYTE3 = 3u,
  ER_BYTE4 = 4u,
  ER_BYTE5 = 5u,
  ER_BYTE6 = 6u,
  ER_BYTE7 = 7u,
  ER_U16_BYTE1_SHIFT = 8u,
  ER_U32_BYTE1_SHIFT = 8u,
  ER_U32_BYTE2_SHIFT = 16u,
  ER_U32_BYTE3_SHIFT = 24u,
  ER_U64_BYTE1_SHIFT = 8u,
  ER_U64_BYTE2_SHIFT = 16u,
  ER_U64_BYTE3_SHIFT = 24u,
  ER_U64_BYTE4_SHIFT = 32u,
  ER_U64_BYTE5_SHIFT = 40u,
  ER_U64_BYTE6_SHIFT = 48u,
  ER_U64_BYTE7_SHIFT = 56u,
  ER_SIZE_MAX_U64 = 0xffffffffffffffffull
};

#define ER_STORE_SLOT_HASH_MULTIPLIER 131u

typedef struct {
  uint8_t used;
  uint8_t hash[ER_HASH_SIZE];
  uint32_t content_type;
  uint64_t offset; //@optimizer-ignore blob offsets mirror the fixed 64-bit record log ABI
  uint64_t size; //@optimizer-ignore blob sizes mirror the fixed 64-bit record log ABI
  size_t cache_off;
  size_t cache_len;
} ErStoreBlobSlot;

typedef struct {
  uint8_t used;
  uint32_t index_id;
  uint32_t value_kind;
  uint32_t content_type;
  uint16_t key_len;
  char key[ER_STORE_MAX_KEY];
  uint8_t hash[ER_HASH_SIZE];
  uint64_t value_size; //@optimizer-ignore index values mirror fixed 64-bit blob/object sizes
} ErStoreKeySlot;

typedef struct {
  uint8_t used;
  uint32_t content_type;
  uint16_t name_len;
  char name[ER_STORE_MAX_NAME];
} ErStoreTypeSlot;

typedef struct {
  uint8_t used;
  uint32_t index_id;
  uint32_t content_type;
  uint16_t name_len;
  char name[ER_STORE_MAX_NAME];
} ErStoreIndexSlot;

typedef struct {
  uint16_t type;
  uint64_t seq; //@optimizer-ignore sequence values mirror the fixed 64-bit record header ABI
  uint64_t payload_len; //@optimizer-ignore payload lengths mirror the fixed 64-bit record header ABI
  uint8_t payload_hash[ER_HASH_SIZE];
  uint8_t prev_hash[ER_HASH_SIZE];
} ErStoreRecordInfo;

static void er_store_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* bytes = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

static void er_store_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static int er_store_equal(const void* a, const void* b, size_t len) {
  size_t i;
  const uint8_t* left = (const uint8_t*)a;
  const uint8_t* right = (const uint8_t*)b;

  for (i = 0u; i < len; ++i) {
    if (left[i] != right[i]) {
      return 0;
    }
  }
  return 1;
}

//@optimizer-ignore-function fixed-width little-endian ABI decoding requires byte-slot indexing
static uint16_t er_store_load16(const uint8_t* bytes) {
  return (uint16_t)((uint16_t)bytes[ER_BYTE0] | ((uint16_t)bytes[ER_BYTE1] << ER_U16_BYTE1_SHIFT));
}

//@optimizer-ignore-function fixed-width little-endian ABI decoding requires byte-slot indexing
static uint32_t er_store_load32(const uint8_t* bytes) {
  return ((uint32_t)bytes[ER_BYTE0]) | ((uint32_t)bytes[ER_BYTE1] << ER_U32_BYTE1_SHIFT) |
         ((uint32_t)bytes[ER_BYTE2] << ER_U32_BYTE2_SHIFT) |
         ((uint32_t)bytes[ER_BYTE3] << ER_U32_BYTE3_SHIFT);
}

//@optimizer-ignore-function fixed-width little-endian ABI decoding requires byte-slot indexing
static uint64_t er_store_load64(const uint8_t* bytes) {
  return ((uint64_t)bytes[ER_BYTE0]) | ((uint64_t)bytes[ER_BYTE1] << ER_U64_BYTE1_SHIFT) |
         ((uint64_t)bytes[ER_BYTE2] << ER_U64_BYTE2_SHIFT) |
         ((uint64_t)bytes[ER_BYTE3] << ER_U64_BYTE3_SHIFT) |
         ((uint64_t)bytes[ER_BYTE4] << ER_U64_BYTE4_SHIFT) |
         ((uint64_t)bytes[ER_BYTE5] << ER_U64_BYTE5_SHIFT) |
         ((uint64_t)bytes[ER_BYTE6] << ER_U64_BYTE6_SHIFT) |
         ((uint64_t)bytes[ER_BYTE7] << ER_U64_BYTE7_SHIFT);
}

//@optimizer-ignore-function fixed-width little-endian ABI encoding requires byte-slot indexing
static void er_store_store16(uint8_t* bytes, uint16_t value) {
  bytes[ER_BYTE0] = (uint8_t)value;
  bytes[ER_BYTE1] = (uint8_t)(value >> ER_U16_BYTE1_SHIFT);
}

//@optimizer-ignore-function fixed-width little-endian ABI encoding requires byte-slot indexing
static void er_store_store32(uint8_t* bytes, uint32_t value) {
  bytes[ER_BYTE0] = (uint8_t)value;
  bytes[ER_BYTE1] = (uint8_t)(value >> ER_U32_BYTE1_SHIFT);
  bytes[ER_BYTE2] = (uint8_t)(value >> ER_U32_BYTE2_SHIFT);
  bytes[ER_BYTE3] = (uint8_t)(value >> ER_U32_BYTE3_SHIFT);
}

//@optimizer-ignore-function fixed-width little-endian ABI encoding requires byte-slot indexing
static void er_store_store64(uint8_t* bytes, uint64_t value) {
  bytes[ER_BYTE0] = (uint8_t)value;
  bytes[ER_BYTE1] = (uint8_t)(value >> ER_U64_BYTE1_SHIFT);
  bytes[ER_BYTE2] = (uint8_t)(value >> ER_U64_BYTE2_SHIFT);
  bytes[ER_BYTE3] = (uint8_t)(value >> ER_U64_BYTE3_SHIFT);
  bytes[ER_BYTE4] = (uint8_t)(value >> ER_U64_BYTE4_SHIFT);
  bytes[ER_BYTE5] = (uint8_t)(value >> ER_U64_BYTE5_SHIFT);
  bytes[ER_BYTE6] = (uint8_t)(value >> ER_U64_BYTE6_SHIFT);
  bytes[ER_BYTE7] = (uint8_t)(value >> ER_U64_BYTE7_SHIFT);
}

//@optimizer-ignore-function CRC32 is the fixed on-disk header checksum algorithm
static uint32_t er_store_crc32(const uint8_t* bytes, size_t len) {
  size_t i;
  uint32_t bit;
  uint32_t crc = ER_CRC_INIT;

  for (i = 0u; i < len; ++i) {
    crc ^= bytes[i];
    for (bit = 0u; bit < ER_BYTE_BITS; ++bit) {
      switch (crc & 1u) {
        case 0u:
          crc >>= 1u;
          break;
        default:
          crc = (crc >> 1u) ^ ER_CRC_POLY;
          break;
      }
    }
  }
  return crc ^ ER_CRC_XOR_OUT;
}

static uint64_t er_store_align_up(uint64_t value, uint64_t alignment) {
  uint64_t mask = alignment - 1u;

  return (value + mask) & ~mask;
}

//@optimizer-ignore-function record log sizes are fixed 64-bit ABI values
static int er_store_size_to_u64(size_t value, uint64_t* out) {
  if (out == (uint64_t*)0) {
    return ER_ERR_BADARG;
  }
  *out = (uint64_t)value;
  if ((size_t)(*out) != value) {
    return ER_ERR_TOOBIG;
  }
  return ER_OK;
}

//@optimizer-ignore-function record log offsets are fixed 64-bit ABI values
static int er_store_add_u64(uint64_t a, uint64_t b, uint64_t* out) {
  if (a > (ER_SIZE_MAX_U64 - b)) {
    return ER_ERR_TOOBIG;
  }
  *out = a + b;
  return ER_OK;
}

//@optimizer-ignore-function bounded key scanning intentionally indexes caller key bytes
static size_t er_store_cstr_len(const char* text, size_t cap, int* ok) {
  size_t len;

  if (ok != (int*)0) {
    *ok = 0;
  }
  if (text == (const char*)0) {
    return 0u;
  }
  for (len = 0u; len < cap; ++len) {
    if (text[len] == 0) {
      if (ok != (int*)0) {
        *ok = 1;
      }
      return len;
    }
  }
  return cap;
}

static int er_store_key_equal_ex(const ErStoreKeySlot* slot, uint32_t index_id, const char* key, size_t key_len) {
  if (slot->index_id != index_id || slot->key_len != key_len) {
    return 0;
  }
  return er_store_equal(slot->key, key, key_len);
}

static int er_store_key_has_prefix(const ErStoreKeySlot* slot, uint32_t index_id, const char* prefix,
                                   size_t prefix_len) {
  if (slot->index_id != index_id) {
    return 0;
  }
  if ((size_t)slot->key_len < prefix_len) {
    return 0;
  }
  return er_store_equal(slot->key, prefix, prefix_len);
}

//@optimizer-ignore-function fixed-size hash bytes are intentionally indexed for slot mixing
static size_t er_store_hash_slot(const uint8_t hash[ER_HASH_SIZE], size_t cap) {
  size_t i;
  size_t value = 0u;

  for (i = 0u; i < ER_HASH_SIZE; ++i) {
    value = (value * ER_STORE_SLOT_HASH_MULTIPLIER) ^ hash[i];
  }
  return value & (cap - 1u);
}

static size_t er_store_key_slot_ex(uint32_t index_id, const char* key, size_t key_len, size_t cap) {
  size_t i;
  size_t value = index_id;

  for (i = 0u; i < key_len; ++i) {
    value = (value * ER_STORE_SLOT_HASH_MULTIPLIER) ^ (uint8_t)key[i];
  }
  return value & (cap - 1u);
}

static size_t er_store_id_slot(uint32_t id, size_t cap) {
  size_t value = id;

  value ^= value >> ER_U32_BYTE1_SHIFT;
  value *= ER_STORE_SLOT_HASH_MULTIPLIER;
  return value & (cap - 1u);
}

static ErStoreBlobSlot* er_store_blobs(er_store_t* store) {
  return (ErStoreBlobSlot*)store->blob_slots;
}

static ErStoreKeySlot* er_store_keys(er_store_t* store) {
  return (ErStoreKeySlot*)store->key_slots;
}

static size_t* er_store_sorted_keys(er_store_t* store) {
  return (size_t*)store->sorted_key_slots;
}

static ErStoreTypeSlot* er_store_types(er_store_t* store) {
  return (ErStoreTypeSlot*)store->type_slots;
}

static ErStoreIndexSlot* er_store_indexes(er_store_t* store) {
  return (ErStoreIndexSlot*)store->index_slots;
}

//@optimizer-ignore-function fixed-capacity hash table indexes the caller-provided arena
static int er_store_find_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], size_t* out_slot) {
  ErStoreBlobSlot* slots = er_store_blobs(store);
  size_t start;
  size_t i;
  size_t slot;

  start = er_store_hash_slot(hash, store->blob_capacity);
  slot = start;
  for (i = 0u; i < store->blob_capacity; ++i) {
    if (slots[slot].used == 0u) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_ERR_NOTFOUND;
    }
    if (er_store_equal(slots[slot].hash, hash, ER_HASH_SIZE)) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_OK;
    }
    ++slot;
    if (slot == store->blob_capacity) {
      slot = 0u;
    }
  }
  return ER_ERR_NOSPACE;
}

//@optimizer-ignore-function blob offsets and sizes mirror fixed 64-bit record log fields
static int er_store_insert_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE],
                                uint64_t offset, //@optimizer-ignore fixed record log offset is part of storage ABI
                                uint64_t size) { //@optimizer-ignore fixed record payload size is part of storage ABI
  ErStoreBlobSlot* slots = er_store_blobs(store);
  size_t slot;
  int found = er_store_find_blob(store, hash, &slot);

  if (found == ER_OK) {
    slots[slot].offset = offset;
    slots[slot].size = size;
    return ER_OK;
  }
  if (found != ER_ERR_NOTFOUND) {
    return found;
  }
  if (store->blob_count >= store->blob_capacity) {
    return ER_ERR_NOSPACE;
  }
  slots[slot].used = 1u;
  er_store_copy(slots[slot].hash, hash, ER_HASH_SIZE);
  slots[slot].content_type = ER_STORE_TYPE_RAW;
  slots[slot].offset = offset;
  slots[slot].size = size;
  slots[slot].cache_off = 0u;
  slots[slot].cache_len = 0u;
  ++store->blob_count;
  return ER_OK;
}

//@optimizer-ignore-function fixed-capacity blob table indexes the caller-provided arena
static int er_store_set_blob_type(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], uint32_t content_type) {
  ErStoreBlobSlot* slots = er_store_blobs(store);
  size_t slot;
  int rc = er_store_find_blob(store, hash, &slot);

  if (rc != ER_OK) {
    return rc;
  }
  slots[slot].content_type = content_type;
  return ER_OK;
}

//@optimizer-ignore-function cache writes are bounded by arena-owned cache slots
static void er_store_cache_blob(er_store_t* store, size_t slot, const void* data, size_t len) {
  ErStoreBlobSlot* slots = er_store_blobs(store);

  if (len == 0u || data == (const void*)0 || len > (store->cache_len - store->cache_used)) {
    if (len != 0u) {
      ++store->cache_rejects;
    }
    return;
  }
  er_store_copy(&store->cache[store->cache_used], data, len);
  slots[slot].cache_off = store->cache_used;
  slots[slot].cache_len = len;
  store->cache_used += len;
  ++store->cache_admissions;
}

//@optimizer-ignore-function fixed-capacity key table indexes the caller-provided arena
static int er_store_find_key_ex(er_store_t* store, uint32_t index_id, const char* key, size_t key_len,
                                size_t* out_slot) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t start;
  size_t i;
  size_t slot;

  start = er_store_key_slot_ex(index_id, key, key_len, store->key_capacity);
  slot = start;
  for (i = 0u; i < store->key_capacity; ++i) {
    if (slots[slot].used == 0u) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_ERR_NOTFOUND;
    }
    if (er_store_key_equal_ex(&slots[slot], index_id, key, key_len)) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_OK;
    }
    ++slot;
    if (slot == store->key_capacity) {
      slot = 0u;
    }
  }
  return ER_ERR_NOSPACE;
}

//@optimizer-ignore-function fixed-capacity key table indexes fixed hash bytes from the caller-provided arena
static int er_store_insert_key_meta(er_store_t* store, uint32_t index_id, const char* key, size_t key_len,
                                    const uint8_t* hash, uint32_t value_kind,
                                    uint32_t content_type, uint64_t value_size) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t slot;
  int found = er_store_find_key_ex(store, index_id, key, key_len, &slot);

  if (found != ER_OK && found != ER_ERR_NOTFOUND) {
    return found;
  }
  if (found == ER_ERR_NOTFOUND) {
    if (store->key_count >= store->key_capacity) {
      return ER_ERR_NOSPACE;
    }
    slots[slot].used = 1u;
    slots[slot].index_id = index_id;
    slots[slot].key_len = (uint16_t)key_len;
    er_store_zero(slots[slot].key, ER_STORE_MAX_KEY);
    er_store_copy(slots[slot].key, key, key_len);
    ++store->key_count;
    store->sorted_key_dirty = 1;
  }
  slots[slot].value_kind = value_kind;
  slots[slot].content_type = content_type;
  slots[slot].value_size = value_size;
  er_store_copy(slots[slot].hash, hash, ER_HASH_SIZE);
  return ER_OK;
}

static int er_store_insert_key_ex(er_store_t* store, uint32_t index_id, const char* key, size_t key_len,
                                  const uint8_t hash[ER_HASH_SIZE]) {
  return er_store_insert_key_meta(store, index_id, key, key_len, hash, ER_STORE_VALUE_UNKNOWN, ER_STORE_TYPE_RAW, 0u);
}

//@optimizer-ignore-function fixed-capacity content-type table indexes the caller-provided arena
static int er_store_find_type(er_store_t* store, uint32_t content_type, size_t* out_slot) {
  ErStoreTypeSlot* slots = er_store_types(store);
  size_t start = er_store_id_slot(content_type, store->type_capacity);
  size_t slot = start;
  size_t i;

  for (i = 0u; i < store->type_capacity; ++i) {
    if (slots[slot].used == 0u) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_ERR_NOTFOUND;
    }
    if (slots[slot].content_type == content_type) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_OK;
    }
    ++slot;
    if (slot == store->type_capacity) {
      slot = 0u;
    }
  }
  return ER_ERR_NOSPACE;
}

//@optimizer-ignore-function fixed-capacity content-type table indexes the caller-provided arena
static int er_store_insert_type(er_store_t* store, uint32_t content_type, const char* name, size_t name_len) {
  ErStoreTypeSlot* slots = er_store_types(store);
  size_t slot;
  int found = er_store_find_type(store, content_type, &slot);

  if (found != ER_OK && found != ER_ERR_NOTFOUND) {
    return found;
  }
  if (found == ER_ERR_NOTFOUND) {
    if (store->type_count >= store->type_capacity) {
      return ER_ERR_NOSPACE;
    }
    slots[slot].used = 1u;
    slots[slot].content_type = content_type;
    ++store->type_count;
  }
  slots[slot].name_len = (uint16_t)name_len;
  er_store_zero(slots[slot].name, ER_STORE_MAX_NAME);
  er_store_copy(slots[slot].name, name, name_len);
  return ER_OK;
}

//@optimizer-ignore-function fixed-capacity index-definition table indexes the caller-provided arena
static int er_store_find_index_def(er_store_t* store, uint32_t index_id, size_t* out_slot) {
  ErStoreIndexSlot* slots = er_store_indexes(store);
  size_t start = er_store_id_slot(index_id, store->index_capacity);
  size_t slot = start;
  size_t i;

  for (i = 0u; i < store->index_capacity; ++i) {
    if (slots[slot].used == 0u) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_ERR_NOTFOUND;
    }
    if (slots[slot].index_id == index_id) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_OK;
    }
    ++slot;
    if (slot == store->index_capacity) {
      slot = 0u;
    }
  }
  return ER_ERR_NOSPACE;
}

//@optimizer-ignore-function fixed-capacity index-definition table indexes the caller-provided arena
static int er_store_insert_index_def(er_store_t* store, uint32_t index_id, uint32_t content_type,
                                     const char* name, size_t name_len) {
  ErStoreIndexSlot* slots = er_store_indexes(store);
  size_t slot;
  int found = er_store_find_index_def(store, index_id, &slot);

  if (found != ER_OK && found != ER_ERR_NOTFOUND) {
    return found;
  }
  if (found == ER_ERR_NOTFOUND) {
    if (store->index_count >= store->index_capacity) {
      return ER_ERR_NOSPACE;
    }
    slots[slot].used = 1u;
    slots[slot].index_id = index_id;
    ++store->index_count;
  }
  slots[slot].content_type = content_type;
  slots[slot].name_len = (uint16_t)name_len;
  er_store_zero(slots[slot].name, ER_STORE_MAX_NAME);
  er_store_copy(slots[slot].name, name, name_len);
  return ER_OK;
}

static int er_store_key_compare_bytes(const char* left, size_t left_len, const char* right, size_t right_len) {
  size_t i;
  size_t min_len = er_math_min_size(left_len, right_len);

  for (i = 0u; i < min_len; ++i) {
    if ((uint8_t)left[i] < (uint8_t)right[i]) {
      return -1;
    }
    if ((uint8_t)left[i] > (uint8_t)right[i]) {
      return 1;
    }
  }
  if (left_len < right_len) {
    return -1;
  }
  if (left_len > right_len) {
    return 1;
  }
  return 0;
}

static int er_store_key_slot_compare(const ErStoreKeySlot* left, const ErStoreKeySlot* right) {
  if (left->index_id < right->index_id) {
    return -1;
  }
  if (left->index_id > right->index_id) {
    return 1;
  }
  return er_store_key_compare_bytes(left->key, left->key_len, right->key, right->key_len);
}

//@optimizer-ignore-function sorted key references intentionally index arena-owned key slots
static int er_store_sorted_ref_less(const ErStoreKeySlot* slots, size_t left_ref, size_t right_ref) {
  return er_store_key_slot_compare(&slots[left_ref], &slots[right_ref]) < 0;
}

static void er_store_sorted_swap(size_t* refs, size_t a, size_t b) {
  size_t tmp = refs[a];

  refs[a] = refs[b];
  refs[b] = tmp;
}

//@optimizer-ignore-function heapsort intentionally indexes sorted key references
static void er_store_sorted_sift_down(const ErStoreKeySlot* slots, size_t* refs, size_t start, size_t end) {
  size_t root = start;
  size_t child;
  size_t swap_index;

  while ((root * 2u + 1u) <= end) {
    child = root * 2u + 1u;
    swap_index = root;
    if (er_store_sorted_ref_less(slots, refs[swap_index], refs[child])) {
      swap_index = child;
    }
    if (child + 1u <= end && er_store_sorted_ref_less(slots, refs[swap_index], refs[child + 1u])) {
      swap_index = child + 1u;
    }
    if (swap_index == root) {
      return;
    }
    er_store_sorted_swap(refs, root, swap_index);
    root = swap_index;
  }
}

static void er_store_sorted_heap_sort(const ErStoreKeySlot* slots, size_t* refs, size_t count) {
  size_t start;
  size_t end;

  if (count < 2u) {
    return;
  }
  start = (count - 2u) / 2u;
  while (1) {
    er_store_sorted_sift_down(slots, refs, start, count - 1u);
    if (start == 0u) {
      break;
    }
    --start;
  }
  end = count - 1u;
  while (end > 0u) {
    er_store_sorted_swap(refs, end, 0u);
    --end;
    er_store_sorted_sift_down(slots, refs, 0u, end);
  }
}

static int er_store_key_compare_search(const ErStoreKeySlot* slot, uint32_t index_id, const char* key,
                                       size_t key_len) {
  if (slot->index_id < index_id) {
    return -1;
  }
  if (slot->index_id > index_id) {
    return 1;
  }
  return er_store_key_compare_bytes(slot->key, slot->key_len, key, key_len);
}

//@optimizer-ignore-function sorted key view intentionally indexes arena-owned key slots
static int er_store_rebuild_sorted_keys(er_store_t* store) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t* refs = er_store_sorted_keys(store);
  size_t i;
  size_t count = 0u;

  if (store->sorted_key_dirty == 0) {
    return ER_OK;
  }
  for (i = 0u; i < store->key_capacity; ++i) {
    if (slots[i].used != 0u) {
      if (count >= store->key_capacity) {
        return ER_ERR_CORRUPT;
      }
      refs[count] = i;
      ++count;
    }
  }
  er_store_sorted_heap_sort(slots, refs, count);
  store->sorted_key_count = count;
  store->sorted_key_dirty = 0;
  return ER_OK;
}

//@optimizer-ignore-function binary search intentionally indexes sorted key references
static size_t er_store_sorted_lower_bound(er_store_t* store, uint32_t index_id, const char* key, size_t key_len) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t* refs = er_store_sorted_keys(store);
  size_t lo = 0u;
  size_t hi = store->sorted_key_count;
  size_t mid;

  while (lo < hi) {
    mid = lo + ((hi - lo) / 2u);
    if (er_store_key_compare_search(&slots[refs[mid]], index_id, key, key_len) < 0) {
      lo = mid + 1u;
    } else {
      hi = mid;
    }
  }
  return lo;
}

static int er_store_hash_bytes(const void* data, size_t len, uint8_t out_hash[ER_HASH_SIZE]) {
  if (er_blake3_hash_bytes((const uint8_t*)data, len, out_hash) == 0u) {
    return ER_ERR_BADARG;
  }
  return ER_OK;
}

//@optimizer-ignore-function record header fields are fixed 64-bit on-disk ABI values
static void er_store_encode_header(uint8_t header[ER_STORE_RECORD_HEADER_SIZE], uint16_t type,
                                   uint64_t seq, //@optimizer-ignore fixed record sequence is part of storage ABI
                                   uint64_t payload_len, //@optimizer-ignore fixed payload length is part of storage ABI
                                   const uint8_t payload_hash[ER_HASH_SIZE],
                                   const uint8_t prev_hash[ER_HASH_SIZE]) {
  er_store_zero(header, ER_STORE_RECORD_HEADER_SIZE);
  er_store_store32(&header[ER_STORE_HEADER_MAGIC_OFF], ER_STORE_RECORD_MAGIC);
  er_store_store16(&header[ER_STORE_HEADER_VERSION_OFF], ER_STORE_RECORD_VERSION);
  er_store_store16(&header[ER_STORE_HEADER_TYPE_OFF], type);
  er_store_store64(&header[ER_STORE_HEADER_SEQ_OFF], seq);
  er_store_store64(&header[ER_STORE_HEADER_PAYLOAD_LEN_OFF], payload_len);
  er_store_copy(&header[ER_STORE_HEADER_PAYLOAD_HASH_OFF], payload_hash, ER_HASH_SIZE);
  er_store_copy(&header[ER_STORE_HEADER_PREV_HASH_OFF], prev_hash, ER_HASH_SIZE);
  er_store_store32(&header[ER_STORE_HEADER_CRC_OFF], er_store_crc32(header, ER_STORE_RECORD_CRC_SIZE));
}

static int er_store_decode_header(const uint8_t header[ER_STORE_RECORD_HEADER_SIZE], ErStoreRecordInfo* info) {
  uint32_t expected_crc;
  uint32_t actual_crc;
  uint32_t magic;
  uint16_t version;

  magic = er_store_load32(&header[ER_STORE_HEADER_MAGIC_OFF]);
  version = er_store_load16(&header[ER_STORE_HEADER_VERSION_OFF]);
  if (magic != ER_STORE_RECORD_MAGIC || version != ER_STORE_RECORD_VERSION) {
    return ER_ERR_CORRUPT;
  }
  expected_crc = er_store_load32(&header[ER_STORE_HEADER_CRC_OFF]);
  actual_crc = er_store_crc32(header, ER_STORE_RECORD_CRC_SIZE);
  if (expected_crc != actual_crc) {
    return ER_ERR_CORRUPT;
  }
  info->type = er_store_load16(&header[ER_STORE_HEADER_TYPE_OFF]);
  info->seq = er_store_load64(&header[ER_STORE_HEADER_SEQ_OFF]);
  info->payload_len = er_store_load64(&header[ER_STORE_HEADER_PAYLOAD_LEN_OFF]);
  er_store_copy(info->payload_hash, &header[ER_STORE_HEADER_PAYLOAD_HASH_OFF], ER_HASH_SIZE);
  er_store_copy(info->prev_hash, &header[ER_STORE_HEADER_PREV_HASH_OFF], ER_HASH_SIZE);
  switch (info->type) {
    case ER_REC_BLOB:
    case ER_REC_INDEX_PUT:
    case ER_REC_TOMBSTONE:
    case ER_REC_BLOB_TYPE:
    case ER_REC_CONTENT_TYPE_DEFINE:
    case ER_REC_INDEX_DEFINE:
    case ER_REC_OBJECT_INDEX_PUT:
      return ER_OK;
    default:
      return ER_ERR_CORRUPT;
  }
}

static void er_store_record_hash(const uint8_t header[ER_STORE_RECORD_HEADER_SIZE], uint8_t out[ER_HASH_SIZE]) {
  (void)er_blake3_hash_bytes(header, ER_STORE_RECORD_HEADER_SIZE, out);
}

static int er_store_write_superblock(er_store_t* store) {
  uint8_t superblock[ER_STORE_SUPERBLOCK_SIZE];
  int rc;

  er_store_zero(superblock, sizeof(superblock));
  superblock[ER_BYTE0] = ER_STORE_MAGIC_0;
  superblock[ER_BYTE1] = ER_STORE_MAGIC_1;
  superblock[ER_BYTE2] = ER_STORE_MAGIC_2;
  superblock[ER_BYTE3] = ER_STORE_MAGIC_3;
  superblock[ER_BYTE4] = ER_STORE_MAGIC_4;
  superblock[ER_BYTE5] = ER_STORE_MAGIC_5;
  superblock[ER_BYTE6] = ER_STORE_MAGIC_6;
  superblock[ER_BYTE7] = ER_STORE_MAGIC_7;
  er_store_store32(&superblock[ER_STORE_SUPER_VERSION_OFF], ER_STORE_VERSION);
  er_store_store32(&superblock[ER_STORE_SUPER_HEADER_SIZE_OFF], ER_STORE_SUPERBLOCK_SIZE);
  er_store_store64(&superblock[ER_STORE_SUPER_LOG_START_OFF], store->log_start);
  er_store_store64(&superblock[ER_STORE_SUPER_LOG_END_OFF], store->log_end);
  er_store_copy(&superblock[ER_STORE_SUPER_ROOT_HASH_OFF], store->last_record_hash, ER_HASH_SIZE);
  er_store_store32(&superblock[ER_STORE_SUPER_CRC_OFF], er_store_crc32(superblock, ER_STORE_SUPER_CRC_OFF));
  rc = store->io.write_at(store->io.ctx, 0u, superblock, sizeof(superblock));
  if (rc != 0) {
    return ER_ERR_IO;
  }
  rc = store->io.sync(store->io.ctx);
  if (rc != 0) {
    return ER_ERR_IO;
  }
  return ER_OK;
}

//@optimizer-ignore-function superblock offsets and IO size mirror fixed 64-bit record log fields
static int er_store_read_superblock(er_store_t* store, uint64_t io_size) {
  uint8_t superblock[ER_STORE_SUPERBLOCK_SIZE];
  uint32_t expected_crc;
  uint32_t actual_crc;

  if (io_size < ER_STORE_SUPERBLOCK_SIZE) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, 0u, superblock, sizeof(superblock)) != 0) {
    return ER_ERR_IO;
  }
  if (superblock[ER_BYTE0] != ER_STORE_MAGIC_0 || superblock[ER_BYTE1] != ER_STORE_MAGIC_1 ||
      superblock[ER_BYTE2] != ER_STORE_MAGIC_2 || superblock[ER_BYTE3] != ER_STORE_MAGIC_3 ||
      superblock[ER_BYTE4] != ER_STORE_MAGIC_4 || superblock[ER_BYTE5] != ER_STORE_MAGIC_5 ||
      superblock[ER_BYTE6] != ER_STORE_MAGIC_6 || superblock[ER_BYTE7] != ER_STORE_MAGIC_7) {
    return ER_ERR_CORRUPT;
  }
  expected_crc = er_store_load32(&superblock[ER_STORE_SUPER_CRC_OFF]);
  actual_crc = er_store_crc32(superblock, ER_STORE_SUPER_CRC_OFF);
  if (expected_crc != actual_crc ||
      er_store_load32(&superblock[ER_STORE_SUPER_VERSION_OFF]) != ER_STORE_VERSION ||
      er_store_load32(&superblock[ER_STORE_SUPER_HEADER_SIZE_OFF]) != ER_STORE_SUPERBLOCK_SIZE) {
    return ER_ERR_CORRUPT;
  }
  store->log_start = er_store_load64(&superblock[ER_STORE_SUPER_LOG_START_OFF]);
  if (store->log_start != ER_STORE_SUPERBLOCK_SIZE || store->log_start > io_size) {
    return ER_ERR_CORRUPT;
  }
  return ER_OK;
}

//@optimizer-ignore-function payload offsets and lengths mirror fixed 64-bit record header fields
static int er_store_hash_payload(er_store_t* store,
                                 uint64_t payload_off, //@optimizer-ignore fixed payload offset is part of storage ABI
                                 uint64_t payload_len, //@optimizer-ignore fixed payload length is part of storage ABI
                                 uint8_t out_hash[ER_HASH_SIZE]) {
  enum { ER_STORE_VERIFY_CHUNK = 512u };
  uint8_t chunk[ER_STORE_VERIFY_CHUNK];
  ErBlake3Hasher hasher;
  uint64_t remaining = payload_len;
  uint64_t off = payload_off;
  size_t take;

  er_blake3_init(&hasher);
  while (remaining != 0u) {
    take = remaining > ER_STORE_VERIFY_CHUNK ? ER_STORE_VERIFY_CHUNK : (size_t)remaining;
    if (store->io.read_at(store->io.ctx, off, chunk, take) != 0) {
      return ER_ERR_IO;
    }
    if (er_blake3_update(&hasher, chunk, take) == 0u) {
      return ER_ERR_CORRUPT;
    }
    off += take;
    remaining -= take;
  }
  if (er_blake3_final(&hasher, out_hash) == 0u) {
    return ER_ERR_CORRUPT;
  }
  return ER_OK;
}

//@optimizer-ignore-function index payload offsets and lengths mirror fixed 64-bit record header fields
static int er_store_apply_index_payload(er_store_t* store, uint64_t payload_off, uint64_t payload_len) {
  uint8_t payload[ER_STORE_INDEX_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY];
  uint32_t index_id;
  size_t key_off;
  uint16_t key_len;

  if (payload_len < ER_STORE_INDEX_OLD_PAYLOAD_OVERHEAD ||
      payload_len > (ER_STORE_INDEX_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY)) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, (size_t)payload_len) != 0) {
    return ER_ERR_IO;
  }
  if (payload_len <= (ER_STORE_INDEX_OLD_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY)) {
    key_len = er_store_load16(payload);
    if (payload_len == ((uint64_t)ER_STORE_INDEX_KEY_LEN_SIZE + (uint64_t)key_len + ER_HASH_SIZE)) {
      index_id = ER_STORE_INDEX_DEFAULT;
      key_off = ER_STORE_INDEX_KEY_LEN_SIZE;
    } else {
      index_id = er_store_load32(payload);
      key_len = er_store_load16(&payload[ER_STORE_INDEX_ID_SIZE]);
      key_off = ER_STORE_INDEX_ID_SIZE + ER_STORE_INDEX_KEY_LEN_SIZE;
    }
  } else {
    return ER_ERR_CORRUPT;
  }
  if (key_len == 0u || key_len > ER_STORE_MAX_KEY ||
      payload_len != ((uint64_t)key_off + (uint64_t)key_len + ER_HASH_SIZE)) {
    return ER_ERR_CORRUPT;
  }
  return er_store_insert_key_ex(store, index_id, (const char*)&payload[key_off], key_len,
                                &payload[key_off + key_len]);
}

//@optimizer-ignore-function blob type records use fixed 64-bit payload offsets from the log
static int er_store_apply_blob_type_payload(er_store_t* store, uint64_t payload_off, uint64_t payload_len) {
  uint8_t payload[ER_STORE_TYPE_PAYLOAD_SIZE];

  if (payload_len != ER_STORE_TYPE_PAYLOAD_SIZE) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, sizeof(payload)) != 0) {
    return ER_ERR_IO;
  }
  return er_store_set_blob_type(store, &payload[ER_STORE_TYPE_HASH_OFF], er_store_load32(payload));
}

//@optimizer-ignore-function type definition records use fixed 64-bit payload offsets from the log
static int er_store_apply_type_define_payload(er_store_t* store, uint64_t payload_off, uint64_t payload_len) {
  uint8_t payload[ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME];
  uint16_t name_len;

  if (payload_len < ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE ||
      payload_len > (ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME)) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, (size_t)payload_len) != 0) {
    return ER_ERR_IO;
  }
  name_len = er_store_load16(&payload[ER_STORE_DEFINE_NAME_LEN_OFF]);
  if (name_len == 0u || name_len > ER_STORE_MAX_NAME ||
      payload_len != ((uint64_t)ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + name_len)) {
    return ER_ERR_CORRUPT;
  }
  return er_store_insert_type(store, er_store_load32(payload),
                              (const char*)&payload[ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE], name_len);
}

//@optimizer-ignore-function index definition records use fixed 64-bit payload offsets from the log
static int er_store_apply_index_define_payload(er_store_t* store, uint64_t payload_off, uint64_t payload_len) {
  uint8_t payload[ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME];
  uint16_t name_len;

  if (payload_len < ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE ||
      payload_len > (ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME)) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, (size_t)payload_len) != 0) {
    return ER_ERR_IO;
  }
  name_len = er_store_load16(&payload[ER_STORE_INDEX_DEFINE_NAME_LEN_OFF]);
  if (name_len == 0u || name_len > ER_STORE_MAX_NAME ||
      payload_len != ((uint64_t)ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + name_len)) {
    return ER_ERR_CORRUPT;
  }
  return er_store_insert_index_def(store, er_store_load32(payload),
                                   er_store_load32(&payload[ER_STORE_INDEX_DEFINE_CONTENT_TYPE_OFF]),
                                   (const char*)&payload[ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE], name_len);
}

//@optimizer-ignore-function projection records use fixed hash bytes and fixed 64-bit value sizes in canonical encoding
static int er_store_apply_project_payload(er_store_t* store, uint64_t payload_off, uint64_t payload_len) {
  uint8_t payload[ER_STORE_PROJECT_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_KEY];
  uint32_t index_id;
  uint32_t value_kind;
  uint32_t content_type;
  uint64_t value_size;
  uint16_t key_len;
  size_t hash_off;

  if (payload_len < ER_STORE_PROJECT_FIXED_PAYLOAD_SIZE ||
      payload_len > (ER_STORE_PROJECT_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_KEY)) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, (size_t)payload_len) != 0) {
    return ER_ERR_IO;
  }
  index_id = er_store_load32(&payload[ER_STORE_PROJECT_INDEX_ID_OFF]);
  value_kind = er_store_load32(&payload[ER_STORE_PROJECT_VALUE_KIND_OFF]);
  content_type = er_store_load32(&payload[ER_STORE_PROJECT_CONTENT_TYPE_OFF]);
  value_size = er_store_load64(&payload[ER_STORE_PROJECT_VALUE_SIZE_OFF]);
  key_len = er_store_load16(&payload[ER_STORE_PROJECT_KEY_LEN_OFF]);
  hash_off = ER_STORE_PROJECT_KEY_OFF + key_len;
  if (key_len == 0u || key_len > ER_STORE_MAX_KEY || hash_off + ER_HASH_SIZE != payload_len ||
      value_kind == ER_STORE_VALUE_UNKNOWN) {
    return ER_ERR_CORRUPT;
  }
  return er_store_insert_key_meta(store, index_id, (const char*)&payload[ER_STORE_PROJECT_KEY_OFF], key_len,
                                  &payload[hash_off], value_kind, content_type, value_size);
}

//@optimizer-ignore-function log replay validates fixed 64-bit record offsets and sequence fields
static int er_store_replay(er_store_t* store, uint64_t io_size, int rebuild, int truncate_bad) {
  uint8_t header[ER_STORE_RECORD_HEADER_SIZE];
  uint8_t zero_hash[ER_HASH_SIZE];
  uint8_t expected_prev[ER_HASH_SIZE];
  uint8_t record_hash[ER_HASH_SIZE];
  uint8_t payload_hash[ER_HASH_SIZE];
  uint64_t off;
  uint64_t payload_off;
  uint64_t next_off;
  uint64_t valid_end;
  uint64_t expected_seq;
  ErStoreRecordInfo info;
  int rc;

  er_store_zero(zero_hash, sizeof(zero_hash));
  er_store_zero(expected_prev, sizeof(expected_prev));
  off = store->log_start;
  valid_end = store->log_start;
  expected_seq = 1u;
  if (rebuild != 0) {
    store->blob_count = 0u;
    store->key_count = 0u;
    store->sorted_key_count = 0u;
    store->sorted_key_dirty = 1;
    store->type_count = 0u;
    store->index_count = 0u;
    er_store_zero(store->blob_slots, sizeof(ErStoreBlobSlot) * store->blob_capacity);
    er_store_zero(store->key_slots, sizeof(ErStoreKeySlot) * store->key_capacity);
    er_store_zero(store->sorted_key_slots, sizeof(size_t) * store->key_capacity);
    er_store_zero(store->type_slots, sizeof(ErStoreTypeSlot) * store->type_capacity);
    er_store_zero(store->index_slots, sizeof(ErStoreIndexSlot) * store->index_capacity);
    store->cache_used = 0u;
  }

  while (off < io_size) {
    if ((io_size - off) < ER_STORE_RECORD_HEADER_SIZE) {
      break;
    }
    if (store->io.read_at(store->io.ctx, off, header, sizeof(header)) != 0) {
      return ER_ERR_IO;
    }
    rc = er_store_decode_header(header, &info);
    if (rc != ER_OK) {
      break;
    }
    if (info.seq != expected_seq || !er_store_equal(info.prev_hash, expected_prev, ER_HASH_SIZE)) {
      break;
    }
    payload_off = off + ER_STORE_RECORD_HEADER_SIZE;
    if (er_store_add_u64(payload_off, info.payload_len, &next_off) != ER_OK || next_off > io_size) {
      break;
    }
    rc = er_store_hash_payload(store, payload_off, info.payload_len, payload_hash);
    if (rc != ER_OK) {
      return rc;
    }
    if (!er_store_equal(payload_hash, info.payload_hash, ER_HASH_SIZE)) {
      break;
    }
    if (rebuild != 0) {
      switch (info.type) {
        case ER_REC_BLOB:
          rc = er_store_insert_blob(store, info.payload_hash, payload_off, info.payload_len);
          break;
        case ER_REC_INDEX_PUT:
          rc = er_store_apply_index_payload(store, payload_off, info.payload_len);
          break;
        case ER_REC_BLOB_TYPE:
          rc = er_store_apply_blob_type_payload(store, payload_off, info.payload_len);
          break;
        case ER_REC_CONTENT_TYPE_DEFINE:
          rc = er_store_apply_type_define_payload(store, payload_off, info.payload_len);
          break;
        case ER_REC_INDEX_DEFINE:
          rc = er_store_apply_index_define_payload(store, payload_off, info.payload_len);
          break;
        case ER_REC_OBJECT_INDEX_PUT:
          rc = er_store_apply_project_payload(store, payload_off, info.payload_len);
          break;
        case ER_REC_TOMBSTONE:
          rc = ER_OK;
          break;
        default:
          rc = ER_ERR_CORRUPT;
          break;
      }
      if (rc != ER_OK) {
        return rc;
      }
    }
    er_store_record_hash(header, record_hash);
    er_store_copy(expected_prev, record_hash, ER_HASH_SIZE);
    valid_end = next_off;
    off = next_off;
    ++expected_seq;
  }

  if (truncate_bad != 0 && valid_end != io_size) {
    if (store->io.truncate(store->io.ctx, valid_end) != 0) {
      return ER_ERR_IO;
    }
  }
  store->log_end = valid_end;
  store->next_seq = expected_seq;
  if (valid_end == store->log_start) {
    er_store_copy(store->last_record_hash, zero_hash, ER_HASH_SIZE);
  } else {
    er_store_copy(store->last_record_hash, expected_prev, ER_HASH_SIZE);
  }
  return ER_OK;
}

//@optimizer-ignore-function IO callbacks use fixed 64-bit record log offsets
static int er_store_validate_io(er_io_t* io) {
  if (io == (er_io_t*)0 || io->read_at == (int (*)(void*, uint64_t, void*, size_t))0 ||
      io->write_at == (int (*)(void*, uint64_t, const void*, size_t))0 ||
      io->sync == (int (*)(void*))0 || io->size == (int (*)(void*, uint64_t*))0 ||
      io->truncate == (int (*)(void*, uint64_t))0) {
    return ER_ERR_BADARG;
  }
  return ER_OK;
}

static size_t er_store_floor_power2(size_t value) {
  size_t out = 1u;

  while (out <= (value >> 1u)) {
    out <<= 1u;
  }
  return out;
}

//@optimizer-ignore-function arena byte accounting uses fixed 64-bit storage-layout sizes
static int er_store_checked_bytes(size_t count, size_t size, uint64_t* out) {
  if (count != 0u && size > ((size_t)-1) / count) {
    return ER_ERR_TOOBIG;
  }
  return er_store_size_to_u64(count * size, out);
}

//@optimizer-ignore-function arena capacity planning uses fixed 64-bit storage-layout sizes
static int er_store_choose_capacity(size_t requested, size_t fallback, size_t min_value, size_t slot_size,
                                    uint64_t available, size_t* out) {
  size_t cap;
  uint64_t bytes;

  cap = requested != 0u ? requested : fallback;
  cap = er_store_floor_power2(er_math_max_size(cap, min_value));
  while (cap >= min_value) {
    if (er_store_checked_bytes(cap, slot_size, &bytes) == ER_OK && bytes <= available) {
      *out = cap;
      return ER_OK;
    }
    cap >>= 1u;
  }
  return ER_ERR_NOSPACE;
}

static int er_store_prepare_arena(er_store_t* store, void* arena, size_t arena_len,
                                  const er_store_config_t* config) {
  uint64_t base;
  uint64_t cursor;
  uint64_t end;
  uint64_t blob_bytes;
  uint64_t key_bytes;
  uint64_t sorted_key_bytes;
  uint64_t type_bytes;
  uint64_t index_bytes;
  uint64_t cache_bytes;
  uint64_t used_bytes;
  size_t requested_blob_slots = 0u;
  size_t requested_key_slots = 0u;
  size_t requested_type_slots = 0u;
  size_t requested_index_slots = 0u;
  size_t requested_cache_bytes = 0u;

  if (arena == (void*)0) {
    return ER_ERR_BADARG;
  }
  if (config != (const er_store_config_t*)0) {
    requested_blob_slots = config->blob_slots;
    requested_key_slots = config->key_slots;
    requested_type_slots = config->type_slots;
    requested_index_slots = config->index_slots;
    requested_cache_bytes = config->cache_bytes;
  }
  if (er_store_size_to_u64(arena_len, &end) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  base = (uint64_t)(uintptr_t)arena;
  cursor = er_store_align_up(base, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end) {
    return ER_ERR_NOSPACE;
  }
  if (er_store_choose_capacity(requested_blob_slots, ER_STORE_BLOB_CAPACITY, ER_STORE_BLOB_CAPACITY,
                               sizeof(ErStoreBlobSlot), end - used_bytes, &store->blob_capacity) != ER_OK ||
      er_store_checked_bytes(store->blob_capacity, sizeof(ErStoreBlobSlot), &blob_bytes) != ER_OK) {
    return ER_ERR_NOSPACE;
  }
  if ((cursor - base) > end || blob_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->blob_slots = (void*)(uintptr_t)cursor;
  cursor += blob_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end) {
    return ER_ERR_NOSPACE;
  }
  if (er_store_choose_capacity(requested_key_slots, ER_STORE_INDEX_CAPACITY, ER_STORE_INDEX_CAPACITY,
                               sizeof(ErStoreKeySlot), end - used_bytes, &store->key_capacity) != ER_OK ||
      er_store_checked_bytes(store->key_capacity, sizeof(ErStoreKeySlot), &key_bytes) != ER_OK) {
    return ER_ERR_NOSPACE;
  }
  if ((cursor - base) > end || key_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->key_slots = (void*)(uintptr_t)cursor;
  cursor += key_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end || er_store_checked_bytes(store->key_capacity, sizeof(size_t), &sorted_key_bytes) != ER_OK) {
    return ER_ERR_NOSPACE;
  }
  if (sorted_key_bytes > (end - used_bytes)) {
    return ER_ERR_NOSPACE;
  }
  store->sorted_key_slots = (void*)(uintptr_t)cursor;
  cursor += sorted_key_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end) {
    return ER_ERR_NOSPACE;
  }
  if (er_store_choose_capacity(requested_type_slots, ER_STORE_TYPE_CAPACITY, ER_STORE_TYPE_CAPACITY,
                               sizeof(ErStoreTypeSlot), end - used_bytes, &store->type_capacity) != ER_OK ||
      er_store_checked_bytes(store->type_capacity, sizeof(ErStoreTypeSlot), &type_bytes) != ER_OK) {
    return ER_ERR_NOSPACE;
  }
  if (type_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->type_slots = (void*)(uintptr_t)cursor;
  cursor += type_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end) {
    return ER_ERR_NOSPACE;
  }
  if (er_store_choose_capacity(requested_index_slots, ER_STORE_INDEX_DEF_CAPACITY, ER_STORE_INDEX_DEF_CAPACITY,
                               sizeof(ErStoreIndexSlot), end - used_bytes, &store->index_capacity) != ER_OK ||
      er_store_checked_bytes(store->index_capacity, sizeof(ErStoreIndexSlot), &index_bytes) != ER_OK) {
    return ER_ERR_NOSPACE;
  }
  if (index_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->index_slots = (void*)(uintptr_t)cursor;
  cursor += index_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  used_bytes = cursor - base;
  if (used_bytes > end) {
    return ER_ERR_NOSPACE;
  }
  cache_bytes = end - used_bytes;
  if (requested_cache_bytes != 0u) {
    if (er_store_size_to_u64(requested_cache_bytes, &cache_bytes) != ER_OK || cache_bytes > (end - used_bytes)) {
      return ER_ERR_NOSPACE;
    }
  }
  store->cache = (uint8_t*)(uintptr_t)cursor;
  store->cache_len = (size_t)cache_bytes;
  store->cache_used = 0u;
  er_store_zero(store->blob_slots, (size_t)blob_bytes);
  er_store_zero(store->key_slots, (size_t)key_bytes);
  er_store_zero(store->sorted_key_slots, (size_t)sorted_key_bytes);
  er_store_zero(store->type_slots, (size_t)type_bytes);
  er_store_zero(store->index_slots, (size_t)index_bytes);
  if (store->cache_len != 0u) {
    er_store_zero(store->cache, store->cache_len);
  }
  return ER_OK;
}

//@optimizer-ignore-function append computes fixed 64-bit record log offsets
static int er_store_append_record(er_store_t* store, uint16_t type, const void* payload,
                                  size_t payload_len, uint8_t payload_hash[ER_HASH_SIZE],
                                  uint64_t* out_payload_off) {
  uint8_t header[ER_STORE_RECORD_HEADER_SIZE];
  uint8_t record_hash[ER_HASH_SIZE];
  uint64_t payload_len_u64;
  uint64_t payload_off;
  uint64_t new_end;

  if (er_store_size_to_u64(payload_len, &payload_len_u64) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  if (er_store_add_u64(store->log_end, ER_STORE_RECORD_HEADER_SIZE, &payload_off) != ER_OK ||
      er_store_add_u64(payload_off, payload_len_u64, &new_end) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  er_store_encode_header(header, type, store->next_seq, payload_len_u64, payload_hash, store->last_record_hash);
  if (store->io.write_at(store->io.ctx, store->log_end, header, sizeof(header)) != 0) {
    return ER_ERR_IO;
  }
  if (payload_len != 0u && store->io.write_at(store->io.ctx, payload_off, payload, payload_len) != 0) {
    return ER_ERR_IO;
  }
  if (store->io.sync(store->io.ctx) != 0) {
    return ER_ERR_IO;
  }
  er_store_record_hash(header, record_hash);
  er_store_copy(store->last_record_hash, record_hash, ER_HASH_SIZE);
  store->log_end = new_end;
  ++store->next_seq;
  if (out_payload_off != (uint64_t*)0) {
    *out_payload_off = payload_off;
  }
  return er_store_write_superblock(store);
}

//@optimizer-ignore-function open scans fixed 64-bit record log offsets from IO size
int er_store_open_config(er_store_t* store, er_io_t io, void* arena, size_t arena_len,
                         const er_store_config_t* config) {
  uint64_t io_size;
  int rc;

  if (store == (er_store_t*)0 || er_store_validate_io(&io) != ER_OK) {
    return ER_ERR_BADARG;
  }
  er_store_zero(store, sizeof(*store));
  store->io = io;
  rc = er_store_prepare_arena(store, arena, arena_len, config);
  if (rc != ER_OK) {
    return rc;
  }
  if (store->io.size(store->io.ctx, &io_size) != 0) {
    return ER_ERR_IO;
  }
  if (io_size == 0u) {
    store->log_start = ER_STORE_SUPERBLOCK_SIZE;
    store->log_end = ER_STORE_SUPERBLOCK_SIZE;
    store->next_seq = 1u;
    er_store_zero(store->last_record_hash, ER_HASH_SIZE);
    return er_store_write_superblock(store);
  }
  rc = er_store_read_superblock(store, io_size);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_replay(store, io_size, 1, 1);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_rebuild_sorted_keys(store);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_write_superblock(store);
}

int er_store_open(er_store_t* store, er_io_t io, void* arena, size_t arena_len) {
  return er_store_open_config(store, io, arena, arena_len, (const er_store_config_t*)0);
}

int er_store_close(er_store_t* store) {
  if (store == (er_store_t*)0) {
    return ER_ERR_BADARG;
  }
  return er_store_write_superblock(store);
}

int er_store_stats(er_store_t* store, er_store_stats_t* out_stats) {
  if (store == (er_store_t*)0 || out_stats == (er_store_stats_t*)0) {
    return ER_ERR_BADARG;
  }
  out_stats->blob_slots = store->blob_capacity;
  out_stats->key_slots = store->key_capacity;
  out_stats->type_slots = store->type_capacity;
  out_stats->index_slots = store->index_capacity;
  out_stats->blob_count = store->blob_count;
  out_stats->key_count = store->key_count;
  out_stats->type_count = store->type_count;
  out_stats->index_count = store->index_count;
  out_stats->cache_bytes = store->cache_len;
  out_stats->cache_used = store->cache_used;
  out_stats->cache_hits = store->cache_hits;
  out_stats->cache_misses = store->cache_misses;
  out_stats->cache_admissions = store->cache_admissions;
  out_stats->cache_rejects = store->cache_rejects;
  return ER_OK;
}

//@optimizer-ignore-function blob append computes fixed 64-bit payload offsets and lengths
static int er_store_append_blob_type(er_store_t* store, uint32_t content_type, const uint8_t hash[ER_HASH_SIZE]) {
  uint8_t payload[ER_STORE_TYPE_PAYLOAD_SIZE];
  uint8_t payload_hash[ER_HASH_SIZE];
  int rc;

  if (content_type == ER_STORE_TYPE_RAW) {
    return ER_OK;
  }
  er_store_store32(payload, content_type);
  er_store_copy(&payload[ER_STORE_TYPE_HASH_OFF], hash, ER_HASH_SIZE);
  rc = er_store_hash_bytes(payload, sizeof(payload), payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_BLOB_TYPE, payload, sizeof(payload), payload_hash, (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_set_blob_type(store, hash, content_type);
}

//@optimizer-ignore-function blob append computes fixed 64-bit payload offsets and lengths
int er_store_put_typed_blob(er_store_t* store, uint32_t content_type, const void* data, size_t len,
                            uint8_t out_hash[ER_HASH_SIZE]) {
  uint8_t hash[ER_HASH_SIZE];
  size_t slot;
  uint64_t payload_off;
  uint64_t payload_len;
  int rc;

  if (store == (er_store_t*)0 || out_hash == (uint8_t*)0 || (len != 0u && data == (const void*)0)) {
    return ER_ERR_BADARG;
  }
  rc = er_store_hash_bytes(data, len, hash);
  if (rc != ER_OK) {
    return rc;
  }
  er_store_copy(out_hash, hash, ER_HASH_SIZE);
  rc = er_store_find_blob(store, hash, &slot);
  if (rc == ER_OK) {
    if (content_type != ER_STORE_TYPE_RAW) {
      if (er_store_blobs(store)[slot].content_type == content_type) {
        return ER_OK;
      }
      return er_store_append_blob_type(store, content_type, hash);
    }
    return ER_OK;
  }
  if (rc != ER_ERR_NOTFOUND) {
    return rc;
  }
  if (er_store_size_to_u64(len, &payload_len) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  rc = er_store_append_record(store, ER_REC_BLOB, data, len, hash, &payload_off);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_insert_blob(store, hash, payload_off, payload_len);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_find_blob(store, hash, &slot);
  if (rc == ER_OK) {
    er_store_cache_blob(store, slot, data, len);
  }
  if (content_type != ER_STORE_TYPE_RAW) {
    return er_store_append_blob_type(store, content_type, hash);
  }
  return ER_OK;
}

int er_store_put_blob(er_store_t* store, const void* data, size_t len, uint8_t out_hash[ER_HASH_SIZE]) {
  return er_store_put_typed_blob(store, ER_STORE_TYPE_RAW, data, len, out_hash);
}

//@optimizer-ignore-function blob lookup indexes fixed-capacity hash slots by content hash
int er_store_get_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], void* out, size_t out_cap,
                      size_t* out_len) {
  ErStoreBlobSlot* slots;
  uint8_t check_hash[ER_HASH_SIZE];
  size_t slot;
  int rc;

  if (store == (er_store_t*)0 || hash == (const uint8_t*)0 || out_len == (size_t*)0 ||
      (out_cap != 0u && out == (void*)0)) {
    return ER_ERR_BADARG;
  }
  rc = er_store_find_blob(store, hash, &slot);
  if (rc != ER_OK) {
    return rc;
  }
  slots = er_store_blobs(store);
  if (slots[slot].size > (uint64_t)out_cap) {
    return ER_ERR_TOOBIG;
  }
  if (slots[slot].cache_len == (size_t)slots[slot].size) {
    ++store->cache_hits;
    er_store_copy(out, &store->cache[slots[slot].cache_off], slots[slot].cache_len);
  } else {
    ++store->cache_misses;
    if (slots[slot].size != 0u && store->io.read_at(store->io.ctx, slots[slot].offset, out,
                                                     (size_t)slots[slot].size) != 0) {
      return ER_ERR_IO;
    }
    er_store_cache_blob(store, slot, out, (size_t)slots[slot].size);
  }
  rc = er_store_hash_bytes(out, (size_t)slots[slot].size, check_hash);
  if (rc != ER_OK) {
    return rc;
  }
  if (!er_store_equal(check_hash, hash, ER_HASH_SIZE)) {
    return ER_ERR_CORRUPT;
  }
  *out_len = (size_t)slots[slot].size;
  return ER_OK;
}

int er_store_get_blob_info(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], er_blob_t* out_blob) {
  ErStoreBlobSlot* slots;
  size_t slot;
  int rc;

  if (store == (er_store_t*)0 || hash == (const uint8_t*)0 || out_blob == (er_blob_t*)0) {
    return ER_ERR_BADARG;
  }
  rc = er_store_find_blob(store, hash, &slot);
  if (rc != ER_OK) {
    return rc;
  }
  slots = er_store_blobs(store);
  er_store_copy(out_blob->hash, slots[slot].hash, ER_HASH_SIZE);
  out_blob->content_type = slots[slot].content_type;
  out_blob->offset = slots[slot].offset;
  out_blob->size = slots[slot].size;
  return ER_OK;
}

//@optimizer-ignore-function object manifests use fixed hash bytes and fixed 64-bit size fields in canonical encoding
static int er_store_get_object_size(er_store_t* store, const uint8_t object_hash[ER_HASH_SIZE],
                                    uint64_t* out_size) {
  uint8_t manifest[ER_STORE_OBJECT_FIRST_HASH_OFF + (ER_STORE_MAX_CHUNKS * ER_HASH_SIZE)];
  er_blob_t info;
  size_t manifest_len = 0u;
  uint64_t total_size;
  uint64_t chunk_size;
  uint32_t chunk_count;
  int rc;

  if (out_size == (uint64_t*)0) {
    return ER_ERR_BADARG;
  }
  rc = er_store_get_blob_info(store, object_hash, &info);
  if (rc != ER_OK) {
    return rc;
  }
  if (info.content_type != ER_STORE_TYPE_OBJECT_MANIFEST || info.size > sizeof(manifest)) {
    return ER_ERR_CORRUPT;
  }
  rc = er_store_get_blob(store, object_hash, manifest, sizeof(manifest), &manifest_len);
  if (rc != ER_OK) {
    return rc;
  }
  if (manifest_len < ER_STORE_OBJECT_FIRST_HASH_OFF) {
    return ER_ERR_CORRUPT;
  }
  total_size = er_store_load64(&manifest[ER_STORE_OBJECT_TOTAL_SIZE_OFF]);
  chunk_size = er_store_load64(&manifest[ER_STORE_OBJECT_CHUNK_SIZE_OFF]);
  chunk_count = er_store_load32(&manifest[ER_STORE_OBJECT_CHUNK_COUNT_OFF]);
  if (chunk_size == 0u || chunk_count > ER_STORE_MAX_CHUNKS ||
      manifest_len != (ER_STORE_OBJECT_FIRST_HASH_OFF + ((size_t)chunk_count * ER_HASH_SIZE))) {
    return ER_ERR_CORRUPT;
  }
  *out_size = total_size;
  return ER_OK;
}

//@optimizer-ignore-function object manifests use fixed 64-bit size fields in their canonical encoding
int er_store_put_object(er_store_t* store, const void* data, size_t len, size_t chunk_size,
                        uint8_t out_object_hash[ER_HASH_SIZE]) {
  uint8_t manifest[ER_STORE_OBJECT_FIRST_HASH_OFF + (ER_STORE_MAX_CHUNKS * ER_HASH_SIZE)];
  const uint8_t* bytes = (const uint8_t*)data;
  size_t chunk_count;
  size_t manifest_len;
  size_t chunk_index;
  size_t off;
  size_t take;
  uint64_t len_u64;
  uint64_t chunk_size_u64;
  uint8_t chunk_hash[ER_HASH_SIZE];
  int rc;

  if (store == (er_store_t*)0 || out_object_hash == (uint8_t*)0 || chunk_size == 0u ||
      (len != 0u && data == (const void*)0)) {
    return ER_ERR_BADARG;
  }
  if (len != 0u && chunk_size > (((size_t)-1) - len + 1u)) {
    return ER_ERR_TOOBIG;
  }
  chunk_count = len == 0u ? 0u : ((len + chunk_size - 1u) / chunk_size);
  if (chunk_count > ER_STORE_MAX_CHUNKS) {
    return ER_ERR_TOOBIG;
  }
  if (er_store_size_to_u64(len, &len_u64) != ER_OK || er_store_size_to_u64(chunk_size, &chunk_size_u64) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  er_store_zero(manifest, sizeof(manifest));
  er_store_store64(&manifest[ER_STORE_OBJECT_TOTAL_SIZE_OFF], len_u64);
  er_store_store64(&manifest[ER_STORE_OBJECT_CHUNK_SIZE_OFF], chunk_size_u64);
  er_store_store32(&manifest[ER_STORE_OBJECT_CHUNK_COUNT_OFF], (uint32_t)chunk_count);
  off = 0u;
  for (chunk_index = 0u; chunk_index < chunk_count; ++chunk_index) {
    take = (len - off) > chunk_size ? chunk_size : (len - off);
    rc = er_store_put_blob(store, &bytes[off], take, chunk_hash);
    if (rc != ER_OK) {
      return rc;
    }
    er_store_copy(&manifest[ER_STORE_OBJECT_FIRST_HASH_OFF + (chunk_index * ER_HASH_SIZE)], chunk_hash,
                  ER_HASH_SIZE);
    off += take;
  }
  manifest_len = ER_STORE_OBJECT_FIRST_HASH_OFF + (chunk_count * ER_HASH_SIZE);
  return er_store_put_typed_blob(store, ER_STORE_TYPE_OBJECT_MANIFEST, manifest, manifest_len, out_object_hash);
}

//@optimizer-ignore-function object manifests use fixed 64-bit size fields in their canonical encoding
int er_store_get_object(er_store_t* store, const uint8_t object_hash[ER_HASH_SIZE], void* out, size_t out_cap,
                        size_t* out_len) {
  uint8_t manifest[ER_STORE_OBJECT_FIRST_HASH_OFF + (ER_STORE_MAX_CHUNKS * ER_HASH_SIZE)];
  er_blob_t info;
  uint64_t total_size;
  uint64_t chunk_size;
  uint32_t chunk_count;
  size_t manifest_len = 0u;
  size_t chunk_index;
  size_t out_off = 0u;
  size_t got_len = 0u;
  size_t expected_len;
  int rc;

  if (store == (er_store_t*)0 || object_hash == (const uint8_t*)0 || out_len == (size_t*)0 ||
      (out_cap != 0u && out == (void*)0)) {
    return ER_ERR_BADARG;
  }
  rc = er_store_get_blob_info(store, object_hash, &info);
  if (rc != ER_OK) {
    return rc;
  }
  if (info.content_type != ER_STORE_TYPE_OBJECT_MANIFEST || info.size > sizeof(manifest)) {
    return ER_ERR_CORRUPT;
  }
  rc = er_store_get_blob(store, object_hash, manifest, sizeof(manifest), &manifest_len);
  if (rc != ER_OK) {
    return rc;
  }
  if (manifest_len < ER_STORE_OBJECT_FIRST_HASH_OFF) {
    return ER_ERR_CORRUPT;
  }
  total_size = er_store_load64(&manifest[ER_STORE_OBJECT_TOTAL_SIZE_OFF]);
  chunk_size = er_store_load64(&manifest[ER_STORE_OBJECT_CHUNK_SIZE_OFF]);
  chunk_count = er_store_load32(&manifest[ER_STORE_OBJECT_CHUNK_COUNT_OFF]);
  if (chunk_size == 0u || chunk_count > ER_STORE_MAX_CHUNKS ||
      manifest_len != (ER_STORE_OBJECT_FIRST_HASH_OFF + ((size_t)chunk_count * ER_HASH_SIZE))) {
    return ER_ERR_CORRUPT;
  }
  if (total_size > (uint64_t)out_cap || total_size > (uint64_t)((size_t)-1)) {
    return ER_ERR_TOOBIG;
  }
  for (chunk_index = 0u; chunk_index < chunk_count; ++chunk_index) {
    expected_len = ((size_t)total_size - out_off) > (size_t)chunk_size ? (size_t)chunk_size
                                                                       : ((size_t)total_size - out_off);
    rc = er_store_get_blob(store, &manifest[ER_STORE_OBJECT_FIRST_HASH_OFF + (chunk_index * ER_HASH_SIZE)],
                           &((uint8_t*)out)[out_off], expected_len, &got_len);
    if (rc != ER_OK) {
      return rc;
    }
    if (got_len != expected_len) {
      return ER_ERR_CORRUPT;
    }
    out_off += got_len;
  }
  if (out_off != (size_t)total_size) {
    return ER_ERR_CORRUPT;
  }
  *out_len = out_off;
  return ER_OK;
}

//@optimizer-ignore-function content type names are metadata labels, not object identity
int er_store_define_content_type(er_store_t* store, uint32_t content_type, const char* name) {
  uint8_t payload[ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME];
  uint8_t payload_hash[ER_HASH_SIZE];
  size_t name_len;
  int name_ok;
  int rc;

  if (store == (er_store_t*)0 || content_type == ER_STORE_TYPE_RAW || name == (const char*)0) {
    return ER_ERR_BADARG;
  }
  name_len = er_store_cstr_len(name, ER_STORE_MAX_NAME + 1u, &name_ok);
  if (name_ok == 0 || name_len == 0u || name_len > ER_STORE_MAX_NAME) {
    return ER_ERR_BADARG;
  }
  er_store_zero(payload, sizeof(payload));
  er_store_store32(payload, content_type);
  er_store_store16(&payload[ER_STORE_DEFINE_NAME_LEN_OFF], (uint16_t)name_len);
  er_store_copy(&payload[ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE], name, name_len);
  rc = er_store_hash_bytes(payload, ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + name_len, payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_CONTENT_TYPE_DEFINE, payload,
                              ER_STORE_DEFINE_FIXED_PAYLOAD_SIZE + name_len, payload_hash, (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_insert_type(store, content_type, name, name_len);
}

//@optimizer-ignore-function index names are metadata labels, not object identity
int er_store_define_index(er_store_t* store, uint32_t index_id, uint32_t content_type, const char* name) {
  uint8_t payload[ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_NAME];
  uint8_t payload_hash[ER_HASH_SIZE];
  size_t name_len;
  int name_ok;
  int rc;

  if (store == (er_store_t*)0 || index_id == ER_STORE_INDEX_DEFAULT || name == (const char*)0) {
    return ER_ERR_BADARG;
  }
  name_len = er_store_cstr_len(name, ER_STORE_MAX_NAME + 1u, &name_ok);
  if (name_ok == 0 || name_len == 0u || name_len > ER_STORE_MAX_NAME) {
    return ER_ERR_BADARG;
  }
  er_store_zero(payload, sizeof(payload));
  er_store_store32(payload, index_id);
  er_store_store32(&payload[ER_STORE_INDEX_DEFINE_CONTENT_TYPE_OFF], content_type);
  er_store_store16(&payload[ER_STORE_INDEX_DEFINE_NAME_LEN_OFF], (uint16_t)name_len);
  er_store_copy(&payload[ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE], name, name_len);
  rc = er_store_hash_bytes(payload, ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + name_len, payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_INDEX_DEFINE, payload,
                              ER_STORE_INDEX_DEFINE_FIXED_PAYLOAD_SIZE + name_len, payload_hash,
                              (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_insert_index_def(store, index_id, content_type, name, name_len);
}

int er_store_index_put_ex(er_store_t* store, uint32_t index_id, const char* key,
                          const uint8_t hash[ER_HASH_SIZE]) {
  uint8_t payload[ER_STORE_INDEX_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY];
  uint8_t payload_hash[ER_HASH_SIZE];
  size_t key_len;
  size_t key_off = ER_STORE_INDEX_ID_SIZE + ER_STORE_INDEX_KEY_LEN_SIZE;
  int key_ok;
  int rc;

  if (store == (er_store_t*)0 || key == (const char*)0 || hash == (const uint8_t*)0) {
    return ER_ERR_BADARG;
  }
  key_len = er_store_cstr_len(key, ER_STORE_MAX_KEY + 1u, &key_ok);
  if (key_ok == 0 || key_len == 0u || key_len > ER_STORE_MAX_KEY) {
    return ER_ERR_BADARG;
  }
  er_store_zero(payload, sizeof(payload));
  er_store_store32(payload, index_id);
  er_store_store16(&payload[ER_STORE_INDEX_ID_SIZE], (uint16_t)key_len);
  er_store_copy(&payload[key_off], key, key_len);
  er_store_copy(&payload[key_off + key_len], hash, ER_HASH_SIZE);
  rc = er_store_hash_bytes(payload, key_off + key_len + ER_HASH_SIZE, payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_INDEX_PUT, payload,
                              key_off + key_len + ER_HASH_SIZE, payload_hash, (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_insert_key_ex(store, index_id, key, key_len, hash);
}

//@optimizer-ignore-function object index projection records use fixed hash bytes and fixed 64-bit object sizes
int er_store_object_index_put(er_store_t* store, uint32_t index_id, const char* key,
                              const uint8_t object_hash[ER_HASH_SIZE]) {
  uint8_t payload[ER_STORE_PROJECT_FIXED_PAYLOAD_SIZE + ER_STORE_MAX_KEY];
  uint8_t payload_hash[ER_HASH_SIZE];
  size_t key_len;
  size_t hash_off;
  uint64_t object_size;
  int key_ok;
  int rc;

  if (store == (er_store_t*)0 || key == (const char*)0 || object_hash == (const uint8_t*)0) {
    return ER_ERR_BADARG;
  }
  key_len = er_store_cstr_len(key, ER_STORE_MAX_KEY + 1u, &key_ok);
  if (key_ok == 0 || key_len == 0u || key_len > ER_STORE_MAX_KEY) {
    return ER_ERR_BADARG;
  }
  rc = er_store_get_object_size(store, object_hash, &object_size);
  if (rc != ER_OK) {
    return rc;
  }
  hash_off = ER_STORE_PROJECT_KEY_OFF + key_len;
  er_store_zero(payload, sizeof(payload));
  er_store_store32(&payload[ER_STORE_PROJECT_INDEX_ID_OFF], index_id);
  er_store_store32(&payload[ER_STORE_PROJECT_VALUE_KIND_OFF], ER_STORE_VALUE_OBJECT);
  er_store_store32(&payload[ER_STORE_PROJECT_CONTENT_TYPE_OFF], ER_STORE_TYPE_OBJECT_MANIFEST);
  er_store_store64(&payload[ER_STORE_PROJECT_VALUE_SIZE_OFF], object_size);
  er_store_store16(&payload[ER_STORE_PROJECT_KEY_LEN_OFF], (uint16_t)key_len);
  er_store_copy(&payload[ER_STORE_PROJECT_KEY_OFF], key, key_len);
  er_store_copy(&payload[hash_off], object_hash, ER_HASH_SIZE);
  rc = er_store_hash_bytes(payload, hash_off + ER_HASH_SIZE, payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_OBJECT_INDEX_PUT, payload, hash_off + ER_HASH_SIZE, payload_hash,
                              (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_insert_key_meta(store, index_id, key, key_len, object_hash, ER_STORE_VALUE_OBJECT,
                                  ER_STORE_TYPE_OBJECT_MANIFEST, object_size);
}

int er_store_index_put(er_store_t* store, const char* key, const uint8_t hash[ER_HASH_SIZE]) {
  return er_store_index_put_ex(store, ER_STORE_INDEX_DEFAULT, key, hash);
}

int er_store_index_get_ex(er_store_t* store, uint32_t index_id, const char* key, uint8_t out_hash[ER_HASH_SIZE]) {
  ErStoreKeySlot* slots;
  size_t key_len;
  size_t slot;
  int key_ok;
  int rc;

  if (store == (er_store_t*)0 || key == (const char*)0 || out_hash == (uint8_t*)0) {
    return ER_ERR_BADARG;
  }
  key_len = er_store_cstr_len(key, ER_STORE_MAX_KEY + 1u, &key_ok);
  if (key_ok == 0 || key_len == 0u || key_len > ER_STORE_MAX_KEY) {
    return ER_ERR_BADARG;
  }
  rc = er_store_find_key_ex(store, index_id, key, key_len, &slot);
  if (rc != ER_OK) {
    return rc;
  }
  slots = er_store_keys(store);
  er_store_copy(out_hash, slots[slot].hash, ER_HASH_SIZE);
  return ER_OK;
}

int er_store_index_get(er_store_t* store, const char* key, uint8_t out_hash[ER_HASH_SIZE]) {
  return er_store_index_get_ex(store, ER_STORE_INDEX_DEFAULT, key, out_hash);
}

int er_store_index_cursor_open(er_store_t* store, uint32_t index_id, const char* prefix,
                               er_store_index_cursor_t* out_cursor) {
  ErStoreKeySlot* slots;
  size_t prefix_len;
  int prefix_ok;
  int rc;

  if (store == (er_store_t*)0 || prefix == (const char*)0 || out_cursor == (er_store_index_cursor_t*)0) {
    return ER_ERR_BADARG;
  }
  prefix_len = er_store_cstr_len(prefix, ER_STORE_MAX_KEY + 1u, &prefix_ok);
  if (prefix_ok == 0 || prefix_len > ER_STORE_MAX_KEY) {
    return ER_ERR_BADARG;
  }
  rc = er_store_rebuild_sorted_keys(store);
  if (rc != ER_OK) {
    return rc;
  }
  out_cursor->store = store;
  out_cursor->index_id = index_id;
  out_cursor->prefix_len = prefix_len;
  er_store_zero(out_cursor->prefix, ER_STORE_MAX_KEY);
  er_store_copy(out_cursor->prefix, prefix, prefix_len);
  slots = er_store_keys(store);
  (void)slots;
  out_cursor->pos = er_store_sorted_lower_bound(store, index_id, prefix, prefix_len);
  return ER_OK;
}

int er_store_index_cursor_next(er_store_index_cursor_t* cursor, er_index_entry_t* out_entry) {
  er_store_t* store;
  ErStoreKeySlot* slots;
  size_t* refs;
  ErStoreKeySlot* slot;

  if (cursor == (er_store_index_cursor_t*)0 || out_entry == (er_index_entry_t*)0 ||
      cursor->store == (er_store_t*)0) {
    return ER_ERR_BADARG;
  }
  store = cursor->store;
  slots = er_store_keys(store);
  refs = er_store_sorted_keys(store);
  while (cursor->pos < store->sorted_key_count) {
    slot = &slots[refs[cursor->pos]];
    if (!er_store_key_has_prefix(slot, cursor->index_id, cursor->prefix, cursor->prefix_len)) {
      return ER_ERR_NOTFOUND;
    }
    ++cursor->pos;
    out_entry->index_id = slot->index_id;
    out_entry->value_kind = slot->value_kind;
    out_entry->content_type = slot->content_type;
    er_store_zero(out_entry->key, ER_STORE_MAX_KEY);
    er_store_copy(out_entry->key, slot->key, slot->key_len);
    er_store_copy(out_entry->hash, slot->hash, ER_HASH_SIZE);
    out_entry->value_size = slot->value_size;
    return ER_OK;
  }
  return ER_ERR_NOTFOUND;
}

int er_store_index_scan_prefix_ex(er_store_t* store, uint32_t index_id, const char* prefix,
                                  er_index_entry_t* out_entries, size_t max_entries, size_t* out_count) {
  er_store_index_cursor_t cursor;
  er_index_entry_t scratch;
  size_t count = 0u;
  int rc;

  if (out_count == (size_t*)0 || (max_entries != 0u && out_entries == (er_index_entry_t*)0)) {
    return ER_ERR_BADARG;
  }
  rc = er_store_index_cursor_open(store, index_id, prefix, &cursor);
  if (rc != ER_OK) {
    return rc;
  }
  while (1) {
    if (count >= max_entries) {
      rc = er_store_index_cursor_next(&cursor, &scratch);
      if (rc == ER_ERR_NOTFOUND) {
        *out_count = count;
        return ER_OK;
      }
      return rc == ER_OK ? ER_ERR_NOSPACE : rc;
    }
    rc = er_store_index_cursor_next(&cursor, &out_entries[count]);
    if (rc == ER_ERR_NOTFOUND) {
      *out_count = count;
      return ER_OK;
    }
    if (rc != ER_OK) {
      return rc;
    }
    ++count;
  }
}

int er_store_index_scan_prefix(er_store_t* store, const char* prefix, er_index_entry_t* out_entries,
                               size_t max_entries, size_t* out_count) {
  return er_store_index_scan_prefix_ex(store, ER_STORE_INDEX_DEFAULT, prefix, out_entries, max_entries, out_count);
}

//@optimizer-ignore-function verify scans fixed 64-bit record log offsets from IO size
int er_store_verify(er_store_t* store) {
  uint64_t io_size;
  uint64_t saved_log_end;
  uint64_t saved_next_seq;
  uint8_t saved_hash[ER_HASH_SIZE];
  int rc;

  if (store == (er_store_t*)0) {
    return ER_ERR_BADARG;
  }
  if (store->io.size(store->io.ctx, &io_size) != 0) {
    return ER_ERR_IO;
  }
  saved_log_end = store->log_end;
  saved_next_seq = store->next_seq;
  er_store_copy(saved_hash, store->last_record_hash, ER_HASH_SIZE);
  rc = er_store_replay(store, io_size, 0, 0);
  if (rc == ER_OK && store->log_end != io_size) {
    rc = ER_ERR_CORRUPT;
  }
  store->log_end = saved_log_end;
  store->next_seq = saved_next_seq;
  er_store_copy(store->last_record_hash, saved_hash, ER_HASH_SIZE);
  return rc;
}

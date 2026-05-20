//@optimizer-ignore single-file storage engine keeps the append log, replay, and indexes together
#include "er_store.h"

#include "er_blake3.h"

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
  ER_STORE_INDEX_KEY_LEN_SIZE = 2u,
  ER_STORE_INDEX_PAYLOAD_OVERHEAD = ER_STORE_INDEX_KEY_LEN_SIZE + ER_HASH_SIZE,
  ER_STORE_ALIGN = 8u,
  ER_REC_BLOB = 1u,
  ER_REC_INDEX_PUT = 2u,
  ER_REC_TOMBSTONE = 3u,
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
  uint64_t offset; //@optimizer-ignore blob offsets mirror the fixed 64-bit record log ABI
  uint64_t size; //@optimizer-ignore blob sizes mirror the fixed 64-bit record log ABI
} ErStoreBlobSlot;

typedef struct {
  uint8_t used;
  uint16_t key_len;
  char key[ER_STORE_MAX_KEY];
  uint8_t hash[ER_HASH_SIZE];
} ErStoreKeySlot;

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

static int er_store_key_equal(const ErStoreKeySlot* slot, const char* key, size_t key_len) {
  if (slot->key_len != key_len) {
    return 0;
  }
  return er_store_equal(slot->key, key, key_len);
}

static int er_store_key_has_prefix(const ErStoreKeySlot* slot, const char* prefix, size_t prefix_len) {
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

static size_t er_store_key_slot(const char* key, size_t key_len, size_t cap) {
  size_t i;
  size_t value = 0u;

  for (i = 0u; i < key_len; ++i) {
    value = (value * ER_STORE_SLOT_HASH_MULTIPLIER) ^ (uint8_t)key[i];
  }
  return value & (cap - 1u);
}

static ErStoreBlobSlot* er_store_blobs(er_store_t* store) {
  return (ErStoreBlobSlot*)store->blob_slots;
}

static ErStoreKeySlot* er_store_keys(er_store_t* store) {
  return (ErStoreKeySlot*)store->key_slots;
}

//@optimizer-ignore-function fixed-capacity hash table indexes the caller-provided arena
static int er_store_find_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], size_t* out_slot) {
  ErStoreBlobSlot* slots = er_store_blobs(store);
  size_t start;
  size_t i;
  size_t slot;

  start = er_store_hash_slot(hash, ER_STORE_BLOB_CAPACITY);
  slot = start;
  for (i = 0u; i < ER_STORE_BLOB_CAPACITY; ++i) {
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
    if (slot == ER_STORE_BLOB_CAPACITY) {
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
  if (store->blob_count >= ER_STORE_BLOB_CAPACITY) {
    return ER_ERR_NOSPACE;
  }
  slots[slot].used = 1u;
  er_store_copy(slots[slot].hash, hash, ER_HASH_SIZE);
  slots[slot].offset = offset;
  slots[slot].size = size;
  ++store->blob_count;
  return ER_OK;
}

//@optimizer-ignore-function fixed-capacity key table indexes the caller-provided arena
static int er_store_find_key(er_store_t* store, const char* key, size_t key_len, size_t* out_slot) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t start;
  size_t i;
  size_t slot;

  start = er_store_key_slot(key, key_len, ER_STORE_INDEX_CAPACITY);
  slot = start;
  for (i = 0u; i < ER_STORE_INDEX_CAPACITY; ++i) {
    if (slots[slot].used == 0u) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_ERR_NOTFOUND;
    }
    if (er_store_key_equal(&slots[slot], key, key_len)) {
      if (out_slot != (size_t*)0) {
        *out_slot = slot;
      }
      return ER_OK;
    }
    ++slot;
    if (slot == ER_STORE_INDEX_CAPACITY) {
      slot = 0u;
    }
  }
  return ER_ERR_NOSPACE;
}

//@optimizer-ignore-function fixed-capacity key table indexes the caller-provided arena
static int er_store_insert_key(er_store_t* store, const char* key, size_t key_len,
                               const uint8_t hash[ER_HASH_SIZE]) {
  ErStoreKeySlot* slots = er_store_keys(store);
  size_t slot;
  int found = er_store_find_key(store, key, key_len, &slot);

  if (found != ER_OK && found != ER_ERR_NOTFOUND) {
    return found;
  }
  if (found == ER_ERR_NOTFOUND) {
    if (store->key_count >= ER_STORE_INDEX_CAPACITY) {
      return ER_ERR_NOSPACE;
    }
    slots[slot].used = 1u;
    slots[slot].key_len = (uint16_t)key_len;
    er_store_zero(slots[slot].key, ER_STORE_MAX_KEY);
    er_store_copy(slots[slot].key, key, key_len);
    ++store->key_count;
  }
  er_store_copy(slots[slot].hash, hash, ER_HASH_SIZE);
  return ER_OK;
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
  uint16_t key_len;

  if (payload_len < ER_STORE_INDEX_PAYLOAD_OVERHEAD ||
      payload_len > (ER_STORE_INDEX_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY)) {
    return ER_ERR_CORRUPT;
  }
  if (store->io.read_at(store->io.ctx, payload_off, payload, (size_t)payload_len) != 0) {
    return ER_ERR_IO;
  }
  key_len = er_store_load16(payload);
  if (key_len == 0u || key_len > ER_STORE_MAX_KEY ||
      payload_len != ((uint64_t)ER_STORE_INDEX_KEY_LEN_SIZE + (uint64_t)key_len + ER_HASH_SIZE)) {
    return ER_ERR_CORRUPT;
  }
  return er_store_insert_key(store, (const char*)&payload[ER_STORE_INDEX_KEY_LEN_SIZE], key_len,
                             &payload[ER_STORE_INDEX_KEY_LEN_SIZE + key_len]);
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
    er_store_zero(store->blob_slots, sizeof(ErStoreBlobSlot) * ER_STORE_BLOB_CAPACITY);
    er_store_zero(store->key_slots, sizeof(ErStoreKeySlot) * ER_STORE_INDEX_CAPACITY);
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

static int er_store_prepare_arena(er_store_t* store, void* arena, size_t arena_len) {
  uint64_t base;
  uint64_t cursor;
  uint64_t end;
  uint64_t blob_bytes;
  uint64_t key_bytes;

  if (arena == (void*)0) {
    return ER_ERR_BADARG;
  }
  if (er_store_size_to_u64(arena_len, &end) != ER_OK) {
    return ER_ERR_TOOBIG;
  }
  base = (uint64_t)(uintptr_t)arena;
  cursor = er_store_align_up(base, ER_STORE_ALIGN);
  blob_bytes = (uint64_t)sizeof(ErStoreBlobSlot) * ER_STORE_BLOB_CAPACITY;
  key_bytes = (uint64_t)sizeof(ErStoreKeySlot) * ER_STORE_INDEX_CAPACITY;
  if ((cursor - base) > end || blob_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->blob_slots = (void*)(uintptr_t)cursor;
  cursor += blob_bytes;
  cursor = er_store_align_up(cursor, ER_STORE_ALIGN);
  if ((cursor - base) > end || key_bytes > (end - (cursor - base))) {
    return ER_ERR_NOSPACE;
  }
  store->key_slots = (void*)(uintptr_t)cursor;
  er_store_zero(store->blob_slots, (size_t)blob_bytes);
  er_store_zero(store->key_slots, (size_t)key_bytes);
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
int er_store_open(er_store_t* store, er_io_t io, void* arena, size_t arena_len) {
  uint64_t io_size;
  int rc;

  if (store == (er_store_t*)0 || er_store_validate_io(&io) != ER_OK) {
    return ER_ERR_BADARG;
  }
  er_store_zero(store, sizeof(*store));
  store->io = io;
  rc = er_store_prepare_arena(store, arena, arena_len);
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
  return er_store_write_superblock(store);
}

int er_store_close(er_store_t* store) {
  if (store == (er_store_t*)0) {
    return ER_ERR_BADARG;
  }
  return er_store_write_superblock(store);
}

//@optimizer-ignore-function blob append computes fixed 64-bit payload offsets and lengths
int er_store_put_blob(er_store_t* store, const void* data, size_t len, uint8_t out_hash[ER_HASH_SIZE]) {
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
  return er_store_insert_blob(store, hash, payload_off, payload_len);
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
  if (slots[slot].size != 0u && store->io.read_at(store->io.ctx, slots[slot].offset, out,
                                                   (size_t)slots[slot].size) != 0) {
    return ER_ERR_IO;
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

int er_store_index_put(er_store_t* store, const char* key, const uint8_t hash[ER_HASH_SIZE]) {
  uint8_t payload[ER_STORE_INDEX_PAYLOAD_OVERHEAD + ER_STORE_MAX_KEY];
  uint8_t payload_hash[ER_HASH_SIZE];
  size_t key_len;
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
  er_store_store16(payload, (uint16_t)key_len);
  er_store_copy(&payload[ER_STORE_INDEX_KEY_LEN_SIZE], key, key_len);
  er_store_copy(&payload[ER_STORE_INDEX_KEY_LEN_SIZE + key_len], hash, ER_HASH_SIZE);
  rc = er_store_hash_bytes(payload, ER_STORE_INDEX_KEY_LEN_SIZE + key_len + ER_HASH_SIZE, payload_hash);
  if (rc != ER_OK) {
    return rc;
  }
  rc = er_store_append_record(store, ER_REC_INDEX_PUT, payload,
                              ER_STORE_INDEX_KEY_LEN_SIZE + key_len + ER_HASH_SIZE, payload_hash,
                              (uint64_t*)0);
  if (rc != ER_OK) {
    return rc;
  }
  return er_store_insert_key(store, key, key_len, hash);
}

int er_store_index_get(er_store_t* store, const char* key, uint8_t out_hash[ER_HASH_SIZE]) {
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
  rc = er_store_find_key(store, key, key_len, &slot);
  if (rc != ER_OK) {
    return rc;
  }
  slots = er_store_keys(store);
  er_store_copy(out_hash, slots[slot].hash, ER_HASH_SIZE);
  return ER_OK;
}

//@optimizer-ignore-function prefix scan walks the fixed-capacity key table deterministically
int er_store_index_scan_prefix(er_store_t* store, const char* prefix, er_index_entry_t* out_entries,
                               size_t max_entries, size_t* out_count) {
  ErStoreKeySlot* slots;
  size_t prefix_len;
  size_t i;
  size_t count = 0u;
  int prefix_ok;

  if (store == (er_store_t*)0 || prefix == (const char*)0 || out_count == (size_t*)0 ||
      (max_entries != 0u && out_entries == (er_index_entry_t*)0)) {
    return ER_ERR_BADARG;
  }
  prefix_len = er_store_cstr_len(prefix, ER_STORE_MAX_KEY + 1u, &prefix_ok);
  if (prefix_ok == 0 || prefix_len > ER_STORE_MAX_KEY) {
    return ER_ERR_BADARG;
  }
  slots = er_store_keys(store);
  for (i = 0u; i < ER_STORE_INDEX_CAPACITY; ++i) {
    if (slots[i].used != 0u && er_store_key_has_prefix(&slots[i], prefix, prefix_len)) {
      if (count >= max_entries) {
        return ER_ERR_NOSPACE;
      }
      er_store_zero(out_entries[count].key, ER_STORE_MAX_KEY);
      er_store_copy(out_entries[count].key, slots[i].key, slots[i].key_len);
      er_store_copy(out_entries[count].hash, slots[i].hash, ER_HASH_SIZE);
      ++count;
    }
  }
  *out_count = count;
  return ER_OK;
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

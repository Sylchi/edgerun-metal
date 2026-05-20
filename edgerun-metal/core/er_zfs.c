#include "er_zfs.h"
#include "er_mem.h"

enum {
  ER_ZFS_LABEL_COUNT = 4u,
  ER_ZFS_HEAD_LABEL0_OFFSET = 0u,
  ER_ZFS_HEAD_LABEL1_OFFSET = ER_ZFS_LABEL_BYTES,
  ER_ZFS_TAIL_LABEL1_BACK_BYTES = ER_ZFS_LABEL_BYTES,
  ER_ZFS_TAIL_LABEL0_BACK_BYTES = ER_ZFS_LABEL_BYTES * 2u,
  ER_ZFS_UBERBLOCK_RING_OFFSET = 128u * 1024u,
  ER_ZFS_UBERBLOCK_RING_BYTES = 128u * 1024u,
  ER_ZFS_UBERBLOCK_COUNT = ER_ZFS_UBERBLOCK_RING_BYTES / ER_ZFS_UBERBLOCK_BYTES,
  ER_ZFS_UBERBLOCK_MAGIC_WORD = 0u,
  ER_ZFS_UBERBLOCK_VERSION_WORD = 1u,
  ER_ZFS_UBERBLOCK_TXG_WORD = 2u,
  ER_ZFS_UBERBLOCK_GUID_SUM_WORD = 3u,
  ER_ZFS_UBERBLOCK_TIMESTAMP_WORD = 4u,
  ER_ZFS_UBERBLOCK_ROOTBP_WORD = 5u,
  ER_ZFS_UBERBLOCK_ROOTBP_WORDS = 16u,
  ER_ZFS_U64_BYTES = 8u,
  ER_ZFS_UINT64_MAX = 0xffffffffffffffffULL,
  ER_ZFS_BYTE_BITS = 8u,
  ER_ZFS_BYTE_MASK = 0xffu
};

static UINT64 er_zfs_get_le64(const UINT8* bytes) {
  UINT32 i;
  UINT64 value = 0u;

  for (i = 0u; i < ER_ZFS_U64_BYTES; ++i) {
    value |= ((UINT64)bytes[i]) << ((UINT64)i * ER_ZFS_BYTE_BITS);
  }
  return value;
}

static UINT64 er_zfs_get_be64(const UINT8* bytes) {
  UINT32 i;
  UINT64 value = 0u;

  for (i = 0u; i < ER_ZFS_U64_BYTES; ++i) {
    value = (value << ER_ZFS_BYTE_BITS) | (UINT64)(bytes[i] & ER_ZFS_BYTE_MASK);
  }
  return value;
}

static UINT8 er_zfs_uberblock_word(const UINT8* uberblock,
                                   UINT32 word_index,
                                   UINT8 big_endian,
                                   UINT64* out_value) {
  const UINT8* word;

  if (uberblock == 0 || out_value == 0) {
    return 0u;
  }
  word = uberblock + ((UINTN)word_index * ER_ZFS_U64_BYTES);
  if (big_endian != 0u) {
    *out_value = er_zfs_get_be64(word);
  } else {
    *out_value = er_zfs_get_le64(word);
  }
  return 1u;
}

static UINT8 er_zfs_uberblock_magic(const UINT8* uberblock,
                                    UINT8* out_big_endian) {
  UINT64 le;
  UINT64 be;

  if (uberblock == 0 || out_big_endian == 0) {
    return 0u;
  }
  le = er_zfs_get_le64(uberblock);
  be = er_zfs_get_be64(uberblock);
  if (le == ER_ZFS_UBERBLOCK_MAGIC) {
    *out_big_endian = 0u;
    return 1u;
  }
  if (be == ER_ZFS_UBERBLOCK_MAGIC) {
    *out_big_endian = 1u;
    return 1u;
  }
  return 0u;
}

UINT8 er_zfs_label_slot_offset(UINT64 device_bytes,
                               UINT16 slot,
                               UINT64* out_offset) {
  if (out_offset == 0 || device_bytes < (UINT64)ER_ZFS_LABEL_BYTES * ER_ZFS_LABEL_COUNT) {
    return 0u;
  }
  switch (slot) {
    case ER_ZFS_LABEL_SLOT_HEAD0:
      *out_offset = ER_ZFS_HEAD_LABEL0_OFFSET;
      return 1u;
    case ER_ZFS_LABEL_SLOT_HEAD1:
      *out_offset = ER_ZFS_HEAD_LABEL1_OFFSET;
      return 1u;
    case ER_ZFS_LABEL_SLOT_TAIL0:
      *out_offset = device_bytes - ER_ZFS_TAIL_LABEL0_BACK_BYTES;
      return 1u;
    case ER_ZFS_LABEL_SLOT_TAIL1:
      *out_offset = device_bytes - ER_ZFS_TAIL_LABEL1_BACK_BYTES;
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_zfs_probe_one_uberblock(const UINT8* bytes,
                                        UINT16 slot,
                                        UINT64 label_offset,
                                        UINT32 uberblock_index,
                                        ErZfsUberblockSummary* out_summary) {
  UINT8 big_endian = 0u;
  UINT64 version = 0u;
  UINT64 txg = 0u;
  UINT64 guid_sum = 0u;
  UINT32 i;

  if (out_summary == 0 ||
      er_zfs_uberblock_magic(bytes, &big_endian) == 0u ||
      er_zfs_uberblock_word(bytes, ER_ZFS_UBERBLOCK_VERSION_WORD,
                            big_endian, &version) == 0u ||
      er_zfs_uberblock_word(bytes, ER_ZFS_UBERBLOCK_TXG_WORD,
                            big_endian, &txg) == 0u ||
      er_zfs_uberblock_word(bytes, ER_ZFS_UBERBLOCK_GUID_SUM_WORD,
                            big_endian, &guid_sum) == 0u ||
      txg == 0u ||
      guid_sum == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_summary, (UINTN)sizeof(*out_summary));
  out_summary->abi_version = ER_ZFS_ABI_VERSION;
  out_summary->slot = slot;
  out_summary->byte_offset = label_offset + ER_ZFS_UBERBLOCK_RING_OFFSET +
                             ((UINT64)uberblock_index * ER_ZFS_UBERBLOCK_BYTES);
  out_summary->txg = txg;
  (void)er_zfs_uberblock_word(bytes, ER_ZFS_UBERBLOCK_TIMESTAMP_WORD,
                              big_endian, &out_summary->timestamp);
  for (i = 0u; i < ER_ZFS_UBERBLOCK_ROOTBP_WORDS; ++i) {
    (void)er_zfs_uberblock_word(bytes,
                                ER_ZFS_UBERBLOCK_ROOTBP_WORD + i,
                                big_endian,
                                &out_summary->rootbp_words[i]);
  }
  (void)version;
  return 1u;
}

UINT8 er_zfs_probe_label_bytes(const UINT8* label_bytes,
                               UINT32 label_len,
                               UINT16 slot,
                               UINT64 label_offset,
                               ErZfsUberblockSummary* out_summary) {
  UINT32 uberblock_index;
  ErZfsUberblockSummary best;
  UINT8 found = 0u;

  if (out_summary == 0 ||
      label_bytes == 0 ||
      label_len < ER_ZFS_LABEL_BYTES) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_summary, (UINTN)sizeof(*out_summary));
  er_mem_zero((UINT8*)&best, (UINTN)sizeof(best));
  for (uberblock_index = 0u; uberblock_index < ER_ZFS_UBERBLOCK_COUNT; ++uberblock_index) {
    const UINT8* uberblock = label_bytes + ER_ZFS_UBERBLOCK_RING_OFFSET +
                             ((UINTN)uberblock_index * ER_ZFS_UBERBLOCK_BYTES);
    ErZfsUberblockSummary candidate;
    if (er_zfs_probe_one_uberblock(uberblock, slot, label_offset,
                                   uberblock_index, &candidate) == 0u) {
      continue;
    }
    if (found == 0u || candidate.txg > best.txg) {
      best = candidate;
      found = 1u;
    }
  }
  if (found == 0u) {
    return 0u;
  }
  *out_summary = best;
  return 1u;
}

UINT8 er_zfs_probe_pool(const ErBlockDevice* device,
                        UINT8* label_buffer,
                        UINT32 label_buffer_len,
                        ErZfsPoolProbe* out_probe) {
  UINT64 device_bytes;
  UINT16 slot;

  if (device == 0 ||
      device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION ||
      label_buffer == 0 ||
      label_buffer_len < ER_ZFS_LABEL_BYTES ||
      out_probe == 0) {
    return 0u;
  }
  if (device->logical_block_bytes == 0u ||
      device->block_count >
          ER_ZFS_UINT64_MAX / (UINT64)device->logical_block_bytes) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_probe, (UINTN)sizeof(*out_probe));
  device_bytes = device->block_count * (UINT64)device->logical_block_bytes;
  out_probe->abi_version = ER_ZFS_ABI_VERSION;
  out_probe->pool_bytes = device_bytes;
  for (slot = 0u; slot < ER_ZFS_LABEL_COUNT; ++slot) {
    UINT64 label_offset = 0u;
    UINT64 lba = 0u;
    ErZfsUberblockSummary summary;
    if (er_zfs_label_slot_offset(device_bytes, slot, &label_offset) == 0u ||
        (label_offset % device->logical_block_bytes) != 0u ||
        (ER_ZFS_LABEL_BYTES % device->logical_block_bytes) != 0u) {
      return 0u;
    }
    lba = label_offset / device->logical_block_bytes;
    if (er_block_device_read(device, lba,
                             ER_ZFS_LABEL_BYTES / device->logical_block_bytes,
                             label_buffer, ER_ZFS_LABEL_BYTES) == 0u) {
      return 0u;
    }
    if (er_zfs_probe_label_bytes(label_buffer, label_buffer_len, slot,
                                 label_offset, &summary) == 0u) {
      continue;
    }
    out_probe->label_count += 1u;
    if (out_probe->selected_txg == 0u ||
        summary.txg > out_probe->selected_txg) {
      out_probe->selected_txg = summary.txg;
      out_probe->selected_slot = slot;
      out_probe->selected = summary;
    }
  }
  return (UINT8)(out_probe->label_count != 0u);
}

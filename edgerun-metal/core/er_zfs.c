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
  ER_ZFS_U32_BYTES = 4u,
  ER_ZFS_U64_BYTES = 8u,
  ER_ZFS_U16_BYTES = 2u,
  ER_ZFS_UINT64_MAX = 0xffffffffffffffffULL,
  ER_ZFS_BYTE_BITS = 8u,
  ER_ZFS_BYTE_MASK = 0xffu,
  ER_ZFS_GPT_HEADER_LBA = 1u,
  ER_ZFS_GPT_SIGNATURE_OFFSET = 0u,
  ER_ZFS_GPT_HEADER_SIZE_OFFSET = 12u,
  ER_ZFS_GPT_FIRST_USABLE_LBA_OFFSET = 40u,
  ER_ZFS_GPT_LAST_USABLE_LBA_OFFSET = 48u,
  ER_ZFS_GPT_ENTRY_LBA_OFFSET = 72u,
  ER_ZFS_GPT_ENTRY_COUNT_OFFSET = 80u,
  ER_ZFS_GPT_ENTRY_SIZE_OFFSET = 84u,
  ER_ZFS_GPT_HEADER_MIN_BYTES = 92u,
  ER_ZFS_GPT_SIGNATURE_BYTES = 8u,
  ER_ZFS_GPT_ENTRY_TYPE_GUID_OFFSET = 0u,
  ER_ZFS_GPT_ENTRY_UNIQUE_GUID_OFFSET = 16u,
  ER_ZFS_GPT_ENTRY_FIRST_LBA_OFFSET = 32u,
  ER_ZFS_GPT_ENTRY_LAST_LBA_OFFSET = 40u,
  ER_ZFS_GPT_ENTRY_NAME_OFFSET = 56u,
  ER_ZFS_GPT_MAX_ENTRY_SIZE = 512u
};

static const UINT8 g_er_zfs_gpt_signature[ER_ZFS_GPT_SIGNATURE_BYTES] = {
    'E', 'F', 'I', ' ', 'P', 'A', 'R', 'T'};

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

static UINT32 er_zfs_get_le32(const UINT8* bytes) {
  UINT32 i;
  UINT32 value = 0u;

  for (i = 0u; i < ER_ZFS_U32_BYTES; ++i) {
    value |= ((UINT32)bytes[i]) << (i * ER_ZFS_BYTE_BITS);
  }
  return value;
}

static UINT16 er_zfs_get_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << ER_ZFS_BYTE_BITS));
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
  if (device == 0 || device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION) {
    return 0u;
  }
  return er_zfs_probe_pool_at(device, 0u, device->block_count,
                              label_buffer, label_buffer_len, out_probe);
}

UINT8 er_zfs_probe_pool_at(const ErBlockDevice* device,
                           UINT64 base_lba,
                           UINT64 block_count,
                           UINT8* label_buffer,
                           UINT32 label_buffer_len,
                           ErZfsPoolProbe* out_probe) {
  UINT64 device_bytes;
  UINT16 slot;

  if (device == 0 ||
      device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION ||
      label_buffer == 0 ||
      label_buffer_len < ER_ZFS_LABEL_BYTES ||
      out_probe == 0 ||
      block_count == 0u ||
      base_lba >= device->block_count ||
      block_count > device->block_count - base_lba) {
    return 0u;
  }
  if (device->logical_block_bytes == 0u ||
      block_count >
          ER_ZFS_UINT64_MAX / (UINT64)device->logical_block_bytes) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_probe, (UINTN)sizeof(*out_probe));
  device_bytes = block_count * (UINT64)device->logical_block_bytes;
  out_probe->abi_version = ER_ZFS_ABI_VERSION;
  out_probe->pool_bytes = device_bytes;
  out_probe->base_lba = base_lba;
  out_probe->block_count = block_count;
  for (slot = 0u; slot < ER_ZFS_LABEL_COUNT; ++slot) {
    UINT64 label_offset = 0u;
    UINT64 lba = 0u;
    ErZfsUberblockSummary summary;
    if (er_zfs_label_slot_offset(device_bytes, slot, &label_offset) == 0u ||
        (label_offset % device->logical_block_bytes) != 0u ||
        (ER_ZFS_LABEL_BYTES % device->logical_block_bytes) != 0u) {
      return 0u;
    }
    lba = base_lba + (label_offset / device->logical_block_bytes);
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

static UINT8 er_zfs_gpt_entry_used(const UINT8* entry) {
  UINT32 i;
  const UINT8* entry_byte;

  if (entry == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_ZFS_GPT_PARTITION_GUID_BYTES; ++i) {
    entry_byte = entry + i;
    if (*entry_byte != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_zfs_gpt_read_partition(const UINT8* entry,
                                       UINT32 entry_size,
                                       UINT32 entry_index,
                                       UINT64 first_usable_lba,
                                       UINT64 last_usable_lba,
                                       ErZfsGptPartition* out_partition) {
  UINT32 i;
  UINT64 first_lba;
  UINT64 last_lba;

  if (entry == 0 ||
      out_partition == 0 ||
      entry_size < ER_ZFS_GPT_PARTITION_ENTRY_MIN_BYTES ||
      er_zfs_gpt_entry_used(entry) == 0u) {
    return 0u;
  }
  first_lba = er_zfs_get_le64(entry + ER_ZFS_GPT_ENTRY_FIRST_LBA_OFFSET);
  last_lba = er_zfs_get_le64(entry + ER_ZFS_GPT_ENTRY_LAST_LBA_OFFSET);
  if (first_lba < first_usable_lba ||
      last_lba > last_usable_lba ||
      first_lba > last_lba) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_partition, (UINTN)sizeof(*out_partition));
  out_partition->abi_version = ER_ZFS_ABI_VERSION;
  out_partition->entry_index = (UINT16)entry_index;
  out_partition->first_lba = first_lba;
  out_partition->last_lba = last_lba;
  er_mem_copy(out_partition->type_guid,
              entry + ER_ZFS_GPT_ENTRY_TYPE_GUID_OFFSET,
              ER_ZFS_GPT_PARTITION_GUID_BYTES);
  er_mem_copy(out_partition->unique_guid,
              entry + ER_ZFS_GPT_ENTRY_UNIQUE_GUID_OFFSET,
              ER_ZFS_GPT_PARTITION_GUID_BYTES);
  for (i = 0u; i < ER_ZFS_GPT_PARTITION_NAME_CODE_UNITS; ++i) {
    UINT16* name_code_unit = out_partition->utf16le_units + i;

    *name_code_unit =
        er_zfs_get_le16(entry + ER_ZFS_GPT_ENTRY_NAME_OFFSET +
                        (i * ER_ZFS_U16_BYTES));
  }
  return 1u;
}

UINT8 er_zfs_gpt_partition_name_matches_ascii(const ErZfsGptPartition* partition,
                                              const char* name,
                                              UINT32 name_len) {
  UINT32 i;
  const char* name_at;
  const UINT16* partition_name_at;

  if (partition == 0 ||
      partition->abi_version != ER_ZFS_ABI_VERSION ||
      name == 0 ||
      name_len == 0u ||
      name_len > ER_ZFS_GPT_PARTITION_NAME_CODE_UNITS) {
    return 0u;
  }
  for (i = 0u; i < name_len; ++i) {
    name_at = name + i;
    partition_name_at = partition->utf16le_units + i;
    if (*name_at == 0 ||
        *partition_name_at != (UINT16)(UINT8)(*name_at)) {
      return 0u;
    }
  }
  if (name_len == ER_ZFS_GPT_PARTITION_NAME_CODE_UNITS) {
    return 1u;
  }
  partition_name_at = partition->utf16le_units + name_len;
  return (UINT8)(*partition_name_at == 0u);
}

UINT8 er_zfs_probe_gpt_for_pool(const ErBlockDevice* device,
                                UINT8* gpt_buffer,
                                UINT32 gpt_buffer_len,
                                UINT8* label_buffer,
                                UINT32 label_buffer_len,
                                ErZfsGptPartition* out_partition,
                                ErZfsPoolProbe* out_probe) {
  UINT64 first_usable_lba;
  UINT64 last_usable_lba;
  UINT64 entry_lba;
  UINT32 header_size;
  UINT32 entry_count;
  UINT32 entry_size;
  UINT32 entries_per_read;
  UINT32 entry_index;

  if (device == 0 ||
      device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION ||
      gpt_buffer == 0 ||
      label_buffer == 0 ||
      out_partition == 0 ||
      out_probe == 0 ||
      gpt_buffer_len < device->logical_block_bytes ||
      label_buffer_len < ER_ZFS_LABEL_BYTES) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_partition, (UINTN)sizeof(*out_partition));
  er_mem_zero((UINT8*)out_probe, (UINTN)sizeof(*out_probe));
  if (er_block_device_read(device, ER_ZFS_GPT_HEADER_LBA, 1u,
                           gpt_buffer, device->logical_block_bytes) == 0u ||
      er_mem_equal(gpt_buffer + ER_ZFS_GPT_SIGNATURE_OFFSET,
                   g_er_zfs_gpt_signature,
                   ER_ZFS_GPT_SIGNATURE_BYTES) == 0u) {
    return 0u;
  }
  header_size = er_zfs_get_le32(gpt_buffer + ER_ZFS_GPT_HEADER_SIZE_OFFSET);
  entry_lba = er_zfs_get_le64(gpt_buffer + ER_ZFS_GPT_ENTRY_LBA_OFFSET);
  entry_count = er_zfs_get_le32(gpt_buffer + ER_ZFS_GPT_ENTRY_COUNT_OFFSET);
  entry_size = er_zfs_get_le32(gpt_buffer + ER_ZFS_GPT_ENTRY_SIZE_OFFSET);
  first_usable_lba = er_zfs_get_le64(gpt_buffer + ER_ZFS_GPT_FIRST_USABLE_LBA_OFFSET);
  last_usable_lba = er_zfs_get_le64(gpt_buffer + ER_ZFS_GPT_LAST_USABLE_LBA_OFFSET);
  if (header_size < ER_ZFS_GPT_HEADER_MIN_BYTES ||
      header_size > device->logical_block_bytes ||
      entry_lba == 0u ||
      entry_count == 0u ||
      entry_size < ER_ZFS_GPT_PARTITION_ENTRY_MIN_BYTES ||
      entry_size > ER_ZFS_GPT_MAX_ENTRY_SIZE ||
      gpt_buffer_len < entry_size ||
      first_usable_lba > last_usable_lba) {
    return 0u;
  }
  entries_per_read = gpt_buffer_len / entry_size;
  if (entries_per_read == 0u) {
    return 0u;
  }
  for (entry_index = 0u; entry_index < entry_count;) {
    UINT32 remaining = entry_count - entry_index;
    UINT32 entries_to_read = remaining < entries_per_read ? remaining : entries_per_read;
    UINT64 byte_offset = ((UINT64)entry_index * (UINT64)entry_size);
    UINT64 read_lba = entry_lba + (byte_offset / device->logical_block_bytes);
    UINT32 read_blocks;
    UINT32 i;

    if ((byte_offset % device->logical_block_bytes) != 0u) {
      return 0u;
    }
    read_blocks = (entries_to_read * entry_size) / device->logical_block_bytes;
    if ((entries_to_read * entry_size) % device->logical_block_bytes != 0u) {
      read_blocks += 1u;
    }
    if (read_blocks == 0u ||
        read_blocks * device->logical_block_bytes > gpt_buffer_len ||
        er_block_device_read(device, read_lba, read_blocks, gpt_buffer,
                             read_blocks * device->logical_block_bytes) == 0u) {
      return 0u;
    }
    for (i = 0u; i < entries_to_read; ++i) {
      const UINT8* entry = gpt_buffer + ((UINTN)i * entry_size);
      ErZfsGptPartition partition;
      UINT64 block_count;

      if (er_zfs_gpt_read_partition(entry, entry_size,
                                    entry_index + i,
                                    first_usable_lba,
                                    last_usable_lba,
                                    &partition) == 0u) {
        continue;
      }
      block_count = partition.last_lba - partition.first_lba + 1u;
      if (er_zfs_probe_pool_at(device, partition.first_lba, block_count,
                               label_buffer, label_buffer_len,
                               out_probe) == 0u) {
        continue;
      }
      *out_partition = partition;
      return 1u;
    }
    entry_index += entries_to_read;
  }
  return 0u;
}

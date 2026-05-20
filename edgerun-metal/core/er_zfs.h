#ifndef ER_ZFS_H
#define ER_ZFS_H

/*
 * Purpose: identify raw ZFS pools from native block-device bytes.
 * Intention: fail closed before any analyzer or cleanup path trusts filesystem metadata.
 */

#include "er_block_device.h"

#define ER_ZFS_ABI_VERSION 1u
#define ER_ZFS_LABEL_BYTES 262144u
#define ER_ZFS_UBERBLOCK_BYTES 1024u
#define ER_ZFS_UBERBLOCK_MAGIC 0x00bab10cULL
#define ER_ZFS_GPT_PARTITION_ENTRY_MIN_BYTES 128u
#define ER_ZFS_GPT_PARTITION_GUID_BYTES 16u
#define ER_ZFS_GPT_PARTITION_NAME_BYTES 72u
#define ER_ZFS_GPT_PARTITION_NAME_CODE_UNITS 36u

typedef enum {
  ER_ZFS_LABEL_SLOT_HEAD0 = 0,
  ER_ZFS_LABEL_SLOT_HEAD1 = 1,
  ER_ZFS_LABEL_SLOT_TAIL0 = 2,
  ER_ZFS_LABEL_SLOT_TAIL1 = 3
} ErZfsLabelSlot;

typedef struct {
  UINT16 abi_version;
  UINT16 slot;
  UINT64 byte_offset;
  UINT64 txg;
  UINT64 timestamp;
  UINT64 rootbp_words[16];
} ErZfsUberblockSummary;

typedef struct {
  UINT16 abi_version;
  UINT16 label_count;
  UINT16 selected_slot;
  UINT16 reserved;
  UINT64 selected_txg;
  UINT64 pool_bytes;
  UINT64 base_lba;
  UINT64 block_count;
  ErZfsUberblockSummary selected;
} ErZfsPoolProbe;

typedef struct {
  UINT16 abi_version;
  UINT16 entry_index;
  UINT64 first_lba;
  UINT64 last_lba;
  UINT8 type_guid[ER_ZFS_GPT_PARTITION_GUID_BYTES];
  UINT8 unique_guid[ER_ZFS_GPT_PARTITION_GUID_BYTES];
  UINT16 utf16le_units[ER_ZFS_GPT_PARTITION_NAME_CODE_UNITS];
} ErZfsGptPartition;

UINT8 er_zfs_label_slot_offset(UINT64 device_bytes,
                               UINT16 slot,
                               UINT64* out_offset);
UINT8 er_zfs_probe_label_bytes(const UINT8* label_bytes,
                               UINT32 label_len,
                               UINT16 slot,
                               UINT64 label_offset,
                               ErZfsUberblockSummary* out_summary);
UINT8 er_zfs_probe_pool(const ErBlockDevice* device,
                        UINT8* label_buffer,
                        UINT32 label_buffer_len,
                        ErZfsPoolProbe* out_probe);
UINT8 er_zfs_probe_pool_at(const ErBlockDevice* device,
                           UINT64 base_lba,
                           UINT64 block_count,
                           UINT8* label_buffer,
                           UINT32 label_buffer_len,
                           ErZfsPoolProbe* out_probe);
UINT8 er_zfs_gpt_partition_name_matches_ascii(const ErZfsGptPartition* partition,
                                              const char* name,
                                              UINT32 name_len);
UINT8 er_zfs_probe_gpt_for_pool(const ErBlockDevice* device,
                                UINT8* gpt_buffer,
                                UINT32 gpt_buffer_len,
                                UINT8* label_buffer,
                                UINT32 label_buffer_len,
                                ErZfsGptPartition* out_partition,
                                ErZfsPoolProbe* out_probe);

#endif

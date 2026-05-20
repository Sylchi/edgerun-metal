#ifndef ER_BLOCK_DEVICE_H
#define ER_BLOCK_DEVICE_H

/*
 * Purpose: define the native block-device contract for storage analyzers.
 * Intention: keep filesystem code independent from NVMe, VirtIO, or board-specific media drivers.
 */

#include "er_types.h"

#define ER_BLOCK_DEVICE_ABI_VERSION 1u
#define ER_BLOCK_DEVICE_ID_BYTES 32u
#define ER_BLOCK_DEVICE_NAME_BYTES 48u

typedef UINT8 (*ErBlockDeviceReadFn)(void* ctx,
                                     UINT64 lba,
                                     UINT32 block_count,
                                     UINT8* out_bytes,
                                     UINT32 byte_len);
typedef UINT8 (*ErBlockDeviceWriteFn)(void* ctx,
                                      UINT64 lba,
                                      UINT32 block_count,
                                      const UINT8* bytes,
                                      UINT32 byte_len);
typedef UINT8 (*ErBlockDeviceFlushFn)(void* ctx);

typedef struct {
  UINT16 abi_version;
  UINT16 flags;
  UINT32 logical_block_bytes;
  UINT64 block_count;
  UINT8 device_id[ER_BLOCK_DEVICE_ID_BYTES];
  char name[ER_BLOCK_DEVICE_NAME_BYTES];
  void* ctx;
  ErBlockDeviceReadFn read;
  ErBlockDeviceWriteFn write;
  ErBlockDeviceFlushFn flush;
} ErBlockDevice;

UINT8 er_block_device_prepare(ErBlockDevice* out_device,
                              UINT32 logical_block_bytes,
                              UINT64 block_count,
                              const UINT8 device_id[ER_BLOCK_DEVICE_ID_BYTES],
                              const char* name,
                              UINT32 name_len,
                              void* ctx,
                              ErBlockDeviceReadFn read,
                              ErBlockDeviceWriteFn write,
                              ErBlockDeviceFlushFn flush);
UINT8 er_block_device_read(const ErBlockDevice* device,
                           UINT64 lba,
                           UINT32 block_count,
                           UINT8* out_bytes,
                           UINT32 byte_len);
UINT8 er_block_device_write(const ErBlockDevice* device,
                            UINT64 lba,
                            UINT32 block_count,
                            const UINT8* bytes,
                            UINT32 byte_len);
UINT8 er_block_device_flush(const ErBlockDevice* device);

#endif

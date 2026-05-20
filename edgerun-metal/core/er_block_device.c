#include "er_block_device.h"
#include "er_mem.h"

enum {
  ER_BLOCK_DEVICE_MIN_BLOCK_BYTES = 512u,
  ER_BLOCK_DEVICE_MAX_BLOCK_BYTES = 65536u,
  ER_BLOCK_DEVICE_UINT32_MAX = 0xffffffffu
};

static UINT8 er_block_device_name_valid(const char* name, UINT32 name_len) {
  UINT32 i;

  if (name == 0 || name_len == 0u || name_len >= ER_BLOCK_DEVICE_NAME_BYTES) {
    return 0u;
  }
  for (i = 0u; i < name_len; ++i) {
    if (*(name + i) == 0) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_block_device_geometry_valid(UINT32 logical_block_bytes,
                                            UINT64 block_count) {
  if (logical_block_bytes < ER_BLOCK_DEVICE_MIN_BLOCK_BYTES ||
      logical_block_bytes > ER_BLOCK_DEVICE_MAX_BLOCK_BYTES ||
      block_count == 0u) {
    return 0u;
  }
  if ((logical_block_bytes & (logical_block_bytes - 1u)) != 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_block_device_io_valid(const ErBlockDevice* device,
                                      UINT64 lba,
                                      UINT32 block_count,
                                      UINT32 byte_len) {
  UINT64 expected_bytes;

  if (device == 0 ||
      device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION ||
      er_block_device_geometry_valid(device->logical_block_bytes,
                                     device->block_count) == 0u ||
      block_count == 0u ||
      lba >= device->block_count ||
      (UINT64)block_count > device->block_count - lba) {
    return 0u;
  }
  expected_bytes = (UINT64)block_count * (UINT64)device->logical_block_bytes;
  if (expected_bytes > ER_BLOCK_DEVICE_UINT32_MAX ||
      byte_len != (UINT32)expected_bytes) {
    return 0u;
  }
  return 1u;
}

UINT8 er_block_device_prepare(ErBlockDevice* out_device,
                              UINT32 logical_block_bytes,
                              UINT64 block_count,
                              const UINT8 device_id[ER_BLOCK_DEVICE_ID_BYTES],
                              const char* name,
                              UINT32 name_len,
                              void* ctx,
                              ErBlockDeviceReadFn read,
                              ErBlockDeviceWriteFn write,
                              ErBlockDeviceFlushFn flush) {
  if (out_device == 0 ||
      device_id == 0 ||
      er_block_device_geometry_valid(logical_block_bytes, block_count) == 0u ||
      er_block_device_name_valid(name, name_len) == 0u ||
      ctx == 0 ||
      read == 0 ||
      write == 0 ||
      flush == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_device, (UINTN)sizeof(*out_device));
  out_device->abi_version = ER_BLOCK_DEVICE_ABI_VERSION;
  out_device->logical_block_bytes = logical_block_bytes;
  out_device->block_count = block_count;
  er_mem_copy(out_device->device_id, device_id, ER_BLOCK_DEVICE_ID_BYTES);
  er_mem_copy((UINT8*)out_device->name, (const UINT8*)name, name_len);
  out_device->ctx = ctx;
  out_device->read = read;
  out_device->write = write;
  out_device->flush = flush;
  return 1u;
}

UINT8 er_block_device_read(const ErBlockDevice* device,
                           UINT64 lba,
                           UINT32 block_count,
                           UINT8* out_bytes,
                           UINT32 byte_len) {
  if (out_bytes == 0 ||
      er_block_device_io_valid(device, lba, block_count, byte_len) == 0u ||
      device->read == 0) {
    return 0u;
  }
  return device->read(device->ctx, lba, block_count, out_bytes, byte_len);
}

UINT8 er_block_device_write(const ErBlockDevice* device,
                            UINT64 lba,
                            UINT32 block_count,
                            const UINT8* bytes,
                            UINT32 byte_len) {
  if (bytes == 0 ||
      er_block_device_io_valid(device, lba, block_count, byte_len) == 0u ||
      device->write == 0) {
    return 0u;
  }
  return device->write(device->ctx, lba, block_count, bytes, byte_len);
}

UINT8 er_block_device_flush(const ErBlockDevice* device) {
  if (device == 0 ||
      device->abi_version != ER_BLOCK_DEVICE_ABI_VERSION ||
      device->ctx == 0 ||
      device->flush == 0) {
    return 0u;
  }
  return device->flush(device->ctx);
}

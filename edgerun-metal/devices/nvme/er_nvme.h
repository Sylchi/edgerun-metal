#ifndef ER_NVME_H
#define ER_NVME_H

/*
 * Purpose: expose native NVMe controller register helpers for selected block devices.
 * Intention: keep raw disk analysis on runtime-owned storage paths instead of host mounts.
 */

#include "er_block_device.h"
#include "er_pci.h"

#define ER_NVME_ADMIN_QUEUE_DEPTH 16u
#define ER_NVME_IO_QUEUE_DEPTH 64u
#define ER_NVME_SECTOR_BYTES 512u

typedef struct {
  UINT8* admin_sq;
  UINT8* admin_cq;
  UINT8* io_sq;
  UINT8* io_cq;
  UINT32 admin_sq_bytes;
  UINT32 admin_cq_bytes;
  UINT32 io_sq_bytes;
  UINT32 io_cq_bytes;
} ErNvmeQueueMemory;

typedef struct {
  UINT64 mmio_base;
  UINT64 mmio_len;
  UINT64 cap;
  UINT32 version;
  UINT32 doorbell_stride_bytes;
  UINT32 page_bytes;
  UINT32 max_transfer_bytes;
  UINT8 initialized;
} ErNvmeController;

UINT8 er_nvme_pci_snapshot_supported(const ErPciDeviceSnapshot* snapshot,
                                     ErPciBarSelection* out_bar);
UINT32 er_nvme_doorbell_stride_from_cap(UINT64 cap);
UINT32 er_nvme_page_bytes_from_cap(UINT64 cap);
UINT8 er_nvme_queue_memory_valid(const ErNvmeQueueMemory* memory);
UINT8 er_nvme_prepare_controller(UINT64 mmio_base,
                                 UINT64 mmio_len,
                                 UINT64 cap,
                                 UINT32 version,
                                 const ErNvmeQueueMemory* memory,
                                 ErNvmeController* out_controller);

#endif

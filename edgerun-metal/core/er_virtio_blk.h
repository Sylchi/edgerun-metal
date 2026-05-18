#ifndef ER_VIRTIO_BLK_H
#define ER_VIRTIO_BLK_H

/*
 * Purpose: expose the native VirtIO block queue owner for object storage pages.
 * Intention: keep durable byte movement behind an explicit device endpoint.
 */

#include "er_types.h"
#include "er_virtio.h"

#define ER_VIRTIO_BLK_QUEUE 0u
#define ER_VIRTIO_BLK_SECTOR_BYTES 512u
#define ER_VIRTIO_BLK_REQ_READ 0u
#define ER_VIRTIO_BLK_REQ_WRITE 1u
#define ER_VIRTIO_BLK_STATUS_OK 0u
#define ER_VIRTIO_BLK_STATUS_IOERR 1u
#define ER_VIRTIO_BLK_STATUS_UNSUPP 2u

typedef struct {
  UINT32 submitted;
  UINT32 completed;
  UINT32 failed;
  UINT32 busy;
  UINT32 invalid;
} ErVirtioBlkStats;

typedef struct {
  ErVirtioMmioTransport transport;
  UINT64 features;
  UINT64 host_features;
  UINT64 capacity_sectors;
  UINT16 queue_size;
  UINT16 last_used_idx;
  UINT8 pending;
  UINT8 pending_status;
  UINT8 initialized;
  ErVirtioBlkStats stats;
} ErVirtioBlk;

typedef struct {
  UINT32 type;
  UINT32 reserved;
  UINT64 sector;
} ErVirtioBlkRequestHeader;

UINT8 er_virtio_blk_init_mmio(UINT64 base, UINT64 len, ErVirtioBlk* out_blk);
UINT8 er_virtio_blk_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioBlk* out_blk);
UINT8 er_virtio_blk_init_first_pci(ErVirtioBlk* out_blk);
UINT8 er_virtio_blk_submit_read(ErVirtioBlk* blk, UINT64 sector, UINT8* data, UINT32 data_len);
UINT8 er_virtio_blk_submit_write(ErVirtioBlk* blk, UINT64 sector, const UINT8* data, UINT32 data_len);
UINT8 er_virtio_blk_poll(ErVirtioBlk* blk, UINT8* out_status);
ErVirtioBlkStats er_virtio_blk_stats(ErVirtioBlk* blk);

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_blk_test_desc(void);
ErVirtioQueueAvail* er_virtio_blk_test_avail(void);
ErVirtioQueueUsed* er_virtio_blk_test_used(void);
ErVirtioBlkRequestHeader* er_virtio_blk_test_request(void);
UINT8* er_virtio_blk_test_status(void);
#endif

#endif

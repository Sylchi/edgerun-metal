#include "er_virtio_blk.h"
#include "er_mem.h"

/*
 * Purpose: implement a minimal polling VirtIO-blk split-queue driver.
 * Intention: provide deterministic block reads and writes before object storage policy uses durability.
 */

#define ER_VIRTIO_BLK_CONFIG_CAPACITY_OFFSET 0u
#define ER_VIRTIO_BLK_CHAIN_HEAD 0u
#define ER_VIRTIO_BLK_CHAIN_DATA 1u
#define ER_VIRTIO_BLK_CHAIN_STATUS 2u
#define ER_VIRTIO_BLK_CHAIN_DESCRIPTORS 3u
#define ER_VIRTIO_BLK_DATA_DESC_READ_FLAGS ER_VIRTIO_DESC_F_NEXT
#define ER_VIRTIO_BLK_DATA_DESC_WRITE_FLAGS (ER_VIRTIO_DESC_F_NEXT | ER_VIRTIO_DESC_F_WRITE)

#if defined(_MSC_VER)
#define ER_VIRTIO_BLK_ALIGN16 __declspec(align(16))
#else
#define ER_VIRTIO_BLK_ALIGN16 __attribute__((aligned(16)))
#endif

typedef struct ER_VIRTIO_BLK_ALIGN16 {
  ErVirtioQueueDesc items[ER_VIRTIO_QUEUE_SIZE];
} ErVirtioBlkDescTable;

static ErVirtioBlkDescTable g_blk_desc;
static ErVirtioQueueAvail g_blk_avail;
static ErVirtioQueueUsed g_blk_used;
static ErVirtioBlkRequestHeader g_blk_request;
static UINT8 g_blk_status;

static UINT8 er_virtio_blk_read_capacity(const ErVirtioMmioTransport* transport,
                                         UINT64* out_capacity_sectors) {
  UINT32 low = 0;
  UINT32 high = 0;

  if (transport == 0 || out_capacity_sectors == 0) {
    return 0u;
  }
  if (er_virtio_config_read32(transport, ER_VIRTIO_BLK_CONFIG_CAPACITY_OFFSET,
                              &low) == 0u ||
      er_virtio_config_read32(transport,
                              ER_VIRTIO_BLK_CONFIG_CAPACITY_OFFSET + sizeof(UINT32),
                              &high) == 0u) {
    return 0u;
  }
  *out_capacity_sectors = (UINT64)low | ((UINT64)high << 32u);
  return (UINT8)(*out_capacity_sectors != 0u);
}

static void er_virtio_blk_reset_storage(void) {
  er_virtio_queue_clear(g_blk_desc.items, &g_blk_avail, &g_blk_used);
  er_mem_zero((UINT8*)&g_blk_request, (UINTN)sizeof(g_blk_request));
  g_blk_status = ER_VIRTIO_BLK_STATUS_IOERR;
}

static UINT8 er_virtio_blk_request_len_valid(UINT32 data_len) {
  return (UINT8)(data_len != 0u &&
                 (data_len % ER_VIRTIO_BLK_SECTOR_BYTES) == 0u);
}

static UINT8 er_virtio_blk_sector_range_valid(const ErVirtioBlk* blk,
                                              UINT64 sector,
                                              UINT32 data_len) {
  UINT64 sectors;

  if (blk == 0 || blk->capacity_sectors == 0u ||
      er_virtio_blk_request_len_valid(data_len) == 0u) {
    return 0u;
  }
  sectors = (UINT64)data_len / ER_VIRTIO_BLK_SECTOR_BYTES;
  if (sector >= blk->capacity_sectors || sectors > blk->capacity_sectors - sector) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_virtio_blk_init_transport(const ErVirtioMmioTransport* transport,
                                          ErVirtioBlk* out_blk) {
  ErVirtioFeatureSet features;
  UINT16 queue_size = 0;
  UINT8 status = 0;

  if (out_blk == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
  er_virtio_blk_reset_storage();
  if (transport == 0 || transport->device_type != ER_VIRTIO_DEVICE_TYPE_BLK) {
    return 0u;
  }
  out_blk->transport = *transport;
  if (er_virtio_mmio_negotiate_features(&out_blk->transport,
                                        ER_VIRTIO_F_VERSION_1,
                                        &features) == 0u ||
      er_virtio_blk_read_capacity(&out_blk->transport,
                                  &out_blk->capacity_sectors) == 0u ||
      er_virtio_configure_driver_queue(&out_blk->transport,
                                       ER_VIRTIO_BLK_QUEUE,
                                       g_blk_desc.items,
                                       &g_blk_avail,
                                       &g_blk_used,
                                       &queue_size) == 0u ||
      queue_size < ER_VIRTIO_BLK_CHAIN_DESCRIPTORS) {
    (void)er_virtio_mmio_write_status(&out_blk->transport, ER_VIRTIO_STATUS_FAILED);
    er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
    return 0u;
  }
  out_blk->host_features = features.host;
  out_blk->features = features.driver;
  out_blk->queue_size = queue_size;
  if (er_virtio_mmio_read_status(&out_blk->transport, &status) == 0u ||
      er_virtio_mmio_write_status(&out_blk->transport,
                                  (UINT8)(status | ER_VIRTIO_STATUS_DRIVER_OK)) == 0u) {
    er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
    return 0u;
  }
  out_blk->initialized = 1u;
  return 1u;
}

UINT8 er_virtio_blk_init_mmio(UINT64 base, UINT64 len, ErVirtioBlk* out_blk) {
  ErVirtioMmioTransport transport;

  if (er_virtio_mmio_transport_init(base, len, ER_VIRTIO_DEVICE_TYPE_BLK,
                                    &transport) == 0u) {
    if (out_blk != 0) {
      er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
    }
    return 0u;
  }
  return er_virtio_blk_init_transport(&transport, out_blk);
}

UINT8 er_virtio_blk_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioBlk* out_blk) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_transport_init(bus, dev, func, ER_VIRTIO_DEVICE_TYPE_BLK,
                                   &transport) == 0u) {
    if (out_blk != 0) {
      er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
    }
    return 0u;
  }
  return er_virtio_blk_init_transport(&transport, out_blk);
}

UINT8 er_virtio_blk_init_first_pci(ErVirtioBlk* out_blk) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_find_transport(ER_VIRTIO_DEVICE_TYPE_BLK, &transport) == 0u) {
    if (out_blk != 0) {
      er_mem_zero((UINT8*)out_blk, (UINTN)sizeof(*out_blk));
    }
    return 0u;
  }
  return er_virtio_blk_init_transport(&transport, out_blk);
}

static UINT8 er_virtio_blk_submit(ErVirtioBlk* blk,
                                  UINT32 type,
                                  UINT64 sector,
                                  const UINT8* data,
                                  UINT32 data_len) {
  UINT16 data_flags;

  if (blk == 0 || blk->initialized == 0u || data == 0 ||
      blk->pending != 0u ||
      er_virtio_blk_sector_range_valid(blk, sector, data_len) == 0u) {
    if (blk != 0) {
      if (blk->pending != 0u) {
        ++blk->stats.busy;
      } else {
        ++blk->stats.invalid;
      }
    }
    return 0u;
  }
  switch (type) {
    case ER_VIRTIO_BLK_REQ_READ:
      data_flags = ER_VIRTIO_BLK_DATA_DESC_WRITE_FLAGS;
      break;
    case ER_VIRTIO_BLK_REQ_WRITE:
      data_flags = ER_VIRTIO_BLK_DATA_DESC_READ_FLAGS;
      break;
    default:
      ++blk->stats.invalid;
      return 0u;
  }

  er_mem_zero((UINT8*)&g_blk_request, (UINTN)sizeof(g_blk_request));
  g_blk_request.type = type;
  g_blk_request.sector = sector;
  g_blk_status = ER_VIRTIO_BLK_STATUS_IOERR;

  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_HEAD].addr = (UINT64)(UINTN)&g_blk_request;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_HEAD].len = (UINT32)sizeof(g_blk_request);
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_HEAD].flags = ER_VIRTIO_DESC_F_NEXT;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_HEAD].next = ER_VIRTIO_BLK_CHAIN_DATA;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_DATA].addr = (UINT64)(UINTN)data;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_DATA].len = data_len;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_DATA].flags = data_flags;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_DATA].next = ER_VIRTIO_BLK_CHAIN_STATUS;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_STATUS].addr = (UINT64)(UINTN)&g_blk_status;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_STATUS].len = (UINT32)sizeof(g_blk_status);
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_STATUS].flags = ER_VIRTIO_DESC_F_WRITE;
  g_blk_desc.items[ER_VIRTIO_BLK_CHAIN_STATUS].next = 0u;

  if (er_virtio_queue_post_descriptor(&g_blk_avail, blk->queue_size,
                                      ER_VIRTIO_BLK_CHAIN_HEAD) == 0u ||
      er_virtio_mmio_notify_queue(&blk->transport, ER_VIRTIO_BLK_QUEUE) == 0u) {
    return 0u;
  }
  blk->pending = 1u;
  ++blk->stats.submitted;
  return 1u;
}

UINT8 er_virtio_blk_submit_read(ErVirtioBlk* blk, UINT64 sector, UINT8* data, UINT32 data_len) {
  return er_virtio_blk_submit(blk, ER_VIRTIO_BLK_REQ_READ, sector, data, data_len);
}

UINT8 er_virtio_blk_submit_write(ErVirtioBlk* blk, UINT64 sector, const UINT8* data, UINT32 data_len) {
  return er_virtio_blk_submit(blk, ER_VIRTIO_BLK_REQ_WRITE, sector, data, data_len);
}

UINT8 er_virtio_blk_poll(ErVirtioBlk* blk, UINT8* out_status) {
  ErVirtioQueueUsedElem elem;

  if (blk == 0 || out_status == 0 || blk->initialized == 0u) {
    return 0u;
  }
  *out_status = ER_VIRTIO_BLK_STATUS_IOERR;
  if (blk->pending == 0u ||
      er_virtio_queue_take_next_used(&g_blk_used, blk->queue_size,
                                     &blk->last_used_idx, &elem) == 0u) {
    return 0u;
  }
  blk->pending = 0u;
  blk->pending_status = g_blk_status;
  *out_status = g_blk_status;
  if (elem.id != ER_VIRTIO_BLK_CHAIN_HEAD ||
      elem.len < (UINT32)sizeof(g_blk_status) ||
      g_blk_status != ER_VIRTIO_BLK_STATUS_OK) {
    ++blk->stats.failed;
    return 0u;
  }
  ++blk->stats.completed;
  return 1u;
}

ErVirtioBlkStats er_virtio_blk_stats(ErVirtioBlk* blk) {
  ErVirtioBlkStats empty;

  er_mem_zero((UINT8*)&empty, (UINTN)sizeof(empty));
  if (blk == 0) {
    return empty;
  }
  return blk->stats;
}

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_blk_test_desc(void) {
  return g_blk_desc.items;
}

ErVirtioQueueAvail* er_virtio_blk_test_avail(void) {
  return &g_blk_avail;
}

ErVirtioQueueUsed* er_virtio_blk_test_used(void) {
  return &g_blk_used;
}

ErVirtioBlkRequestHeader* er_virtio_blk_test_request(void) {
  return &g_blk_request;
}

UINT8* er_virtio_blk_test_status(void) {
  return &g_blk_status;
}
#endif

#ifndef ER_VIRTIO_H
#define ER_VIRTIO_H

/*
 * Purpose: define the native VirtIO transport and split-queue primitives used by metal drivers.
 * Intention: keep device policy outside the executor while making queue ownership explicit.
 */

#include "er_bus.h"
#include "er_types.h"

#define ER_VIRTIO_VENDOR_ID 0x1af4u
#define ER_VIRTIO_MODERN_DEVICE_ID_NET 0x1041u
#define ER_VIRTIO_MODERN_DEVICE_ID_BLK 0x1042u
#define ER_VIRTIO_MODERN_DEVICE_ID_CONSOLE 0x1043u
#define ER_VIRTIO_MODERN_DEVICE_ID_RNG 0x1044u
#define ER_VIRTIO_MODERN_DEVICE_ID_GPU 0x1050u

#define ER_VIRTIO_DEVICE_TYPE_NET 1u
#define ER_VIRTIO_DEVICE_TYPE_BLK 2u
#define ER_VIRTIO_DEVICE_TYPE_CONSOLE 3u
#define ER_VIRTIO_DEVICE_TYPE_RNG 4u
#define ER_VIRTIO_DEVICE_TYPE_GPU 16u

#define ER_VIRTIO_F_VERSION_1 (1ull << 32)
#define ER_VIRTIO_NET_F_MAC (1ull << 5)
#define ER_VIRTIO_NET_F_STATUS (1ull << 16)

#define ER_VIRTIO_STATUS_ACKNOWLEDGE 0x01u
#define ER_VIRTIO_STATUS_DRIVER 0x02u
#define ER_VIRTIO_STATUS_DRIVER_OK 0x04u
#define ER_VIRTIO_STATUS_FEATURES_OK 0x08u
#define ER_VIRTIO_STATUS_FAILED 0x80u

#define ER_VIRTIO_MMIO_MAGIC 0x74726976u
#define ER_VIRTIO_MMIO_VERSION_MODERN 2u
#define ER_VIRTIO_MMIO_VENDOR_ANY 0u

#define ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET 0x000u
#define ER_VIRTIO_MMIO_VERSION_OFFSET 0x004u
#define ER_VIRTIO_MMIO_DEVICE_ID_OFFSET 0x008u
#define ER_VIRTIO_MMIO_VENDOR_OFFSET 0x00cu
#define ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET 0x010u
#define ER_VIRTIO_MMIO_DEVICE_FEATURES_SEL_OFFSET 0x014u
#define ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET 0x020u
#define ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET 0x024u
#define ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET 0x030u
#define ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET 0x034u
#define ER_VIRTIO_MMIO_QUEUE_NUM_OFFSET 0x038u
#define ER_VIRTIO_MMIO_QUEUE_READY_OFFSET 0x044u
#define ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET 0x050u
#define ER_VIRTIO_MMIO_INTERRUPT_STATUS_OFFSET 0x060u
#define ER_VIRTIO_MMIO_INTERRUPT_ACK_OFFSET 0x064u
#define ER_VIRTIO_MMIO_STATUS_OFFSET 0x070u
#define ER_VIRTIO_MMIO_QUEUE_DESC_LOW_OFFSET 0x080u
#define ER_VIRTIO_MMIO_QUEUE_DESC_HIGH_OFFSET 0x084u
#define ER_VIRTIO_MMIO_QUEUE_DRIVER_LOW_OFFSET 0x090u
#define ER_VIRTIO_MMIO_QUEUE_DRIVER_HIGH_OFFSET 0x094u
#define ER_VIRTIO_MMIO_QUEUE_DEVICE_LOW_OFFSET 0x0a0u
#define ER_VIRTIO_MMIO_QUEUE_DEVICE_HIGH_OFFSET 0x0a4u
#define ER_VIRTIO_MMIO_CONFIG_OFFSET 0x100u

#define ER_VIRTIO_TRANSPORT_KIND_NONE 0u
#define ER_VIRTIO_TRANSPORT_KIND_MMIO 1u
#define ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI 2u

#define ER_VIRTIO_QUEUE_SIZE 16u
#define ER_VIRTIO_DESC_F_NEXT 0x0001u
#define ER_VIRTIO_DESC_F_WRITE 0x0002u

#define ER_VIRTIO_PCI_CAP_VENDOR 0x09u
#define ER_VIRTIO_PCI_CAP_COMMON_CFG 1u
#define ER_VIRTIO_PCI_CAP_NOTIFY_CFG 2u
#define ER_VIRTIO_PCI_CAP_ISR_CFG 3u
#define ER_VIRTIO_PCI_CAP_DEVICE_CFG 4u

typedef struct {
  UINT64 addr;
  UINT32 len;
  UINT16 flags;
  UINT16 next;
} ErVirtioQueueDesc;

typedef struct {
  UINT16 flags;
  UINT16 idx;
  UINT16 ring[ER_VIRTIO_QUEUE_SIZE];
  UINT16 used_event;
} ErVirtioQueueAvail;

typedef struct {
  UINT32 id;
  UINT32 len;
} ErVirtioQueueUsedElem;

typedef struct {
  UINT16 flags;
  UINT16 idx;
  ErVirtioQueueUsedElem ring[ER_VIRTIO_QUEUE_SIZE];
  UINT16 avail_event;
} ErVirtioQueueUsed;

typedef struct {
  UINT8 present;
  UINT8 cfg_type;
  UINT8 bar;
  UINT32 offset;
  UINT32 length;
  UINT32 notify_off_multiplier;
  ErBusAddress address;
} ErVirtioPciCap;

typedef struct {
  UINT8 transport_kind;
  UINT32 bus;
  UINT32 dev;
  UINT32 func;
  ErBusAddress address;
  ErVirtioPciCap common;
  ErVirtioPciCap notify;
  ErVirtioPciCap device;
  ErVirtioPciCap isr;
  UINT32 device_type;
  UINT32 vendor_id;
} ErVirtioMmioTransport;

typedef struct {
  UINT64 host;
  UINT64 driver;
} ErVirtioFeatureSet;

UINT8 er_virtio_mmio_transport_init(UINT64 base, UINT64 len, UINT32 expected_device_type,
                                    ErVirtioMmioTransport* out_transport);
UINT8 er_virtio_pci_transport_init(UINT32 bus, UINT32 dev, UINT32 func,
                                   UINT32 expected_device_type,
                                   ErVirtioMmioTransport* out_transport);
UINT8 er_virtio_pci_find_transport(UINT32 expected_device_type,
                                   ErVirtioMmioTransport* out_transport);
UINT8 er_virtio_mmio_read32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32* out_value);
UINT8 er_virtio_mmio_write32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32 value);
UINT8 er_virtio_mmio_read_features(const ErVirtioMmioTransport* transport, UINT64* out_features);
UINT8 er_virtio_mmio_write_driver_features(const ErVirtioMmioTransport* transport, UINT64 features);
UINT8 er_virtio_mmio_read_status(const ErVirtioMmioTransport* transport, UINT8* out_status);
UINT8 er_virtio_mmio_write_status(const ErVirtioMmioTransport* transport, UINT8 status);
UINT8 er_virtio_config_read8(const ErVirtioMmioTransport* transport, UINT64 offset, UINT8* out_value);
UINT8 er_virtio_config_read16(const ErVirtioMmioTransport* transport, UINT64 offset, UINT16* out_value);
UINT8 er_virtio_config_read32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32* out_value);
UINT8 er_virtio_mmio_negotiate_features(const ErVirtioMmioTransport* transport, UINT64 supported_features,
                                        ErVirtioFeatureSet* out_features);
UINT8 er_virtio_mmio_configure_split_queue(const ErVirtioMmioTransport* transport, UINT16 queue,
                                           UINT16 max_queue_size, UINT16 min_queue_size,
                                           UINT64 desc, UINT64 driver, UINT64 device,
                                           UINT16* out_queue_size);
UINT8 er_virtio_mmio_notify_queue(const ErVirtioMmioTransport* transport, UINT16 queue);
UINT8 er_virtio_mmio_take_interrupt_status(const ErVirtioMmioTransport* transport, UINT8* out_status);

void er_virtio_queue_clear(ErVirtioQueueDesc* desc, ErVirtioQueueAvail* avail,
                           ErVirtioQueueUsed* used);
UINT8 er_virtio_queue_post_descriptor(ErVirtioQueueAvail* avail, UINT16 queue_size, UINT16 desc_id);
UINT16 er_virtio_queue_used_idx(const ErVirtioQueueUsed* used);
UINT8 er_virtio_queue_take_next_used(const ErVirtioQueueUsed* used, UINT16 queue_size,
                                     UINT16* last_used_idx, ErVirtioQueueUsedElem* out_elem);

#endif

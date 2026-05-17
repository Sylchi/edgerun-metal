#include "er_virtio.h"
#include "er_mem.h"

/*
 * Purpose: implement VirtIO MMIO register access and split-queue helpers.
 * Intention: make the first native device-driver path testable before adding device policy.
 */

#define ER_VIRTIO_MMIO_MIN_LEN 0x200u
#define ER_VIRTIO_FEATURE_SEL_LOW 0u
#define ER_VIRTIO_FEATURE_SEL_HIGH 1u
#define ER_VIRTIO_U64_HIGH_SHIFT 32u
#define ER_VIRTIO_U32_MASK 0xffffffffull

static void er_virtio_fence(void) {
#if defined(__GNUC__) || defined(__clang__)
  __atomic_thread_fence(__ATOMIC_SEQ_CST);
#endif
}

static UINT32 er_virtio_low32(UINT64 value) {
  return (UINT32)(value & ER_VIRTIO_U32_MASK);
}

static UINT32 er_virtio_high32(UINT64 value) {
  return (UINT32)(value >> ER_VIRTIO_U64_HIGH_SHIFT);
}

static UINT8 er_virtio_mmio_set_failed(const ErVirtioMmioTransport* transport) {
  UINT8 status = 0;

  if (er_virtio_mmio_read_status(transport, &status) == 0u) {
    return 0;
  }
  return er_virtio_mmio_write_status(transport, (UINT8)(status | ER_VIRTIO_STATUS_FAILED));
}

UINT8 er_virtio_mmio_transport_init(UINT64 base, UINT64 len, UINT32 expected_device_type,
                                    ErVirtioMmioTransport* out_transport) {
  ErBusAddress address;
  UINT32 magic = 0;
  UINT32 version = 0;
  UINT32 device_type = 0;
  UINT32 vendor = 0;

  if (out_transport == 0 || len < ER_VIRTIO_MMIO_MIN_LEN) {
    return 0;
  }
  er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  if (er_bus_prepare_mmio32_address(base, len, 0u, ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                    &address) == 0u) {
    return 0;
  }
  out_transport->address = address;
  if (er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET, &magic) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_VERSION_OFFSET, &version) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_DEVICE_ID_OFFSET, &device_type) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_VENDOR_OFFSET, &vendor) == 0u) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0;
  }
  if (magic != ER_VIRTIO_MMIO_MAGIC || version != ER_VIRTIO_MMIO_VERSION_MODERN ||
      device_type == 0u ||
      (expected_device_type != 0u && device_type != expected_device_type)) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0;
  }
  out_transport->device_type = device_type;
  out_transport->vendor_id = vendor;
  return 1;
}

UINT8 er_virtio_mmio_read32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  return er_bus_read32(&transport->address, offset, out_value);
}

UINT8 er_virtio_mmio_write32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32 value) {
  if (transport == 0) {
    return 0;
  }
  return er_bus_write32(&transport->address, offset, value);
}

UINT8 er_virtio_mmio_read_features(const ErVirtioMmioTransport* transport, UINT64* out_features) {
  UINT32 low = 0;
  UINT32 high = 0;

  if (transport == 0 || out_features == 0) {
    return 0;
  }
  if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_SEL_OFFSET,
                            ER_VIRTIO_FEATURE_SEL_LOW) == 0u ||
      er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET, &low) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_SEL_OFFSET,
                            ER_VIRTIO_FEATURE_SEL_HIGH) == 0u ||
      er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET, &high) == 0u) {
    return 0;
  }
  *out_features = (UINT64)low | ((UINT64)high << ER_VIRTIO_U64_HIGH_SHIFT);
  return 1;
}

UINT8 er_virtio_mmio_write_driver_features(const ErVirtioMmioTransport* transport, UINT64 features) {
  if (transport == 0) {
    return 0;
  }
  return (UINT8)(er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET,
                                       ER_VIRTIO_FEATURE_SEL_LOW) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET,
                                       er_virtio_low32(features)) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET,
                                       ER_VIRTIO_FEATURE_SEL_HIGH) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET,
                                       er_virtio_high32(features)) != 0u);
}

UINT8 er_virtio_mmio_read_status(const ErVirtioMmioTransport* transport, UINT8* out_status) {
  UINT32 status = 0;

  if (out_status == 0 || er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_STATUS_OFFSET, &status) == 0u) {
    return 0;
  }
  *out_status = (UINT8)status;
  return 1;
}

UINT8 er_virtio_mmio_write_status(const ErVirtioMmioTransport* transport, UINT8 status) {
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_STATUS_OFFSET, (UINT32)status);
}

UINT8 er_virtio_mmio_negotiate_features(const ErVirtioMmioTransport* transport, UINT64 supported_features,
                                        ErVirtioFeatureSet* out_features) {
  UINT64 host = 0;
  UINT64 driver = 0;
  UINT8 status = 0;

  if (transport == 0 || out_features == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_features, (UINTN)sizeof(*out_features));
  if (er_virtio_mmio_write_status(transport, 0u) == 0u ||
      er_virtio_mmio_write_status(transport, ER_VIRTIO_STATUS_ACKNOWLEDGE) == 0u ||
      er_virtio_mmio_write_status(transport, ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER) == 0u ||
      er_virtio_mmio_read_features(transport, &host) == 0u) {
    return 0;
  }
  driver = host & supported_features;
  if ((driver & ER_VIRTIO_F_VERSION_1) == 0u) {
    (void)er_virtio_mmio_set_failed(transport);
    return 0;
  }
  if (er_virtio_mmio_write_driver_features(transport, driver) == 0u ||
      er_virtio_mmio_read_status(transport, &status) == 0u ||
      er_virtio_mmio_write_status(transport, (UINT8)(status | ER_VIRTIO_STATUS_FEATURES_OK)) == 0u ||
      er_virtio_mmio_read_status(transport, &status) == 0u) {
    return 0;
  }
  if ((status & ER_VIRTIO_STATUS_FEATURES_OK) == 0u) {
    (void)er_virtio_mmio_set_failed(transport);
    return 0;
  }
  out_features->host = host;
  out_features->driver = driver;
  return 1;
}

UINT8 er_virtio_mmio_configure_split_queue(const ErVirtioMmioTransport* transport, UINT16 queue,
                                           UINT16 max_queue_size, UINT16 min_queue_size,
                                           UINT64 desc, UINT64 driver, UINT64 device,
                                           UINT16* out_queue_size) {
  UINT32 host_queue_size = 0;
  UINT16 queue_size;

  if (transport == 0 || out_queue_size == 0 || max_queue_size == 0u ||
      min_queue_size == 0u || min_queue_size > max_queue_size ||
      desc == 0u || driver == 0u || device == 0u) {
    return 0;
  }
  *out_queue_size = 0;
  if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET, (UINT32)queue) == 0u ||
      er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET, &host_queue_size) == 0u) {
    return 0;
  }
  queue_size = (host_queue_size < (UINT32)max_queue_size) ? (UINT16)host_queue_size : max_queue_size;
  if (queue_size < min_queue_size) {
    return 0;
  }
  if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_NUM_OFFSET, (UINT32)queue_size) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DESC_LOW_OFFSET, er_virtio_low32(desc)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DESC_HIGH_OFFSET, er_virtio_high32(desc)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DRIVER_LOW_OFFSET, er_virtio_low32(driver)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DRIVER_HIGH_OFFSET, er_virtio_high32(driver)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DEVICE_LOW_OFFSET, er_virtio_low32(device)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DEVICE_HIGH_OFFSET, er_virtio_high32(device)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_READY_OFFSET, 1u) == 0u) {
    return 0;
  }
  *out_queue_size = queue_size;
  return 1;
}

UINT8 er_virtio_mmio_notify_queue(const ErVirtioMmioTransport* transport, UINT16 queue) {
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET, (UINT32)queue);
}

UINT8 er_virtio_mmio_take_interrupt_status(const ErVirtioMmioTransport* transport, UINT8* out_status) {
  UINT32 status = 0;

  if (out_status == 0 || er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_INTERRUPT_STATUS_OFFSET, &status) == 0u) {
    return 0;
  }
  *out_status = (UINT8)status;
  if (*out_status == 0u) {
    return 1;
  }
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_INTERRUPT_ACK_OFFSET, (UINT32)*out_status);
}

void er_virtio_queue_clear(ErVirtioQueueDesc* desc, ErVirtioQueueAvail* avail,
                           ErVirtioQueueUsed* used) {
  if (desc != 0) {
    er_mem_zero((UINT8*)desc, (UINTN)(sizeof(ErVirtioQueueDesc) * ER_VIRTIO_QUEUE_SIZE));
  }
  if (avail != 0) {
    er_mem_zero((UINT8*)avail, (UINTN)sizeof(*avail));
  }
  if (used != 0) {
    er_mem_zero((UINT8*)used, (UINTN)sizeof(*used));
  }
}

UINT8 er_virtio_queue_post_descriptor(ErVirtioQueueAvail* avail, UINT16 queue_size, UINT16 desc_id) {
  UINT16 idx;

  if (avail == 0 || queue_size == 0u || queue_size > ER_VIRTIO_QUEUE_SIZE || desc_id >= queue_size) {
    return 0;
  }
  idx = avail->idx;
  avail->ring[(UINTN)(idx % queue_size)] = desc_id;
  er_virtio_fence();
  avail->idx = (UINT16)(idx + 1u);
  return 1;
}

UINT16 er_virtio_queue_used_idx(const ErVirtioQueueUsed* used) {
  if (used == 0) {
    return 0;
  }
  return used->idx;
}

UINT8 er_virtio_queue_take_next_used(const ErVirtioQueueUsed* used, UINT16 queue_size,
                                     UINT16* last_used_idx, ErVirtioQueueUsedElem* out_elem) {
  UINT16 used_idx;
  UINT16 ring_idx;

  if (used == 0 || last_used_idx == 0 || out_elem == 0 ||
      queue_size == 0u || queue_size > ER_VIRTIO_QUEUE_SIZE) {
    return 0;
  }
  used_idx = er_virtio_queue_used_idx(used);
  if (used_idx == *last_used_idx) {
    return 0;
  }
  ring_idx = (UINT16)(*last_used_idx % queue_size);
  *out_elem = used->ring[ring_idx];
  *last_used_idx = (UINT16)(*last_used_idx + 1u);
  return 1;
}

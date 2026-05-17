#include "er_virtio_net.h"
#include "er_mem.h"

/*
 * Purpose: implement a minimal polling VirtIO-net split-queue driver.
 * Intention: provide native frame send/receive without depending on UEFI network services.
 */

#define ER_VIRTIO_NET_RX_QUEUE 0u
#define ER_VIRTIO_NET_TX_QUEUE 1u
#define ER_VIRTIO_NET_TX_FREE_ALL_MASK 0xffffu
#define ER_VIRTIO_NET_HDR_LEN 12u
#define ER_VIRTIO_NET_CONFIG_MAC_OFFSET 0u
#define ER_VIRTIO_NET_CONFIG_STATUS_OFFSET 6u

#if defined(_MSC_VER)
#define ER_VIRTIO_ALIGN16 __declspec(align(16))
#else
#define ER_VIRTIO_ALIGN16 __attribute__((aligned(16)))
#endif

typedef struct {
  UINT8 flags;
  UINT8 gso_type;
  UINT16 hdr_len;
  UINT16 gso_size;
  UINT16 csum_start;
  UINT16 csum_offset;
  UINT16 num_buffers;
} ErVirtioNetHeader;

typedef struct ER_VIRTIO_ALIGN16 {
  ErVirtioQueueDesc items[ER_VIRTIO_QUEUE_SIZE];
} ErVirtioNetDescTable;

typedef struct ER_VIRTIO_ALIGN16 {
  UINT8 bytes[ER_VIRTIO_QUEUE_SIZE][ER_VIRTIO_NET_BUFFER_SIZE];
} ErVirtioNetBuffers;

static ErVirtioNetDescTable g_rx_desc;
static ErVirtioQueueAvail g_rx_avail;
static ErVirtioQueueUsed g_rx_used;
static ErVirtioNetBuffers g_rx_buffers;

static ErVirtioNetDescTable g_tx_desc;
static ErVirtioQueueAvail g_tx_avail;
static ErVirtioQueueUsed g_tx_used;
static ErVirtioNetBuffers g_tx_buffers;

static UINT8 er_virtio_net_read_config8(const ErVirtioNet* net, UINT64 offset, UINT8* out_value) {
  if (net == 0 || out_value == 0) {
    return 0;
  }
  return er_virtio_config_read8(&net->transport, offset, out_value);
}

static UINT8 er_virtio_net_read_config16(const ErVirtioNet* net, UINT64 offset, UINT16* out_value) {
  if (net == 0 || out_value == 0) {
    return 0;
  }
  return er_virtio_config_read16(&net->transport, offset, out_value);
}

static UINT8 er_virtio_net_frame_len(UINT32 payload_len, UINT32* out_frame_len) {
  UINT32 frame_len;

  if (out_frame_len == 0 || payload_len == 0u ||
      payload_len > ER_VIRTIO_NET_BUFFER_SIZE - ER_VIRTIO_NET_HDR_LEN) {
    return 0;
  }
  frame_len = payload_len + ER_VIRTIO_NET_HDR_LEN;
  if (frame_len > ER_VIRTIO_NET_BUFFER_SIZE) {
    return 0;
  }
  *out_frame_len = frame_len;
  return 1;
}

static UINT8 er_virtio_net_payload_len(UINT32 frame_len, UINT32* out_payload_len) {
  if (out_payload_len == 0 || frame_len < ER_VIRTIO_NET_HDR_LEN ||
      frame_len > ER_VIRTIO_NET_BUFFER_SIZE) {
    return 0;
  }
  *out_payload_len = frame_len - ER_VIRTIO_NET_HDR_LEN;
  return 1;
}

static void er_virtio_net_clear_header(UINT8* buffer) {
  er_mem_zero(buffer, (UINTN)sizeof(ErVirtioNetHeader));
}

static void er_virtio_net_reset_storage(void) {
  er_virtio_queue_clear(g_rx_desc.items, &g_rx_avail, &g_rx_used);
  er_virtio_queue_clear(g_tx_desc.items, &g_tx_avail, &g_tx_used);
  er_mem_zero((UINT8*)&g_rx_buffers, (UINTN)sizeof(g_rx_buffers));
  er_mem_zero((UINT8*)&g_tx_buffers, (UINTN)sizeof(g_tx_buffers));
}

static UINT8 er_virtio_net_configure_queue(const ErVirtioMmioTransport* transport, UINT16 queue,
                                           ErVirtioQueueDesc* desc, ErVirtioQueueAvail* avail,
                                           ErVirtioQueueUsed* used, UINT16* out_queue_size) {
  return er_virtio_mmio_configure_split_queue(transport, queue, ER_VIRTIO_QUEUE_SIZE,
                                             ER_VIRTIO_QUEUE_SIZE, (UINT64)(UINTN)desc,
                                             (UINT64)(UINTN)avail, (UINT64)(UINTN)used,
                                             out_queue_size);
}

static void er_virtio_net_init_rx_queue(ErVirtioNet* net) {
  UINT16 i;

  net->rx_last_used_idx = 0;
  net->stats.rx_received = 0;
  net->stats.rx_invalid = 0;
  net->stats.rx_empty = 0;
  g_rx_avail.idx = 0;
  g_rx_used.idx = 0;
  for (i = 0; i < ER_VIRTIO_QUEUE_SIZE; ++i) {
    g_rx_desc.items[i].addr = (UINT64)(UINTN)&g_rx_buffers.bytes[i][0];
    g_rx_desc.items[i].len = ER_VIRTIO_NET_BUFFER_SIZE;
    g_rx_desc.items[i].flags = ER_VIRTIO_DESC_F_WRITE;
    g_rx_desc.items[i].next = 0;
    (void)er_virtio_queue_post_descriptor(&g_rx_avail, net->queue_size, i);
  }
}

static void er_virtio_net_init_tx_queue(ErVirtioNet* net) {
  net->tx_last_used_idx = 0;
  net->tx_free_mask = ER_VIRTIO_NET_TX_FREE_ALL_MASK;
  net->stats.tx_submitted = 0;
  net->stats.tx_completed = 0;
  g_tx_avail.idx = 0;
  g_tx_used.idx = 0;
}

static UINT8 er_virtio_net_take_tx_descriptor(ErVirtioNet* net, UINT16* out_desc_id) {
  UINT16 i;

  if (net == 0 || out_desc_id == 0 || net->tx_free_mask == 0u) {
    return 0;
  }
  for (i = 0; i < ER_VIRTIO_QUEUE_SIZE; ++i) {
    if ((net->tx_free_mask & (UINT16)(1u << i)) != 0u) {
      net->tx_free_mask = (UINT16)(net->tx_free_mask & (UINT16)~(UINT16)(1u << i));
      *out_desc_id = i;
      return 1;
    }
  }
  return 0;
}

static void er_virtio_net_reap_tx_used(ErVirtioNet* net) {
  ErVirtioQueueUsedElem elem;

  if (net == 0) {
    return;
  }
  while (er_virtio_queue_take_next_used(&g_tx_used, ER_VIRTIO_QUEUE_SIZE,
                                       &net->tx_last_used_idx, &elem) != 0u) {
    if (elem.id < ER_VIRTIO_QUEUE_SIZE) {
      net->tx_free_mask = (UINT16)(net->tx_free_mask | (UINT16)(1u << elem.id));
    }
    ++net->stats.tx_completed;
  }
}

static UINT8 er_virtio_net_init_transport(const ErVirtioMmioTransport* transport, ErVirtioNet* out_net) {
  ErVirtioFeatureSet features;
  UINT16 rx_queue_size = 0;
  UINT16 tx_queue_size = 0;
  UINT16 i;
  UINT8 status = 0;

  if (out_net == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_net, (UINTN)sizeof(*out_net));
  er_virtio_net_reset_storage();
  if (transport == 0 || transport->device_type != ER_VIRTIO_DEVICE_TYPE_NET) {
    return 0;
  }
  out_net->transport = *transport;
  if (er_virtio_mmio_negotiate_features(&out_net->transport,
                                        ER_VIRTIO_F_VERSION_1 | ER_VIRTIO_NET_F_MAC |
                                          ER_VIRTIO_NET_F_STATUS,
                                        &features) == 0u) {
    er_mem_zero((UINT8*)out_net, (UINTN)sizeof(*out_net));
    return 0;
  }
  out_net->host_features = features.host;
  out_net->features = features.driver;

  if ((out_net->features & ER_VIRTIO_NET_F_MAC) != 0u) {
    for (i = 0; i < ER_VIRTIO_NET_MAC_LEN; ++i) {
      if (er_virtio_net_read_config8(out_net, ER_VIRTIO_NET_CONFIG_MAC_OFFSET + i,
                                     &out_net->mac[i]) == 0u) {
        return 0;
      }
    }
  }
  if ((out_net->features & ER_VIRTIO_NET_F_STATUS) != 0u) {
    if (er_virtio_net_read_config16(out_net, ER_VIRTIO_NET_CONFIG_STATUS_OFFSET,
                                    &out_net->status) == 0u) {
      return 0;
    }
    out_net->link_up = (UINT8)((out_net->status & ER_VIRTIO_NET_STATUS_LINK_UP) != 0u);
  } else {
    out_net->status = ER_VIRTIO_NET_STATUS_LINK_UP;
    out_net->link_up = 1;
  }

  if (er_virtio_net_configure_queue(&out_net->transport, ER_VIRTIO_NET_RX_QUEUE,
                                    g_rx_desc.items, &g_rx_avail, &g_rx_used,
                                    &rx_queue_size) == 0u ||
      er_virtio_net_configure_queue(&out_net->transport, ER_VIRTIO_NET_TX_QUEUE,
                                    g_tx_desc.items, &g_tx_avail, &g_tx_used,
                                    &tx_queue_size) == 0u) {
    (void)er_virtio_mmio_write_status(&out_net->transport, ER_VIRTIO_STATUS_FAILED);
    return 0;
  }
  if (rx_queue_size != tx_queue_size) {
    (void)er_virtio_mmio_write_status(&out_net->transport, ER_VIRTIO_STATUS_FAILED);
    return 0;
  }
  out_net->queue_size = rx_queue_size;
  er_virtio_net_init_rx_queue(out_net);
  er_virtio_net_init_tx_queue(out_net);
  if (er_virtio_mmio_read_status(&out_net->transport, &status) == 0u ||
      er_virtio_mmio_write_status(&out_net->transport,
                                  (UINT8)(status | ER_VIRTIO_STATUS_DRIVER_OK)) == 0u ||
      er_virtio_mmio_notify_queue(&out_net->transport, ER_VIRTIO_NET_RX_QUEUE) == 0u) {
    return 0;
  }
  out_net->initialized = 1;
  return 1;
}

UINT8 er_virtio_net_init_mmio(UINT64 base, UINT64 len, ErVirtioNet* out_net) {
  ErVirtioMmioTransport transport;

  if (er_virtio_mmio_transport_init(base, len, ER_VIRTIO_DEVICE_TYPE_NET, &transport) == 0u) {
    if (out_net != 0) {
      er_mem_zero((UINT8*)out_net, (UINTN)sizeof(*out_net));
    }
    return 0;
  }
  return er_virtio_net_init_transport(&transport, out_net);
}

UINT8 er_virtio_net_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioNet* out_net) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_transport_init(bus, dev, func, ER_VIRTIO_DEVICE_TYPE_NET, &transport) == 0u) {
    if (out_net != 0) {
      er_mem_zero((UINT8*)out_net, (UINTN)sizeof(*out_net));
    }
    return 0;
  }
  return er_virtio_net_init_transport(&transport, out_net);
}

UINT8 er_virtio_net_init_first_pci(ErVirtioNet* out_net) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_find_transport(ER_VIRTIO_DEVICE_TYPE_NET, &transport) == 0u) {
    if (out_net != 0) {
      er_mem_zero((UINT8*)out_net, (UINTN)sizeof(*out_net));
    }
    return 0;
  }
  return er_virtio_net_init_transport(&transport, out_net);
}

UINT8 er_virtio_net_send(ErVirtioNet* net, const UINT8* frame, UINT32 frame_len) {
  UINT32 virtio_frame_len = 0;
  UINT16 desc_id = 0;
  UINT8* buffer;

  if (net == 0 || net->initialized == 0u || frame == 0 ||
      er_virtio_net_frame_len(frame_len, &virtio_frame_len) == 0u) {
    return 0;
  }
  er_virtio_net_reap_tx_used(net);
  if (er_virtio_net_take_tx_descriptor(net, &desc_id) == 0u) {
    return 0;
  }
  buffer = &g_tx_buffers.bytes[desc_id][0];
  er_virtio_net_clear_header(buffer);
  er_mem_copy(buffer + ER_VIRTIO_NET_HDR_LEN, frame, (UINTN)frame_len);
  g_tx_desc.items[desc_id].addr = (UINT64)(UINTN)buffer;
  g_tx_desc.items[desc_id].len = virtio_frame_len;
  g_tx_desc.items[desc_id].flags = 0;
  g_tx_desc.items[desc_id].next = 0;
  if (er_virtio_queue_post_descriptor(&g_tx_avail, net->queue_size, desc_id) == 0u ||
      er_virtio_mmio_notify_queue(&net->transport, ER_VIRTIO_NET_TX_QUEUE) == 0u) {
    net->tx_free_mask = (UINT16)(net->tx_free_mask | (UINT16)(1u << desc_id));
    return 0;
  }
  ++net->stats.tx_submitted;
  return 1;
}

UINT8 er_virtio_net_recv(ErVirtioNet* net, UINT8* out_frame, UINT32 out_capacity, UINT32* out_frame_len) {
  ErVirtioQueueUsedElem elem;
  UINT32 payload_len = 0;
  UINT32 copy_len = 0;
  UINT16 desc_id;

  if (net == 0 || net->initialized == 0u || out_frame_len == 0) {
    return 0;
  }
  *out_frame_len = 0;
  if (er_virtio_queue_take_next_used(&g_rx_used, ER_VIRTIO_QUEUE_SIZE,
                                     &net->rx_last_used_idx, &elem) == 0u) {
    return 0;
  }
  if (elem.id >= net->queue_size || er_virtio_net_payload_len(elem.len, &payload_len) == 0u) {
    ++net->stats.rx_invalid;
    if (elem.id < net->queue_size) {
      (void)er_virtio_queue_post_descriptor(&g_rx_avail, net->queue_size, (UINT16)elem.id);
      (void)er_virtio_mmio_notify_queue(&net->transport, ER_VIRTIO_NET_RX_QUEUE);
    }
    return 0;
  }
  desc_id = (UINT16)elem.id;
  copy_len = payload_len;
  if (copy_len > out_capacity) {
    copy_len = out_capacity;
  }
  if (copy_len == 0u) {
    ++net->stats.rx_empty;
  } else {
    if (out_frame == 0) {
      ++net->stats.rx_invalid;
      (void)er_virtio_queue_post_descriptor(&g_rx_avail, net->queue_size, desc_id);
      (void)er_virtio_mmio_notify_queue(&net->transport, ER_VIRTIO_NET_RX_QUEUE);
      return 0;
    }
    er_mem_copy(out_frame, &g_rx_buffers.bytes[desc_id][ER_VIRTIO_NET_HDR_LEN], (UINTN)copy_len);
    ++net->stats.rx_received;
  }
  *out_frame_len = copy_len;
  (void)er_virtio_queue_post_descriptor(&g_rx_avail, net->queue_size, desc_id);
  (void)er_virtio_mmio_notify_queue(&net->transport, ER_VIRTIO_NET_RX_QUEUE);
  return 1;
}

ErVirtioNetStats er_virtio_net_stats(ErVirtioNet* net) {
  ErVirtioNetStats empty;

  er_mem_zero((UINT8*)&empty, (UINTN)sizeof(empty));
  if (net == 0) {
    return empty;
  }
  if (net->initialized != 0u) {
    er_virtio_net_reap_tx_used(net);
  }
  return net->stats;
}

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_net_test_rx_desc(void) {
  return g_rx_desc.items;
}

ErVirtioQueueAvail* er_virtio_net_test_rx_avail(void) {
  return &g_rx_avail;
}

ErVirtioQueueUsed* er_virtio_net_test_rx_used(void) {
  return &g_rx_used;
}

UINT8* er_virtio_net_test_rx_buffer(UINT16 index) {
  if (index >= ER_VIRTIO_QUEUE_SIZE) {
    return 0;
  }
  return &g_rx_buffers.bytes[index][0];
}

ErVirtioQueueDesc* er_virtio_net_test_tx_desc(void) {
  return g_tx_desc.items;
}

ErVirtioQueueAvail* er_virtio_net_test_tx_avail(void) {
  return &g_tx_avail;
}

ErVirtioQueueUsed* er_virtio_net_test_tx_used(void) {
  return &g_tx_used;
}

UINT8* er_virtio_net_test_tx_buffer(UINT16 index) {
  if (index >= ER_VIRTIO_QUEUE_SIZE) {
    return 0;
  }
  return &g_tx_buffers.bytes[index][0];
}
#endif

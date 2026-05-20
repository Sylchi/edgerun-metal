#ifndef ER_VIRTIO_NET_H
#define ER_VIRTIO_NET_H

/*
 * Purpose: expose a polling VirtIO network driver for the metal relay path.
 * Intention: replace firmware UDP with an explicit native frame transport.
 */

#include "er_types.h"
#include "er_virtio.h"

#define ER_VIRTIO_NET_BUFFER_SIZE 2048u
#define ER_VIRTIO_NET_MTU 1500u
#define ER_VIRTIO_NET_MAC_LEN 6u
#define ER_VIRTIO_NET_STATUS_LINK_UP 0x0001u

typedef struct {
  UINT32 tx_submitted;
  UINT32 tx_completed;
  UINT32 rx_received;
  UINT32 rx_invalid;
  UINT32 rx_empty;
} ErVirtioNetStats;

typedef struct {
  ErVirtioMmioTransport transport;
  UINT64 features;
  UINT64 host_features;
  UINT8 mac[ER_VIRTIO_NET_MAC_LEN];
  UINT16 status;
  UINT16 queue_size;
  UINT16 rx_last_used_idx;
  UINT16 tx_last_used_idx;
  UINT16 tx_free_mask;
  UINT8 initialized;
  UINT8 link_up;
  ErVirtioNetStats stats;
} ErVirtioNet;

UINT8 er_virtio_net_init_mmio(UINT64 base, UINT64 len, ErVirtioNet* out_net);
UINT8 er_virtio_net_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioNet* out_net);
UINT8 er_virtio_net_init_first_pci(ErVirtioNet* out_net);
UINT8 er_virtio_net_send(ErVirtioNet* net, const UINT8* frame, UINT32 frame_len);
UINT8 er_virtio_net_recv(ErVirtioNet* net, UINT8* out_frame, UINT32 out_capacity, UINT32* out_frame_len);
ErVirtioNetStats er_virtio_net_stats(ErVirtioNet* net);

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_net_test_rx_desc(void);
ErVirtioQueueAvail* er_virtio_net_test_rx_avail(void);
ErVirtioQueueUsed* er_virtio_net_test_rx_used(void);
UINT8* er_virtio_net_test_rx_buffer(UINT16 index);
ErVirtioQueueDesc* er_virtio_net_test_tx_desc(void);
ErVirtioQueueAvail* er_virtio_net_test_tx_avail(void);
ErVirtioQueueUsed* er_virtio_net_test_tx_used(void);
UINT8* er_virtio_net_test_tx_buffer(UINT16 index);
#endif

#endif

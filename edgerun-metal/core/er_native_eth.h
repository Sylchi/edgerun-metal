#ifndef ER_NATIVE_ETH_H
#define ER_NATIVE_ETH_H

/*
 * Purpose: carry opaque EdgeRun bytes directly over native Ethernet frames.
 * Intention: keep MAC addresses as local route locators and keep IP/UDP/TLS out of the native path.
 */

#include "er_net_frame.h"
#include "er_virtio_net.h"

typedef struct {
  UINT32 tx_frames_sent;
  UINT32 rx_frames_polled;
  UINT32 rx_frames_accepted;
  UINT32 rx_frames_rejected;
} ErNativeEthStats;

typedef struct {
  ErVirtioNet* net;
  UINT8 peer_mac[ER_NET_MAC_LEN];
  ErNativeEthStats stats;
} ErNativeEth;

UINT8 er_native_eth_init(ErNativeEth* endpoint, ErVirtioNet* net,
                         const UINT8* peer_mac);
UINT8 er_native_eth_send(ErNativeEth* endpoint, const UINT8* payload,
                         UINT32 payload_len);
UINT8 er_native_eth_recv(ErNativeEth* endpoint, UINT8* out_payload,
                         UINT32 out_capacity, UINT32* out_payload_len);
ErNativeEthStats er_native_eth_stats(const ErNativeEth* endpoint);

#endif

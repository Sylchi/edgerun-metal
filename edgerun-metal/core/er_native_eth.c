#include "er_native_eth.h"
#include "er_mem.h"

/*
 * Purpose: implement direct L2 EdgeRun transport on top of VirtIO-net frames.
 * Intention: make native networking a byte mover for sealed work, not an IP stack.
 */

static UINT8 er_native_eth_valid_endpoint(const ErNativeEth* endpoint) {
  if (endpoint == 0 || endpoint->net == 0 ||
      endpoint->net->initialized == 0u || endpoint->net->link_up == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_native_eth_init(ErNativeEth* endpoint, ErVirtioNet* net,
                         const UINT8* peer_mac) {
  if (endpoint == 0 || net == 0 || net->initialized == 0u ||
      net->link_up == 0u || peer_mac == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)endpoint, (UINTN)sizeof(*endpoint));
  endpoint->net = net;
  er_mem_copy(endpoint->peer_mac, peer_mac, ER_NET_MAC_LEN);
  return 1;
}

UINT8 er_native_eth_send(ErNativeEth* endpoint, const UINT8* payload,
                         UINT32 payload_len) {
  UINT8 frame[ER_NET_FRAME_MAX];
  UINT32 frame_len = 0u;

  if (er_native_eth_valid_endpoint(endpoint) == 0u ||
      payload == 0 || payload_len == 0u) {
    return 0;
  }
  if (er_net_build_eth_frame(endpoint->net->mac, endpoint->peer_mac,
                             ER_NET_ETH_TYPE_EDGERUN, payload, payload_len,
                             frame, (UINT32)sizeof(frame), &frame_len) == 0u) {
    return 0;
  }
  if (er_virtio_net_send(endpoint->net, frame, frame_len) == 0u) {
    return 0;
  }
  ++endpoint->stats.tx_frames_sent;
  return 1;
}

UINT8 er_native_eth_recv(ErNativeEth* endpoint, UINT8* out_payload,
                         UINT32 out_capacity, UINT32* out_payload_len) {
  UINT8 frame[ER_NET_FRAME_MAX];
  UINT8 src_mac[ER_NET_MAC_LEN];
  UINT32 frame_len = 0u;

  if (er_native_eth_valid_endpoint(endpoint) == 0u || out_payload_len == 0) {
    return 0;
  }
  *out_payload_len = 0u;
  if (er_virtio_net_recv(endpoint->net, frame, (UINT32)sizeof(frame),
                         &frame_len) == 0u) {
    return 0;
  }
  ++endpoint->stats.rx_frames_polled;
  if (er_net_parse_eth_frame(frame, frame_len, endpoint->net->mac,
                             ER_NET_ETH_TYPE_EDGERUN, src_mac, out_payload,
                             out_capacity, out_payload_len) == 0u) {
    ++endpoint->stats.rx_frames_rejected;
    return 0;
  }
  ++endpoint->stats.rx_frames_accepted;
  er_mem_copy(endpoint->peer_mac, src_mac, ER_NET_MAC_LEN);
  return 1;
}

ErNativeEthStats er_native_eth_stats(const ErNativeEth* endpoint) {
  ErNativeEthStats empty;

  er_mem_zero((UINT8*)&empty, (UINTN)sizeof(empty));
  if (endpoint == 0) {
    return empty;
  }
  return endpoint->stats;
}

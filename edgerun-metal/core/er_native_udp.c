#include "er_native_udp.h"
#include "er_mem.h"

/*
 * Purpose: implement minimal native UDP carriage over VirtIO-net Ethernet frames.
 * Intention: keep address resolution explicit before replacing firmware UDP relay.
 */

static UINT8 er_native_udp_valid_endpoint(const ErNativeUdp* endpoint) {
  if (endpoint == 0 || endpoint->net == 0 ||
      endpoint->net->initialized == 0u || endpoint->net->link_up == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_native_udp_init(ErNativeUdp* endpoint, ErVirtioNet* net,
                         const UINT8* local_ip, UINT16 local_port,
                         const UINT8* remote_ip, UINT16 remote_port) {
  if (endpoint == 0 || net == 0 || net->initialized == 0u ||
      local_ip == 0 || remote_ip == 0 || local_port == 0u || remote_port == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)endpoint, (UINTN)sizeof(*endpoint));
  endpoint->net = net;
  er_mem_copy(endpoint->local_ip, local_ip, ER_NET_IPV4_LEN);
  er_mem_copy(endpoint->remote_ip, remote_ip, ER_NET_IPV4_LEN);
  endpoint->local_port = local_port;
  endpoint->remote_port = remote_port;
  return 1;
}

UINT8 er_native_udp_learn_arp(ErNativeUdp* endpoint, const UINT8* frame, UINT32 frame_len) {
  if (er_native_udp_valid_endpoint(endpoint) == 0u || frame == 0) {
    return 0;
  }
  if (er_net_parse_arp_ipv4_reply(frame, frame_len, endpoint->remote_ip,
                                  endpoint->local_ip, endpoint->remote_mac) == 0u) {
    return 0;
  }
  endpoint->remote_mac_known = 1u;
  ++endpoint->stats.arp_replies_accepted;
  return 1;
}

UINT8 er_native_udp_poll_arp(ErNativeUdp* endpoint, UINT32 max_frames) {
  UINT8 frame[ER_NET_FRAME_MAX];
  UINT32 frame_len;
  UINT32 i;
  UINT8 learned = 0u;

  if (er_native_udp_valid_endpoint(endpoint) == 0u || max_frames == 0u) {
    return 0;
  }
  for (i = 0; i < max_frames; ++i) {
    frame_len = 0u;
    if (er_virtio_net_recv(endpoint->net, frame, (UINT32)sizeof(frame), &frame_len) == 0u) {
      return learned;
    }
    ++endpoint->stats.rx_frames_polled;
    if (er_native_udp_learn_arp(endpoint, frame, frame_len) != 0u) {
      learned = 1u;
    }
  }
  return learned;
}

UINT8 er_native_udp_resolve(ErNativeUdp* endpoint) {
  UINT8 frame[ER_NET_ARP_FRAME_LEN];
  UINT32 frame_len = 0u;

  if (er_native_udp_valid_endpoint(endpoint) == 0u) {
    return 0;
  }
  if (endpoint->remote_mac_known != 0u) {
    return 1;
  }
  if (er_net_build_arp_request(endpoint->net->mac, endpoint->local_ip,
                               endpoint->remote_ip, frame, (UINT32)sizeof(frame),
                               &frame_len) == 0u) {
    return 0;
  }
  if (er_virtio_net_send(endpoint->net, frame, frame_len) == 0u) {
    return 0;
  }
  ++endpoint->stats.arp_requests_sent;
  return 1;
}

UINT8 er_native_udp_send(ErNativeUdp* endpoint, const UINT8* payload, UINT32 payload_len) {
  UINT8 frame[ER_NET_FRAME_MAX];
  UINT32 frame_len = 0u;

  if (er_native_udp_valid_endpoint(endpoint) == 0u ||
      payload == 0 || payload_len == 0u || endpoint->remote_mac_known == 0u) {
    return 0;
  }
  if (er_net_build_ipv4_udp_frame(endpoint->net->mac, endpoint->remote_mac,
                                  endpoint->local_ip, endpoint->remote_ip,
                                  endpoint->local_port, endpoint->remote_port,
                                  payload, payload_len, frame, (UINT32)sizeof(frame),
                                  &frame_len) == 0u) {
    return 0;
  }
  if (er_virtio_net_send(endpoint->net, frame, frame_len) == 0u) {
    return 0;
  }
  ++endpoint->stats.udp_frames_sent;
  return 1;
}

ErNativeUdpStats er_native_udp_stats(const ErNativeUdp* endpoint) {
  ErNativeUdpStats empty;

  er_mem_zero((UINT8*)&empty, (UINTN)sizeof(empty));
  if (endpoint == 0) {
    return empty;
  }
  return endpoint->stats;
}

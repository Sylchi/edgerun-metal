#ifndef ER_NATIVE_UDP_H
#define ER_NATIVE_UDP_H

/*
 * Purpose: bind a VirtIO-net device to a small native IPv4/UDP endpoint.
 * Intention: provide a firmware-free packet sink for relay bytes once ARP resolves.
 */

#include "er_net_frame.h"
#include "er_virtio_net.h"

typedef struct {
  UINT32 arp_requests_sent;
  UINT32 arp_replies_accepted;
  UINT32 udp_frames_sent;
  UINT32 rx_frames_polled;
} ErNativeUdpStats;

typedef struct {
  ErVirtioNet* net;
  UINT8 local_ip[ER_NET_IPV4_LEN];
  UINT8 remote_ip[ER_NET_IPV4_LEN];
  UINT8 remote_mac[ER_NET_MAC_LEN];
  UINT16 local_port;
  UINT16 remote_port;
  UINT8 remote_mac_known;
  ErNativeUdpStats stats;
} ErNativeUdp;

UINT8 er_native_udp_init(ErNativeUdp* endpoint, ErVirtioNet* net,
                         const UINT8* local_ip, UINT16 local_port,
                         const UINT8* remote_ip, UINT16 remote_port);
UINT8 er_native_udp_learn_arp(ErNativeUdp* endpoint, const UINT8* frame, UINT32 frame_len);
UINT8 er_native_udp_poll_arp(ErNativeUdp* endpoint, UINT32 max_frames);
UINT8 er_native_udp_resolve(ErNativeUdp* endpoint);
UINT8 er_native_udp_send(ErNativeUdp* endpoint, const UINT8* payload, UINT32 payload_len);
ErNativeUdpStats er_native_udp_stats(const ErNativeUdp* endpoint);

#endif

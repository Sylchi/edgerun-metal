#ifndef ER_NET_FRAME_H
#define ER_NET_FRAME_H

/*
 * Purpose: build minimal Ethernet frames for native metal network drivers.
 * Intention: keep packet serialization deterministic and independent of firmware UDP services.
 */

#include "er_types.h"

#define ER_NET_MAC_LEN 6u
#define ER_NET_IPV4_LEN 4u
#define ER_NET_ETH_HEADER_LEN 14u
#define ER_NET_IPV4_HEADER_LEN 20u
#define ER_NET_UDP_HEADER_LEN 8u
#define ER_NET_ARP_PAYLOAD_LEN 28u
#define ER_NET_ARP_FRAME_LEN (ER_NET_ETH_HEADER_LEN + ER_NET_ARP_PAYLOAD_LEN)
#define ER_NET_IPV4_UDP_HEADER_LEN (ER_NET_ETH_HEADER_LEN + ER_NET_IPV4_HEADER_LEN + ER_NET_UDP_HEADER_LEN)
#define ER_NET_ETH_MTU 1500u
#define ER_NET_FRAME_MAX (ER_NET_ETH_HEADER_LEN + ER_NET_ETH_MTU)
#define ER_NET_ETH_PAYLOAD_MAX ER_NET_ETH_MTU
#define ER_NET_UDP_PAYLOAD_MAX (ER_NET_ETH_MTU - ER_NET_IPV4_HEADER_LEN - ER_NET_UDP_HEADER_LEN)

#define ER_NET_ETH_TYPE_EDGERUN 0x88b5u
#define ER_NET_ETH_TYPE_IPV4 0x0800u
#define ER_NET_ETH_TYPE_ARP 0x0806u
#define ER_NET_IP_PROTO_UDP 17u

UINT16 er_net_checksum16(const UINT8* bytes, UINT32 len);
UINT8 er_net_build_eth_frame(const UINT8* src_mac, const UINT8* dst_mac,
                             UINT16 eth_type, const UINT8* payload,
                             UINT32 payload_len, UINT8* out_frame,
                             UINT32 out_capacity, UINT32* out_frame_len);
UINT8 er_net_parse_eth_frame(const UINT8* frame, UINT32 frame_len,
                             const UINT8* expected_dst_mac,
                             UINT16 expected_eth_type, UINT8* out_src_mac,
                             UINT8* out_payload, UINT32 out_capacity,
                             UINT32* out_payload_len);
UINT8 er_net_build_ipv4_udp_frame(const UINT8* src_mac, const UINT8* dst_mac,
                                  const UINT8* src_ip, const UINT8* dst_ip,
                                  UINT16 src_port, UINT16 dst_port,
                                  const UINT8* payload, UINT32 payload_len,
                                  UINT8* out_frame, UINT32 out_capacity,
                                  UINT32* out_frame_len);
UINT8 er_net_build_arp_request(const UINT8* src_mac, const UINT8* src_ip,
                               const UINT8* target_ip, UINT8* out_frame,
                               UINT32 out_capacity, UINT32* out_frame_len);
UINT8 er_net_parse_arp_ipv4_reply(const UINT8* frame, UINT32 frame_len,
                                  const UINT8* expected_sender_ip,
                                  const UINT8* expected_target_ip,
                                  UINT8* out_sender_mac);

#endif

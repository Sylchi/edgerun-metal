#include "er_net_frame.h"
#include "er_mem.h"

/*
 * Purpose: serialize Ethernet/IPv4/UDP and ARP packets for native drivers.
 * Intention: make firmware-free relay packets explicit byte records with deterministic checksums.
 */

#define ER_NET_U16_HIGH_SHIFT 8u
#define ER_NET_U16_BYTE_MASK 0xffu
#define ER_NET_U16_WORD_MASK 0xffffu
#define ER_NET_U32_HIGH16_SHIFT 16u
#define ER_NET_ETH_DST_OFFSET 0u
#define ER_NET_ETH_SRC_OFFSET 6u
#define ER_NET_ETH_TYPE_OFFSET 12u
#define ER_NET_IPV4_OFFSET ER_NET_ETH_HEADER_LEN
#define ER_NET_IPV4_VERSION_IHL 0x45u
#define ER_NET_IPV4_TOTAL_LEN_OFFSET 2u
#define ER_NET_IPV4_ID_OFFSET 4u
#define ER_NET_IPV4_FLAGS_FRAGMENT_OFFSET 6u
#define ER_NET_IPV4_TTL_OFFSET 8u
#define ER_NET_IPV4_PROTO_OFFSET 9u
#define ER_NET_IPV4_TTL 64u
#define ER_NET_IPV4_CHECKSUM_OFFSET 10u
#define ER_NET_IPV4_SRC_OFFSET 12u
#define ER_NET_IPV4_DST_OFFSET 16u
#define ER_NET_UDP_OFFSET (ER_NET_ETH_HEADER_LEN + ER_NET_IPV4_HEADER_LEN)
#define ER_NET_UDP_SRC_PORT_OFFSET 0u
#define ER_NET_UDP_DST_PORT_OFFSET 2u
#define ER_NET_UDP_LEN_OFFSET 4u
#define ER_NET_UDP_CHECKSUM_OFFSET 6u
#define ER_NET_UDP_CHECKSUM_ZERO 0u
#define ER_NET_UDP_PAYLOAD_OFFSET ER_NET_IPV4_UDP_HEADER_LEN
#define ER_NET_ARP_OFFSET ER_NET_ETH_HEADER_LEN
#define ER_NET_ARP_HTYPE_OFFSET 0u
#define ER_NET_ARP_PTYPE_OFFSET 2u
#define ER_NET_ARP_HLEN_OFFSET 4u
#define ER_NET_ARP_PLEN_OFFSET 5u
#define ER_NET_ARP_OP_OFFSET 6u
#define ER_NET_ARP_HTYPE_ETHERNET 1u
#define ER_NET_ARP_PTYPE_IPV4 ER_NET_ETH_TYPE_IPV4
#define ER_NET_ARP_HLEN_ETHERNET ER_NET_MAC_LEN
#define ER_NET_ARP_PLEN_IPV4 ER_NET_IPV4_LEN
#define ER_NET_ARP_OP_REQUEST 1u
#define ER_NET_ARP_OP_REPLY 2u
#define ER_NET_ARP_SHA_OFFSET 8u
#define ER_NET_ARP_SPA_OFFSET 14u
#define ER_NET_ARP_THA_OFFSET 18u
#define ER_NET_ARP_TPA_OFFSET 24u
#define ER_NET_BROADCAST_BYTE 0xffu

static void er_net_put_u16_be(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> ER_NET_U16_HIGH_SHIFT) & ER_NET_U16_BYTE_MASK);
  dst[1] = (UINT8)(value & ER_NET_U16_BYTE_MASK);
}

static UINT16 er_net_get_u16_be(const UINT8* src) {
  return (UINT16)(((UINT16)src[0] << ER_NET_U16_HIGH_SHIFT) | (UINT16)src[1]);
}

static UINT8 er_net_bytes_equal(const UINT8* a, const UINT8* b, UINT32 len) {
  UINT32 i;

  if (a == 0 || b == 0) {
    return 0;
  }
  for (i = 0; i < len; ++i) {
    if (a[i] != b[i]) {
      return 0;
    }
  }
  return 1;
}

static void er_net_put_eth_header(UINT8* frame, const UINT8* src_mac, const UINT8* dst_mac,
                                  UINT16 eth_type) {
  er_mem_copy(frame + ER_NET_ETH_DST_OFFSET, dst_mac, ER_NET_MAC_LEN);
  er_mem_copy(frame + ER_NET_ETH_SRC_OFFSET, src_mac, ER_NET_MAC_LEN);
  er_net_put_u16_be(frame + ER_NET_ETH_TYPE_OFFSET, eth_type);
}

UINT8 er_net_build_eth_frame(const UINT8* src_mac, const UINT8* dst_mac,
                             UINT16 eth_type, const UINT8* payload,
                             UINT32 payload_len, UINT8* out_frame,
                             UINT32 out_capacity, UINT32* out_frame_len) {
  UINT32 frame_len;

  if (src_mac == 0 || dst_mac == 0 || out_frame == 0 || out_frame_len == 0 ||
      eth_type == 0u || payload_len == 0u || payload_len > ER_NET_ETH_PAYLOAD_MAX ||
      payload == 0) {
    return 0;
  }
  frame_len = ER_NET_ETH_HEADER_LEN + payload_len;
  if (frame_len > out_capacity || frame_len > ER_NET_FRAME_MAX) {
    return 0;
  }
  er_net_put_eth_header(out_frame, src_mac, dst_mac, eth_type);
  er_mem_copy(out_frame + ER_NET_ETH_HEADER_LEN, payload, (UINTN)payload_len);
  *out_frame_len = frame_len;
  return 1;
}

UINT8 er_net_parse_eth_frame(const UINT8* frame, UINT32 frame_len,
                             const UINT8* expected_dst_mac,
                             UINT16 expected_eth_type, UINT8* out_src_mac,
                             UINT8* out_payload, UINT32 out_capacity,
                             UINT32* out_payload_len) {
  UINT32 payload_len;

  if (frame == 0 || expected_dst_mac == 0 || out_src_mac == 0 ||
      out_payload_len == 0 || expected_eth_type == 0u ||
      frame_len <= ER_NET_ETH_HEADER_LEN || frame_len > ER_NET_FRAME_MAX) {
    return 0;
  }
  payload_len = frame_len - ER_NET_ETH_HEADER_LEN;
  if (payload_len == 0u || payload_len > out_capacity ||
      er_net_bytes_equal(frame + ER_NET_ETH_DST_OFFSET, expected_dst_mac,
                         ER_NET_MAC_LEN) == 0u ||
      er_net_get_u16_be(frame + ER_NET_ETH_TYPE_OFFSET) != expected_eth_type) {
    return 0;
  }
  er_mem_copy(out_src_mac, frame + ER_NET_ETH_SRC_OFFSET, ER_NET_MAC_LEN);
  if (payload_len > 0u && out_payload == 0) {
    return 0;
  }
  er_mem_copy(out_payload, frame + ER_NET_ETH_HEADER_LEN, (UINTN)payload_len);
  *out_payload_len = payload_len;
  return 1;
}

UINT16 er_net_checksum16(const UINT8* bytes, UINT32 len) {
  UINT32 sum = 0;
  UINT32 i = 0;

  if (bytes == 0 || len == 0u) {
    return 0;
  }
  while (i + 1u < len) {
    sum += ((UINT32)bytes[i] << ER_NET_U16_HIGH_SHIFT) | (UINT32)bytes[i + 1u];
    i += 2u;
  }
  if (i < len) {
    sum += (UINT32)bytes[i] << ER_NET_U16_HIGH_SHIFT;
  }
  while ((sum >> ER_NET_U32_HIGH16_SHIFT) != 0u) {
    sum = (sum & ER_NET_U16_WORD_MASK) + (sum >> ER_NET_U32_HIGH16_SHIFT);
  }
  return (UINT16)(~sum & ER_NET_U16_WORD_MASK);
}

UINT8 er_net_build_ipv4_udp_frame(const UINT8* src_mac, const UINT8* dst_mac,
                                  const UINT8* src_ip, const UINT8* dst_ip,
                                  UINT16 src_port, UINT16 dst_port,
                                  const UINT8* payload, UINT32 payload_len,
                                  UINT8* out_frame, UINT32 out_capacity,
                                  UINT32* out_frame_len) {
  UINT32 udp_len;
  UINT32 ip_len;
  UINT32 frame_len;
  UINT8* ip;
  UINT8* udp;
  UINT16 ip_checksum;

  if (src_mac == 0 || dst_mac == 0 || src_ip == 0 || dst_ip == 0 ||
      out_frame == 0 || out_frame_len == 0 ||
      (payload_len > 0u && payload == 0) || payload_len > ER_NET_UDP_PAYLOAD_MAX) {
    return 0;
  }
  udp_len = ER_NET_UDP_HEADER_LEN + payload_len;
  ip_len = ER_NET_IPV4_HEADER_LEN + udp_len;
  frame_len = ER_NET_ETH_HEADER_LEN + ip_len;
  if (frame_len > out_capacity || frame_len > ER_NET_FRAME_MAX) {
    return 0;
  }
  er_mem_zero(out_frame, (UINTN)frame_len);
  er_net_put_eth_header(out_frame, src_mac, dst_mac, ER_NET_ETH_TYPE_IPV4);

  ip = out_frame + ER_NET_IPV4_OFFSET;
  ip[0] = ER_NET_IPV4_VERSION_IHL;
  ip[1] = 0;
  er_net_put_u16_be(ip + ER_NET_IPV4_TOTAL_LEN_OFFSET, (UINT16)ip_len);
  er_net_put_u16_be(ip + ER_NET_IPV4_ID_OFFSET, 0);
  er_net_put_u16_be(ip + ER_NET_IPV4_FLAGS_FRAGMENT_OFFSET, 0);
  ip[ER_NET_IPV4_TTL_OFFSET] = ER_NET_IPV4_TTL;
  ip[ER_NET_IPV4_PROTO_OFFSET] = ER_NET_IP_PROTO_UDP;
  er_mem_copy(ip + ER_NET_IPV4_SRC_OFFSET, src_ip, ER_NET_IPV4_LEN);
  er_mem_copy(ip + ER_NET_IPV4_DST_OFFSET, dst_ip, ER_NET_IPV4_LEN);
  ip_checksum = er_net_checksum16(ip, ER_NET_IPV4_HEADER_LEN);
  er_net_put_u16_be(ip + ER_NET_IPV4_CHECKSUM_OFFSET, ip_checksum);

  udp = out_frame + ER_NET_UDP_OFFSET;
  er_net_put_u16_be(udp + ER_NET_UDP_SRC_PORT_OFFSET, src_port);
  er_net_put_u16_be(udp + ER_NET_UDP_DST_PORT_OFFSET, dst_port);
  er_net_put_u16_be(udp + ER_NET_UDP_LEN_OFFSET, (UINT16)udp_len);
  er_net_put_u16_be(udp + ER_NET_UDP_CHECKSUM_OFFSET, ER_NET_UDP_CHECKSUM_ZERO);
  er_mem_copy(out_frame + ER_NET_UDP_PAYLOAD_OFFSET, payload, (UINTN)payload_len);
  *out_frame_len = frame_len;
  return 1;
}

UINT8 er_net_build_arp_request(const UINT8* src_mac, const UINT8* src_ip,
                               const UINT8* target_ip, UINT8* out_frame,
                               UINT32 out_capacity, UINT32* out_frame_len) {
  UINT8 broadcast[ER_NET_MAC_LEN];
  UINT8* arp;

  if (src_mac == 0 || src_ip == 0 || target_ip == 0 || out_frame == 0 ||
      out_frame_len == 0 || out_capacity < ER_NET_ARP_FRAME_LEN) {
    return 0;
  }
  for (UINT32 i = 0; i < ER_NET_MAC_LEN; ++i) {
    broadcast[i] = ER_NET_BROADCAST_BYTE;
  }
  er_mem_zero(out_frame, ER_NET_ARP_FRAME_LEN);
  er_net_put_eth_header(out_frame, src_mac, broadcast, ER_NET_ETH_TYPE_ARP);
  arp = out_frame + ER_NET_ARP_OFFSET;
  er_net_put_u16_be(arp + ER_NET_ARP_HTYPE_OFFSET, ER_NET_ARP_HTYPE_ETHERNET);
  er_net_put_u16_be(arp + ER_NET_ARP_PTYPE_OFFSET, ER_NET_ARP_PTYPE_IPV4);
  arp[ER_NET_ARP_HLEN_OFFSET] = ER_NET_ARP_HLEN_ETHERNET;
  arp[ER_NET_ARP_PLEN_OFFSET] = ER_NET_ARP_PLEN_IPV4;
  er_net_put_u16_be(arp + ER_NET_ARP_OP_OFFSET, ER_NET_ARP_OP_REQUEST);
  er_mem_copy(arp + ER_NET_ARP_SHA_OFFSET, src_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + ER_NET_ARP_SPA_OFFSET, src_ip, ER_NET_IPV4_LEN);
  er_mem_copy(arp + ER_NET_ARP_TPA_OFFSET, target_ip, ER_NET_IPV4_LEN);
  *out_frame_len = ER_NET_ARP_FRAME_LEN;
  return 1;
}

UINT8 er_net_parse_arp_ipv4_reply(const UINT8* frame, UINT32 frame_len,
                                  const UINT8* expected_sender_ip,
                                  const UINT8* expected_target_ip,
                                  UINT8* out_sender_mac) {
  const UINT8* arp;

  if (frame == 0 || expected_sender_ip == 0 || expected_target_ip == 0 ||
      out_sender_mac == 0 || frame_len < ER_NET_ARP_FRAME_LEN) {
    return 0;
  }
  if (er_net_get_u16_be(frame + ER_NET_ETH_TYPE_OFFSET) != ER_NET_ETH_TYPE_ARP) {
    return 0;
  }
  arp = frame + ER_NET_ARP_OFFSET;
  if (er_net_get_u16_be(arp + ER_NET_ARP_HTYPE_OFFSET) != ER_NET_ARP_HTYPE_ETHERNET ||
      er_net_get_u16_be(arp + ER_NET_ARP_PTYPE_OFFSET) != ER_NET_ARP_PTYPE_IPV4 ||
      arp[ER_NET_ARP_HLEN_OFFSET] != ER_NET_ARP_HLEN_ETHERNET ||
      arp[ER_NET_ARP_PLEN_OFFSET] != ER_NET_ARP_PLEN_IPV4 ||
      er_net_get_u16_be(arp + ER_NET_ARP_OP_OFFSET) != ER_NET_ARP_OP_REPLY) {
    return 0;
  }
  if (er_net_bytes_equal(arp + ER_NET_ARP_SPA_OFFSET, expected_sender_ip, ER_NET_IPV4_LEN) == 0u ||
      er_net_bytes_equal(arp + ER_NET_ARP_TPA_OFFSET, expected_target_ip, ER_NET_IPV4_LEN) == 0u) {
    return 0;
  }
  er_mem_copy(out_sender_mac, arp + ER_NET_ARP_SHA_OFFSET, ER_NET_MAC_LEN);
  return 1;
}

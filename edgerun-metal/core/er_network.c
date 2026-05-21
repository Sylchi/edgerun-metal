#include "er_network.h"
#include "er_mem.h"

/*
 * Purpose: coordinate local EdgeRun network locators and erwire carrier use.
 * Intention: keep carrier selection deterministic and keep work authority in er_work_route.
 */

#define ER_NETWORK_BYTE0 0u
#define ER_NETWORK_BYTE1 1u
#define ER_NETWORK_BYTE2 2u
#define ER_NETWORK_BYTE3 3u
#define ER_NETWORK_WIFI_GROUP_OFFSET 0u
#define ER_NETWORK_WIFI_CHANNEL_OFFSET 4u
#define ER_NETWORK_WIFI_SSID_LEN_OFFSET 5u
#define ER_NETWORK_WIFI_SSID_OFFSET 6u
#define ER_NETWORK_UDP_A_OFFSET 0u
#define ER_NETWORK_UDP_B_OFFSET 1u
#define ER_NETWORK_UDP_C_OFFSET 2u
#define ER_NETWORK_UDP_D_OFFSET 3u
#define ER_NETWORK_UDP_PORT_HIGH_OFFSET 4u
#define ER_NETWORK_UDP_PORT_LOW_OFFSET 5u
#define ER_NETWORK_U8_MASK 0xffu
#define ER_NETWORK_U16_HIGH_SHIFT 8u
#define ER_NETWORK_U32_BYTE2_SHIFT 16u
#define ER_NETWORK_U32_BYTE3_SHIFT 24u
#define ER_NETWORK_COST_DEFAULT 1u
#define ER_NETWORK_ERWIRE_PACKET_MAX (ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD)

static void er_network_put_u32_le(UINT8* dst, UINT32 value) {
  dst[ER_NETWORK_BYTE0] = (UINT8)(value & ER_NETWORK_U8_MASK);
  dst[ER_NETWORK_BYTE1] = (UINT8)((value >> ER_NETWORK_U16_HIGH_SHIFT) & ER_NETWORK_U8_MASK);
  dst[ER_NETWORK_BYTE2] = (UINT8)((value >> ER_NETWORK_U32_BYTE2_SHIFT) & ER_NETWORK_U8_MASK);
  dst[ER_NETWORK_BYTE3] = (UINT8)((value >> ER_NETWORK_U32_BYTE3_SHIFT) & ER_NETWORK_U8_MASK);
}

static UINT8 er_network_bytes_equal(const UINT8* a, const UINT8* b, UINTN len) {
  UINTN i;

  if (a == 0 || b == 0) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    if (a[i] != b[i]) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_network_node_equal(const ErNodeId* a, const ErNodeId* b) {
  if (a == 0 || b == 0) {
    return 0u;
  }
  return er_network_bytes_equal(a->bytes, b->bytes, ER_NODE_ID_LEN);
}

static UINT8 er_network_locator_address_len_valid(const ErNetworkLocator* locator) {
  if (locator == 0) {
    return 0u;
  }
  switch (locator->kind) {
    case ER_NETWORK_LOCATOR_KIND_NATIVE_ETH:
      return locator->address_len == ER_NETWORK_LOCATOR_NATIVE_ETH_LEN;
    case ER_NETWORK_LOCATOR_KIND_WIFI_OPEN:
      if (locator->address_len < ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN) {
        return 0u;
      }
      return locator->address_len ==
             (UINT8)(ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN +
                     locator->address[ER_NETWORK_WIFI_SSID_LEN_OFFSET]);
    case ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP:
      return locator->address_len == ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN;
    case ER_NETWORK_LOCATOR_KIND_MEMORY:
      return locator->address_len == 0u;
    default:
      return 0u;
  }
}

static UINT8 er_network_locator_shape_valid(const ErNetworkLocator* locator) {
  if (locator == 0 ||
      locator->abi_version != ER_NETWORK_ABI_VERSION ||
      locator->kind == ER_NETWORK_LOCATOR_KIND_NONE ||
      locator->directness == ER_NETWORK_DIRECTNESS_NONE ||
      locator->directness > ER_NETWORK_DIRECTNESS_STORE_FORWARD ||
      er_network_locator_address_len_valid(locator) == 0u) {
    return 0u;
  }
  if (locator->kind == ER_NETWORK_LOCATOR_KIND_WIFI_OPEN) {
    UINT8 ssid_len = locator->address[ER_NETWORK_WIFI_SSID_LEN_OFFSET];
    if (ssid_len > ER_NETWORK_LOCATOR_WIFI_OPEN_SSID_MAX ||
        locator->address[ER_NETWORK_WIFI_CHANNEL_OFFSET] == 0u) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_network_locator_better(const ErNetworkLocator* candidate,
                                       const ErNetworkLocator* current) {
  if (current == 0) {
    return 1u;
  }
  if (candidate->directness != current->directness) {
    return candidate->directness < current->directness;
  }
  if (candidate->cost_per_packet != current->cost_per_packet) {
    return candidate->cost_per_packet < current->cost_per_packet;
  }
  if (candidate->cost_per_byte != current->cost_per_byte) {
    return candidate->cost_per_byte < current->cost_per_byte;
  }
  if (candidate->priority != current->priority) {
    return candidate->priority > current->priority;
  }
  if (candidate->valid_until_ms != current->valid_until_ms) {
    return candidate->valid_until_ms > current->valid_until_ms;
  }
  return 0u;
}

static UINT8 er_network_route_valid(const ErNetworkRoute* route) {
  return route != 0 &&
         route->abi_version == ER_NETWORK_ABI_VERSION &&
         er_network_locator_shape_valid(&route->selected_locator) != 0u;
}

static UINT8 er_network_admitted_route_valid(const ErNetworkRoute* route,
                                             const ErAdmittedRoute* admitted_route) {
  return route != 0 &&
         admitted_route != 0 &&
         admitted_route->abi_version == ER_WORK_ABI_VERSION &&
         admitted_route->admitted_budget != 0u &&
         er_network_node_equal(&admitted_route->target_node_id,
                               &route->target_node_id) != 0u;
}

static UINT8 er_network_native_route_matches_io(const ErNetworkIo* io,
                                                const ErNetworkRoute* route) {
  return io != 0 &&
         io->abi_version == ER_NETWORK_ABI_VERSION &&
         io->native_eth != 0 &&
         route != 0 &&
         route->selected_locator.kind == ER_NETWORK_LOCATOR_KIND_NATIVE_ETH &&
         er_network_bytes_equal(io->native_eth->peer_mac,
                                route->selected_locator.address,
                                ER_NET_MAC_LEN) != 0u;
}

static UINT8 er_network_firmware_udp_route_matches_io(const ErNetworkIo* io,
                                                      const ErNetworkRoute* route) {
  const ErChannelEndpoint* endpoint;

  if (io == 0 ||
      io->abi_version != ER_NETWORK_ABI_VERSION ||
      io->firmware_udp == 0 ||
      route == 0 ||
      route->selected_locator.kind != ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP) {
    return 0u;
  }
  endpoint = io->firmware_udp;
  if (er_hw_relay_endpoint_is_firmware_udp(endpoint) == 0u ||
      endpoint->address_len != ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN ||
      er_network_bytes_equal(endpoint->address, route->selected_locator.address,
                             ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_network_wifi_open_carrier_valid(
    const ErNetworkWifiOpenCarrier* carrier) {
  return (UINT8)(carrier != 0 &&
                 carrier->abi_version == ER_NETWORK_ABI_VERSION &&
                 carrier->send != 0 &&
                 carrier->recv != 0);
}

static UINT8 er_network_wifi_open_route_matches_io(const ErNetworkIo* io,
                                                   const ErNetworkRoute* route) {
  return (UINT8)(io != 0 &&
                 io->abi_version == ER_NETWORK_ABI_VERSION &&
                 er_network_wifi_open_carrier_valid(io->wifi_open) != 0u &&
                 route != 0 &&
                 route->selected_locator.kind ==
                     ER_NETWORK_LOCATOR_KIND_WIFI_OPEN &&
                 er_network_locator_shape_valid(&route->selected_locator) != 0u);
}

static UINT8 er_network_route_from_peer_locator(const ErNetworkPeer* peer,
                                                UINT8 peer_index,
                                                UINT8 locator_index,
                                                ErNetworkRoute* out_route) {
  if (peer == 0 || out_route == 0 || locator_index >= peer->locator_count) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_route, (UINTN)sizeof(*out_route));
  out_route->abi_version = ER_NETWORK_ABI_VERSION;
  out_route->peer_index = peer_index;
  out_route->locator_index = locator_index;
  out_route->target_node_id = peer->node_id;
  out_route->next_hop_node_id = peer->node_id;
  out_route->selected_locator = peer->locators[locator_index];
  return 1u;
}

static UINT8 er_network_route_from_matching_locator(const ErNetworkPeer* peers,
                                                    UINT8 peer_count,
                                                    UINT8 locator_kind,
                                                    const UINT8* address,
                                                    UINT8 address_len,
                                                    UINT64 now_ms,
                                                    ErNetworkRoute* out_route) {
  UINT8 peer_index;
  UINT8 locator_index;

  if (peers == 0 || address == 0 || out_route == 0) {
    return 0u;
  }
  for (peer_index = 0u; peer_index < peer_count; ++peer_index) {
    const ErNetworkPeer* peer = &peers[peer_index];
    if (peer->abi_version != ER_NETWORK_ABI_VERSION ||
        peer->locator_count > ER_NETWORK_MAX_LOCATORS) {
      continue;
    }
    for (locator_index = 0u;
         locator_index < peer->locator_count;
         ++locator_index) {
      const ErNetworkLocator* locator = &peer->locators[locator_index];
      if (locator->kind == locator_kind &&
          er_network_locator_valid(locator, now_ms) != 0u &&
          locator->address_len == address_len &&
          er_network_bytes_equal(locator->address,
                                 address,
                                 address_len) != 0u) {
        return er_network_route_from_peer_locator(peer,
                                                  peer_index,
                                                  locator_index,
                                                  out_route);
      }
    }
  }
  return 0u;
}

UINT8 er_network_locator_prepare_native_eth(const UINT8 mac[ER_NET_MAC_LEN],
                                            UINT16 priority,
                                            UINT64 valid_until_ms,
                                            ErNetworkLocator* out_locator) {
  if (mac == 0 || out_locator == 0 || valid_until_ms == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_locator, (UINTN)sizeof(*out_locator));
  out_locator->abi_version = ER_NETWORK_ABI_VERSION;
  out_locator->kind = ER_NETWORK_LOCATOR_KIND_NATIVE_ETH;
  out_locator->directness = ER_NETWORK_DIRECTNESS_DIRECT;
  out_locator->priority = priority;
  out_locator->valid_until_ms = valid_until_ms;
  out_locator->cost_per_packet = ER_NETWORK_COST_DEFAULT;
  out_locator->cost_per_byte = ER_NETWORK_COST_DEFAULT;
  out_locator->address_len = ER_NETWORK_LOCATOR_NATIVE_ETH_LEN;
  er_mem_copy(out_locator->address, mac, ER_NETWORK_LOCATOR_NATIVE_ETH_LEN);
  return 1u;
}

UINT8 er_network_locator_prepare_wifi_open(UINT32 group_id,
                                           UINT8 channel,
                                           const UINT8* ssid,
                                           UINT8 ssid_len,
                                           UINT16 priority,
                                           UINT64 valid_until_ms,
                                           ErNetworkLocator* out_locator) {
  if (out_locator == 0 ||
      group_id == ER_BLE_WIFI_GROUP_ID_INVALID ||
      channel == 0u ||
      ssid_len > ER_NETWORK_LOCATOR_WIFI_OPEN_SSID_MAX ||
      (ssid_len > 0u && ssid == 0) ||
      valid_until_ms == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_locator, (UINTN)sizeof(*out_locator));
  out_locator->abi_version = ER_NETWORK_ABI_VERSION;
  out_locator->kind = ER_NETWORK_LOCATOR_KIND_WIFI_OPEN;
  out_locator->directness = ER_NETWORK_DIRECTNESS_DIRECT;
  out_locator->priority = priority;
  out_locator->valid_until_ms = valid_until_ms;
  out_locator->cost_per_packet = ER_NETWORK_COST_DEFAULT;
  out_locator->cost_per_byte = ER_NETWORK_COST_DEFAULT;
  out_locator->address_len = (UINT8)(ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN + ssid_len);
  er_network_put_u32_le(&out_locator->address[ER_NETWORK_WIFI_GROUP_OFFSET], group_id);
  out_locator->address[ER_NETWORK_WIFI_CHANNEL_OFFSET] = channel;
  out_locator->address[ER_NETWORK_WIFI_SSID_LEN_OFFSET] = ssid_len;
  if (ssid_len > 0u) {
    er_mem_copy(&out_locator->address[ER_NETWORK_WIFI_SSID_OFFSET], ssid, ssid_len);
  }
  return 1u;
}

UINT8 er_network_locator_prepare_firmware_udp(UINT8 a,
                                              UINT8 b,
                                              UINT8 c,
                                              UINT8 d,
                                              UINT16 port,
                                              UINT16 priority,
                                              UINT64 valid_until_ms,
                                              ErNetworkLocator* out_locator) {
  if (out_locator == 0 || port == 0u || valid_until_ms == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_locator, (UINTN)sizeof(*out_locator));
  out_locator->abi_version = ER_NETWORK_ABI_VERSION;
  out_locator->kind = ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP;
  out_locator->directness = ER_NETWORK_DIRECTNESS_DIRECT;
  out_locator->priority = priority;
  out_locator->valid_until_ms = valid_until_ms;
  out_locator->cost_per_packet = ER_NETWORK_COST_DEFAULT;
  out_locator->cost_per_byte = ER_NETWORK_COST_DEFAULT;
  out_locator->address_len = ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN;
  out_locator->address[ER_NETWORK_UDP_A_OFFSET] = a;
  out_locator->address[ER_NETWORK_UDP_B_OFFSET] = b;
  out_locator->address[ER_NETWORK_UDP_C_OFFSET] = c;
  out_locator->address[ER_NETWORK_UDP_D_OFFSET] = d;
  out_locator->address[ER_NETWORK_UDP_PORT_HIGH_OFFSET] =
      (UINT8)((port >> ER_NETWORK_U16_HIGH_SHIFT) & ER_NETWORK_U8_MASK);
  out_locator->address[ER_NETWORK_UDP_PORT_LOW_OFFSET] =
      (UINT8)(port & ER_NETWORK_U8_MASK);
  return 1u;
}

UINT8 er_network_locator_prepare_memory(UINT16 priority,
                                        UINT64 valid_until_ms,
                                        ErNetworkLocator* out_locator) {
  if (out_locator == 0 || valid_until_ms == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_locator, (UINTN)sizeof(*out_locator));
  out_locator->abi_version = ER_NETWORK_ABI_VERSION;
  out_locator->kind = ER_NETWORK_LOCATOR_KIND_MEMORY;
  out_locator->directness = ER_NETWORK_DIRECTNESS_DIRECT;
  out_locator->priority = priority;
  out_locator->valid_until_ms = valid_until_ms;
  out_locator->cost_per_packet = 0u;
  out_locator->cost_per_byte = 0u;
  out_locator->address_len = 0u;
  return 1u;
}

UINT8 er_network_locator_from_wifi_burst(const ErWifiBurstPlan* plan,
                                         UINT16 priority,
                                         UINT64 valid_until_ms,
                                         ErNetworkLocator* out_locator) {
  if (plan == 0 || plan->open == 0u) {
    return 0u;
  }
  return er_network_locator_prepare_wifi_open(plan->group_id,
                                              plan->wifi_channel,
                                              plan->ssid,
                                              plan->ssid_len,
                                              priority,
                                              valid_until_ms,
                                              out_locator);
}

UINT8 er_network_locator_valid(const ErNetworkLocator* locator,
                               UINT64 now_ms) {
  return er_network_locator_shape_valid(locator) != 0u &&
         locator->valid_until_ms > now_ms;
}

UINT8 er_network_peer_prepare(const ErNodeId* node_id,
                              const ErNetworkLocator* locators,
                              UINT8 locator_count,
                              ErNetworkPeer* out_peer) {
  UINT8 i;

  if (node_id == 0 || out_peer == 0 ||
      locator_count > ER_NETWORK_MAX_LOCATORS ||
      (locator_count > 0u && locators == 0)) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_peer, (UINTN)sizeof(*out_peer));
  out_peer->abi_version = ER_NETWORK_ABI_VERSION;
  out_peer->node_id = *node_id;
  for (i = 0u; i < locator_count; ++i) {
    if (er_network_peer_add_locator(out_peer, &locators[i]) == 0u) {
      er_mem_zero((UINT8*)out_peer, (UINTN)sizeof(*out_peer));
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_network_peer_add_locator(ErNetworkPeer* peer,
                                  const ErNetworkLocator* locator) {
  if (peer == 0 ||
      locator == 0 ||
      peer->abi_version != ER_NETWORK_ABI_VERSION ||
      peer->locator_count >= ER_NETWORK_MAX_LOCATORS ||
      er_network_locator_shape_valid(locator) == 0u) {
    return 0u;
  }
  peer->locators[peer->locator_count] = *locator;
  ++peer->locator_count;
  return 1u;
}

UINT8 er_network_route_select(const ErNetworkPeer* peers,
                              UINT8 peer_count,
                              const ErNodeId* target_node_id,
                              UINT64 now_ms,
                              ErNetworkRoute* out_route) {
  UINT8 peer_index;
  UINT8 locator_index;
  const ErNetworkPeer* best_peer = 0;
  const ErNetworkLocator* best_locator = 0;
  UINT8 best_peer_index = 0u;
  UINT8 best_locator_index = 0u;

  if (peers == 0 || target_node_id == 0 || out_route == 0 || peer_count == 0u) {
    return 0u;
  }
  for (peer_index = 0u; peer_index < peer_count; ++peer_index) {
    const ErNetworkPeer* peer = &peers[peer_index];
    if (peer->abi_version != ER_NETWORK_ABI_VERSION ||
        peer->locator_count > ER_NETWORK_MAX_LOCATORS ||
        er_network_node_equal(&peer->node_id, target_node_id) == 0u) {
      continue;
    }
    for (locator_index = 0u; locator_index < peer->locator_count; ++locator_index) {
      const ErNetworkLocator* locator = &peer->locators[locator_index];
      if (er_network_locator_valid(locator, now_ms) == 0u) {
        continue;
      }
      if (best_locator == 0 ||
          er_network_locator_better(locator, best_locator) != 0u) {
        best_peer = peer;
        best_locator = locator;
        best_peer_index = peer_index;
        best_locator_index = locator_index;
      }
    }
  }
  if (best_peer == 0 || best_locator == 0) {
    return 0u;
  }
  return er_network_route_from_peer_locator(best_peer, best_peer_index,
                                            best_locator_index, out_route);
}

UINT8 er_network_erwire_kind_requires_admission(UINT16 kind) {
  switch (kind) {
    case ERWIRE_KIND_CHANNEL_ENVELOPE:
    case ERWIRE_KIND_CAPABILITY_ENVELOPE:
    case ERWIRE_KIND_RELAY_TRANSIT_HOP:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_network_send_erwire(ErNetworkIo* io,
                             const ErNetworkRoute* route,
                             const ErAdmittedRoute* admitted_route,
                             UINT16 kind,
                             UINT16 flags,
                             const UINT8* payload,
                             UINT32 payload_len) {
  if (io == 0 ||
      io->abi_version != ER_NETWORK_ABI_VERSION ||
      er_network_route_valid(route) == 0u ||
      (er_network_erwire_kind_requires_admission(kind) != 0u &&
       er_network_admitted_route_valid(route, admitted_route) == 0u) ||
      payload_len > ERWIRE_MAX_PAYLOAD ||
      (payload_len > 0u && payload == 0)) {
    return 0u;
  }
  switch (route->selected_locator.kind) {
    case ER_NETWORK_LOCATOR_KIND_NATIVE_ETH:
      if (er_network_native_route_matches_io(io, route) == 0u ||
          erwire_set_native_eth_sink(io->native_eth) == 0u) {
        return 0u;
      }
      erwire_send(kind, flags, payload, payload_len);
      erwire_clear_native_eth_sink();
      return 1u;
    case ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP:
      if (er_network_firmware_udp_route_matches_io(io, route) == 0u) {
        return 0u;
      }
      erwire_clear_native_eth_sink();
      erwire_send(kind, flags, payload, payload_len);
      return 1u;
    case ER_NETWORK_LOCATOR_KIND_WIFI_OPEN:
    {
      UINT8 packet[ER_NETWORK_ERWIRE_PACKET_MAX];
      UINT32 packet_len = 0u;

      if (er_network_wifi_open_route_matches_io(io, route) == 0u ||
          erwire_build_packet(kind,
                              flags,
                              payload,
                              payload_len,
                              packet,
                              (UINT32)sizeof(packet),
                              &packet_len) == 0u) {
        return 0u;
      }
      return io->wifi_open->send(io->wifi_open->ctx,
                                 &route->selected_locator,
                                 packet,
                                 packet_len);
    }
    case ER_NETWORK_LOCATOR_KIND_MEMORY:
    default:
      return 0u;
  }
}

UINT8 er_network_poll_erwire(ErNetworkIo* io,
                             const ErNetworkPeer* peers,
                             UINT8 peer_count,
                             UINT64 now_ms,
                             ErNetworkRoute* out_route,
                             ErwirePacketHeader* out_header,
                             UINT8* out_payload,
                             UINT32 out_capacity,
                             UINT32* out_payload_len) {
  UINT8 packet[ER_NETWORK_ERWIRE_PACKET_MAX];
  UINT32 packet_len = 0u;
  ErNetworkLocator wifi_locator;

  if (io == 0 ||
      io->abi_version != ER_NETWORK_ABI_VERSION ||
      peers == 0 ||
      out_route == 0 ||
      out_payload_len == 0) {
    return 0u;
  }
  if (io->native_eth != 0 &&
      erwire_set_native_eth_sink(io->native_eth) != 0u &&
      erwire_poll_native_eth(out_header, out_payload, out_capacity,
                             out_payload_len) != 0u) {
    erwire_clear_native_eth_sink();
    return er_network_route_from_matching_locator(peers,
                                                  peer_count,
                                                  ER_NETWORK_LOCATOR_KIND_NATIVE_ETH,
                                                  io->native_eth->peer_mac,
                                                  ER_NETWORK_LOCATOR_NATIVE_ETH_LEN,
                                                  now_ms,
                                                  out_route);
  }
  erwire_clear_native_eth_sink();

  if (er_network_wifi_open_carrier_valid(io->wifi_open) == 0u ||
      io->wifi_open->recv(io->wifi_open->ctx,
                          &wifi_locator,
                          packet,
                          (UINT32)sizeof(packet),
                          &packet_len) == 0u ||
      erwire_parse_packet(packet,
                          packet_len,
                          out_header,
                          out_payload,
                          out_capacity,
                          out_payload_len) == 0u) {
    return 0u;
  }
  return er_network_route_from_matching_locator(peers,
                                                peer_count,
                                                ER_NETWORK_LOCATOR_KIND_WIFI_OPEN,
                                                wifi_locator.address,
                                                wifi_locator.address_len,
                                                now_ms,
                                                out_route);
}

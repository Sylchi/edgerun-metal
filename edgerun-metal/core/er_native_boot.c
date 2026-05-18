#include "er_native_boot.h"
#include "er_mem.h"
#include "er_work_route.h"

enum {
  ER_NATIVE_BOOT_QEMU_MICROVM_CANDIDATES = 2u,
  ER_NATIVE_BOOT_MAC0 = 0x02u,
  ER_NATIVE_BOOT_MAC1 = 0x21u,
  ER_NATIVE_BOOT_MAC2 = 0x22u,
  ER_NATIVE_BOOT_MAC3 = 0x23u,
  ER_NATIVE_BOOT_MAC4 = 0x24u,
  ER_NATIVE_BOOT_MAC5 = 0x25u
};

static const UINT8 g_native_relay_ingress_domain[] = "edgerun:c:v1:native-relay-ingress";
static const char g_native_relay_ingress_label[] = "native-eth";
static ErVirtioNet g_native_boot_net;
static ErNativeEth g_native_boot_eth;
static const UINT8 g_qemu_microvm_peer_mac[ER_NET_MAC_LEN] = {
  ER_NATIVE_BOOT_MAC0,
  ER_NATIVE_BOOT_MAC1,
  ER_NATIVE_BOOT_MAC2,
  ER_NATIVE_BOOT_MAC3,
  ER_NATIVE_BOOT_MAC4,
  ER_NATIVE_BOOT_MAC5
};

static void er_native_boot_clear_state(ErNativeBootState* state) {
  if (state == 0) {
    return;
  }
  er_mem_zero((UINT8*)state, (UINTN)sizeof(*state));
}

static void er_native_boot_clear_eth_sink(void) {
  erwire_clear_native_eth_sink();
  er_mem_zero((UINT8*)&g_native_boot_net, (UINTN)sizeof(g_native_boot_net));
  er_mem_zero((UINT8*)&g_native_boot_eth, (UINTN)sizeof(g_native_boot_eth));
}

static void er_native_boot_set_eth_sink_state(ErNativeBootState* state) {
  if (state == 0) {
    return;
  }
  state->initialized = 1u;
  state->erwire_sink_ready = 1u;
  state->net = &g_native_boot_net;
  state->eth = &g_native_boot_eth;
}

UINT8 er_native_boot_configure_erwire_eth_sink(UINT64 mmio_base, UINT64 mmio_len,
                                               const UINT8* peer_mac,
                                               ErNativeBootState* out_state) {
  er_native_boot_clear_state(out_state);
  er_native_boot_clear_eth_sink();

  if (peer_mac == 0 ||
      er_virtio_net_init_mmio(mmio_base, mmio_len, &g_native_boot_net) == 0u ||
      er_native_eth_init(&g_native_boot_eth, &g_native_boot_net, peer_mac) == 0u ||
      erwire_set_native_eth_sink(&g_native_boot_eth) == 0u) {
    return 0;
  }

  er_native_boot_set_eth_sink_state(out_state);
  return 1;
}

UINT8 er_native_boot_configure_pci_erwire_eth_sink(ErNativeBootState* out_state) {
  er_native_boot_clear_state(out_state);
  er_native_boot_clear_eth_sink();

  if (er_virtio_net_init_first_pci(&g_native_boot_net) == 0u ||
      er_native_eth_init(&g_native_boot_eth, &g_native_boot_net, g_qemu_microvm_peer_mac) == 0u ||
      erwire_set_native_eth_sink(&g_native_boot_eth) == 0u) {
    return 0;
  }

  er_native_boot_set_eth_sink_state(out_state);
  return 1;
}

UINT8 er_native_boot_configure_qemu_microvm_erwire_eth_sink(ErNativeBootState* out_state) {
  static const UINT64 bases[ER_NATIVE_BOOT_QEMU_MICROVM_CANDIDATES] = {
    ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_BASE,
    ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_ALT_BASE
  };
  UINT32 i;

  for (i = 0u; i < ER_NATIVE_BOOT_QEMU_MICROVM_CANDIDATES; ++i) {
    if (er_native_boot_configure_erwire_eth_sink(bases[i],
                                                ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_LEN,
                                                g_qemu_microvm_peer_mac,
                                                out_state) != 0u) {
      return 1;
    }
  }
  return 0;
}

static UINT8 er_native_boot_hash_ingress_packet(const ErCryptoProvider* crypto,
                                                const ErwirePacketHeader* header,
                                                const UINT8* payload,
                                                UINT32 payload_len,
                                                ErHash* out_hash) {
  ErByteSpan spans[2];

  if (crypto == 0 || header == 0 || out_hash == 0 ||
      (payload_len > 0u && payload == 0)) {
    return 0;
  }
  spans[0].bytes = (const UINT8*)header;
  spans[0].len = (UINTN)sizeof(*header);
  spans[1].bytes = payload;
  spans[1].len = (UINTN)payload_len;
  return er_crypto_hash(crypto,
                        g_native_relay_ingress_domain,
                        (UINTN)(sizeof(g_native_relay_ingress_domain) - 1u),
                        spans, 2u, out_hash);
}

UINT8 er_native_boot_poll_relay_ingress(const ErNativeBootState* state,
                                        const ErCryptoProvider* crypto,
                                        ErNativeRelayIngress* out_ingress) {
  ErNativeEthStats before;
  ErNativeEthStats after;
  UINT8 payload[ERWIRE_MAX_PAYLOAD];
  UINT32 payload_len = 0u;

  if (out_ingress == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_ingress, (UINTN)sizeof(*out_ingress));
  if (state == 0 || state->initialized == 0u || state->erwire_sink_ready == 0u ||
      state->eth == 0 || crypto == 0) {
    return 0;
  }

  before = er_native_eth_stats(state->eth);
  if (erwire_poll_native_eth(&out_ingress->header, payload,
                             (UINT32)sizeof(payload), &payload_len) == 0u) {
    after = er_native_eth_stats(state->eth);
    if (after.rx_frames_accepted != before.rx_frames_accepted) {
      out_ingress->status = ER_NATIVE_RELAY_INGRESS_MALFORMED;
    }
    return 1;
  }

  out_ingress->payload_len = payload_len;
  if (payload_len > 0u) {
    er_mem_copy(out_ingress->payload, payload, (UINTN)payload_len);
  }
  if (er_native_boot_hash_ingress_packet(crypto, &out_ingress->header,
                                         payload, payload_len,
                                         &out_ingress->packet_hash) == 0u ||
      er_hw_relay_prepare_native_eth_endpoint(state->eth->peer_mac,
                                              g_native_relay_ingress_label,
                                              (UINTN)(sizeof(g_native_relay_ingress_label) - 1u),
                                              &out_ingress->ingress) == 0u) {
    return 0;
  }
  out_ingress->status = ER_NATIVE_RELAY_INGRESS_ACCEPTED;
  return 1;
}

static UINT8 er_native_boot_relay_packet_matches_route(const ErRelayPacketHeader* packet,
                                                       const ErAdmittedRoute* route) {
  if (packet == 0 || route == 0 ||
      packet->abi_version != ER_RELAY_PACKET_ABI_VERSION ||
      packet->packet_kind != ER_RELAY_PACKET_KIND_BYTES ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      packet->sequence == 0u ||
      er_node_id_equal(&packet->source_node_id,
                                &route->source_node_id) == 0u ||
      er_node_id_equal(&packet->target_node_id,
                                &route->target_node_id) == 0u ||
      er_hash_equal(&packet->admission_id,
                                &route->admission_hash) == 0u ||
      er_hash_equal(&packet->route_hash,
                                &route->target_route_commitment) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_native_boot_route_is_render_capability(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_CAPABILITY &&
                 route->department == ER_DEPARTMENT_CAPABILITY &&
                 route->work_type == ER_WORK_TYPE_CAPABILITY_INVOKE);
}

static UINT8 er_native_boot_route_is_storage_object(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_STORAGE &&
                 route->department == ER_DEPARTMENT_STORAGE &&
                 route->work_type == ER_WORK_TYPE_OBJECT_RETRIEVE);
}

static UINT8 er_native_boot_object_packet_header_valid(const ErVfsObjectPacket* packet) {
  return (UINT8)(packet != 0 &&
                 packet->header.abi_version == ER_VFS_ABI_VERSION &&
                 packet->header.packet_count != 0u &&
                 packet->header.packet_index < packet->header.packet_count &&
                 packet->header.object_len != 0u &&
                 packet->header.bytes_len != 0u &&
                 packet->header.bytes_len <= ER_VFS_OBJECT_PACKET_BYTES &&
                 er_hash_nonzero(&packet->header.object_id) != 0u &&
                 er_hash_nonzero(&packet->header.payload_hash) != 0u &&
                 er_hash_nonzero(&packet->header.packet_id) != 0u);
}

static UINT8 er_native_boot_decode_storage_object_intent(const UINT8* payload,
                                                         UINT32 payload_len,
                                                         ErNativeEndpointIntent* out_intent) {
  UINT32 bytes_len;

  if (payload == 0 || out_intent == 0 ||
      payload_len < (UINT32)sizeof(out_intent->object_packet.header) ||
      payload_len > (UINT32)sizeof(out_intent->object_packet.header) +
                    ER_VFS_OBJECT_PACKET_BYTES) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_UNSUPPORTED;
    return 1u;
  }
  bytes_len = payload_len - (UINT32)sizeof(out_intent->object_packet.header);
  er_mem_copy((UINT8*)&out_intent->object_packet.header, payload,
              (UINTN)sizeof(out_intent->object_packet.header));
  if (bytes_len > 0u) {
    er_mem_copy(out_intent->object_packet.bytes,
                payload + (UINT32)sizeof(out_intent->object_packet.header),
                (UINTN)bytes_len);
  }
  if (er_native_boot_object_packet_header_valid(&out_intent->object_packet) == 0u ||
      out_intent->object_packet.header.bytes_len != bytes_len ||
      er_hash_equal(&out_intent->packet.payload_hash,
                    &out_intent->object_packet.header.packet_id) == 0u) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_MALFORMED;
    return 1u;
  }
  out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_STORAGE_OBJECT_PACKET;
  return 1u;
}

UINT8 er_native_boot_decode_endpoint_intent(const ErNativeRelayIngress* ingress,
                                            const ErAdmittedRoute* route,
                                            ErNativeEndpointIntent* out_intent) {
  const UINT8* payload = 0;
  UINT32 payload_len = 0u;

  if (out_intent == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_intent, (UINTN)sizeof(*out_intent));
  if (ingress == 0 || route == 0) {
    return 0;
  }
  if (ingress->status == ER_NATIVE_RELAY_INGRESS_NONE) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_NONE;
    return 1;
  }
  if (ingress->status != ER_NATIVE_RELAY_INGRESS_ACCEPTED ||
      ingress->payload_len == 0u ||
      er_relay_packet_decode_header(ingress->payload, ingress->payload_len,
                                    &out_intent->packet) == 0u ||
      er_relay_packet_payload(ingress->payload, ingress->payload_len,
                              &payload, &payload_len) == 0u ||
      er_native_boot_relay_packet_matches_route(&out_intent->packet,
                                                route) == 0u) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_MALFORMED;
    return 1;
  }
  if (er_native_boot_route_is_storage_object(route) != 0u) {
    return er_native_boot_decode_storage_object_intent(payload, payload_len,
                                                       out_intent);
  }
  if (er_native_boot_route_is_render_capability(route) == 0u ||
      payload_len < (UINT32)sizeof(out_intent->capability)) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_UNSUPPORTED;
    return 1;
  }
  er_mem_copy((UINT8*)&out_intent->capability, payload,
              (UINTN)sizeof(out_intent->capability));
  out_intent->scene_payload_len =
      payload_len - (UINT32)sizeof(out_intent->capability);
  if (out_intent->scene_payload_len > 0u) {
    er_mem_copy(out_intent->scene_payload,
                payload + (UINT32)sizeof(out_intent->capability),
                (UINTN)out_intent->scene_payload_len);
  }
  if (er_work_capability_envelope_header_valid(&out_intent->capability) == 0u ||
      out_intent->capability.content_type != ER_CAPABILITY_CONTENT_RENDER ||
      out_intent->capability.risk_flags != ER_CAPABILITY_RISK_NONE ||
      out_intent->capability.payload_len != out_intent->scene_payload_len ||
      out_intent->capability.sequence != out_intent->packet.sequence ||
      er_node_id_equal(&out_intent->capability.source_node_id,
                                &route->source_node_id) == 0u ||
      er_node_id_equal(&out_intent->capability.target_node_id,
                                &route->target_node_id) == 0u) {
    out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_MALFORMED;
    return 1;
  }
  out_intent->kind = ER_NATIVE_ENDPOINT_INTENT_RENDER_CAPABILITY;
  return 1;
}

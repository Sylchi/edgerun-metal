#include "er_native_boot.h"
#include "er_mem.h"

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

UINT8 er_native_boot_configure_erwire_eth_sink(UINT64 mmio_base, UINT64 mmio_len,
                                               const UINT8* peer_mac,
                                               ErNativeBootState* out_state) {
  er_native_boot_clear_state(out_state);
  erwire_clear_native_eth_sink();
  er_mem_zero((UINT8*)&g_native_boot_net, (UINTN)sizeof(g_native_boot_net));
  er_mem_zero((UINT8*)&g_native_boot_eth, (UINTN)sizeof(g_native_boot_eth));

  if (peer_mac == 0 ||
      er_virtio_net_init_mmio(mmio_base, mmio_len, &g_native_boot_net) == 0u ||
      er_native_eth_init(&g_native_boot_eth, &g_native_boot_net, peer_mac) == 0u ||
      erwire_set_native_eth_sink(&g_native_boot_eth) == 0u) {
    return 0;
  }

  if (out_state != 0) {
    out_state->initialized = 1u;
    out_state->erwire_sink_ready = 1u;
    out_state->net = &g_native_boot_net;
    out_state->eth = &g_native_boot_eth;
  }
  return 1;
}

UINT8 er_native_boot_configure_pci_erwire_eth_sink(ErNativeBootState* out_state) {
  er_native_boot_clear_state(out_state);
  erwire_clear_native_eth_sink();
  er_mem_zero((UINT8*)&g_native_boot_net, (UINTN)sizeof(g_native_boot_net));
  er_mem_zero((UINT8*)&g_native_boot_eth, (UINTN)sizeof(g_native_boot_eth));

  if (er_virtio_net_init_first_pci(&g_native_boot_net) == 0u ||
      er_native_eth_init(&g_native_boot_eth, &g_native_boot_net, g_qemu_microvm_peer_mac) == 0u ||
      erwire_set_native_eth_sink(&g_native_boot_eth) == 0u) {
    return 0;
  }

  if (out_state != 0) {
    out_state->initialized = 1u;
    out_state->erwire_sink_ready = 1u;
    out_state->net = &g_native_boot_net;
    out_state->eth = &g_native_boot_eth;
  }
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
                                        const ErRelayVirtioRoutes* routes,
                                        const ErCryptoProvider* crypto,
                                        ErNativeRelayIngress* out_ingress) {
  ErNativeEthStats before;
  ErNativeEthStats after;
  ErChannelEndpoint ingress;
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
  if (er_native_boot_hash_ingress_packet(crypto, &out_ingress->header,
                                         payload, payload_len,
                                         &out_ingress->packet_hash) == 0u ||
      er_hw_relay_prepare_native_eth_endpoint(state->eth->peer_mac,
                                              g_native_relay_ingress_label,
                                              (UINTN)(sizeof(g_native_relay_ingress_label) - 1u),
                                              &ingress) == 0u) {
    return 0;
  }

  if (er_relay_route_erwire_to_virtio(&ingress, out_ingress->header.Kind,
                                      payload, payload_len, routes,
                                      &out_ingress->intent) == 0u) {
    out_ingress->status = ER_NATIVE_RELAY_INGRESS_UNROUTED;
    return 1;
  }
  out_ingress->intent.sequence = out_ingress->header.Seq;
  out_ingress->intent.packet_hash = out_ingress->packet_hash;
  out_ingress->status = ER_NATIVE_RELAY_INGRESS_ROUTED;
  return 1;
}

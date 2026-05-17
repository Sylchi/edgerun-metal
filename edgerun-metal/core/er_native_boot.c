#include "er_native_boot.h"
#include "er_mem.h"
#include "erwire.h"

enum {
  ER_NATIVE_BOOT_QEMU_MICROVM_CANDIDATES = 2u,
  ER_NATIVE_BOOT_MAC0 = 0x02u,
  ER_NATIVE_BOOT_MAC1 = 0x21u,
  ER_NATIVE_BOOT_MAC2 = 0x22u,
  ER_NATIVE_BOOT_MAC3 = 0x23u,
  ER_NATIVE_BOOT_MAC4 = 0x24u,
  ER_NATIVE_BOOT_MAC5 = 0x25u
};

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

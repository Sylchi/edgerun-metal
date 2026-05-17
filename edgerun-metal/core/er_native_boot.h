#ifndef ER_NATIVE_BOOT_H
#define ER_NATIVE_BOOT_H

/*
 * Purpose: wire boot-time native transports without depending on EFI network services.
 * Intention: keep emulator-specific probe policy small and testable while drivers stay generic.
 */

#include "er_types.h"
#include "er_virtio_net.h"
#include "er_native_eth.h"

#define ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_BASE 0xfeb02e00ull
#define ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_ALT_BASE 0xfeb02c00ull
#define ER_NATIVE_BOOT_QEMU_MICROVM_VIRTIO_MMIO_LEN 0x200ull

typedef struct {
  UINT8 initialized;
  UINT8 erwire_sink_ready;
  ErVirtioNet* net;
  ErNativeEth* eth;
} ErNativeBootState;

UINT8 er_native_boot_configure_erwire_eth_sink(UINT64 mmio_base, UINT64 mmio_len,
                                               const UINT8* peer_mac,
                                               ErNativeBootState* out_state);
UINT8 er_native_boot_configure_qemu_microvm_erwire_eth_sink(ErNativeBootState* out_state);

#endif

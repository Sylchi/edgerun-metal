#include "er_relay_dispatch.h"
#include "er_hw_relay.h"
#include "er_mem.h"
#include "er_virtio.h"

/*
 * Purpose: turn routed relay intents into deterministic endpoint dispatch records.
 * Intention: prove dispatch boundaries before VirtIO block/GPU adapters grow queues.
 */

enum {
  ER_RELAY_DISPATCH_VIRTIO_DEVICE_TYPE_OFFSET = 0u,
  ER_RELAY_DISPATCH_VIRTIO_QUEUE_OFFSET = 4u,
  ER_RELAY_DISPATCH_U16_HIGH_SHIFT = 8u,
  ER_RELAY_DISPATCH_U32_BYTE2_SHIFT = 16u,
  ER_RELAY_DISPATCH_U32_BYTE3_SHIFT = 24u
};

static UINT16 er_relay_dispatch_get_u16(const UINT8* src) {
  return (UINT16)((UINT16)src[0] |
                  (UINT16)((UINT16)src[1] << ER_RELAY_DISPATCH_U16_HIGH_SHIFT));
}

static UINT32 er_relay_dispatch_get_u32(const UINT8* src) {
  return (UINT32)((UINT32)src[0] |
                  ((UINT32)src[1] << ER_RELAY_DISPATCH_U16_HIGH_SHIFT) |
                  ((UINT32)src[2] << ER_RELAY_DISPATCH_U32_BYTE2_SHIFT) |
                  ((UINT32)src[3] << ER_RELAY_DISPATCH_U32_BYTE3_SHIFT));
}

static ErRelayDispatchStatus er_relay_dispatch_status_for_virtio(UINT32 device_type) {
  switch (device_type) {
    case ER_VIRTIO_DEVICE_TYPE_BLK:
      return ER_RELAY_DISPATCH_STORAGE_CAPTURE;
    case ER_VIRTIO_DEVICE_TYPE_GPU:
      return ER_RELAY_DISPATCH_RENDER_CAPTURE;
    default:
      return ER_RELAY_DISPATCH_UNSUPPORTED_ENDPOINT;
  }
}

UINT8 er_relay_dispatch_intent(const ErRelayForwardIntent* intent,
                               const UINT8* packet, UINTN packet_len,
                               ErRelayDispatchRecord* out_record) {
  if (out_record == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_record, (UINTN)sizeof(*out_record));
  if (intent == 0 || intent->abi_version != ER_WORK_ABI_VERSION ||
      (packet_len > 0u && packet == 0)) {
    return 0;
  }

  out_record->packet_len = packet_len;
  out_record->sequence = intent->sequence;
  out_record->packet_hash = intent->packet_hash;

  if (intent->to.kind != ER_CHANNEL_KIND_DEVICE_RING) {
    out_record->status = ER_RELAY_DISPATCH_UNSUPPORTED_ENDPOINT;
    return 1;
  }
  if (er_hw_relay_endpoint_is_virtio(&intent->to) == 0u) {
    out_record->status = ER_RELAY_DISPATCH_MALFORMED_ENDPOINT;
    return 1;
  }

  out_record->virtio_device_type =
      er_relay_dispatch_get_u32(intent->to.address + ER_RELAY_DISPATCH_VIRTIO_DEVICE_TYPE_OFFSET);
  out_record->virtio_queue =
      er_relay_dispatch_get_u16(intent->to.address + ER_RELAY_DISPATCH_VIRTIO_QUEUE_OFFSET);
  out_record->status = er_relay_dispatch_status_for_virtio(out_record->virtio_device_type);
  return 1;
}

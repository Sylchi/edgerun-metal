#include "er_hw_relay.h"
#include "er_mem.h"
#include "er_netlog.h"
#include "er_virtio.h"
#include "erwire.h"

/*
 * Purpose: bind erwire relay traffic to firmware, Ethernet, and VirtIO endpoints.
 * Intention: packet forwarding is concrete hardware movement, not policy or app execution.
 */

static const char g_default_udp_label[] = "uefi-udp4";
static const char g_default_storage_label[] = "virtio-blk";
static const char g_default_display_label[] = "virtio-gpu";
#define ER_HW_RELAY_UDP_WAIT_POLLS 100000u

enum {
  ER_HW_RELAY_ADDR_IPV4_A_INDEX = 0u,
  ER_HW_RELAY_ADDR_IPV4_B_INDEX = 1u,
  ER_HW_RELAY_ADDR_IPV4_C_INDEX = 2u,
  ER_HW_RELAY_ADDR_IPV4_D_INDEX = 3u,
  ER_HW_RELAY_ADDR_PORT_HIGH_INDEX = 4u,
  ER_HW_RELAY_ADDR_PORT_LOW_INDEX = 5u,
  ER_HW_RELAY_PORT_HIGH_SHIFT = 8u,
  ER_HW_RELAY_PORT_BYTE_MASK = 0xffu,
  ER_HW_RELAY_DEFAULT_IP_A = 10u,
  ER_HW_RELAY_DEFAULT_IP_B = 42u,
  ER_HW_RELAY_DEFAULT_IP_C = 0u,
  ER_HW_RELAY_DEFAULT_IP_D = 1u,
  ER_HW_RELAY_VIRTIO_DEVICE_TYPE_OFFSET = 0u,
  ER_HW_RELAY_VIRTIO_QUEUE_OFFSET = 4u,
  ER_HW_RELAY_VIRTIO_TRANSPORT_KIND_OFFSET = 6u,
  ER_HW_RELAY_VIRTIO_RESERVED_OFFSET = 7u,
  ER_HW_RELAY_U16_HIGH_SHIFT = 8u,
  ER_HW_RELAY_U32_BYTE2_SHIFT = 16u,
  ER_HW_RELAY_U32_BYTE3_SHIFT = 24u,
  ER_HW_RELAY_U8_MASK = 0xffu,
  ER_HW_RELAY_VIRTIO_QUEUE_DEFAULT = 0u,
  ER_HW_RELAY_CAPABILITY_CONTENT_TYPE_OFFSET = 6u,
  ER_HW_RELAY_CAPABILITY_HEADER_MIN = 8u,
  ER_HW_RELAY_WORK_DEPARTMENT_OFFSET = 4u,
  ER_HW_RELAY_WORK_HEADER_MIN = 6u
};

static UINT8 er_hw_relay_bytes_equal(const UINT8* a, const UINT8* b, UINTN len) {
  UINTN i;

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

static void er_hw_relay_put_u16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & ER_HW_RELAY_U8_MASK);
  dst[1] = (UINT8)((value >> ER_HW_RELAY_U16_HIGH_SHIFT) & ER_HW_RELAY_U8_MASK);
}

static void er_hw_relay_put_u32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)(value & ER_HW_RELAY_U8_MASK);
  dst[1] = (UINT8)((value >> ER_HW_RELAY_U16_HIGH_SHIFT) & ER_HW_RELAY_U8_MASK);
  dst[2] = (UINT8)((value >> ER_HW_RELAY_U32_BYTE2_SHIFT) & ER_HW_RELAY_U8_MASK);
  dst[3] = (UINT8)((value >> ER_HW_RELAY_U32_BYTE3_SHIFT) & ER_HW_RELAY_U8_MASK);
}

static UINT16 er_hw_relay_get_u16(const UINT8* src) {
  return (UINT16)((UINT16)src[0] |
                  (UINT16)((UINT16)src[1] << ER_HW_RELAY_U16_HIGH_SHIFT));
}

static UINT8 er_hw_relay_kind_targets_storage(UINT16 erwire_kind) {
  switch (erwire_kind) {
    case ERWIRE_KIND_BLOB_CHUNK:
    case ERWIRE_KIND_VFS_OBJECT_PACKET:
    case ERWIRE_KIND_VFS_OBJECT_LABEL_REF:
    case ERWIRE_KIND_VFS_OBJECT_TRANSFORM:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_hw_relay_capability_targets_display(const UINT8* payload,
                                                    UINT32 payload_len) {
  UINT16 content_type;

  if (payload == 0 || payload_len < ER_HW_RELAY_CAPABILITY_HEADER_MIN) {
    return 0u;
  }
  content_type = er_hw_relay_get_u16(payload + ER_HW_RELAY_CAPABILITY_CONTENT_TYPE_OFFSET);
  switch (content_type) {
    case ER_CAPABILITY_CONTENT_VIDEO:
    case ER_CAPABILITY_CONTENT_RENDER:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_hw_relay_capability_targets_storage(const UINT8* payload,
                                                    UINT32 payload_len) {
  UINT16 content_type;

  if (payload == 0 || payload_len < ER_HW_RELAY_CAPABILITY_HEADER_MIN) {
    return 0u;
  }
  content_type = er_hw_relay_get_u16(payload + ER_HW_RELAY_CAPABILITY_CONTENT_TYPE_OFFSET);
  return (UINT8)(content_type == ER_CAPABILITY_CONTENT_OBJECT);
}

static UINT8 er_hw_relay_work_targets_storage(const UINT8* payload,
                                              UINT32 payload_len) {
  UINT16 department;

  if (payload == 0 || payload_len < ER_HW_RELAY_WORK_HEADER_MIN) {
    return 0u;
  }
  department = er_hw_relay_get_u16(payload + ER_HW_RELAY_WORK_DEPARTMENT_OFFSET);
  return (UINT8)(department == ER_DEPARTMENT_STORAGE ||
                 department == ER_DEPARTMENT_RETRIEVAL);
}

static UINT8 er_hw_relay_choose_virtio_target(UINT16 erwire_kind,
                                              const UINT8* payload,
                                              UINT32 payload_len,
                                              const ErHwRelayVirtioRoutes* routes,
                                              ErChannelEndpoint* out_endpoint) {
  if (routes == 0 || out_endpoint == 0) {
    return 0;
  }
  if (er_hw_relay_kind_targets_storage(erwire_kind) != 0u ||
      (erwire_kind == ERWIRE_KIND_CAPABILITY_ENVELOPE &&
       er_hw_relay_capability_targets_storage(payload, payload_len) != 0u) ||
      (erwire_kind == ERWIRE_KIND_WORK_REQUEST &&
       er_hw_relay_work_targets_storage(payload, payload_len) != 0u)) {
    if (routes->storage_ready == 0u ||
        er_hw_relay_endpoint_is_virtio(&routes->storage) == 0u) {
      return 0;
    }
    *out_endpoint = routes->storage;
    return 1;
  }
  if (erwire_kind == ERWIRE_KIND_CAPABILITY_ENVELOPE &&
      er_hw_relay_capability_targets_display(payload, payload_len) != 0u) {
    if (routes->display_ready == 0u ||
        er_hw_relay_endpoint_is_virtio(&routes->display) == 0u) {
      return 0;
    }
    *out_endpoint = routes->display;
    return 1;
  }
  return 0;
}

UINT8 er_hw_relay_prepare_firmware_udp_endpoint(UINT8 a, UINT8 b, UINT8 c, UINT8 d, UINT16 port,
                                                const char* label, UINTN label_len,
                                                ErChannelEndpoint* out_endpoint) {
  if (out_endpoint == 0 || label == 0 || label_len == 0u || label_len > ER_CHANNEL_LABEL_MAX) {
    return 0;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_FIRMWARE_UDP;
  out_endpoint->address_len = ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN;
  out_endpoint->label_len = (UINT16)label_len;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_A_INDEX] = a;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_B_INDEX] = b;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_C_INDEX] = c;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_D_INDEX] = d;
  out_endpoint->address[ER_HW_RELAY_ADDR_PORT_HIGH_INDEX] =
    (UINT8)((port >> ER_HW_RELAY_PORT_HIGH_SHIFT) & ER_HW_RELAY_PORT_BYTE_MASK);
  out_endpoint->address[ER_HW_RELAY_ADDR_PORT_LOW_INDEX] = (UINT8)(port & ER_HW_RELAY_PORT_BYTE_MASK);
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1;
}

UINT8 er_hw_relay_default_firmware_udp_endpoint(ErChannelEndpoint* out_endpoint) {
  return er_hw_relay_prepare_firmware_udp_endpoint(ER_HW_RELAY_DEFAULT_IP_A, ER_HW_RELAY_DEFAULT_IP_B,
                                                  ER_HW_RELAY_DEFAULT_IP_C, ER_HW_RELAY_DEFAULT_IP_D,
                                                  ER_HW_RELAY_FIRMWARE_UDP_PORT,
                                                  g_default_udp_label,
                                                  (UINTN)(sizeof(g_default_udp_label) - 1u),
                                                  out_endpoint);
}

UINT8 er_hw_relay_endpoint_is_firmware_udp(const ErChannelEndpoint* endpoint) {
  if (endpoint == 0 || endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind != ER_CHANNEL_KIND_FIRMWARE_UDP ||
      endpoint->address_len != ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN) {
    return 0;
  }
  return 1;
}

UINT8 er_hw_relay_forward_to_firmware_udp(const ErRelayForwardIntent* intent, const UINT8* packet, UINTN packet_len) {
  if (intent == 0 || packet == 0 || packet_len == 0u) {
    return 0;
  }
  if (intent->abi_version != ER_WORK_ABI_VERSION ||
      er_hw_relay_endpoint_is_firmware_udp(&intent->to) == 0u) {
    return 0;
  }
  if (er_netlog_ready() == 0u) {
    return 0;
  }
  er_netlog_flush_text();
  return er_netlog_write_bytes_wait(packet, packet_len, ER_HW_RELAY_UDP_WAIT_POLLS);
}

UINT8 er_hw_relay_prepare_native_eth_endpoint(const UINT8* mac,
                                              const char* label, UINTN label_len,
                                              ErChannelEndpoint* out_endpoint) {
  if (mac == 0 || out_endpoint == 0 || label == 0 ||
      label_len == 0u || label_len > ER_CHANNEL_LABEL_MAX) {
    return 0;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_DEVICE_RING;
  out_endpoint->address_len = ER_HW_RELAY_NATIVE_ETH_ADDR_LEN;
  out_endpoint->label_len = (UINT16)label_len;
  er_mem_copy(out_endpoint->address, mac, ER_HW_RELAY_NATIVE_ETH_ADDR_LEN);
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1;
}

UINT8 er_hw_relay_endpoint_is_native_eth(const ErChannelEndpoint* endpoint) {
  if (endpoint == 0 || endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind != ER_CHANNEL_KIND_DEVICE_RING ||
      endpoint->address_len != ER_HW_RELAY_NATIVE_ETH_ADDR_LEN) {
    return 0;
  }
  return 1;
}

UINT8 er_hw_relay_forward_to_native_eth(ErNativeEth* native_eth,
                                        const ErRelayForwardIntent* intent,
                                        const UINT8* packet, UINTN packet_len) {
  if (native_eth == 0 || intent == 0 || packet == 0 || packet_len == 0u ||
      packet_len > ER_NET_ETH_PAYLOAD_MAX) {
    return 0;
  }
  if (intent->abi_version != ER_WORK_ABI_VERSION ||
      er_hw_relay_endpoint_is_native_eth(&intent->to) == 0u ||
      er_hw_relay_bytes_equal(native_eth->peer_mac, intent->to.address,
                              ER_HW_RELAY_NATIVE_ETH_ADDR_LEN) == 0u) {
    return 0;
  }
  return er_native_eth_send(native_eth, packet, (UINT32)packet_len);
}

UINT8 er_hw_relay_prepare_virtio_endpoint(UINT32 device_type, UINT16 queue,
                                          const char* label, UINTN label_len,
                                          ErChannelEndpoint* out_endpoint) {
  if (out_endpoint == 0 || label == 0 || label_len == 0u ||
      label_len > ER_CHANNEL_LABEL_MAX || device_type == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_DEVICE_RING;
  out_endpoint->address_len = ER_HW_RELAY_VIRTIO_ADDR_LEN;
  out_endpoint->label_len = (UINT16)label_len;
  er_hw_relay_put_u32(out_endpoint->address + ER_HW_RELAY_VIRTIO_DEVICE_TYPE_OFFSET,
                      device_type);
  er_hw_relay_put_u16(out_endpoint->address + ER_HW_RELAY_VIRTIO_QUEUE_OFFSET,
                      queue);
  out_endpoint->address[ER_HW_RELAY_VIRTIO_TRANSPORT_KIND_OFFSET] =
      ER_VIRTIO_TRANSPORT_KIND_NONE;
  out_endpoint->address[ER_HW_RELAY_VIRTIO_RESERVED_OFFSET] = 0u;
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1;
}

UINT8 er_hw_relay_endpoint_is_virtio(const ErChannelEndpoint* endpoint) {
  if (endpoint == 0 || endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind != ER_CHANNEL_KIND_DEVICE_RING ||
      endpoint->address_len != ER_HW_RELAY_VIRTIO_ADDR_LEN ||
      endpoint->address[ER_HW_RELAY_VIRTIO_RESERVED_OFFSET] != 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_hw_relay_prepare_default_virtio_routes(ErHwRelayVirtioRoutes* out_routes) {
  if (out_routes == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_routes, (UINTN)sizeof(*out_routes));
  if (er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_BLK,
                                          ER_HW_RELAY_VIRTIO_QUEUE_DEFAULT,
                                          g_default_storage_label,
                                          (UINTN)(sizeof(g_default_storage_label) - 1u),
                                          &out_routes->storage) == 0u ||
      er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_GPU,
                                          ER_HW_RELAY_VIRTIO_QUEUE_DEFAULT,
                                          g_default_display_label,
                                          (UINTN)(sizeof(g_default_display_label) - 1u),
                                          &out_routes->display) == 0u) {
    er_mem_zero((UINT8*)out_routes, (UINTN)sizeof(*out_routes));
    return 0;
  }
  out_routes->storage_ready = 1u;
  out_routes->display_ready = 1u;
  return 1;
}

UINT8 er_hw_relay_route_erwire_to_virtio(const ErChannelEndpoint* ingress,
                                         UINT16 erwire_kind,
                                         const UINT8* payload, UINT32 payload_len,
                                         const ErHwRelayVirtioRoutes* routes,
                                         ErRelayForwardIntent* out_intent) {
  ErChannelEndpoint target;

  if (ingress == 0 || out_intent == 0 ||
      (payload_len > 0u && payload == 0) ||
      er_hw_relay_choose_virtio_target(erwire_kind, payload, payload_len,
                                       routes, &target) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_intent, (UINTN)sizeof(*out_intent));
  out_intent->abi_version = ER_WORK_ABI_VERSION;
  out_intent->from = *ingress;
  out_intent->to = target;
  return 1;
}

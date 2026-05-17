#include "er_relay_router.h"
#include "er_mem.h"
#include "er_virtio.h"
#include "erwire.h"

/*
 * Purpose: map parsed erwire packet classes onto concrete relay endpoints.
 * Intention: keep native Ethernet as ingress and VirtIO devices as explicit route targets.
 */

static const char g_default_storage_label[] = "virtio-blk";
static const char g_default_display_label[] = "virtio-gpu";

enum {
  ER_RELAY_ROUTER_U16_HIGH_SHIFT = 8u,
  ER_RELAY_ROUTER_CAPABILITY_CONTENT_TYPE_OFFSET = 6u,
  ER_RELAY_ROUTER_CAPABILITY_HEADER_MIN = 8u,
  ER_RELAY_ROUTER_WORK_DEPARTMENT_OFFSET = 4u,
  ER_RELAY_ROUTER_WORK_HEADER_MIN = 6u,
  ER_RELAY_ROUTER_VIRTIO_QUEUE_DEFAULT = 0u
};

static UINT16 er_relay_router_get_u16(const UINT8* src) {
  return (UINT16)((UINT16)src[0] |
                  (UINT16)((UINT16)src[1] << ER_RELAY_ROUTER_U16_HIGH_SHIFT));
}

static UINT8 er_relay_router_kind_targets_storage(UINT16 erwire_kind) {
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

static UINT8 er_relay_router_capability_targets_display(const UINT8* payload,
                                                        UINT32 payload_len) {
  UINT16 content_type;

  if (payload == 0 || payload_len < ER_RELAY_ROUTER_CAPABILITY_HEADER_MIN) {
    return 0u;
  }
  content_type = er_relay_router_get_u16(payload + ER_RELAY_ROUTER_CAPABILITY_CONTENT_TYPE_OFFSET);
  switch (content_type) {
    case ER_CAPABILITY_CONTENT_VIDEO:
    case ER_CAPABILITY_CONTENT_RENDER:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_relay_router_capability_targets_storage(const UINT8* payload,
                                                        UINT32 payload_len) {
  UINT16 content_type;

  if (payload == 0 || payload_len < ER_RELAY_ROUTER_CAPABILITY_HEADER_MIN) {
    return 0u;
  }
  content_type = er_relay_router_get_u16(payload + ER_RELAY_ROUTER_CAPABILITY_CONTENT_TYPE_OFFSET);
  return (UINT8)(content_type == ER_CAPABILITY_CONTENT_OBJECT);
}

static UINT8 er_relay_router_work_targets_storage(const UINT8* payload,
                                                  UINT32 payload_len) {
  UINT16 department;

  if (payload == 0 || payload_len < ER_RELAY_ROUTER_WORK_HEADER_MIN) {
    return 0u;
  }
  department = er_relay_router_get_u16(payload + ER_RELAY_ROUTER_WORK_DEPARTMENT_OFFSET);
  return (UINT8)(department == ER_DEPARTMENT_STORAGE ||
                 department == ER_DEPARTMENT_RETRIEVAL);
}

static UINT8 er_relay_router_choose_virtio_target(UINT16 erwire_kind,
                                                  const UINT8* payload,
                                                  UINT32 payload_len,
                                                  const ErRelayVirtioRoutes* routes,
                                                  ErChannelEndpoint* out_endpoint) {
  if (routes == 0 || out_endpoint == 0) {
    return 0;
  }
  if (er_relay_router_kind_targets_storage(erwire_kind) != 0u ||
      (erwire_kind == ERWIRE_KIND_CAPABILITY_ENVELOPE &&
       er_relay_router_capability_targets_storage(payload, payload_len) != 0u) ||
      (erwire_kind == ERWIRE_KIND_WORK_REQUEST &&
       er_relay_router_work_targets_storage(payload, payload_len) != 0u)) {
    if (routes->storage_ready == 0u ||
        er_hw_relay_endpoint_is_virtio(&routes->storage) == 0u) {
      return 0;
    }
    *out_endpoint = routes->storage;
    return 1;
  }
  if (erwire_kind == ERWIRE_KIND_CAPABILITY_ENVELOPE &&
      er_relay_router_capability_targets_display(payload, payload_len) != 0u) {
    if (routes->display_ready == 0u ||
        er_hw_relay_endpoint_is_virtio(&routes->display) == 0u) {
      return 0;
    }
    *out_endpoint = routes->display;
    return 1;
  }
  return 0;
}

UINT8 er_relay_prepare_default_virtio_routes(ErRelayVirtioRoutes* out_routes) {
  if (out_routes == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_routes, (UINTN)sizeof(*out_routes));
  if (er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_BLK,
                                          ER_RELAY_ROUTER_VIRTIO_QUEUE_DEFAULT,
                                          g_default_storage_label,
                                          (UINTN)(sizeof(g_default_storage_label) - 1u),
                                          &out_routes->storage) == 0u ||
      er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_GPU,
                                          ER_RELAY_ROUTER_VIRTIO_QUEUE_DEFAULT,
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

UINT8 er_relay_route_erwire_to_virtio(const ErChannelEndpoint* ingress,
                                      UINT16 erwire_kind,
                                      const UINT8* payload, UINT32 payload_len,
                                      const ErRelayVirtioRoutes* routes,
                                      ErRelayForwardIntent* out_intent) {
  ErChannelEndpoint target;

  if (ingress == 0 || out_intent == 0 ||
      (payload_len > 0u && payload == 0) ||
      er_relay_router_choose_virtio_target(erwire_kind, payload, payload_len,
                                           routes, &target) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_intent, (UINTN)sizeof(*out_intent));
  out_intent->abi_version = ER_WORK_ABI_VERSION;
  out_intent->from = *ingress;
  out_intent->to = target;
  return 1;
}

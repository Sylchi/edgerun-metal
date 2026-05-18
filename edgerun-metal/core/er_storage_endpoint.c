#include "er_storage_endpoint.h"
#include "er_mem.h"

/*
 * Purpose: implement storage endpoint capture over admitted object packets.
 * Intention: prove endpoint-side object validation before adding block-device durability.
 */

static const UINT8 g_storage_capture_domain[] = "edgerun:c:v1:storage:endpoint-capture";

enum {
  ER_STORAGE_CAPTURE_SPAN_COUNT = 4u,
  ER_STORAGE_CAPTURE_ROUTE_SPAN = 0u,
  ER_STORAGE_CAPTURE_OBJECT_SPAN = 1u,
  ER_STORAGE_CAPTURE_PACKET_SPAN = 2u,
  ER_STORAGE_CAPTURE_PAYLOAD_SPAN = 3u
};

static UINT8 er_storage_endpoint_route_valid(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_STORAGE &&
                 route->department == ER_DEPARTMENT_STORAGE &&
                 route->work_type == ER_WORK_TYPE_OBJECT_RETRIEVE &&
                 er_hash_nonzero(&route->route_id) != 0u &&
                 er_hash_nonzero(&route->target_route_commitment) != 0u &&
                 er_node_id_nonzero(&route->source_node_id) != 0u &&
                 er_node_id_nonzero(&route->target_node_id) != 0u);
}

static UINT8 er_storage_endpoint_packet_matches_store(const ErStorageEndpointObjectStore* store,
                                                      const ErVfsObjectPacket* packet) {
  if (store == 0 || packet == 0) {
    return 0u;
  }
  if (store->packet_count == 0u) {
    return 1u;
  }
  return (UINT8)(store->object_len == packet->header.object_len &&
                 store->packet_count == packet->header.packet_count &&
                 er_hash_equal(&store->object_id,
                               &packet->header.object_id) != 0u);
}

static UINT8 er_storage_endpoint_capture_hash(const ErCryptoProvider* crypto,
                                              const ErAdmittedRoute* route,
                                              const ErVfsObjectPacket* packet,
                                              ErHash* out_hash) {
  ErByteSpan spans[ER_STORAGE_CAPTURE_SPAN_COUNT];

  if (crypto == 0 || route == 0 || packet == 0 || out_hash == 0) {
    return 0u;
  }
  spans[ER_STORAGE_CAPTURE_ROUTE_SPAN].bytes = route->route_id.bytes;
  spans[ER_STORAGE_CAPTURE_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_OBJECT_SPAN].bytes = packet->header.object_id.bytes;
  spans[ER_STORAGE_CAPTURE_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_PACKET_SPAN].bytes = packet->header.packet_id.bytes;
  spans[ER_STORAGE_CAPTURE_PACKET_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_PAYLOAD_SPAN].bytes = packet->bytes;
  spans[ER_STORAGE_CAPTURE_PAYLOAD_SPAN].len = packet->header.bytes_len;
  return er_crypto_hash(crypto, g_storage_capture_domain,
                        (UINTN)(sizeof(g_storage_capture_domain) - 1u),
                        spans, ER_STORAGE_CAPTURE_SPAN_COUNT, out_hash);
}

UINT8 er_storage_endpoint_object_store_init(ErStorageEndpointObjectStore* store,
                                            ErVfsObjectPacket* packets,
                                            UINT32 packet_capacity) {
  if (store == 0 || packets == 0 || packet_capacity == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)store, (UINTN)sizeof(*store));
  er_mem_zero((UINT8*)packets,
              (UINTN)packet_capacity * (UINTN)sizeof(packets[0]));
  store->abi_version = ER_WORK_ABI_VERSION;
  store->packets = packets;
  store->packet_capacity = packet_capacity;
  return 1u;
}

UINT8 er_storage_endpoint_capture_object_packet(const ErCryptoProvider* crypto,
                                                const ErAdmittedRoute* route,
                                                const ErChannelEnvelopeHeader* envelope,
                                                const ErVfsObjectPacket* packet,
                                                ErStorageEndpointObjectCapture* out_capture) {
  if (crypto == 0 || out_capture == 0 ||
      er_storage_endpoint_route_valid(route) == 0u ||
      er_vfs_object_packet_valid(crypto, packet) == 0u ||
      er_work_verify_channel_envelope_for_route(envelope, route) == 0u ||
      er_hash_equal(&envelope->packet_hash, &packet->header.packet_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_capture, (UINTN)sizeof(*out_capture));
  out_capture->abi_version = ER_WORK_ABI_VERSION;
  out_capture->route_id = route->route_id;
  out_capture->object_id = packet->header.object_id;
  out_capture->object_len = packet->header.object_len;
  out_capture->packet_count = packet->header.packet_count;
  out_capture->packet_index = packet->header.packet_index;
  out_capture->bytes_len = packet->header.bytes_len;
  out_capture->packet_id = packet->header.packet_id;
  out_capture->payload_hash = packet->header.payload_hash;
  return er_storage_endpoint_capture_hash(crypto, route, packet,
                                          &out_capture->capture_hash);
}

UINT8 er_storage_endpoint_store_object_packet(const ErCryptoProvider* crypto,
                                              const ErAdmittedRoute* route,
                                              const ErChannelEnvelopeHeader* envelope,
                                              const ErVfsObjectPacket* packet,
                                              ErStorageEndpointObjectStore* store,
                                              ErStorageEndpointObjectCapture* out_capture) {
  ErStorageEndpointObjectCapture capture;
  UINT32 packet_index;

  if (store == 0 || store->abi_version != ER_WORK_ABI_VERSION ||
      store->packets == 0 ||
      er_storage_endpoint_capture_object_packet(crypto, route, envelope,
                                                packet, &capture) == 0u ||
      er_storage_endpoint_packet_matches_store(store, packet) == 0u ||
      packet->header.packet_count > store->packet_capacity ||
      er_hash_nonzero(&store->packets[packet->header.packet_index].header.packet_id) != 0u) {
    return 0u;
  }

  if (store->packet_count == 0u) {
    store->route_id = route->route_id;
    store->object_id = packet->header.object_id;
    store->object_len = packet->header.object_len;
    store->packet_count = packet->header.packet_count;
  } else if (er_hash_equal(&store->route_id, &route->route_id) == 0u) {
    return 0u;
  }

  packet_index = packet->header.packet_index;
  store->packets[packet_index] = *packet;
  ++store->accepted_packet_count;
  store->complete = (UINT16)(store->accepted_packet_count == store->packet_count);
  if (out_capture != 0) {
    *out_capture = capture;
  }
  return 1u;
}

UINT8 er_storage_endpoint_prepare_package_storage_response(const ErCryptoProvider* crypto,
                                                           const ErStorageEndpointObjectStore* store,
                                                           const ErHash* expected_route_id,
                                                           const ErHash* expected_object_id,
                                                           UINT64 expected_object_len,
                                                           UINT8* object_bytes,
                                                           UINTN object_capacity,
                                                           ErAppPackageStorageResponse* out_response) {
  UINTN object_len = 0u;
  ErHash object_id;

  if (crypto == 0 || store == 0 || expected_route_id == 0 ||
      expected_object_id == 0 || object_bytes == 0 || out_response == 0 ||
      store->abi_version != ER_WORK_ABI_VERSION ||
      store->complete == 0u ||
      store->packet_count == 0u ||
      store->packets == 0 ||
      store->accepted_packet_count != store->packet_count ||
      store->object_len != expected_object_len ||
      object_capacity < expected_object_len ||
      er_hash_equal(&store->route_id, expected_route_id) == 0u ||
      er_hash_equal(&store->object_id, expected_object_id) == 0u) {
    return 0u;
  }
  if (er_vfs_assemble_object_packets(crypto, store->packets,
                                     store->packet_count, object_bytes,
                                     object_capacity, &object_len,
                                     &object_id) == 0u ||
      object_len != (UINTN)expected_object_len ||
      er_hash_equal(&object_id, expected_object_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
  out_response->abi_version = ER_APP_ABI_VERSION;
  out_response->retrieve_route_id = store->route_id;
  out_response->object_id = store->object_id;
  out_response->object_len = store->object_len;
  out_response->packets = store->packets;
  out_response->packet_count = store->packet_count;
  out_response->bytes = object_bytes;
  out_response->capacity = object_capacity;
  return 1u;
}

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

static UINT8 er_storage_endpoint_packet_header_valid(const ErVfsObjectPacket* packet) {
  if (packet == 0 ||
      packet->header.abi_version != ER_VFS_ABI_VERSION ||
      packet->header.packet_count == 0u ||
      packet->header.packet_index >= packet->header.packet_count ||
      packet->header.object_len == 0u ||
      packet->header.bytes_len > ER_VFS_OBJECT_PACKET_BYTES ||
      er_hash_nonzero(&packet->header.object_id) == 0u ||
      er_hash_nonzero(&packet->header.payload_hash) == 0u ||
      er_hash_nonzero(&packet->header.packet_id) == 0u) {
    return 0u;
  }
  return 1u;
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

UINT8 er_storage_endpoint_capture_object_packet(const ErCryptoProvider* crypto,
                                                const ErAdmittedRoute* route,
                                                const ErChannelEnvelopeHeader* envelope,
                                                const ErVfsObjectPacket* packet,
                                                ErStorageEndpointObjectCapture* out_capture) {
  UINT8 object_bytes[ER_VFS_OBJECT_PACKET_BYTES];
  UINTN object_len = 0u;
  ErHash object_id;

  if (crypto == 0 || out_capture == 0 ||
      er_storage_endpoint_route_valid(route) == 0u ||
      er_storage_endpoint_packet_header_valid(packet) == 0u ||
      er_work_verify_channel_envelope_for_route(envelope, route) == 0u ||
      er_hash_equal(&envelope->packet_hash, &packet->header.packet_id) == 0u) {
    return 0u;
  }
  if (er_vfs_assemble_object_packets(crypto, packet, 1u, object_bytes,
                                     (UINTN)sizeof(object_bytes), &object_len,
                                     &object_id) == 0u ||
      object_len != (UINTN)packet->header.object_len ||
      er_hash_equal(&object_id, &packet->header.object_id) == 0u) {
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

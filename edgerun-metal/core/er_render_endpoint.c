#include "er_render_endpoint.h"
#include "er_mem.h"
#include "wasm_vm.h"

/*
 * Purpose: verify render capability work before renderer-specific capture or drawing.
 * Intention: the endpoint records exactly what admitted scene payload it accepted.
 */

static const UINT8 g_render_capture_domain[] = "edgerun:c:v1:render:endpoint-capture";
static const UINT8 g_render_scene_payload_domain[] = "edgerun:c:v1:render:scene-payload";
static const UINT8 g_render_scene_domain[] = "edgerun:c:v1:render:endpoint-scene";

enum {
  ER_RENDER_ENDPOINT_U64_BYTES = 8u,
  ER_RENDER_ENDPOINT_U32_BYTES = 4u,
  ER_RENDER_ENDPOINT_BYTE_BITS = 8u,
  ER_RENDER_ENDPOINT_BYTE_MASK = 0xffu,
  ER_RENDER_ENDPOINT_FIELD_BYTES = (ER_RENDER_ENDPOINT_U64_BYTES * 2u) +
                                   (ER_RENDER_ENDPOINT_U32_BYTES * 2u),
  ER_RENDER_ENDPOINT_SEQUENCE_OFFSET = 0u,
  ER_RENDER_ENDPOINT_TIMESTAMP_OFFSET = 8u,
  ER_RENDER_ENDPOINT_SCENE_BYTES_OFFSET = 16u,
  ER_RENDER_ENDPOINT_RISK_OFFSET = 20u,
  ER_RENDER_ENDPOINT_CAPTURE_SPAN_COUNT = 7u,
  ER_RENDER_ENDPOINT_CAPTURE_ROUTE_SPAN = 0u,
  ER_RENDER_ENDPOINT_CAPTURE_CAPABILITY_SPAN = 1u,
  ER_RENDER_ENDPOINT_CAPTURE_INVOCATION_SPAN = 2u,
  ER_RENDER_ENDPOINT_CAPTURE_SCENE_SPAN = 3u,
  ER_RENDER_ENDPOINT_CAPTURE_SOURCE_SPAN = 4u,
  ER_RENDER_ENDPOINT_CAPTURE_TARGET_SPAN = 5u,
  ER_RENDER_ENDPOINT_CAPTURE_FIELDS_SPAN = 6u,
  ER_RENDER_ENDPOINT_STATE_FIELD_BYTES = ER_RENDER_ENDPOINT_U64_BYTES * 9u,
  ER_RENDER_ENDPOINT_STATE_SEQUENCE_OFFSET = 0u,
  ER_RENDER_ENDPOINT_STATE_BYTES_OFFSET = 8u,
  ER_RENDER_ENDPOINT_STATE_RECTS_OFFSET = 16u,
  ER_RENDER_ENDPOINT_STATE_HITS_OFFSET = 24u,
  ER_RENDER_ENDPOINT_STATE_DRAG_SOURCES_OFFSET = 32u,
  ER_RENDER_ENDPOINT_STATE_DROP_TARGETS_OFFSET = 40u,
  ER_RENDER_ENDPOINT_STATE_TRANSITIONS_OFFSET = 48u,
  ER_RENDER_ENDPOINT_STATE_ICON_QUADS_OFFSET = 56u,
  ER_RENDER_ENDPOINT_STATE_TEXT_QUADS_OFFSET = 64u,
  ER_RENDER_ENDPOINT_SCENE_SPAN_COUNT = 5u,
  ER_RENDER_ENDPOINT_SCENE_CAPTURE_SPAN = 0u,
  ER_RENDER_ENDPOINT_SCENE_HASH_SPAN = 1u,
  ER_RENDER_ENDPOINT_SCENE_SOURCE_SPAN = 2u,
  ER_RENDER_ENDPOINT_SCENE_TARGET_SPAN = 3u,
  ER_RENDER_ENDPOINT_SCENE_FIELDS_SPAN = 4u
};

static void er_render_put_be(UINT8* dst, UINT64 value, UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_RENDER_ENDPOINT_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_RENDER_ENDPOINT_BYTE_MASK);
  }
}

static void er_render_put_be64(UINT8* dst, UINT64 value) {
  er_render_put_be(dst, value, ER_RENDER_ENDPOINT_U64_BYTES);
}

static void er_render_put_be32(UINT8* dst, UINT32 value) {
  er_render_put_be(dst, value, ER_RENDER_ENDPOINT_U32_BYTES);
}

static UINT8 er_render_hash_equal(const ErHash* left, const ErHash* right) {
  if (left == 0 || right == 0) {
    return 0;
  }
  return er_mem_equal(left->bytes, right->bytes, ER_HASH_LEN);
}

static UINT8 er_render_node_equal(const ErNodeId* left, const ErNodeId* right) {
  if (left == 0 || right == 0) {
    return 0;
  }
  return er_mem_equal(left->bytes, right->bytes, ER_NODE_ID_LEN);
}

static UINT8 er_render_capture_valid(const ErRenderEndpointCapture* capture) {
  return (UINT8)(capture != 0 &&
                 capture->abi_version == ER_RENDER_ENDPOINT_ABI_VERSION &&
                 er_mem_any_nonzero(capture->capture_id.bytes, ER_HASH_LEN) != 0u &&
                 er_mem_any_nonzero(capture->scene_hash.bytes, ER_HASH_LEN) != 0u);
}

static UINT8 er_render_route_accepts_capability(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_CAPABILITY &&
                 route->department == ER_DEPARTMENT_CAPABILITY &&
                 route->work_type == ER_WORK_TYPE_CAPABILITY_INVOKE);
}

static UINT8 er_render_capability_is_render_invoke(const ErCapabilityEnvelopeHeader* capability) {
  return (UINT8)(er_work_capability_envelope_header_valid(capability) != 0u &&
                 capability->kind == ER_CAPABILITY_PACKET_INVOKE &&
                 capability->operation == ER_WORK_TYPE_CAPABILITY_INVOKE &&
                 capability->content_type == ER_CAPABILITY_CONTENT_RENDER &&
                 capability->risk_flags == ER_CAPABILITY_RISK_NONE);
}

static UINT8 er_render_endpoint_capture_id(const ErCryptoProvider* crypto,
                                           const ErRenderEndpointCapture* capture,
                                           ErHash* out_capture_id) {
  UINT8 fields[ER_RENDER_ENDPOINT_FIELD_BYTES];
  ErByteSpan spans[ER_RENDER_ENDPOINT_CAPTURE_SPAN_COUNT];

  if (crypto == 0 || capture == 0 || out_capture_id == 0) {
    return 0;
  }
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_SEQUENCE_OFFSET],
                     capture->sequence);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_TIMESTAMP_OFFSET],
                     capture->timestamp_ms);
  er_render_put_be32(&fields[ER_RENDER_ENDPOINT_SCENE_BYTES_OFFSET],
                     capture->scene_bytes);
  er_render_put_be32(&fields[ER_RENDER_ENDPOINT_RISK_OFFSET],
                     capture->risk_flags);
  spans[ER_RENDER_ENDPOINT_CAPTURE_ROUTE_SPAN].bytes = capture->route_id.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_CAPABILITY_SPAN].bytes =
      capture->capability_id.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_CAPABILITY_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_INVOCATION_SPAN].bytes =
      capture->invocation_id.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_INVOCATION_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_SCENE_SPAN].bytes = capture->scene_hash.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_SCENE_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_SOURCE_SPAN].bytes =
      capture->source_node_id.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_SOURCE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_TARGET_SPAN].bytes =
      capture->target_node_id.bytes;
  spans[ER_RENDER_ENDPOINT_CAPTURE_TARGET_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_RENDER_ENDPOINT_CAPTURE_FIELDS_SPAN].bytes = fields;
  spans[ER_RENDER_ENDPOINT_CAPTURE_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_render_capture_domain,
                        (UINTN)(sizeof(g_render_capture_domain) - 1u),
                        spans, ER_RENDER_ENDPOINT_CAPTURE_SPAN_COUNT,
                        out_capture_id);
}

static UINT8 er_render_endpoint_scene_id(const ErCryptoProvider* crypto,
                                         const ErRenderEndpointScene* scene,
                                         ErHash* out_scene_id) {
  UINT8 fields[ER_RENDER_ENDPOINT_STATE_FIELD_BYTES];
  ErByteSpan spans[ER_RENDER_ENDPOINT_SCENE_SPAN_COUNT];

  if (crypto == 0 || scene == 0 || out_scene_id == 0) {
    return 0;
  }
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_SEQUENCE_OFFSET],
                     scene->sequence);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_BYTES_OFFSET],
                     (UINT64)scene->scene_bytes);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_RECTS_OFFSET],
                     (UINT64)scene->scene_stats.rects);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_HITS_OFFSET],
                     (UINT64)scene->scene_stats.hits);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_DRAG_SOURCES_OFFSET],
                     (UINT64)scene->scene_stats.drag_sources);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_DROP_TARGETS_OFFSET],
                     (UINT64)scene->scene_stats.drop_targets);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_TRANSITIONS_OFFSET],
                     (UINT64)scene->scene_stats.transitions);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_ICON_QUADS_OFFSET],
                     (UINT64)scene->scene_stats.icon_quads);
  er_render_put_be64(&fields[ER_RENDER_ENDPOINT_STATE_TEXT_QUADS_OFFSET],
                     (UINT64)scene->scene_stats.text_quads);
  spans[ER_RENDER_ENDPOINT_SCENE_CAPTURE_SPAN].bytes = scene->capture_id.bytes;
  spans[ER_RENDER_ENDPOINT_SCENE_CAPTURE_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_SCENE_HASH_SPAN].bytes = scene->scene_hash.bytes;
  spans[ER_RENDER_ENDPOINT_SCENE_HASH_SPAN].len = ER_HASH_LEN;
  spans[ER_RENDER_ENDPOINT_SCENE_SOURCE_SPAN].bytes = scene->source_node_id.bytes;
  spans[ER_RENDER_ENDPOINT_SCENE_SOURCE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_RENDER_ENDPOINT_SCENE_TARGET_SPAN].bytes = scene->target_node_id.bytes;
  spans[ER_RENDER_ENDPOINT_SCENE_TARGET_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_RENDER_ENDPOINT_SCENE_FIELDS_SPAN].bytes = fields;
  spans[ER_RENDER_ENDPOINT_SCENE_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_render_scene_domain,
                        (UINTN)(sizeof(g_render_scene_domain) - 1u),
                        spans, ER_RENDER_ENDPOINT_SCENE_SPAN_COUNT,
                        out_scene_id);
}

UINT8 er_render_endpoint_scene_payload_hash(const ErCryptoProvider* crypto,
                                            const UINT8* bytes,
                                            UINT32 len,
                                            ErHash* out_hash) {
  ErByteSpan span;

  if (crypto == 0 || bytes == 0 || len == 0u || out_hash == 0) {
    return 0;
  }
  span.bytes = bytes;
  span.len = (UINTN)len;
  return er_crypto_hash(crypto, g_render_scene_payload_domain,
                        (UINTN)(sizeof(g_render_scene_payload_domain) - 1u),
                        &span, 1u, out_hash);
}

UINT8 er_render_endpoint_capture(const ErCryptoProvider* crypto,
                                 const ErAdmittedRoute* route,
                                 const ErChannelEnvelopeHeader* envelope,
                                 const ErCapabilityEnvelopeHeader* capability,
                                 ErRenderEndpointCapture* out_capture) {
  if (crypto == 0 || out_capture == 0 ||
      er_render_route_accepts_capability(route) == 0u ||
      er_work_verify_channel_envelope_for_route(envelope, route) == 0u ||
      er_render_capability_is_render_invoke(capability) == 0u ||
      er_render_node_equal(&capability->source_node_id,
                           &route->source_node_id) == 0u ||
      er_render_node_equal(&capability->target_node_id,
                           &route->target_node_id) == 0u ||
      capability->sequence != envelope->sequence ||
      er_render_hash_equal(&capability->payload_hash,
                           &envelope->packet_hash) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_capture, (UINTN)sizeof(*out_capture));
  out_capture->abi_version = ER_RENDER_ENDPOINT_ABI_VERSION;
  out_capture->route_id = route->route_id;
  out_capture->capability_id = capability->capability_id;
  out_capture->invocation_id = capability->invocation_id;
  out_capture->scene_hash = capability->payload_hash;
  out_capture->source_node_id = capability->source_node_id;
  out_capture->target_node_id = capability->target_node_id;
  out_capture->sequence = capability->sequence;
  out_capture->timestamp_ms = capability->timestamp_ms;
  out_capture->scene_bytes = capability->payload_len;
  out_capture->risk_flags = capability->risk_flags;
  return er_render_endpoint_capture_id(crypto, out_capture,
                                       &out_capture->capture_id);
}

UINT8 er_render_endpoint_decode_scene_payload(const ErCryptoProvider* crypto,
                                              const ErRenderEndpointCapture* capture,
                                              const UINT8* bytes,
                                              UINT32 len,
                                              er_ui_scene_t* out_scene,
                                              ErRenderEndpointScene* out_endpoint_scene) {
  ErHash payload_hash;
  er_ui_scene_stats_t stats;

  if (crypto == 0 || er_render_capture_valid(capture) == 0u || bytes == 0 ||
      len == 0u || out_scene == 0 || out_endpoint_scene == 0 ||
      len != capture->scene_bytes ||
      er_render_endpoint_scene_payload_hash(crypto, bytes, len,
                                            &payload_hash) == 0u ||
      er_render_hash_equal(&payload_hash, &capture->scene_hash) == 0u ||
      er_wasm_ui_command_decode(bytes, len, out_scene, &stats) != 0) {
    return 0;
  }

  er_mem_zero((UINT8*)out_endpoint_scene,
              (UINTN)sizeof(*out_endpoint_scene));
  out_endpoint_scene->abi_version = ER_RENDER_ENDPOINT_ABI_VERSION;
  out_endpoint_scene->capture_id = capture->capture_id;
  out_endpoint_scene->scene_hash = capture->scene_hash;
  out_endpoint_scene->source_node_id = capture->source_node_id;
  out_endpoint_scene->target_node_id = capture->target_node_id;
  out_endpoint_scene->sequence = capture->sequence;
  out_endpoint_scene->scene_bytes = len;
  out_endpoint_scene->scene_stats = stats;
  return er_render_endpoint_scene_id(crypto, out_endpoint_scene,
                                     &out_endpoint_scene->scene_id);
}

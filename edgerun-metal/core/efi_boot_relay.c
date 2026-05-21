#include "internal/efi_boot_internal.h"

/*
 * Purpose: connect post-boot native erwire ingress to OS endpoint dispatch.
 * Intention: keep relay polling/classification testable outside the infinite UI loop.
 */

static const char g_er_ui_boot_render_endpoint_label[] = "render-endpoint";
static const char g_er_ui_boot_storage_endpoint_label[] = "storage-endpoint";

enum {
  ER_UI_BOOT_RELAY_FIRST_HOP_INDEX = 0u
};

static ErUiBootAppContext* er_ui_boot_relay_active_app(ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

static UINT8 er_ui_boot_prepare_memory_endpoint(const ErAdmittedRoute* route,
                                                const char* label,
                                                UINT16 label_len,
                                                ErChannelEndpoint* out_endpoint) {
  if (route == 0 || out_endpoint == 0 ||
      label == 0 || label_len == 0u ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&route->channel_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_MEMORY;
  out_endpoint->channel_id = route->channel_id;
  out_endpoint->label_len = label_len;
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label,
              (UINTN)label_len);
  return 1u;
}

static UINT8 er_ui_boot_prepare_endpoint_for_route(const ErAdmittedRoute* route,
                                                   ErChannelEndpoint* out_endpoint) {
  if (route == 0) {
    return 0u;
  }
  switch (route->role) {
    case ER_NODE_ROLE_CAPABILITY:
      return er_ui_boot_prepare_memory_endpoint(route,
                                                g_er_ui_boot_render_endpoint_label,
                                                (UINT16)(sizeof(g_er_ui_boot_render_endpoint_label) - 1u),
                                                out_endpoint);
    case ER_NODE_ROLE_STORAGE:
      return er_ui_boot_prepare_memory_endpoint(route,
                                                g_er_ui_boot_storage_endpoint_label,
                                                (UINT16)(sizeof(g_er_ui_boot_storage_endpoint_label) - 1u),
                                                out_endpoint);
    default:
      return 0u;
  }
}

UINT8 er_ui_boot_prepare_route_envelope(const ErAdmittedRoute* route,
                                        const ErHash* packet_hash,
                                        UINT64 sequence,
                                        ErChannelEnvelopeHeader* out_envelope) {
  if (route == 0 || packet_hash == 0 || out_envelope == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_envelope, (UINTN)sizeof(*out_envelope));
  out_envelope->abi_version = ER_WORK_ABI_VERSION;
  out_envelope->packet_kind = route->work_type;
  out_envelope->channel_id = route->channel_id;
  out_envelope->from = route->source_node_id;
  out_envelope->to = route->target_node_id;
  out_envelope->route_hash = route->target_route_commitment;
  out_envelope->packet_hash = *packet_hash;
  out_envelope->sequence = sequence;
  return er_work_verify_channel_envelope_for_route(out_envelope, route);
}

static UINT8 er_ui_boot_prepare_native_relay_transit(ErUiBootRenderContext* render,
                                                     const ErNativeRelayIngress* ingress,
                                                     const ErAdmittedRoute* route,
                                                     const ErRelayPacketHeader* packet) {
  ErCryptoProvider crypto;
  ErChannelEnvelopeHeader envelope;
  ErRelayForwardIntent intent;
  ErHash input_hash;
  ErHash previous_transit_hash;

  if (render == 0 || ingress == 0 || route == 0 || packet == 0 ||
      er_hash_nonzero(&ingress->packet_hash) == 0u) {
    return 0u;
  }

  if (er_ui_boot_prepare_route_envelope(route, &ingress->packet_hash,
                                        packet->sequence, &envelope) == 0u) {
    return 0u;
  }

  er_crypto_blake3_provider(&crypto);
  if (er_work_ordered_message_input_hash(&crypto, &envelope, &input_hash) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)&intent, (UINTN)sizeof(intent));
  intent.abi_version = ER_WORK_ABI_VERSION;
  intent.relay_node_id = route->relay_node_id;
  intent.source_node_id = route->source_node_id;
  intent.target_node_id = route->target_node_id;
  intent.from = ingress->ingress;
  if (er_ui_boot_prepare_endpoint_for_route(route, &intent.to) == 0u) {
    return 0u;
  }
  intent.route_hash = route->target_route_commitment;
  intent.packet_hash = ingress->packet_hash;
  intent.sequence = packet->sequence;

  er_mem_zero(previous_transit_hash.bytes, ER_HASH_LEN);
  if (er_work_prepare_relay_transit_hop(&crypto, &intent, &input_hash,
                                        &previous_transit_hash,
                                        ER_UI_BOOT_RELAY_FIRST_HOP_INDEX,
                                        &render->native_relay_last_transit) == 0u) {
    return 0u;
  }
  ++render->native_relay_stats.transit_hops;
  if (render->native_relay != 0 && render->native_relay->initialized != 0u) {
    erwire_send(ERWIRE_KIND_RELAY_TRANSIT_HOP,
                ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                (const UINT8*)&render->native_relay_last_transit,
                (UINT32)sizeof(render->native_relay_last_transit));
    ++render->native_relay_stats.transit_emitted;
  }
  return 1u;
}

static UINT8 er_ui_boot_decode_native_render_scene(ErUiBootRenderContext* render,
                                                   const ErAdmittedRoute* route,
                                                   const ErNativeEndpointIntent* intent,
                                                   UINT8* out_redraw) {
  ErCryptoProvider crypto;
  ErChannelEnvelopeHeader envelope;

  if (render == 0 || route == 0 || intent == 0 || out_redraw == 0) {
    return 0u;
  }
  if (intent->scene_payload_len == 0u) {
    return 1u;
  }
  if (render->scene == 0) {
    return 0u;
  }

  er_crypto_blake3_provider(&crypto);
  if (er_ui_boot_prepare_route_envelope(route, &intent->capability.payload_hash,
                                        intent->packet.sequence,
                                        &envelope) == 0u ||
      er_render_endpoint_capture(&crypto, route, &envelope,
                                 &intent->capability,
                                 &render->native_relay_last_render_capture) == 0u ||
      er_render_endpoint_decode_scene_payload(&crypto,
                                              &render->native_relay_last_render_capture,
                                              intent->scene_payload,
                                              intent->scene_payload_len,
                                              render->scene,
                                              &render->native_relay_last_render_scene) == 0u) {
    return 0u;
  }
  ++render->native_relay_stats.render_scenes;
  *out_redraw = 1u;
  return 1u;
}

static UINT8 er_ui_boot_storage_store_needs_replacement(const ErStorageEndpointObjectStore* store,
                                                        const ErVfsObjectPacket* packet) {
  if (store == 0 || packet == 0 ||
      store->abi_version != ER_WORK_ABI_VERSION ||
      store->complete == 0u ||
      packet->header.packet_index != 0u) {
    return 0u;
  }
  return (UINT8)(er_hash_equal(&store->object_id,
                               &packet->header.object_id) == 0u);
}

static UINT8 er_ui_boot_prepare_active_app_storage_store(ErUiBootAppContext* app,
                                                         const ErVfsObjectPacket* packet) {
  if (app == 0 || packet == 0) {
    return 0u;
  }
  if (app->storage.app_store.abi_version != ER_WORK_ABI_VERSION ||
      er_ui_boot_storage_store_needs_replacement(&app->storage.app_store,
                                                 packet) != 0u) {
    return er_storage_endpoint_object_store_init(&app->storage.app_store,
                                                 app->storage.app_packets,
                                                 ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY);
  }
  return 1u;
}

static UINT8 er_ui_boot_capture_native_storage_object(ErUiBootRenderContext* render,
                                                      const ErAdmittedRoute* route,
                                                      const ErNativeEndpointIntent* intent) {
  ErCryptoProvider crypto;
  ErChannelEnvelopeHeader envelope;
  ErUiBootAppContext* active_app;

  if (render == 0 || route == 0 || intent == 0) {
    return 0u;
  }
  active_app = er_ui_boot_relay_active_app(render);
  if (active_app == 0 ||
      er_ui_boot_prepare_active_app_storage_store(active_app,
                                                 &intent->object_packet) == 0u) {
    return 0u;
  }

  er_crypto_blake3_provider(&crypto);
  if (er_ui_boot_prepare_route_envelope(route, &intent->packet.payload_hash,
                                        intent->packet.sequence,
                                        &envelope) == 0u ||
      er_storage_endpoint_store_object_packet(&crypto, route, &envelope,
                                              &intent->object_packet,
                                              &active_app->storage.app_store,
                                              &render->native_relay_last_storage_capture) == 0u) {
    return 0u;
  }
  ++render->native_relay_stats.storage_object_packets;
  return 1u;
}

static UINT8 er_ui_boot_try_storage_intent(ErUiBootRenderContext* render,
                                           const ErNativeRelayIngress* ingress,
                                           ErNativeEndpointIntent* out_intent,
                                           ErAdmittedRoute* out_route) {
  if (render == 0 || ingress == 0 || out_intent == 0 || out_route == 0) {
    return 0u;
  }
  if (er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                render->active_app,
                                                out_route) == 0u ||
      er_native_boot_decode_endpoint_intent(ingress, out_route,
                                            out_intent) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_ui_boot_dispatch_native_relay_ingress(ErUiBootRenderContext* render,
                                               const ErNativeRelayIngress* ingress,
                                               UINT8* out_redraw) {
  ErUiBootAppContext* active_app;
  ErAdmittedRoute route;
  ErNativeEndpointIntent intent;

  if (out_redraw == 0) {
    return 0u;
  }
  *out_redraw = 0u;
  if (render == 0 || ingress == 0) {
    return 0u;
  }

  switch (ingress->status) {
    case ER_NATIVE_RELAY_INGRESS_NONE:
      ++render->native_relay_stats.none;
      return 1u;
    case ER_NATIVE_RELAY_INGRESS_MALFORMED:
      ++render->native_relay_stats.malformed;
      return 1u;
    case ER_NATIVE_RELAY_INGRESS_ACCEPTED:
      break;
    default:
      ++render->native_relay_stats.malformed;
      return 1u;
  }

  active_app = er_ui_boot_relay_active_app(render);
  if (active_app == 0 ||
      er_ui_wasm_app_prepare_render_route(active_app->runtime.presentation,
                                          &route) == 0u ||
      er_native_boot_decode_endpoint_intent(ingress, &route, &intent) == 0u) {
    return 0u;
  }
  if (intent.kind == ER_NATIVE_ENDPOINT_INTENT_MALFORMED &&
      er_ui_boot_try_storage_intent(render, ingress, &intent, &route) == 0u) {
    return 0u;
  }

  switch (intent.kind) {
    case ER_NATIVE_ENDPOINT_INTENT_NONE:
      ++render->native_relay_stats.none;
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_RENDER_CAPABILITY:
      if (er_ui_boot_prepare_native_relay_transit(render, ingress, &route,
                                                  &intent.packet) == 0u ||
          er_ui_boot_decode_native_render_scene(render, &route, &intent,
                                                out_redraw) == 0u) {
        return 0u;
      }
      ++render->native_relay_stats.render_capability;
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_STORAGE_OBJECT_PACKET:
      if (er_ui_boot_prepare_native_relay_transit(render, ingress, &route,
                                                  &intent.packet) == 0u ||
          er_ui_boot_capture_native_storage_object(render, &route,
                                                  &intent) == 0u) {
        return 0u;
      }
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_UNSUPPORTED:
      if (er_ui_boot_prepare_native_relay_transit(render, ingress, &route,
                                                  &intent.packet) == 0u) {
        return 0u;
      }
      ++render->native_relay_stats.unsupported;
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_MALFORMED:
      ++render->native_relay_stats.malformed;
      return 1u;
    default:
      ++render->native_relay_stats.malformed;
      return 1u;
  }
}

UINT8 er_ui_boot_poll_native_relay(ErUiBootRenderContext* render,
                                   UINT8* out_redraw) {
  ErCryptoProvider crypto;
  ErNativeRelayIngress ingress;

  if (out_redraw == 0) {
    return 0u;
  }
  *out_redraw = 0u;
  if (render == 0) {
    return 0u;
  }
  if (render->native_relay == 0 || render->native_relay->initialized == 0u) {
    return 1u;
  }

  er_crypto_blake3_provider(&crypto);
  ++render->native_relay_stats.polls;
  if (er_native_boot_poll_relay_ingress(render->native_relay, &crypto,
                                        &ingress) == 0u) {
    return 0u;
  }
  return er_ui_boot_dispatch_native_relay_ingress(render, &ingress, out_redraw);
}

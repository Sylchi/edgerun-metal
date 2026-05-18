#include "efi_boot_internal.h"

/*
 * Purpose: connect post-boot native erwire ingress to OS endpoint dispatch.
 * Intention: keep relay polling/classification testable outside the infinite UI loop.
 */

static const char g_er_ui_boot_render_endpoint_label[] = "render-endpoint";

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

static UINT8 er_ui_boot_prepare_render_endpoint(const ErAdmittedRoute* route,
                                                ErChannelEndpoint* out_endpoint) {
  if (route == 0 || out_endpoint == 0 ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&route->channel_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_MEMORY;
  out_endpoint->channel_id = route->channel_id;
  out_endpoint->label_len = (UINT16)(sizeof(g_er_ui_boot_render_endpoint_label) - 1u);
  er_mem_copy((UINT8*)out_endpoint->label,
              (const UINT8*)g_er_ui_boot_render_endpoint_label,
              (UINTN)(sizeof(g_er_ui_boot_render_endpoint_label) - 1u));
  return 1u;
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

  er_mem_zero((UINT8*)&envelope, (UINTN)sizeof(envelope));
  envelope.abi_version = ER_WORK_ABI_VERSION;
  envelope.packet_kind = route->work_type;
  envelope.channel_id = route->channel_id;
  envelope.from = route->source_node_id;
  envelope.to = route->target_node_id;
  envelope.route_hash = route->target_route_commitment;
  envelope.packet_hash = ingress->packet_hash;
  envelope.sequence = packet->sequence;
  if (er_work_verify_channel_envelope_for_route(&envelope, route) == 0u) {
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
  if (er_ui_boot_prepare_render_endpoint(route, &intent.to) == 0u) {
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

  switch (intent.kind) {
    case ER_NATIVE_ENDPOINT_INTENT_NONE:
      ++render->native_relay_stats.none;
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_RENDER_CAPABILITY:
      if (er_ui_boot_prepare_native_relay_transit(render, ingress, &route,
                                                  &intent.packet) == 0u) {
        return 0u;
      }
      ++render->native_relay_stats.render_capability;
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

#include "efi_boot_internal.h"

/*
 * Purpose: connect post-boot native erwire ingress to OS endpoint dispatch.
 * Intention: keep relay polling/classification testable outside the infinite UI loop.
 */

static ErUiBootAppContext* er_ui_boot_relay_active_app(ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
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
      ++render->native_relay_stats.render_capability;
      return 1u;
    case ER_NATIVE_ENDPOINT_INTENT_UNSUPPORTED:
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

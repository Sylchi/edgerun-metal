#include "er_ui_demo_apps.h"

static const float ER_UI_DEMO_APP_PAD = 24.0f;
static const float ER_UI_DEMO_APP_COMPACT_PAD = 10.0f;
static const float ER_UI_DEMO_APP_GAP = 16.0f;
static const float ER_UI_DEMO_APP_COMPACT_GAP = 8.0f;
static const float ER_UI_DEMO_APP_HEADER_H = 86.0f;
static const float ER_UI_DEMO_APP_COMPACT_HEADER_H = 46.0f;
static const float ER_UI_DEMO_APP_CARD_H = 128.0f;
static const float ER_UI_DEMO_APP_COMPACT_CARD_H = 82.0f;
static const float ER_UI_DEMO_APP_ROW_H = 58.0f;
static const float ER_UI_DEMO_APP_COMPACT_ROW_H = 44.0f;
static const float ER_UI_DEMO_APP_COMPACT_MAX_W = 720.0f;
static const float ER_UI_DEMO_APP_METRIC_RATIO_HALF = 0.5f;
static const float ER_UI_DEMO_APP_METRIC_COLUMN_COUNT = 3.0f;
static const float ER_UI_DEMO_APP_CHART_GAP_COUNT = 3.0f;
static const float ER_UI_DEMO_APP_CHART_H = 210.0f;
static const float ER_UI_DEMO_APP_CHART_MIN_H = 96.0f;
static const float ER_UI_DEMO_APP_ROUTE_PATH_H = 132.0f;
static const float ER_UI_DEMO_APP_NETWORK_TABLE_H = 190.0f;
static const float ER_UI_DEMO_APP_PACKAGE_CARD_H = 126.0f;
static const float ER_UI_DEMO_APP_IDENTITY_CARD_H = 118.0f;
static const float ER_UI_DEMO_APP_CONTACT_ROW_GAP = 10.0f;
#define ER_UI_DEMO_APP_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_DEMO_APP_ACTION_BASE_ID 0xED021000u
#define ER_UI_DEMO_APP_RESOURCES_ADMIT_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 1u)
#define ER_UI_DEMO_APP_RESOURCES_CHART_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 20u)
#define ER_UI_DEMO_APP_RESOURCES_RECEIPT_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 30u)
#define ER_UI_DEMO_APP_NETWORK_HEADER_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 101u)
#define ER_UI_DEMO_APP_NETWORK_TABLE_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 120u)
#define ER_UI_DEMO_APP_NETWORK_PACKAGE_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 130u)
#define ER_UI_DEMO_APP_PEOPLE_HEADER_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 201u)
#define ER_UI_DEMO_APP_PEOPLE_IDENTITY_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 210u)
#define ER_UI_DEMO_APP_PEOPLE_CONTACT_ARI_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 211u)
#define ER_UI_DEMO_APP_PEOPLE_CONTACT_MINA_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 212u)
#define ER_UI_DEMO_APP_PEOPLE_THREAD_ID (ER_UI_DEMO_APP_ACTION_BASE_ID + 213u)
static const size_t ER_UI_DEMO_APP_NETWORK_TABLE_ROWS = 3u;

static er_ui_status_t er_ui_demo_emit_resources(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  static const char* const chart_labels[] = {"cpu", "mem", "net", "store"};
  static const float chart_values[] = {0.46f, 0.64f, 0.31f, 0.72f};
  er_ui_status_t status;
  float metric_w;
  bool compact = bounds.w <= ER_UI_DEMO_APP_COMPACT_MAX_W;
  float pad = compact ? ER_UI_DEMO_APP_COMPACT_PAD : ER_UI_DEMO_APP_PAD;
  float gap = compact ? ER_UI_DEMO_APP_COMPACT_GAP : ER_UI_DEMO_APP_GAP;
  float header_h = compact ? ER_UI_DEMO_APP_COMPACT_HEADER_H : ER_UI_DEMO_APP_HEADER_H;
  float card_h = compact ? ER_UI_DEMO_APP_COMPACT_CARD_H : ER_UI_DEMO_APP_CARD_H;
  float row_h = compact ? ER_UI_DEMO_APP_COMPACT_ROW_H : ER_UI_DEMO_APP_ROW_H;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, pad, pad);
  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, header_h);
  er_ui_bounds_t metrics = er_ui_bounds(content.x, header.y + header.h + gap, content.w, card_h);
  float chart_h = compact ? content.h - header.h - card_h - row_h - gap * ER_UI_DEMO_APP_CHART_GAP_COUNT : ER_UI_DEMO_APP_CHART_H;
  if (chart_h < ER_UI_DEMO_APP_CHART_MIN_H) chart_h = ER_UI_DEMO_APP_CHART_MIN_H;
  er_ui_bounds_t chart = er_ui_bounds(content.x, metrics.y + metrics.h + gap, content.w, chart_h);
  er_ui_bounds_t receipt = er_ui_bounds(content.x, chart.y + chart.h + gap, content.w, row_h);

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "Resources", "local device budgets admitted to apps", "Admit route",
                                          ER_UI_DEMO_APP_RESOURCES_ADMIT_ID);
  if (status != ER_UI_OK) return status;

  if (compact) {
    metric_w = (metrics.w - gap) * ER_UI_DEMO_APP_METRIC_RATIO_HALF;
    status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metrics.x, metrics.y, metric_w, metrics.h), theme, "CPU", "46%",
                                           "", true, 0.46f, theme.colors.info);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metrics.x + metric_w + gap, metrics.y, metric_w, metrics.h), theme,
                                           "Memory", "64%", "", true, 0.64f, theme.colors.accent);
    if (status != ER_UI_OK) return status;
  } else {
    metric_w = (metrics.w - gap * (ER_UI_DEMO_APP_METRIC_COLUMN_COUNT - 1.0f)) / ER_UI_DEMO_APP_METRIC_COLUMN_COUNT;
    status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metrics.x, metrics.y, metric_w, metrics.h), theme, "CPU", "46%",
                                           "mintable compute window", true, 0.46f, theme.colors.info);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metrics.x + metric_w + gap, metrics.y, metric_w, metrics.h), theme,
                                           "Memory", "64%", "linear pages reserved", true, 0.64f, theme.colors.accent);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_metric_card_emit(
      scene,
      font,
      er_ui_bounds(metrics.x + (metric_w + gap) * (ER_UI_DEMO_APP_METRIC_COLUMN_COUNT - 1.0f), metrics.y, metric_w, metrics.h),
      theme,
      "Storage",
      "72%",
      "cache bytes available",
      true,
      0.72f,
      theme.colors.success);
    if (status != ER_UI_OK) return status;
  }

  status = er_ui_shadcn_bar_chart_emit(scene, font, chart, theme, "Jurisdiction budget", chart_labels, chart_values,
                                       ER_UI_DEMO_APP_ARRAY_COUNT(chart_values), ER_UI_DEMO_APP_RESOURCES_CHART_ID, 1u);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_receipt_row_emit(scene, font, receipt, theme, "ui-counter.wasm", "+36 bytes accounted", "accepted",
                                      ER_UI_DEMO_APP_RESOURCES_RECEIPT_ID);
}

static er_ui_status_t er_ui_demo_emit_network(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  static const char* const route[] = {"app", "ui relay", "device", "peer"};
  static const char* const headers[] = {"Token", "Rate", "Policy"};
  static const char* const cells[] = {
    "local.cpu", "1.0", "own device",
    "peer.bytes", "0.7", "friend relay",
    "store.cache", "0.2", "verified hash"
  };
  er_ui_status_t status;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, ER_UI_DEMO_APP_PAD, ER_UI_DEMO_APP_PAD);
  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, ER_UI_DEMO_APP_HEADER_H);
  er_ui_bounds_t route_box = er_ui_bounds(content.x, header.y + header.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_ROUTE_PATH_H);
  er_ui_bounds_t table = er_ui_bounds(content.x, route_box.y + route_box.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_NETWORK_TABLE_H);
  er_ui_bounds_t package = er_ui_bounds(content.x, table.y + table.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_PACKAGE_CARD_H);

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "Network", "packets routed by admission slips", "Relay packet",
                                          ER_UI_DEMO_APP_NETWORK_HEADER_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_route_path_emit(scene, font, route_box, theme, "Packet path", route, ER_UI_DEMO_APP_ARRAY_COUNT(route));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_table_emit(scene, font, table, theme, headers, ER_UI_DEMO_APP_ARRAY_COUNT(headers), cells, ER_UI_DEMO_APP_NETWORK_TABLE_ROWS,
                                   ER_UI_DEMO_APP_NETWORK_TABLE_ID);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_package_card_emit(scene, font, package, theme, "chat.demo.wasm", "requires peer.bytes token", "blake3: routed-ui-demo",
                                        ER_UI_DEMO_APP_NETWORK_PACKAGE_ID);
}

static er_ui_status_t er_ui_demo_emit_people(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  er_ui_status_t status;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, ER_UI_DEMO_APP_PAD, ER_UI_DEMO_APP_PAD);
  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, ER_UI_DEMO_APP_HEADER_H);
  er_ui_bounds_t identity = er_ui_bounds(content.x, header.y + header.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_IDENTITY_CARD_H);
  er_ui_bounds_t contact_a = er_ui_bounds(content.x, identity.y + identity.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_ROW_H);
  er_ui_bounds_t contact_b = er_ui_bounds(content.x, contact_a.y + contact_a.h + ER_UI_DEMO_APP_CONTACT_ROW_GAP, content.w, ER_UI_DEMO_APP_ROW_H);
  er_ui_bounds_t thread = er_ui_bounds(content.x, contact_b.y + contact_b.h + ER_UI_DEMO_APP_GAP, content.w, ER_UI_DEMO_APP_ROW_H);

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "People", "human relations as local policy", "Share token",
                                          ER_UI_DEMO_APP_PEOPLE_HEADER_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_identity_card_emit(scene, font, identity, theme, "Ken", "device.identity.local", "user-governed",
                                           ER_UI_DEMO_APP_PEOPLE_IDENTITY_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_contact_card_emit(scene, font, contact_a, theme, "Ari", "can relay 64 KiB/s until revoked",
                                          ER_UI_DEMO_APP_PEOPLE_CONTACT_ARI_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_contact_card_emit(scene, font, contact_b, theme, "Mina", "storage cache accepted for signed packages",
                                          ER_UI_DEMO_APP_PEOPLE_CONTACT_MINA_ID);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_thread_row_emit(scene, font, thread, theme, "Route request", "peer asks for temporary packet budget", true,
                                      ER_UI_DEMO_APP_PEOPLE_THREAD_ID);
}

static er_ui_status_t er_ui_demo_emit_surface(
  uint32_t surface_id,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  void* user) {
  (void)user;
  if (!font) return ER_UI_ERR_INVALID_ARGUMENT;
  switch (surface_id) {
    case ER_UI_DEMO_APP_RESOURCES_ID:
      return er_ui_demo_emit_resources(scene, font, bounds, theme);
    case ER_UI_DEMO_APP_NETWORK_ID:
      return er_ui_demo_emit_network(scene, font, bounds, theme);
    case ER_UI_DEMO_APP_PEOPLE_ID:
      return er_ui_demo_emit_people(scene, font, bounds, theme);
    default:
      return er_ui_shadcn_empty_emit(scene, font, er_ui_bounds_inset(bounds, ER_UI_DEMO_APP_PAD, ER_UI_DEMO_APP_PAD),
                                    theme, "No admitted app", "The focused surface has no demo renderer.");
  }
}

er_ui_status_t er_ui_demo_apps_state_init(er_ui_demo_apps_state_t* state, er_ui_allocator_t allocator) {
  er_ui_status_t status;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_shell_state_init_with_allocator(&state->shell, allocator);
  if (status != ER_UI_OK) return status;
  er_ui_shadcn_demo_gallery_state_init(&state->gallery);
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_DEMO_APP_RESOURCES_ID, "Resources");
  if (status != ER_UI_OK) return status;
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_DEMO_APP_NETWORK_ID, "Network");
  if (status != ER_UI_OK) return status;
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_DEMO_APP_PEOPLE_ID, "People");
  if (status != ER_UI_OK) return status;
  return er_ui_workspace_focus_surface(&state->shell, ER_UI_DEMO_APP_RESOURCES_ID);
}

void er_ui_demo_apps_state_destroy(er_ui_demo_apps_state_t* state) {
  if (!state) return;
  er_ui_shell_state_destroy(&state->shell);
}

er_ui_status_t er_ui_demo_apps_apply_action(er_ui_demo_apps_state_t* state, er_ui_action_t action, bool* out_changed) {
  bool gallery_changed;
  er_ui_status_t status;
  if (out_changed) *out_changed = false;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;

  gallery_changed = er_ui_shadcn_demo_gallery_apply_action(&state->gallery, action);
  status = er_ui_shell_apply_action(&state->shell, action, out_changed);
  if (status != ER_UI_OK) return status;
  if (out_changed && gallery_changed) *out_changed = true;
  return ER_UI_OK;
}

er_ui_status_t er_ui_demo_apps_emit_scene(
  er_ui_demo_apps_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_shell_emit_scene_with_font_and_surfaces(&state->shell, scene, bounds, theme, font, er_ui_demo_emit_surface, state);
}

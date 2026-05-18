#include "er_ui_ledger_app.h"
#include "er_ui_painter.h"
#include "er_ui_shadcn.h"
#include "er_ui_spacing.h"

#define ER_UI_LEDGER_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS_LIMIT 4u

static const float ER_UI_LEDGER_MARGIN = 12.0f;
static const float ER_UI_LEDGER_GAP = 12.0f;
static const float ER_UI_LEDGER_MIN_SIDE_W = 136.0f;
static const float ER_UI_LEDGER_SIDE_W = 168.0f;
static const float ER_UI_LEDGER_STACKED_SIDE_H = 132.0f;
static const float ER_UI_LEDGER_MIN_CARD_W = 240.0f;
static const float ER_UI_LEDGER_DASHBOARD_MIN_CARD_W = 320.0f;
static const float ER_UI_LEDGER_NARROW_CARD_W = 280.0f;
static const size_t ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS = ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS_LIMIT;
static const size_t ER_UI_LEDGER_DASHBOARD_MASONRY_COLUMNS = 3u;
static const size_t ER_UI_LEDGER_DASHBOARD_DETAILS_COLUMN = 3u;
static const size_t ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS = 4u;
static const size_t ER_UI_LEDGER_DASHBOARD_COMPACT_SUMMARY_CARDS = 3u;
static const size_t ER_UI_LEDGER_ACCESS_MAX_COLUMNS = 2u;
static const float ER_UI_LEDGER_SURFACE_BODY_Y = 58.0f;
static const float ER_UI_LEDGER_FORM_CARD_H = 286.0f;
static const float ER_UI_LEDGER_NAV_ROW_H = 34.0f;
static const float ER_UI_LEDGER_FIELD_H = ER_UI_SHADCN_CONTROL_H;
static const float ER_UI_LEDGER_BUTTON_H = ER_UI_SHADCN_CONTROL_H;
static const float ER_UI_LEDGER_BAR_MIN_W = 22.0f;
static const float ER_UI_LEDGER_BAR_MAX_W = 40.0f;
static const float ER_UI_LEDGER_BAR_GAP = 12.0f;
static const float ER_UI_LEDGER_BAR_MAX_H = 104.0f;
static const float ER_UI_LEDGER_PROGRESS_H = 4.0f;
static const float ER_UI_LEDGER_TRANSACTION_H = 42.0f;
static const float ER_UI_LEDGER_QR_CELL = 7.0f;
static const float ER_UI_LEDGER_TEXT_ADVANCE = 7.0f;
static const float ER_UI_LEDGER_TEXT_CLIP_ASCENT = 20.0f;
static const float ER_UI_LEDGER_TEXT_CLIP_DESCENT = 6.0f;
static const float ER_UI_LEDGER_CARD_PAD = ER_UI_SHADCN_CARD_PAD_X;
static const float ER_UI_LEDGER_COMPACT_NAV_GAP = 8.0f;
static const float ER_UI_LEDGER_COMPACT_NAV_Y = 92.0f;
static const float ER_UI_LEDGER_DENSE_CARD_H = 180.0f;
static const float ER_UI_LEDGER_DENSE_FORM_H = 190.0f;
static const float ER_UI_LEDGER_DASHBOARD_ROW_MIN_H = 300.0f;
static const float ER_UI_LEDGER_DASHBOARD_CARD_H = 216.0f;
static const float ER_UI_LEDGER_DASHBOARD_FORM_H = 266.0f;
static const float ER_UI_LEDGER_DASHBOARD_TALL_H = 322.0f;
static const float ER_UI_LEDGER_SCROLL_THUMB_MIN_H = 32.0f;
static const size_t ER_UI_LEDGER_ACTIVITY_BAR_COUNT = 7u;
static const size_t ER_UI_LEDGER_STOCK_CHART_GUIDE_COUNT = 7u;
static const size_t ER_UI_LEDGER_STOCK_CHART_SEGMENT_COUNT = 6u;
static const size_t ER_UI_LEDGER_POWER_BAR_COUNT = 8u;
static const uint32_t ER_UI_LEDGER_ACTION_BASE = 0xED024000u;
static const uint32_t ER_UI_LEDGER_PAYOUT_SLIDER_ID = ER_UI_LEDGER_ACTION_BASE + 1u;
static const uint32_t ER_UI_LEDGER_INVEST_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 2u;
static const uint32_t ER_UI_LEDGER_TRANSFER_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 4u;
static const uint32_t ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 8u;
static const uint32_t ER_UI_LEDGER_DASHBOARD_SCROLL_ID = ER_UI_LEDGER_ACTION_BASE + 16u;
static const uint32_t ER_UI_LEDGER_CREATE_RELEASE_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 32u;
static const uint32_t ER_UI_LEDGER_PAYOUT_SETTINGS_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 64u;
static const uint32_t ER_UI_LEDGER_CATALOG_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 128u;
static const uint32_t ER_UI_LEDGER_GOAL_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 256u;
static const uint32_t ER_UI_LEDGER_VIEW_TRANSACTIONS_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 512u;
static const uint32_t ER_UI_LEDGER_TARGET_ROW_BASE_ID = ER_UI_LEDGER_ACTION_BASE + 1024u;
static const uint32_t ER_UI_LEDGER_TRANSACTION_ROW_BASE_ID = ER_UI_LEDGER_ACTION_BASE + 2048u;

typedef struct {
  er_ui_resolved_theme_t theme;
  er_ui_color4_t bg;
  er_ui_color4_t panel;
  er_ui_color4_t panel_alt;
  er_ui_color4_t field;
  er_ui_color4_t border;
  er_ui_color4_t ring;
  er_ui_color4_t text;
  er_ui_color4_t muted;
  er_ui_color4_t subtle;
  er_ui_color4_t button;
  er_ui_color4_t button_text;
  er_ui_color4_t success;
  er_ui_color4_t danger;
  er_ui_color4_t warning;
} er_ui_ledger_colors_t;

typedef struct {
  uint32_t id;
  const char* label;
  er_ui_icon_t icon;
} er_ui_ledger_nav_item_t;

typedef struct {
  const char* label;
  float value;
} er_ui_ledger_bar_t;

typedef struct {
  const char* title;
  const char* amount;
  const char* detail;
  float progress;
} er_ui_ledger_target_t;

typedef struct {
  const char* name;
  const char* kind;
  const char* date;
  const char* amount;
  er_ui_icon_t icon;
  bool positive;
} er_ui_ledger_transaction_t;

typedef struct {
  er_ui_bounds_t sidebar;
  er_ui_bounds_t content;
} er_ui_ledger_content_layout_t;

typedef struct {
  const char* label;
  const char* value;
  bool selectable;
} er_ui_ledger_field_row_t;

typedef struct {
  er_ui_vertical_flow_t columns[ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS_LIMIT];
} er_ui_ledger_dashboard_columns_t;

static er_ui_status_t er_ui_ledger_sidebar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id);

static const er_ui_ledger_nav_item_t ER_UI_LEDGER_NAV_ITEMS[] = {
  {ER_UI_LEDGER_APP_LEDGER_ID, "Dashboard", ER_UI_ICON_APP},
  {ER_UI_LEDGER_APP_PAYMENTS_ID, "Payments", ER_UI_ICON_WALLET},
  {ER_UI_LEDGER_APP_ACCESS_ID, "Access", ER_UI_ICON_LOCK}
};

static const er_ui_ledger_bar_t ER_UI_LEDGER_CONTRIBUTIONS[] = {
  {"Dec", 0.58f},
  {"Jan", 0.80f},
  {"Feb", 0.66f},
  {"Mar", 0.94f},
  {"Apr", 0.54f},
  {"May", 1.00f}
};

static const er_ui_ledger_target_t ER_UI_LEDGER_TARGETS[] = {
  {"RETIREMENT", "$420,000", "$273,000 secured", 0.65f},
  {"REAL ESTATE", "$85,000", "$27,200 secured", 0.32f}
};

static const er_ui_ledger_transaction_t ER_UI_LEDGER_TRANSACTIONS[] = {
  {"Blue Bottle Coffee", "Food & Drink", "Today, 10:24 AM", "-$6.50", ER_UI_ICON_WALLET, false},
  {"Whole Foods Market", "Groceries", "Yesterday", "-$142.30", ER_UI_ICON_STORAGE, false},
  {"Stripe Payout", "Income", "Oct 12", "+$4,200.00", ER_UI_ICON_DATABASE, true},
  {"Uber Technologies", "Transport", "Oct 11", "-$24.10", ER_UI_ICON_ROUTE, false},
  {"Netflix Subscription", "Entertainment", "Oct 10", "-$19.99", ER_UI_ICON_APP, false}
};

static const float ER_UI_LEDGER_ACTIVITY_VALUES[] = {0.34f, 0.48f, 0.28f, 0.58f, 0.38f, 0.44f, 0.68f};

//@optimizer-ignore-constant fixed QR preview module coordinates are deterministic design data, not executable arithmetic
static const uint8_t ER_UI_LEDGER_QR_DOTS[][2u] = {
  {0u, 0u}, {1u, 0u}, {2u, 0u}, {4u, 0u}, {5u, 0u}, {7u, 0u}, {8u, 0u}, {9u, 0u},
  {0u, 1u}, {2u, 1u}, {3u, 1u}, {5u, 1u}, {6u, 1u}, {9u, 1u},
  {0u, 2u}, {1u, 2u}, {2u, 2u}, {4u, 2u}, {7u, 2u}, {8u, 2u}, {9u, 2u},
  {1u, 3u}, {3u, 3u}, {4u, 3u}, {5u, 3u}, {8u, 3u},
  {0u, 4u}, {2u, 4u}, {5u, 4u}, {6u, 4u}, {7u, 4u}, {9u, 4u},
  {1u, 5u}, {2u, 5u}, {3u, 5u}, {6u, 5u}, {8u, 5u}, {9u, 5u},
  {0u, 6u}, {4u, 6u}, {5u, 6u}, {7u, 6u}, {9u, 6u},
  {0u, 7u}, {1u, 7u}, {3u, 7u}, {6u, 7u}, {7u, 7u}, {8u, 7u},
  {0u, 8u}, {2u, 8u}, {4u, 8u}, {5u, 8u}, {8u, 8u}, {9u, 8u},
  {0u, 9u}, {1u, 9u}, {2u, 9u}, {4u, 9u}, {6u, 9u}, {7u, 9u}, {9u, 9u}
};

static er_ui_ledger_colors_t er_ui_ledger_colors(er_ui_resolved_theme_t theme) {
  er_ui_ledger_colors_t colors;
  colors.theme = theme;
  colors.bg = theme.shadcn.colors.background;
  colors.panel = theme.shadcn.colors.card;
  colors.panel_alt = theme.shadcn.colors.secondary;
  colors.field = er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f);
  colors.border = theme.shadcn.colors.border;
  colors.ring = theme.shadcn.colors.ring;
  colors.text = theme.shadcn.colors.foreground;
  colors.muted = theme.shadcn.colors.muted_foreground;
  colors.subtle = er_ui_color_with_alpha(theme.shadcn.colors.foreground, 0.42f);
  colors.button = theme.shadcn.colors.primary;
  colors.button_text = theme.shadcn.colors.primary_foreground;
  colors.success = theme.colors.success;
  colors.danger = theme.colors.danger;
  colors.warning = theme.colors.warning;
  return colors;
}

static size_t er_ui_ledger_text_fit_count(const char* text, float max_w) {
  size_t count = 0u;
  const char* cursor = text;
  if (text == 0 || max_w <= 0.0f) return 0u;
  while (*cursor != '\0' && ((float)(count + 1u) * ER_UI_LEDGER_TEXT_ADVANCE) <= max_w) {
    count++;
    cursor++;
  }
  return count;
}

static er_ui_status_t er_ui_ledger_text_clipped(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  float max_w,
  er_ui_color4_t color) {
  bool pushed = false;
  size_t count = er_ui_ledger_text_fit_count(text, max_w);
  if (text == 0) return ER_UI_ERR_INVALID_ARGUMENT;
  if (count == 0u) return ER_UI_OK;
  er_ui_status_t status = er_ui_scene_push_clip(scene, er_ui_clip(x, y - ER_UI_LEDGER_TEXT_CLIP_ASCENT, max_w, ER_UI_LEDGER_TEXT_CLIP_ASCENT + ER_UI_LEDGER_TEXT_CLIP_DESCENT), &pushed);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text_n(scene, font, text, count, x, y, color);
  if (pushed) er_ui_scene_pop_clip(scene);
  return status;
}

static er_ui_status_t er_ui_ledger_text_right_clipped(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float right_x,
  float y,
  float max_w,
  er_ui_color4_t color) {
  size_t count = er_ui_ledger_text_fit_count(text, max_w);
  float text_w = (float)count * ER_UI_LEDGER_TEXT_ADVANCE;
  return er_ui_ledger_text_clipped(scene, font, text, right_x - text_w, y, max_w, color);
}

static er_ui_status_t er_ui_ledger_rect(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

static er_ui_status_t er_ui_ledger_border(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

static er_ui_bounds_t er_ui_ledger_card_content_rect(er_ui_bounds_t bounds) {
  return er_ui_bounds_inset_ltrb(bounds,
                                 ER_UI_SHADCN_CARD_PAD_X,
                                 ER_UI_SHADCN_CARD_PAD_Y,
                                 ER_UI_SHADCN_CARD_PAD_X,
                                 ER_UI_SHADCN_CARD_PAD_Y);
}

static er_ui_status_t er_ui_ledger_nav_row(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t row,
  er_ui_ledger_colors_t colors,
  const er_ui_ledger_nav_item_t* nav,
  uint32_t focused_id) {
  if (!scene || !font || !nav || !er_ui_bounds_valid(row)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = nav->id == focused_id ? colors.field : er_ui_color_with_alpha(colors.field, 0.0f);
  er_ui_color4_t color = nav->id == focused_id ? colors.text : colors.muted;
  er_ui_painter_t painter = er_ui_painter(scene);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_WORKSPACE_TAB, nav->id, row.x, row.y, row.w, row.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, row, ER_UI_SHADCN_RADIUS_MD, fill);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_icon(&painter, er_ui_bounds(row.x + 10.0f, row.y + 8.0f, 16.0f, 16.0f),
                              nav->icon, color);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, nav->label, row.x + 34.0f, row.y + 22.0f, row.w - 42.0f, color);
}

static er_ui_status_t er_ui_ledger_card(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_ledger_colors_t colors) {
  return er_ui_component_card_emit(scene, bounds, colors.theme);
}

static er_ui_status_t er_ui_ledger_card_with_header(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* title,
  const char* subtitle) {
  er_ui_status_t status = er_ui_ledger_card(scene, bounds, colors);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  er_ui_bounds_t header = er_ui_bounds(content.x, bounds.y + 14.0f, content.w, subtitle ? 54.0f : 38.0f);
  return er_ui_component_panel_header_emit(scene, font, header, colors.theme, title, subtitle ? subtitle : "", 0, 0u);
}

static er_ui_status_t er_ui_ledger_subtile(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  const char* value) {
  er_ui_status_t status = er_ui_ledger_rect(scene, bounds, ER_UI_SHADCN_RADIUS_MD, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, label, bounds.x + 12.0f, bounds.y + 22.0f, bounds.w - 24.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, value, bounds.x + 12.0f, bounds.y + 46.0f, bounds.w - 24.0f, colors.text);
}

static er_ui_ledger_content_layout_t er_ui_ledger_content_layout(er_ui_bounds_t bounds) {
  er_ui_ledger_content_layout_t layout;
  er_ui_responsive_sidecar_t sidecar = er_ui_responsive_sidecar(
    bounds,
    ER_UI_LEDGER_MIN_SIDE_W,
    ER_UI_LEDGER_SIDE_W,
    ER_UI_LEDGER_MIN_CARD_W,
    ER_UI_LEDGER_MARGIN,
    ER_UI_LEDGER_STACKED_SIDE_H);
  layout.sidebar = sidecar.side;
  layout.content = sidecar.main;
  return layout;
}

static er_ui_status_t er_ui_ledger_begin_surface(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id,
  const char* title,
  er_ui_ledger_content_layout_t* out_layout) {
  er_ui_ledger_content_layout_t layout;
  er_ui_status_t status;
  if (out_layout == 0) return ER_UI_ERR_INVALID_ARGUMENT;
  layout = er_ui_ledger_content_layout(bounds);
  if (!er_ui_bounds_valid(layout.sidebar) || !er_ui_bounds_valid(layout.content)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_ledger_sidebar(scene, font, layout.sidebar, colors, focused_id);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, title, layout.content.x, layout.content.y + 40.0f, layout.content.w, colors.text);
  if (status != ER_UI_OK) return status;
  *out_layout = layout;
  return ER_UI_OK;
}

static er_ui_bounds_t er_ui_ledger_surface_body(er_ui_ledger_content_layout_t layout) {
  return er_ui_bounds(
    layout.content.x,
    layout.content.y + ER_UI_LEDGER_SURFACE_BODY_Y,
    layout.content.w,
    er_ui_float_max(layout.content.h - ER_UI_LEDGER_SURFACE_BODY_Y - ER_UI_LEDGER_MARGIN, 1.0f));
}

static er_ui_status_t er_ui_ledger_icon(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_icon_t icon,
  er_ui_color4_t color) {
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, bounds, icon, color);
}

static er_ui_status_t er_ui_ledger_button(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  uint32_t id) {
  return er_ui_component_button_emit(
    scene,
    font,
    bounds,
    colors.theme,
    label,
    id,
    ER_UI_COMPONENT_BUTTON_DEFAULT,
    ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT,
    true);
}

static er_ui_status_t er_ui_ledger_field(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  const char* value,
  bool selectable) {
  er_ui_bounds_t component_bounds = er_ui_bounds(bounds.x, bounds.y - 18.0f, bounds.w, bounds.h + 18.0f);
  if (selectable) {
    return er_ui_component_select_static_emit(scene, font, component_bounds, colors.theme, label, value, false);
  }
  return er_ui_component_field_static_emit(scene, font, component_bounds, colors.theme, label, value, false);
}

static er_ui_status_t er_ui_ledger_field_rows(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const er_ui_ledger_field_row_t* rows,
  size_t row_count,
  float first_y,
  float row_gap) {
  er_ui_status_t status = ER_UI_OK;
  if (rows == 0 && row_count != 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (row_count == 0u) return ER_UI_OK;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  const er_ui_ledger_field_row_t* row = rows;
  const er_ui_ledger_field_row_t* end = rows + row_count;
  float y = bounds.y + first_y;
  while (row < end) {
    status = er_ui_ledger_field(scene, font,
                                er_ui_bounds(content.x, y, content.w, ER_UI_LEDGER_FIELD_H),
                                colors, row->label, row->value, row->selectable);
    if (status != ER_UI_OK) return status;
    y += row_gap;
    row++;
  }
  return status;
}

static er_ui_status_t er_ui_ledger_progress(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  float value) {
  return er_ui_component_progress_emit(scene, bounds, colors.theme, value);
}

static er_ui_status_t er_ui_ledger_slider(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  float value) {
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SLIDER, ER_UI_LEDGER_PAYOUT_SLIDER_ID, bounds.x, bounds.y - 10.0f, bounds.w, 24.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_progress(scene, bounds, colors, value);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t thumb = er_ui_bounds(bounds.x + bounds.w * value - 8.0f, bounds.y - 7.0f, 16.0f, 16.0f);
  status = er_ui_ledger_rect(scene, thumb, 8.0f, colors.theme.shadcn.colors.foreground);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_border(scene, thumb, 8.0f, colors.theme.shadcn.colors.primary);
}

static er_ui_status_t er_ui_ledger_bottom_button(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  uint32_t id,
  float bottom_inset) {
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(content.x, bounds.y + bounds.h - bottom_inset, content.w, ER_UI_LEDGER_BUTTON_H),
                             colors, label, id);
}

static er_ui_status_t er_ui_ledger_sidebar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_status_t status;
  float x = bounds.x + 14.0f;
  float y = bounds.y + 24.0f;
  bool compact = bounds.h <= ER_UI_LEDGER_STACKED_SIDE_H;

  status = er_ui_ledger_rect(scene, bounds, 0.0f, colors.panel);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "EdgeRun Ledger", x, y, bounds.w - 28.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "local settlement console", x, y + 22.0f, bounds.w - 28.0f, colors.muted);
  if (status != ER_UI_OK) return status;

  y += 52.0f;
  //@optimizer-ignore nav renderer intentionally emits one hit, icon, and label per fixed surface
  const er_ui_ledger_nav_item_t* nav = ER_UI_LEDGER_NAV_ITEMS;
  const er_ui_ledger_nav_item_t* nav_end = ER_UI_LEDGER_NAV_ITEMS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_NAV_ITEMS);
  if (compact) {
    float nav_w = (bounds.w - 28.0f - ER_UI_LEDGER_COMPACT_NAV_GAP * (float)(ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_NAV_ITEMS) - 1u)) /
                  (float)ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_NAV_ITEMS);
    size_t nav_index = 0u;
    while (nav < nav_end) {
      er_ui_bounds_t row = er_ui_bounds(x + (nav_w + ER_UI_LEDGER_COMPACT_NAV_GAP) * (float)nav_index,
                                        bounds.y + ER_UI_LEDGER_COMPACT_NAV_Y,
                                        nav_w,
                                        ER_UI_LEDGER_NAV_ROW_H);
      status = er_ui_ledger_nav_row(scene, font, row, colors, nav, focused_id);
      if (status != ER_UI_OK) return status;
      nav++;
      nav_index++;
    }
    return ER_UI_OK;
  }

  while (nav < nav_end) {
    er_ui_bounds_t row = er_ui_bounds(x - 6.0f, y,
                                      bounds.w - 16.0f, ER_UI_LEDGER_NAV_ROW_H);
    //@optimizer-ignore fixed sidebar navigation renders one deterministic item per surface row
    status = er_ui_ledger_nav_row(scene, font, row, colors, nav, focused_id);
    if (status != ER_UI_OK) return status;
    y += ER_UI_LEDGER_NAV_ROW_H + 4.0f;
    nav++;
  }

  er_ui_bounds_t qr_card = er_ui_bounds(bounds.x + 14.0f, bounds.y + bounds.h - 170.0f, bounds.w - 28.0f, 144.0f);
  status = er_ui_ledger_card(scene, qr_card, colors);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(qr_card.x + 42.0f, qr_card.y + 14.0f, 84.0f, 84.0f), 8.0f, colors.button);
  if (status != ER_UI_OK) return status;
  //@optimizer-ignore QR preview intentionally emits one deterministic rectangle per dark module
  const uint8_t(*dot)[2u] = ER_UI_LEDGER_QR_DOTS;
  const uint8_t(*dot_end)[2u] = ER_UI_LEDGER_QR_DOTS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_QR_DOTS);
  while (dot < dot_end) {
    status = er_ui_ledger_rect(scene,
                               er_ui_bounds(qr_card.x + 46.0f + (float)(*dot)[0u] * ER_UI_LEDGER_QR_CELL,
                                            qr_card.y + 24.0f + (float)(*dot)[1u] * ER_UI_LEDGER_QR_CELL,
                                            ER_UI_LEDGER_QR_CELL - 1.0f, ER_UI_LEDGER_QR_CELL - 1.0f),
                               0.0f, colors.bg);
    if (status != ER_UI_OK) return status;
    dot++;
  }
  status = er_ui_ledger_text_clipped(scene, font, "Pair mobile device", qr_card.x + 14.0f, qr_card.y + 114.0f, qr_card.w - 28.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, "scan local access key", qr_card.x + 14.0f, qr_card.y + 134.0f, qr_card.w - 28.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_contribution_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Contribution History",
                                                        "Last 6 months of activity");
  if (status != ER_UI_OK) return status;
  if (bounds.h < ER_UI_LEDGER_DENSE_CARD_H || bounds.w < ER_UI_LEDGER_NARROW_CARD_W) {
    status = er_ui_ledger_progress(scene, er_ui_bounds(bounds.x + 16.0f, bounds.y + 76.0f, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H), colors, 0.76f);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_clipped(scene, font, "May 25, 2024", bounds.x + 16.0f, bounds.y + 108.0f, bounds.w * 0.48f, colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_ledger_text_right_clipped(scene, font, "$1,000 scheduled", bounds.x + bounds.w - 16.0f, bounds.y + 108.0f, bounds.w - 32.0f, colors.muted);
  }
  float bars_w = bounds.w - ER_UI_LEDGER_CARD_PAD * 2.0f;
  float bar_w = (bars_w - ER_UI_LEDGER_BAR_GAP * (float)(ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS) - 1u)) /
                (float)ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS);
  bar_w = er_ui_float_clamp(bar_w, ER_UI_LEDGER_BAR_MIN_W, ER_UI_LEDGER_BAR_MAX_W);
  float bars_x = bounds.x + (bounds.w - (bar_w * (float)ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS) +
                                          ER_UI_LEDGER_BAR_GAP * (float)(ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS) - 1u))) *
                             0.5f;
  float bars_base = bounds.y + 152.0f;
  const er_ui_ledger_bar_t* bar = ER_UI_LEDGER_CONTRIBUTIONS;
  const er_ui_ledger_bar_t* bar_end = ER_UI_LEDGER_CONTRIBUTIONS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS);
  float bar_x = bars_x;
  while (bar < bar_end) {
    float h = ER_UI_LEDGER_BAR_MAX_H * bar->value;
    float x = bar_x;
    status = er_ui_ledger_rect(scene, er_ui_bounds(x, bars_base - h, bar_w, h), 5.0f, colors.subtle);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_clipped(scene, font, bar->label, x + 2.0f, bounds.y + 176.0f, bar_w, colors.subtle);
    if (status != ER_UI_OK) return status;
    bar_x += bar_w + ER_UI_LEDGER_BAR_GAP;
    bar++;
  }
  er_ui_bounds_t upcoming = er_ui_bounds(bounds.x + ER_UI_LEDGER_CARD_PAD, bounds.y + bounds.h - 96.0f, bounds.w * 0.5f - 22.0f, 78.0f);
  er_ui_bounds_t plan = er_ui_bounds(upcoming.x + upcoming.w + ER_UI_LEDGER_GAP, upcoming.y, upcoming.w, upcoming.h);
  status = er_ui_ledger_subtile(scene, font, upcoming, colors, "UPCOMING", "May 25, 2024");
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_subtile(scene, font, plan, colors, "AUTO-SAVE PLAN", "Accelerated");
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, "$1,000 scheduled", plan.x + 12.0f, plan.y + 64.0f, plan.w - 24.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_payout_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Currency", "USD - United States Dollar", true}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Payout Threshold",
                                                        "Minimum balance required before payout");
  if (status != ER_UI_OK) return status;
  bool dense = bounds.h < ER_UI_LEDGER_DENSE_FORM_H || bounds.w < ER_UI_LEDGER_NARROW_CARD_W;
  bool compact = bounds.h < 260.0f || bounds.w < ER_UI_LEDGER_NARROW_CARD_W;
  if (dense) {
    status = er_ui_ledger_text_clipped(scene, font, "Minimum Payout Amount", bounds.x + 16.0f, bounds.y + 74.0f, bounds.w * 0.52f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right_clipped(scene, font, "$2500.00", bounds.x + bounds.w - 16.0f, bounds.y + 74.0f, bounds.w * 0.42f, colors.text);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t slider = er_ui_bounds(bounds.x + 16.0f, bounds.y + 92.0f, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H);
    status = er_ui_ledger_slider(scene, slider, colors, 0.25f);
    if (status != ER_UI_OK) return status;
    return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Save Threshold", ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID, 42.0f);
  }
  float field_y = compact ? 56.0f : 84.0f;
  float amount_y = compact ? 108.0f : 158.0f;
  float slider_y = compact ? 126.0f : 176.0f;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), field_y, 72.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Minimum Payout Amount", bounds.x + 16.0f, bounds.y + amount_y, bounds.w * 0.52f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right_clipped(scene, font, "$2500.00", bounds.x + bounds.w - 16.0f, bounds.y + amount_y, bounds.w * 0.42f, colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t slider = er_ui_bounds(bounds.x + 16.0f, bounds.y + slider_y, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H);
  status = er_ui_ledger_slider(scene, slider, colors, 0.25f);
  if (status != ER_UI_OK) return status;
  if (!compact) {
    status = er_ui_ledger_text_clipped(scene, font, "$50 (MIN)", slider.x, slider.y + 24.0f, slider.w * 0.45f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right_clipped(scene, font, "$10,000 (MAX)", slider.x + slider.w, slider.y + 24.0f, slider.w * 0.45f, colors.muted);
    if (status != ER_UI_OK) return status;
  }
  if (bounds.h >= 360.0f) {
    er_ui_bounds_t notes = er_ui_bounds(bounds.x + 16.0f, bounds.y + 224.0f, bounds.w - 32.0f, bounds.h - 286.0f);
    status = er_ui_ledger_text_clipped(scene, font, "Notes", notes.x, notes.y - 8.0f, notes.w, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, notes, ER_UI_SHADCN_RADIUS_MD, colors.field);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_border(scene, notes, ER_UI_SHADCN_RADIUS_MD, colors.theme.shadcn.colors.input);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_clipped(scene, font, "Add any notes for this payout configuration...", notes.x + 10.0f, notes.y + 24.0f, notes.w - 20.0f, colors.muted);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Save Threshold", ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID, 48.0f);
}

static er_ui_status_t er_ui_ledger_targets_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card(scene, bounds, colors);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  const char* action = bounds.h >= ER_UI_LEDGER_DENSE_CARD_H && bounds.w >= ER_UI_LEDGER_NARROW_CARD_W ? "New Goal" : 0;
  status = er_ui_component_panel_header_emit(scene, font, er_ui_bounds(content.x, bounds.y + 14.0f, content.w, 54.0f),
                                             colors.theme, "Savings Targets", "Active milestones for 2024", action,
                                             ER_UI_LEDGER_GOAL_BUTTON_ID);
  if (status != ER_UI_OK) return status;
  const er_ui_ledger_target_t* row = ER_UI_LEDGER_TARGETS;
  const er_ui_ledger_target_t* end = ER_UI_LEDGER_TARGETS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TARGETS);
  float target_y = bounds.y + (bounds.h < ER_UI_LEDGER_DENSE_CARD_H ? 62.0f : 70.0f);
  uint32_t target_id = ER_UI_LEDGER_TARGET_ROW_BASE_ID;
  while (row < end) {
    if (target_y + 96.0f > bounds.y + bounds.h - 12.0f) break;
    er_ui_bounds_t target = er_ui_bounds(bounds.x + 16.0f, target_y, bounds.w - 32.0f, 96.0f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, target_id, target.x, target.y, target.w, target.h));
    if (status != ER_UI_OK) return status;
    status = er_ui_component_metric_card_emit(scene, font, target, colors.theme, row->title, row->amount, row->detail, true, row->progress, colors.success);
    if (status != ER_UI_OK) return status;
    target_y += 112.0f;
    row++;
    target_id++;
  }
  if (bounds.h < 312.0f) return ER_UI_OK;
  status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 54.0f, bounds.w, 1.0f), 0.0f, colors.border);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, "You have not met your targets for this year.", bounds.x + 16.0f, bounds.y + bounds.h - 24.0f, bounds.w - 32.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_invest_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Amount to Invest", "$ 1,000.00", false},
    {"Order Type", "Market Order", true}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Buy Investment", 0);
  if (status != ER_UI_OK) return status;
  bool dense = bounds.h < ER_UI_LEDGER_DENSE_FORM_H || bounds.w < ER_UI_LEDGER_NARROW_CARD_W;
  bool compact = bounds.h < 260.0f || bounds.w < ER_UI_LEDGER_NARROW_CARD_W;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), compact ? 54.0f : 76.0f, compact ? 50.0f : 72.0f);
  if (status != ER_UI_OK) return status;
  if (dense) {
    return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID, 42.0f);
  }
  if (compact) {
    return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID, 48.0f);
  }
  status = er_ui_ledger_text_clipped(scene, font, "Market orders execute at the current price.", bounds.x + 16.0f, bounds.y + 162.0f, bounds.w - 32.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Estimated Shares", bounds.x + 16.0f, bounds.y + 196.0f, bounds.w * 0.52f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right_clipped(scene, font, "1.95", bounds.x + bounds.w - 16.0f, bounds.y + 196.0f, bounds.w * 0.35f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Buying Power", bounds.x + 16.0f, bounds.y + 220.0f, bounds.w * 0.52f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right_clipped(scene, font, "$12,450.00", bounds.x + bounds.w - 16.0f, bounds.y + 220.0f, bounds.w * 0.45f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 64.0f, bounds.w, 1.0f), 0.0f, colors.border);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID, 48.0f);
}

static er_ui_status_t er_ui_ledger_transactions_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card(scene, bounds, colors);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  status = er_ui_component_panel_header_emit(scene, font, er_ui_bounds(content.x, bounds.y + 14.0f, content.w, 54.0f),
                                             colors.theme, "Recent Transactions", "Your latest account activity.",
                                             "View All", ER_UI_LEDGER_VIEW_TRANSACTIONS_BUTTON_ID);
  if (status != ER_UI_OK) return status;
  float y = bounds.y + 76.0f;
  const er_ui_ledger_transaction_t* row = ER_UI_LEDGER_TRANSACTIONS;
  const er_ui_ledger_transaction_t* end = ER_UI_LEDGER_TRANSACTIONS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TRANSACTIONS);
  uint32_t transaction_id = ER_UI_LEDGER_TRANSACTION_ROW_BASE_ID;
  while (row < end) {
    if (y + ER_UI_LEDGER_TRANSACTION_H > bounds.y + bounds.h - 12.0f) break;
    status = er_ui_component_transaction_row_emit(scene, font,
                                                  er_ui_bounds(content.x, y, content.w, ER_UI_LEDGER_TRANSACTION_H),
                                                  colors.theme,
                                                  row->name,
                                                  row->kind,
                                                  row->date,
                                                  row->amount,
                                                  row->positive,
                                                  transaction_id);
    if (status != ER_UI_OK) return status;
    y += ER_UI_LEDGER_TRANSACTION_H;
    row++;
    transaction_id++;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_ledger_access_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Email Address", "artist@studio.inc", false},
    {"Password", "************", false}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Account Access", 0);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 76.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Update Security", ER_UI_LEDGER_TRANSFER_BUTTON_ID, 48.0f);
}

static er_ui_status_t er_ui_ledger_account_summary_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Card Balance", "Available account buffer");
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "US$12.94", bounds.x + 16.0f, bounds.y + 86.0f, bounds.w - 32.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "US$11,337.06 available", bounds.x + 16.0f, bounds.y + 112.0f, bounds.w - 32.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t activity = er_ui_bounds(bounds.x + 16.0f, bounds.y + 148.0f, bounds.w - 32.0f, 92.0f);
  status = er_ui_ledger_rect(scene, activity, ER_UI_SHADCN_RADIUS_MD, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Yearly Activity", activity.x + 12.0f, activity.y + 24.0f, activity.w - 24.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  float bar_gap = 8.0f;
  float bar_w = (activity.w - 24.0f - bar_gap * (float)(ER_UI_LEDGER_ACTIVITY_BAR_COUNT - 1u)) / (float)ER_UI_LEDGER_ACTIVITY_BAR_COUNT;
  if (bar_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < ER_UI_LEDGER_ACTIVITY_BAR_COUNT; ++i) {
    float bar_h = 34.0f * ER_UI_LEDGER_ACTIVITY_VALUES[i];
    float x = activity.x + 12.0f + (bar_w + bar_gap) * (float)i;
    status = er_ui_ledger_rect(scene, er_ui_bounds(x, activity.y + 70.0f - bar_h, bar_w, bar_h), 3.0f, colors.subtle);
    if (status != ER_UI_OK) return status;
  }
  if (bounds.h < 320.0f) return ER_UI_OK;
  er_ui_bounds_t transfer = er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 94.0f, bounds.w - 32.0f, 76.0f);
  status = er_ui_ledger_rect(scene, transfer, ER_UI_SHADCN_RADIUS_MD, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Transfer Funds", transfer.x + 12.0f, transfer.y + 24.0f, transfer.w - 24.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_clipped(scene, font, "Move money between accounts.", transfer.x + 12.0f, transfer.y + 48.0f, transfer.w - 24.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_release_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card(scene, bounds, colors);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  er_ui_bounds_t icon = er_ui_bounds(content.x, content.y + 18.0f, 34.0f, 34.0f);
  status = er_ui_ledger_rect(scene, icon, ER_UI_SHADCN_RADIUS_MD, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_icon(scene, er_ui_bounds(icon.x + 9.0f, icon.y + 9.0f, 16.0f, 16.0f), ER_UI_ICON_MESSAGE_PLUS, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Distribute Track", content.x, content.y + 86.0f, content.w, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Upload your first master and start reaching listeners.", content.x, content.y + 112.0f, content.w, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(content.x, bounds.y + bounds.h - 50.0f, er_ui_float_min(content.w, 144.0f), ER_UI_LEDGER_BUTTON_H),
                             colors, "Create Release", ER_UI_LEDGER_CREATE_RELEASE_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_claimable_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Claimable Balance", 0);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  status = er_ui_ledger_text_clipped(scene, font, "$0.00", content.x, content.y + 70.0f, content.w, colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t pill = er_ui_bounds(content.x, content.y + 88.0f, 112.0f, 24.0f);
  status = er_ui_ledger_rect(scene, pill, 12.0f, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(pill.x + 10.0f, pill.y + 9.0f, 6.0f, 6.0f), 3.0f, colors.warning);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Pending Setup", pill.x + 22.0f, pill.y + 16.0f, pill.w - 28.0f, colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t summary = er_ui_bounds(content.x, content.y + 124.0f, content.w, 76.0f);
  status = er_ui_ledger_rect(scene, summary, ER_UI_SHADCN_RADIUS_MD, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Net Royalties", summary.x + 12.0f, summary.y + 24.0f, summary.w * 0.52f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right_clipped(scene, font, "$0.00", summary.x + summary.w - 12.0f, summary.y + 24.0f, summary.w * 0.32f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Ready to Claim", summary.x + 12.0f, summary.y + 54.0f, summary.w * 0.52f, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text_right_clipped(scene, font, "$0.00 USD", summary.x + summary.w - 12.0f, summary.y + 54.0f, summary.w * 0.38f, colors.text);
}

static er_ui_status_t er_ui_ledger_payout_preferences_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Payout Preferences", "Receiving Method");
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  status = er_ui_ledger_field(scene, font, er_ui_bounds(content.x, content.y + 76.0f, content.w, ER_UI_LEDGER_FIELD_H),
                              colors, "Account Holder Name", "Synthetic Horizons Music LLC", false);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t bank = er_ui_bounds(content.x, content.y + 134.0f, content.w * 0.5f - ER_UI_LEDGER_GAP * 0.5f, 54.0f);
  er_ui_bounds_t paypal = er_ui_bounds(bank.x + bank.w + ER_UI_LEDGER_GAP, bank.y, bank.w, bank.h);
  status = er_ui_ledger_rect(scene, bank, ER_UI_SHADCN_RADIUS_MD, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_border(scene, bank, ER_UI_SHADCN_RADIUS_MD, colors.theme.shadcn.colors.input);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(bank.x + 10.0f, bank.y + 17.0f, 10.0f, 10.0f), 5.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Bank Transfer", bank.x + 28.0f, bank.y + 24.0f, bank.w - 36.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "SWIFT / IBAN", bank.x + 28.0f, bank.y + 44.0f, bank.w - 36.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, paypal, ER_UI_SHADCN_RADIUS_MD, colors.panel);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_border(scene, paypal, ER_UI_SHADCN_RADIUS_MD, colors.border);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "PayPal", paypal.x + 14.0f, paypal.y + 24.0f, paypal.w - 28.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field(scene, font, er_ui_bounds(content.x, content.y + 222.0f, content.w, ER_UI_LEDGER_FIELD_H),
                              colors, "IBAN / Account Number", "DE89 3704 0044 ...", false);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(content.x, bounds.y + bounds.h - 50.0f, content.w, ER_UI_LEDGER_BUTTON_H),
                             colors, "Save Payout Settings", ER_UI_LEDGER_PAYOUT_SETTINGS_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_stock_performance_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Stock Performance", "6-month price history.");
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  status = er_ui_ledger_field(scene, font, er_ui_bounds(content.x, content.y + 72.0f, content.w, ER_UI_LEDGER_FIELD_H), colors, "Ticker", "VOO", true);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t chart = er_ui_bounds(content.x, content.y + 126.0f, content.w, bounds.h - 158.0f);
  status = er_ui_ledger_rect(scene, chart, ER_UI_SHADCN_RADIUS_MD, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  float guide_step = (chart.h - 36.0f) / (float)ER_UI_LEDGER_STOCK_CHART_SEGMENT_COUNT;
  for (size_t i = 0u; i < ER_UI_LEDGER_STOCK_CHART_GUIDE_COUNT; ++i) {
    float y = chart.y + 18.0f + (float)i * guide_step;
    status = er_ui_ledger_rect(scene, er_ui_bounds(chart.x + 12.0f, y, chart.w - 24.0f, 1.0f), 0.0f, er_ui_color_with_alpha(colors.border, 0.45f));
    if (status != ER_UI_OK) return status;
  }
  float step = chart.w / (float)ER_UI_LEDGER_STOCK_CHART_SEGMENT_COUNT;
  for (size_t i = 0u; i < ER_UI_LEDGER_STOCK_CHART_SEGMENT_COUNT; ++i) {
    float left_h = 38.0f + ER_UI_LEDGER_ACTIVITY_VALUES[i] * 42.0f;
    float right_h = 38.0f + ER_UI_LEDGER_ACTIVITY_VALUES[i + 1u] * 42.0f;
    float x = chart.x + step * (float)i;
    float w = step + 1.0f;
    float y = chart.y + chart.h - er_ui_float_max(left_h, right_h) - 10.0f;
    float h = er_ui_float_max(left_h, right_h);
    status = er_ui_ledger_rect(scene, er_ui_bounds(x, y, w, h), 0.0f, er_ui_color_with_alpha(colors.subtle, 0.46f));
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_ledger_power_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Power Usage", "Whole Home");
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  er_ui_bounds_t chart = er_ui_bounds(content.x, content.y + 72.0f, content.w, 112.0f);
  float bar_gap = 10.0f;
  float bar_w = (chart.w - bar_gap * (float)(ER_UI_LEDGER_POWER_BAR_COUNT - 1u)) / (float)ER_UI_LEDGER_POWER_BAR_COUNT;
  for (size_t i = 0u; i < ER_UI_LEDGER_POWER_BAR_COUNT; ++i) {
    float value = i < ER_UI_LEDGER_ACTIVITY_BAR_COUNT ? ER_UI_LEDGER_ACTIVITY_VALUES[i] : 0.58f;
    float h = 88.0f * value;
    status = er_ui_ledger_rect(scene, er_ui_bounds(chart.x + (bar_w + bar_gap) * (float)i, chart.y + chart.h - h, bar_w, h), 4.0f, colors.subtle);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_ledger_text_clipped(scene, font, "Currently Using", content.x, content.y + 212.0f, content.w * 0.48f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "3.4 kW", content.x, content.y + 236.0f, content.w * 0.48f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right_clipped(scene, font, "85%", content.x + content.w, content.y + 236.0f, content.w * 0.32f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_progress(scene, er_ui_bounds(content.x, bounds.y + bounds.h - 30.0f, content.w, ER_UI_LEDGER_PROGRESS_H), colors, 0.85f);
}

static er_ui_status_t er_ui_ledger_catalog_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card(scene, bounds, colors);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  er_ui_bounds_t icon = er_ui_bounds(bounds.x + bounds.w * 0.5f - 17.0f, content.y + 20.0f, 34.0f, 34.0f);
  status = er_ui_ledger_rect(scene, icon, ER_UI_SHADCN_RADIUS_MD, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_icon(scene, er_ui_bounds(icon.x + 9.0f, icon.y + 9.0f, 16.0f, 16.0f), ER_UI_ICON_STORAGE, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Explore Catalog", content.x, content.y + 94.0f, content.w, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Check your ISRC codes, metadata, and assets before going live.", content.x, content.y + 122.0f, content.w, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(bounds.x + bounds.w * 0.5f - 60.0f, bounds.y + bounds.h - 54.0f, 120.0f, ER_UI_LEDGER_BUTTON_H),
                             colors, "View Catalog", ER_UI_LEDGER_CATALOG_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_milestone_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Set a new milestone", "Define your financial target and pace.");
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_ledger_card_content_rect(bounds);
  status = er_ui_ledger_field(scene, font, er_ui_bounds(content.x, content.y + 78.0f, content.w, ER_UI_LEDGER_FIELD_H),
                              colors, "Goal Name", "e.g. Home Downpayment", false);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t amount = er_ui_bounds(content.x, content.y + 136.0f, content.w * 0.5f - ER_UI_LEDGER_GAP * 0.5f, ER_UI_LEDGER_FIELD_H);
  er_ui_bounds_t date = er_ui_bounds(amount.x + amount.w + ER_UI_LEDGER_GAP, amount.y, amount.w, amount.h);
  status = er_ui_ledger_field(scene, font, amount, colors, "Target Amount", "$15,000", false);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field(scene, font, date, colors, "Target Date", "Dec 2025", false);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_button(scene, font, er_ui_bounds(content.x, bounds.y + bounds.h - 88.0f, content.w, ER_UI_LEDGER_BUTTON_H),
                               colors, "Create Goal", ER_UI_LEDGER_GOAL_BUTTON_ID);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_rect(scene, er_ui_bounds(content.x, bounds.y + bounds.h - 42.0f, content.w, ER_UI_LEDGER_BUTTON_H), ER_UI_SHADCN_RADIUS_MD, colors.field);
}

static er_ui_status_t er_ui_ledger_transfer_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Amount", "$ 1,200.00", false},
    {"From", "Main Checking", true}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Transfer Funds",
                                                        "Move money between accounts");
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 88.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Schedule Transfer", ER_UI_LEDGER_TRANSFER_BUTTON_ID, 48.0f);
}

static er_ui_status_t er_ui_ledger_scrollbar(
  er_ui_scene_t* scene,
  er_ui_ledger_colors_t colors,
  er_ui_scroll_viewport_t viewport) {
  if (!viewport.scrollable) return ER_UI_OK;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLLBAR, ER_UI_LEDGER_DASHBOARD_SCROLL_ID,
                                                               viewport.hit.x, viewport.hit.y, viewport.hit.w, viewport.hit.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, viewport.track, ER_UI_SCROLLBAR_TRACK_W * 0.5f, er_ui_color_with_alpha(colors.border, 0.5f));
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_rect(scene, viewport.thumb, ER_UI_SCROLLBAR_TRACK_W * 0.5f, colors.muted);
}

static er_ui_status_t er_ui_ledger_dashboard(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id,
  float scroll) {
  er_ui_ledger_content_layout_t layout = er_ui_ledger_content_layout(bounds);
  if (!er_ui_bounds_valid(layout.sidebar) || !er_ui_bounds_valid(layout.content)) return ER_UI_ERR_INVALID_ARGUMENT;
  float top_y = layout.content.y + ER_UI_LEDGER_MARGIN;
  float grid_y = top_y + 44.0f;
  float available_h = er_ui_float_max(layout.content.y + layout.content.h - grid_y - ER_UI_LEDGER_MARGIN, 1.0f);
  er_ui_responsive_grid_t grid = er_ui_responsive_grid(
    er_ui_bounds(layout.content.x, grid_y, layout.content.w, available_h),
    ER_UI_LEDGER_DASHBOARD_MIN_CARD_W,
    ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS,
    ER_UI_LEDGER_GAP,
    ER_UI_LEDGER_GAP);

  er_ui_status_t status = er_ui_ledger_sidebar(scene, font, layout.sidebar, colors, focused_id);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "Dashboard", layout.content.x, top_y + 12.0f, layout.content.w, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_clipped(scene, font, "settlement, royalties, and device-local accounting", layout.content.x, top_y + 34.0f, layout.content.w, colors.muted);
  if (status != ER_UI_OK) return status;

  if (grid.columns == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (grid.columns >= ER_UI_LEDGER_DASHBOARD_MASONRY_COLUMNS) {
    float content_h = grid.columns >= ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS ?
                        ER_UI_LEDGER_DASHBOARD_FORM_H * 4.0f + ER_UI_LEDGER_GAP * 3.0f :
                        ER_UI_LEDGER_DASHBOARD_FORM_H * 6.0f + ER_UI_LEDGER_DASHBOARD_CARD_H * 2.0f +
                          ER_UI_LEDGER_GAP * 7.0f;
    er_ui_scroll_viewport_t viewport = er_ui_scroll_viewport(grid.bounds, content_h, scroll, ER_UI_LEDGER_SCROLL_THUMB_MIN_H);
    er_ui_status_t hit_status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLL_AREA, ER_UI_LEDGER_DASHBOARD_SCROLL_ID,
                                                                      viewport.viewport.x, viewport.viewport.y,
                                                                      viewport.viewport.w, viewport.viewport.h));
    if (hit_status != ER_UI_OK) return hit_status;
    bool pushed = false;
    status = er_ui_scene_push_clip(scene, er_ui_clip(viewport.viewport.x, viewport.viewport.y, viewport.viewport.w, viewport.viewport.h), &pushed);
    if (status != ER_UI_OK) return status;

    er_ui_ledger_dashboard_columns_t masonry = {0};
    size_t details_column = grid.columns >= ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS ? ER_UI_LEDGER_DASHBOARD_DETAILS_COLUMN : 2u;
    for (size_t i = 0u; i < grid.columns; ++i) {
      er_ui_bounds_t column = er_ui_bounds(
        viewport.content.x + (grid.column_w + grid.gap_x) * (float)i,
        viewport.content.y,
        grid.column_w,
        content_h);
      masonry.columns[i] = er_ui_vertical_flow(column, ER_UI_LEDGER_GAP);
    }

    status = er_ui_ledger_contribution_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[0u], ER_UI_LEDGER_DASHBOARD_CARD_H), colors);
    if (status == ER_UI_OK) {
      status = er_ui_ledger_transactions_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[0u], ER_UI_LEDGER_DASHBOARD_TALL_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_release_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[0u], ER_UI_LEDGER_DASHBOARD_CARD_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_claimable_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[0u], ER_UI_LEDGER_DASHBOARD_CARD_H), colors);
    }

    if (status == ER_UI_OK) {
      status = er_ui_ledger_payout_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[1u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_invest_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[1u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_account_summary_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[1u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_transfer_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[1u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }

    if (status == ER_UI_OK) {
      status = er_ui_ledger_targets_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[2u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_access_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[2u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_payout_preferences_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[2u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_power_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[2u], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }

    if (status == ER_UI_OK) {
      status = er_ui_ledger_stock_performance_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[details_column], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_catalog_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[details_column], ER_UI_LEDGER_DASHBOARD_CARD_H), colors);
    }
    if (status == ER_UI_OK) {
      status = er_ui_ledger_milestone_card(scene, font, er_ui_vertical_flow_next(&masonry.columns[details_column], ER_UI_LEDGER_DASHBOARD_FORM_H), colors);
    }

    if (pushed) er_ui_scene_pop_clip(scene);
    if (status != ER_UI_OK) return status;
    return er_ui_ledger_scrollbar(scene, colors, viewport);
  }

  size_t summary_cards = grid.columns >= ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS ? ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS :
                                                                            ER_UI_LEDGER_DASHBOARD_COMPACT_SUMMARY_CARDS;
  size_t summary_rows = er_ui_responsive_grid_row_count(grid, summary_cards);
  size_t detail_index = summary_rows * grid.columns;
  size_t transaction_span = grid.columns > 2u ? grid.columns - 1u : 1u;
  size_t account_index = detail_index + transaction_span;
  bool invest_in_summary = summary_cards == ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS;
  size_t invest_index = account_index + 1u;
  size_t release_index = invest_in_summary ? account_index + 1u : invest_index + 1u;
  size_t claimable_index = release_index + 1u;
  size_t item_count = claimable_index + 1u;
  size_t row_count = er_ui_responsive_grid_row_count(grid, item_count);
  float row_h = er_ui_float_max(er_ui_responsive_grid_row_height(grid, row_count), ER_UI_LEDGER_DASHBOARD_ROW_MIN_H);
  float content_h = er_ui_responsive_grid_height(grid, item_count, row_h);
  er_ui_scroll_viewport_t viewport = er_ui_scroll_viewport(grid.bounds, content_h, scroll, ER_UI_LEDGER_SCROLL_THUMB_MIN_H);
  er_ui_status_t hit_status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLL_AREA, ER_UI_LEDGER_DASHBOARD_SCROLL_ID,
                                                                    viewport.viewport.x, viewport.viewport.y,
                                                                    viewport.viewport.w, viewport.viewport.h));
  if (hit_status != ER_UI_OK) return hit_status;
  er_ui_responsive_grid_t content_grid = grid;
  content_grid.bounds = viewport.content;
  bool pushed = false;
  status = er_ui_scene_push_clip(scene, er_ui_clip(viewport.viewport.x, viewport.viewport.y, viewport.viewport.w, viewport.viewport.h), &pushed);
  if (status != ER_UI_OK) return status;
  size_t cell_index = 0u;
  status = er_ui_ledger_contribution_card(scene, font, er_ui_responsive_grid_cell(content_grid, cell_index, row_h), colors);
  cell_index++;
  if (status == ER_UI_OK) status = er_ui_ledger_payout_card(scene, font, er_ui_responsive_grid_cell(content_grid, cell_index, row_h), colors);
  cell_index++;
  if (status == ER_UI_OK) status = er_ui_ledger_targets_card(scene, font, er_ui_responsive_grid_cell(content_grid, cell_index, row_h), colors);
  cell_index++;
  if (status == ER_UI_OK && invest_in_summary) {
    status = er_ui_ledger_invest_card(scene, font, er_ui_responsive_grid_cell(content_grid, cell_index, row_h), colors);
    cell_index++;
  }
  if (status == ER_UI_OK) {
    status = er_ui_ledger_transactions_card(scene, font, er_ui_responsive_grid_span(content_grid, detail_index, transaction_span, row_h), colors);
  }
  if (status == ER_UI_OK) {
    status = er_ui_ledger_account_summary_card(scene, font, er_ui_responsive_grid_cell(content_grid, account_index, row_h), colors);
  }
  if (status == ER_UI_OK && !invest_in_summary) {
    status = er_ui_ledger_invest_card(scene, font, er_ui_responsive_grid_cell(content_grid, invest_index, row_h), colors);
  }
  if (status == ER_UI_OK) {
    status = er_ui_ledger_release_card(scene, font, er_ui_responsive_grid_cell(content_grid, release_index, row_h), colors);
  }
  if (status == ER_UI_OK) {
    status = er_ui_ledger_claimable_card(scene, font, er_ui_responsive_grid_cell(content_grid, claimable_index, row_h), colors);
  }
  if (pushed) er_ui_scene_pop_clip(scene);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_scrollbar(scene, colors, viewport);
  return status;
}

static er_ui_status_t er_ui_ledger_payments(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_ledger_content_layout_t layout;
  er_ui_status_t status = er_ui_ledger_begin_surface(scene, font, bounds, colors, focused_id, "Payments", &layout);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t body = er_ui_ledger_surface_body(layout);
  er_ui_vertical_flow_t flow = er_ui_vertical_flow(body, ER_UI_LEDGER_GAP);
  status = er_ui_ledger_transfer_card(scene, font, er_ui_vertical_flow_next(&flow, ER_UI_LEDGER_FORM_CARD_H), colors);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_transactions_card(scene, font, er_ui_vertical_flow_remaining(&flow), colors);
}

static er_ui_status_t er_ui_ledger_access(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_ledger_content_layout_t layout;
  er_ui_status_t status = er_ui_ledger_begin_surface(scene, font, bounds, colors, focused_id, "Access", &layout);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t body = er_ui_ledger_surface_body(layout);
  er_ui_responsive_grid_t grid = er_ui_responsive_grid(body, ER_UI_LEDGER_MIN_CARD_W, ER_UI_LEDGER_ACCESS_MAX_COLUMNS, ER_UI_LEDGER_GAP, ER_UI_LEDGER_GAP);
  if (grid.columns == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  float row_h = er_ui_float_max(er_ui_responsive_grid_row_height(grid, er_ui_responsive_grid_row_count(grid, 2u)), 1.0f);
  status = er_ui_ledger_access_card(scene, font, er_ui_responsive_grid_cell(grid, 0u, row_h), colors);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_targets_card(scene, font, er_ui_responsive_grid_cell(grid, 1u, row_h), colors);
}

er_ui_status_t er_ui_ledger_app_state_init(er_ui_ledger_app_state_t* state, er_ui_allocator_t allocator) {
  er_ui_status_t status;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_shell_state_init_with_allocator(&state->shell, allocator);
  if (status != ER_UI_OK) return status;
  er_ui_component_gallery_state_init(&state->gallery);
  state->dashboard_scroll = 0.0f;
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_LEDGER_APP_LEDGER_ID, "Dashboard");
  if (status != ER_UI_OK) return status;
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_LEDGER_APP_PAYMENTS_ID, "Payments");
  if (status != ER_UI_OK) return status;
  status = er_ui_workspace_add_named_surface(&state->shell, ER_UI_LEDGER_APP_ACCESS_ID, "Access");
  if (status != ER_UI_OK) return status;
  return er_ui_workspace_focus_surface(&state->shell, ER_UI_LEDGER_APP_LEDGER_ID);
}

void er_ui_ledger_app_state_destroy(er_ui_ledger_app_state_t* state) {
  if (!state) return;
  er_ui_shell_state_destroy(&state->shell);
}

er_ui_status_t er_ui_ledger_app_apply_action(er_ui_ledger_app_state_t* state, er_ui_action_t action, bool* out_changed) {
  bool gallery_changed;
  bool scroll_changed = false;
  bool shell_changed = false;
  er_ui_status_t status;
  if (out_changed) *out_changed = false;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;

  gallery_changed = er_ui_component_gallery_apply_action(&state->gallery, action);
  if (action.kind == ER_UI_ACTION_SCROLL_CHANGED && action.id == ER_UI_LEDGER_DASHBOARD_SCROLL_ID) {
    float next_scroll = er_ui_float_clamp(action.float_value, 0.0f, 1.0f);
    if (state->dashboard_scroll != next_scroll) {
      state->dashboard_scroll = next_scroll;
      scroll_changed = true;
    }
  }
  status = er_ui_shell_apply_action(&state->shell, action, &shell_changed);
  if (status != ER_UI_OK) return status;
  if (out_changed) *out_changed = gallery_changed || scroll_changed || shell_changed;
  return ER_UI_OK;
}

er_ui_status_t er_ui_ledger_app_emit_scene(
  er_ui_ledger_app_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!state || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_ledger_colors_t colors = er_ui_ledger_colors(theme);
  uint32_t focused_id = er_ui_workspace_focused_surface_id(&state->shell);
  scene->clear = colors.bg;
  er_ui_status_t status = er_ui_ledger_rect(scene, bounds, 0.0f, colors.bg);
  if (status != ER_UI_OK) return status;
  bool pushed = false;
  status = er_ui_scene_push_clip(scene, er_ui_clip(bounds.x, bounds.y, bounds.w, bounds.h), &pushed);
  if (status != ER_UI_OK) return status;
  switch (focused_id) {
    case ER_UI_LEDGER_APP_PAYMENTS_ID:
      status = er_ui_ledger_payments(scene, font, bounds, colors, focused_id);
      break;
    case ER_UI_LEDGER_APP_ACCESS_ID:
      status = er_ui_ledger_access(scene, font, bounds, colors, focused_id);
      break;
    case ER_UI_LEDGER_APP_LEDGER_ID:
    default:
      status = er_ui_ledger_dashboard(scene, font, bounds, colors, focused_id, state->dashboard_scroll);
      break;
  }
  if (pushed) er_ui_scene_pop_clip(scene);
  return status;
}

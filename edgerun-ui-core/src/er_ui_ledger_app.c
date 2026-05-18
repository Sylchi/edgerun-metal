#include "er_ui_ledger_app.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"

#define ER_UI_LEDGER_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_LEDGER_RGB_BG 10u, 10u, 10u
#define ER_UI_LEDGER_RGB_SIDEBAR 14u, 14u, 14u
#define ER_UI_LEDGER_RGB_PANEL 27u, 27u, 27u
#define ER_UI_LEDGER_RGB_PANEL_ALT 34u, 34u, 34u
#define ER_UI_LEDGER_RGB_FIELD 38u, 38u, 38u
#define ER_UI_LEDGER_RGB_BORDER 58u, 58u, 58u
#define ER_UI_LEDGER_RGB_TEXT 245u, 245u, 245u
#define ER_UI_LEDGER_RGB_MUTED 166u, 166u, 166u
#define ER_UI_LEDGER_RGB_SUBTLE 122u, 122u, 122u
#define ER_UI_LEDGER_RGB_BUTTON 229u, 229u, 229u
#define ER_UI_LEDGER_RGB_BUTTON_TEXT 18u, 18u, 18u
#define ER_UI_LEDGER_RGB_SUCCESS 16u, 185u, 129u
#define ER_UI_LEDGER_RGB_DANGER 239u, 68u, 68u
#define ER_UI_LEDGER_RGB_WARNING 245u, 158u, 11u

static const float ER_UI_LEDGER_MARGIN = 24.0f;
static const float ER_UI_LEDGER_GAP = 16.0f;
static const float ER_UI_LEDGER_MIN_SIDE_W = 160.0f;
static const float ER_UI_LEDGER_SIDE_W = 220.0f;
static const float ER_UI_LEDGER_STACKED_SIDE_H = 160.0f;
static const float ER_UI_LEDGER_MIN_CARD_W = 220.0f;
static const size_t ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS = 4u;
static const size_t ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS = 4u;
static const size_t ER_UI_LEDGER_DASHBOARD_COMPACT_SUMMARY_CARDS = 3u;
static const size_t ER_UI_LEDGER_ACCESS_MAX_COLUMNS = 2u;
static const float ER_UI_LEDGER_SURFACE_BODY_Y = 72.0f;
static const float ER_UI_LEDGER_FORM_CARD_H = 286.0f;
static const float ER_UI_LEDGER_CARD_RADIUS = 8.0f;
static const float ER_UI_LEDGER_NAV_ROW_H = 34.0f;
static const float ER_UI_LEDGER_FIELD_H = 32.0f;
static const float ER_UI_LEDGER_BUTTON_H = 34.0f;
static const float ER_UI_LEDGER_BAR_MIN_W = 22.0f;
static const float ER_UI_LEDGER_BAR_MAX_W = 40.0f;
static const float ER_UI_LEDGER_BAR_GAP = 12.0f;
static const float ER_UI_LEDGER_BAR_MAX_H = 104.0f;
static const float ER_UI_LEDGER_PROGRESS_H = 4.0f;
static const float ER_UI_LEDGER_TRANSACTION_H = 42.0f;
static const float ER_UI_LEDGER_QR_CELL = 7.0f;
static const float ER_UI_LEDGER_TEXT_ADVANCE = 7.0f;
static const float ER_UI_LEDGER_BUTTON_TEXT_PAD_X = 14.0f;
static const float ER_UI_LEDGER_BUTTON_TEXT_MIN_START_RATIO = 0.30f;
static const float ER_UI_LEDGER_CARD_PAD = 16.0f;
static const float ER_UI_LEDGER_COMPACT_NAV_GAP = 8.0f;
static const float ER_UI_LEDGER_COMPACT_NAV_Y = 92.0f;
static const float ER_UI_LEDGER_DENSE_CARD_H = 180.0f;
static const float ER_UI_LEDGER_DENSE_FORM_H = 190.0f;
static const float ER_UI_LEDGER_FIELD_PAD_X = 10.0f;
static const float ER_UI_LEDGER_DOT_SIZE = 4.0f;
static const float ER_UI_LEDGER_SELECT_CHEVRON_W = 14.0f;
static const float ER_UI_LEDGER_SELECT_CHEVRON_H = 14.0f;
static const size_t ER_UI_LEDGER_ACTIVITY_BAR_COUNT = 7u;
static const size_t ER_UI_LEDGER_TEXT_CAP = 96u;
static const uint32_t ER_UI_LEDGER_ACTION_BASE = 0xED024000u;
static const uint32_t ER_UI_LEDGER_PAYOUT_SLIDER_ID = ER_UI_LEDGER_ACTION_BASE + 1u;
static const uint32_t ER_UI_LEDGER_INVEST_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 2u;
static const uint32_t ER_UI_LEDGER_TRANSFER_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 4u;
static const uint32_t ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID = ER_UI_LEDGER_ACTION_BASE + 8u;

typedef struct {
  er_ui_color4_t bg;
  er_ui_color4_t panel;
  er_ui_color4_t panel_alt;
  er_ui_color4_t field;
  er_ui_color4_t border;
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

static er_ui_ledger_colors_t er_ui_ledger_colors(void) {
  er_ui_ledger_colors_t colors;
  colors.bg = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_BG);
  colors.panel = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_PANEL);
  colors.panel_alt = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_PANEL_ALT);
  colors.field = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_FIELD);
  colors.border = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_BORDER);
  colors.text = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_TEXT);
  colors.muted = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_MUTED);
  colors.subtle = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_SUBTLE);
  colors.button = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_BUTTON);
  colors.button_text = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_BUTTON_TEXT);
  colors.success = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_SUCCESS);
  colors.danger = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_DANGER);
  colors.warning = er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_WARNING);
  return colors;
}

static er_ui_status_t er_ui_ledger_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color) {
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_LEDGER_TEXT_CAP, x, y, color);
}

static size_t er_ui_ledger_ascii_len(const char* text) {
  size_t len = 0u;
  const char* cursor = text;
  if (!text) return 0u;
  while (*cursor) {
    len++;
    cursor++;
  }
  return len;
}

static er_ui_status_t er_ui_ledger_text_right(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float right_x,
  float y,
  er_ui_color4_t color) {
  float text_w = (float)er_ui_ledger_ascii_len(text) * ER_UI_LEDGER_TEXT_ADVANCE;
  return er_ui_ledger_text(scene, font, text, right_x - text_w, y, color);
}

static er_ui_status_t er_ui_ledger_rect(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

static er_ui_status_t er_ui_ledger_border(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
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
  status = er_ui_ledger_rect(scene, row, 7.0f, fill);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_icon(&painter, er_ui_bounds(row.x + 10.0f, row.y + 8.0f, 16.0f, 16.0f),
                              nav->icon, color);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, nav->label, row.x + 34.0f, row.y + 22.0f, color);
}

static er_ui_status_t er_ui_ledger_card(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_shadow(bounds.x, bounds.y + 6.0f, bounds.w, bounds.h,
                                                                        ER_UI_LEDGER_CARD_RADIUS,
                                                                        er_ui_color_rgba(0.0f, 0.0f, 0.0f, 0.18f), 12.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, bounds, ER_UI_LEDGER_CARD_RADIUS, colors.panel);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_border(scene, bounds, ER_UI_LEDGER_CARD_RADIUS, colors.border);
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
  status = er_ui_ledger_text(scene, font, title, bounds.x + 16.0f, bounds.y + 26.0f, colors.text);
  if (status != ER_UI_OK) return status;
  if (subtitle == 0) return ER_UI_OK;
  return er_ui_ledger_text(scene, font, subtitle, bounds.x + 16.0f, bounds.y + 48.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_subtile(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  const char* value) {
  er_ui_status_t status = er_ui_ledger_rect(scene, bounds, 7.0f, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, label, bounds.x + 12.0f, bounds.y + 22.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, value, bounds.x + 12.0f, bounds.y + 46.0f, colors.text);
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
  status = er_ui_ledger_text(scene, font, title, layout.content.x, layout.content.y + 40.0f, colors.text);
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

static er_ui_status_t er_ui_ledger_select_chevron(
  er_ui_scene_t* scene,
  er_ui_bounds_t field,
  er_ui_ledger_colors_t colors) {
  float x = field.x + field.w - ER_UI_LEDGER_FIELD_PAD_X - ER_UI_LEDGER_SELECT_CHEVRON_W;
  float y = field.y + (field.h - ER_UI_LEDGER_SELECT_CHEVRON_H) * 0.5f;
  return er_ui_ledger_icon(scene, er_ui_bounds(x, y, ER_UI_LEDGER_SELECT_CHEVRON_W, ER_UI_LEDGER_SELECT_CHEVRON_H), ER_UI_ICON_CHEVRON_RIGHT, colors.muted);
}

static er_ui_status_t er_ui_ledger_button(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  uint32_t id) {
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, bounds, 7.0f, colors.button);
  if (status != ER_UI_OK) return status;
  float text_w = (float)er_ui_ledger_ascii_len(label) * ER_UI_LEDGER_TEXT_ADVANCE;
  float text_x = bounds.x + (bounds.w - text_w) * 0.5f;
  if (text_x < bounds.x + ER_UI_LEDGER_BUTTON_TEXT_PAD_X) text_x = bounds.x + ER_UI_LEDGER_BUTTON_TEXT_PAD_X;
  if (text_x < bounds.x + bounds.w * ER_UI_LEDGER_BUTTON_TEXT_MIN_START_RATIO) {
    text_x = bounds.x + bounds.w * ER_UI_LEDGER_BUTTON_TEXT_MIN_START_RATIO;
  }
  return er_ui_ledger_text(scene, font, label, text_x, bounds.y + 22.0f, colors.button_text);
}

static er_ui_status_t er_ui_ledger_field(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  const char* value,
  bool selectable) {
  er_ui_status_t status = er_ui_ledger_text(scene, font, label, bounds.x, bounds.y - 8.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, bounds, 7.0f, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_border(scene, bounds, 7.0f, colors.border);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, value, bounds.x + ER_UI_LEDGER_FIELD_PAD_X, bounds.y + 21.0f, colors.text);
  if (status != ER_UI_OK) return status;
  if (!selectable) return ER_UI_OK;
  return er_ui_ledger_select_chevron(scene, bounds, colors);
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
  const er_ui_ledger_field_row_t* row = rows;
  const er_ui_ledger_field_row_t* end = rows + row_count;
  float y = bounds.y + first_y;
  while (row < end) {
    status = er_ui_ledger_field(scene, font,
                                er_ui_bounds(bounds.x + 16.0f, y,
                                             bounds.w - 32.0f, ER_UI_LEDGER_FIELD_H),
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
  er_ui_status_t status = er_ui_ledger_rect(scene, bounds, 0.0f, colors.field);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_rect(scene, er_ui_bounds(bounds.x, bounds.y, bounds.w * value, bounds.h), 0.0f, colors.text);
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
  return er_ui_ledger_rect(scene, er_ui_bounds(bounds.x + bounds.w * value - 4.0f, bounds.y - 4.0f, 8.0f, 8.0f), 999.0f, colors.text);
}

static er_ui_status_t er_ui_ledger_bottom_button(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  uint32_t id,
  float bottom_inset) {
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - bottom_inset,
                                          bounds.w - 32.0f, ER_UI_LEDGER_BUTTON_H),
                             colors, label, id);
}

static er_ui_status_t er_ui_ledger_sidebar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_status_t status;
  float x = bounds.x + 18.0f;
  float y = bounds.y + 34.0f;
  bool compact = bounds.h <= ER_UI_LEDGER_STACKED_SIDE_H;

  status = er_ui_ledger_rect(scene, bounds, 0.0f, er_ui_color_rgb_u8(ER_UI_LEDGER_RGB_SIDEBAR));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "EdgeRun Ledger", x, y, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "local settlement console", x, y + 24.0f, colors.muted);
  if (status != ER_UI_OK) return status;

  y += 62.0f;
  //@optimizer-ignore nav renderer intentionally emits one hit, icon, and label per fixed surface
  const er_ui_ledger_nav_item_t* nav = ER_UI_LEDGER_NAV_ITEMS;
  const er_ui_ledger_nav_item_t* nav_end = ER_UI_LEDGER_NAV_ITEMS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_NAV_ITEMS);
  if (compact) {
    float nav_w = (bounds.w - 36.0f - ER_UI_LEDGER_COMPACT_NAV_GAP * (float)(ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_NAV_ITEMS) - 1u)) /
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
                                      bounds.w - 24.0f, ER_UI_LEDGER_NAV_ROW_H);
    //@optimizer-ignore fixed sidebar navigation renders one deterministic item per surface row
    status = er_ui_ledger_nav_row(scene, font, row, colors, nav, focused_id);
    if (status != ER_UI_OK) return status;
    y += ER_UI_LEDGER_NAV_ROW_H + 4.0f;
    nav++;
  }

  er_ui_bounds_t qr_card = er_ui_bounds(bounds.x + 18.0f, bounds.y + bounds.h - 194.0f, bounds.w - 36.0f, 156.0f);
  status = er_ui_ledger_card(scene, qr_card, colors);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(qr_card.x + 58.0f, qr_card.y + 18.0f, 84.0f, 84.0f), 8.0f, colors.button);
  if (status != ER_UI_OK) return status;
  //@optimizer-ignore QR preview intentionally emits one deterministic rectangle per dark module
  const uint8_t(*dot)[2u] = ER_UI_LEDGER_QR_DOTS;
  const uint8_t(*dot_end)[2u] = ER_UI_LEDGER_QR_DOTS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_QR_DOTS);
  while (dot < dot_end) {
    status = er_ui_ledger_rect(scene,
                               er_ui_bounds(qr_card.x + 62.0f + (float)(*dot)[0u] * ER_UI_LEDGER_QR_CELL,
                                            qr_card.y + 28.0f + (float)(*dot)[1u] * ER_UI_LEDGER_QR_CELL,
                                            ER_UI_LEDGER_QR_CELL - 1.0f, ER_UI_LEDGER_QR_CELL - 1.0f),
                               0.0f, colors.bg);
    if (status != ER_UI_OK) return status;
    dot++;
  }
  status = er_ui_ledger_text(scene, font, "Pair mobile device", qr_card.x + 24.0f, qr_card.y + 124.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, "scan local access key", qr_card.x + 24.0f, qr_card.y + 146.0f, colors.muted);
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
  if (bounds.h < ER_UI_LEDGER_DENSE_CARD_H) {
    status = er_ui_ledger_progress(scene, er_ui_bounds(bounds.x + 16.0f, bounds.y + 76.0f, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H), colors, 0.76f);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, "May 25, 2024", bounds.x + 16.0f, bounds.y + 108.0f, colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_ledger_text_right(scene, font, "$1,000 scheduled", bounds.x + bounds.w - 16.0f, bounds.y + 108.0f, colors.muted);
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
    status = er_ui_ledger_text(scene, font, bar->label, x + 2.0f, bounds.y + 176.0f, colors.subtle);
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
  return er_ui_ledger_text(scene, font, "$1,000 scheduled", plan.x + 12.0f, plan.y + 64.0f, colors.muted);
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
  bool dense = bounds.h < ER_UI_LEDGER_DENSE_FORM_H;
  bool compact = bounds.h < 260.0f;
  if (dense) {
    status = er_ui_ledger_text(scene, font, "Minimum Payout Amount", bounds.x + 16.0f, bounds.y + 74.0f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right(scene, font, "$2500.00", bounds.x + bounds.w - 16.0f, bounds.y + 74.0f, colors.text);
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
  status = er_ui_ledger_text(scene, font, "Minimum Payout Amount", bounds.x + 16.0f, bounds.y + amount_y, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right(scene, font, "$2500.00", bounds.x + bounds.w - 16.0f, bounds.y + amount_y, colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t slider = er_ui_bounds(bounds.x + 16.0f, bounds.y + slider_y, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H);
  status = er_ui_ledger_slider(scene, slider, colors, 0.25f);
  if (status != ER_UI_OK) return status;
  if (!compact) {
    status = er_ui_ledger_text(scene, font, "$50 (MIN)", slider.x, slider.y + 24.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right(scene, font, "$10,000 (MAX)", slider.x + slider.w, slider.y + 24.0f, colors.muted);
    if (status != ER_UI_OK) return status;
  }
  if (bounds.h >= 360.0f) {
    er_ui_bounds_t notes = er_ui_bounds(bounds.x + 16.0f, bounds.y + 224.0f, bounds.w - 32.0f, bounds.h - 286.0f);
    status = er_ui_ledger_text(scene, font, "Notes", notes.x, notes.y - 8.0f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, notes, 7.0f, colors.field);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_border(scene, notes, 7.0f, colors.border);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, "Add any notes for this payout configuration...", notes.x + 10.0f, notes.y + 24.0f, colors.muted);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Save Threshold", ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID, 48.0f);
}

static er_ui_status_t er_ui_ledger_targets_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Savings Targets",
                                                        "Active milestones for 2024");
  if (status != ER_UI_OK) return status;
  if (bounds.h >= ER_UI_LEDGER_DENSE_CARD_H) {
    er_ui_bounds_t new_goal = er_ui_bounds(bounds.x + bounds.w - 82.0f, bounds.y + 12.0f, 66.0f, 28.0f);
    status = er_ui_ledger_rect(scene, new_goal, 7.0f, colors.field);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_border(scene, new_goal, 7.0f, colors.border);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, "New Goal", new_goal.x + 8.0f, new_goal.y + 19.0f, colors.text);
    if (status != ER_UI_OK) return status;
  }
  const er_ui_ledger_target_t* row = ER_UI_LEDGER_TARGETS;
  const er_ui_ledger_target_t* end = ER_UI_LEDGER_TARGETS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TARGETS);
  float target_y = bounds.y + (bounds.h < ER_UI_LEDGER_DENSE_CARD_H ? 62.0f : 70.0f);
  while (row < end) {
    if (target_y + 96.0f > bounds.y + bounds.h - 12.0f) break;
    er_ui_bounds_t target = er_ui_bounds(bounds.x + 16.0f, target_y, bounds.w - 32.0f, 96.0f);
    status = er_ui_ledger_rect(scene, target, 7.0f, colors.panel_alt);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->title, target.x + 12.0f, target.y + 24.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->amount, target.x + 12.0f, target.y + 52.0f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_progress(scene, er_ui_bounds(target.x + 12.0f, target.y + 68.0f, target.w - 24.0f, ER_UI_LEDGER_PROGRESS_H),
                                   colors, row->progress);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->progress > 0.5f ? "65% achieved" : "32% achieved", target.x + 12.0f, target.y + 88.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right(scene, font, row->detail, target.x + target.w - 12.0f, target.y + 88.0f, colors.text);
    if (status != ER_UI_OK) return status;
    target_y += 112.0f;
    row++;
  }
  if (bounds.h < 312.0f) return ER_UI_OK;
  status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 54.0f, bounds.w, 1.0f), 0.0f, colors.border);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, "You have not met your targets for this year.", bounds.x + 16.0f, bounds.y + bounds.h - 24.0f, colors.muted);
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
  bool dense = bounds.h < ER_UI_LEDGER_DENSE_FORM_H;
  bool compact = bounds.h < 260.0f;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), compact ? 54.0f : 76.0f, compact ? 50.0f : 72.0f);
  if (status != ER_UI_OK) return status;
  if (dense) {
    return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID, 42.0f);
  }
  if (compact) {
    return er_ui_ledger_bottom_button(scene, font, bounds, colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID, 48.0f);
  }
  status = er_ui_ledger_text(scene, font, "Market orders execute at the current price.", bounds.x + 16.0f, bounds.y + 162.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Estimated Shares", bounds.x + 16.0f, bounds.y + 196.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right(scene, font, "1.95", bounds.x + bounds.w - 16.0f, bounds.y + 196.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Buying Power", bounds.x + 16.0f, bounds.y + 220.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text_right(scene, font, "$12,450.00", bounds.x + bounds.w - 16.0f, bounds.y + 220.0f, colors.text);
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
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Recent Transactions",
                                                        "Your latest account activity.");
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t view_all = er_ui_bounds(bounds.x + bounds.w - 84.0f, bounds.y + 12.0f, 66.0f, 28.0f);
  status = er_ui_ledger_rect(scene, view_all, 7.0f, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_border(scene, view_all, 7.0f, colors.border);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "View All", view_all.x + 9.0f, view_all.y + 19.0f, colors.text);
  if (status != ER_UI_OK) return status;
  float y = bounds.y + 76.0f;
  const er_ui_ledger_transaction_t* row = ER_UI_LEDGER_TRANSACTIONS;
  const er_ui_ledger_transaction_t* end = ER_UI_LEDGER_TRANSACTIONS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TRANSACTIONS);
  while (row < end) {
    if (y + ER_UI_LEDGER_TRANSACTION_H > bounds.y + bounds.h - 12.0f) break;
    er_ui_bounds_t tile = er_ui_bounds(bounds.x + 16.0f, y + 6.0f, 32.0f, 32.0f);
    er_ui_color4_t amount = row->positive ? colors.success : colors.text;
    status = er_ui_ledger_rect(scene, tile, 7.0f, colors.field);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_icon(scene, er_ui_bounds(tile.x + 8.0f, tile.y + 8.0f, 16.0f, 16.0f), row->icon, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->name, bounds.x + 60.0f, y + 18.0f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->kind, bounds.x + 60.0f, y + 36.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    float amount_right = bounds.x + bounds.w - 34.0f;
    float amount_w = (float)er_ui_ledger_ascii_len(row->amount) * ER_UI_LEDGER_TEXT_ADVANCE;
    float date_right = amount_right - amount_w - 52.0f;
    status = er_ui_ledger_text_right(scene, font, row->date, date_right, y + 26.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text_right(scene, font, row->amount, amount_right, y + 26.0f, amount);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x + bounds.w - 22.0f, y + 21.0f, ER_UI_LEDGER_DOT_SIZE, ER_UI_LEDGER_DOT_SIZE),
                               ER_UI_LEDGER_DOT_SIZE * 0.5f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x + bounds.w - 14.0f, y + 21.0f, ER_UI_LEDGER_DOT_SIZE, ER_UI_LEDGER_DOT_SIZE),
                               ER_UI_LEDGER_DOT_SIZE * 0.5f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, er_ui_bounds(bounds.x + 16.0f, y + ER_UI_LEDGER_TRANSACTION_H - 1.0f,
                                                  bounds.w - 32.0f, 1.0f), 0.0f, colors.border);
    if (status != ER_UI_OK) return status;
    y += ER_UI_LEDGER_TRANSACTION_H;
    row++;
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
  status = er_ui_ledger_text(scene, font, "US$12.94", bounds.x + 16.0f, bounds.y + 86.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "US$11,337.06 available", bounds.x + 16.0f, bounds.y + 112.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t activity = er_ui_bounds(bounds.x + 16.0f, bounds.y + 148.0f, bounds.w - 32.0f, 92.0f);
  status = er_ui_ledger_rect(scene, activity, 7.0f, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Yearly Activity", activity.x + 12.0f, activity.y + 24.0f, colors.muted);
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
  status = er_ui_ledger_rect(scene, transfer, 7.0f, colors.panel_alt);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Transfer Funds", transfer.x + 12.0f, transfer.y + 24.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, "Move money between accounts.", transfer.x + 12.0f, transfer.y + 48.0f, colors.muted);
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

static er_ui_status_t er_ui_ledger_dashboard(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_ledger_content_layout_t layout = er_ui_ledger_content_layout(bounds);
  if (!er_ui_bounds_valid(layout.sidebar) || !er_ui_bounds_valid(layout.content)) return ER_UI_ERR_INVALID_ARGUMENT;
  float top_y = layout.content.y + ER_UI_LEDGER_MARGIN;
  float grid_y = top_y + 58.0f;
  float available_h = er_ui_float_max(layout.content.y + layout.content.h - grid_y - ER_UI_LEDGER_MARGIN, 1.0f);
  er_ui_responsive_grid_t grid = er_ui_responsive_grid(
    er_ui_bounds(layout.content.x, grid_y, layout.content.w, available_h),
    ER_UI_LEDGER_MIN_CARD_W,
    ER_UI_LEDGER_DASHBOARD_MAX_COLUMNS,
    ER_UI_LEDGER_GAP,
    ER_UI_LEDGER_GAP);

  er_ui_status_t status = er_ui_ledger_sidebar(scene, font, layout.sidebar, colors, focused_id);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Dashboard", layout.content.x, top_y + 14.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "settlement, royalties, and device-local accounting", layout.content.x, top_y + 38.0f, colors.muted);
  if (status != ER_UI_OK) return status;

  if (grid.columns == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t summary_cards = grid.columns >= ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS ? ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS :
                                                                            ER_UI_LEDGER_DASHBOARD_COMPACT_SUMMARY_CARDS;
  size_t summary_rows = er_ui_responsive_grid_row_count(grid, summary_cards);
  size_t detail_index = summary_rows * grid.columns;
  size_t transaction_span = grid.columns > 2u ? grid.columns - 1u : 1u;
  size_t row_count = er_ui_responsive_grid_row_count(grid, detail_index + transaction_span + 1u);
  float row_h = er_ui_float_max(er_ui_responsive_grid_row_height(grid, row_count), 1.0f);
  size_t cell_index = 0u;
  status = er_ui_ledger_contribution_card(scene, font, er_ui_responsive_grid_cell(grid, cell_index, row_h), colors);
  if (status != ER_UI_OK) return status;
  cell_index++;
  status = er_ui_ledger_payout_card(scene, font, er_ui_responsive_grid_cell(grid, cell_index, row_h), colors);
  if (status != ER_UI_OK) return status;
  cell_index++;
  status = er_ui_ledger_targets_card(scene, font, er_ui_responsive_grid_cell(grid, cell_index, row_h), colors);
  if (status != ER_UI_OK) return status;
  cell_index++;
  if (summary_cards == ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS) {
    status = er_ui_ledger_invest_card(scene, font, er_ui_responsive_grid_cell(grid, cell_index, row_h), colors);
    if (status != ER_UI_OK) return status;
    cell_index++;
  }
  status = er_ui_ledger_transactions_card(scene, font, er_ui_responsive_grid_span(grid, detail_index, transaction_span, row_h), colors);
  if (status != ER_UI_OK) return status;
  if (summary_cards == ER_UI_LEDGER_DASHBOARD_WIDE_SUMMARY_CARDS) {
    return er_ui_ledger_account_summary_card(scene, font, er_ui_responsive_grid_cell(grid, detail_index + transaction_span, row_h), colors);
  }
  return er_ui_ledger_invest_card(scene, font, er_ui_responsive_grid_cell(grid, detail_index + transaction_span, row_h), colors);
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
  er_ui_status_t status;
  if (out_changed) *out_changed = false;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;

  gallery_changed = er_ui_component_gallery_apply_action(&state->gallery, action);
  status = er_ui_shell_apply_action(&state->shell, action, out_changed);
  if (status != ER_UI_OK) return status;
  if (out_changed && gallery_changed) *out_changed = true;
  return ER_UI_OK;
}

er_ui_status_t er_ui_ledger_app_emit_scene(
  er_ui_ledger_app_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  (void)theme;
  if (!state || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_ledger_colors_t colors = er_ui_ledger_colors();
  uint32_t focused_id = er_ui_workspace_focused_surface_id(&state->shell);
  scene->clear = colors.bg;
  er_ui_status_t status = er_ui_ledger_rect(scene, bounds, 0.0f, colors.bg);
  if (status != ER_UI_OK) return status;
  switch (focused_id) {
    case ER_UI_LEDGER_APP_PAYMENTS_ID:
      return er_ui_ledger_payments(scene, font, bounds, colors, focused_id);
    case ER_UI_LEDGER_APP_ACCESS_ID:
      return er_ui_ledger_access(scene, font, bounds, colors, focused_id);
    case ER_UI_LEDGER_APP_LEDGER_ID:
    default:
      return er_ui_ledger_dashboard(scene, font, bounds, colors, focused_id);
  }
}

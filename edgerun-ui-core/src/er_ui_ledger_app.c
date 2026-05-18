#include "er_ui_ledger_app.h"
#include "er_ui_painter.h"

#define ER_UI_LEDGER_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_LEDGER_RGB_BG 8u, 8u, 8u
#define ER_UI_LEDGER_RGB_SIDEBAR 12u, 12u, 12u
#define ER_UI_LEDGER_RGB_PANEL 24u, 24u, 24u
#define ER_UI_LEDGER_RGB_PANEL_ALT 30u, 30u, 30u
#define ER_UI_LEDGER_RGB_FIELD 35u, 35u, 35u
#define ER_UI_LEDGER_RGB_BORDER 45u, 45u, 45u
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
static const float ER_UI_LEDGER_SIDE_W = 220.0f;
static const float ER_UI_LEDGER_RIGHT_W = 340.0f;
static const float ER_UI_LEDGER_MIN_MAIN_W = 520.0f;
static const float ER_UI_LEDGER_CARD_RADIUS = 8.0f;
static const float ER_UI_LEDGER_NAV_ROW_H = 34.0f;
static const float ER_UI_LEDGER_FIELD_H = 32.0f;
static const float ER_UI_LEDGER_BUTTON_H = 34.0f;
static const float ER_UI_LEDGER_BAR_W = 26.0f;
static const float ER_UI_LEDGER_BAR_GAP = 14.0f;
static const float ER_UI_LEDGER_BAR_MAX_H = 82.0f;
static const float ER_UI_LEDGER_PROGRESS_H = 4.0f;
static const float ER_UI_LEDGER_TRANSACTION_H = 46.0f;
static const float ER_UI_LEDGER_QR_CELL = 7.0f;
static const float ER_UI_LEDGER_TEXT_ADVANCE = 7.0f;
static const float ER_UI_LEDGER_BUTTON_TEXT_PAD_X = 14.0f;
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
  float content_x;
  float content_w;
} er_ui_ledger_content_layout_t;

typedef struct {
  const char* label;
  const char* value;
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

static er_ui_status_t er_ui_ledger_rect(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

static er_ui_status_t er_ui_ledger_border(er_ui_scene_t* scene, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
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

static er_ui_ledger_content_layout_t er_ui_ledger_content_layout(er_ui_bounds_t bounds) {
  er_ui_ledger_content_layout_t layout;
  layout.content_x = bounds.x + ER_UI_LEDGER_SIDE_W + ER_UI_LEDGER_MARGIN;
  layout.content_w = bounds.w - layout.content_x - ER_UI_LEDGER_MARGIN;
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
  status = er_ui_ledger_sidebar(scene, font, er_ui_bounds(bounds.x, bounds.y, ER_UI_LEDGER_SIDE_W, bounds.h),
                                colors, focused_id);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, title, layout.content_x, bounds.y + 40.0f, colors.text);
  if (status != ER_UI_OK) return status;
  *out_layout = layout;
  return ER_UI_OK;
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
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, bounds, 7.0f, colors.button);
  if (status != ER_UI_OK) return status;
  float text_w = (float)er_ui_ledger_ascii_len(label) * ER_UI_LEDGER_TEXT_ADVANCE;
  float text_x = bounds.x + (bounds.w - text_w) * 0.5f;
  if (text_x < bounds.x + ER_UI_LEDGER_BUTTON_TEXT_PAD_X) text_x = bounds.x + ER_UI_LEDGER_BUTTON_TEXT_PAD_X;
  return er_ui_ledger_text(scene, font, label, text_x, bounds.y + 22.0f, colors.button_text);
}

static er_ui_status_t er_ui_ledger_field(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  const char* label,
  const char* value) {
  er_ui_status_t status = er_ui_ledger_text(scene, font, label, bounds.x, bounds.y - 8.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, bounds, 7.0f, colors.field);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_border(scene, bounds, 7.0f, colors.border);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, value, bounds.x + 10.0f, bounds.y + 21.0f, colors.text);
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
                                colors, row->label, row->value);
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

static er_ui_status_t er_ui_ledger_sidebar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  er_ui_status_t status;
  float x = bounds.x + 18.0f;
  float y = bounds.y + 34.0f;
  er_ui_painter_t painter = er_ui_painter(scene);

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
  while (nav < nav_end) {
    er_ui_bounds_t row = er_ui_bounds(x - 6.0f, y,
                                      bounds.w - 24.0f, ER_UI_LEDGER_NAV_ROW_H);
    er_ui_color4_t fill = nav->id == focused_id ? colors.field : er_ui_color_with_alpha(colors.field, 0.0f);
    er_ui_color4_t color = nav->id == focused_id ? colors.text : colors.muted;
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_WORKSPACE_TAB, nav->id, row.x, row.y, row.w, row.h));
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_rect(scene, row, 7.0f, fill);
    if (status != ER_UI_OK) return status;
    //@optimizer-ignore fixed sidebar navigation renders one deterministic icon per surface row
    status = er_ui_painter_icon(&painter, er_ui_bounds(row.x + 10.0f, row.y + 8.0f, 16.0f, 16.0f),
                                nav->icon, color);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, nav->label, row.x + 34.0f, row.y + 22.0f, color);
    if (status != ER_UI_OK) return status;
    y += ER_UI_LEDGER_NAV_ROW_H + 4.0f;
    nav++;
  }

  er_ui_bounds_t qr_card = er_ui_bounds(bounds.x + 18.0f, bounds.y + bounds.h - 214.0f, bounds.w - 36.0f, 176.0f);
  status = er_ui_ledger_card(scene, qr_card, colors);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(qr_card.x + 52.0f, qr_card.y + 22.0f, 96.0f, 96.0f), 8.0f, colors.button);
  if (status != ER_UI_OK) return status;
  //@optimizer-ignore QR preview intentionally emits one deterministic rectangle per dark module
  const uint8_t(*dot)[2u] = ER_UI_LEDGER_QR_DOTS;
  const uint8_t(*dot_end)[2u] = ER_UI_LEDGER_QR_DOTS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_QR_DOTS);
  while (dot < dot_end) {
    status = er_ui_ledger_rect(scene,
                               er_ui_bounds(qr_card.x + 62.0f + (float)(*dot)[0u] * ER_UI_LEDGER_QR_CELL,
                                            qr_card.y + 32.0f + (float)(*dot)[1u] * ER_UI_LEDGER_QR_CELL,
                                            ER_UI_LEDGER_QR_CELL - 1.0f, ER_UI_LEDGER_QR_CELL - 1.0f),
                               0.0f, colors.bg);
    if (status != ER_UI_OK) return status;
    dot++;
  }
  status = er_ui_ledger_text(scene, font, "Pair mobile device", qr_card.x + 28.0f, qr_card.y + 140.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, "scan local access key", qr_card.x + 28.0f, qr_card.y + 162.0f, colors.muted);
}

static er_ui_status_t er_ui_ledger_contribution_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Contribution History",
                                                        "Last 6 months of settlement");
  if (status != ER_UI_OK) return status;
  float bars_x = bounds.x + 28.0f;
  float bars_base = bounds.y + 132.0f;
  const er_ui_ledger_bar_t* bar = ER_UI_LEDGER_CONTRIBUTIONS;
  const er_ui_ledger_bar_t* bar_end = ER_UI_LEDGER_CONTRIBUTIONS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_CONTRIBUTIONS);
  float bar_x = bars_x;
  while (bar < bar_end) {
    float h = ER_UI_LEDGER_BAR_MAX_H * bar->value;
    float x = bar_x;
    status = er_ui_ledger_rect(scene, er_ui_bounds(x, bars_base - h, ER_UI_LEDGER_BAR_W, h), 5.0f, colors.subtle);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, bar->label, x - 2.0f, bounds.y + 158.0f, colors.subtle);
    if (status != ER_UI_OK) return status;
    bar_x += ER_UI_LEDGER_BAR_W + ER_UI_LEDGER_BAR_GAP;
    bar++;
  }
  status = er_ui_ledger_text(scene, font, "UPCOMING", bounds.x + 16.0f, bounds.y + bounds.h - 44.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_text(scene, font, "May 25, 2024", bounds.x + 16.0f, bounds.y + bounds.h - 20.0f, colors.text);
}

static er_ui_status_t er_ui_ledger_payout_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Currency", "USD - United States Dollar"}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Payout Threshold",
                                                        "Minimum balance before payout");
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 76.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Minimum Payout Amount", bounds.x + 16.0f, bounds.y + 142.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "$2500.00", bounds.x + bounds.w - 110.0f, bounds.y + 142.0f, colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t slider = er_ui_bounds(bounds.x + 16.0f, bounds.y + 158.0f, bounds.w - 32.0f, ER_UI_LEDGER_PROGRESS_H);
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SLIDER, ER_UI_LEDGER_PAYOUT_SLIDER_ID, slider.x, slider.y - 10.0f, slider.w, 24.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_progress(scene, slider, colors, 0.25f);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_rect(scene, er_ui_bounds(slider.x + slider.w * 0.25f - 4.0f, slider.y - 4.0f, 8.0f, 8.0f), 999.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 48.0f,
                                          bounds.w - 32.0f, ER_UI_LEDGER_BUTTON_H),
                             colors, "Save Threshold", ER_UI_LEDGER_SAVE_THRESHOLD_BUTTON_ID);
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
  const er_ui_ledger_target_t* row = ER_UI_LEDGER_TARGETS;
  const er_ui_ledger_target_t* end = ER_UI_LEDGER_TARGETS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TARGETS);
  float target_y = bounds.y + 70.0f;
  while (row < end) {
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
    status = er_ui_ledger_text(scene, font, row->detail, target.x + target.w - 128.0f, target.y + 88.0f, colors.text);
    if (status != ER_UI_OK) return status;
    target_y += 112.0f;
    row++;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_ledger_invest_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Amount to Invest", "$ 1,000.00"},
    {"Order Type", "Market Order"}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Buy Investment", 0);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 76.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Estimated Shares", bounds.x + 16.0f, bounds.y + 196.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "1.95", bounds.x + bounds.w - 52.0f, bounds.y + 196.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Buying Power", bounds.x + 16.0f, bounds.y + 220.0f, colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "$12,450.00", bounds.x + bounds.w - 106.0f, bounds.y + 220.0f, colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font,
                             er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 48.0f,
                                          bounds.w - 32.0f, ER_UI_LEDGER_BUTTON_H),
                             colors, "Review Order", ER_UI_LEDGER_INVEST_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_transactions_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Recent Transactions",
                                                        "Latest account activity");
  if (status != ER_UI_OK) return status;
  float y = bounds.y + 76.0f;
  const er_ui_ledger_transaction_t* row = ER_UI_LEDGER_TRANSACTIONS;
  const er_ui_ledger_transaction_t* end = ER_UI_LEDGER_TRANSACTIONS + ER_UI_LEDGER_ARRAY_COUNT(ER_UI_LEDGER_TRANSACTIONS);
  while (row < end) {
    er_ui_bounds_t tile = er_ui_bounds(bounds.x + 16.0f, y + 6.0f, 32.0f, 32.0f);
    er_ui_color4_t amount = row->positive ? colors.success : colors.text;
    status = er_ui_ledger_rect(scene, tile, 7.0f, colors.field);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_icon(scene, er_ui_bounds(tile.x + 8.0f, tile.y + 8.0f, 16.0f, 16.0f), row->icon, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->name, bounds.x + 60.0f, y + 20.0f, colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->kind, bounds.x + 60.0f, y + 40.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->date, bounds.x + bounds.w - 210.0f, y + 28.0f, colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_text(scene, font, row->amount, bounds.x + bounds.w - 116.0f, y + 28.0f, amount);
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
    {"Email Address", "artist@studio.inc"},
    {"Password", "************"}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors, "Account Access", 0);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 76.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font, er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 48.0f, bounds.w - 32.0f,
                                                       ER_UI_LEDGER_BUTTON_H),
                             colors, "Update Security", ER_UI_LEDGER_TRANSFER_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_transfer_card(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors) {
  er_ui_ledger_field_row_t rows[] = {
    {"Amount", "$ 1,200.00"},
    {"From", "Main Checking"}
  };
  er_ui_status_t status = er_ui_ledger_card_with_header(scene, font, bounds, colors,
                                                        "Transfer Funds",
                                                        "Move money between accounts");
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_field_rows(scene, font, bounds, colors, rows, ER_UI_LEDGER_ARRAY_COUNT(rows), 88.0f, 72.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_button(scene, font, er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 48.0f, bounds.w - 32.0f,
                                                       ER_UI_LEDGER_BUTTON_H),
                             colors, "Schedule Transfer", ER_UI_LEDGER_TRANSFER_BUTTON_ID);
}

static er_ui_status_t er_ui_ledger_dashboard(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_ledger_colors_t colors,
  uint32_t focused_id) {
  float content_x = bounds.x + ER_UI_LEDGER_SIDE_W + ER_UI_LEDGER_MARGIN;
  float right_w = bounds.w >= 1180.0f ? ER_UI_LEDGER_RIGHT_W : 300.0f;
  float right_x = bounds.x + bounds.w - right_w - ER_UI_LEDGER_MARGIN;
  float main_w = right_x - content_x - ER_UI_LEDGER_GAP;
  if (main_w < ER_UI_LEDGER_MIN_MAIN_W) {
    main_w = bounds.w - content_x - ER_UI_LEDGER_MARGIN;
    right_w = 0.0f;
  }
  float top_y = bounds.y + ER_UI_LEDGER_MARGIN;
  float half_w = (main_w - ER_UI_LEDGER_GAP) * 0.5f;

  er_ui_status_t status = er_ui_ledger_sidebar(scene, font, er_ui_bounds(bounds.x, bounds.y, ER_UI_LEDGER_SIDE_W, bounds.h),
                                               colors, focused_id);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "Dashboard", content_x, top_y + 14.0f, colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_text(scene, font, "settlement, royalties, and device-local accounting", content_x, top_y + 38.0f, colors.muted);
  if (status != ER_UI_OK) return status;

  status = er_ui_ledger_contribution_card(scene, font, er_ui_bounds(content_x, top_y + 58.0f, half_w, 222.0f), colors);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_payout_card(scene, font, er_ui_bounds(content_x + half_w + ER_UI_LEDGER_GAP, top_y + 58.0f, half_w, 222.0f), colors);
  if (status != ER_UI_OK) return status;
  status = er_ui_ledger_transactions_card(scene, font, er_ui_bounds(content_x, top_y + 296.0f, main_w, 306.0f), colors);
  if (status != ER_UI_OK) return status;

  if (right_w > 0.0f) {
    status = er_ui_ledger_targets_card(scene, font, er_ui_bounds(right_x, top_y, right_w, 300.0f), colors);
    if (status != ER_UI_OK) return status;
    status = er_ui_ledger_invest_card(scene, font, er_ui_bounds(right_x, top_y + 316.0f, right_w, 286.0f), colors);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
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
  status = er_ui_ledger_transfer_card(scene, font,
                                      er_ui_bounds(layout.content_x, bounds.y + 72.0f,
                                                   layout.content_w * 0.48f, 286.0f),
                                      colors);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_transactions_card(scene, font,
                                        er_ui_bounds(layout.content_x, bounds.y + 374.0f,
                                                     layout.content_w, 306.0f),
                                        colors);
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
  status = er_ui_ledger_access_card(scene, font,
                                    er_ui_bounds(layout.content_x, bounds.y + 72.0f,
                                                 layout.content_w * 0.48f, 286.0f),
                                    colors);
  if (status != ER_UI_OK) return status;
  return er_ui_ledger_targets_card(scene, font,
                                   er_ui_bounds(layout.content_x + layout.content_w * 0.52f,
                                                bounds.y + 72.0f,
                                                layout.content_w * 0.48f, 300.0f),
                                   colors);
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

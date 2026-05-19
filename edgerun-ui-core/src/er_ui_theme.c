#include "er_ui_theme.h"

#define ER_UI_RGB_BLACK 0u, 0u, 0u
#define ER_UI_RGB_SLATE_50 250u, 250u, 250u
#define ER_UI_RGB_SLATE_400 161u, 161u, 170u
#define ER_UI_RGB_SLATE_700 63u, 63u, 70u
#define ER_UI_RGB_SLATE_800 39u, 39u, 42u
#define ER_UI_RGB_SLATE_900 24u, 24u, 27u
#define ER_UI_RGB_SLATE_950 9u, 9u, 11u
#define ER_UI_RGB_SKY_50 240u, 249u, 255u
#define ER_UI_RGB_CYAN_600 8u, 145u, 178u
#define ER_UI_RGB_EMERALD_500 16u, 185u, 129u
#define ER_UI_RGB_AMBER_500 245u, 158u, 11u
#define ER_UI_RGB_VIOLET_500 139u, 92u, 246u
#define ER_UI_RGB_ROSE_600 225u, 29u, 72u
#define ER_UI_RGB_DESIGN_NEUTRAL_BACKGROUND 10u, 10u, 10u
#define ER_UI_RGB_DESIGN_NEUTRAL_CARD 23u, 23u, 23u
#define ER_UI_RGB_DESIGN_NEUTRAL_FOREGROUND 250u, 250u, 250u
#define ER_UI_RGB_DESIGN_NEUTRAL_PRIMARY 229u, 229u, 229u
#define ER_UI_RGB_DESIGN_NEUTRAL_SECONDARY 38u, 38u, 38u
#define ER_UI_RGB_DESIGN_NEUTRAL_MUTED_FOREGROUND 161u, 161u, 161u
#define ER_UI_RGB_DESIGN_NEUTRAL_RING 115u, 115u, 115u
#define ER_UI_RGB_DESIGN_CHART_1 38u, 38u, 38u
#define ER_UI_RGB_DESIGN_CHART_2 82u, 82u, 82u
#define ER_UI_RGB_DESIGN_CHART_3 115u, 115u, 115u
#define ER_UI_RGB_DESIGN_CHART_4 161u, 161u, 161u
#define ER_UI_RGB_DESIGN_CHART_5 229u, 229u, 229u

static const float ER_UI_RADIUS_NONE_VALUE = 0.0f;
static const float ER_UI_RADIUS_COMPACT_CONTROL = 6.0f;
static const float ER_UI_RADIUS_COMPACT_CARD = 8.0f;
static const float ER_UI_RADIUS_COMPACT_PANEL = 8.0f;
static const float ER_UI_RADIUS_DEFAULT_CONTROL = 8.0f;
static const float ER_UI_RADIUS_DEFAULT_CARD = 14.0f;
static const float ER_UI_RADIUS_DEFAULT_PANEL = 14.0f;
static const float ER_UI_RADIUS_SOFT_CONTROL = 14.0f;
static const float ER_UI_RADIUS_SOFT_PANEL = 18.0f;
static const float ER_UI_RADIUS_PILL = 999.0f;
static const float ER_UI_DESIGN_BORDER_ALPHA = 0.10f;
static const float ER_UI_DESIGN_INPUT_ALPHA = 0.15f;
static const float ER_UI_DESIGN_INPUT_FILL_ALPHA = 0.30f;
static const float ER_UI_DESIGN_ACTIVE_ALPHA = 0.50f;
static const float ER_UI_ACCENT_ACTIVE_ALPHA = 0.42f;
static const float ER_UI_DESIGN_RADIUS_SM = 6.0f;
static const float ER_UI_DESIGN_RADIUS_MD = 8.0f;
static const float ER_UI_DESIGN_RADIUS_LG = 10.0f;
static const float ER_UI_DESIGN_RADIUS_XL = 14.0f;
static const float ER_UI_DESIGN_CARD_PAD = 24.0f;
static const float ER_UI_DESIGN_CARD_GAP = 24.0f;
static const float ER_UI_DESIGN_FIELD_GAP = 12.0f;
static const float ER_UI_DESIGN_CONTROL_H = 36.0f;
static const float ER_UI_DESIGN_CONTROL_PAD_X = 10.0f;
static const float ER_UI_DESIGN_BUTTON_H_SM = 32.0f;
static const float ER_UI_DESIGN_BUTTON_H_LG = 40.0f;
static const float ER_UI_DESIGN_PROGRESS_H = 6.0f;
static const float ER_UI_DESIGN_SLIDER_THUMB = 16.0f;

er_ui_color4_t er_ui_palette_black(void) { return er_ui_color_rgb_u8(ER_UI_RGB_BLACK); }
er_ui_color4_t er_ui_palette_slate_50(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_50); }
er_ui_color4_t er_ui_palette_slate_400(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_400); }
er_ui_color4_t er_ui_palette_slate_700(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_700); }
er_ui_color4_t er_ui_palette_slate_800(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_800); }
er_ui_color4_t er_ui_palette_slate_900(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_900); }
er_ui_color4_t er_ui_palette_slate_950(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SLATE_950); }
er_ui_color4_t er_ui_palette_sky_50(void) { return er_ui_color_rgb_u8(ER_UI_RGB_SKY_50); }
er_ui_color4_t er_ui_palette_cyan_600(void) { return er_ui_color_rgb_u8(ER_UI_RGB_CYAN_600); }
er_ui_color4_t er_ui_palette_emerald_500(void) { return er_ui_color_rgb_u8(ER_UI_RGB_EMERALD_500); }
er_ui_color4_t er_ui_palette_amber_500(void) { return er_ui_color_rgb_u8(ER_UI_RGB_AMBER_500); }
er_ui_color4_t er_ui_palette_violet_500(void) { return er_ui_color_rgb_u8(ER_UI_RGB_VIOLET_500); }
er_ui_color4_t er_ui_palette_rose_600(void) { return er_ui_color_rgb_u8(ER_UI_RGB_ROSE_600); }

static er_ui_color4_t er_ui_palette_active_row(void) { return er_ui_color_with_alpha(er_ui_palette_slate_700(), 0.72f); }

er_ui_radius_preset_t er_ui_radius_preset_next(er_ui_radius_preset_t preset) {
  switch (preset) {
    case ER_UI_RADIUS_NONE: return ER_UI_RADIUS_COMPACT;
    case ER_UI_RADIUS_COMPACT: return ER_UI_RADIUS_DEFAULT;
    case ER_UI_RADIUS_DEFAULT: return ER_UI_RADIUS_SOFT;
    default: return ER_UI_RADIUS_NONE;
  }
}

er_ui_accent_preset_t er_ui_accent_preset_next(er_ui_accent_preset_t preset) {
  switch (preset) {
    case ER_UI_ACCENT_NEUTRAL: return ER_UI_ACCENT_CYAN;
    case ER_UI_ACCENT_CYAN: return ER_UI_ACCENT_BLUE;
    case ER_UI_ACCENT_BLUE: return ER_UI_ACCENT_GREEN;
    case ER_UI_ACCENT_GREEN: return ER_UI_ACCENT_VIOLET;
    case ER_UI_ACCENT_VIOLET: return ER_UI_ACCENT_AMBER;
    default: return ER_UI_ACCENT_NEUTRAL;
  }
}

er_ui_density_t er_ui_density_next(er_ui_density_t density) {
  switch (density) {
    case ER_UI_DENSITY_COMPACT: return ER_UI_DENSITY_SPACIOUS;
    case ER_UI_DENSITY_COMFORTABLE: return ER_UI_DENSITY_COMPACT;
    default: return ER_UI_DENSITY_COMFORTABLE;
  }
}

er_ui_color_scheme_t er_ui_color_scheme_next(er_ui_color_scheme_t scheme) {
  switch (scheme) {
    case ER_UI_COLOR_SCHEME_DARK: return ER_UI_COLOR_SCHEME_TERMINAL;
    case ER_UI_COLOR_SCHEME_TERMINAL: return ER_UI_COLOR_SCHEME_LIGHT;
    default: return ER_UI_COLOR_SCHEME_DARK;
  }
}

er_ui_color4_t er_ui_accent_color(er_ui_accent_preset_t accent) {
  switch (accent) {
    case ER_UI_ACCENT_NEUTRAL: return er_ui_palette_slate_400();
    case ER_UI_ACCENT_GREEN: return er_ui_palette_emerald_500();
    case ER_UI_ACCENT_VIOLET: return er_ui_palette_violet_500();
    case ER_UI_ACCENT_AMBER: return er_ui_palette_amber_500();
    case ER_UI_ACCENT_BLUE:
    case ER_UI_ACCENT_CYAN:
    default: return er_ui_palette_cyan_600();
  }
}

er_ui_radius_scale_t er_ui_radius_scale_from_preset(er_ui_radius_preset_t preset) {
  switch (preset) {
    case ER_UI_RADIUS_NONE: return (er_ui_radius_scale_t){ER_UI_RADIUS_NONE_VALUE, ER_UI_RADIUS_NONE_VALUE, ER_UI_RADIUS_NONE_VALUE, ER_UI_RADIUS_NONE_VALUE};
    case ER_UI_RADIUS_COMPACT: return (er_ui_radius_scale_t){ER_UI_RADIUS_COMPACT_CONTROL, ER_UI_RADIUS_COMPACT_CARD, ER_UI_RADIUS_COMPACT_PANEL, ER_UI_RADIUS_PILL};
    case ER_UI_RADIUS_SOFT: return (er_ui_radius_scale_t){ER_UI_RADIUS_SOFT_CONTROL, ER_UI_RADIUS_DEFAULT_CARD, ER_UI_RADIUS_SOFT_PANEL, ER_UI_RADIUS_PILL};
    case ER_UI_RADIUS_DEFAULT:
    default: return (er_ui_radius_scale_t){ER_UI_RADIUS_DEFAULT_CONTROL, ER_UI_RADIUS_DEFAULT_CARD, ER_UI_RADIUS_DEFAULT_PANEL, ER_UI_RADIUS_PILL};
  }
}

er_ui_semantic_colors_t er_ui_semantic_colors_with_accent(er_ui_semantic_colors_t colors, er_ui_color4_t accent) {
  colors.accent = accent;
  colors.active = er_ui_color_with_alpha(accent, ER_UI_ACCENT_ACTIVE_ALPHA);
  return colors;
}

er_ui_semantic_colors_t er_ui_semantic_colors_for_scheme(er_ui_color_scheme_t scheme) {
  er_ui_semantic_colors_t colors = {0};
  switch (scheme) {
    case ER_UI_COLOR_SCHEME_TERMINAL:
      colors.bg = er_ui_palette_black();
      colors.sidebar = er_ui_color_with_alpha(er_ui_palette_black(), 0.98f);
      colors.topbar = er_ui_color_with_alpha(er_ui_palette_slate_950(), 0.96f);
      colors.panel = er_ui_color_with_alpha(er_ui_palette_slate_950(), 0.94f);
      colors.row = er_ui_color_with_alpha(er_ui_palette_slate_900(), 0.78f);
      colors.active = er_ui_palette_active_row();
      colors.composer = er_ui_color_with_alpha(er_ui_palette_slate_950(), 0.98f);
      colors.text = er_ui_palette_slate_50();
      colors.muted = er_ui_palette_slate_400();
      colors.border = er_ui_color_with_alpha(er_ui_palette_emerald_500(), 0.34f);
      colors.accent = er_ui_palette_emerald_500();
      break;
    case ER_UI_COLOR_SCHEME_LIGHT:
      colors.bg = er_ui_palette_slate_50();
      colors.sidebar = er_ui_color_with_alpha(er_ui_palette_slate_50(), 0.98f);
      colors.topbar = er_ui_color_with_alpha(er_ui_palette_slate_50(), 0.96f);
      colors.panel = er_ui_color_with_alpha(er_ui_palette_slate_50(), 0.94f);
      colors.row = er_ui_color_with_alpha(er_ui_palette_slate_400(), 0.22f);
      colors.active = er_ui_palette_active_row();
      colors.composer = er_ui_color_with_alpha(er_ui_palette_slate_50(), 0.98f);
      colors.text = er_ui_palette_slate_950();
      colors.muted = er_ui_palette_slate_700();
      colors.border = er_ui_color_with_alpha(er_ui_palette_slate_400(), 0.52f);
      colors.accent = er_ui_palette_cyan_600();
      break;
    case ER_UI_COLOR_SCHEME_DARK:
    default:
      return er_ui_semantic_colors_from_design(er_ui_design_canonical());
      break;
  }
  colors.accent_text = er_ui_palette_sky_50();
  colors.success = er_ui_palette_emerald_500();
  colors.warning = er_ui_palette_amber_500();
  colors.danger = er_ui_palette_rose_600();
  colors.info = er_ui_palette_violet_500();
  return colors;
}

er_ui_design_colors_t er_ui_design_neutral_dark_colors(void) {
  er_ui_design_colors_t colors = {0};
  colors.background = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_BACKGROUND);
  colors.foreground = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_FOREGROUND);
  colors.card = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_CARD);
  colors.card_foreground = colors.foreground;
  colors.popover = colors.card;
  colors.popover_foreground = colors.foreground;
  colors.primary = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_PRIMARY);
  colors.primary_foreground = colors.card;
  colors.secondary = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_SECONDARY);
  colors.secondary_foreground = colors.foreground;
  colors.muted = colors.secondary;
  colors.muted_foreground = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_MUTED_FOREGROUND);
  colors.accent = colors.secondary;
  colors.accent_foreground = colors.foreground;
  colors.destructive = er_ui_palette_rose_600();
  colors.destructive_foreground = colors.foreground;
  colors.border = er_ui_color_rgba(1.0f, 1.0f, 1.0f, ER_UI_DESIGN_BORDER_ALPHA);
  colors.input = er_ui_color_rgba(1.0f, 1.0f, 1.0f, ER_UI_DESIGN_INPUT_ALPHA);
  colors.ring = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_NEUTRAL_RING);
  colors.sidebar = colors.card;
  colors.sidebar_foreground = colors.foreground;
  colors.sidebar_primary = colors.primary;
  colors.sidebar_primary_foreground = colors.primary_foreground;
  colors.sidebar_accent = colors.secondary;
  colors.sidebar_accent_foreground = colors.foreground;
  colors.sidebar_border = colors.border;
  colors.sidebar_ring = colors.ring;
  colors.chart_1 = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_CHART_1);
  colors.chart_2 = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_CHART_2);
  colors.chart_3 = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_CHART_3);
  colors.chart_4 = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_CHART_4);
  colors.chart_5 = er_ui_color_rgb_u8(ER_UI_RGB_DESIGN_CHART_5);
  return colors;
}

er_ui_design_radius_t er_ui_design_default_radius(void) {
  er_ui_design_radius_t radius = {ER_UI_DESIGN_RADIUS_SM, ER_UI_DESIGN_RADIUS_MD, ER_UI_DESIGN_RADIUS_LG, ER_UI_DESIGN_RADIUS_XL};
  return radius;
}

er_ui_design_metrics_t er_ui_design_default_metrics(void) {
  er_ui_design_metrics_t metrics = {0};
  metrics.card_pad_x = ER_UI_DESIGN_CARD_PAD;
  metrics.card_pad_y = ER_UI_DESIGN_CARD_PAD;
  metrics.card_gap = ER_UI_DESIGN_CARD_GAP;
  metrics.field_gap = ER_UI_DESIGN_FIELD_GAP;
  metrics.control_h = ER_UI_DESIGN_CONTROL_H;
  metrics.control_pad_x = ER_UI_DESIGN_CONTROL_PAD_X;
  metrics.button_h_sm = ER_UI_DESIGN_BUTTON_H_SM;
  metrics.button_h_default = ER_UI_DESIGN_CONTROL_H;
  metrics.button_h_lg = ER_UI_DESIGN_BUTTON_H_LG;
  metrics.icon_button = ER_UI_DESIGN_CONTROL_H;
  metrics.progress_h = ER_UI_DESIGN_PROGRESS_H;
  metrics.slider_thumb = ER_UI_DESIGN_SLIDER_THUMB;
  return metrics;
}

er_ui_design_system_t er_ui_design_canonical(void) {
  er_ui_design_system_t design = {0};
  design.colors = er_ui_design_neutral_dark_colors();
  design.radius = er_ui_design_default_radius();
  design.metrics = er_ui_design_default_metrics();
  return design;
}

er_ui_semantic_colors_t er_ui_semantic_colors_from_design(er_ui_design_system_t design) {
  er_ui_semantic_colors_t colors = {0};
  colors.bg = design.colors.background;
  colors.sidebar = design.colors.sidebar;
  colors.topbar = er_ui_color_with_alpha(design.colors.background, ER_UI_DESIGN_INPUT_FILL_ALPHA);
  colors.panel = design.colors.card;
  colors.row = design.colors.secondary;
  colors.active = er_ui_color_with_alpha(design.colors.muted, ER_UI_DESIGN_ACTIVE_ALPHA);
  colors.composer = er_ui_color_with_alpha(design.colors.input, ER_UI_DESIGN_INPUT_FILL_ALPHA);
  colors.text = design.colors.foreground;
  colors.muted = design.colors.muted_foreground;
  colors.border = design.colors.border;
  colors.accent = design.colors.primary;
  colors.accent_text = design.colors.primary_foreground;
  colors.success = er_ui_palette_emerald_500();
  colors.warning = er_ui_palette_amber_500();
  colors.danger = design.colors.destructive;
  colors.info = er_ui_palette_violet_500();
  return colors;
}

er_ui_style_preset_t er_ui_style_preset_user_default(void) {
  er_ui_style_preset_t preset = {ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT};
  return preset;
}

er_ui_style_preset_t er_ui_style_preset_author_vision(void) {
  er_ui_style_preset_t preset = {ER_UI_COLOR_SCHEME_TERMINAL, ER_UI_ACCENT_GREEN, ER_UI_RADIUS_COMPACT};
  return preset;
}

er_ui_resolved_theme_t er_ui_resolved_theme(er_ui_style_authority_t authority, er_ui_style_preset_t preset) {
  er_ui_resolved_theme_t theme = {0};
  theme.authority = authority;
  theme.preset = preset;
  theme.design = er_ui_design_canonical();
  theme.colors = er_ui_semantic_colors_for_scheme(preset.scheme);
  if (preset.accent != ER_UI_ACCENT_NEUTRAL) theme.colors = er_ui_semantic_colors_with_accent(theme.colors, er_ui_accent_color(preset.accent));
  theme.radius = er_ui_radius_scale_from_preset(preset.radius);
  theme.density = ER_UI_DENSITY_COMFORTABLE;
  return theme;
}

er_ui_resolved_theme_t er_ui_resolved_theme_user_default(void) {
  return er_ui_resolved_theme(ER_UI_STYLE_AUTHORITY_USER, er_ui_style_preset_user_default());
}

er_ui_color4_t er_ui_theme_color(er_ui_resolved_theme_t theme, er_ui_color_token_t token) {
  switch (token) {
    case ER_UI_COLOR_TOKEN_BG: return theme.colors.bg;
    case ER_UI_COLOR_TOKEN_SIDEBAR: return theme.colors.sidebar;
    case ER_UI_COLOR_TOKEN_TOPBAR: return theme.colors.topbar;
    case ER_UI_COLOR_TOKEN_PANEL: return theme.colors.panel;
    case ER_UI_COLOR_TOKEN_ROW: return theme.colors.row;
    case ER_UI_COLOR_TOKEN_ACTIVE: return theme.colors.active;
    case ER_UI_COLOR_TOKEN_COMPOSER: return theme.colors.composer;
    case ER_UI_COLOR_TOKEN_TEXT: return theme.colors.text;
    case ER_UI_COLOR_TOKEN_MUTED: return theme.colors.muted;
    case ER_UI_COLOR_TOKEN_BORDER: return theme.colors.border;
    case ER_UI_COLOR_TOKEN_ACCENT: return theme.colors.accent;
    case ER_UI_COLOR_TOKEN_ACCENT_TEXT: return theme.colors.accent_text;
    case ER_UI_COLOR_TOKEN_SUCCESS: return theme.colors.success;
    case ER_UI_COLOR_TOKEN_WARNING: return theme.colors.warning;
    case ER_UI_COLOR_TOKEN_DANGER: return theme.colors.danger;
    case ER_UI_COLOR_TOKEN_INFO:
    default: return theme.colors.info;
  }
}

er_ui_color4_t er_ui_design_theme_color(er_ui_resolved_theme_t theme, er_ui_design_color_token_t token) {
  switch (token) {
    case ER_UI_DESIGN_COLOR_BACKGROUND: return theme.design.colors.background;
    case ER_UI_DESIGN_COLOR_FOREGROUND: return theme.design.colors.foreground;
    case ER_UI_DESIGN_COLOR_CARD: return theme.design.colors.card;
    case ER_UI_DESIGN_COLOR_CARD_FOREGROUND: return theme.design.colors.card_foreground;
    case ER_UI_DESIGN_COLOR_POPOVER: return theme.design.colors.popover;
    case ER_UI_DESIGN_COLOR_POPOVER_FOREGROUND: return theme.design.colors.popover_foreground;
    case ER_UI_DESIGN_COLOR_PRIMARY: return theme.design.colors.primary;
    case ER_UI_DESIGN_COLOR_PRIMARY_FOREGROUND: return theme.design.colors.primary_foreground;
    case ER_UI_DESIGN_COLOR_SECONDARY: return theme.design.colors.secondary;
    case ER_UI_DESIGN_COLOR_SECONDARY_FOREGROUND: return theme.design.colors.secondary_foreground;
    case ER_UI_DESIGN_COLOR_MUTED: return theme.design.colors.muted;
    case ER_UI_DESIGN_COLOR_MUTED_FOREGROUND: return theme.design.colors.muted_foreground;
    case ER_UI_DESIGN_COLOR_ACCENT: return theme.design.colors.accent;
    case ER_UI_DESIGN_COLOR_ACCENT_FOREGROUND: return theme.design.colors.accent_foreground;
    case ER_UI_DESIGN_COLOR_DESTRUCTIVE: return theme.design.colors.destructive;
    case ER_UI_DESIGN_COLOR_DESTRUCTIVE_FOREGROUND: return theme.design.colors.destructive_foreground;
    case ER_UI_DESIGN_COLOR_BORDER: return theme.design.colors.border;
    case ER_UI_DESIGN_COLOR_INPUT: return theme.design.colors.input;
    case ER_UI_DESIGN_COLOR_RING: return theme.design.colors.ring;
    case ER_UI_DESIGN_COLOR_SIDEBAR: return theme.design.colors.sidebar;
    case ER_UI_DESIGN_COLOR_SIDEBAR_FOREGROUND: return theme.design.colors.sidebar_foreground;
    case ER_UI_DESIGN_COLOR_SIDEBAR_PRIMARY: return theme.design.colors.sidebar_primary;
    case ER_UI_DESIGN_COLOR_SIDEBAR_PRIMARY_FOREGROUND: return theme.design.colors.sidebar_primary_foreground;
    case ER_UI_DESIGN_COLOR_SIDEBAR_ACCENT: return theme.design.colors.sidebar_accent;
    case ER_UI_DESIGN_COLOR_SIDEBAR_ACCENT_FOREGROUND: return theme.design.colors.sidebar_accent_foreground;
    case ER_UI_DESIGN_COLOR_SIDEBAR_BORDER: return theme.design.colors.sidebar_border;
    case ER_UI_DESIGN_COLOR_SIDEBAR_RING: return theme.design.colors.sidebar_ring;
    case ER_UI_DESIGN_COLOR_CHART_1: return theme.design.colors.chart_1;
    case ER_UI_DESIGN_COLOR_CHART_2: return theme.design.colors.chart_2;
    case ER_UI_DESIGN_COLOR_CHART_3: return theme.design.colors.chart_3;
    case ER_UI_DESIGN_COLOR_CHART_4: return theme.design.colors.chart_4;
    case ER_UI_DESIGN_COLOR_CHART_5:
    default: return theme.design.colors.chart_5;
  }
}

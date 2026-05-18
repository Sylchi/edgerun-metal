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

static const float ER_UI_CARD_RADIUS_MAX = 8.0f;

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

static er_ui_color4_t er_ui_palette_bg(void) { return er_ui_palette_slate_950(); }
static er_ui_color4_t er_ui_palette_sidebar(void) { return er_ui_color_with_alpha(er_ui_palette_black(), 0.86f); }
static er_ui_color4_t er_ui_palette_topbar(void) { return er_ui_color_with_alpha(er_ui_palette_black(), 0.82f); }
static er_ui_color4_t er_ui_palette_row(void) { return er_ui_color_with_alpha(er_ui_palette_slate_800(), 0.62f); }
static er_ui_color4_t er_ui_palette_active_row(void) { return er_ui_color_with_alpha(er_ui_palette_slate_700(), 0.72f); }
static er_ui_color4_t er_ui_palette_panel(void) { return er_ui_color_with_alpha(er_ui_palette_slate_900(), 0.88f); }
static er_ui_color4_t er_ui_palette_composer(void) { return er_ui_color_with_alpha(er_ui_palette_slate_800(), 0.42f); }

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
    case ER_UI_RADIUS_NONE: return (er_ui_radius_scale_t){0.0f, 0.0f, 0.0f, 0.0f};
    case ER_UI_RADIUS_COMPACT: return (er_ui_radius_scale_t){6.0f, 6.0f, 8.0f, 999.0f};
    case ER_UI_RADIUS_SOFT: return (er_ui_radius_scale_t){14.0f, ER_UI_CARD_RADIUS_MAX, 18.0f, 999.0f};
    case ER_UI_RADIUS_DEFAULT:
    default: return (er_ui_radius_scale_t){10.0f, 8.0f, 12.0f, 999.0f};
  }
}

er_ui_semantic_colors_t er_ui_semantic_colors_with_accent(er_ui_semantic_colors_t colors, er_ui_color4_t accent) {
  colors.accent = accent;
  colors.active = er_ui_color_with_alpha(accent, 0.42f);
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
      colors.bg = er_ui_palette_bg();
      colors.sidebar = er_ui_palette_sidebar();
      colors.topbar = er_ui_palette_topbar();
      colors.panel = er_ui_palette_panel();
      colors.row = er_ui_palette_row();
      colors.active = er_ui_palette_active_row();
      colors.composer = er_ui_palette_composer();
      colors.text = er_ui_palette_slate_50();
      colors.muted = er_ui_palette_slate_400();
      colors.border = er_ui_color_with_alpha(er_ui_palette_slate_700(), 0.32f);
      colors.accent = er_ui_palette_cyan_600();
      break;
  }
  colors.accent_text = er_ui_palette_sky_50();
  colors.success = er_ui_palette_emerald_500();
  colors.warning = er_ui_palette_amber_500();
  colors.danger = er_ui_palette_rose_600();
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

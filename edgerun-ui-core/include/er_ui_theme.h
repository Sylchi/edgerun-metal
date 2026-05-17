#ifndef ER_UI_THEME_H
#define ER_UI_THEME_H

#include "er_ui_scene.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_STYLE_AUTHORITY_USER = 0,
  ER_UI_STYLE_AUTHORITY_AUTHOR_VISION
} er_ui_style_authority_t;

typedef enum {
  ER_UI_RADIUS_NONE = 0,
  ER_UI_RADIUS_COMPACT,
  ER_UI_RADIUS_DEFAULT,
  ER_UI_RADIUS_SOFT
} er_ui_radius_preset_t;

typedef enum {
  ER_UI_ACCENT_NEUTRAL = 0,
  ER_UI_ACCENT_CYAN,
  ER_UI_ACCENT_BLUE,
  ER_UI_ACCENT_GREEN,
  ER_UI_ACCENT_VIOLET,
  ER_UI_ACCENT_AMBER
} er_ui_accent_preset_t;

typedef enum {
  ER_UI_DENSITY_COMPACT = 0,
  ER_UI_DENSITY_COMFORTABLE,
  ER_UI_DENSITY_SPACIOUS
} er_ui_density_t;

typedef enum {
  ER_UI_COLOR_TOKEN_BG = 0,
  ER_UI_COLOR_TOKEN_SIDEBAR,
  ER_UI_COLOR_TOKEN_TOPBAR,
  ER_UI_COLOR_TOKEN_PANEL,
  ER_UI_COLOR_TOKEN_ROW,
  ER_UI_COLOR_TOKEN_ACTIVE,
  ER_UI_COLOR_TOKEN_COMPOSER,
  ER_UI_COLOR_TOKEN_TEXT,
  ER_UI_COLOR_TOKEN_MUTED,
  ER_UI_COLOR_TOKEN_BORDER,
  ER_UI_COLOR_TOKEN_ACCENT,
  ER_UI_COLOR_TOKEN_ACCENT_TEXT,
  ER_UI_COLOR_TOKEN_SUCCESS,
  ER_UI_COLOR_TOKEN_WARNING,
  ER_UI_COLOR_TOKEN_DANGER,
  ER_UI_COLOR_TOKEN_INFO
} er_ui_color_token_t;

typedef struct {
  er_ui_color4_t bg;
  er_ui_color4_t sidebar;
  er_ui_color4_t topbar;
  er_ui_color4_t panel;
  er_ui_color4_t row;
  er_ui_color4_t active;
  er_ui_color4_t composer;
  er_ui_color4_t text;
  er_ui_color4_t muted;
  er_ui_color4_t border;
  er_ui_color4_t accent;
  er_ui_color4_t accent_text;
  er_ui_color4_t success;
  er_ui_color4_t warning;
  er_ui_color4_t danger;
  er_ui_color4_t info;
} er_ui_semantic_colors_t;

typedef struct {
  float control;
  float card;
  float panel;
  float pill;
} er_ui_radius_scale_t;

typedef struct {
  er_ui_color_scheme_t scheme;
  er_ui_accent_preset_t accent;
  er_ui_radius_preset_t radius;
} er_ui_style_preset_t;

typedef struct {
  er_ui_style_authority_t authority;
  er_ui_style_preset_t preset;
  er_ui_semantic_colors_t colors;
  er_ui_radius_scale_t radius;
  er_ui_density_t density;
} er_ui_resolved_theme_t;

er_ui_color4_t er_ui_palette_black(void);
er_ui_color4_t er_ui_palette_slate_50(void);
er_ui_color4_t er_ui_palette_slate_400(void);
er_ui_color4_t er_ui_palette_slate_700(void);
er_ui_color4_t er_ui_palette_slate_800(void);
er_ui_color4_t er_ui_palette_slate_900(void);
er_ui_color4_t er_ui_palette_slate_950(void);
er_ui_color4_t er_ui_palette_sky_50(void);
er_ui_color4_t er_ui_palette_cyan_600(void);
er_ui_color4_t er_ui_palette_emerald_500(void);
er_ui_color4_t er_ui_palette_amber_500(void);
er_ui_color4_t er_ui_palette_violet_500(void);
er_ui_color4_t er_ui_palette_rose_600(void);

er_ui_radius_preset_t er_ui_radius_preset_next(er_ui_radius_preset_t preset);
er_ui_accent_preset_t er_ui_accent_preset_next(er_ui_accent_preset_t preset);
er_ui_density_t er_ui_density_next(er_ui_density_t density);
er_ui_color_scheme_t er_ui_color_scheme_next(er_ui_color_scheme_t scheme);
er_ui_color4_t er_ui_accent_color(er_ui_accent_preset_t accent);
er_ui_radius_scale_t er_ui_radius_scale_from_preset(er_ui_radius_preset_t preset);
er_ui_semantic_colors_t er_ui_semantic_colors_for_scheme(er_ui_color_scheme_t scheme);
er_ui_semantic_colors_t er_ui_semantic_colors_with_accent(er_ui_semantic_colors_t colors, er_ui_color4_t accent);
er_ui_style_preset_t er_ui_style_preset_user_default(void);
er_ui_style_preset_t er_ui_style_preset_author_vision(void);
er_ui_resolved_theme_t er_ui_resolved_theme(er_ui_style_authority_t authority, er_ui_style_preset_t preset);
er_ui_resolved_theme_t er_ui_resolved_theme_user_default(void);
er_ui_color4_t er_ui_theme_color(er_ui_resolved_theme_t theme, er_ui_color_token_t token);

#ifdef __cplusplus
}
#endif

#endif

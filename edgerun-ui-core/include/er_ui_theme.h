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

typedef enum {
  ER_UI_SHADCN_COLOR_BACKGROUND = 0,
  ER_UI_SHADCN_COLOR_FOREGROUND,
  ER_UI_SHADCN_COLOR_CARD,
  ER_UI_SHADCN_COLOR_CARD_FOREGROUND,
  ER_UI_SHADCN_COLOR_POPOVER,
  ER_UI_SHADCN_COLOR_POPOVER_FOREGROUND,
  ER_UI_SHADCN_COLOR_PRIMARY,
  ER_UI_SHADCN_COLOR_PRIMARY_FOREGROUND,
  ER_UI_SHADCN_COLOR_SECONDARY,
  ER_UI_SHADCN_COLOR_SECONDARY_FOREGROUND,
  ER_UI_SHADCN_COLOR_MUTED,
  ER_UI_SHADCN_COLOR_MUTED_FOREGROUND,
  ER_UI_SHADCN_COLOR_ACCENT,
  ER_UI_SHADCN_COLOR_ACCENT_FOREGROUND,
  ER_UI_SHADCN_COLOR_DESTRUCTIVE,
  ER_UI_SHADCN_COLOR_DESTRUCTIVE_FOREGROUND,
  ER_UI_SHADCN_COLOR_BORDER,
  ER_UI_SHADCN_COLOR_INPUT,
  ER_UI_SHADCN_COLOR_RING,
  ER_UI_SHADCN_COLOR_SIDEBAR,
  ER_UI_SHADCN_COLOR_SIDEBAR_FOREGROUND,
  ER_UI_SHADCN_COLOR_SIDEBAR_PRIMARY,
  ER_UI_SHADCN_COLOR_SIDEBAR_PRIMARY_FOREGROUND,
  ER_UI_SHADCN_COLOR_SIDEBAR_ACCENT,
  ER_UI_SHADCN_COLOR_SIDEBAR_ACCENT_FOREGROUND,
  ER_UI_SHADCN_COLOR_SIDEBAR_BORDER,
  ER_UI_SHADCN_COLOR_SIDEBAR_RING,
  ER_UI_SHADCN_COLOR_CHART_1,
  ER_UI_SHADCN_COLOR_CHART_2,
  ER_UI_SHADCN_COLOR_CHART_3,
  ER_UI_SHADCN_COLOR_CHART_4,
  ER_UI_SHADCN_COLOR_CHART_5
} er_ui_shadcn_color_token_t;

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
  er_ui_color4_t background;
  er_ui_color4_t foreground;
  er_ui_color4_t card;
  er_ui_color4_t card_foreground;
  er_ui_color4_t popover;
  er_ui_color4_t popover_foreground;
  er_ui_color4_t primary;
  er_ui_color4_t primary_foreground;
  er_ui_color4_t secondary;
  er_ui_color4_t secondary_foreground;
  er_ui_color4_t muted;
  er_ui_color4_t muted_foreground;
  er_ui_color4_t accent;
  er_ui_color4_t accent_foreground;
  er_ui_color4_t destructive;
  er_ui_color4_t destructive_foreground;
  er_ui_color4_t border;
  er_ui_color4_t input;
  er_ui_color4_t ring;
  er_ui_color4_t sidebar;
  er_ui_color4_t sidebar_foreground;
  er_ui_color4_t sidebar_primary;
  er_ui_color4_t sidebar_primary_foreground;
  er_ui_color4_t sidebar_accent;
  er_ui_color4_t sidebar_accent_foreground;
  er_ui_color4_t sidebar_border;
  er_ui_color4_t sidebar_ring;
  er_ui_color4_t chart_1;
  er_ui_color4_t chart_2;
  er_ui_color4_t chart_3;
  er_ui_color4_t chart_4;
  er_ui_color4_t chart_5;
} er_ui_shadcn_colors_t;

typedef struct {
  float control;
  float card;
  float panel;
  float pill;
} er_ui_radius_scale_t;

typedef struct {
  float sm;
  float md;
  float lg;
  float xl;
} er_ui_shadcn_radius_t;

typedef struct {
  float card_pad_x;
  float card_pad_y;
  float card_gap;
  float field_gap;
  float control_h;
  float control_pad_x;
  float button_h_sm;
  float button_h_default;
  float button_h_lg;
  float icon_button;
  float progress_h;
  float slider_thumb;
} er_ui_shadcn_metrics_t;

typedef struct {
  er_ui_shadcn_colors_t colors;
  er_ui_shadcn_radius_t radius;
  er_ui_shadcn_metrics_t metrics;
} er_ui_shadcn_design_system_t;

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
  er_ui_shadcn_design_system_t shadcn;
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
er_ui_shadcn_colors_t er_ui_shadcn_neutral_dark_colors(void);
er_ui_shadcn_radius_t er_ui_shadcn_default_radius(void);
er_ui_shadcn_metrics_t er_ui_shadcn_vega_metrics(void);
er_ui_shadcn_design_system_t er_ui_shadcn_neutral_dark_vega(void);
er_ui_semantic_colors_t er_ui_semantic_colors_from_shadcn(er_ui_shadcn_design_system_t design);
er_ui_style_preset_t er_ui_style_preset_user_default(void);
er_ui_style_preset_t er_ui_style_preset_author_vision(void);
er_ui_resolved_theme_t er_ui_resolved_theme(er_ui_style_authority_t authority, er_ui_style_preset_t preset);
er_ui_resolved_theme_t er_ui_resolved_theme_user_default(void);
er_ui_color4_t er_ui_theme_color(er_ui_resolved_theme_t theme, er_ui_color_token_t token);
er_ui_color4_t er_ui_shadcn_theme_color(er_ui_resolved_theme_t theme, er_ui_shadcn_color_token_t token);

#ifdef __cplusplus
}
#endif

#endif

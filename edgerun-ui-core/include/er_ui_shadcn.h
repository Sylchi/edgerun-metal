#ifndef ER_UI_SHADCN_H
#define ER_UI_SHADCN_H

#include "er_ui_scene.h"

/*
 * Neutral dark tokens from ui/shadcn-ui/apps/v4/registry/themes.ts and
 * component values from ui/shadcn-ui/apps/v4/registry/styles/style-vega.css.
 */

#define ER_UI_SHADCN_RADIUS_MD 8.0f
#define ER_UI_SHADCN_RADIUS_XL 14.0f
#define ER_UI_SHADCN_CONTROL_H 36.0f
#define ER_UI_SHADCN_CARD_PAD_X 24.0f
#define ER_UI_SHADCN_CARD_PAD_Y 24.0f
#define ER_UI_SHADCN_CARD_GAP 24.0f
#define ER_UI_SHADCN_FIELD_GAP 12.0f
#define ER_UI_SHADCN_NEUTRAL_DARK_BACKGROUND_RGB 10u, 10u, 10u
#define ER_UI_SHADCN_NEUTRAL_DARK_CARD_RGB 23u, 23u, 23u
#define ER_UI_SHADCN_NEUTRAL_DARK_FOREGROUND_RGB 250u, 250u, 250u
#define ER_UI_SHADCN_NEUTRAL_DARK_PRIMARY_RGB 229u, 229u, 229u
#define ER_UI_SHADCN_NEUTRAL_DARK_PRIMARY_FOREGROUND_RGB 23u, 23u, 23u
#define ER_UI_SHADCN_NEUTRAL_DARK_SECONDARY_RGB 38u, 38u, 38u
#define ER_UI_SHADCN_NEUTRAL_DARK_MUTED_FOREGROUND_RGB 161u, 161u, 161u
#define ER_UI_SHADCN_NEUTRAL_DARK_SUBTLE_FOREGROUND_RGB 115u, 115u, 115u
#define ER_UI_SHADCN_NEUTRAL_DARK_RING_RGB 115u, 115u, 115u

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_background(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_BACKGROUND_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_card(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_CARD_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_foreground(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_FOREGROUND_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_primary(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_PRIMARY_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_primary_foreground(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_PRIMARY_FOREGROUND_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_secondary(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_SECONDARY_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_muted_foreground(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_MUTED_FOREGROUND_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_subtle_foreground(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_SUBTLE_FOREGROUND_RGB);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_border(void) {
  return er_ui_color_rgba(1.0f, 1.0f, 1.0f, 0.10f);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_input(void) {
  return er_ui_color_rgba(1.0f, 1.0f, 1.0f, 0.15f);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_input_fill(void) {
  return er_ui_color_rgba(1.0f, 1.0f, 1.0f, 0.045f);
}

static inline er_ui_color4_t er_ui_shadcn_neutral_dark_ring(void) {
  return er_ui_color_rgb_u8(ER_UI_SHADCN_NEUTRAL_DARK_RING_RGB);
}

#endif

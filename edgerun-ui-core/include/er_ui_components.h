#ifndef ER_UI_COMPONENTS_H
#define ER_UI_COMPONENTS_H

#include "er_ui_primitives.h"
#include "er_ui_runtime.h"
#include "er_ui_text.h"
#include "er_ui_theme.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_SHADCN_CATEGORY_FOUNDATION = 0,
  ER_UI_SHADCN_CATEGORY_FORM,
  ER_UI_SHADCN_CATEGORY_OVERLAY,
  ER_UI_SHADCN_CATEGORY_NAVIGATION,
  ER_UI_SHADCN_CATEGORY_DATA_DISPLAY,
  ER_UI_SHADCN_CATEGORY_FEEDBACK,
  ER_UI_SHADCN_CATEGORY_LAYOUT,
  ER_UI_SHADCN_CATEGORY_MEDIA
} er_ui_shadcn_demo_category_t;

typedef enum {
  ER_UI_SHADCN_STATUS_CATALOGED = 0,
  ER_UI_SHADCN_STATUS_NATIVE_PRIMITIVE,
  ER_UI_SHADCN_STATUS_EXACT_PORT
} er_ui_shadcn_demo_status_t;

typedef enum {
  ER_UI_SHADCN_RESOLVE_SLUG = 0,
  ER_UI_SHADCN_RESOLVE_SOURCE_COMPONENT,
  ER_UI_SHADCN_RESOLVE_MODULE_PATH,
  ER_UI_SHADCN_RESOLVE_SLOT
} er_ui_shadcn_resolve_kind_t;

typedef enum {
  ER_UI_SHADCN_BUTTON_DEFAULT = 0,
  ER_UI_SHADCN_BUTTON_DESTRUCTIVE,
  ER_UI_SHADCN_BUTTON_OUTLINE,
  ER_UI_SHADCN_BUTTON_SECONDARY,
  ER_UI_SHADCN_BUTTON_GHOST,
  ER_UI_SHADCN_BUTTON_LINK
} er_ui_shadcn_button_variant_t;

typedef enum {
  ER_UI_SHADCN_BUTTON_SIZE_DEFAULT = 0,
  ER_UI_SHADCN_BUTTON_SIZE_SM,
  ER_UI_SHADCN_BUTTON_SIZE_LG,
  ER_UI_SHADCN_BUTTON_SIZE_ICON
} er_ui_shadcn_button_size_t;

typedef enum {
  ER_UI_SHADCN_BADGE_DEFAULT = 0,
  ER_UI_SHADCN_BADGE_SECONDARY,
  ER_UI_SHADCN_BADGE_DESTRUCTIVE,
  ER_UI_SHADCN_BADGE_OUTLINE
} er_ui_shadcn_badge_variant_t;

typedef struct {
  const char* name;
  const char* slug;
  const char* route;
  er_ui_shadcn_demo_category_t category;
  const char* source_component;
  const char* edge_builder;
  const char* const* slots;
  size_t slot_count;
  const char* const* states;
  size_t state_count;
  er_ui_shadcn_demo_status_t status;
} er_ui_shadcn_demo_spec_t;

typedef struct {
  const er_ui_shadcn_demo_spec_t* spec;
  er_ui_shadcn_resolve_kind_t kind;
} er_ui_shadcn_resolved_demo_t;

typedef struct {
  const char* identifier;
  er_ui_shadcn_resolve_kind_t resolve_kind;
  const char* slug;
  const char* source_component;
  const char* edge_builder;
  er_ui_shadcn_demo_category_t category;
  er_ui_shadcn_demo_status_t status;
  bool native_renderer;
  bool exact_port;
} er_ui_shadcn_port_mapping_t;

typedef struct {
  const char* slug;
  const char* const* slots;
  size_t slot_count;
  const char* const* states;
  size_t state_count;
  const char* const* variants;
  size_t variant_count;
  const char* const* interactions;
  size_t interaction_count;
  const char* const* keyboard;
  size_t keyboard_count;
  const char* aria_pattern;
  bool compound;
} er_ui_shadcn_parity_contract_t;

#define ER_UI_SHADCN_DEMO_COUNT 57u
#define ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID 18000u
#define ER_UI_SHADCN_SELECT_CURRENCY_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1100u)
#define ER_UI_SHADCN_SELECT_ORDER_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1120u)
#define ER_UI_SHADCN_SELECT_TICKER_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1140u)
#define ER_UI_SHADCN_CHART_CONTRIBUTION_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1200u)
#define ER_UI_SHADCN_CHART_STOCK_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1220u)
#define ER_UI_SHADCN_CHART_POWER_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1240u)
#define ER_UI_SHADCN_SELECT_PREFERRED_CURRENCY_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 942u)
#define ER_UI_SHADCN_SELECT_ORDER_TYPE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 946u)
#define ER_UI_SHADCN_SELECT_DEFAULT_CURRENCY_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 968u)
#define ER_UI_SHADCN_SELECT_TICKER_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1056u)
#define ER_UI_SHADCN_GALLERY_SLIDER_CAPACITY 32u
#define ER_UI_SHADCN_SHOWCASE_ROW_BASE_ID (ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 3000u)

typedef struct {
  uint32_t id;
  float value;
} er_ui_shadcn_slider_value_t;

typedef struct {
  bool has_open_select;
  uint32_t open_select;
  size_t currency_index;
  size_t order_index;
  size_t ticker_index;
  size_t contribution_bar;
  size_t stock_bar;
  size_t power_bar;
  er_ui_shadcn_slider_value_t sliders[ER_UI_SHADCN_GALLERY_SLIDER_CAPACITY];
  size_t slider_count;
} er_ui_shadcn_demo_gallery_state_t;

const char* er_ui_shadcn_demo_category_label(er_ui_shadcn_demo_category_t category);
const char* er_ui_shadcn_demo_status_label(er_ui_shadcn_demo_status_t status);
const char* er_ui_shadcn_resolve_kind_label(er_ui_shadcn_resolve_kind_t kind);
const er_ui_shadcn_demo_spec_t* er_ui_shadcn_demo_at(size_t index);
size_t er_ui_shadcn_demo_count(void);
bool er_ui_shadcn_demo_has_native_renderer(const er_ui_shadcn_demo_spec_t* spec);
bool er_ui_shadcn_demo_is_exact_port(const er_ui_shadcn_demo_spec_t* spec);
bool er_ui_shadcn_demo_uses_slot(const er_ui_shadcn_demo_spec_t* spec, const char* slot);
bool er_ui_shadcn_demo_uses_state(const er_ui_shadcn_demo_spec_t* spec, const char* state);
const er_ui_shadcn_demo_spec_t* er_ui_shadcn_find_demo_by_slug(const char* slug);
const er_ui_shadcn_demo_spec_t* er_ui_shadcn_find_demo_by_source_component(const char* source_component);
bool er_ui_shadcn_resolve_demo_identifier(const char* identifier, er_ui_shadcn_resolved_demo_t* out_resolved);
bool er_ui_shadcn_port_mapping_for_identifier(const char* identifier, er_ui_shadcn_port_mapping_t* out_mapping);
size_t er_ui_shadcn_native_demo_count(void);
size_t er_ui_shadcn_exact_demo_count(void);
size_t er_ui_shadcn_exact_parity_count(void);
size_t er_ui_shadcn_count_by_category(er_ui_shadcn_demo_category_t category);
size_t er_ui_shadcn_count_by_status(er_ui_shadcn_demo_status_t status);
bool er_ui_shadcn_parity_contract_for_slug(const char* slug, er_ui_shadcn_parity_contract_t* out_contract);
bool er_ui_shadcn_contract_supports_slot(const er_ui_shadcn_parity_contract_t* contract, const char* slot);
bool er_ui_shadcn_contract_supports_state(const er_ui_shadcn_parity_contract_t* contract, const char* state);
bool er_ui_shadcn_contract_supports_variant(const er_ui_shadcn_parity_contract_t* contract, const char* variant);
bool er_ui_shadcn_contract_supports_interaction(const er_ui_shadcn_parity_contract_t* contract, const char* interaction);
void er_ui_shadcn_demo_gallery_state_init(er_ui_shadcn_demo_gallery_state_t* state);
bool er_ui_shadcn_demo_gallery_apply_action(er_ui_shadcn_demo_gallery_state_t* state, er_ui_action_t action);
bool er_ui_shadcn_demo_gallery_select_open(const er_ui_shadcn_demo_gallery_state_t* state, uint32_t id);
float er_ui_shadcn_demo_gallery_slider(const er_ui_shadcn_demo_gallery_state_t* state, uint32_t id, float fallback);
size_t er_ui_shadcn_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index);
bool er_ui_shadcn_component_preview_available(const char* slug);
bool er_ui_shadcn_demo_preview_available(const char* slug);
bool er_ui_shadcn_component_preview_available_by_source_component(const char* source_component);
bool er_ui_shadcn_component_preview_available_by_identifier(const char* identifier);
bool er_ui_shadcn_demo_preview_available_by_identifier(const char* identifier);
er_ui_bounds_t er_ui_shadcn_button_bounds(er_ui_bounds_t bounds, er_ui_shadcn_button_size_t size);
er_ui_status_t er_ui_shadcn_card_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_shadcn_button_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  uint32_t id,
  er_ui_shadcn_button_variant_t variant,
  er_ui_shadcn_button_size_t size,
  bool active);
er_ui_status_t er_ui_shadcn_select_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool open);
er_ui_status_t er_ui_shadcn_slider_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  float value,
  uint32_t id);
er_ui_status_t er_ui_shadcn_badge_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_shadcn_badge_variant_t variant);
er_ui_status_t er_ui_shadcn_field_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool text_area);
er_ui_status_t er_ui_shadcn_checkbox_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool checked,
  uint32_t id);
er_ui_status_t er_ui_shadcn_progress_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, float value);
er_ui_status_t er_ui_shadcn_switch_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, bool checked, uint32_t id);
er_ui_status_t er_ui_shadcn_separator_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_shadcn_tabs_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_status_t er_ui_shadcn_list_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail,
  uint32_t id,
  bool selected);
er_ui_status_t er_ui_shadcn_radio_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool selected,
  uint32_t id);
er_ui_status_t er_ui_shadcn_table_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* headers,
  size_t header_count,
  const char* const* cells,
  size_t row_count,
  uint32_t id_base);
er_ui_status_t er_ui_shadcn_skeleton_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_shadcn_toast_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* message,
  er_ui_color4_t accent);
er_ui_status_t er_ui_shadcn_empty_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body);
er_ui_status_t er_ui_shadcn_alert_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent);
er_ui_status_t er_ui_shadcn_avatar_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_color4_t color,
  bool online);
er_ui_status_t er_ui_shadcn_breadcrumb_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_status_t er_ui_shadcn_command_palette_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* placeholder,
  uint32_t id);
er_ui_status_t er_ui_shadcn_bar_chart_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* const* labels,
  const float* values,
  size_t value_count,
  uint32_t base_id,
  size_t selected);
bool er_ui_shadcn_component_scene_preview_available(const char* slug);
er_ui_status_t er_ui_shadcn_component_scene_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* slug,
  const er_ui_shadcn_demo_gallery_state_t* state);
er_ui_status_t er_ui_shadcn_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* selected_slug,
  const er_ui_shadcn_demo_gallery_state_t* state);

#ifdef __cplusplus
}
#endif

#endif

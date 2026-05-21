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
  ER_UI_COMPONENT_BUTTON_DEFAULT = 0,
  ER_UI_COMPONENT_BUTTON_DESTRUCTIVE,
  ER_UI_COMPONENT_BUTTON_OUTLINE,
  ER_UI_COMPONENT_BUTTON_SECONDARY,
  ER_UI_COMPONENT_BUTTON_GHOST,
  ER_UI_COMPONENT_BUTTON_LINK
} er_ui_component_button_variant_t;

typedef enum {
  ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT = 0,
  ER_UI_COMPONENT_BUTTON_SIZE_SM,
  ER_UI_COMPONENT_BUTTON_SIZE_LG,
  ER_UI_COMPONENT_BUTTON_SIZE_ICON
} er_ui_component_button_size_t;

typedef enum {
  ER_UI_COMPONENT_STATE_DEFAULT = 0,
  ER_UI_COMPONENT_STATE_HOVER,
  ER_UI_COMPONENT_STATE_FOCUS,
  ER_UI_COMPONENT_STATE_ACTIVE,
  ER_UI_COMPONENT_STATE_DISABLED,
  ER_UI_COMPONENT_STATE_LOADING,
  ER_UI_COMPONENT_STATE_ERROR
} er_ui_component_state_t;

typedef enum {
  ER_UI_COMPONENT_A11Y_GENERIC = 0,
  ER_UI_COMPONENT_A11Y_GROUP,
  ER_UI_COMPONENT_A11Y_BUTTON,
  ER_UI_COMPONENT_A11Y_DIALOG,
  ER_UI_COMPONENT_A11Y_LIST_ITEM,
  ER_UI_COMPONENT_A11Y_STATUS,
  ER_UI_COMPONENT_A11Y_TAB_LIST
} er_ui_component_a11y_role_t;

typedef enum {
  ER_UI_COMPONENT_BADGE_DEFAULT = 0,
  ER_UI_COMPONENT_BADGE_SECONDARY,
  ER_UI_COMPONENT_BADGE_DESTRUCTIVE,
  ER_UI_COMPONENT_BADGE_OUTLINE
} er_ui_component_badge_variant_t;

#define ER_UI_COMPONENT_STATE_COUNT 7u
const char* er_ui_component_state_label(er_ui_component_state_t state);
const er_ui_component_state_t* er_ui_component_states(size_t* out_count);
const char* er_ui_component_a11y_role_label(er_ui_component_a11y_role_t role);
er_ui_bounds_t er_ui_component_button_bounds(er_ui_bounds_t bounds, er_ui_component_button_size_t size);
er_ui_status_t er_ui_component_card_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_button_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  uint32_t id,
  er_ui_component_button_variant_t variant,
  er_ui_component_button_size_t size,
  bool active);
er_ui_status_t er_ui_component_select_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool open);
er_ui_status_t er_ui_component_select_static_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  bool open);
er_ui_status_t er_ui_component_slider_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  float value,
  uint32_t id);
er_ui_status_t er_ui_component_badge_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_component_badge_variant_t variant);
er_ui_status_t er_ui_component_field_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool text_area);
er_ui_status_t er_ui_component_field_static_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  bool text_area);
er_ui_status_t er_ui_component_checkbox_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool checked,
  uint32_t id);
er_ui_status_t er_ui_component_progress_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float value);
er_ui_status_t er_ui_component_switch_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  bool checked,
  uint32_t id);
er_ui_status_t er_ui_component_separator_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_tabs_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_status_t er_ui_component_list_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail,
  uint32_t id,
  bool selected);
er_ui_status_t er_ui_component_radio_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool selected,
  uint32_t id);
er_ui_status_t er_ui_component_table_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* headers,
  size_t header_count,
  const char* const* cells,
  size_t row_count,
  uint32_t id_base);
er_ui_status_t er_ui_component_invoice_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* invoice,
  const char* due,
  const char* status_text,
  const char* const* items,
  const char* const* quantities,
  const char* const* rates,
  const char* const* amounts,
  size_t row_count,
  const char* subtotal,
  const char* tax,
  const char* total,
  const char* secondary_action,
  const char* primary_action,
  uint32_t id_base);
er_ui_status_t er_ui_component_skeleton_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_spinner_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_toast_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* message,
  er_ui_color4_t accent);
er_ui_status_t er_ui_component_empty_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body);
er_ui_status_t er_ui_component_tooltip_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* text);
er_ui_status_t er_ui_component_dialog_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent);
er_ui_status_t er_ui_component_progress_ring_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float value,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_alert_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent);
er_ui_status_t er_ui_component_avatar_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_color4_t color,
  bool online);
er_ui_status_t er_ui_component_breadcrumb_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_status_t er_ui_component_command_palette_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* placeholder,
  uint32_t id);
er_ui_status_t er_ui_component_tree_item_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  uint8_t depth,
  bool expanded,
  uint32_t id);
er_ui_status_t er_ui_component_section_header_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail);
er_ui_status_t er_ui_component_identity_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* node,
  const char* policy,
  uint32_t id);
er_ui_status_t er_ui_component_contact_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* detail,
  uint32_t id);
er_ui_status_t er_ui_component_thread_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* last_message,
  bool unread,
  uint32_t id);
er_ui_status_t er_ui_component_attachment_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* kind,
  uint32_t id);
er_ui_status_t er_ui_component_capability_grant_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* app,
  const char* capability,
  const char* state,
  uint32_t id);
er_ui_status_t er_ui_component_proof_event_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* hash,
  const char* status_text,
  uint32_t id);
er_ui_status_t er_ui_component_route_path_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* const* hops,
  size_t hop_count);
er_ui_status_t er_ui_component_package_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* policy,
  const char* hash,
  uint32_t id);
er_ui_status_t er_ui_component_receipt_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* amount,
  const char* status_text,
  uint32_t id);
er_ui_status_t er_ui_component_panel_header_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* subtitle,
  const char* action_label,
  uint32_t action_id);
er_ui_status_t er_ui_component_metric_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* value,
  const char* detail,
  bool has_progress,
  float progress,
  er_ui_color4_t accent);
er_ui_status_t er_ui_component_transaction_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* subtitle,
  const char* date,
  const char* amount,
  bool positive,
  uint32_t id);
er_ui_status_t er_ui_component_menu_item_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  const char* badge,
  bool selected,
  er_ui_color4_t accent,
  uint32_t id);
er_ui_status_t er_ui_component_control_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  const char* accessory,
  uint32_t id);
er_ui_status_t er_ui_component_bar_chart_emit(
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
er_ui_status_t er_ui_network_app_prompt_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* app_name,
  const char* package_size,
  const char* retrieval_cost,
  const char* policy_hash,
  uint32_t run_once_id,
  uint32_t verify_cache_id,
  uint32_t cancel_id);
#ifdef __cplusplus
}
#endif

#endif

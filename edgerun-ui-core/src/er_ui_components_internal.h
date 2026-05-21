#ifndef ER_UI_COMPONENTS_INTERNAL_H
#define ER_UI_COMPONENTS_INTERNAL_H

#include "er_ui_components.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"
#include "er_math.h"

typedef enum {
  ER_UI_COMPONENT_CATEGORY_FOUNDATION = 0,
  ER_UI_COMPONENT_CATEGORY_FORM,
  ER_UI_COMPONENT_CATEGORY_OVERLAY,
  ER_UI_COMPONENT_CATEGORY_NAVIGATION,
  ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
  ER_UI_COMPONENT_CATEGORY_FEEDBACK,
  ER_UI_COMPONENT_CATEGORY_LAYOUT,
  ER_UI_COMPONENT_CATEGORY_MEDIA
} er_ui_component_category_t;

typedef enum {
  ER_UI_COMPONENT_STATUS_CATALOGED = 0,
  ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE,
  ER_UI_COMPONENT_STATUS_EXACT_PORT
} er_ui_component_status_t;

typedef enum {
  ER_UI_COMPONENT_RESOLVE_SLUG = 0,
  ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT,
  ER_UI_COMPONENT_RESOLVE_MODULE_PATH,
  ER_UI_COMPONENT_RESOLVE_SLOT
} er_ui_component_resolve_kind_t;

typedef enum {
  ER_UI_COMPONENT_NETWORK_APP_PROMPT = 0,
  ER_UI_COMPONENT_APP_STORE_CARD,
  ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS,
  ER_UI_COMPONENT_RUNTIME_EVENT_ROW,
  ER_UI_COMPONENT_PACKAGE_PROOF_ROW,
  ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW,
  ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW,
  ER_UI_COMPONENT_NODE_INSTANCE_ROW,
  ER_UI_COMPONENT_ADMISSION_POLICY_ROW,
  ER_UI_COMPONENT_ROUTE_BUDGET_ROW,
  ER_UI_COMPONENT_DATA_TABLE_CONTROLS,
  ER_UI_COMPONENT_ICON_ONLY_BUTTON,
  ER_UI_COMPONENT_SEGMENTED_CONTROL,
  ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW,
  ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW,
  ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL
} er_ui_component_test_id_t;

typedef struct {
  const char* name;
  const char* slug;
  const char* route;
  er_ui_component_category_t category;
  const char* source_component;
  const char* edge_builder;
  const char* const* slots;
  size_t slot_count;
  const char* const* states;
  size_t state_count;
  er_ui_component_status_t status;
} er_ui_component_spec_t;

typedef struct {
  const er_ui_component_spec_t* spec;
  er_ui_component_resolve_kind_t kind;
} er_ui_component_resolved_t;

typedef struct {
  const char* identifier;
  er_ui_component_resolve_kind_t resolve_kind;
  const char* slug;
  const char* source_component;
  const char* edge_builder;
  er_ui_component_category_t category;
  er_ui_component_status_t status;
  bool native_renderer;
  bool exact_port;
} er_ui_component_port_mapping_t;

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
} er_ui_component_parity_contract_t;

typedef struct {
  const char* name;
  bool required;
} er_ui_component_projected_field_t;

typedef struct {
  er_ui_component_test_id_t component;
  const er_ui_component_projected_field_t* fields;
  size_t field_count;
} er_ui_component_projection_contract_t;

typedef struct {
  er_ui_component_test_id_t component;
  const er_ui_component_state_t* states;
  size_t state_count;
} er_ui_component_state_matrix_t;

typedef struct {
  er_ui_component_test_id_t component;
  er_ui_component_a11y_role_t role;
  const char* const* label_fields;
  size_t label_field_count;
} er_ui_component_accessibility_metadata_t;

#define ER_UI_COMPONENT_COUNT 59u
#define ER_UI_COMPONENT_CANONICAL_BASE_COUNT 55u
#define ER_UI_COMPONENT_TEST_ID_COUNT 16u
#define ER_UI_COMPONENT_PREVIEW_BASE_ID 18000u
#define ER_UI_COMPONENT_SELECT_CURRENCY_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1100u)
#define ER_UI_COMPONENT_SELECT_ORDER_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1120u)
#define ER_UI_COMPONENT_SELECT_TICKER_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1140u)
#define ER_UI_COMPONENT_CHART_CONTRIBUTION_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1200u)
#define ER_UI_COMPONENT_CHART_STOCK_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1220u)
#define ER_UI_COMPONENT_CHART_POWER_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1240u)
#define ER_UI_COMPONENT_SELECT_CURRENCY_COUNT 3u
#define ER_UI_COMPONENT_SELECT_ORDER_COUNT 3u
#define ER_UI_COMPONENT_SELECT_TICKER_COUNT 4u
#define ER_UI_COMPONENT_CHART_CONTRIBUTION_COUNT 7u
#define ER_UI_COMPONENT_CHART_STOCK_COUNT 8u
#define ER_UI_COMPONENT_CHART_POWER_COUNT 8u
#define ER_UI_COMPONENT_CHART_CONTRIBUTION_DEFAULT_INDEX 5u
#define ER_UI_COMPONENT_CHART_STOCK_DEFAULT_INDEX 5u
#define ER_UI_COMPONENT_CHART_POWER_DEFAULT_INDEX 6u
#define ER_UI_COMPONENT_SELECT_PREFERRED_CURRENCY_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 942u)
#define ER_UI_COMPONENT_SELECT_ORDER_TYPE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 946u)
#define ER_UI_COMPONENT_SELECT_DEFAULT_CURRENCY_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 968u)
#define ER_UI_COMPONENT_SELECT_TICKER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1056u)
#define ER_UI_COMPONENT_GALLERY_SLIDER_CAPACITY 32u
#define ER_UI_COMPONENT_SHOWCASE_ROW_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 3000u)

typedef struct {
  uint32_t id;
  float value;
} er_ui_component_slider_value_t;

typedef struct {
  bool has_open_select;
  uint32_t open_select;
  size_t currency_index;
  size_t order_index;
  size_t ticker_index;
  size_t contribution_bar;
  size_t stock_bar;
  size_t power_bar;
  er_ui_component_slider_value_t sliders[ER_UI_COMPONENT_GALLERY_SLIDER_CAPACITY];
  size_t slider_count;
} er_ui_component_gallery_state_t;

#define ER_UI_COMPONENT_TEXT_CAPACITY 128u
#define ER_UI_COMPONENT_SUFFIX_TSX_LEN 4u
#define ER_UI_COMPONENT_SUFFIX_TS_LEN 3u
#define ER_UI_COMPONENT_SUFFIX_JSX_LEN 4u
#define ER_UI_COMPONENT_SUFFIX_JS_LEN 3u
#define ER_UI_COMPONENT_EMPTY_COUNT 0u
#define ER_UI_COMPONENT_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_COMPONENT_SHOWCASE_MIN_LIST_W 160.0f
#define ER_UI_COMPONENT_SHOWCASE_PREFERRED_LIST_W 260.0f
#define ER_UI_COMPONENT_SHOWCASE_MIN_PREVIEW_W 220.0f
#define ER_UI_COMPONENT_SHOWCASE_INSET 16.0f
#define ER_UI_COMPONENT_SHOWCASE_STACKED_LIST_H 168.0f
#define ER_UI_COMPONENT_SHOWCASE_GRID_MIN_CARD_W 292.0f
#define ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS 4u
#define ER_UI_COMPONENT_SHOWCASE_GRID_GAP 18.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_H 250.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PAD 18.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_HEADER_H 54.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_W 190.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_H 110.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_DETAIL_MIN_H 64.0f
#define ER_UI_COMPONENT_SHOWCASE_SCROLL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 4200u)
#define ER_UI_COMPONENT_SHOWCASE_SCROLL_THUMB_MIN_H 48.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_X 12.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_Y 15.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_SIZE 28.0f
#define ER_UI_COMPONENT_ICON_ROW_TEXT_X 48.0f
#define ER_UI_COMPONENT_ICON_ROW_TITLE_Y 24.0f
#define ER_UI_COMPONENT_ICON_ROW_DETAIL_Y 46.0f
#define ER_UI_COMPONENT_ROW_SEPARATOR_H 1.0f
#define ER_UI_COMPONENT_TEXT_ADVANCE 7.0f
#define ER_UI_COMPONENT_TEXT_PAD_X 10.0f
#define ER_UI_COMPONENT_ROW_TEXT_PAD_RIGHT 12.0f
#define ER_UI_COMPONENT_CONTROL_ICON_RESERVED_W 34.0f
#define ER_UI_COMPONENT_BADGED_CARD_ICON_X 16.0f
#define ER_UI_COMPONENT_BADGED_CARD_ICON_Y 18.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_X 16.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_BOTTOM 34.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_W 120.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_H 24.0f
#define ER_UI_COMPONENT_SPEC( \
  title, \
  slug, \
  category, \
  source, \
  fixture, \
  slots, \
  states, \
  state_count, \
  component_status) \
  { \
    title, \
    slug, \
    "/docs/components/" slug, \
    category, \
    source, \
    fixture, \
    slots, \
    ER_UI_COMPONENT_ARRAY_COUNT(slots), \
    states, \
    state_count, \
    component_status \
  }
#define ER_UI_COMPONENT_ENTRY(title, slug, category, source, fixture, slots, states) \
  ER_UI_COMPONENT_SPEC( \
    title, \
    slug, \
    category, \
    source, \
    fixture, \
    slots, \
    states, \
    ER_UI_COMPONENT_ARRAY_COUNT(states), \
    ER_UI_COMPONENT_STATUS_EXACT_PORT)
#define ER_UI_COMPONENT_NATIVE(title, slug, category, source, fixture, slots, states) \
  ER_UI_COMPONENT_SPEC( \
    title, \
    slug, \
    category, \
    source, \
    fixture, \
    slots, \
    states, \
    ER_UI_COMPONENT_ARRAY_COUNT(states), \
    ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE)
#define ER_UI_COMPONENT_EMPTY(title, slug, category, source, fixture, slots, states) \
  ER_UI_COMPONENT_SPEC( \
    title, \
    slug, \
    category, \
    source, \
    fixture, \
    slots, \
    states, \
    ER_UI_COMPONENT_EMPTY_COUNT, \
    ER_UI_COMPONENT_STATUS_EXACT_PORT)
#define ER_UI_COMPONENT_FIELD_SET(fields) \
  do { \
    *out_fields = fields; \
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(fields); \
    return true; \
  } while (0)
#define ER_UI_COMPONENT_A11Y_SET(role, labels) \
  do { \
    *out_role = role; \
    *out_label_fields = labels; \
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(labels); \
    return true; \
  } while (0)

const char* er_ui_component_selector(er_ui_component_test_id_t component);
const er_ui_component_test_id_t* er_ui_component_test_ids(size_t* out_count);
const char* er_ui_component_state_selector(er_ui_component_state_t state);
const char* er_ui_component_category_label(er_ui_component_category_t category);
const char* er_ui_component_status_label(er_ui_component_status_t status);
const char* er_ui_component_resolve_kind_label(er_ui_component_resolve_kind_t kind);
const er_ui_component_spec_t* er_ui_component_at(size_t index);
size_t er_ui_component_count(void);
const char* er_ui_component_canonical_source(void);
size_t er_ui_component_canonical_count(void);
const char* er_ui_component_canonical_at(size_t index);
bool er_ui_component_canonical_covered(const char* slug);
bool er_ui_component_has_native_renderer(const er_ui_component_spec_t* spec);
bool er_ui_component_is_exact_port(const er_ui_component_spec_t* spec);
bool er_ui_component_uses_slot(const er_ui_component_spec_t* spec, const char* slot);
bool er_ui_component_uses_state(const er_ui_component_spec_t* spec, const char* state);
const er_ui_component_spec_t* er_ui_component_find_by_slug(const char* slug);
const er_ui_component_spec_t* er_ui_component_find_by_source_component(const char* source_component);
bool er_ui_component_resolve_identifier(const char* identifier, er_ui_component_resolved_t* out_resolved);
bool er_ui_component_port_mapping_for_identifier(const char* identifier, er_ui_component_port_mapping_t* out_mapping);
size_t er_ui_component_native_count(void);
size_t er_ui_component_exact_count(void);
size_t er_ui_component_exact_parity_count(void);
size_t er_ui_component_count_by_category(er_ui_component_category_t category);
size_t er_ui_component_count_by_status(er_ui_component_status_t status);
bool er_ui_component_parity_contract_for_slug(const char* slug, er_ui_component_parity_contract_t* out_contract);
bool er_ui_component_contract_supports_slot(const er_ui_component_parity_contract_t* contract, const char* slot);
bool er_ui_component_contract_supports_state(const er_ui_component_parity_contract_t* contract, const char* state);
bool er_ui_component_contract_supports_variant(const er_ui_component_parity_contract_t* contract, const char* variant);
bool er_ui_component_contract_supports_interaction(
  const er_ui_component_parity_contract_t* contract,
  const char* interaction);
const char* er_ui_component_name(er_ui_component_test_id_t component);
bool er_ui_component_state_matrix_for(
  er_ui_component_test_id_t component,
  er_ui_component_state_matrix_t* out_matrix);
bool er_ui_component_state_matrix_has_state(
  const er_ui_component_state_matrix_t* matrix,
  er_ui_component_state_t state);
bool er_ui_component_projection_contract_for(
  er_ui_component_test_id_t component,
  er_ui_component_projection_contract_t* out_contract);
bool er_ui_component_projection_contract_has_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name);
bool er_ui_component_projection_contract_requires_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name);
size_t er_ui_component_projection_required_field_count(
  const er_ui_component_projection_contract_t* contract);
bool er_ui_component_accessibility_metadata_for(
  er_ui_component_test_id_t component,
  er_ui_component_accessibility_metadata_t* out_metadata);
bool er_ui_component_accessibility_metadata_has_label_field(
  const er_ui_component_accessibility_metadata_t* metadata,
  const char* name);
void er_ui_component_gallery_state_init(er_ui_component_gallery_state_t* state);
bool er_ui_component_gallery_apply_action(er_ui_component_gallery_state_t* state, er_ui_action_t action);
bool er_ui_component_gallery_select_open(const er_ui_component_gallery_state_t* state, uint32_t id);
float er_ui_component_gallery_slider(const er_ui_component_gallery_state_t* state, uint32_t id);
size_t er_ui_component_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index);
bool er_ui_component_preview_available(const char* slug);
bool er_ui_component_catalog_preview_available(const char* slug);
bool er_ui_component_preview_available_by_source_component(const char* source_component);
bool er_ui_component_preview_available_by_identifier(const char* identifier);
bool er_ui_component_catalog_preview_available_by_identifier(const char* identifier);
bool er_ui_component_scene_preview_available(const char* slug);
er_ui_status_t er_ui_component_scene_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* slug,
  const er_ui_component_gallery_state_t* state);
er_ui_status_t er_ui_component_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* selected_slug,
  const er_ui_component_gallery_state_t* state);

#define ER_UI_COMPONENT_IDENTIFIER_CAPACITY ER_UI_COMPONENT_TEXT_CAPACITY
#define ER_UI_COMPONENT_PREVIEW_BREADCRUMB_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_DEFAULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 2u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_SECONDARY_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 3u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_GHOST_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 4u)
#define ER_UI_COMPONENT_PREVIEW_CHECKBOX_TERMS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 6u)
#define ER_UI_COMPONENT_PREVIEW_CHECKBOX_EMAILS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 7u)
#define ER_UI_COMPONENT_PREVIEW_COMMAND_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 8u)
#define ER_UI_COMPONENT_PREVIEW_FIELD_EMAIL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 11u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 12u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 13u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_H 40.0f
#define ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CANCEL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 90u)
#define ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CONFIRM_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 91u)
#define ER_UI_COMPONENT_PREVIEW_BREADCRUMB_CURRENT_INDEX 2u
#define ER_UI_COMPONENT_PREVIEW_DATE_PICKER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 66u)
#define ER_UI_COMPONENT_PREVIEW_CALENDAR_DAY_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 48u)
#define ER_UI_COMPONENT_PREVIEW_CALENDAR_SELECTED_INDEX 2u
#define ER_UI_COMPONENT_PREVIEW_DRAWER_SLIDER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 34u)
#define ER_UI_COMPONENT_PREVIEW_DRAWER_SUBMIT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 35u)
#define ER_UI_COMPONENT_PREVIEW_CHART_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 120u)
#define ER_UI_COMPONENT_PREVIEW_CHART_ACTIVE_INDEX 3u
#define ER_UI_COMPONENT_PREVIEW_BUTTON_GROUP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 27u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_PROFILE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 9u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_BILLING_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 10u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_LOGOUT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 11u)
#define ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_PRIMITIVES_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 31u)
#define ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_COLORS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 32u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_SELECT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 59u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_SEARCH_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 60u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_RESULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 61u)
#define ER_UI_COMPONENT_PREVIEW_TABLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 43u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_OTP_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 80u)
#define ER_UI_COMPONENT_PREVIEW_INVOICE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 130u)
#define ER_UI_COMPONENT_INVOICE_SECONDARY_ACTION_OFFSET 100u
#define ER_UI_COMPONENT_INVOICE_PRIMARY_ACTION_OFFSET 101u
#define ER_UI_COMPONENT_PREVIEW_ITEM_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 13u)
#define ER_UI_COMPONENT_PREVIEW_LABEL_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 92u)
#define ER_UI_COMPONENT_PREVIEW_MENUBAR_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 70u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_PREVIOUS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 37u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_CURRENT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 38u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_NEXT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 39u)
#define ER_UI_COMPONENT_PREVIEW_NAVIGATION_TABS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 74u)
#define ER_UI_COMPONENT_PREVIEW_NAVIGATION_INSTALL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 77u)
#define ER_UI_COMPONENT_PREVIEW_POPOVER_BUTTON_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 41u)
#define ER_UI_COMPONENT_PREVIEW_POPOVER_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 42u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_DEFAULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 14u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_COMFORTABLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 15u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_COMPACT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 16u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_INITIAL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 17u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_UPDATES_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 18u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_PRESET_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 19u)
#define ER_UI_COMPONENT_PREVIEW_SHEET_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 42u)
#define ER_UI_COMPONENT_PREVIEW_SHEET_SAVE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 43u)
#define ER_UI_COMPONENT_PREVIEW_SIDEBAR_DASHBOARD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 78u)
#define ER_UI_COMPONENT_PREVIEW_SIDEBAR_TRANSACTIONS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 79u)
#define ER_UI_COMPONENT_PREVIEW_SLIDER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 21u)
#define ER_UI_COMPONENT_PREVIEW_SWITCH_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 22u)
#define ER_UI_COMPONENT_PREVIEW_TABS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 23u)
#define ER_UI_COMPONENT_PREVIEW_TEXTAREA_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 45u)
#define ER_UI_COMPONENT_PREVIEW_TOGGLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 24u)
#define ER_UI_COMPONENT_PREVIEW_TOGGLE_GROUP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 44u)
#define ER_UI_COMPONENT_PREVIEW_TOOLTIP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 26u)

typedef struct {
  er_ui_hit_kind_t hit_kind;
  uint32_t id;
  float radius;
  er_ui_color4_t fill;
  er_ui_icon_t icon;
  er_ui_color4_t icon_color;
  er_ui_bounds_t icon_bounds;
  float text_x;
  float title_y;
  float detail_y;
  bool border;
  bool separator;
} er_ui_component_icon_text_row_t;

bool er_ui_component_streq(const char* a, const char* b);
bool er_ui_component_list_contains(const char* const* values, size_t count, const char* value);
bool er_ui_component_range_starts_with(const char* start, const char* end, const char* prefix, size_t prefix_len);
bool er_ui_component_ends_with_len(const char* start, const char* end, const char* suffix, size_t suffix_len);
const er_ui_component_spec_t* er_ui_component_catalog_data_at(size_t index);
er_ui_status_t er_ui_component_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_ascii_text_clipped(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  float max_w,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_icon(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_icon_t icon,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_icon_tile(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_icon_t icon,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_text_pair(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* primary,
  float primary_x,
  float primary_y,
  er_ui_color4_t primary_color,
  const char* secondary,
  float secondary_x,
  float secondary_y,
  er_ui_color4_t secondary_color,
  bool emit_empty_secondary);
er_ui_status_t er_ui_component_fill_border(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  float radius,
  er_ui_color4_t fill,
  er_ui_color4_t border);
er_ui_status_t er_ui_component_row_frame_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  bool has_hit,
  float radius,
  er_ui_color4_t fill);
er_ui_status_t er_ui_component_row_body_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  bool has_hit,
  const char* title,
  const char* detail,
  float radius,
  er_ui_color4_t fill,
  float title_y,
  float detail_y);
er_ui_component_icon_text_row_t er_ui_component_icon_text_row(
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  float radius,
  er_ui_color4_t fill,
  er_ui_icon_t icon,
  er_ui_color4_t icon_color,
  er_ui_bounds_t bounds,
  float tile_y,
  float text_x,
  float title_y,
  float detail_y,
  bool border,
  bool separator);
er_ui_status_t er_ui_component_icon_text_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_icon_text_row_t* row,
  const char* title,
  const char* detail);
er_ui_status_t er_ui_component_bottom_separator_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_badged_icon_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  uint32_t id,
  const char* title,
  const char* detail,
  const char* badge,
  er_ui_icon_t icon,
  er_ui_color4_t icon_color,
  float icon_size,
  float text_x,
  float title_y,
  float detail_y);
er_ui_color4_t er_ui_component_button_fill(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_button_border(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_button_text(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_badge_fill(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant);
er_ui_color4_t er_ui_component_badge_text(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant);
float er_ui_component_clamp01(float value);

#endif

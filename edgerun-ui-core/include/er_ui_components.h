#ifndef ER_UI_COMPONENTS_H
#define ER_UI_COMPONENTS_H

#include <stdbool.h>
#include <stddef.h>

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

#ifdef __cplusplus
}
#endif

#endif

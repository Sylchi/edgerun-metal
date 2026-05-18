#include "er_ui_components_internal.h"

static const er_ui_component_test_id_t component_test_ids[] = {
  ER_UI_COMPONENT_NETWORK_APP_PROMPT,
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
};

static const er_ui_component_state_t component_states[] = {
  ER_UI_COMPONENT_STATE_DEFAULT,
  ER_UI_COMPONENT_STATE_HOVER,
  ER_UI_COMPONENT_STATE_FOCUS,
  ER_UI_COMPONENT_STATE_ACTIVE,
  ER_UI_COMPONENT_STATE_DISABLED,
  ER_UI_COMPONENT_STATE_LOADING,
  ER_UI_COMPONENT_STATE_ERROR
};

static const er_ui_component_projected_field_t network_app_prompt_fields[] = {
  {"app_name", true},
  {"package_size", false},
  {"retrieval_cost", false},
  {"policy_hash", false},
  {"run_once_id", true},
  {"verify_cache_id", true},
  {"cancel_id", true},
};
static const er_ui_component_projected_field_t app_store_card_fields[] = {
  {"name", true},
  {"developer", false},
  {"release", false},
  {"package_hash", false},
  {"app_policy_hash", false},
  {"access_mode", false},
  {"detail_id", true},
  {"run_id", true},
};
static const er_ui_component_projected_field_t trust_manager_action_fields[] = {
  {"open_identity_id", true},
  {"open_app_store_id", true},
  {"revoke_grant_id", true},
  {"remove_cache_id", true},
};
static const er_ui_component_projected_field_t runtime_event_row_fields[] = {
  {"title", true},
  {"detail", false},
  {"event_hash", true},
  {"status", false},
  {"id", true},
  {"accent", false},
};
static const er_ui_component_projected_field_t package_proof_row_fields[] = {
  {"package_hash", true},
  {"manifest_hash", true},
  {"developer", false},
  {"release", false},
  {"status", false},
  {"id", true},
};
static const er_ui_component_projected_field_t import_sync_source_row_fields[] = {
  {"kind", true},
  {"name", false},
  {"detail", false},
  {"policy_hash", false},
  {"status", false},
  {"id", true},
  {"sync_id", false},
  {"configure_id", false},
};
static const er_ui_component_projected_field_t publish_from_node_row_fields[] = {
  {"kind", true},
  {"title", false},
  {"node_instance", false},
  {"route_scope", false},
  {"policy_hash", false},
  {"budget", false},
  {"status", false},
  {"id", true},
  {"publish_id", false},
  {"configure_id", false},
};
static const er_ui_component_projected_field_t node_instance_row_fields[] = {
  {"role", true},
  {"runtime_target", false},
  {"route_scope", false},
  {"policy_hash", false},
  {"status", false},
  {"id", true},
  {"open_id", false},
};
static const er_ui_component_projected_field_t admission_policy_row_fields[] = {
  {"source", true},
  {"policy_hash", true},
  {"admission_node", false},
  {"validity", false},
  {"status", false},
  {"id", true},
  {"inspect_id", false},
};
static const er_ui_component_projected_field_t route_budget_row_fields[] = {
  {"route", true},
  {"admitted_budget", true},
  {"spent", false},
  {"channel", false},
  {"status", false},
  {"id", true},
  {"inspect_id", false},
};
static const er_ui_component_projected_field_t data_table_control_fields[] = {
  {"title", false},
  {"filter_label", false},
  {"filter_value", false},
  {"filter_id", true},
  {"clear_filter_id", false},
  {"columns", true},
};
//@optimizer-ignore-constant icon-only projection metadata is returned with an explicit field count by component id switch
static const er_ui_component_projected_field_t icon_only_button_fields[] = {
  {"icon", true},
  {"id", true},
  {"label", true},
  {"active", false},
};
static const er_ui_component_projected_field_t segmented_control_fields[] = {
  {"items", true},
  {"selected", true},
};
static const er_ui_component_projected_field_t receipt_payment_row_fields[] = {
  {"label", true},
  {"receipt_id", false},
  {"policy_hash", false},
  {"amount", true},
  {"status", true},
  {"id", true},
  {"action", false},
};
static const er_ui_component_projected_field_t capability_grant_row_fields[] = {
  {"app", true},
  {"capability", true},
  {"scope", false},
  {"policy_hash", false},
  {"expiry", false},
  {"status", false},
  {"id", true},
  {"revoke_id", false},
};
static const er_ui_component_projected_field_t system_surface_state_panel_fields[] = {
  {"kind", true},
  {"state", true},
  {"title", false},
  {"detail", false},
  {"reference", false},
  {"id", true},
  {"action", false},
};

static const char *const network_app_prompt_labels[] = {
  "app_name",
};
static const char *const app_store_card_labels[] = {
  "name",
  "developer",
  "app_policy_hash",
};
static const char *const trust_manager_action_labels[] = {
  "open_identity_id",
  "open_app_store_id",
  "revoke_grant_id",
  "remove_cache_id",
};
static const char *const runtime_event_row_labels[] = {
  "title",
  "event_hash",
  "status",
};
static const char *const package_proof_row_labels[] = {
  "package_hash",
  "manifest_hash",
  "status",
};
static const char *const import_sync_source_row_labels[] = {
  "kind",
  "name",
  "policy_hash",
  "status",
};
static const char *const publish_from_node_row_labels[] = {
  "kind",
  "title",
  "node_instance",
  "policy_hash",
  "status",
};
static const char *const node_instance_row_labels[] = {
  "role",
  "runtime_target",
  "policy_hash",
  "status",
};
static const char *const admission_policy_row_labels[] = {
  "source",
  "policy_hash",
  "admission_node",
  "status",
};
static const char *const route_budget_row_labels[] = {
  "route",
  "admitted_budget",
  "status",
};
static const char *const data_table_control_labels[] = {
  "title",
  "filter_label",
  "columns",
};
static const char *const icon_only_button_labels[] = {
  "label",
};
static const char *const segmented_control_labels[] = {
  "items",
};
static const char *const receipt_payment_row_labels[] = {
  "label",
  "receipt_id",
  "amount",
  "status",
};
static const char *const capability_grant_row_labels[] = {
  "app",
  "capability",
  "scope",
  "status",
};
static const char *const system_surface_state_panel_labels[] = {
  "kind",
  "state",
  "title",
  "detail",
};

static const char* const no_variants[] = {0};
static const char* const no_keyboard[] = {0};
static const char* const static_interactions[] = {"render"};
static const char* const click_interactions[] = {"render", "click"};
static const char* const input_interactions[] = {"render", "focus", "input", "disabled"};
static const char* const disclosure_interactions[] = {"render", "open", "close", "focus", "disabled"};
static const char* const overlay_interactions[] = {"render", "trigger", "open", "close", "focus-trap"};
static const char* const menu_interactions[] = {"render", "trigger", "open", "close", "select", "disabled"};
static const char* const collection_interactions[] = {"render", "select", "keyboard-nav", "disabled"};
static const char* const drag_interactions[] = {"render", "drag", "keyboard-nav", "disabled"};
static const char* const text_input_keyboard[] = {"Tab", "Shift+Tab", "Input"};
static const char* const menu_keyboard[] = {"Enter", "Space", "Escape", "ArrowUp", "ArrowDown", "Home", "End"};
static const char* const horizontal_keyboard[] = {"Enter", "Space", "ArrowLeft", "ArrowRight", "Home", "End"};
static const char* const overlay_keyboard[] = {"Escape", "Tab", "Shift+Tab"};
static const char* const dialog_keyboard[] = {"Escape", "Tab", "Shift+Tab", "Enter"};
static const char* const input_otp_keyboard[] = {
  "Tab",
  "Shift+Tab",
  "ArrowLeft",
  "ArrowRight",
  "Backspace",
  "Input",
  "Paste"};
static const char* const slider_keyboard[] = {"ArrowLeft", "ArrowRight", "Home", "End", "PageUp", "PageDown"};
static const char* const button_variants[] = {"default", "destructive", "outline", "secondary", "ghost", "link"};
static const char* const badge_variants[] = {"default", "secondary", "destructive", "outline"};
static const char* const alert_variants[] = {"default", "destructive"};
static const char* const sheet_sides[] = {"top", "right", "bottom", "left"};
static const char* const field_variants[] = {"default", "invalid"};
static const char* const orientation_variants[] = {"horizontal", "vertical"};
static const char* const toast_variants[] = {"default", "destructive", "success", "warning", "info"};
static const char* const direction_variants[] = {"ltr", "rtl"};


static const char* const* er_ui_component_variants_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_component_streq(slug, "alert")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(alert_variants);
    return alert_variants;
  }
  if (er_ui_component_streq(slug, "badge")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(badge_variants);
    return badge_variants;
  }
  if (er_ui_component_streq(slug, "button")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(button_variants);
    return button_variants;
  }
  if (er_ui_component_streq(slug, "button-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  if (er_ui_component_streq(slug, "separator")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  if (er_ui_component_streq(slug, "resizable")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  static const char* const card_variants[] = {"default", "sm"};
  if (er_ui_component_streq(slug, "card")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(card_variants);
    return card_variants;
  }
  if (er_ui_component_streq(slug, "direction")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(direction_variants);
    return direction_variants;
  }
  if (er_ui_component_streq(slug, "field")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "input")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "input-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "native-select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "sheet")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(sheet_sides);
    return sheet_sides;
  }
  if (er_ui_component_streq(slug, "sonner")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toast_variants);
    return toast_variants;
  }
  if (er_ui_component_streq(slug, "toast")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toast_variants);
    return toast_variants;
  }
  static const char* const toggle_group_variants[] = {"single", "multiple"};
  if (er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toggle_group_variants);
    return toggle_group_variants;
  }
  *out_count = 0u;
  return no_variants;
}

static const char* const* er_ui_component_interactions_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_component_streq(slug, "accordion")
    || er_ui_component_streq(slug, "collapsible")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(disclosure_interactions);
    return disclosure_interactions;
  }
  if (er_ui_component_streq(slug, "alert-dialog")
    || er_ui_component_streq(slug, "dialog")
    || er_ui_component_streq(slug, "drawer")
    || er_ui_component_streq(slug, "hover-card")
    || er_ui_component_streq(slug, "popover")
    || er_ui_component_streq(slug, "sheet")
    || er_ui_component_streq(slug, "tooltip")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(overlay_interactions);
    return overlay_interactions;
  }
  if (er_ui_component_streq(slug, "button")
    || er_ui_component_streq(slug, "button-group")
    || er_ui_component_streq(slug, "pagination")
    || er_ui_component_streq(slug, "toggle")
    || er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(click_interactions);
    return click_interactions;
  }
  if (er_ui_component_streq(slug, "calendar")
    || er_ui_component_streq(slug, "carousel")
    || er_ui_component_streq(slug, "checkbox")
    || er_ui_component_streq(slug, "combobox")
    || er_ui_component_streq(slug, "command")
    || er_ui_component_streq(slug, "date-picker")
    || er_ui_component_streq(slug, "menubar")
    || er_ui_component_streq(slug, "navigation-menu")
    || er_ui_component_streq(slug, "radio-group")
    || er_ui_component_streq(slug, "select")
    || er_ui_component_streq(slug, "tabs")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(collection_interactions);
    return collection_interactions;
  }
  if (er_ui_component_streq(slug, "context-menu")
    || er_ui_component_streq(slug, "dropdown-menu")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(menu_interactions);
    return menu_interactions;
  }
  if (er_ui_component_streq(slug, "field")
    || er_ui_component_streq(slug, "input")
    || er_ui_component_streq(slug, "input-group")
    || er_ui_component_streq(slug, "input-otp")
    || er_ui_component_streq(slug, "native-select")
    || er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(input_interactions);
    return input_interactions;
  }
  if (er_ui_component_streq(slug, "resizable")
    || er_ui_component_streq(slug, "slider")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(drag_interactions);
    return drag_interactions;
  }
  *out_count = ER_UI_COMPONENT_ARRAY_COUNT(static_interactions);
  return static_interactions;
}

static const char* const* er_ui_component_keyboard_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  static const char* const enter_space_keyboard[] = {"Enter", "Space"};
  if (er_ui_component_streq(slug, "accordion")
    || er_ui_component_streq(slug, "button")
    || er_ui_component_streq(slug, "button-group")
    || er_ui_component_streq(slug, "checkbox")
    || er_ui_component_streq(slug, "collapsible")
    || er_ui_component_streq(slug, "toggle")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(enter_space_keyboard);
    return enter_space_keyboard;
  }
  if (er_ui_component_streq(slug, "alert-dialog")
    || er_ui_component_streq(slug, "dialog")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(dialog_keyboard);
    return dialog_keyboard;
  }
  if (er_ui_component_streq(slug, "context-menu")
    || er_ui_component_streq(slug, "dropdown-menu")
    || er_ui_component_streq(slug, "command")
    || er_ui_component_streq(slug, "combobox")
    || er_ui_component_streq(slug, "select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(menu_keyboard);
    return menu_keyboard;
  }
  if (er_ui_component_streq(slug, "calendar")
    || er_ui_component_streq(slug, "carousel")
    || er_ui_component_streq(slug, "menubar")
    || er_ui_component_streq(slug, "navigation-menu")
    || er_ui_component_streq(slug, "pagination")
    || er_ui_component_streq(slug, "radio-group")
    || er_ui_component_streq(slug, "tabs")
    || er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(horizontal_keyboard);
    return horizontal_keyboard;
  }
  if (er_ui_component_streq(slug, "date-picker")
    || er_ui_component_streq(slug, "drawer")
    || er_ui_component_streq(slug, "hover-card")
    || er_ui_component_streq(slug, "popover")
    || er_ui_component_streq(slug, "sheet")
    || er_ui_component_streq(slug, "tooltip")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(overlay_keyboard);
    return overlay_keyboard;
  }
  if (er_ui_component_streq(slug, "field")
    || er_ui_component_streq(slug, "input")
    || er_ui_component_streq(slug, "input-group")
    || er_ui_component_streq(slug, "native-select")
    || er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(text_input_keyboard);
    return text_input_keyboard;
  }
  if (er_ui_component_streq(slug, "input-otp")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(input_otp_keyboard);
    return input_otp_keyboard;
  }
  if (er_ui_component_streq(slug, "resizable")
    || er_ui_component_streq(slug, "slider")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(slider_keyboard);
    return slider_keyboard;
  }
  *out_count = 0u;
  return no_keyboard;
}

static const char* er_ui_component_aria_pattern_for_slug(const char* slug) {
  if (er_ui_component_streq(slug, "accordion")) return "accordion";
  if (er_ui_component_streq(slug, "alert")) return "alert";
  if (er_ui_component_streq(slug, "alert-dialog")) return "alertdialog";
  if (er_ui_component_streq(slug, "breadcrumb")) return "breadcrumb-navigation";
  if (er_ui_component_streq(slug, "button")) return "button";
  if (er_ui_component_streq(slug, "button-group")) return "button";
  if (er_ui_component_streq(slug, "toggle")) return "button";
  if (er_ui_component_streq(slug, "toggle-group")) return "button";
  if (er_ui_component_streq(slug, "calendar")) return "grid";
  if (er_ui_component_streq(slug, "date-picker")) return "grid";
  if (er_ui_component_streq(slug, "carousel")) return "region";
  if (er_ui_component_streq(slug, "chart")) return "figure";
  if (er_ui_component_streq(slug, "checkbox")) return "checkbox";
  if (er_ui_component_streq(slug, "collapsible")) return "disclosure";
  if (er_ui_component_streq(slug, "combobox")) return "combobox";
  if (er_ui_component_streq(slug, "command")) return "command-menu";
  if (er_ui_component_streq(slug, "context-menu")) return "menu";
  if (er_ui_component_streq(slug, "dropdown-menu")) return "menu";
  if (er_ui_component_streq(slug, "menubar")) return "menu";
  if (er_ui_component_streq(slug, "data-table")) return "table";
  if (er_ui_component_streq(slug, "table")) return "table";
  if (er_ui_component_streq(slug, "dialog")) return "dialog";
  if (er_ui_component_streq(slug, "drawer")) return "dialog";
  if (er_ui_component_streq(slug, "sheet")) return "dialog";
  if (er_ui_component_streq(slug, "field")) return "form-control";
  if (er_ui_component_streq(slug, "input")) return "form-control";
  if (er_ui_component_streq(slug, "input-group")) return "form-control";
  if (er_ui_component_streq(slug, "input-otp")) return "form-control";
  if (er_ui_component_streq(slug, "textarea")) return "form-control";
  if (er_ui_component_streq(slug, "hover-card")) return "non-modal-dialog";
  if (er_ui_component_streq(slug, "popover")) return "non-modal-dialog";
  if (er_ui_component_streq(slug, "navigation-menu")) return "navigation";
  if (er_ui_component_streq(slug, "pagination")) return "navigation";
  if (er_ui_component_streq(slug, "sidebar")) return "navigation";
  if (er_ui_component_streq(slug, "native-select")) return "listbox";
  if (er_ui_component_streq(slug, "select")) return "listbox";
  if (er_ui_component_streq(slug, "progress")) return "progressbar";
  if (er_ui_component_streq(slug, "radio-group")) return "radiogroup";
  if (er_ui_component_streq(slug, "resizable")) return "slider";
  if (er_ui_component_streq(slug, "slider")) return "slider";
  if (er_ui_component_streq(slug, "scroll-area")) return "scroll-region";
  if (er_ui_component_streq(slug, "separator")) return "separator";
  if (er_ui_component_streq(slug, "tabs")) return "tabs";
  if (er_ui_component_streq(slug, "toast")) return "status";
  if (er_ui_component_streq(slug, "sonner")) return "status";
  if (er_ui_component_streq(slug, "tooltip")) return "tooltip";
  return "presentation";
}

bool er_ui_component_parity_contract_for_slug(const char* slug, er_ui_component_parity_contract_t* out_contract) {
  if (!slug || !out_contract) return false;
  const er_ui_component_spec_t* spec = er_ui_component_find_by_slug(slug);
  if (!spec) return false;
  *out_contract = (er_ui_component_parity_contract_t){0};
  out_contract->slug = spec->slug;
  out_contract->slots = spec->slots;
  out_contract->slot_count = spec->slot_count;
  out_contract->states = spec->states;
  out_contract->state_count = spec->state_count;
  out_contract->variants = er_ui_component_variants_for_slug(spec->slug, &out_contract->variant_count);
  out_contract->interactions = er_ui_component_interactions_for_slug(spec->slug, &out_contract->interaction_count);
  out_contract->keyboard = er_ui_component_keyboard_for_slug(spec->slug, &out_contract->keyboard_count);
  out_contract->aria_pattern = er_ui_component_aria_pattern_for_slug(spec->slug);
  out_contract->compound = spec->slot_count > 1u;
  return true;
}

size_t er_ui_component_exact_parity_count(void) {
  size_t count = 0u;
  for (size_t i = 0u; i < er_ui_component_count(); ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    er_ui_component_parity_contract_t contract = {0};
    if (component && component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT
      && er_ui_component_parity_contract_for_slug(component->slug, &contract)) {
      count++;
    }
  }
  return count;
}

bool er_ui_component_contract_supports_slot(const er_ui_component_parity_contract_t* contract, const char* slot) {
  return contract && er_ui_component_list_contains(contract->slots, contract->slot_count, slot);
}
bool er_ui_component_contract_supports_state(const er_ui_component_parity_contract_t* contract, const char* state) {
  return contract && er_ui_component_list_contains(contract->states, contract->state_count, state);
}
bool er_ui_component_contract_supports_variant(const er_ui_component_parity_contract_t* contract, const char* variant) {
  return contract && er_ui_component_list_contains(contract->variants, contract->variant_count, variant);
}
bool er_ui_component_contract_supports_interaction(
  const er_ui_component_parity_contract_t* contract,
  const char* interaction) {
  return contract && er_ui_component_list_contains(contract->interactions, contract->interaction_count, interaction);
}

const char* er_ui_component_selector(er_ui_component_test_id_t component) {
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT: return "edgerun.network_app_prompt";
    case ER_UI_COMPONENT_APP_STORE_CARD: return "edgerun.app_store_card";
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS: return "edgerun.trust_manager_actions";
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW: return "edgerun.runtime_event_row";
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW: return "edgerun.package_proof_row";
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW: return "edgerun.import_sync_source_row";
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW: return "edgerun.publish_from_node_row";
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW: return "edgerun.node_instance_row";
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW: return "edgerun.admission_policy_row";
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW: return "edgerun.route_budget_row";
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS: return "edgerun.data_table_controls";
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON: return "edgerun.icon_only_button";
    case ER_UI_COMPONENT_SEGMENTED_CONTROL: return "edgerun.segmented_control";
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW: return "edgerun.receipt_payment_row";
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW: return "edgerun.capability_grant_detail_row";
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL: return "edgerun.system_surface_state_panel";
    default: return "";
  }
}

const char* er_ui_component_name(er_ui_component_test_id_t component) {
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT: return "NetworkAppPrompt";
    case ER_UI_COMPONENT_APP_STORE_CARD: return "AppStoreCard";
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS: return "TrustManagerActions";
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW: return "RuntimeEventRow";
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW: return "PackageProofRow";
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW: return "ImportSyncSourceRow";
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW: return "PublishFromNodeRow";
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW: return "NodeInstanceRow";
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW: return "AdmissionPolicyRow";
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW: return "RouteBudgetRow";
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS: return "DataTableControls";
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON: return "IconOnlyButton";
    case ER_UI_COMPONENT_SEGMENTED_CONTROL: return "SegmentedControl";
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW: return "ReceiptPaymentRow";
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW: return "CapabilityGrantDetailRow";
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL: return "SystemSurfaceStatePanel";
    default: return "";
  }
}

const er_ui_component_test_id_t* er_ui_component_test_ids(size_t* out_count) {
  if (out_count) *out_count = sizeof(component_test_ids) / sizeof(component_test_ids[0]);
  return component_test_ids;
}

const char* er_ui_component_state_selector(er_ui_component_state_t state) {
  switch (state) {
    case ER_UI_COMPONENT_STATE_DEFAULT: return "state.default";
    case ER_UI_COMPONENT_STATE_HOVER: return "state.hover";
    case ER_UI_COMPONENT_STATE_FOCUS: return "state.focus";
    case ER_UI_COMPONENT_STATE_ACTIVE: return "state.active";
    case ER_UI_COMPONENT_STATE_DISABLED: return "state.disabled";
    case ER_UI_COMPONENT_STATE_LOADING: return "state.loading";
    case ER_UI_COMPONENT_STATE_ERROR: return "state.error";
    default: return "";
  }
}

const char* er_ui_component_state_label(er_ui_component_state_t state) {
  switch (state) {
    case ER_UI_COMPONENT_STATE_DEFAULT: return "Default";
    case ER_UI_COMPONENT_STATE_HOVER: return "Hover";
    case ER_UI_COMPONENT_STATE_FOCUS: return "Focus";
    case ER_UI_COMPONENT_STATE_ACTIVE: return "Active";
    case ER_UI_COMPONENT_STATE_DISABLED: return "Disabled";
    case ER_UI_COMPONENT_STATE_LOADING: return "Loading";
    case ER_UI_COMPONENT_STATE_ERROR: return "Error";
    default: return "";
  }
}

const er_ui_component_state_t* er_ui_component_states(size_t* out_count) {
  if (out_count) *out_count = ER_UI_COMPONENT_STATE_COUNT;
  return component_states;
}

const char* er_ui_component_a11y_role_label(er_ui_component_a11y_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_A11Y_GROUP: return "group";
    case ER_UI_COMPONENT_A11Y_BUTTON: return "button";
    case ER_UI_COMPONENT_A11Y_DIALOG: return "dialog";
    case ER_UI_COMPONENT_A11Y_LIST_ITEM: return "list-item";
    case ER_UI_COMPONENT_A11Y_STATUS: return "status";
    case ER_UI_COMPONENT_A11Y_TAB_LIST: return "tab-list";
    case ER_UI_COMPONENT_A11Y_GENERIC:
    default: return "generic";
  }
}

bool er_ui_component_state_matrix_for(
  er_ui_component_test_id_t component,
  er_ui_component_state_matrix_t* out_matrix) {
  if (!out_matrix || component >= ER_UI_COMPONENT_TEST_ID_COUNT) return false;
  out_matrix->component = component;
  out_matrix->states = component_states;
  out_matrix->state_count = ER_UI_COMPONENT_STATE_COUNT;
  return true;
}

bool er_ui_component_state_matrix_has_state(
  const er_ui_component_state_matrix_t* matrix,
  er_ui_component_state_t state) {
  if (!matrix || !matrix->states) return false;
  for (size_t i = 0u; i < matrix->state_count; ++i) {
    if (matrix->states[i] == state) return true;
  }
  return false;
}

//@optimizer-ignore-function component field metadata lookup is a fixed switch over known component ids
static bool er_ui_component_field_set_for(
  er_ui_component_test_id_t component,
  const er_ui_component_projected_field_t** out_fields,
  size_t* out_count) {
  if (!out_fields || !out_count) return false;
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT:
      ER_UI_COMPONENT_FIELD_SET(network_app_prompt_fields);
    case ER_UI_COMPONENT_APP_STORE_CARD:
      ER_UI_COMPONENT_FIELD_SET(app_store_card_fields);
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS:
      ER_UI_COMPONENT_FIELD_SET(trust_manager_action_fields);
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW:
      ER_UI_COMPONENT_FIELD_SET(runtime_event_row_fields);
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW:
      ER_UI_COMPONENT_FIELD_SET(package_proof_row_fields);
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW:
      ER_UI_COMPONENT_FIELD_SET(import_sync_source_row_fields);
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW:
      ER_UI_COMPONENT_FIELD_SET(publish_from_node_row_fields);
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW:
      ER_UI_COMPONENT_FIELD_SET(node_instance_row_fields);
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW:
      ER_UI_COMPONENT_FIELD_SET(admission_policy_row_fields);
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW:
      ER_UI_COMPONENT_FIELD_SET(route_budget_row_fields);
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS:
      ER_UI_COMPONENT_FIELD_SET(data_table_control_fields);
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON:
      ER_UI_COMPONENT_FIELD_SET(icon_only_button_fields);
    case ER_UI_COMPONENT_SEGMENTED_CONTROL:
      ER_UI_COMPONENT_FIELD_SET(segmented_control_fields);
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW:
      ER_UI_COMPONENT_FIELD_SET(receipt_payment_row_fields);
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW:
      ER_UI_COMPONENT_FIELD_SET(capability_grant_row_fields);
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL:
      ER_UI_COMPONENT_FIELD_SET(system_surface_state_panel_fields);
    default: return false;
  }
}

bool er_ui_component_projection_contract_for(
  er_ui_component_test_id_t component,
  er_ui_component_projection_contract_t* out_contract) {
  if (!out_contract) return false;
  const er_ui_component_projected_field_t* fields = 0;
  size_t field_count = 0u;
  //@optimizer-ignore component field metadata lookup is a fixed switch over known component ids
  if (!er_ui_component_field_set_for(component, &fields, &field_count)) return false;
  out_contract->component = component;
  out_contract->fields = fields;
  out_contract->field_count = field_count;
  return true;
}

bool er_ui_component_projection_contract_has_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name) {
  if (!contract || !contract->fields || !name) return false;
  for (size_t i = 0u; i < contract->field_count; ++i) {
    if (er_ui_component_streq(contract->fields[i].name, name)) return true;
  }
  return false;
}

bool er_ui_component_projection_contract_requires_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name) {
  if (!contract || !contract->fields || !name) return false;
  for (size_t i = 0u; i < contract->field_count; ++i) {
    if (contract->fields[i].required && er_ui_component_streq(contract->fields[i].name, name)) {
      return true;
    }
  }
  return false;
}

size_t er_ui_component_projection_required_field_count(const er_ui_component_projection_contract_t* contract) {
  if (!contract || !contract->fields) return 0u;
  size_t count = 0u;
  for (size_t i = 0u; i < contract->field_count; ++i) if (contract->fields[i].required) count++;
  return count;
}

//@optimizer-ignore-function component accessibility metadata lookup is a fixed switch over known component ids
static bool er_ui_component_accessibility_set_for(
  er_ui_component_test_id_t component,
  er_ui_component_a11y_role_t* out_role,
  const char* const** out_label_fields,
  size_t* out_count) {
  if (!out_role || !out_label_fields || !out_count) return false;
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_DIALOG, network_app_prompt_labels);
    case ER_UI_COMPONENT_APP_STORE_CARD:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, app_store_card_labels);
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_GROUP, trust_manager_action_labels);
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, runtime_event_row_labels);
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, package_proof_row_labels);
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, import_sync_source_row_labels);
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, publish_from_node_row_labels);
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, node_instance_row_labels);
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, admission_policy_row_labels);
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, route_budget_row_labels);
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_GROUP, data_table_control_labels);
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_BUTTON, icon_only_button_labels);
    case ER_UI_COMPONENT_SEGMENTED_CONTROL:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_TAB_LIST, segmented_control_labels);
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, receipt_payment_row_labels);
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, capability_grant_row_labels);
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_STATUS, system_surface_state_panel_labels);
    default: return false;
  }
}

bool er_ui_component_accessibility_metadata_for(
  er_ui_component_test_id_t component,
  er_ui_component_accessibility_metadata_t* out_metadata) {
  if (!out_metadata) return false;
  er_ui_component_a11y_role_t role = ER_UI_COMPONENT_A11Y_GENERIC;
  const char* const* label_fields = 0;
  size_t label_field_count = 0u;
  //@optimizer-ignore component accessibility metadata lookup is a fixed switch over known component ids
  if (!er_ui_component_accessibility_set_for(component, &role, &label_fields, &label_field_count)) return false;
  out_metadata->component = component;
  out_metadata->role = role;
  out_metadata->label_fields = label_fields;
  out_metadata->label_field_count = label_field_count;
  return true;
}

bool er_ui_component_accessibility_metadata_has_label_field(
  const er_ui_component_accessibility_metadata_t* metadata,
  const char* name) {
  if (!metadata || !metadata->label_fields || !name) return false;
  return er_ui_component_list_contains(metadata->label_fields, metadata->label_field_count, name);
}

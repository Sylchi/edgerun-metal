#include "er_ui_components_internal.h"

static bool er_ui_component_preview_select_id(uint32_t id) {
  return id == ER_UI_COMPONENT_SELECT_PREFERRED_CURRENCY_ID ||
         id == ER_UI_COMPONENT_SELECT_ORDER_TYPE_ID ||
         id == ER_UI_COMPONENT_SELECT_DEFAULT_CURRENCY_ID ||
         id == ER_UI_COMPONENT_SELECT_TICKER_ID;
}


static bool er_ui_component_gallery_set_slider(
  er_ui_component_gallery_state_t* state,
  uint32_t id,
  float value) {
  if (!state) return false;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) {
      state->sliders[i].value = er_ui_component_clamp01(value);
      return true;
    }
  }
  if (state->slider_count >= ER_UI_COMPONENT_GALLERY_SLIDER_CAPACITY) return false;
  state->sliders[state->slider_count++] = (er_ui_component_slider_value_t){
    id,
    er_ui_component_clamp01(value)
  };
  return true;
}

void er_ui_component_gallery_state_init(er_ui_component_gallery_state_t* state) {
  if (!state) return;
  *state = (er_ui_component_gallery_state_t){0};
  state->contribution_bar = ER_UI_COMPONENT_CHART_CONTRIBUTION_DEFAULT_INDEX;
  state->stock_bar = ER_UI_COMPONENT_CHART_STOCK_DEFAULT_INDEX;
  state->power_bar = ER_UI_COMPONENT_CHART_POWER_DEFAULT_INDEX;
  (void)er_ui_component_gallery_set_slider(state, ER_UI_COMPONENT_PREVIEW_SLIDER_ID, 0.42f);
}

size_t er_ui_component_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index) {
  if (out_has_index) *out_has_index = false;
  if (id < base) return 0u;
  uint32_t offset = id - base;
  if ((size_t)offset >= len) return 0u;
  if (out_has_index) *out_has_index = true;
  return (size_t)offset;
}

bool er_ui_component_gallery_apply_action(er_ui_component_gallery_state_t* state, er_ui_action_t action) {
  if (!state) return false;
  if (action.kind == ER_UI_ACTION_OPEN_CHANGED) {
    if (!er_ui_component_preview_select_id(action.id)) return false;
    state->has_open_select = action.bool_value;
    state->open_select = action.bool_value ? action.id : 0u;
    return true;
  }
  if (action.kind == ER_UI_ACTION_SLIDER_CHANGED) {
    return er_ui_component_gallery_set_slider(state, action.id, action.float_value);
  }
  if (action.kind != ER_UI_ACTION_ACTIVATED || !action.has_hit) return false;
  if (action.hit.kind == ER_UI_HIT_MENU_ITEM) {
    bool has_index = false;
    size_t index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_CURRENCY_BASE_ID,
      ER_UI_COMPONENT_SELECT_CURRENCY_COUNT,
      &has_index);
    if (has_index) {
      state->currency_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_ORDER_BASE_ID,
      ER_UI_COMPONENT_SELECT_ORDER_COUNT,
      &has_index);
    if (has_index) {
      state->order_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_TICKER_BASE_ID,
      ER_UI_COMPONENT_SELECT_TICKER_COUNT,
      &has_index);
    if (has_index) {
      state->ticker_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
  }
  if (action.hit.kind == ER_UI_HIT_BUTTON) {
    bool has_index = false;
    size_t index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_CONTRIBUTION_BASE_ID,
      ER_UI_COMPONENT_CHART_CONTRIBUTION_COUNT,
      &has_index);
    if (has_index) {
      state->contribution_bar = index;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_STOCK_BASE_ID,
      ER_UI_COMPONENT_CHART_STOCK_COUNT,
      &has_index);
    if (has_index) {
      state->stock_bar = index;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_POWER_BASE_ID,
      ER_UI_COMPONENT_CHART_POWER_COUNT,
      &has_index);
    if (has_index) {
      state->power_bar = index;
      return true;
    }
  }
  return false;
}

bool er_ui_component_gallery_select_open(const er_ui_component_gallery_state_t* state, uint32_t id) {
  return state && state->has_open_select && state->open_select == id;
}

float er_ui_component_gallery_slider(const er_ui_component_gallery_state_t* state, uint32_t id) {
  if (!state) return 0.0f;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) return state->sliders[i].value;
  }
  return 0.0f;
}

bool er_ui_component_preview_available(const char* slug) {
  const er_ui_component_spec_t* spec = er_ui_component_find_by_slug(slug);
  return er_ui_component_has_native_renderer(spec);
}

bool er_ui_component_catalog_preview_available(const char* slug) {
  return er_ui_component_preview_available(slug);
}

bool er_ui_component_preview_available_by_source_component(const char* source_component) {
  const er_ui_component_spec_t* spec = er_ui_component_find_by_source_component(source_component);
  return er_ui_component_has_native_renderer(spec);
}

bool er_ui_component_preview_available_by_identifier(const char* identifier) {
  er_ui_component_resolved_t resolved = {0};
  if (!er_ui_component_resolve_identifier(identifier, &resolved)) return false;
  return er_ui_component_has_native_renderer(resolved.spec);
}

bool er_ui_component_catalog_preview_available_by_identifier(const char* identifier) {
  return er_ui_component_preview_available_by_identifier(identifier);
}

#include "er_ui_components_internal.h"

static const char* const er_ui_component_shadcn_reference_slugs[ER_UI_COMPONENT_SHADCN_REFERENCE_COUNT] = {
  "accordion",
  "alert",
  "alert-dialog",
  "aspect-ratio",
  "avatar",
  "badge",
  "breadcrumb",
  "button",
  "button-group",
  "calendar",
  "card",
  "carousel",
  "chart",
  "checkbox",
  "collapsible",
  "combobox",
  "command",
  "context-menu",
  "dialog",
  "direction",
  "drawer",
  "dropdown-menu",
  "empty",
  "field",
  "hover-card",
  "input",
  "input-group",
  "input-otp",
  "item",
  "kbd",
  "label",
  "menubar",
  "native-select",
  "navigation-menu",
  "pagination",
  "popover",
  "progress",
  "radio-group",
  "resizable",
  "scroll-area",
  "select",
  "separator",
  "sheet",
  "sidebar",
  "skeleton",
  "slider",
  "sonner",
  "spinner",
  "switch",
  "table",
  "tabs",
  "textarea",
  "toggle",
  "toggle-group",
  "tooltip",
};

const char* er_ui_component_category_label(er_ui_component_category_t category) {
  switch (category) {
    case ER_UI_COMPONENT_CATEGORY_FOUNDATION: return "Foundation";
    case ER_UI_COMPONENT_CATEGORY_FORM: return "Form";
    case ER_UI_COMPONENT_CATEGORY_OVERLAY: return "Overlay";
    case ER_UI_COMPONENT_CATEGORY_NAVIGATION: return "Navigation";
    case ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY: return "Data Display";
    case ER_UI_COMPONENT_CATEGORY_FEEDBACK: return "Feedback";
    case ER_UI_COMPONENT_CATEGORY_LAYOUT: return "Layout";
    case ER_UI_COMPONENT_CATEGORY_MEDIA: return "Media";
    default: return "";
  }
}

const char* er_ui_component_status_label(er_ui_component_status_t status) {
  switch (status) {
    case ER_UI_COMPONENT_STATUS_CATALOGED: return "Cataloged";
    case ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE: return "Native primitive";
    case ER_UI_COMPONENT_STATUS_EXACT_PORT: return "Exact port";
    default: return "";
  }
}

const char* er_ui_component_resolve_kind_label(er_ui_component_resolve_kind_t kind) {
  switch (kind) {
    case ER_UI_COMPONENT_RESOLVE_SLUG: return "Slug";
    case ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT: return "Source component";
    case ER_UI_COMPONENT_RESOLVE_MODULE_PATH: return "Module path";
    case ER_UI_COMPONENT_RESOLVE_SLOT: return "Slot";
    default: return "";
  }
}

const er_ui_component_spec_t* er_ui_component_at(size_t index) {
  return er_ui_component_catalog_data_at(index);
}

size_t er_ui_component_count(void) { return ER_UI_COMPONENT_COUNT; }

const char* er_ui_component_shadcn_reference_source(void) {
  return "ui/shadcn-ui/apps/v4/registry/bases/base/ui";
}

size_t er_ui_component_shadcn_reference_count(void) {
  return ER_UI_COMPONENT_SHADCN_REFERENCE_COUNT;
}

const char* er_ui_component_shadcn_reference_at(size_t index) {
  if (index >= ER_UI_COMPONENT_SHADCN_REFERENCE_COUNT) return 0;
  return er_ui_component_shadcn_reference_slugs[index];
}

bool er_ui_component_shadcn_reference_covered(const char* slug) {
  return er_ui_component_find_by_slug(slug) != 0;
}

bool er_ui_component_has_native_renderer(const er_ui_component_spec_t* spec) {
  return spec
    && (spec->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
      || spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT);
}

bool er_ui_component_is_exact_port(const er_ui_component_spec_t* spec) {
  return spec && spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT;
}

bool er_ui_component_uses_slot(const er_ui_component_spec_t* spec, const char* slot) {
  return spec && er_ui_component_list_contains(spec->slots, spec->slot_count, slot);
}

bool er_ui_component_uses_state(const er_ui_component_spec_t* spec, const char* state) {
  return spec && er_ui_component_list_contains(spec->states, spec->state_count, state);
}

const er_ui_component_spec_t* er_ui_component_find_by_slug(const char* slug) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && er_ui_component_streq(component->slug, slug)) return component;
  }
  return 0;
}

const er_ui_component_spec_t* er_ui_component_find_by_source_component(const char* source_component) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && er_ui_component_streq(component->source_component, source_component)) return component;
  }
  return 0;
}

static bool er_ui_component_is_upper(char c) { return c >= 'A' && c <= 'Z'; }
static char er_ui_component_lower(char c) {
  return er_ui_component_is_upper(c) ? (char)(c + 32) : c;
}

static bool er_ui_component_normalize_identifier(const char* identifier, char* out, size_t cap, bool* out_from_path) {
  if (!identifier || !out || cap == 0u || !out_from_path) return false;
  static const char data_slot_prefix[] = "data-slot=";
  const size_t data_slot_prefix_len = ER_UI_COMPONENT_ARRAY_COUNT(data_slot_prefix) - 1u;
  const char* start = identifier;
  while (*start == ' ' || *start == '\t' || *start == '\n' || *start == '\r') start++;
  const char* end = start;
  while (*end) end++;
  while (end > start && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\n' || end[-1] == '\r')) end--;
  if (er_ui_component_range_starts_with(start, end, data_slot_prefix, data_slot_prefix_len)) {
    start += data_slot_prefix_len;
    while (start < end && (*start == '\"' || *start == '\'')) start++;
    while (end > start && (end[-1] == '\"' || end[-1] == '\'')) end--;
  }
  *out_from_path = false;
  const char* last = start;
  for (const char* p = start; p < end; ++p) {
    if (*p == '/') { *out_from_path = true; last = p + 1; }
  }
  start = last;
  if (er_ui_component_ends_with_len(start, end, ".tsx", ER_UI_COMPONENT_SUFFIX_TSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".jsx", ER_UI_COMPONENT_SUFFIX_JSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".ts", ER_UI_COMPONENT_SUFFIX_TS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TS_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".js", ER_UI_COMPONENT_SUFFIX_JS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JS_LEN;
  }
  bool needs_kebab = false;
  for (const char* p = start; p < end; ++p) {
    if (er_ui_component_is_upper(*p) || *p == '_' || *p == ' ') needs_kebab = true;
  }
  size_t n = 0u;
  bool previous_was_separator = true;
  for (const char* p = start; p < end; ++p) {
    char ch = *p;
    if (needs_kebab && (ch == '_' || ch == ' ')) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      previous_was_separator = true;
      continue;
    }
    if (needs_kebab && er_ui_component_is_upper(ch)) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      if (n + 1u >= cap) return false;
      out[n++] = er_ui_component_lower(ch);
      previous_was_separator = false;
      continue;
    }
    if (n + 1u >= cap) return false;
    out[n++] = er_ui_component_lower(ch);
    previous_was_separator = ch == '-';
  }
  out[n] = '\0';
  return n > 0u;
}

bool er_ui_component_resolve_identifier(const char* identifier, er_ui_component_resolved_t* out_resolved) {
  if (!identifier || !out_resolved) return false;
  const char* trimmed = identifier;
  while (*trimmed == ' ' || *trimmed == '\t' || *trimmed == '\n' || *trimmed == '\r') trimmed++;
  const er_ui_component_spec_t* direct_source = er_ui_component_find_by_source_component(trimmed);
  if (direct_source) {
    out_resolved->spec = direct_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  char normalized[ER_UI_COMPONENT_IDENTIFIER_CAPACITY];
  bool from_path = false;
  if (!er_ui_component_normalize_identifier(identifier, normalized, sizeof(normalized), &from_path)) return false;
  const er_ui_component_spec_t* by_slug = er_ui_component_find_by_slug(normalized);
  if (by_slug) {
    out_resolved->spec = by_slug;
    out_resolved->kind = from_path ? ER_UI_COMPONENT_RESOLVE_MODULE_PATH : ER_UI_COMPONENT_RESOLVE_SLUG;
    return true;
  }
  const er_ui_component_spec_t* by_source = er_ui_component_find_by_source_component(normalized);
  if (by_source) {
    out_resolved->spec = by_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && er_ui_component_uses_slot(component, normalized)) {
      out_resolved->spec = component;
      out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SLOT;
      return true;
    }
  }
  return false;
}

bool er_ui_component_port_mapping_for_identifier(const char* identifier, er_ui_component_port_mapping_t* out_mapping) {
  if (!identifier || !out_mapping) return false;
  er_ui_component_resolved_t resolved = {0};
  if (!er_ui_component_resolve_identifier(identifier, &resolved)) return false;
  out_mapping->identifier = identifier;
  out_mapping->resolve_kind = resolved.kind;
  out_mapping->slug = resolved.spec->slug;
  out_mapping->source_component = resolved.spec->source_component;
  out_mapping->edge_builder = resolved.spec->edge_builder;
  out_mapping->category = resolved.spec->category;
  out_mapping->status = resolved.spec->status;
  out_mapping->native_renderer = er_ui_component_has_native_renderer(resolved.spec);
  out_mapping->exact_port = er_ui_component_is_exact_port(resolved.spec);
  return true;
}

size_t er_ui_component_native_count(void) {
  size_t count = 0u;
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component
      && (component->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
        || component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT)) {
      count++;
    }
  }
  return count;
}
size_t er_ui_component_exact_count(void) {
  size_t count = 0u;
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT) count++;
  }
  return count;
}
size_t er_ui_component_count_by_category(er_ui_component_category_t category) {
  size_t count = 0u;
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && component->category == category) count++;
  }
  return count;
}
size_t er_ui_component_count_by_status(er_ui_component_status_t status) {
  size_t count = 0u;
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    const er_ui_component_spec_t* component = er_ui_component_at(i);
    if (component && component->status == status) count++;
  }
  return count;
}

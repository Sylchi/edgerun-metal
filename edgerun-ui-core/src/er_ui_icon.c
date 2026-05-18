#include "er_ui_icon.h"

/*
 * Purpose: implement canonical semantic icon names and provider atlas mappings.
 * Intention: give renderers stable icon IDs while keeping Lucide/Tabler naming out of backend code.
 */

typedef struct {
  const char* label;
  const char* tabler;
  const char* lucide;
} ErUiIconMapping;

//@optimizer-ignore-constant icon metadata is indexed only after er_ui_icon_t range guards and mirrors ER_UI_ICON_COUNT order
static const ErUiIconMapping g_icon_mappings[ER_UI_ICON_COUNT] = {
  {"activity", "activity", "activity"},
  {"app", "apps", "app-window"},
  {"bell", "bell", "bell"},
  {"chat", "message-circle", "message-circle"},
  {"check", "check", "check"},
  {"chevron-right", "chevron-right", "chevron-right"},
  {"code", "code", "code"},
  {"cpu", "cpu", "cpu"},
  {"database", "database", "database"},
  {"eye", "eye", "eye"},
  {"file", "file", "file"},
  {"key", "key", "key"},
  {"lock", "lock", "lock"},
  {"menu", "menu-2", "menu"},
  {"message-plus", "message-plus", "message-circle-plus"},
  {"network", "network", "network"},
  {"route", "route", "route"},
  {"search", "search", "search"},
  {"send", "arrow-up", "arrow-up"},
  {"server", "server", "server"},
  {"settings", "settings", "settings"},
  {"shield", "shield-check", "shield-check"},
  {"sparkles", "sparkles", "sparkles"},
  {"storage", "database", "database"},
  {"terminal", "terminal-2", "square-terminal"},
  {"trust", "shield-check", "shield-check"},
  {"trash", "trash", "trash-2"},
  {"user", "user", "user"},
  {"wallet", "wallet", "wallet"},
  {"warning", "alert-triangle", "triangle-alert"},
  {"x", "x", "x"}
};

static const ErUiIconMapping* er_ui_icon_mapping(er_ui_icon_t icon) {
  if ((uint32_t)icon >= (uint32_t)ER_UI_ICON_COUNT) return 0;
  return g_icon_mappings + (uint32_t)icon;
}

const char* er_ui_icon_label(er_ui_icon_t icon) {
  const ErUiIconMapping* mapping = er_ui_icon_mapping(icon);
  if (!mapping) return "unknown";
  return mapping->label;
}

uint32_t er_ui_icon_atlas_id(er_ui_icon_t icon) {
  if ((uint32_t)icon >= (uint32_t)ER_UI_ICON_COUNT) return 0u;
  return (uint32_t)icon + 1u;
}

er_ui_icon_t er_ui_icon_from_atlas_id(uint32_t atlas_id) {
  if (atlas_id == 0u || atlas_id > (uint32_t)ER_UI_ICON_COUNT) return ER_UI_ICON_APP;
  return (er_ui_icon_t)(atlas_id - 1u);
}

const char* er_ui_icon_provider_name(er_ui_icon_t icon, er_ui_icon_provider_t provider) {
  const ErUiIconMapping* mapping = er_ui_icon_mapping(icon);
  if (!mapping) return 0;
  if (provider == ER_UI_ICON_PROVIDER_TABLER) {
    return mapping->tabler;
  }
  if (provider == ER_UI_ICON_PROVIDER_LUCIDE) {
    return mapping->lucide;
  }
  return 0;
}

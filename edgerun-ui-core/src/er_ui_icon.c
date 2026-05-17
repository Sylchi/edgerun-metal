#include "er_ui_icon.h"

/*
 * Purpose: implement canonical semantic icon names and provider atlas mappings.
 * Intention: give renderers stable icon IDs while keeping Lucide/Tabler naming out of backend code.
 */

const char* er_ui_icon_label(er_ui_icon_t icon) {
  switch (icon) {
    case ER_UI_ICON_ACTIVITY: return "activity";
    case ER_UI_ICON_APP: return "app";
    case ER_UI_ICON_BELL: return "bell";
    case ER_UI_ICON_CHAT: return "chat";
    case ER_UI_ICON_CHECK: return "check";
    case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
    case ER_UI_ICON_CODE: return "code";
    case ER_UI_ICON_CPU: return "cpu";
    case ER_UI_ICON_DATABASE: return "database";
    case ER_UI_ICON_EYE: return "eye";
    case ER_UI_ICON_FILE: return "file";
    case ER_UI_ICON_KEY: return "key";
    case ER_UI_ICON_LOCK: return "lock";
    case ER_UI_ICON_MENU: return "menu";
    case ER_UI_ICON_MESSAGE_PLUS: return "message-plus";
    case ER_UI_ICON_NETWORK: return "network";
    case ER_UI_ICON_ROUTE: return "route";
    case ER_UI_ICON_SEARCH: return "search";
    case ER_UI_ICON_SEND: return "send";
    case ER_UI_ICON_SERVER: return "server";
    case ER_UI_ICON_SETTINGS: return "settings";
    case ER_UI_ICON_SHIELD: return "shield";
    case ER_UI_ICON_SPARKLES: return "sparkles";
    case ER_UI_ICON_STORAGE: return "storage";
    case ER_UI_ICON_TERMINAL: return "terminal";
    case ER_UI_ICON_TRUST: return "trust";
    case ER_UI_ICON_TRASH: return "trash";
    case ER_UI_ICON_USER: return "user";
    case ER_UI_ICON_WALLET: return "wallet";
    case ER_UI_ICON_WARNING: return "warning";
    case ER_UI_ICON_X: return "x";
    case ER_UI_ICON_COUNT:
    default: return "unknown";
  }
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
  if (provider == ER_UI_ICON_PROVIDER_TABLER) {
    switch (icon) {
      case ER_UI_ICON_ACTIVITY: return "activity";
      case ER_UI_ICON_APP: return "apps";
      case ER_UI_ICON_BELL: return "bell";
      case ER_UI_ICON_CHAT: return "message-circle";
      case ER_UI_ICON_CHECK: return "check";
      case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
      case ER_UI_ICON_CODE: return "code";
      case ER_UI_ICON_CPU: return "cpu";
      case ER_UI_ICON_DATABASE: return "database";
      case ER_UI_ICON_EYE: return "eye";
      case ER_UI_ICON_FILE: return "file";
      case ER_UI_ICON_KEY: return "key";
      case ER_UI_ICON_LOCK: return "lock";
      case ER_UI_ICON_MENU: return "menu-2";
      case ER_UI_ICON_MESSAGE_PLUS: return "message-plus";
      case ER_UI_ICON_NETWORK: return "network";
      case ER_UI_ICON_ROUTE: return "route";
      case ER_UI_ICON_SEARCH: return "search";
      case ER_UI_ICON_SEND: return "arrow-up";
      case ER_UI_ICON_SERVER: return "server";
      case ER_UI_ICON_SETTINGS: return "settings";
      case ER_UI_ICON_SHIELD: return "shield-check";
      case ER_UI_ICON_SPARKLES: return "sparkles";
      case ER_UI_ICON_STORAGE: return "database";
      case ER_UI_ICON_TERMINAL: return "terminal-2";
      case ER_UI_ICON_TRUST: return "shield-check";
      case ER_UI_ICON_TRASH: return "trash";
      case ER_UI_ICON_USER: return "user";
      case ER_UI_ICON_WALLET: return "wallet";
      case ER_UI_ICON_WARNING: return "alert-triangle";
      case ER_UI_ICON_X: return "x";
      case ER_UI_ICON_COUNT:
      default: return 0;
    }
  }
  if (provider == ER_UI_ICON_PROVIDER_LUCIDE) {
    switch (icon) {
      case ER_UI_ICON_ACTIVITY: return "activity";
      case ER_UI_ICON_APP: return "app-window";
      case ER_UI_ICON_BELL: return "bell";
      case ER_UI_ICON_CHAT: return "message-circle";
      case ER_UI_ICON_CHECK: return "check";
      case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
      case ER_UI_ICON_CODE: return "code";
      case ER_UI_ICON_CPU: return "cpu";
      case ER_UI_ICON_DATABASE: return "database";
      case ER_UI_ICON_EYE: return "eye";
      case ER_UI_ICON_FILE: return "file";
      case ER_UI_ICON_KEY: return "key";
      case ER_UI_ICON_LOCK: return "lock";
      case ER_UI_ICON_MENU: return "menu";
      case ER_UI_ICON_MESSAGE_PLUS: return "message-circle-plus";
      case ER_UI_ICON_NETWORK: return "network";
      case ER_UI_ICON_ROUTE: return "route";
      case ER_UI_ICON_SEARCH: return "search";
      case ER_UI_ICON_SEND: return "arrow-up";
      case ER_UI_ICON_SERVER: return "server";
      case ER_UI_ICON_SETTINGS: return "settings";
      case ER_UI_ICON_SHIELD: return "shield-check";
      case ER_UI_ICON_SPARKLES: return "sparkles";
      case ER_UI_ICON_STORAGE: return "database";
      case ER_UI_ICON_TERMINAL: return "square-terminal";
      case ER_UI_ICON_TRUST: return "shield-check";
      case ER_UI_ICON_TRASH: return "trash-2";
      case ER_UI_ICON_USER: return "user";
      case ER_UI_ICON_WALLET: return "wallet";
      case ER_UI_ICON_WARNING: return "triangle-alert";
      case ER_UI_ICON_X: return "x";
      case ER_UI_ICON_COUNT:
      default: return 0;
    }
  }
  return 0;
}

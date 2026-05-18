#ifndef ER_UI_ICON_H
#define ER_UI_ICON_H

/*
 * Purpose: define canonical EdgeRun UI icon identities and provider mappings.
 * Intention: keep Lucide/Tabler/icon atlas semantics in UI-core, not in render backends.
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_ICON_ACTIVITY = 0,
  ER_UI_ICON_APP,
  ER_UI_ICON_BELL,
  ER_UI_ICON_CHAT,
  ER_UI_ICON_CHECK,
  ER_UI_ICON_CHEVRON_LEFT,
  ER_UI_ICON_CHEVRON_RIGHT,
  ER_UI_ICON_CODE,
  ER_UI_ICON_CPU,
  ER_UI_ICON_DATABASE,
  ER_UI_ICON_EYE,
  ER_UI_ICON_FILE,
  ER_UI_ICON_KEY,
  ER_UI_ICON_LOCK,
  ER_UI_ICON_MENU,
  ER_UI_ICON_MESSAGE_PLUS,
  ER_UI_ICON_NETWORK,
  ER_UI_ICON_ROUTE,
  ER_UI_ICON_SEARCH,
  ER_UI_ICON_SEND,
  ER_UI_ICON_SERVER,
  ER_UI_ICON_SETTINGS,
  ER_UI_ICON_SHIELD,
  ER_UI_ICON_SPARKLES,
  ER_UI_ICON_STORAGE,
  ER_UI_ICON_TERMINAL,
  ER_UI_ICON_TRUST,
  ER_UI_ICON_TRASH,
  ER_UI_ICON_USER,
  ER_UI_ICON_WALLET,
  ER_UI_ICON_WARNING,
  ER_UI_ICON_X,
  ER_UI_ICON_COUNT
} er_ui_icon_t;

typedef enum {
  ER_UI_ICON_PROVIDER_LUCIDE = 0,
  ER_UI_ICON_PROVIDER_TABLER
} er_ui_icon_provider_t;

const char* er_ui_icon_label(er_ui_icon_t icon);
uint32_t er_ui_icon_atlas_id(er_ui_icon_t icon);
er_ui_icon_t er_ui_icon_from_atlas_id(uint32_t atlas_id);
const char* er_ui_icon_provider_name(er_ui_icon_t icon, er_ui_icon_provider_t provider);

#ifdef __cplusplus
}
#endif

#endif

#ifndef ER_UI_LEDGER_APP_H
#define ER_UI_LEDGER_APP_H

#include "../src/er_ui_components_internal.h"
#include "er_ui_shell.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_LEDGER_APP_LEDGER_ID 0xED020001u
#define ER_UI_LEDGER_APP_PAYMENTS_ID 0xED020002u
#define ER_UI_LEDGER_APP_ACCESS_ID 0xED020003u

typedef struct {
  er_ui_shell_state_t shell;
  er_ui_component_gallery_state_t gallery;
  float dashboard_scroll;
} er_ui_ledger_app_state_t;

er_ui_status_t er_ui_ledger_app_state_init(er_ui_ledger_app_state_t* state, er_ui_allocator_t allocator);
void er_ui_ledger_app_state_destroy(er_ui_ledger_app_state_t* state);
er_ui_status_t er_ui_ledger_app_apply_action(er_ui_ledger_app_state_t* state, er_ui_action_t action, bool* out_changed);
er_ui_status_t er_ui_ledger_app_emit_scene(
  er_ui_ledger_app_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);

#ifdef __cplusplus
}
#endif

#endif

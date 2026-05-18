#ifndef ER_UI_DEMO_APPS_H
#define ER_UI_DEMO_APPS_H

#include "er_ui_components.h"
#include "er_ui_shell.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_DEMO_APP_LEDGER_ID 0xED020001u
#define ER_UI_DEMO_APP_PAYMENTS_ID 0xED020002u
#define ER_UI_DEMO_APP_ACCESS_ID 0xED020003u

typedef struct {
  er_ui_shell_state_t shell;
  er_ui_shadcn_demo_gallery_state_t gallery;
} er_ui_demo_apps_state_t;

er_ui_status_t er_ui_demo_apps_state_init(er_ui_demo_apps_state_t* state, er_ui_allocator_t allocator);
void er_ui_demo_apps_state_destroy(er_ui_demo_apps_state_t* state);
er_ui_status_t er_ui_demo_apps_apply_action(er_ui_demo_apps_state_t* state, er_ui_action_t action, bool* out_changed);
er_ui_status_t er_ui_demo_apps_emit_scene(
  er_ui_demo_apps_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);

#ifdef __cplusplus
}
#endif

#endif

#include "internal/efi_boot_internal.h"

er_ui_action_t er_ui_boot_action_from_ps2(er_ui_runtime_state_t* runtime,
                                          const er_ui_scene_t* scene,
                                          ErPs2KeyboardAction input) {
  er_ui_action_t action = {0};

  action.kind = ER_UI_ACTION_NONE;
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY) {
    return er_ui_runtime_key_down(runtime, scene, input.key, input.modifiers);
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    action.kind = ER_UI_ACTION_TAB_SELECTED;
    action.id = input.surface_id;
  }
  return action;
}

UINT8 er_ui_boot_apply_input(er_ui_ledger_app_state_t* ledger_state,
                             er_ui_runtime_state_t* runtime,
                             er_ui_scene_t* scene,
                             ErUiBootRenderContext* render,
                             ErPs2KeyboardAction input,
                             UINT8* out_redraw) {
  er_ui_action_t action;
  bool changed = false;

  (void)render;
  if (out_redraw == 0) {
    return 0u;
  }
  *out_redraw = 0u;
  if (ledger_state == 0 || runtime == 0 || scene == 0) {
    return 0u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_NONE) {
    return 1u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    *out_redraw = 1u;
  }
  action = er_ui_boot_action_from_ps2(runtime, scene, input);
  if (action.kind == ER_UI_ACTION_NONE) {
    return 1u;
  }
  if (er_ui_ledger_app_apply_action(ledger_state, action, &changed) != ER_UI_OK) {
    return 0u;
  }
  *out_redraw = (UINT8)(changed || er_ui_action_needs_redraw(action));
  return 1u;
}

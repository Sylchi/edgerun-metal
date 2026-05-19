#include "efi_boot_internal.h"

ErUiBootAppContext* er_ui_boot_active_app(ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

const ErUiBootAppContext* er_ui_boot_active_app_const(const ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

UINT8 er_ui_boot_switch_app_for_surface(ErUiBootRenderContext* render, UINT32 surface_id) {
  UINT32 app_index;
  UINT32 user_app_surface_id;
  UINT32 i;

  if (render == 0 || render->apps == 0 || render->app_count == 0u) {
    return 0u;
  }
  for (i = 0u; i < render->app_count && i < ER_UI_BOOT_INSTALLED_APP_COUNT; ++i) {
    if (er_ui_boot_user_app_surface_id(i, &user_app_surface_id) != 0u &&
        surface_id == user_app_surface_id) {
      app_index = i;
      if (app_index >= render->app_count || render->apps[app_index].ready == 0u) {
        return 0u;
      }
      render->active_app = app_index;
      return 1u;
    }
  }
  switch (surface_id) {
    case ER_UI_LEDGER_APP_LEDGER_ID:
      app_index = 0u;
      break;
    case ER_UI_LEDGER_APP_PAYMENTS_ID:
      app_index = render->app_count > 1u ? 1u : 0u;
      break;
    case ER_UI_LEDGER_APP_ACCESS_ID:
      app_index = 0u;
      break;
    default:
      return 1u;
  }
  if (app_index >= render->app_count || render->apps[app_index].ready == 0u) {
    return 0u;
  }
  render->active_app = app_index;
  return 1u;
}

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
  ErUiBootAppContext* active_app;
  er_ui_action_t action;
  bool changed = false;

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
    if (er_ui_boot_switch_app_for_surface(render, input.surface_id) == 0u) {
      return 0u;
    }
    *out_redraw = 1u;
  }
  active_app = er_ui_boot_active_app(render);
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY && active_app != 0) {
    if (er_ui_wasm_app_deliver_key_input(&active_app->runtime,
                                         input.key, input.modifiers) != 0 ||
        er_ui_boot_execute_wasm_app(&active_app->runtime) == 0u) {
      return 0u;
    }
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

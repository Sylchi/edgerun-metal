#ifndef ER_PS2_KEYBOARD_H
#define ER_PS2_KEYBOARD_H

/*
 * Purpose: decode PS/2 set-1 keyboard bytes into UI input actions.
 * Intention: keep post-ExitBootServices keyboard input independent of firmware ConIn.
 */

#include "er_types.h"
#include "er_ui_demo_apps.h"
#include "er_ui_runtime.h"

typedef enum {
  ER_PS2_KEYBOARD_ACTION_NONE = 0,
  ER_PS2_KEYBOARD_ACTION_UI_KEY,
  ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE,
  ER_PS2_KEYBOARD_ACTION_QUIT
} ErPs2KeyboardActionKind;

typedef struct {
  UINT8 extended;
  UINT8 left_shift_down;
  UINT8 right_shift_down;
} ErPs2KeyboardState;

typedef struct {
  ErPs2KeyboardActionKind kind;
  er_ui_key_t key;
  er_ui_key_modifiers_t modifiers;
  UINT32 surface_id;
} ErPs2KeyboardAction;

void er_ps2_keyboard_action_clear(ErPs2KeyboardAction* action);
UINT8 er_ps2_keyboard_decode_set1(ErPs2KeyboardState* state, UINT8 scan_code,
                                  ErPs2KeyboardAction* out_action);
UINT8 er_ps2_keyboard_poll(ErPs2KeyboardState* state, ErPs2KeyboardAction* out_action);

#endif

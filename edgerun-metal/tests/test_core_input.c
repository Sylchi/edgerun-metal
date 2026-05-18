#include "test_core_internal.h"

static void test_ps2_keyboard_set1_decoder(void) {
  ErPs2KeyboardState state = {0};
  ErPs2KeyboardAction action;

  check_int64("ps2 decode tab",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, &action), 1);
  check_int64("ps2 tab action", action.kind, ER_PS2_KEYBOARD_ACTION_UI_KEY);
  check_int64("ps2 tab key", action.key.kind, ER_UI_KEY_TAB);
  check_int64("ps2 tab shift clear", action.modifiers.shift, 0);

  check_int64("ps2 decode shift down",
              er_ps2_keyboard_decode_set1(&state, 0x2au, &action), 1);
  check_int64("ps2 shift down no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);
  check_int64("ps2 decode shifted tab",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, &action), 1);
  check_int64("ps2 shifted tab key", action.key.kind, ER_UI_KEY_TAB);
  check_int64("ps2 shifted tab modifier", action.modifiers.shift, 1);
  check_int64("ps2 decode shift up",
              er_ps2_keyboard_decode_set1(&state, 0xaau, &action), 1);
  check_int64("ps2 shift up no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);

  check_int64("ps2 decode surface 1",
              er_ps2_keyboard_decode_set1(&state, 0x02u, &action), 1);
  check_int64("ps2 surface action", action.kind, ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE);
  check_uint64("ps2 ledger surface", action.surface_id, ER_UI_LEDGER_APP_LEDGER_ID);
  check_int64("ps2 decode surface 2",
              er_ps2_keyboard_decode_set1(&state, 0x03u, &action), 1);
  check_uint64("ps2 payments surface", action.surface_id, ER_UI_LEDGER_APP_PAYMENTS_ID);
  check_int64("ps2 decode surface 3",
              er_ps2_keyboard_decode_set1(&state, 0x04u, &action), 1);
  check_uint64("ps2 access surface", action.surface_id, ER_UI_LEDGER_APP_ACCESS_ID);

  check_int64("ps2 extended prefix",
              er_ps2_keyboard_decode_set1(&state, 0xe0u, &action), 1);
  check_int64("ps2 extended prefix no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);
  check_int64("ps2 extended right arrow",
              er_ps2_keyboard_decode_set1(&state, 0x4du, &action), 1);
  check_int64("ps2 right arrow key", action.key.kind, ER_UI_KEY_ARROW_RIGHT);
  check_int64("ps2 release ignored",
              er_ps2_keyboard_decode_set1(&state, 0xcdu, &action), 1);
  check_int64("ps2 release no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);

  check_int64("ps2 decode quit",
              er_ps2_keyboard_decode_set1(&state, 0x10u, &action), 1);
  check_int64("ps2 quit action", action.kind, ER_PS2_KEYBOARD_ACTION_QUIT);
  check_int64("ps2 rejects null state",
              er_ps2_keyboard_decode_set1(0, 0x0fu, &action), 0);
  check_int64("ps2 rejects null action",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, 0), 0);
}

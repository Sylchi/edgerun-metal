#include "er_ps2_keyboard.h"

#include "er_bus.h"

#define ER_PS2_DATA_PORT 0x60u
#define ER_PS2_STATUS_PORT 0x64u
#define ER_PS2_STATUS_OUTPUT_FULL 0x01u
#define ER_PS2_SET1_EXTENDED_PREFIX 0xe0u
#define ER_PS2_SET1_RELEASE_MASK 0x80u
#define ER_PS2_SET1_MAKE_MASK 0x7fu
#define ER_PS2_SET1_ESC 0x01u
#define ER_PS2_SET1_1 0x02u
#define ER_PS2_SET1_2 0x03u
#define ER_PS2_SET1_3 0x04u
#define ER_PS2_SET1_Q 0x10u
#define ER_PS2_SET1_TAB 0x0fu
#define ER_PS2_SET1_ENTER 0x1cu
#define ER_PS2_SET1_LEFT_SHIFT 0x2au
#define ER_PS2_SET1_RIGHT_SHIFT 0x36u
#define ER_PS2_SET1_SPACE 0x39u
#define ER_PS2_SET1_HOME 0x47u
#define ER_PS2_SET1_ARROW_UP 0x48u
#define ER_PS2_SET1_PAGE_UP 0x49u
#define ER_PS2_SET1_ARROW_LEFT 0x4bu
#define ER_PS2_SET1_ARROW_RIGHT 0x4du
#define ER_PS2_SET1_END 0x4fu
#define ER_PS2_SET1_ARROW_DOWN 0x50u
#define ER_PS2_SET1_PAGE_DOWN 0x51u
#define ER_PS2_SET1_DELETE 0x53u

void er_ps2_keyboard_action_clear(ErPs2KeyboardAction* action) {
  if (action == 0) return;
  action->kind = ER_PS2_KEYBOARD_ACTION_NONE;
  action->key = er_ui_key(ER_UI_KEY_OTHER);
  action->modifiers = er_ui_key_modifiers(false, false, false, false);
  action->surface_id = 0u;
}

static er_ui_key_modifiers_t er_ps2_keyboard_modifiers(const ErPs2KeyboardState* state) {
  return er_ui_key_modifiers_shift((bool)(state != 0 &&
                                          (state->left_shift_down != 0u ||
                                           state->right_shift_down != 0u)));
}

static void er_ps2_keyboard_set_ui_key(const ErPs2KeyboardState* state,
                                       er_ui_key_kind_t key,
                                       ErPs2KeyboardAction* out_action) {
  out_action->kind = ER_PS2_KEYBOARD_ACTION_UI_KEY;
  out_action->key = er_ui_key(key);
  out_action->modifiers = er_ps2_keyboard_modifiers(state);
}

static UINT8 er_ps2_keyboard_set_surface(UINT8 make_code, ErPs2KeyboardAction* out_action) {
  switch (make_code) {
    case ER_PS2_SET1_1:
      out_action->kind = ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE;
      out_action->surface_id = ER_UI_LEDGER_APP_LEDGER_ID;
      return 1u;
    case ER_PS2_SET1_2:
      out_action->kind = ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE;
      out_action->surface_id = ER_UI_LEDGER_APP_PAYMENTS_ID;
      return 1u;
    case ER_PS2_SET1_3:
      out_action->kind = ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE;
      out_action->surface_id = ER_UI_LEDGER_APP_ACCESS_ID;
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_ps2_keyboard_set_key(UINT8 make_code,
                                     const ErPs2KeyboardState* state,
                                     ErPs2KeyboardAction* out_action) {
  switch (make_code) {
    case ER_PS2_SET1_ESC:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ESCAPE, out_action);
      return 1u;
    case ER_PS2_SET1_TAB:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_TAB, out_action);
      return 1u;
    case ER_PS2_SET1_ENTER:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ENTER, out_action);
      return 1u;
    case ER_PS2_SET1_SPACE:
      out_action->kind = ER_PS2_KEYBOARD_ACTION_UI_KEY;
      out_action->key = er_ui_key_other(' ');
      out_action->modifiers = er_ps2_keyboard_modifiers(state);
      return 1u;
    case ER_PS2_SET1_HOME:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_HOME, out_action);
      return 1u;
    case ER_PS2_SET1_END:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_END, out_action);
      return 1u;
    case ER_PS2_SET1_PAGE_UP:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_PAGE_UP, out_action);
      return 1u;
    case ER_PS2_SET1_PAGE_DOWN:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_PAGE_DOWN, out_action);
      return 1u;
    case ER_PS2_SET1_DELETE:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_DELETE, out_action);
      return 1u;
    case ER_PS2_SET1_ARROW_LEFT:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ARROW_LEFT, out_action);
      return 1u;
    case ER_PS2_SET1_ARROW_RIGHT:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ARROW_RIGHT, out_action);
      return 1u;
    case ER_PS2_SET1_ARROW_UP:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ARROW_UP, out_action);
      return 1u;
    case ER_PS2_SET1_ARROW_DOWN:
      er_ps2_keyboard_set_ui_key(state, ER_UI_KEY_ARROW_DOWN, out_action);
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_ps2_keyboard_decode_set1(ErPs2KeyboardState* state, UINT8 scan_code,
                                  ErPs2KeyboardAction* out_action) {
  UINT8 make_code;
  UINT8 released;

  if (state == 0 || out_action == 0) {
    return 0u;
  }
  er_ps2_keyboard_action_clear(out_action);

  if (scan_code == ER_PS2_SET1_EXTENDED_PREFIX) {
    state->extended = 1u;
    return 1u;
  }

  make_code = (UINT8)(scan_code & ER_PS2_SET1_MAKE_MASK);
  released = (UINT8)((scan_code & ER_PS2_SET1_RELEASE_MASK) != 0u);

  if (make_code == ER_PS2_SET1_LEFT_SHIFT) {
    state->left_shift_down = (UINT8)(released == 0u);
    state->extended = 0u;
    return 1u;
  }
  if (make_code == ER_PS2_SET1_RIGHT_SHIFT) {
    state->right_shift_down = (UINT8)(released == 0u);
    state->extended = 0u;
    return 1u;
  }
  if (released != 0u) {
    state->extended = 0u;
    return 1u;
  }

  if (state->extended == 0u && make_code == ER_PS2_SET1_Q) {
    out_action->kind = ER_PS2_KEYBOARD_ACTION_QUIT;
    return 1u;
  }

  if (state->extended == 0u &&
      er_ps2_keyboard_set_surface(make_code, out_action) != 0u) {
    return 1u;
  }
  (void)er_ps2_keyboard_set_key(make_code, state, out_action);
  state->extended = 0u;
  return 1u;
}

UINT8 er_ps2_keyboard_poll(ErPs2KeyboardState* state, ErPs2KeyboardAction* out_action) {
  ErBusAddress status_port;
  ErBusAddress data_port;
  UINT8 status;
  UINT8 scan_code;

  if (state == 0 || out_action == 0) {
    return 0u;
  }
  er_ps2_keyboard_action_clear(out_action);

  if (er_bus_prepare_io_port_address(ER_PS2_STATUS_PORT, ER_BUS_ACCESS_READ8, &status_port) == 0u ||
      er_bus_prepare_io_port_address(ER_PS2_DATA_PORT, ER_BUS_ACCESS_READ8, &data_port) == 0u) {
    return 0u;
  }
  if (er_bus_read8(&status_port, 0u, &status) == 0u) {
    return 0u;
  }
  if ((status & ER_PS2_STATUS_OUTPUT_FULL) == 0u) {
    return 1u;
  }
  if (er_bus_read8(&data_port, 0u, &scan_code) == 0u) {
    return 0u;
  }
  return er_ps2_keyboard_decode_set1(state, scan_code, out_action);
}

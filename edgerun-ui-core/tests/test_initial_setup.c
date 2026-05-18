#include "test_common.h"

static er_ui_action_t test_button_action(uint32_t id) {
  er_ui_action_t action = {0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, id, 0.0f, 0.0f, 10.0f, 10.0f);
  return action;
}

static void test_initial_setup_state_validates_and_emits_intent(void) {
  char password[64];
  char confirm[64];
  char status[96];
  er_ui_initial_setup_state_t state = {0};
  expect_status(er_ui_initial_setup_state_init(&state, password, sizeof(password), confirm, sizeof(confirm), status, sizeof(status)), ER_UI_OK,
                "initial setup: state init succeeds");
  expect_status(er_ui_initial_setup_set_password(&state, "short"), ER_UI_OK, "initial setup: short password stores");
  expect_status(er_ui_initial_setup_set_confirm_password(&state, "short"), ER_UI_OK, "initial setup: short confirm stores");
  er_ui_initial_setup_intent_t intent = er_ui_initial_setup_handle_action(&state, test_button_action(ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID));
  expect_size(intent.kind, ER_UI_INITIAL_SETUP_INTENT_NONE, "initial setup: short password has no intent");
  expect_string(state.status, "password must be at least 8 bytes", "initial setup: short password status");

  expect_status(er_ui_initial_setup_set_password(&state, "correct horse battery"), ER_UI_OK, "initial setup: password stores");
  expect_status(er_ui_initial_setup_set_confirm_password(&state, "wrong horse battery"), ER_UI_OK, "initial setup: mismatched confirm stores");
  intent = er_ui_initial_setup_handle_action(&state, test_button_action(ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID));
  expect_size(intent.kind, ER_UI_INITIAL_SETUP_INTENT_NONE, "initial setup: mismatch has no intent");
  expect_string(state.status, "passwords do not match", "initial setup: mismatch status");

  expect_status(er_ui_initial_setup_set_confirm_password(&state, "correct horse battery"), ER_UI_OK, "initial setup: matching confirm stores");
  intent = er_ui_initial_setup_handle_action(&state, test_button_action(ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID));
  expect_size(intent.kind, ER_UI_INITIAL_SETUP_INTENT_CREATE_PASSWORD_ROOT, "initial setup: valid password emits intent");
  expect_true(intent.password == state.password, "initial setup: intent borrows password");
  expect_size(intent.password_len, state.password_len, "initial setup: intent password length");
  expect_true(state.busy, "initial setup: valid submit marks busy");

  expect_status(er_ui_initial_setup_mark_configured(&state, 128u), ER_UI_OK, "initial setup: mark configured succeeds");
  expect_true(state.configured, "initial setup: configured flag set");
  expect_true(!state.busy, "initial setup: configured clears busy");
  expect_size(state.password_len, 0u, "initial setup: configured clears password");
  expect_string(state.status, "password root configured", "initial setup: configured status");
}

static void test_initial_setup_surface_emits_fields_and_button(void) {
  char password[64];
  char confirm[64];
  char status[96];
  er_ui_initial_setup_state_t state = {0};
  er_ui_initial_setup_surface_t surface = {0};
  expect_status(er_ui_initial_setup_state_init(&state, password, sizeof(password), confirm, sizeof(confirm), status, sizeof(status)), ER_UI_OK,
                "initial setup surface: state init succeeds");
  expect_status(er_ui_initial_setup_set_password(&state, "correct horse battery"), ER_UI_OK, "initial setup surface: password stores");
  expect_status(er_ui_initial_setup_build_surface(&state, &surface), ER_UI_OK, "initial setup surface: builds");
  expect_size(surface.root.kind, ER_UI_NODE_COLUMN, "initial setup surface: root is column");
  expect_size(surface.root.child_count, 2u, "initial setup surface: root child count");
  er_ui_a11y_node_t a11y = {0};
  expect_status(er_ui_node_accessibility(&surface.nodes[11], &a11y), ER_UI_OK, "initial setup surface: password field a11y");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "initial setup surface: password field role");
  expect_true(a11y.has_id && a11y.id == ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID, "initial setup surface: password field id");
  expect_string(surface.nodes[11].value, "masked", "initial setup surface: password value is masked");
  expect_status(er_ui_node_accessibility(&surface.nodes[13], &a11y), ER_UI_OK, "initial setup surface: create button a11y");
  expect_true(a11y.has_id && a11y.id == ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID, "initial setup surface: create button id");
}

static void test_yubikey_grant_validates_pin_and_surface(void) {
  char pin[16];
  char status[96];
  er_ui_yubikey_grant_state_t state = {0};
  expect_status(er_ui_yubikey_grant_state_init(&state, pin, sizeof(pin), status, sizeof(status)), ER_UI_OK, "yubikey: state init succeeds");
  expect_status(er_ui_yubikey_grant_set_pin(&state, "12a345"), ER_UI_OK, "yubikey: pin filters digits");
  expect_string(state.pin, "12345", "yubikey: non-digits are filtered");
  er_ui_yubikey_grant_intent_t intent = er_ui_yubikey_grant_handle_action(&state, test_button_action(ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID));
  expect_size(intent.kind, ER_UI_YUBIKEY_GRANT_INTENT_NONE, "yubikey: short pin has no intent");
  expect_string(state.status, "PIV PIN must be 6 to 8 digits", "yubikey: short pin status");

  expect_status(er_ui_yubikey_grant_set_pin(&state, "123456789"), ER_UI_OK, "yubikey: long pin truncates to max");
  expect_string(state.pin, "12345678", "yubikey: pin max length");
  intent = er_ui_yubikey_grant_handle_action(&state, test_button_action(ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID));
  expect_size(intent.kind, ER_UI_YUBIKEY_GRANT_INTENT_SIGN_GRANT, "yubikey: valid pin emits sign intent");
  expect_true(intent.has_pin, "yubikey: intent has pin");
  expect_size(intent.pin_len, 8u, "yubikey: intent pin length");

  expect_status(er_ui_yubikey_grant_mark_signed(&state, "grant signed"), ER_UI_OK, "yubikey: mark signed succeeds");
  expect_true(state.signed_grant, "yubikey: signed flag set");
  er_ui_initial_setup_surface_t surface = {0};
  expect_status(er_ui_yubikey_grant_build_surface(&state, &surface), ER_UI_OK, "yubikey: surface builds");
  expect_size(surface.root.kind, ER_UI_NODE_CARD, "yubikey: root is card");
  expect_size(surface.root.child_count, 4u, "yubikey: root child count");
  expect_string(surface.nodes[5].label, "signed", "yubikey: signed badge label");
}

void run_initial_setup_tests(void) {
  test_initial_setup_state_validates_and_emits_intent();
  test_initial_setup_surface_emits_fields_and_button();
  test_yubikey_grant_validates_pin_and_surface();
}

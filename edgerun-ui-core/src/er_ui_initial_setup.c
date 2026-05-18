#include "er_ui_initial_setup.h"

static const er_ui_color4_t ER_UI_INITIAL_SETUP_ACCENT = {0.090f, 0.650f, 0.530f, 1.0f};
static const er_ui_color4_t ER_UI_INITIAL_SETUP_AMBER = {0.920f, 0.660f, 0.250f, 1.0f};
static const char ER_UI_INITIAL_SETUP_STATUS_WAITING[] = "waiting for local secret";
static const char ER_UI_INITIAL_SETUP_STATUS_CONFIGURED[] = "configured";
static const char ER_UI_INITIAL_SETUP_STATUS_TOO_SHORT[] = "password must be at least 8 bytes";
static const char ER_UI_INITIAL_SETUP_STATUS_MISMATCH[] = "passwords do not match";
static const char ER_UI_INITIAL_SETUP_STATUS_DONE[] = "password root configured";
static const char ER_UI_YUBIKEY_STATUS_WAITING[] = "waiting for YubiKey signature";
static const char ER_UI_YUBIKEY_STATUS_BAD_PIN[] = "PIV PIN must be 6 to 8 digits";
static const char ER_UI_MASKED_VALUE[] = "masked";
static const char ER_UI_EMPTY_VALUE[] = "";

static size_t er_ui_setup_cstr_len(const char* value) {
  if (!value) return 0u;
  size_t len = 0u;
  while (value[len] != '\0') len++;
  return len;
}

static er_ui_status_t er_ui_setup_copy(char* dst, size_t capacity, size_t* out_len, const char* src) {
  if (!dst || capacity == 0u || !out_len || !src) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t src_len = er_ui_setup_cstr_len(src);
  if (src_len + 1u > capacity) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < src_len; ++i) dst[i] = src[i];
  dst[src_len] = '\0';
  *out_len = src_len;
  return ER_UI_OK;
}

static void er_ui_setup_clear(char* dst, size_t capacity, size_t* len) {
  if (dst && capacity > 0u) dst[0] = '\0';
  if (len) *len = 0u;
}

static bool er_ui_setup_action_submits(er_ui_action_t action, uint32_t field_id, uint32_t button_id) {
  if (action.kind == ER_UI_ACTION_SUBMITTED && action.id == field_id) return true;
  return action.kind == ER_UI_ACTION_ACTIVATED && action.has_hit && action.hit.kind == ER_UI_HIT_BUTTON && action.hit.id == button_id;
}

static er_ui_status_t er_ui_setup_add(er_ui_node_t* parent, er_ui_node_t* child) {
  return er_ui_node_add_child(parent, child);
}

static er_ui_node_t er_ui_setup_field(const char* label, bool has_value, uint32_t id) {
  return er_ui_node_field(label, has_value ? ER_UI_MASKED_VALUE : ER_UI_EMPTY_VALUE, id);
}

er_ui_status_t er_ui_initial_setup_state_init(
  er_ui_initial_setup_state_t* state,
  char* password,
  size_t password_capacity,
  char* confirm_password,
  size_t confirm_password_capacity,
  char* status,
  size_t status_capacity) {
  if (!state || !password || password_capacity == 0u || !confirm_password || confirm_password_capacity == 0u || !status || status_capacity == 0u) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  *state = (er_ui_initial_setup_state_t){0};
  state->password = password;
  state->password_capacity = password_capacity;
  state->confirm_password = confirm_password;
  state->confirm_password_capacity = confirm_password_capacity;
  state->status = status;
  state->status_capacity = status_capacity;
  er_ui_setup_clear(state->password, state->password_capacity, &state->password_len);
  er_ui_setup_clear(state->confirm_password, state->confirm_password_capacity, &state->confirm_password_len);
  er_ui_setup_clear(state->status, state->status_capacity, &state->status_len);
  return ER_UI_OK;
}

er_ui_status_t er_ui_initial_setup_set_password(er_ui_initial_setup_state_t* state, const char* value) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_setup_copy(state->password, state->password_capacity, &state->password_len, value);
  if (status != ER_UI_OK) return status;
  er_ui_setup_clear(state->status, state->status_capacity, &state->status_len);
  return ER_UI_OK;
}

er_ui_status_t er_ui_initial_setup_set_confirm_password(er_ui_initial_setup_state_t* state, const char* value) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_setup_copy(state->confirm_password, state->confirm_password_capacity, &state->confirm_password_len, value);
  if (status != ER_UI_OK) return status;
  er_ui_setup_clear(state->status, state->status_capacity, &state->status_len);
  return ER_UI_OK;
}

er_ui_initial_setup_intent_t er_ui_initial_setup_handle_action(er_ui_initial_setup_state_t* state, er_ui_action_t action) {
  er_ui_initial_setup_intent_t none = {0};
  if (!state || state->busy) return none;
  bool submits = er_ui_setup_action_submits(action, ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID, ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID) ||
                 er_ui_setup_action_submits(action, ER_UI_INITIAL_SETUP_CONFIRM_FIELD_ID, ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID);
  if (!submits) return none;
  if (state->password_len < ER_UI_INITIAL_SETUP_PASSWORD_MIN_LEN) {
    (void)er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, ER_UI_INITIAL_SETUP_STATUS_TOO_SHORT);
    return none;
  }
  if (state->password_len != state->confirm_password_len) {
    (void)er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, ER_UI_INITIAL_SETUP_STATUS_MISMATCH);
    return none;
  }
  for (size_t i = 0u; i < state->password_len; ++i) {
    if (state->password[i] != state->confirm_password[i]) {
      (void)er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, ER_UI_INITIAL_SETUP_STATUS_MISMATCH);
      return none;
    }
  }
  state->busy = true;
  er_ui_initial_setup_intent_t intent = {0};
  intent.kind = ER_UI_INITIAL_SETUP_INTENT_CREATE_PASSWORD_ROOT;
  intent.password = state->password;
  intent.password_len = state->password_len;
  return intent;
}

er_ui_status_t er_ui_initial_setup_mark_configured(er_ui_initial_setup_state_t* state, size_t envelope_len) {
  (void)envelope_len;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_setup_clear(state->password, state->password_capacity, &state->password_len);
  er_ui_setup_clear(state->confirm_password, state->confirm_password_capacity, &state->confirm_password_len);
  state->busy = false;
  state->configured = true;
  return er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, ER_UI_INITIAL_SETUP_STATUS_DONE);
}

er_ui_status_t er_ui_initial_setup_mark_error(er_ui_initial_setup_state_t* state, const char* message) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  state->busy = false;
  return er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, message);
}

er_ui_status_t er_ui_initial_setup_build_surface(const er_ui_initial_setup_state_t* state, er_ui_initial_setup_surface_t* out_surface) {
  if (!state || !out_surface) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_surface = (er_ui_initial_setup_surface_t){0};
  const char* status = state->status_len > 0u ? state->status : (state->configured ? ER_UI_INITIAL_SETUP_STATUS_CONFIGURED : ER_UI_INITIAL_SETUP_STATUS_WAITING);
  out_surface->root = er_ui_node_column();
  er_ui_node_set_gap(&out_surface->root, 16.0f);
  out_surface->nodes[0] = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->nodes[0], 12.0f, 8.0f, 0.0f);
  out_surface->nodes[1] = er_ui_node_row();
  out_surface->nodes[2] = er_ui_node_text("Initial Setup");
  out_surface->nodes[3] = er_ui_node_badge(state->configured ? "ready" : "required", state->configured ? ER_UI_SHADCN_BADGE_DEFAULT : ER_UI_SHADCN_BADGE_SECONDARY);
  out_surface->nodes[4] = er_ui_node_text(status);
  out_surface->nodes[5] = er_ui_node_progress(state->configured ? 1.0f : 0.15f);
  out_surface->nodes[5].color = state->configured ? ER_UI_INITIAL_SETUP_ACCENT : ER_UI_INITIAL_SETUP_AMBER;
  out_surface->nodes[6] = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->nodes[6], 12.0f, 10.0f, 0.0f);
  out_surface->nodes[7] = er_ui_node_row();
  out_surface->nodes[8] = er_ui_node_icon(ER_UI_ICON_LOCK, "Password Root", ER_UI_INITIAL_SETUP_ACCENT);
  out_surface->nodes[9] = er_ui_node_text("Password Root");
  out_surface->nodes[10] = er_ui_node_separator();
  out_surface->nodes[11] = er_ui_setup_field("Password", state->password_len > 0u, ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID);
  out_surface->nodes[12] = er_ui_setup_field("Confirm password", state->confirm_password_len > 0u, ER_UI_INITIAL_SETUP_CONFIRM_FIELD_ID);
  out_surface->nodes[13] = er_ui_node_button(state->busy ? "Working" : "Create", ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID, ER_UI_SHADCN_BUTTON_DEFAULT);
  er_ui_status_t status_code = er_ui_setup_add(&out_surface->nodes[1], &out_surface->nodes[2]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[1], &out_surface->nodes[3]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[1]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[4]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[5]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[7], &out_surface->nodes[8]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[7], &out_surface->nodes[9]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[6], &out_surface->nodes[7]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[6], &out_surface->nodes[10]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[6], &out_surface->nodes[11]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[6], &out_surface->nodes[12]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[6], &out_surface->nodes[13]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[0]);
  if (status_code != ER_UI_OK) return status_code;
  return er_ui_setup_add(&out_surface->root, &out_surface->nodes[6]);
}

er_ui_status_t er_ui_yubikey_grant_state_init(er_ui_yubikey_grant_state_t* state, char* pin, size_t pin_capacity, char* status, size_t status_capacity) {
  if (!state || !pin || pin_capacity == 0u || !status || status_capacity == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  *state = (er_ui_yubikey_grant_state_t){0};
  state->pin = pin;
  state->pin_capacity = pin_capacity;
  state->status = status;
  state->status_capacity = status_capacity;
  er_ui_setup_clear(state->pin, state->pin_capacity, &state->pin_len);
  er_ui_setup_clear(state->status, state->status_capacity, &state->status_len);
  return ER_UI_OK;
}

er_ui_status_t er_ui_yubikey_grant_set_pin(er_ui_yubikey_grant_state_t* state, const char* value) {
  if (!state || !value) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t count = 0u;
  for (size_t i = 0u; value[i] != '\0'; ++i) {
    if (value[i] >= '0' && value[i] <= '9' && count < ER_UI_YUBIKEY_GRANT_PIN_MAX_LEN) {
      if (count + 1u >= state->pin_capacity) return ER_UI_ERR_INVALID_ARGUMENT;
      state->pin[count++] = value[i];
    }
  }
  state->pin[count] = '\0';
  state->pin_len = count;
  er_ui_setup_clear(state->status, state->status_capacity, &state->status_len);
  return ER_UI_OK;
}

er_ui_yubikey_grant_intent_t er_ui_yubikey_grant_handle_action(er_ui_yubikey_grant_state_t* state, er_ui_action_t action) {
  er_ui_yubikey_grant_intent_t none = {0};
  if (!state || state->busy) return none;
  if (!er_ui_setup_action_submits(action, ER_UI_YUBIKEY_GRANT_PIN_FIELD_ID, ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID)) return none;
  if (state->pin_len > 0u && state->pin_len < ER_UI_YUBIKEY_GRANT_PIN_MIN_LEN) {
    er_ui_setup_clear(state->pin, state->pin_capacity, &state->pin_len);
    (void)er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, ER_UI_YUBIKEY_STATUS_BAD_PIN);
    return none;
  }
  er_ui_yubikey_grant_intent_t intent = {0};
  intent.kind = ER_UI_YUBIKEY_GRANT_INTENT_SIGN_GRANT;
  intent.has_pin = state->pin_len > 0u;
  intent.pin = state->pin;
  intent.pin_len = state->pin_len;
  state->busy = true;
  return intent;
}

er_ui_status_t er_ui_yubikey_grant_mark_signed(er_ui_yubikey_grant_state_t* state, const char* summary) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_setup_clear(state->pin, state->pin_capacity, &state->pin_len);
  state->busy = false;
  state->signed_grant = true;
  return er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, summary);
}

er_ui_status_t er_ui_yubikey_grant_mark_error(er_ui_yubikey_grant_state_t* state, const char* message) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_setup_clear(state->pin, state->pin_capacity, &state->pin_len);
  state->busy = false;
  return er_ui_setup_copy(state->status, state->status_capacity, &state->status_len, message);
}

er_ui_status_t er_ui_yubikey_grant_build_surface(const er_ui_yubikey_grant_state_t* state, er_ui_initial_setup_surface_t* out_surface) {
  if (!state || !out_surface) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_surface = (er_ui_initial_setup_surface_t){0};
  const char* status = state->status_len > 0u ? state->status : (state->signed_grant ? "signed" : ER_UI_YUBIKEY_STATUS_WAITING);
  out_surface->root = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->root, 12.0f, 10.0f, 0.0f);
  out_surface->nodes[0] = er_ui_node_row();
  out_surface->nodes[1] = er_ui_node_icon(ER_UI_ICON_KEY, "YubiKey", ER_UI_INITIAL_SETUP_ACCENT);
  out_surface->nodes[2] = er_ui_node_column();
  out_surface->nodes[3] = er_ui_node_text("YubiKey Grant Signature");
  out_surface->nodes[4] = er_ui_node_text(status);
  out_surface->nodes[5] = er_ui_node_badge(state->signed_grant ? "signed" : "required", state->signed_grant ? ER_UI_SHADCN_BADGE_DEFAULT : ER_UI_SHADCN_BADGE_SECONDARY);
  out_surface->nodes[6] = er_ui_node_separator();
  out_surface->nodes[7] = er_ui_setup_field("PIV PIN", state->pin_len > 0u, ER_UI_YUBIKEY_GRANT_PIN_FIELD_ID);
  out_surface->nodes[8] = er_ui_node_button(state->busy ? "Signing" : "Sign", ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID, ER_UI_SHADCN_BUTTON_DEFAULT);
  er_ui_status_t status_code = er_ui_setup_add(&out_surface->nodes[2], &out_surface->nodes[3]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[2], &out_surface->nodes[4]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[1]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[2]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[0], &out_surface->nodes[5]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[0]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[6]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[7]);
  if (status_code != ER_UI_OK) return status_code;
  return er_ui_setup_add(&out_surface->root, &out_surface->nodes[8]);
}

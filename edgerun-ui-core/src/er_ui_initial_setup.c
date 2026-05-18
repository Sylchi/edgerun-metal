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
static const char ER_UI_YUBIKEY_STATUS_SIGNED[] = "signed";
static const char ER_UI_MASKED_VALUE[] = "masked";
static const char ER_UI_EMPTY_VALUE[] = "";
static const float ER_UI_INITIAL_SETUP_ROOT_GAP = 16.0f;
static const float ER_UI_INITIAL_SETUP_STATUS_PAD_X = 12.0f;
static const float ER_UI_INITIAL_SETUP_STATUS_PAD_Y = 8.0f;
static const float ER_UI_INITIAL_SETUP_FORM_PAD_X = 12.0f;
static const float ER_UI_INITIAL_SETUP_FORM_PAD_Y = 10.0f;
static const float ER_UI_INITIAL_SETUP_PROGRESS_DONE = 1.0f;
static const float ER_UI_INITIAL_SETUP_PROGRESS_WAITING = 0.15f;
static const uint8_t ER_UI_FINGERPRINT_RECORD_MAGIC[] = {'E', 'R', 'F', 'G', '1'};
static const uint8_t ER_UI_TPM_RECORD_MAGIC[] = {'E', 'R', 'T', 'D', '1'};
static const uint8_t ER_UI_YUBIKEY_RECORD_MAGIC[] = {'E', 'R', 'Y', 'U', '1'};
static const uint8_t ER_UI_DEVICE_GRANT_RECORD_MAGIC[] = {'E', 'R', 'D', 'G', '1'};
static const uint8_t ER_UI_DEVICE_GRANT_DOMAIN[] = "edgerun:v1:ui:initial-setup:user-device-admission-grant";

typedef enum {
  ER_UI_SETUP_SPAN_STRING = 0,
  ER_UI_SETUP_SPAN_BYTES
} er_ui_setup_span_kind_t;

static bool er_ui_initial_setup_state_init_args_valid(
  const er_ui_initial_setup_state_t* state,
  const char* password,
  size_t password_capacity,
  const char* confirm_password,
  size_t confirm_password_capacity,
  const char* status,
  size_t status_capacity) {
  return state != 0 &&
         password != 0 &&
         password_capacity > 0u &&
         confirm_password != 0 &&
         confirm_password_capacity > 0u &&
         status != 0 &&
         status_capacity > 0u;
}

typedef enum {
  ER_UI_SETUP_SURFACE_STATUS_CARD = 0,
  ER_UI_SETUP_SURFACE_STATUS_HEADER,
  ER_UI_SETUP_SURFACE_TITLE,
  ER_UI_SETUP_SURFACE_STATUS_BADGE,
  ER_UI_SETUP_SURFACE_STATUS_TEXT,
  ER_UI_SETUP_SURFACE_PROGRESS,
  ER_UI_SETUP_SURFACE_FORM_CARD,
  ER_UI_SETUP_SURFACE_FORM_HEADER,
  ER_UI_SETUP_SURFACE_FORM_ICON,
  ER_UI_SETUP_SURFACE_FORM_TITLE,
  ER_UI_SETUP_SURFACE_FORM_SEPARATOR,
  ER_UI_SETUP_SURFACE_PASSWORD_FIELD,
  ER_UI_SETUP_SURFACE_CONFIRM_FIELD,
  ER_UI_SETUP_SURFACE_CREATE_BUTTON
} er_ui_setup_surface_node_t;

typedef enum {
  ER_UI_YUBIKEY_SURFACE_HEADER = 0,
  ER_UI_YUBIKEY_SURFACE_ICON,
  ER_UI_YUBIKEY_SURFACE_COPY,
  ER_UI_YUBIKEY_SURFACE_TITLE,
  ER_UI_YUBIKEY_SURFACE_STATUS_TEXT,
  ER_UI_YUBIKEY_SURFACE_STATUS_BADGE,
  ER_UI_YUBIKEY_SURFACE_SEPARATOR,
  ER_UI_YUBIKEY_SURFACE_PIN_FIELD,
  ER_UI_YUBIKEY_SURFACE_SIGN_BUTTON
} er_ui_yubikey_surface_node_t;

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

static bool er_ui_setup_string_span_valid(er_ui_initial_setup_string_span_t value) {
  return value.bytes || value.len == 0u;
}

static bool er_ui_setup_byte_span_valid(er_ui_initial_setup_byte_span_t value) {
  return value.bytes || value.len == 0u;
}

static er_ui_record_status_t er_ui_setup_record_done(er_ui_record_writer_t* writer, size_t* out_len) {
  if (!out_len) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  *out_len = er_ui_record_writer_len(writer);
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_setup_write_string_span(er_ui_record_writer_t* writer, er_ui_initial_setup_string_span_t value) {
  if (!er_ui_setup_string_span_valid(value)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return er_ui_record_write_string(writer, value.bytes, value.len);
}

static er_ui_record_status_t er_ui_setup_write_byte_span(er_ui_record_writer_t* writer, er_ui_initial_setup_byte_span_t value) {
  if (!er_ui_setup_byte_span_valid(value)) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return er_ui_record_write_bytes(writer, value.bytes, value.len);
}

static er_ui_record_status_t er_ui_setup_write_byte_vec(
  er_ui_record_writer_t* writer,
  const er_ui_initial_setup_byte_span_t* values,
  size_t count) {
  if (!values && count > 0u) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_status_t status = er_ui_record_write_vec_len(writer, count);
  if (status != ER_UI_RECORD_OK) return status;
  for (size_t i = 0u; i < count; ++i) {
    status = er_ui_setup_write_byte_span(writer, values[i]);
    if (status != ER_UI_RECORD_OK) return status;
  }
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_setup_write_string_vec(
  er_ui_record_writer_t* writer,
  const er_ui_initial_setup_string_span_t* values,
  size_t count) {
  if (!values && count > 0u) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_status_t status = er_ui_record_write_vec_len(writer, count);
  if (status != ER_UI_RECORD_OK) return status;
  for (size_t i = 0u; i < count; ++i) {
    status = er_ui_setup_write_string_span(writer, values[i]);
    if (status != ER_UI_RECORD_OK) return status;
  }
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_setup_read_string_span(er_ui_record_reader_t* reader, er_ui_initial_setup_string_span_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return er_ui_record_read_string(reader, &out_value->bytes, &out_value->len);
}

static er_ui_record_status_t er_ui_setup_read_byte_span(er_ui_record_reader_t* reader, er_ui_initial_setup_byte_span_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  return er_ui_record_read_bytes(reader, &out_value->bytes, &out_value->len);
}

static er_ui_record_status_t er_ui_setup_read_vec_header(
  er_ui_record_reader_t* reader,
  const void* values,
  size_t capacity,
  size_t* out_count,
  size_t* count) {
  if (!out_count) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_status_t status = er_ui_record_read_vec_len(reader, count);
  if (status != ER_UI_RECORD_OK) return status;
  if ((!values && *count > 0u) || *count > capacity) return ER_UI_RECORD_ERR_NO_SPACE;
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_setup_read_span_vec(
  er_ui_record_reader_t* reader,
  void* values,
  size_t capacity,
  size_t* out_count,
  er_ui_setup_span_kind_t kind) {
  size_t count = 0u;
  er_ui_record_status_t status = er_ui_setup_read_vec_header(reader, values, capacity, out_count, &count);
  if (status != ER_UI_RECORD_OK) return status;
  for (size_t i = 0u; i < count; ++i) {
    switch (kind) {
      case ER_UI_SETUP_SPAN_STRING:
        status = er_ui_setup_read_string_span(reader, &((er_ui_initial_setup_string_span_t*)values)[i]);
        break;
      case ER_UI_SETUP_SPAN_BYTES:
        status = er_ui_setup_read_byte_span(reader, &((er_ui_initial_setup_byte_span_t*)values)[i]);
        break;
      default:
        status = ER_UI_RECORD_ERR_INVALID_ARGUMENT;
        break;
    }
    if (status != ER_UI_RECORD_OK) return status;
  }
  *out_count = count;
  return ER_UI_RECORD_OK;
}

static er_ui_record_status_t er_ui_setup_read_string_vec(
  er_ui_record_reader_t* reader,
  er_ui_initial_setup_string_span_t* values,
  size_t capacity,
  size_t* out_count) {
  return er_ui_setup_read_span_vec(reader, values, capacity, out_count, ER_UI_SETUP_SPAN_STRING);
}

static er_ui_record_status_t er_ui_setup_read_byte_vec(
  er_ui_record_reader_t* reader,
  er_ui_initial_setup_byte_span_t* values,
  size_t capacity,
  size_t* out_count) {
  return er_ui_setup_read_span_vec(reader, values, capacity, out_count, ER_UI_SETUP_SPAN_BYTES);
}

static er_ui_record_status_t er_ui_setup_write_device_grant_fields(
  er_ui_record_writer_t* writer,
  const er_ui_user_device_admission_grant_t* value,
  bool include_signature) {
  er_ui_record_status_t status = er_ui_setup_write_byte_span(writer, value->user_public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(writer, value->user_key_label);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_byte_span(writer, value->device_public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(writer, value->device_key_label);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(writer, value->fingerprint_template_ref);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_vec(writer, value->allowed_roles, value->allowed_roles_count);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_vec(writer, value->allowed_hardware_scopes, value->allowed_hardware_scopes_count);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_write_bool(writer, value->presence_required);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_write_array_32(writer, value->policy_hash);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_write_u64(writer, value->issued_at_secs);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_write_u64(writer, value->expires_at_secs);
  if (status != ER_UI_RECORD_OK || !include_signature) return status;
  return er_ui_setup_write_byte_span(writer, value->user_signature);
}

static er_ui_record_status_t er_ui_setup_write_device_grant_record(
  const er_ui_user_device_admission_grant_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len,
  const uint8_t* magic,
  size_t magic_len,
  bool include_domain,
  bool include_signature) {
  if (!value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_writer_t writer = {0};
  er_ui_record_status_t status = er_ui_record_writer_init(&writer, out, capacity, magic, magic_len);
  if (status != ER_UI_RECORD_OK) return status;
  if (include_domain) {
    status = er_ui_record_write_bytes(&writer, ER_UI_DEVICE_GRANT_DOMAIN, sizeof(ER_UI_DEVICE_GRANT_DOMAIN) - 1u);
    if (status != ER_UI_RECORD_OK) return status;
  }
  status = er_ui_setup_write_device_grant_fields(&writer, value, include_signature);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_setup_record_done(&writer, out_len);
}

er_ui_status_t er_ui_initial_setup_state_init(
  er_ui_initial_setup_state_t* state,
  char* password,
  size_t password_capacity,
  char* confirm_password,
  size_t confirm_password_capacity,
  char* status,
  size_t status_capacity) {
  if (!er_ui_initial_setup_state_init_args_valid(state, password, password_capacity, confirm_password, confirm_password_capacity, status, status_capacity)) {
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
  er_ui_node_set_gap(&out_surface->root, ER_UI_INITIAL_SETUP_ROOT_GAP);
  out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD] = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD], ER_UI_INITIAL_SETUP_STATUS_PAD_X, ER_UI_INITIAL_SETUP_STATUS_PAD_Y, 0.0f);
  out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_HEADER] = er_ui_node_row();
  out_surface->nodes[ER_UI_SETUP_SURFACE_TITLE] = er_ui_node_text("Initial Setup");
  out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_BADGE] = er_ui_node_badge(
    state->configured ? "ready" : "required",
    state->configured ? ER_UI_COMPONENT_BADGE_DEFAULT : ER_UI_COMPONENT_BADGE_SECONDARY);
  out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_TEXT] = er_ui_node_text(status);
  out_surface->nodes[ER_UI_SETUP_SURFACE_PROGRESS] =
    er_ui_node_progress(state->configured ? ER_UI_INITIAL_SETUP_PROGRESS_DONE : ER_UI_INITIAL_SETUP_PROGRESS_WAITING);
  out_surface->nodes[ER_UI_SETUP_SURFACE_PROGRESS].color = state->configured ? ER_UI_INITIAL_SETUP_ACCENT : ER_UI_INITIAL_SETUP_AMBER;
  out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD] = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], ER_UI_INITIAL_SETUP_FORM_PAD_X, ER_UI_INITIAL_SETUP_FORM_PAD_Y, 0.0f);
  out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_HEADER] = er_ui_node_row();
  out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_ICON] = er_ui_node_icon(ER_UI_ICON_LOCK, "Password Root", ER_UI_INITIAL_SETUP_ACCENT);
  out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_TITLE] = er_ui_node_text("Password Root");
  out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_SEPARATOR] = er_ui_node_separator();
  out_surface->nodes[ER_UI_SETUP_SURFACE_PASSWORD_FIELD] = er_ui_setup_field("Password", state->password_len > 0u, ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID);
  out_surface->nodes[ER_UI_SETUP_SURFACE_CONFIRM_FIELD] =
    er_ui_setup_field("Confirm password", state->confirm_password_len > 0u, ER_UI_INITIAL_SETUP_CONFIRM_FIELD_ID);
  out_surface->nodes[ER_UI_SETUP_SURFACE_CREATE_BUTTON] =
    er_ui_node_button(state->busy ? "Working" : "Create", ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID, ER_UI_COMPONENT_BUTTON_DEFAULT);
  er_ui_status_t status_code =
    er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_HEADER], &out_surface->nodes[ER_UI_SETUP_SURFACE_TITLE]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_HEADER], &out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_BADGE]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_HEADER]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_TEXT]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_PROGRESS]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_HEADER], &out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_ICON]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_HEADER], &out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_TITLE]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_HEADER]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_SEPARATOR]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_PASSWORD_FIELD]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_CONFIRM_FIELD]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD], &out_surface->nodes[ER_UI_SETUP_SURFACE_CREATE_BUTTON]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_SETUP_SURFACE_STATUS_CARD]);
  if (status_code != ER_UI_OK) return status_code;
  return er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_SETUP_SURFACE_FORM_CARD]);
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
  const char* status = state->status_len > 0u ? state->status : (state->signed_grant ? ER_UI_YUBIKEY_STATUS_SIGNED : ER_UI_YUBIKEY_STATUS_WAITING);
  out_surface->root = er_ui_node_card();
  er_ui_node_set_spacing(&out_surface->root, ER_UI_INITIAL_SETUP_FORM_PAD_X, ER_UI_INITIAL_SETUP_FORM_PAD_Y, 0.0f);
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_HEADER] = er_ui_node_row();
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_ICON] = er_ui_node_icon(ER_UI_ICON_KEY, "YubiKey", ER_UI_INITIAL_SETUP_ACCENT);
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_COPY] = er_ui_node_column();
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_TITLE] = er_ui_node_text("YubiKey Grant Signature");
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_STATUS_TEXT] = er_ui_node_text(status);
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_STATUS_BADGE] = er_ui_node_badge(
    state->signed_grant ? ER_UI_YUBIKEY_STATUS_SIGNED : "required",
    state->signed_grant ? ER_UI_COMPONENT_BADGE_DEFAULT : ER_UI_COMPONENT_BADGE_SECONDARY);
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_SEPARATOR] = er_ui_node_separator();
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_PIN_FIELD] = er_ui_setup_field("PIV PIN", state->pin_len > 0u, ER_UI_YUBIKEY_GRANT_PIN_FIELD_ID);
  out_surface->nodes[ER_UI_YUBIKEY_SURFACE_SIGN_BUTTON] =
    er_ui_node_button(state->busy ? "Signing" : "Sign", ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID, ER_UI_COMPONENT_BUTTON_DEFAULT);
  er_ui_status_t status_code =
    er_ui_setup_add(&out_surface->nodes[ER_UI_YUBIKEY_SURFACE_COPY], &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_TITLE]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_YUBIKEY_SURFACE_COPY], &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_STATUS_TEXT]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_YUBIKEY_SURFACE_HEADER], &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_ICON]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_YUBIKEY_SURFACE_HEADER], &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_COPY]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->nodes[ER_UI_YUBIKEY_SURFACE_HEADER], &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_STATUS_BADGE]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_HEADER]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_SEPARATOR]);
  if (status_code != ER_UI_OK) return status_code;
  status_code = er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_PIN_FIELD]);
  if (status_code != ER_UI_OK) return status_code;
  return er_ui_setup_add(&out_surface->root, &out_surface->nodes[ER_UI_YUBIKEY_SURFACE_SIGN_BUTTON]);
}

er_ui_record_status_t er_ui_fingerprint_presence_ref_write(
  const er_ui_fingerprint_presence_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len) {
  if (!value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_writer_t writer = {0};
  er_ui_record_status_t status = er_ui_record_writer_init(&writer, out, capacity, ER_UI_FINGERPRINT_RECORD_MAGIC, sizeof(ER_UI_FINGERPRINT_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(&writer, value->provider);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(&writer, value->template_ref);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_setup_record_done(&writer, out_len);
}

er_ui_record_status_t er_ui_fingerprint_presence_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_fingerprint_presence_ref_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_reader_t reader = {0};
  er_ui_record_status_t status = er_ui_record_reader_init(&reader, bytes, byte_len, ER_UI_FINGERPRINT_RECORD_MAGIC, sizeof(ER_UI_FINGERPRINT_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->provider);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->template_ref);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_record_reader_finish(&reader);
}

er_ui_record_status_t er_ui_tpm_device_authority_ref_write(
  const er_ui_tpm_device_authority_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len) {
  if (!value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_writer_t writer = {0};
  er_ui_record_status_t status = er_ui_record_writer_init(&writer, out, capacity, ER_UI_TPM_RECORD_MAGIC, sizeof(ER_UI_TPM_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(&writer, value->key_name);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_byte_span(&writer, value->public_key);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_setup_record_done(&writer, out_len);
}

er_ui_record_status_t er_ui_tpm_device_authority_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_tpm_device_authority_ref_t* out_value) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_reader_t reader = {0};
  er_ui_record_status_t status = er_ui_record_reader_init(&reader, bytes, byte_len, ER_UI_TPM_RECORD_MAGIC, sizeof(ER_UI_TPM_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->key_name);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_byte_span(&reader, &out_value->public_key);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_record_reader_finish(&reader);
}

er_ui_record_status_t er_ui_yubikey_user_authority_ref_write(
  const er_ui_yubikey_user_authority_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len) {
  if (!value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_writer_t writer = {0};
  er_ui_record_status_t status = er_ui_record_writer_init(&writer, out, capacity, ER_UI_YUBIKEY_RECORD_MAGIC, sizeof(ER_UI_YUBIKEY_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_string_span(&writer, value->slot);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_byte_span(&writer, value->public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_write_byte_vec(&writer, value->attestation_chain, value->attestation_chain_count);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_setup_record_done(&writer, out_len);
}

er_ui_record_status_t er_ui_yubikey_user_authority_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_yubikey_user_authority_ref_t* out_value,
  er_ui_initial_setup_byte_span_t* attestation_chain,
  size_t attestation_chain_capacity) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_reader_t reader = {0};
  er_ui_record_status_t status = er_ui_record_reader_init(&reader, bytes, byte_len, ER_UI_YUBIKEY_RECORD_MAGIC, sizeof(ER_UI_YUBIKEY_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  out_value->attestation_chain = attestation_chain;
  out_value->attestation_chain_capacity = attestation_chain_capacity;
  status = er_ui_setup_read_string_span(&reader, &out_value->slot);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_byte_span(&reader, &out_value->public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_byte_vec(&reader, attestation_chain, attestation_chain_capacity, &out_value->attestation_chain_count);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_record_reader_finish(&reader);
}

er_ui_record_status_t er_ui_user_device_admission_grant_signing_preimage_write(
  const er_ui_user_device_admission_grant_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len) {
  return er_ui_setup_write_device_grant_record(value, out, capacity, out_len, 0, 0u, true, false);
}

er_ui_record_status_t er_ui_user_device_admission_grant_write(
  const er_ui_user_device_admission_grant_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len) {
  return er_ui_setup_write_device_grant_record(value, out, capacity, out_len, ER_UI_DEVICE_GRANT_RECORD_MAGIC,
                                              sizeof(ER_UI_DEVICE_GRANT_RECORD_MAGIC), false, true);
}

er_ui_record_status_t er_ui_user_device_admission_grant_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_user_device_admission_grant_t* out_value,
  er_ui_initial_setup_string_span_t* allowed_roles,
  size_t allowed_roles_capacity,
  er_ui_initial_setup_string_span_t* allowed_hardware_scopes,
  size_t allowed_hardware_scopes_capacity) {
  if (!out_value) return ER_UI_RECORD_ERR_INVALID_ARGUMENT;
  er_ui_record_reader_t reader = {0};
  er_ui_record_status_t status = er_ui_record_reader_init(&reader, bytes, byte_len, ER_UI_DEVICE_GRANT_RECORD_MAGIC, sizeof(ER_UI_DEVICE_GRANT_RECORD_MAGIC));
  if (status != ER_UI_RECORD_OK) return status;
  out_value->allowed_roles = allowed_roles;
  out_value->allowed_roles_capacity = allowed_roles_capacity;
  out_value->allowed_hardware_scopes = allowed_hardware_scopes;
  out_value->allowed_hardware_scopes_capacity = allowed_hardware_scopes_capacity;
  status = er_ui_setup_read_byte_span(&reader, &out_value->user_public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->user_key_label);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_byte_span(&reader, &out_value->device_public_key);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->device_key_label);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_span(&reader, &out_value->fingerprint_template_ref);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_vec(&reader, allowed_roles, allowed_roles_capacity, &out_value->allowed_roles_count);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_string_vec(&reader, allowed_hardware_scopes, allowed_hardware_scopes_capacity, &out_value->allowed_hardware_scopes_count);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_read_bool(&reader, &out_value->presence_required);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_read_array_32(&reader, out_value->policy_hash);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_read_u64(&reader, &out_value->issued_at_secs);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_record_read_u64(&reader, &out_value->expires_at_secs);
  if (status != ER_UI_RECORD_OK) return status;
  status = er_ui_setup_read_byte_span(&reader, &out_value->user_signature);
  if (status != ER_UI_RECORD_OK) return status;
  return er_ui_record_reader_finish(&reader);
}

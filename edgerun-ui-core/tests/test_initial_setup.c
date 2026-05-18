#include "test_common.h"

static const size_t ER_TEST_INITIAL_SETUP_PASSWORD_CAPACITY = 64u;
static const size_t ER_TEST_INITIAL_SETUP_CONFIRM_CAPACITY = 64u;
static const size_t ER_TEST_INITIAL_SETUP_STATUS_CAPACITY = 96u;
static const size_t ER_TEST_INITIAL_SETUP_CONFIGURED_GENERATION = 128u;
static const size_t ER_TEST_INITIAL_SETUP_ROOT_CHILDREN = 2u;
static const size_t ER_TEST_INITIAL_SETUP_PASSWORD_NODE_INDEX = 11u;
static const size_t ER_TEST_INITIAL_SETUP_CREATE_NODE_INDEX = 13u;
static const size_t ER_TEST_YUBIKEY_PIN_CAPACITY = 16u;
static const size_t ER_TEST_YUBIKEY_PIN_MAX_LEN = 8u;
static const size_t ER_TEST_YUBIKEY_ROOT_CHILDREN = 4u;
static const size_t ER_TEST_YUBIKEY_SIGNED_BADGE_NODE_INDEX = 5u;
static const size_t ER_TEST_INITIAL_SETUP_RECORD_CAPACITY = 1024u;
static const size_t ER_TEST_DEVICE_GRANT_RECORD_CAPACITY = 2048u;
static const size_t ER_TEST_ATTESTATION_CHAIN_COUNT = 2u;
static const size_t ER_TEST_PARSED_CHAIN_CAPACITY = 2u;
static const size_t ER_TEST_SMALL_CHAIN_CAPACITY = 1u;
static const size_t ER_TEST_PARSED_LIST_CAPACITY = 2u;
static const size_t ER_TEST_SMALL_LIST_CAPACITY = 1u;
static const uint8_t ER_TEST_SIGNATURE_BYTE = 3u;
static const uint64_t ER_TEST_GRANT_ISSUED_AT_SECS = 10u;
static const uint64_t ER_TEST_GRANT_EXPIRES_AT_SECS = 20u;

static size_t test_array_count_size(const void* values, size_t bytes, size_t element_size) {
  (void)values;
  return bytes / element_size;
}

static er_ui_action_t test_button_action(uint32_t id) {
  er_ui_action_t action = {0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, id, 0.0f, 0.0f, 10.0f, 10.0f);
  return action;
}

static void expect_initial_record_status(er_ui_record_status_t got, er_ui_record_status_t expected, const char* name) {
  expect_true(got == expected, name);
}

static er_ui_initial_setup_string_span_t test_str_span(const char* value) {
  er_ui_initial_setup_string_span_t span = {0};
  span.bytes = value;
  while (value[span.len] != '\0') span.len++;
  return span;
}

static er_ui_initial_setup_byte_span_t test_byte_span(const uint8_t* bytes, size_t len) {
  er_ui_initial_setup_byte_span_t span = {0};
  span.bytes = bytes;
  span.len = len;
  return span;
}

static void expect_initial_string_span(er_ui_initial_setup_string_span_t got, const char* expected, const char* name) {
  size_t len = 0u;
  bool same;
  while (expected[len] != '\0') len++;
  same = got.len == len;
  for (size_t i = 0u; same && i < len; ++i) same = got.bytes[i] == expected[i];
  expect_true(same, name);
}

static void expect_initial_byte_span(er_ui_initial_setup_byte_span_t got, const uint8_t* expected, size_t expected_len, const char* name) {
  bool same = got.len == expected_len;
  for (size_t i = 0u; same && i < expected_len; ++i) same = got.bytes[i] == expected[i];
  expect_true(same, name);
}

static bool test_bytes_contains_run(const uint8_t* bytes, size_t bytes_len, uint8_t value, size_t run_len) {
  size_t run = 0u;
  if (run_len == 0u || bytes_len < run_len) return false;
  for (size_t i = 0u; i < bytes_len; ++i) {
    run = bytes[i] == value ? run + 1u : 0u;
    if (run >= run_len) return true;
  }
  return false;
}

static void test_initial_setup_state_validates_and_emits_intent(void) {
  char password[ER_TEST_INITIAL_SETUP_PASSWORD_CAPACITY];
  char confirm[ER_TEST_INITIAL_SETUP_CONFIRM_CAPACITY];
  char status[ER_TEST_INITIAL_SETUP_STATUS_CAPACITY];
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

  expect_status(er_ui_initial_setup_mark_configured(&state, ER_TEST_INITIAL_SETUP_CONFIGURED_GENERATION), ER_UI_OK,
                "initial setup: mark configured succeeds");
  expect_true(state.configured, "initial setup: configured flag set");
  expect_true(!state.busy, "initial setup: configured clears busy");
  expect_size(state.password_len, 0u, "initial setup: configured clears password");
  expect_string(state.status, "password root configured", "initial setup: configured status");
}

static void test_initial_setup_surface_emits_fields_and_button(void) {
  char password[ER_TEST_INITIAL_SETUP_PASSWORD_CAPACITY];
  char confirm[ER_TEST_INITIAL_SETUP_CONFIRM_CAPACITY];
  char status[ER_TEST_INITIAL_SETUP_STATUS_CAPACITY];
  er_ui_initial_setup_state_t state = {0};
  er_ui_initial_setup_surface_t surface = {0};
  expect_status(er_ui_initial_setup_state_init(&state, password, sizeof(password), confirm, sizeof(confirm), status, sizeof(status)), ER_UI_OK,
                "initial setup surface: state init succeeds");
  expect_status(er_ui_initial_setup_set_password(&state, "correct horse battery"), ER_UI_OK, "initial setup surface: password stores");
  expect_status(er_ui_initial_setup_build_surface(&state, &surface), ER_UI_OK, "initial setup surface: builds");
  expect_size(surface.root.kind, ER_UI_NODE_COLUMN, "initial setup surface: root is column");
  expect_size(surface.root.child_count, ER_TEST_INITIAL_SETUP_ROOT_CHILDREN, "initial setup surface: root child count");
  er_ui_a11y_node_t a11y = {0};
  expect_status(er_ui_node_accessibility(&surface.nodes[ER_TEST_INITIAL_SETUP_PASSWORD_NODE_INDEX], &a11y), ER_UI_OK,
                "initial setup surface: password field a11y");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "initial setup surface: password field role");
  expect_true(a11y.has_id && a11y.id == ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID, "initial setup surface: password field id");
  expect_string(surface.nodes[ER_TEST_INITIAL_SETUP_PASSWORD_NODE_INDEX].value, "masked", "initial setup surface: password value is masked");
  expect_status(er_ui_node_accessibility(&surface.nodes[ER_TEST_INITIAL_SETUP_CREATE_NODE_INDEX], &a11y), ER_UI_OK,
                "initial setup surface: create button a11y");
  expect_true(a11y.has_id && a11y.id == ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID, "initial setup surface: create button id");
}

static void test_yubikey_grant_validates_pin_and_surface(void) {
  char pin[ER_TEST_YUBIKEY_PIN_CAPACITY];
  char status[ER_TEST_INITIAL_SETUP_STATUS_CAPACITY];
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
  expect_size(intent.pin_len, ER_TEST_YUBIKEY_PIN_MAX_LEN, "yubikey: intent pin length");

  expect_status(er_ui_yubikey_grant_mark_signed(&state, "grant signed"), ER_UI_OK, "yubikey: mark signed succeeds");
  expect_true(state.signed_grant, "yubikey: signed flag set");
  er_ui_initial_setup_surface_t surface = {0};
  expect_status(er_ui_yubikey_grant_build_surface(&state, &surface), ER_UI_OK, "yubikey: surface builds");
  expect_size(surface.root.kind, ER_UI_NODE_CARD, "yubikey: root is card");
  expect_size(surface.root.child_count, ER_TEST_YUBIKEY_ROOT_CHILDREN, "yubikey: root child count");
  const er_ui_node_t* signed_badge = surface.nodes + ER_TEST_YUBIKEY_SIGNED_BADGE_NODE_INDEX;
  expect_string(signed_badge->label, "signed", "yubikey: signed badge label");
}

static void test_authority_records_round_trip_without_allocation(void) {
  uint8_t out[ER_TEST_INITIAL_SETUP_RECORD_CAPACITY];
  size_t len = 0u;
  const uint8_t public_key[] = {1u, 2u, 3u, 4u};
  const uint8_t tpm_key[] = {9u, 8u, 7u};
  const uint8_t attestation_a[] = {10u, 11u};
  const uint8_t attestation_b[] = {12u, 13u, 14u};
  er_ui_fingerprint_presence_ref_t fingerprint = {test_str_span("goodix"), test_str_span("template-a")};
  er_ui_tpm_device_authority_ref_t tpm = {test_str_span("tpm:0x81000001"), test_byte_span(tpm_key, sizeof(tpm_key))};
  er_ui_initial_setup_byte_span_t chain[] = {test_byte_span(attestation_a, sizeof(attestation_a)), test_byte_span(attestation_b, sizeof(attestation_b))};
  er_ui_yubikey_user_authority_ref_t yubikey = {0};
  yubikey.slot = test_str_span("9c");
  yubikey.public_key = test_byte_span(public_key, sizeof(public_key));
  yubikey.attestation_chain = chain;
  yubikey.attestation_chain_count = test_array_count_size(chain, sizeof(chain), sizeof(chain[0]));
  yubikey.attestation_chain_capacity = test_array_count_size(chain, sizeof(chain), sizeof(chain[0]));

  expect_initial_record_status(er_ui_fingerprint_presence_ref_write(&fingerprint, out, sizeof(out), &len), ER_UI_RECORD_OK,
                               "initial setup records: fingerprint writes");
  expect_size(out[0], 'E', "initial setup records: fingerprint magic starts with E");
  er_ui_fingerprint_presence_ref_t parsed_fingerprint = {0};
  expect_initial_record_status(er_ui_fingerprint_presence_ref_read(out, len, &parsed_fingerprint), ER_UI_RECORD_OK,
                               "initial setup records: fingerprint reads");
  expect_initial_string_span(parsed_fingerprint.provider, "goodix", "initial setup records: fingerprint provider");
  expect_initial_string_span(parsed_fingerprint.template_ref, "template-a", "initial setup records: fingerprint template");

  expect_initial_record_status(er_ui_tpm_device_authority_ref_write(&tpm, out, sizeof(out), &len), ER_UI_RECORD_OK,
                               "initial setup records: tpm writes");
  er_ui_tpm_device_authority_ref_t parsed_tpm = {0};
  expect_initial_record_status(er_ui_tpm_device_authority_ref_read(out, len, &parsed_tpm), ER_UI_RECORD_OK,
                               "initial setup records: tpm reads");
  expect_initial_string_span(parsed_tpm.key_name, "tpm:0x81000001", "initial setup records: tpm key name");
  expect_initial_byte_span(parsed_tpm.public_key, tpm_key, sizeof(tpm_key), "initial setup records: tpm public key");

  expect_initial_record_status(er_ui_yubikey_user_authority_ref_write(&yubikey, out, sizeof(out), &len), ER_UI_RECORD_OK,
                               "initial setup records: yubikey writes");
  er_ui_initial_setup_byte_span_t parsed_chain[ER_TEST_PARSED_CHAIN_CAPACITY];
  er_ui_yubikey_user_authority_ref_t parsed_yubikey = {0};
  expect_initial_record_status(er_ui_yubikey_user_authority_ref_read(out, len, &parsed_yubikey, parsed_chain,
                                                                     test_array_count_size(parsed_chain, sizeof(parsed_chain), sizeof(parsed_chain[0]))),
                               ER_UI_RECORD_OK, "initial setup records: yubikey reads");
  expect_initial_string_span(parsed_yubikey.slot, "9c", "initial setup records: yubikey slot");
  expect_initial_byte_span(parsed_yubikey.public_key, public_key, sizeof(public_key), "initial setup records: yubikey public key");
  expect_size(parsed_yubikey.attestation_chain_count, ER_TEST_ATTESTATION_CHAIN_COUNT, "initial setup records: yubikey chain count");
  expect_initial_byte_span(parsed_yubikey.attestation_chain[1], attestation_b, sizeof(attestation_b), "initial setup records: yubikey second chain");
  expect_initial_record_status(er_ui_yubikey_user_authority_ref_read(out, len, &parsed_yubikey, parsed_chain, ER_TEST_SMALL_CHAIN_CAPACITY),
                               ER_UI_RECORD_ERR_NO_SPACE, "initial setup records: yubikey reports small chain array");
}

static void test_device_grant_record_and_signing_preimage(void) {
  uint8_t out[ER_TEST_DEVICE_GRANT_RECORD_CAPACITY];
  uint8_t preimage[ER_TEST_DEVICE_GRANT_RECORD_CAPACITY];
  size_t len = 0u;
  size_t preimage_len = 0u;
  const uint8_t user_key[] = {1u, 1u, 1u, 1u};
  const uint8_t device_key[] = {2u, 2u, 2u};
  const uint8_t signature[] = {3u, 3u, 3u, 3u, 3u};
  er_ui_initial_setup_string_span_t roles[] = {test_str_span("admission:device"), test_str_span("notary:device")};
  er_ui_initial_setup_string_span_t scopes[] = {test_str_span("tpm:sign"), test_str_span("fingerprint:presence")};
  er_ui_user_device_admission_grant_t grant = {0};
  grant.user_public_key = test_byte_span(user_key, sizeof(user_key));
  grant.user_key_label = test_str_span("9c");
  grant.device_public_key = test_byte_span(device_key, sizeof(device_key));
  grant.device_key_label = test_str_span("tpm:0x81000001");
  grant.fingerprint_template_ref = test_str_span("template-a");
  grant.allowed_roles = roles;
  grant.allowed_roles_count = test_array_count_size(roles, sizeof(roles), sizeof(roles[0]));
  grant.allowed_roles_capacity = test_array_count_size(roles, sizeof(roles), sizeof(roles[0]));
  grant.allowed_hardware_scopes = scopes;
  grant.allowed_hardware_scopes_count = test_array_count_size(scopes, sizeof(scopes), sizeof(scopes[0]));
  grant.allowed_hardware_scopes_capacity = test_array_count_size(scopes, sizeof(scopes), sizeof(scopes[0]));
  grant.presence_required = true;
  for (size_t i = 0u; i < ER_UI_INITIAL_SETUP_POLICY_HASH_LEN; ++i) grant.policy_hash[i] = (uint8_t)(i + 1u);
  grant.issued_at_secs = ER_TEST_GRANT_ISSUED_AT_SECS;
  grant.expires_at_secs = ER_TEST_GRANT_EXPIRES_AT_SECS;
  grant.user_signature = test_byte_span(signature, sizeof(signature));

  expect_initial_record_status(er_ui_user_device_admission_grant_write(&grant, out, sizeof(out), &len), ER_UI_RECORD_OK,
                               "initial setup records: device grant writes");
  er_ui_initial_setup_string_span_t parsed_roles[ER_TEST_PARSED_LIST_CAPACITY];
  er_ui_initial_setup_string_span_t parsed_scopes[ER_TEST_PARSED_LIST_CAPACITY];
  er_ui_user_device_admission_grant_t parsed = {0};
  expect_initial_record_status(er_ui_user_device_admission_grant_read(out, len, &parsed, parsed_roles,
                                                                      test_array_count_size(parsed_roles, sizeof(parsed_roles), sizeof(parsed_roles[0])),
                                                                      parsed_scopes,
                                                                      test_array_count_size(parsed_scopes, sizeof(parsed_scopes), sizeof(parsed_scopes[0]))),
                               ER_UI_RECORD_OK, "initial setup records: device grant reads");
  expect_initial_byte_span(parsed.user_public_key, user_key, sizeof(user_key), "initial setup records: grant user key");
  expect_initial_string_span(parsed.allowed_roles[1], "notary:device", "initial setup records: grant second role");
  expect_true(parsed.presence_required, "initial setup records: grant presence flag");
  expect_size((size_t)parsed.expires_at_secs, (size_t)ER_TEST_GRANT_EXPIRES_AT_SECS, "initial setup records: grant expiry");
  expect_initial_byte_span(parsed.user_signature, signature, sizeof(signature), "initial setup records: grant signature");
  expect_initial_record_status(er_ui_user_device_admission_grant_read(out, len, &parsed, parsed_roles, ER_TEST_SMALL_LIST_CAPACITY, parsed_scopes,
                                                                      ER_TEST_PARSED_LIST_CAPACITY),
                               ER_UI_RECORD_ERR_NO_SPACE,
                               "initial setup records: grant reports small role array");

  expect_initial_record_status(er_ui_user_device_admission_grant_signing_preimage_write(&grant, preimage, sizeof(preimage), &preimage_len),
                               ER_UI_RECORD_OK, "initial setup records: grant preimage writes");
  expect_true(preimage_len > 0u && preimage_len != len, "initial setup records: preimage is distinct from persisted record");
  expect_true(!test_bytes_contains_run(preimage, preimage_len, ER_TEST_SIGNATURE_BYTE, sizeof(signature)),
              "initial setup records: preimage does not include signature bytes");
}

void run_initial_setup_tests(void) {
  test_initial_setup_state_validates_and_emits_intent();
  test_initial_setup_surface_emits_fields_and_button();
  test_yubikey_grant_validates_pin_and_surface();
  test_authority_records_round_trip_without_allocation();
  test_device_grant_record_and_signing_preimage();
}

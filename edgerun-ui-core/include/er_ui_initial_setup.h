#ifndef ER_UI_INITIAL_SETUP_H
#define ER_UI_INITIAL_SETUP_H

#include "er_ui_node.h"
#include "er_ui_record_codec.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_INITIAL_SETUP_PASSWORD_MIN_LEN 8u
#define ER_UI_INITIAL_SETUP_PASSWORD_FIELD_ID 91001u
#define ER_UI_INITIAL_SETUP_CONFIRM_FIELD_ID 91002u
#define ER_UI_INITIAL_SETUP_CREATE_BUTTON_ID 91003u
#define ER_UI_YUBIKEY_GRANT_PIN_FIELD_ID 91101u
#define ER_UI_YUBIKEY_GRANT_SIGN_BUTTON_ID 91102u
#define ER_UI_YUBIKEY_GRANT_PIN_MIN_LEN 6u
#define ER_UI_YUBIKEY_GRANT_PIN_MAX_LEN 8u
#define ER_UI_INITIAL_SETUP_POLICY_HASH_LEN 32u

typedef enum {
  ER_UI_INITIAL_SETUP_INTENT_NONE = 0,
  ER_UI_INITIAL_SETUP_INTENT_CREATE_PASSWORD_ROOT
} er_ui_initial_setup_intent_kind_t;

typedef enum {
  ER_UI_YUBIKEY_GRANT_INTENT_NONE = 0,
  ER_UI_YUBIKEY_GRANT_INTENT_SIGN_GRANT
} er_ui_yubikey_grant_intent_kind_t;

typedef struct {
  char* password;
  size_t password_capacity;
  size_t password_len;
  char* confirm_password;
  size_t confirm_password_capacity;
  size_t confirm_password_len;
  char* status;
  size_t status_capacity;
  size_t status_len;
  bool busy;
  bool configured;
} er_ui_initial_setup_state_t;

typedef struct {
  er_ui_initial_setup_intent_kind_t kind;
  const char* password;
  size_t password_len;
} er_ui_initial_setup_intent_t;

typedef struct {
  char* pin;
  size_t pin_capacity;
  size_t pin_len;
  char* status;
  size_t status_capacity;
  size_t status_len;
  bool busy;
  bool signed_grant;
} er_ui_yubikey_grant_state_t;

typedef struct {
  er_ui_yubikey_grant_intent_kind_t kind;
  bool has_pin;
  const char* pin;
  size_t pin_len;
} er_ui_yubikey_grant_intent_t;

typedef struct {
  er_ui_node_t root;
  er_ui_node_t nodes[16u];
} er_ui_initial_setup_surface_t;

typedef struct {
  const uint8_t* bytes;
  size_t len;
} er_ui_initial_setup_byte_span_t;

typedef struct {
  const char* bytes;
  size_t len;
} er_ui_initial_setup_string_span_t;

typedef struct {
  er_ui_initial_setup_string_span_t provider;
  er_ui_initial_setup_string_span_t template_ref;
} er_ui_fingerprint_presence_ref_t;

typedef struct {
  er_ui_initial_setup_string_span_t key_name;
  er_ui_initial_setup_byte_span_t public_key;
} er_ui_tpm_device_authority_ref_t;

typedef struct {
  er_ui_initial_setup_string_span_t slot;
  er_ui_initial_setup_byte_span_t public_key;
  er_ui_initial_setup_byte_span_t* attestation_chain;
  size_t attestation_chain_count;
  size_t attestation_chain_capacity;
} er_ui_yubikey_user_authority_ref_t;

typedef struct {
  er_ui_initial_setup_byte_span_t user_public_key;
  er_ui_initial_setup_string_span_t user_key_label;
  er_ui_initial_setup_byte_span_t device_public_key;
  er_ui_initial_setup_string_span_t device_key_label;
  er_ui_initial_setup_string_span_t fingerprint_template_ref;
  er_ui_initial_setup_string_span_t* allowed_roles;
  size_t allowed_roles_count;
  size_t allowed_roles_capacity;
  er_ui_initial_setup_string_span_t* allowed_hardware_scopes;
  size_t allowed_hardware_scopes_count;
  size_t allowed_hardware_scopes_capacity;
  bool presence_required;
  uint8_t policy_hash[ER_UI_INITIAL_SETUP_POLICY_HASH_LEN];
  uint64_t issued_at_secs;
  uint64_t expires_at_secs;
  er_ui_initial_setup_byte_span_t user_signature;
} er_ui_user_device_admission_grant_t;

er_ui_status_t er_ui_initial_setup_state_init(
  er_ui_initial_setup_state_t* state,
  char* password,
  size_t password_capacity,
  char* confirm_password,
  size_t confirm_password_capacity,
  char* status,
  size_t status_capacity);
er_ui_status_t er_ui_initial_setup_set_password(er_ui_initial_setup_state_t* state, const char* value);
er_ui_status_t er_ui_initial_setup_set_confirm_password(er_ui_initial_setup_state_t* state, const char* value);
er_ui_initial_setup_intent_t er_ui_initial_setup_handle_action(er_ui_initial_setup_state_t* state, er_ui_action_t action);
er_ui_status_t er_ui_initial_setup_mark_configured(er_ui_initial_setup_state_t* state, size_t envelope_len);
er_ui_status_t er_ui_initial_setup_mark_error(er_ui_initial_setup_state_t* state, const char* message);
er_ui_status_t er_ui_initial_setup_build_surface(const er_ui_initial_setup_state_t* state, er_ui_initial_setup_surface_t* out_surface);

er_ui_status_t er_ui_yubikey_grant_state_init(er_ui_yubikey_grant_state_t* state, char* pin, size_t pin_capacity, char* status, size_t status_capacity);
er_ui_status_t er_ui_yubikey_grant_set_pin(er_ui_yubikey_grant_state_t* state, const char* value);
er_ui_yubikey_grant_intent_t er_ui_yubikey_grant_handle_action(er_ui_yubikey_grant_state_t* state, er_ui_action_t action);
er_ui_status_t er_ui_yubikey_grant_mark_signed(er_ui_yubikey_grant_state_t* state, const char* summary);
er_ui_status_t er_ui_yubikey_grant_mark_error(er_ui_yubikey_grant_state_t* state, const char* message);
er_ui_status_t er_ui_yubikey_grant_build_surface(const er_ui_yubikey_grant_state_t* state, er_ui_initial_setup_surface_t* out_surface);

er_ui_record_status_t er_ui_fingerprint_presence_ref_write(
  const er_ui_fingerprint_presence_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len);
er_ui_record_status_t er_ui_fingerprint_presence_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_fingerprint_presence_ref_t* out_value);
er_ui_record_status_t er_ui_tpm_device_authority_ref_write(
  const er_ui_tpm_device_authority_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len);
er_ui_record_status_t er_ui_tpm_device_authority_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_tpm_device_authority_ref_t* out_value);
er_ui_record_status_t er_ui_yubikey_user_authority_ref_write(
  const er_ui_yubikey_user_authority_ref_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len);
er_ui_record_status_t er_ui_yubikey_user_authority_ref_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_yubikey_user_authority_ref_t* out_value,
  er_ui_initial_setup_byte_span_t* attestation_chain,
  size_t attestation_chain_capacity);
er_ui_record_status_t er_ui_user_device_admission_grant_write(
  const er_ui_user_device_admission_grant_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len);
er_ui_record_status_t er_ui_user_device_admission_grant_read(
  const uint8_t* bytes,
  size_t byte_len,
  er_ui_user_device_admission_grant_t* out_value,
  er_ui_initial_setup_string_span_t* allowed_roles,
  size_t allowed_roles_capacity,
  er_ui_initial_setup_string_span_t* allowed_hardware_scopes,
  size_t allowed_hardware_scopes_capacity);
er_ui_record_status_t er_ui_user_device_admission_grant_signing_preimage_write(
  const er_ui_user_device_admission_grant_t* value,
  uint8_t* out,
  size_t capacity,
  size_t* out_len);

#ifdef __cplusplus
}
#endif

#endif

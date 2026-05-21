#include "er_identity.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_KEY_A_SEED = 17u,
  TEST_KEY_B_SEED = 71u,
  TEST_HASH_SEED = 99u,
  TEST_CLOCK_KEEPER_SEED = 31u,
  TEST_LABEL_SIZE = 8u,
  TEST_MATERIAL_SIZE = 9u
};

static int g_failed = 0;
static int g_total = 0;

static void test_fill(uint8_t* out, size_t len, uint8_t seed) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    out[i] = (uint8_t)(seed + i);
  }
}

static void test_zero(uint8_t* out, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static int test_bytes_equal(const uint8_t* left, const uint8_t* right,
                            size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (left[i] != right[i]) {
      return 0;
    }
  }
  return 1;
}

static void check_int(const char* label, int got, int want) {
  ++g_total;
  if (got != want) {
    ++g_failed;
    fprintf(stderr, "%s: got %d want %d\n", label, got, want);
  }
}

static void check_bytes(const char* label, const uint8_t* got,
                        const uint8_t* want, size_t len) {
  ++g_total;
  if (test_bytes_equal(got, want, len) == 0) {
    ++g_failed;
    fprintf(stderr, "%s: bytes differ\n", label);
  }
}

static er_clock_epoch_stamp_t test_epoch(uint64_t tick) {
  er_clock_epoch_stamp_t epoch;
  uint64_t i;

  for (i = 0u; i < ER_CLOCK_KEEPER_ID_SIZE; ++i) {
    epoch.keeper_id.bytes[i] = (uint8_t)(TEST_CLOCK_KEEPER_SEED + i);
  }
  epoch.tick = tick;
  epoch.slot = 1u;
  epoch.epoch = 1u;
  epoch.era = 1u;
  return epoch;
}

static void test_public_key_identity(void) {
  uint8_t key[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  er_identity_source_t source;
  er_identity_t identity;
  er_identity_id_t id;

  test_fill(key, sizeof(key), TEST_KEY_A_SEED);
  check_int("source prepare ed25519",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key, sizeof(key), &source),
            ER_IDENTITY_OK);
  check_int("source valid", er_identity_source_valid(&source), 1);
  check_int("identity prepare user",
            er_identity_prepare(ER_IDENTITY_KIND_USER, &source, test_epoch(1u), &identity),
            ER_IDENTITY_OK);
  check_int("identity valid", er_identity_valid(&identity), 1);
  check_int("identity id nonzero", er_identity_id_nonzero(&identity.id), 1);
  check_int("id from source",
            er_identity_id_from_source(&source, &id),
            ER_IDENTITY_OK);
  check_bytes("identity id derived", identity.id.bytes, id.bytes,
              ER_IDENTITY_ID_SIZE);
}

static void test_rejects_invalid_sources(void) {
  uint8_t key[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  er_identity_source_t source;

  test_fill(key, sizeof(key), TEST_KEY_A_SEED);
  check_int("reject wrong ed25519 len",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key, ER_IDENTITY_ED25519_PUBLIC_SIZE - 1u,
                                       &source),
            ER_IDENTITY_ERR_BADARG);
  test_zero(key, sizeof(key));
  check_int("reject zero key",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key, sizeof(key), &source),
            ER_IDENTITY_ERR_BADARG);
}

static void test_child_identity(void) {
  uint8_t key[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  static const uint8_t label[TEST_LABEL_SIZE] = {
      'a', 'p', 'p', ':', 'm', 'a', 'i', 'n'};
  static const uint8_t material[TEST_MATERIAL_SIZE] = {
      'o', 'b', 'j', 'e', 'c', 't', '-', 'v', '1'};
  er_identity_source_t source;
  er_identity_t parent;
  er_identity_t child;
  er_identity_t child_again;

  test_fill(key, sizeof(key), TEST_KEY_A_SEED);
  check_int("child parent source",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key, sizeof(key), &source),
            ER_IDENTITY_OK);
  check_int("child parent prepare",
            er_identity_prepare(ER_IDENTITY_KIND_USER, &source, test_epoch(1u), &parent),
            ER_IDENTITY_OK);
  check_int("derive app child",
            er_identity_derive_child(&parent, ER_IDENTITY_KIND_APP,
                                     test_epoch(2u),
                                     label, sizeof(label),
                                     material, sizeof(material),
                                     &child),
            ER_IDENTITY_OK);
  check_int("derive app child again",
            er_identity_derive_child(&parent, ER_IDENTITY_KIND_APP,
                                     test_epoch(2u),
                                     label, sizeof(label),
                                     material, sizeof(material),
                                     &child_again),
            ER_IDENTITY_OK);
  check_int("child valid", er_identity_valid(&child), 1);
  check_int("child kind", (int)child.identity_kind,
            (int)ER_IDENTITY_KIND_APP);
  check_int("child source kind", (int)child.source.source_kind,
            (int)ER_IDENTITY_SOURCE_DERIVED);
  check_int("child deterministic", er_identity_equal(&child, &child_again), 1);
}

static void test_delegated_identity(void) {
  uint8_t key_a[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  uint8_t key_b[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  uint8_t scope_hash[ER_IDENTITY_HASH_SIZE];
  er_identity_source_t source_a;
  er_identity_source_t source_b;
  er_identity_source_t delegation_source;
  er_identity_t app;
  er_identity_t device;
  er_identity_t delegated;

  test_fill(key_a, sizeof(key_a), TEST_KEY_A_SEED);
  test_fill(key_b, sizeof(key_b), TEST_KEY_B_SEED);
  test_fill(scope_hash, sizeof(scope_hash), TEST_HASH_SEED);
  check_int("delegation app source",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key_a, sizeof(key_a), &source_a),
            ER_IDENTITY_OK);
  check_int("delegation device source",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       key_b, sizeof(key_b), &source_b),
            ER_IDENTITY_OK);
  check_int("delegation app identity",
            er_identity_prepare(ER_IDENTITY_KIND_APP, &source_a, test_epoch(1u), &app),
            ER_IDENTITY_OK);
  check_int("delegation device identity",
            er_identity_prepare(ER_IDENTITY_KIND_DEVICE, &source_b, test_epoch(1u), &device),
            ER_IDENTITY_OK);
  check_int("delegation source",
            er_identity_source_prepare_delegation(&app.id, &device.id,
                                                  scope_hash,
                                                  &delegation_source),
            ER_IDENTITY_OK);
  check_int("delegated identity",
            er_identity_prepare(ER_IDENTITY_KIND_DELEGATED,
                                &delegation_source,
                                test_epoch(2u),
                                &delegated),
            ER_IDENTITY_OK);
  check_int("delegated valid", er_identity_valid(&delegated), 1);
  check_int("delegated not app", er_identity_id_equal(&delegated.id, &app.id), 0);
  check_int("delegated not device",
            er_identity_id_equal(&delegated.id, &device.id), 0);
}

static void test_instantiate_device_sources(void) {
  uint8_t tpm_key[ER_IDENTITY_P256_PUBLIC_SIZE];
  uint8_t keystone_key[ER_IDENTITY_P256_PUBLIC_SIZE];
  er_identity_instantiation_t instantiation;
  er_identity_t tpm_device;
  er_identity_t keystone_device;

  test_fill(tpm_key, sizeof(tpm_key), TEST_KEY_A_SEED);
  test_fill(keystone_key, sizeof(keystone_key), TEST_KEY_B_SEED);
  instantiation.identity_kind = ER_IDENTITY_KIND_DEVICE;
  instantiation.source_kind = ER_IDENTITY_SOURCE_TPM_P256_PUBLIC;
  instantiation.material = tpm_key;
  instantiation.material_len = sizeof(tpm_key);
  instantiation.epoch = test_epoch(1u);
  check_int("instantiate tpm device",
            er_identity_instantiate(&instantiation, &tpm_device),
            ER_IDENTITY_OK);
  check_int("tpm device valid", er_identity_valid(&tpm_device), 1);
  check_int("tpm device source",
            (int)tpm_device.source.source_kind,
            (int)ER_IDENTITY_SOURCE_TPM_P256_PUBLIC);

  instantiation.source_kind = ER_IDENTITY_SOURCE_ANDROID_KEYSTONE_P256_PUBLIC;
  instantiation.material = keystone_key;
  instantiation.material_len = sizeof(keystone_key);
  check_int("instantiate keystone device",
            er_identity_instantiate(&instantiation, &keystone_device),
            ER_IDENTITY_OK);
  check_int("keystone device valid", er_identity_valid(&keystone_device), 1);
  check_int("keystone source",
            (int)keystone_device.source.source_kind,
            (int)ER_IDENTITY_SOURCE_ANDROID_KEYSTONE_P256_PUBLIC);
  check_int("device sources differ",
            er_identity_id_equal(&tpm_device.id, &keystone_device.id), 0);
}

static void test_instantiate_app_delegation(void) {
  uint8_t parent_key[ER_IDENTITY_ED25519_PUBLIC_SIZE];
  uint8_t app_hash[ER_IDENTITY_HASH_SIZE];
  uint8_t scope_hash[ER_IDENTITY_HASH_SIZE];
  er_identity_source_t parent_source;
  er_identity_t parent;
  er_identity_t app;
  er_identity_t app_again;
  er_identity_t sign_only_app;
  er_identity_app_instantiation_t instantiation;

  test_fill(parent_key, sizeof(parent_key), TEST_KEY_A_SEED);
  test_fill(app_hash, sizeof(app_hash), TEST_HASH_SEED);
  test_fill(scope_hash, sizeof(scope_hash), TEST_KEY_B_SEED);
  check_int("app parent source",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_ED25519_PUBLIC,
                                       parent_key, sizeof(parent_key),
                                       &parent_source),
            ER_IDENTITY_OK);
  check_int("app parent identity",
            er_identity_prepare(ER_IDENTITY_KIND_DEVICE, &parent_source,
                                test_epoch(1u), &parent),
            ER_IDENTITY_OK);

  instantiation.parent = &parent;
  instantiation.app_material = app_hash;
  instantiation.app_material_len = sizeof(app_hash);
  instantiation.scope_hash = scope_hash;
  instantiation.epoch = test_epoch(2u);
  instantiation.required_parent_operations =
      ER_IDENTITY_INSTANTIATION_OPERATION_VERIFY_AND_SIGN;
  check_int("instantiate app",
            er_identity_instantiate_app(&instantiation, &app),
            ER_IDENTITY_OK);
  check_int("app valid", er_identity_valid(&app), 1);
  check_int("app delegated kind",
            (int)app.identity_kind,
            (int)ER_IDENTITY_KIND_DELEGATED);
  check_int("app source delegation",
            (int)app.source.source_kind,
            (int)ER_IDENTITY_SOURCE_DELEGATION);
  check_int("instantiate app again",
            er_identity_instantiate_app(&instantiation, &app_again),
            ER_IDENTITY_OK);
  check_int("app deterministic", er_identity_equal(&app, &app_again), 1);

  instantiation.required_parent_operations =
      ER_IDENTITY_INSTANTIATION_OPERATION_SIGN;
  check_int("instantiate sign-only app",
            er_identity_instantiate_app(&instantiation, &sign_only_app),
            ER_IDENTITY_OK);
  check_int("operation changes app identity",
            er_identity_id_equal(&app.id, &sign_only_app.id), 0);
  instantiation.required_parent_operations = 0u;
  check_int("reject missing parent operations",
            er_identity_instantiate_app(&instantiation, &sign_only_app),
            ER_IDENTITY_ERR_BADARG);
}

int main(void) {
  test_public_key_identity();
  test_rejects_invalid_sources();
  test_child_identity();
  test_delegated_identity();
  test_instantiate_device_sources();
  test_instantiate_app_delegation();

  if (g_failed != 0) {
    fprintf(stderr, "identity tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("identity tests passed: %d\n", g_total);
  return 0;
}

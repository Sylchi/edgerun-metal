#include "er_identity.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_KEY_A_SEED = 17u,
  TEST_KEY_B_SEED = 71u,
  TEST_HASH_SEED = 99u,
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

int main(void) {
  test_public_key_identity();
  test_rejects_invalid_sources();
  test_child_identity();
  test_delegated_identity();

  if (g_failed != 0) {
    fprintf(stderr, "identity tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("identity tests passed: %d\n", g_total);
  return 0;
}

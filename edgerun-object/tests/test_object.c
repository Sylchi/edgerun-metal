#include "er_object.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_BUFFER_SIZE = 4096u,
  TEST_LEAF_BYTES = 6u,
  TEST_TREE_CHILDREN = 2u,
  TEST_LEAF_OWNER_COUNT = 2u,
  TEST_LEAF_ENVELOPE_COUNT = 2u,
  TEST_SINGLE_OWNER_COUNT = 1u,
  TEST_SINGLE_ENVELOPE_COUNT = 1u,
  TEST_FIRST_OWNER_INDEX = 0u,
  TEST_SECOND_OWNER_INDEX = 1u,
  TEST_MISSING_OWNER_INDEX = 2u,
  TEST_USER_OWNER_SEED = 10u,
  TEST_APP_OWNER_SEED = 20u,
  TEST_TREE_OWNER_SEED = 44u,
  TEST_MISMATCH_OWNER_SEED = 99u,
  TEST_ENVELOPE_KEY_SEED = 33u,
  TEST_ENVELOPE_METADATA_SEED = 77u,
  TEST_CHILD0_ID_SEED = 1u,
  TEST_CHILD1_ID_SEED = 2u,
  TEST_LEAF_EPOCH_TICK = 1u,
  TEST_TREE_EPOCH_TICK = 2u,
  TEST_MISMATCH_EPOCH_TICK = 3u,
  TEST_INVALID_EPOCH_TICK = 4u,
  TEST_CLOCK_KEEPER_SEED = 31u,
  TEST_CHILD0_LEN = 11u,
  TEST_CHILD1_LEN = 7u,
  TEST_TREE_TOTAL_LEN = TEST_CHILD0_LEN + TEST_CHILD1_LEN
};

static int g_failed = 0;
static int g_total = 0;

static void test_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static void test_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static int test_equal(const uint8_t* a, const uint8_t* b, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (a[i] != b[i]) {
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

static void check_u64(const char* label, uint64_t got, uint64_t want) {
  ++g_total;
  if (got != want) {
    ++g_failed;
    fprintf(stderr, "%s: got %llu want %llu\n", label,
            (unsigned long long)got, (unsigned long long)want);
  }
}

static void check_bytes(const char* label, const uint8_t* got,
                        const uint8_t* want, size_t len) {
  ++g_total;
  if (test_equal(got, want, len) == 0) {
    ++g_failed;
    fprintf(stderr, "%s: bytes differ\n", label);
  }
}

static er_object_requirements_t test_requirements(uint32_t confidentiality) {
  er_object_requirements_t requirements;

  requirements.durability = ER_OBJECT_DURABILITY_DURABLE;
  requirements.confidentiality = confidentiality;
  requirements.portability = ER_OBJECT_PORTABILITY_USER_PORTABLE;
  requirements.integrity = ER_OBJECT_INTEGRITY_HASH_ONLY;
  requirements.lifetime = ER_OBJECT_LIFETIME_RETAINED;
  requirements.visibility = ER_OBJECT_VISIBILITY_APP_NAMESPACE;
  requirements.access_cost = ER_OBJECT_ACCESS_EXPLICIT_IO;
  return requirements;
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

static er_object_owner_t test_owner(uint32_t kind, uint8_t seed) {
  er_object_owner_t owner;
  size_t i;

  owner.owner_kind = kind;
  for (i = 0u; i < ER_OBJECT_ID_SIZE; ++i) {
    owner.node_id[i] = (uint8_t)(seed + i);
  }
  return owner;
}

static er_object_envelope_t test_envelope(uint32_t kind, uint16_t owner_index) {
  er_object_envelope_t envelope;
  size_t i;

  envelope.envelope_kind = kind;
  envelope.owner_index = owner_index;
  envelope.algorithm = ER_OBJECT_ALGORITHM_XCHACHA20_POLY1305;
  envelope.flags = 0u;
  for (i = 0u; i < ER_OBJECT_ID_SIZE; ++i) {
    envelope.key_id[i] = (uint8_t)(TEST_ENVELOPE_KEY_SEED + i);
    envelope.metadata_hash[i] = (uint8_t)(TEST_ENVELOPE_METADATA_SEED + i);
  }
  return envelope;
}

static void test_leaf_node(void) {
  uint8_t object[TEST_BUFFER_SIZE];
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  uint8_t verify_id[ER_OBJECT_ID_SIZE];
  er_object_requirements_t requirements =
      test_requirements(ER_OBJECT_CONFIDENTIALITY_USER_APP_PRIVATE);
  er_object_owner_t owners[TEST_LEAF_OWNER_COUNT];
  er_object_owner_t read_owner;
  er_object_envelope_t envelopes[TEST_LEAF_ENVELOPE_COUNT];
  er_object_envelope_t read_envelope;
  er_object_info_t info;
  size_t object_len = 0u;
  size_t canonical_len = 0u;
  static const uint8_t payload[TEST_LEAF_BYTES] = {1u, 2u, 3u, 4u, 5u, 6u};

  owners[TEST_FIRST_OWNER_INDEX] = test_owner(ER_OBJECT_OWNER_USER, TEST_USER_OWNER_SEED);
  owners[TEST_SECOND_OWNER_INDEX] = test_owner(ER_OBJECT_OWNER_APP, TEST_APP_OWNER_SEED);
  envelopes[TEST_FIRST_OWNER_INDEX] = test_envelope(ER_OBJECT_ENVELOPE_USER,
                                                    TEST_FIRST_OWNER_INDEX);
  envelopes[TEST_SECOND_OWNER_INDEX] = test_envelope(ER_OBJECT_ENVELOPE_APP,
                                                     TEST_SECOND_OWNER_INDEX);
  check_int("leaf size",
            er_object_canonical_size(ER_OBJECT_KIND_BYTES, sizeof(payload),
                                     TEST_LEAF_OWNER_COUNT,
                                     TEST_LEAF_ENVELOPE_COUNT,
                                     0u, &canonical_len),
            ER_OBJECT_OK);
  check_int("leaf build",
            er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                                 test_epoch(TEST_LEAF_EPOCH_TICK),
                                 owners, TEST_LEAF_OWNER_COUNT,
                                 envelopes, TEST_LEAF_ENVELOPE_COUNT, 0, 0u,
                                 payload, sizeof(payload),
                                 object, sizeof(object), &object_len, object_id),
            ER_OBJECT_OK);
  check_u64("leaf len", object_len, canonical_len);
  check_int("leaf verify", er_object_verify(object, object_len, &info), ER_OBJECT_OK);
  check_int("leaf kind", (int)info.node_kind, (int)ER_OBJECT_KIND_BYTES);
  check_u64("leaf logical len", info.logical_len, sizeof(payload));
  check_u64("leaf body len", info.body_len, sizeof(payload));
  check_u64("leaf epoch tick", info.epoch.tick, TEST_LEAF_EPOCH_TICK);
  check_bytes("leaf body", info.body, payload, sizeof(payload));
  check_int("leaf id", er_object_id(object, object_len, verify_id), ER_OBJECT_OK);
  check_bytes("leaf id matches", verify_id, object_id, ER_OBJECT_ID_SIZE);
  check_int("leaf owner accessor",
            er_object_owner_at(object, object_len, TEST_SECOND_OWNER_INDEX, &read_owner),
            ER_OBJECT_OK);
  check_int("leaf owner kind", (int)read_owner.owner_kind,
            (int)ER_OBJECT_OWNER_APP);
  check_bytes("leaf owner id", read_owner.node_id, owners[TEST_SECOND_OWNER_INDEX].node_id,
              ER_OBJECT_ID_SIZE);
  check_int("leaf envelope accessor",
            er_object_envelope_at(object, object_len, TEST_FIRST_OWNER_INDEX, &read_envelope),
            ER_OBJECT_OK);
  check_int("leaf envelope kind", (int)read_envelope.envelope_kind,
            (int)ER_OBJECT_ENVELOPE_USER);
  check_int("leaf rejects missing owner",
            er_object_owner_at(object, object_len, TEST_MISSING_OWNER_INDEX, &read_owner),
            ER_OBJECT_ERR_BADARG);

  object[object_len - 1u] ^= 1u;
  check_int("tampered verify", er_object_verify(object, object_len, &info), ER_OBJECT_OK);
  check_int("tampered id", er_object_id(object, object_len, verify_id), ER_OBJECT_OK);
  check_int("tampered id changed", test_equal(verify_id, object_id, ER_OBJECT_ID_SIZE), 0);
}

static void test_tree_node(void) {
  uint8_t object[TEST_BUFFER_SIZE];
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  uint8_t req_hash[ER_OBJECT_ID_SIZE];
  er_object_requirements_t requirements =
      test_requirements(ER_OBJECT_CONFIDENTIALITY_PUBLIC);
  er_object_owner_t owner = test_owner(ER_OBJECT_OWNER_APP, TEST_TREE_OWNER_SEED);
  er_object_child_ref_t children[TEST_TREE_CHILDREN];
  er_object_child_ref_t read_child;
  er_object_info_t info;
  size_t object_len = 0u;

  test_zero(children, sizeof(children));
  check_int("requirements hash",
            er_object_requirements_hash(&requirements, req_hash),
            ER_OBJECT_OK);
  children[0].logical_offset = 0u;
  children[0].logical_len = TEST_CHILD0_LEN;
  children[0].node_kind = ER_OBJECT_KIND_BYTES;
  test_zero(children[0].object_id, sizeof(children[0].object_id));
  children[0].object_id[0] = TEST_CHILD0_ID_SEED;
  test_copy(children[0].requirements_hash, req_hash, ER_OBJECT_ID_SIZE);
  children[1].logical_offset = TEST_CHILD0_LEN;
  children[1].logical_len = TEST_CHILD1_LEN;
  children[1].node_kind = ER_OBJECT_KIND_BYTES;
  children[1].object_id[0] = TEST_CHILD1_ID_SEED;
  test_copy(children[1].requirements_hash, req_hash, ER_OBJECT_ID_SIZE);
  children[1].requirements_hash[1] ^= 1u;
  check_int("tree build",
            er_object_build_node(ER_OBJECT_KIND_TREE, 0u, &requirements,
                                 test_epoch(TEST_TREE_EPOCH_TICK),
                                 &owner, TEST_SINGLE_OWNER_COUNT, 0, 0u, children,
                                 TEST_TREE_CHILDREN, 0, 0u,
                                 object, sizeof(object), &object_len, object_id),
            ER_OBJECT_OK);
  check_int("tree verify", er_object_verify(object, object_len, &info), ER_OBJECT_OK);
  check_int("tree kind", (int)info.node_kind, (int)ER_OBJECT_KIND_TREE);
  check_u64("tree logical len", info.logical_len, TEST_TREE_TOTAL_LEN);
  check_u64("tree body len", info.body_len, 0u);
  check_int("tree child accessor",
            er_object_child_at(object, object_len, TEST_SECOND_OWNER_INDEX, &read_child),
            ER_OBJECT_OK);
  check_u64("tree child offset", read_child.logical_offset, TEST_CHILD0_LEN);
  check_u64("tree child len", read_child.logical_len, TEST_CHILD1_LEN);
  check_bytes("tree child req hash", read_child.requirements_hash,
              children[1].requirements_hash, ER_OBJECT_ID_SIZE);

  children[1].logical_offset = TEST_CHILD0_LEN + TEST_CHILD0_ID_SEED;
  check_int("tree rejects gap",
            er_object_build_node(ER_OBJECT_KIND_TREE, 0u, &requirements,
                                 test_epoch(TEST_TREE_EPOCH_TICK),
                                 &owner, TEST_SINGLE_OWNER_COUNT, 0, 0u, children,
                                 TEST_TREE_CHILDREN, 0, 0u,
                                 object, sizeof(object), &object_len, object_id),
            ER_OBJECT_ERR_BADARG);

  children[1].logical_offset = TEST_CHILD0_LEN;
  test_zero(children[1].requirements_hash, ER_OBJECT_ID_SIZE);
  check_int("tree rejects empty child requirements",
            er_object_build_node(ER_OBJECT_KIND_TREE, 0u, &requirements,
                                 test_epoch(TEST_TREE_EPOCH_TICK),
                                 &owner, TEST_SINGLE_OWNER_COUNT, 0, 0u, children,
                                 TEST_TREE_CHILDREN, 0, 0u,
                                 object, sizeof(object), &object_len, object_id),
            ER_OBJECT_ERR_BADARG);
}

static void test_rejects_mismatched_envelope(void) {
  uint8_t object[TEST_BUFFER_SIZE];
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  er_object_requirements_t requirements =
      test_requirements(ER_OBJECT_CONFIDENTIALITY_APP_PRIVATE);
  er_object_owner_t owner = test_owner(ER_OBJECT_OWNER_APP, TEST_MISMATCH_OWNER_SEED);
  er_object_envelope_t envelope = test_envelope(ER_OBJECT_ENVELOPE_USER,
                                                TEST_FIRST_OWNER_INDEX);
  size_t object_len = 0u;
  static const uint8_t payload[] = {4u};

  check_int("mismatched envelope owner",
            er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                                 test_epoch(TEST_MISMATCH_EPOCH_TICK),
                                 &owner, TEST_SINGLE_OWNER_COUNT,
                                 &envelope, TEST_SINGLE_ENVELOPE_COUNT, 0, 0u,
                                 payload, sizeof(payload), object,
                                 sizeof(object), &object_len, object_id),
            ER_OBJECT_ERR_BADARG);
}

static void test_rejects_invalid_requirements(void) {
  uint8_t object[TEST_BUFFER_SIZE];
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  er_object_requirements_t requirements =
      test_requirements(ER_OBJECT_CONFIDENTIALITY_PUBLIC);
  size_t object_len = 0u;
  static const uint8_t payload[] = {9u};

  requirements.confidentiality = 0u;
  check_int("invalid requirements valid",
            er_object_requirements_valid(&requirements), 0);
  check_int("invalid requirements build",
            er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                                 test_epoch(TEST_INVALID_EPOCH_TICK),
                                 0, 0u, 0, 0u, 0, 0u,
                                 payload, sizeof(payload), object,
                                 sizeof(object), &object_len, object_id),
            ER_OBJECT_ERR_BADARG);
}

static void test_signature_object(void) {
  uint8_t subject[TEST_BUFFER_SIZE];
  uint8_t challenge[TEST_BUFFER_SIZE];
  uint8_t signature_object[TEST_BUFFER_SIZE];
  uint8_t subject_id[ER_OBJECT_ID_SIZE];
  uint8_t challenge_id[ER_OBJECT_ID_SIZE];
  uint8_t signature_id[ER_OBJECT_ID_SIZE];
  uint8_t signer_id[ER_OBJECT_ID_SIZE];
  uint8_t signature[64u];
  er_object_requirements_t requirements =
      test_requirements(ER_OBJECT_CONFIDENTIALITY_INTEGRITY_ONLY);
  er_object_signature_info_t signature_info;
  size_t subject_len = 0u;
  size_t challenge_len = 0u;
  size_t signature_len = 0u;
  size_t i;
  static const uint8_t subject_body[] = {1u, 4u, 9u};
  static const uint8_t challenge_body[] = {2u, 5u, 10u};

  for (i = 0u; i < ER_OBJECT_ID_SIZE; ++i) {
    signer_id[i] = (uint8_t)(0x55u + i);
  }
  for (i = 0u; i < sizeof(signature); ++i) {
    signature[i] = (uint8_t)(0x80u + i);
  }
  check_int("signature subject build",
            er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                                 test_epoch(TEST_LEAF_EPOCH_TICK),
                                 0, 0u, 0, 0u, 0, 0u,
                                 subject_body, sizeof(subject_body),
                                 subject, sizeof(subject), &subject_len,
                                 subject_id),
            ER_OBJECT_OK);
  check_int("signature challenge build",
            er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                                 test_epoch(TEST_TREE_EPOCH_TICK),
                                 0, 0u, 0, 0u, 0, 0u,
                                 challenge_body, sizeof(challenge_body),
                                 challenge, sizeof(challenge), &challenge_len,
                                 challenge_id),
            ER_OBJECT_OK);
  check_int("signature build",
            er_object_sign(subject, subject_len, challenge, challenge_len,
                           signer_id, ER_OBJECT_ALGORITHM_ED25519,
                           signature, sizeof(signature),
                           test_epoch(TEST_MISMATCH_EPOCH_TICK),
                           signature_object, sizeof(signature_object),
                           &signature_len, signature_id),
            ER_OBJECT_OK);
  check_int("signature verify",
            er_object_signature_verify(signature_object, signature_len,
                                       &signature_info),
            ER_OBJECT_OK);
  check_bytes("signature signer", signature_info.signer_id, signer_id,
              ER_OBJECT_ID_SIZE);
  check_bytes("signature subject id", signature_info.subject_id, subject_id,
              ER_OBJECT_ID_SIZE);
  check_bytes("signature challenge id", signature_info.challenge_id,
              challenge_id, ER_OBJECT_ID_SIZE);
  check_int("signature algorithm", (int)signature_info.algorithm,
            (int)ER_OBJECT_ALGORITHM_ED25519);
  check_int("signature length", (int)signature_info.signature_len,
            (int)sizeof(signature));
  check_bytes("signature bytes", signature_info.signature, signature,
              sizeof(signature));

  signature_object[signature_len - 1u] ^= 1u;
  check_int("signature still canonical after byte change",
            er_object_verify(signature_object, signature_len, 0),
            ER_OBJECT_OK);
  check_int("signature verifier accepts changed signature bytes",
            er_object_signature_verify(signature_object, signature_len, 0),
            ER_OBJECT_OK);
  test_zero(&signature_object[signature_len - sizeof(signature)],
            sizeof(signature));
  check_int("signature verifier rejects zero signature",
            er_object_signature_verify(signature_object, signature_len, 0),
            ER_OBJECT_ERR_CORRUPT);
}

int main(void) {
  test_leaf_node();
  test_tree_node();
  test_rejects_mismatched_envelope();
  test_rejects_invalid_requirements();
  test_signature_object();

  if (g_failed != 0) {
    fprintf(stderr, "object tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("object tests passed: %d\n", g_total);
  return 0;
}

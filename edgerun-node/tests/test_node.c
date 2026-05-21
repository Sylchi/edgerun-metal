#include "er_node.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_IO_CAP = 32768u,
  TEST_ARENA_SIZE = ER_STORE_ARENA_MIN_SIZE,
  TEST_NODE_ARENA_SIZE = 4096u,
  TEST_CHILD_MEMORY_SIZE = 1024u,
  TEST_PARENT_STORAGE_LIMIT = 8192u,
  TEST_CHILD_STORAGE_LIMIT = 2048u,
  TEST_OBJECT_CAP = 4096u,
  TEST_TPM_SIGNATURE_SIZE = 64u,
  TEST_TPM_SIGNATURE_HALF = 32u
};

typedef struct {
  uint8_t bytes[TEST_IO_CAP];
  uint64_t size;
} TestIo;

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

static int test_equal(const void* left, const void* right, size_t len) {
  size_t i;
  const uint8_t* a = (const uint8_t*)left;
  const uint8_t* b = (const uint8_t*)right;

  for (i = 0u; i < len; ++i) {
    if (a[i] != b[i]) {
      return 0;
    }
  }
  return 1;
}

static int test_read_at(void* ctx, uint64_t off, void* buf, size_t len) {
  TestIo* io = (TestIo*)ctx;

  if (off > io->size || len > (size_t)(io->size - off)) {
    return -1;
  }
  test_copy(buf, &io->bytes[off], len);
  return 0;
}

static int test_write_at(void* ctx, uint64_t off, const void* buf, size_t len) {
  TestIo* io = (TestIo*)ctx;
  uint64_t end = off + len;

  if (end < off || end > TEST_IO_CAP) {
    return -1;
  }
  if (off > io->size) {
    test_zero(&io->bytes[io->size], (size_t)(off - io->size));
  }
  test_copy(&io->bytes[off], buf, len);
  if (end > io->size) {
    io->size = end;
  }
  return 0;
}

static int test_sync(void* ctx) {
  (void)ctx;
  return 0;
}

static int test_size(void* ctx, uint64_t* out_size) {
  TestIo* io = (TestIo*)ctx;

  *out_size = io->size;
  return 0;
}

static int test_truncate(void* ctx, uint64_t size) {
  TestIo* io = (TestIo*)ctx;

  if (size > TEST_IO_CAP) {
    return -1;
  }
  io->size = size;
  return 0;
}

static er_io_t test_make_io(TestIo* io) {
  er_io_t out;

  out.ctx = io;
  out.read_at = test_read_at;
  out.write_at = test_write_at;
  out.sync = test_sync;
  out.size = test_size;
  out.truncate = test_truncate;
  return out;
}

static void check_int(const char* name, int actual, int expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %d expected %d\n", name, actual, expected);
    ++g_failed;
  }
}

static void check_bytes(const char* name, const uint8_t* actual,
                        const uint8_t* expected, size_t len) {
  size_t i;

  ++g_total;
  for (i = 0u; i < len; ++i) {
    if (actual[i] != expected[i]) {
      fprintf(stderr, "FAIL %s: byte mismatch\n", name);
      ++g_failed;
      return;
    }
  }
}

static void check_nonzero(const char* name, const uint8_t* bytes, size_t len) {
  size_t i;
  int ok = 0;

  ++g_total;
  for (i = 0u; i < len; ++i) {
    if (bytes[i] != 0u) {
      ok = 1;
    }
  }
  if (ok == 0) {
    fprintf(stderr, "FAIL %s: all zero\n", name);
    ++g_failed;
  }
}

static void test_prepare_identity(er_identity_t* out_identity,
                                  er_clock_t* out_clock) {
  er_identity_source_t source;
  er_clock_keeper_id_t keeper_id;
  er_clock_limits_t limits;
  uint8_t material[ER_IDENTITY_HASH_SIZE];
  size_t i;

  for (i = 0u; i < ER_CLOCK_KEEPER_ID_SIZE; ++i) {
    keeper_id.bytes[i] = (uint8_t)(0x11u + i);
  }
  for (i = 0u; i < sizeof(material); ++i) {
    material[i] = (uint8_t)(0x44u + i);
  }
  limits = er_clock_default_limits();
  check_int("clock init", er_clock_init(&keeper_id, &limits, out_clock),
            ER_CLOCK_OK);
  check_int("identity source",
            er_identity_source_prepare(ER_IDENTITY_SOURCE_HASH, material,
                                       sizeof(material), &source),
            ER_IDENTITY_OK);
  check_int("identity prepare",
            er_identity_prepare(ER_IDENTITY_KIND_DEVICE, &source,
                                out_clock->now, out_identity),
            ER_IDENTITY_OK);
}

static void test_prepare_tpm_identity(er_identity_t* out_identity,
                                      er_clock_t* out_clock) {
  er_identity_instantiation_t instantiation;
  er_clock_keeper_id_t keeper_id;
  er_clock_limits_t limits;
  uint8_t public_key[ER_IDENTITY_P256_PUBLIC_SIZE];
  size_t i;

  for (i = 0u; i < ER_CLOCK_KEEPER_ID_SIZE; ++i) {
    keeper_id.bytes[i] = (uint8_t)(0x21u + i);
  }
  for (i = 0u; i < sizeof(public_key); ++i) {
    public_key[i] = (uint8_t)(0x61u + i);
  }
  limits = er_clock_default_limits();
  check_int("tpm clock init", er_clock_init(&keeper_id, &limits, out_clock),
            ER_CLOCK_OK);
  instantiation.identity_kind = ER_IDENTITY_KIND_DEVICE;
  instantiation.source_kind = ER_IDENTITY_SOURCE_TPM_P256_PUBLIC;
  instantiation.material = public_key;
  instantiation.material_len = sizeof(public_key);
  instantiation.epoch = out_clock->now;
  check_int("tpm identity instantiate",
            er_identity_instantiate(&instantiation, out_identity),
            ER_IDENTITY_OK);
}

static int test_tpm_authority_sign(void* context,
                                   const er_identity_t* identity,
                                   const void* subject_canonical,
                                   size_t subject_len,
                                   const void* challenge_canonical,
                                   size_t challenge_len,
                                   uint16_t algorithm,
                                   uint8_t out_signature[ER_NODE_SIGNATURE_MAX_SIZE],
                                   size_t* out_signature_len) {
  uint8_t subject_id[ER_OBJECT_ID_SIZE];
  uint8_t challenge_id[ER_OBJECT_ID_SIZE];
  size_t i;

  (void)context;
  if (identity == (const er_identity_t*)0 ||
      identity->source.source_kind != ER_IDENTITY_SOURCE_TPM_P256_PUBLIC ||
      algorithm != ER_OBJECT_ALGORITHM_ECDSA_P256_SHA256 ||
      out_signature == (uint8_t*)0 ||
      out_signature_len == (size_t*)0 ||
      er_object_id(subject_canonical, subject_len, subject_id) != ER_OBJECT_OK ||
      er_object_id(challenge_canonical, challenge_len, challenge_id) != ER_OBJECT_OK) {
    return ER_NODE_ERR_BADARG;
  }
  for (i = 0u; i < TEST_TPM_SIGNATURE_HALF; ++i) {
    out_signature[i] = (uint8_t)(subject_id[i] ^ identity->id.bytes[i]);
    out_signature[TEST_TPM_SIGNATURE_HALF + i] =
        (uint8_t)(challenge_id[i] ^ identity->id.bytes[i]);
  }
  *out_signature_len = TEST_TPM_SIGNATURE_SIZE;
  return ER_NODE_OK;
}

static int test_tpm_authority_verify(void* context,
                                     const er_identity_t* identity,
                                     const void* subject_canonical,
                                     size_t subject_len,
                                     const void* challenge_canonical,
                                     size_t challenge_len,
                                     uint16_t algorithm,
                                     const void* signature,
                                     size_t signature_len) {
  uint8_t expected[ER_NODE_SIGNATURE_MAX_SIZE];
  size_t expected_len = 0u;

  if (signature == (const void*)0 ||
      test_tpm_authority_sign(context,
                              identity,
                              subject_canonical,
                              subject_len,
                              challenge_canonical,
                              challenge_len,
                              algorithm,
                              expected,
                              &expected_len) != ER_NODE_OK ||
      signature_len != expected_len) {
    return ER_NODE_ERR_BADARG;
  }
  return test_equal(signature, expected, expected_len) != 0
             ? ER_NODE_OK
             : ER_NODE_ERR_CORRUPT;
}

static void test_prepare_delegated_identity(const er_identity_t* parent,
                                            er_clock_epoch_stamp_t epoch,
                                            er_identity_t* out_identity) {
  uint8_t material[ER_IDENTITY_HASH_SIZE];
  static const char label[] = "child";
  size_t i;

  for (i = 0u; i < sizeof(material); ++i) {
    material[i] = (uint8_t)(0x90u + i);
  }
  check_int("delegated identity",
            er_identity_derive_child(parent, ER_IDENTITY_KIND_DELEGATED,
                                     epoch, label, sizeof(label) - 1u,
                                     material, sizeof(material),
                                     out_identity),
            ER_IDENTITY_OK);
}

static er_store_config_t test_store_config(const er_identity_t* identity,
                                           er_clock_epoch_stamp_t epoch) {
  er_store_config_t config;

  test_zero(&config, sizeof(config));
  test_copy(config.storage_identity_id, identity->id.bytes,
            ER_STORE_IDENTITY_ID_SIZE);
  config.epoch = epoch;
  return config;
}

static er_object_requirements_t test_requirements(void) {
  er_object_requirements_t requirements;

  requirements.durability = ER_OBJECT_DURABILITY_DURABLE;
  requirements.confidentiality = ER_OBJECT_CONFIDENTIALITY_INTEGRITY_ONLY;
  requirements.portability = ER_OBJECT_PORTABILITY_PUBLIC_PORTABLE;
  requirements.integrity = ER_OBJECT_INTEGRITY_HASH_ONLY;
  requirements.lifetime = ER_OBJECT_LIFETIME_RETAINED;
  requirements.visibility = ER_OBJECT_VISIBILITY_PUBLIC;
  requirements.access_cost = ER_OBJECT_ACCESS_EXPLICIT_IO;
  return requirements;
}

static void test_node_objects_and_store_receipts(void) {
  static uint8_t arena[TEST_ARENA_SIZE];
  static uint8_t node_arena[TEST_NODE_ARENA_SIZE];
  uint8_t canonical[TEST_OBJECT_CAP];
  uint8_t fetched[TEST_OBJECT_CAP];
  uint8_t identity_object[TEST_OBJECT_CAP];
  uint8_t clock_object[TEST_OBJECT_CAP];
  uint8_t receipt_object[TEST_OBJECT_CAP];
  uint8_t signature_object[TEST_OBJECT_CAP];
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  uint8_t identity_object_id[ER_OBJECT_ID_SIZE];
  uint8_t clock_object_id[ER_OBJECT_ID_SIZE];
  uint8_t receipt_id[ER_OBJECT_ID_SIZE];
  uint8_t signature_id[ER_OBJECT_ID_SIZE];
  size_t canonical_len = 0u;
  size_t fetched_len = 0u;
  size_t identity_object_len = 0u;
  size_t clock_object_len = 0u;
  size_t receipt_len = 0u;
  size_t signature_len = 0u;
  er_object_signature_info_t signature_info;
  er_object_requirements_t requirements;
  er_object_info_t info;
  er_identity_t identity;
  er_clock_t clock;
  er_store_config_t config;
  er_store_t store;
  er_node_t node;
  er_node_t unsigned_node;
  er_node_authority_t authority;
  er_node_receipt_t receipt;
  TestIo io;
  static const uint8_t body[] = {7u, 8u, 9u};

  test_zero(&io, sizeof(io));
  test_prepare_tpm_identity(&identity, &clock);
  config = test_store_config(&identity, clock.now);
  check_int("store open", er_store_open(&store, test_make_io(&io),
                                        arena, sizeof(arena), &config),
            ER_OK);
  authority.identity_source_kind = ER_IDENTITY_SOURCE_TPM_P256_PUBLIC;
  authority.signature_algorithm = ER_OBJECT_ALGORITHM_ECDSA_P256_SHA256;
  authority.context = (void*)0;
  authority.sign = test_tpm_authority_sign;
  authority.verify = test_tpm_authority_verify;
  check_int("node open", er_node_open(&node, &identity, &authority, node_arena,
                                      sizeof(node_arena),
                                      TEST_PARENT_STORAGE_LIMIT, &store),
            ER_NODE_OK);
  check_int("describe identity",
            er_node_describe_identity(&node, identity_object,
                                      sizeof(identity_object),
                                      &identity_object_len,
                                      identity_object_id),
            ER_NODE_OK);
  check_int("verify identity object",
            er_object_verify(identity_object, identity_object_len, &info),
            ER_OBJECT_OK);
  check_nonzero("identity object id", identity_object_id, ER_OBJECT_ID_SIZE);
  check_int("describe clock",
            er_node_describe_clock(&node, clock_object,
                                   sizeof(clock_object), &clock_object_len,
                                   clock_object_id),
            ER_NODE_OK);
  check_int("verify clock object",
            er_object_verify(clock_object, clock_object_len, &info),
            ER_OBJECT_OK);
  requirements = test_requirements();
  check_int("build object",
            er_node_build_object(&node, ER_OBJECT_KIND_BYTES, 0u,
                                 &requirements,
                                 (const er_object_child_ref_t*)0, 0u,
                                 body, sizeof(body), canonical,
                                 sizeof(canonical), &canonical_len,
                                 object_id),
            ER_NODE_OK);
  check_int("store object", er_node_store_object(&node, canonical,
                                                canonical_len, &receipt),
            ER_NODE_OK);
  check_nonzero("store receipt root", receipt.log_root, ER_OBJECT_ID_SIZE);
  check_int("fetch object", er_node_fetch_object(&node, object_id, fetched,
                                                sizeof(fetched), &fetched_len,
                                                &receipt),
            ER_NODE_OK);
  check_int("fetch same len", (int)(fetched_len == canonical_len), 1);
  check_int("request object",
            er_node_request(&node, canonical, canonical_len, receipt_object,
                            sizeof(receipt_object), &receipt_len, receipt_id),
            ER_NODE_OK);
  check_int("verify request receipt",
            er_object_verify(receipt_object, receipt_len, &info),
            ER_OBJECT_OK);
  check_int("unsigned node open",
            er_node_open(&unsigned_node, &identity,
                         (const er_node_authority_t*)0,
                         (void*)0, 0u, 0u, (er_store_t*)0),
            ER_NODE_OK);
  check_int("unsigned node rejects sign",
            er_node_sign(&unsigned_node, canonical, canonical_len,
                         clock_object, clock_object_len,
                         signature_object, sizeof(signature_object),
                         &signature_len, signature_id),
            ER_NODE_ERR_BADARG);
  check_int("node sign",
            er_node_sign(&node, canonical, canonical_len, clock_object,
                         clock_object_len,
                         signature_object, sizeof(signature_object),
                         &signature_len, signature_id),
            ER_NODE_OK);
  check_int("node signature verify",
            er_object_signature_verify(signature_object, signature_len,
                                       &signature_info),
            ER_OBJECT_OK);
  check_int("node signature algorithm", (int)signature_info.algorithm,
            (int)ER_OBJECT_ALGORITHM_ECDSA_P256_SHA256);
  check_int("node authority verify",
            er_node_verify_signature(&node, canonical, canonical_len,
                                     clock_object, clock_object_len,
                                     signature_object, signature_len),
            ER_NODE_OK);
  check_int("canonical object verify",
            er_object_verify(canonical, canonical_len, &info),
            ER_OBJECT_OK);
  check_bytes("canonical object id", info.object_id, object_id,
              ER_OBJECT_ID_SIZE);
}

static void test_node_spawn_delegates_budget(void) {
  static uint8_t parent_arena[TEST_NODE_ARENA_SIZE];
  uint8_t receipt_object[TEST_OBJECT_CAP];
  uint8_t receipt_id[ER_OBJECT_ID_SIZE];
  size_t receipt_len = 0u;
  er_identity_t parent_identity;
  er_identity_t child_identity;
  er_clock_t parent_clock;
  er_clock_t child_clock;
  er_node_t parent_node;
  er_node_t child_node;
  er_node_budget_t parent_budget;
  er_node_budget_t child_budget;
  er_object_info_t receipt_info;

  test_prepare_identity(&parent_identity, &parent_clock);
  child_clock = parent_clock;
  test_prepare_delegated_identity(&parent_identity, child_clock.now,
                                  &child_identity);
  check_int("spawn parent open",
            er_node_open(&parent_node, &parent_identity,
                         (const er_node_authority_t*)0, parent_arena,
                         sizeof(parent_arena), TEST_PARENT_STORAGE_LIMIT,
                         (er_store_t*)0),
            ER_NODE_OK);
  check_int("spawn child",
            er_node_spawn(&parent_node, &child_identity, TEST_CHILD_MEMORY_SIZE,
                          TEST_CHILD_STORAGE_LIMIT, (er_store_t*)0,
                          &child_node, receipt_object, sizeof(receipt_object),
                          &receipt_len, receipt_id),
            ER_NODE_OK);
  check_int("spawn receipt verify",
            er_object_verify(receipt_object, receipt_len, &receipt_info),
            ER_OBJECT_OK);
  check_nonzero("spawn receipt id", receipt_id, ER_OBJECT_ID_SIZE);
  check_int("spawn parent budget",
            er_node_budget(&parent_node, &parent_budget), ER_NODE_OK);
  check_int("spawn parent memory used",
            (int)parent_budget.memory_used, (int)TEST_CHILD_MEMORY_SIZE);
  check_int("spawn parent storage used",
            (int)parent_budget.storage_used,
            (int)TEST_CHILD_STORAGE_LIMIT);
  check_int("spawn child budget",
            er_node_budget(&child_node, &child_budget), ER_NODE_OK);
  check_int("spawn child memory len",
            (int)child_budget.memory_len, (int)TEST_CHILD_MEMORY_SIZE);
  check_int("spawn child storage limit",
            (int)child_budget.storage_limit,
            (int)TEST_CHILD_STORAGE_LIMIT);
  check_int("spawn rejects over memory",
            er_node_spawn(&parent_node, &child_identity, TEST_NODE_ARENA_SIZE,
                          0u, (er_store_t*)0, &child_node, receipt_object,
                          sizeof(receipt_object), &receipt_len, receipt_id),
            ER_NODE_ERR_BADARG);
  check_int("spawn rejects nondelegated",
            er_node_spawn(&parent_node, &parent_identity, 0u, 0u,
                          (er_store_t*)0, &child_node, receipt_object,
                          sizeof(receipt_object), &receipt_len, receipt_id),
            ER_NODE_ERR_BADARG);
}

int main(void) {
  test_node_objects_and_store_receipts();
  test_node_spawn_delegates_budget();

  if (g_failed != 0) {
    fprintf(stderr, "node tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("node tests passed: %d\n", g_total);
  return 0;
}

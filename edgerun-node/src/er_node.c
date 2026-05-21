#include "er_node.h"

enum {
  ER_NODE_BODY_IDENTITY_SIZE = 4u + ER_IDENTITY_ID_SIZE + ER_CLOCK_KEEPER_ID_SIZE + 32u,
  ER_NODE_BODY_CLOCK_SIZE = ER_CLOCK_KEEPER_ID_SIZE + 32u,
  ER_NODE_BODY_STORE_SIZE = ER_IDENTITY_ID_SIZE + ER_OBJECT_ID_SIZE,
  ER_NODE_BODY_RECEIPT_SIZE = 4u + 4u + ER_OBJECT_ID_SIZE + ER_OBJECT_ID_SIZE +
                              ER_OBJECT_ID_SIZE + ER_CLOCK_KEEPER_ID_SIZE + 32u,
  ER_NODE_BODY_SPAWN_SIZE = 8u + ER_IDENTITY_ID_SIZE + ER_IDENTITY_ID_SIZE +
                            8u + 8u + 8u + 8u +
                            ER_CLOCK_KEEPER_ID_SIZE + 32u,
  ER_NODE_SPAWN_MAGIC0 = 'E',
  ER_NODE_SPAWN_MAGIC1 = 'R',
  ER_NODE_SPAWN_MAGIC2 = 'S',
  ER_NODE_SPAWN_MAGIC3 = 'P',
  ER_NODE_SPAWN_MAGIC4 = 'W',
  ER_NODE_SPAWN_MAGIC5 = 'N',
  ER_NODE_SPAWN_MAGIC6 = '0',
  ER_NODE_SPAWN_MAGIC7 = '1',
  ER_NODE_BYTE0 = 0u,
  ER_NODE_BYTE1 = 1u,
  ER_NODE_BYTE2 = 2u,
  ER_NODE_BYTE3 = 3u,
  ER_NODE_BYTE4 = 4u,
  ER_NODE_BYTE5 = 5u,
  ER_NODE_BYTE6 = 6u,
  ER_NODE_BYTE7 = 7u,
  ER_NODE_U16_SHIFT = 8u,
  ER_NODE_U32_SHIFT1 = 8u,
  ER_NODE_U32_SHIFT2 = 16u,
  ER_NODE_U32_SHIFT3 = 24u,
  ER_NODE_U64_SHIFT1 = 8u,
  ER_NODE_U64_SHIFT2 = 16u,
  ER_NODE_U64_SHIFT3 = 24u,
  ER_NODE_U64_SHIFT4 = 32u,
  ER_NODE_U64_SHIFT5 = 40u,
  ER_NODE_U64_SHIFT6 = 48u,
  ER_NODE_U64_SHIFT7 = 56u
};

typedef struct __attribute__((__may_alias__)) {
  er_identity_t identity;
  er_clock_t clock;
  er_store_t* store;
  uint8_t* arena;
  size_t arena_len;
  size_t arena_used;
  uint64_t storage_limit;
  uint64_t storage_used;
} ErNodeState;

_Static_assert(sizeof(ErNodeState) <= sizeof(er_node_t),
               "public node handle must fit private node state");
_Static_assert(_Alignof(ErNodeState) <= _Alignof(er_node_t),
               "public node handle must satisfy private node state alignment");

static ErNodeState* er_node_state(er_node_t* node) {
  return (ErNodeState*)node;
}

static const ErNodeState* er_node_const_state(const er_node_t* node) {
  return (const ErNodeState*)node;
}

static void er_node_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static void er_node_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static int er_node_equal(const void* left, const void* right, size_t len) {
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

static void er_node_store16(uint8_t* out, uint16_t value) {
  out[ER_NODE_BYTE0] = (uint8_t)value;
  out[ER_NODE_BYTE1] = (uint8_t)(value >> ER_NODE_U16_SHIFT);
}

static void er_node_store32(uint8_t* out, uint32_t value) {
  out[ER_NODE_BYTE0] = (uint8_t)value;
  out[ER_NODE_BYTE1] = (uint8_t)(value >> ER_NODE_U32_SHIFT1);
  out[ER_NODE_BYTE2] = (uint8_t)(value >> ER_NODE_U32_SHIFT2);
  out[ER_NODE_BYTE3] = (uint8_t)(value >> ER_NODE_U32_SHIFT3);
}

static void er_node_store64(uint8_t* out, uint64_t value) {
  out[ER_NODE_BYTE0] = (uint8_t)value;
  out[ER_NODE_BYTE1] = (uint8_t)(value >> ER_NODE_U64_SHIFT1);
  out[ER_NODE_BYTE2] = (uint8_t)(value >> ER_NODE_U64_SHIFT2);
  out[ER_NODE_BYTE3] = (uint8_t)(value >> ER_NODE_U64_SHIFT3);
  out[ER_NODE_BYTE4] = (uint8_t)(value >> ER_NODE_U64_SHIFT4);
  out[ER_NODE_BYTE5] = (uint8_t)(value >> ER_NODE_U64_SHIFT5);
  out[ER_NODE_BYTE6] = (uint8_t)(value >> ER_NODE_U64_SHIFT6);
  out[ER_NODE_BYTE7] = (uint8_t)(value >> ER_NODE_U64_SHIFT7);
}

static er_object_requirements_t er_node_runtime_requirements(void) {
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

static int er_node_build_bytes_object(const ErNodeState* state, const void* body,
                                      size_t body_len, void* out,
                                      size_t out_cap, size_t* out_len,
                                      uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  er_object_requirements_t requirements;

  if (state == (const ErNodeState*)0) {
    return ER_NODE_ERR_BADARG;
  }
  requirements = er_node_runtime_requirements();
  return er_object_build_node(ER_OBJECT_KIND_BYTES, 0u, &requirements,
                              state->clock.now, (const er_object_owner_t*)0, 0u,
                              (const er_object_envelope_t*)0, 0u,
                              (const er_object_child_ref_t*)0, 0u, body,
                              body_len, out, out_cap, out_len,
                              out_id) == ER_OBJECT_OK
             ? ER_NODE_OK
             : ER_NODE_ERR_CORRUPT;
}

static void er_node_epoch_body(er_clock_epoch_stamp_t epoch, uint8_t* out) {
  er_node_copy(out, epoch.keeper_id.bytes, ER_CLOCK_KEEPER_ID_SIZE);
  er_node_store64(&out[ER_CLOCK_KEEPER_ID_SIZE], epoch.tick);
  er_node_store64(&out[ER_CLOCK_KEEPER_ID_SIZE + 8u], epoch.slot);
  er_node_store64(&out[ER_CLOCK_KEEPER_ID_SIZE + 16u], epoch.epoch);
  er_node_store64(&out[ER_CLOCK_KEEPER_ID_SIZE + 24u], epoch.era);
}

int er_node_open_config(er_node_t* node, const er_node_config_t* config) {
  ErNodeState* state = er_node_state(node);

  if (node == (er_node_t*)0 || config == (const er_node_config_t*)0 ||
      er_identity_valid(config->identity) == 0 ||
      config->clock == (const er_clock_t*)0 ||
      er_clock_stamp_valid(config->clock->now) == 0 ||
      er_clock_stamp_same_keeper(config->identity->epoch,
                                 config->clock->now) == 0 ||
      (config->arena_len != 0u && config->arena == (void*)0)) {
    return ER_NODE_ERR_BADARG;
  }
  er_node_zero(state, sizeof(*state));
  state->identity = *config->identity;
  state->clock = *config->clock;
  state->store = config->store;
  state->arena = (uint8_t*)config->arena;
  state->arena_len = config->arena_len;
  state->storage_limit = config->storage_limit;
  return ER_NODE_OK;
}

int er_node_open(er_node_t* node, const er_identity_t* identity,
                 const er_clock_t* clock, er_store_t* store) {
  er_node_config_t config;

  er_node_zero(&config, sizeof(config));
  config.identity = identity;
  config.clock = clock;
  config.store = store;
  return er_node_open_config(node, &config);
}

int er_node_identity(const er_node_t* node, er_identity_t* out_identity) {
  const ErNodeState* state = er_node_const_state(node);

  if (node == (const er_node_t*)0 || out_identity == (er_identity_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  *out_identity = state->identity;
  return ER_NODE_OK;
}

int er_node_epoch(const er_node_t* node, er_clock_epoch_stamp_t* out_epoch) {
  const ErNodeState* state = er_node_const_state(node);

  if (node == (const er_node_t*)0 || out_epoch == (er_clock_epoch_stamp_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  *out_epoch = state->clock.now;
  return ER_NODE_OK;
}

int er_node_budget(const er_node_t* node, er_node_budget_t* out_budget) {
  const ErNodeState* state = er_node_const_state(node);

  if (node == (const er_node_t*)0 || out_budget == (er_node_budget_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  out_budget->memory_len = state->arena_len;
  out_budget->memory_used = state->arena_used;
  out_budget->storage_limit = state->storage_limit;
  out_budget->storage_used = state->storage_used;
  return ER_NODE_OK;
}

static int er_node_add_size(size_t a, size_t b, size_t* out) {
  if (out == (size_t*)0 || a > ((size_t)-1) - b) {
    return ER_NODE_ERR_TOOBIG;
  }
  *out = a + b;
  return ER_NODE_OK;
}

static int er_node_add_u64(uint64_t a, uint64_t b, uint64_t* out) {
  if (out == (uint64_t*)0 || a > (0xffffffffffffffffull - b)) {
    return ER_NODE_ERR_TOOBIG;
  }
  *out = a + b;
  return ER_NODE_OK;
}

int er_node_spawn(er_node_t* parent, const er_identity_t* child_identity,
                  const er_clock_t* child_clock, size_t memory_len,
                  uint64_t storage_limit, er_store_t* child_store,
                  er_node_t* out_child, void* out_receipt_object,
                  size_t out_cap, size_t* out_len,
                  uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  ErNodeState* parent_state = er_node_state(parent);
  er_node_config_t child_config;
  uint8_t body[ER_NODE_BODY_SPAWN_SIZE];
  size_t memory_end;
  uint64_t storage_end;

  if (parent == (er_node_t*)0 || out_child == (er_node_t*)0 ||
      child_identity == (const er_identity_t*)0 ||
      child_clock == (const er_clock_t*)0 ||
      out_receipt_object == (void*)0 || out_len == (size_t*)0 ||
      out_id == (uint8_t*)0 ||
      child_identity->identity_kind != ER_IDENTITY_KIND_DELEGATED ||
      er_identity_valid(child_identity) == 0 ||
      er_clock_stamp_valid(child_clock->now) == 0 ||
      er_clock_stamp_same_keeper(child_identity->epoch, child_clock->now) == 0 ||
      er_node_add_size(parent_state->arena_used, memory_len,
                       &memory_end) != ER_NODE_OK ||
      memory_end > parent_state->arena_len ||
      (memory_len != 0u && parent_state->arena == (uint8_t*)0) ||
      er_node_add_u64(parent_state->storage_used, storage_limit,
                      &storage_end) != ER_NODE_OK ||
      storage_end > parent_state->storage_limit) {
    return ER_NODE_ERR_BADARG;
  }

  er_node_zero(&child_config, sizeof(child_config));
  child_config.identity = child_identity;
  child_config.clock = child_clock;
  child_config.store = child_store;
  child_config.arena = memory_len == 0u ? (void*)0
                                        : &parent_state->arena[parent_state->arena_used];
  child_config.arena_len = memory_len;
  child_config.storage_limit = storage_limit;
  if (er_node_open_config(out_child, &child_config) != ER_NODE_OK) {
    return ER_NODE_ERR_CORRUPT;
  }

  er_node_zero(body, sizeof(body));
  body[0] = ER_NODE_SPAWN_MAGIC0;
  body[1] = ER_NODE_SPAWN_MAGIC1;
  body[2] = ER_NODE_SPAWN_MAGIC2;
  body[3] = ER_NODE_SPAWN_MAGIC3;
  body[4] = ER_NODE_SPAWN_MAGIC4;
  body[5] = ER_NODE_SPAWN_MAGIC5;
  body[6] = ER_NODE_SPAWN_MAGIC6;
  body[7] = ER_NODE_SPAWN_MAGIC7;
  er_node_copy(&body[8u], parent_state->identity.id.bytes,
               ER_IDENTITY_ID_SIZE);
  er_node_copy(&body[8u + ER_IDENTITY_ID_SIZE],
               child_identity->id.bytes, ER_IDENTITY_ID_SIZE);
  er_node_store64(&body[8u + (2u * ER_IDENTITY_ID_SIZE)],
                  (uint64_t)parent_state->arena_used);
  er_node_store64(&body[16u + (2u * ER_IDENTITY_ID_SIZE)],
                  (uint64_t)memory_len);
  er_node_store64(&body[24u + (2u * ER_IDENTITY_ID_SIZE)],
                  parent_state->storage_used);
  er_node_store64(&body[32u + (2u * ER_IDENTITY_ID_SIZE)],
                  storage_limit);
  er_node_epoch_body(parent_state->clock.now,
                     &body[40u + (2u * ER_IDENTITY_ID_SIZE)]);
  parent_state->arena_used = memory_end;
  parent_state->storage_used = storage_end;
  return er_node_build_bytes_object(parent_state, body, sizeof(body),
                                    out_receipt_object, out_cap, out_len,
                                    out_id);
}

int er_node_describe_identity(const er_node_t* node, void* out, size_t out_cap,
                              size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  const ErNodeState* state = er_node_const_state(node);
  uint8_t body[ER_NODE_BODY_IDENTITY_SIZE];

  if (node == (const er_node_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  er_node_zero(body, sizeof(body));
  er_node_store16(body, state->identity.abi_version);
  er_node_store16(&body[2u], state->identity.identity_kind);
  er_node_copy(&body[4u], state->identity.id.bytes, ER_IDENTITY_ID_SIZE);
  er_node_epoch_body(state->identity.epoch, &body[4u + ER_IDENTITY_ID_SIZE]);
  return er_node_build_bytes_object(state, body, sizeof(body), out, out_cap,
                                    out_len, out_id);
}

int er_node_describe_clock(const er_node_t* node, void* out, size_t out_cap,
                           size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  const ErNodeState* state = er_node_const_state(node);
  uint8_t body[ER_NODE_BODY_CLOCK_SIZE];

  if (node == (const er_node_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  er_node_epoch_body(state->clock.now, body);
  return er_node_build_bytes_object(state, body, sizeof(body), out, out_cap,
                                    out_len, out_id);
}

int er_node_describe_store(const er_node_t* node, void* out, size_t out_cap,
                           size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  const ErNodeState* state = er_node_const_state(node);
  uint8_t body[ER_NODE_BODY_STORE_SIZE];
  er_store_stats_t stats;

  if (node == (const er_node_t*)0 || state->store == (er_store_t*)0) {
    return ER_NODE_ERR_NOSTORE;
  }
  if (er_store_stats(state->store, &stats) != ER_OK) {
    return ER_NODE_ERR_CORRUPT;
  }
  er_node_zero(body, sizeof(body));
  er_node_copy(body, stats.storage_identity_id, ER_STORE_IDENTITY_ID_SIZE);
  er_node_copy(&body[ER_STORE_IDENTITY_ID_SIZE], stats.log_root,
               ER_OBJECT_ID_SIZE);
  return er_node_build_bytes_object(state, body, sizeof(body), out, out_cap,
                                    out_len, out_id);
}

int er_node_build_object(er_node_t* node, uint16_t node_kind, uint32_t flags,
                         const er_object_requirements_t* requirements,
                         const er_object_child_ref_t* children,
                         uint32_t child_count, const void* body,
                         size_t body_len, void* out, size_t out_cap,
                         size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  ErNodeState* state = er_node_state(node);

  if (node == (er_node_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  return er_object_build_node(node_kind, flags, requirements, state->clock.now,
                              (const er_object_owner_t*)0, 0u,
                              (const er_object_envelope_t*)0, 0u, children,
                              child_count, body, body_len, out, out_cap,
                              out_len, out_id) == ER_OBJECT_OK
             ? ER_NODE_OK
             : ER_NODE_ERR_CORRUPT;
}

static void er_node_receipt_fill(ErNodeState* state, uint32_t method,
                                 uint32_t status,
                                 const uint8_t subject_id[ER_OBJECT_ID_SIZE],
                                 const uint8_t result_id[ER_OBJECT_ID_SIZE],
                                 er_node_receipt_t* out_receipt) {
  er_node_zero(out_receipt, sizeof(*out_receipt));
  out_receipt->method = method;
  out_receipt->status = status;
  if (subject_id != (const uint8_t*)0) {
    er_node_copy(out_receipt->subject_id, subject_id, ER_OBJECT_ID_SIZE);
  }
  if (result_id != (const uint8_t*)0) {
    er_node_copy(out_receipt->result_id, result_id, ER_OBJECT_ID_SIZE);
  }
  if (state->store != (er_store_t*)0) {
    (void)er_store_log_root(state->store, out_receipt->log_root);
  }
  out_receipt->epoch = state->clock.now;
}

int er_node_store_object(er_node_t* node, const void* canonical,
                         size_t canonical_len,
                         er_node_receipt_t* out_receipt) {
  ErNodeState* state = er_node_state(node);
  er_object_info_t info;
  uint8_t id[ER_OBJECT_ID_SIZE];
  int status;

  if (node == (er_node_t*)0 || canonical == (const void*)0 ||
      out_receipt == (er_node_receipt_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  if (state->store == (er_store_t*)0) {
    return ER_NODE_ERR_NOSTORE;
  }
  if (er_object_verify(canonical, canonical_len, &info) != ER_OBJECT_OK) {
    return ER_NODE_ERR_CORRUPT;
  }
  status = er_store_put_canonical_object(state->store, canonical,
                                         canonical_len, id);
  if (status != ER_OK || !er_node_equal(id, info.object_id, ER_OBJECT_ID_SIZE)) {
    return ER_NODE_ERR_CORRUPT;
  }
  er_node_receipt_fill(state, ER_NODE_METHOD_STORE, ER_NODE_OK,
                       info.object_id, id, out_receipt);
  return ER_NODE_OK;
}

int er_node_fetch_object(er_node_t* node, const uint8_t object_id[ER_OBJECT_ID_SIZE],
                         void* out, size_t out_cap, size_t* out_len,
                         er_node_receipt_t* out_receipt) {
  ErNodeState* state = er_node_state(node);
  int status;

  if (node == (er_node_t*)0 || object_id == (const uint8_t*)0 ||
      out == (void*)0 || out_len == (size_t*)0 ||
      out_receipt == (er_node_receipt_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  if (state->store == (er_store_t*)0) {
    return ER_NODE_ERR_NOSTORE;
  }
  status = er_store_get_canonical_object(state->store, object_id, out,
                                         out_cap, out_len);
  if (status != ER_OK) {
    return status == ER_ERR_TOOBIG ? ER_NODE_ERR_TOOBIG : ER_NODE_ERR_CORRUPT;
  }
  er_node_receipt_fill(state, ER_NODE_METHOD_FETCH, ER_NODE_OK, object_id,
                       object_id, out_receipt);
  return ER_NODE_OK;
}

int er_node_request(er_node_t* node, const void* capability_object,
                    size_t capability_len, void* out_receipt_object,
                    size_t out_cap, size_t* out_len,
                    uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  ErNodeState* state = er_node_state(node);
  er_object_info_t capability;
  uint8_t body[ER_NODE_BODY_RECEIPT_SIZE];
  uint8_t log_root[ER_OBJECT_ID_SIZE];

  if (node == (er_node_t*)0 || capability_object == (const void*)0 ||
      out_receipt_object == (void*)0 || out_len == (size_t*)0 ||
      out_id == (uint8_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  if (er_object_verify(capability_object, capability_len, &capability) !=
      ER_OBJECT_OK) {
    return ER_NODE_ERR_CORRUPT;
  }
  er_node_zero(log_root, sizeof(log_root));
  if (state->store != (er_store_t*)0) {
    (void)er_store_log_root(state->store, log_root);
  }
  er_node_zero(body, sizeof(body));
  er_node_store32(body, ER_NODE_METHOD_REQUEST);
  er_node_store32(&body[4u], ER_NODE_OK);
  er_node_copy(&body[8u], capability.object_id, ER_OBJECT_ID_SIZE);
  er_node_copy(&body[8u + ER_OBJECT_ID_SIZE], capability.object_id,
               ER_OBJECT_ID_SIZE);
  er_node_copy(&body[8u + (2u * ER_OBJECT_ID_SIZE)], log_root,
               ER_OBJECT_ID_SIZE);
  er_node_epoch_body(state->clock.now, &body[8u + (3u * ER_OBJECT_ID_SIZE)]);
  return er_node_build_bytes_object(state, body, sizeof(body),
                                    out_receipt_object, out_cap, out_len,
                                    out_id);
}

int er_node_sign(er_node_t* node, const void* subject_canonical,
                 size_t subject_len, const void* challenge_canonical,
                 size_t challenge_len, uint16_t algorithm,
                 const void* signature, size_t signature_len,
                 void* out_signature_object, size_t out_cap,
                 size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]) {
  ErNodeState* state = er_node_state(node);

  if (node == (er_node_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  return er_object_sign(subject_canonical, subject_len, challenge_canonical,
                        challenge_len, state->identity.id.bytes, algorithm,
                        signature, signature_len, state->clock.now,
                        out_signature_object, out_cap, out_len,
                        out_id) == ER_OBJECT_OK
             ? ER_NODE_OK
             : ER_NODE_ERR_CORRUPT;
}

int er_node_import_object(er_node_t* node, const void* external_bytes,
                          size_t external_len, void* out_canonical,
                          size_t out_cap, size_t* out_len,
                          uint8_t out_id[ER_OBJECT_ID_SIZE],
                          er_node_receipt_t* out_receipt) {
  ErNodeState* state = er_node_state(node);
  er_object_info_t info;
  int rc;

  if (node == (er_node_t*)0 || external_bytes == (const void*)0 ||
      out_canonical == (void*)0 || out_len == (size_t*)0 ||
      out_id == (uint8_t*)0 || out_receipt == (er_node_receipt_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  rc = er_object_deserialize(external_bytes, external_len, &info, out_id);
  if (rc != ER_OBJECT_OK) {
    return ER_NODE_ERR_CORRUPT;
  }
  if (external_len > out_cap) {
    return ER_NODE_ERR_TOOBIG;
  }
  er_node_copy(out_canonical, external_bytes, external_len);
  *out_len = external_len;
  er_node_receipt_fill(state, ER_NODE_METHOD_IMPORT, ER_NODE_OK,
                       info.object_id, info.object_id, out_receipt);
  return ER_NODE_OK;
}

int er_node_export_object(er_node_t* node, const void* canonical,
                          size_t canonical_len, void* out_external,
                          size_t out_cap, size_t* out_len,
                          uint8_t out_id[ER_OBJECT_ID_SIZE],
                          er_node_receipt_t* out_receipt) {
  ErNodeState* state = er_node_state(node);
  int rc;

  if (node == (er_node_t*)0 || out_receipt == (er_node_receipt_t*)0) {
    return ER_NODE_ERR_BADARG;
  }
  rc = er_object_serialize(canonical, canonical_len, out_external, out_cap,
                           out_len, out_id);
  if (rc == ER_OBJECT_ERR_TOOBIG) {
    return ER_NODE_ERR_TOOBIG;
  }
  if (rc != ER_OBJECT_OK) {
    return rc == ER_OBJECT_ERR_BADARG ? ER_NODE_ERR_BADARG
                                      : ER_NODE_ERR_CORRUPT;
  }
  er_node_receipt_fill(state, ER_NODE_METHOD_EXPORT, ER_NODE_OK,
                       out_id, out_id, out_receipt);
  return ER_NODE_OK;
}

#include "er_jurisdiction.h"
#include "er_identity.h"
#include "er_mem.h"

/*
 * Purpose: derive canonical jurisdiction policy and node-instance ids.
 * Intention: mirror the Rust protocol concepts without depending on Rust,
 * host layout, or transport-specific route state.
 */

static const UINT8 g_admission_policy_id_domain[] =
    "edgerun-runtime.admission-policy.v1";
static const UINT8 g_node_instance_id_domain[] =
    "edgerun-runtime.node-instance.v1";

enum {
  ER_JURISDICTION_U16_BYTES = 2u,
  ER_JURISDICTION_U64_BYTES = 8u,
  ER_JURISDICTION_BYTE_BITS = 8u,
  ER_JURISDICTION_BYTE_MASK = 0xffu,
  ER_ADMISSION_POLICY_FIELD_BYTES = ER_JURISDICTION_U16_BYTES +
                                    (ER_JURISDICTION_U64_BYTES * 3u),
  ER_ADMISSION_POLICY_SPAN_COUNT = 4u,
  ER_ADMISSION_POLICY_OWNER_SPAN = 0u,
  ER_ADMISSION_POLICY_NODE_SPAN = 1u,
  ER_ADMISSION_POLICY_HASH_SPAN = 2u,
  ER_ADMISSION_POLICY_FIELDS_SPAN = 3u,
  ER_NODE_INSTANCE_FIELD_BYTES = (ER_JURISDICTION_U16_BYTES * 3u) +
                                 (ER_JURISDICTION_U64_BYTES * 3u),
  ER_NODE_INSTANCE_SPAN_COUNT = 4u,
  ER_NODE_INSTANCE_OWNER_SPAN = 0u,
  ER_NODE_INSTANCE_NODE_SPAN = 1u,
  ER_NODE_INSTANCE_SCOPE_SPAN = 2u,
  ER_NODE_INSTANCE_FIELDS_SPAN = 3u
};

static void er_jurisdiction_put_le16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & ER_JURISDICTION_BYTE_MASK);
  dst[1] = (UINT8)((value >> ER_JURISDICTION_BYTE_BITS) &
                   ER_JURISDICTION_BYTE_MASK);
}

static void er_jurisdiction_put_le64(UINT8* dst, UINT64 value) {
  UINTN i;

  for (i = 0u; i < ER_JURISDICTION_U64_BYTES; ++i) {
    dst[i] = (UINT8)((value >> (i * ER_JURISDICTION_BYTE_BITS)) &
                     ER_JURISDICTION_BYTE_MASK);
  }
}

static void er_jurisdiction_span_set(ErByteSpan* span, const UINT8* bytes,
                                     UINTN len) {
  span->bytes = bytes;
  span->len = len;
}

static UINT8 er_jurisdiction_owner_valid(const ErIdentity* owner_identity) {
  if (er_identity_valid(owner_identity) == 0u ||
      owner_identity->material_len != ER_NODE_ID_LEN) {
    return 0u;
  }
  switch (owner_identity->identity_type) {
    case ER_IDENTITY_TYPE_PUBLIC_KEY:
      return (UINT8)(owner_identity->backing_type == ER_IDENTITY_BACKING_ED25519);
    case ER_IDENTITY_TYPE_HASH:
      return (UINT8)(owner_identity->backing_type == ER_IDENTITY_BACKING_HASH);
    default:
      return 0u;
  }
}

UINT8 er_jurisdiction_node_identity_authority_valid(const ErNodeIdentity* identity) {
  if (identity == 0 ||
      identity->abi_version != ER_WORK_ABI_VERSION ||
      identity->role == 0u ||
      identity->identity.identity_type != ER_IDENTITY_TYPE_PUBLIC_KEY ||
      identity->identity.backing_type != ER_IDENTITY_BACKING_ED25519 ||
      identity->identity.material_len != ER_NODE_ID_LEN ||
      er_identity_valid(&identity->identity) == 0u ||
      er_mem_equal(identity->node_id.bytes,
                   identity->identity.material,
                   ER_NODE_ID_LEN) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_admission_policy_source_valid(UINT16 source) {
  switch (source) {
    case ER_ADMISSION_POLICY_SOURCE_DAO:
    case ER_ADMISSION_POLICY_SOURCE_USER:
    case ER_ADMISSION_POLICY_SOURCE_INHERITED:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_node_instance_status_valid(UINT16 status) {
  switch (status) {
    case ER_NODE_INSTANCE_STATUS_PENDING:
    case ER_NODE_INSTANCE_STATUS_RUNNING:
    case ER_NODE_INSTANCE_STATUS_STOPPED:
    case ER_NODE_INSTANCE_STATUS_REVOKED:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_runtime_target_valid(UINT16 runtime_target) {
  switch (runtime_target) {
    case ER_RUNTIME_TARGET_FIRMWARE:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_admission_policy_id(const ErCryptoProvider* crypto,
                                    UINT16 source,
                                    const ErIdentity* owner_identity,
                                    const ErNodeIdentity* admission_node,
                                    const ErHash* policy_hash,
                                    UINT64 max_budget,
                                    UINT64 valid_from_ms,
                                    UINT64 valid_until_ms,
                                    ErHash* out_policy_id) {
  UINT8 fields[ER_ADMISSION_POLICY_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_ADMISSION_POLICY_SPAN_COUNT];

  if (crypto == 0 ||
      owner_identity == 0 ||
      admission_node == 0 ||
      policy_hash == 0 ||
      out_policy_id == 0 ||
      er_admission_policy_source_valid(source) == 0u ||
      er_jurisdiction_owner_valid(owner_identity) == 0u ||
      er_jurisdiction_node_identity_authority_valid(admission_node) == 0u ||
      admission_node->role != ER_NODE_ROLE_ADMISSION ||
      er_hash_nonzero(policy_hash) == 0u ||
      max_budget == 0u ||
      valid_until_ms < valid_from_ms) {
    return 0u;
  }

  er_jurisdiction_put_le16(cursor, source);
  cursor += ER_JURISDICTION_U16_BYTES;
  er_jurisdiction_put_le64(cursor, max_budget);
  cursor += ER_JURISDICTION_U64_BYTES;
  er_jurisdiction_put_le64(cursor, valid_from_ms);
  cursor += ER_JURISDICTION_U64_BYTES;
  er_jurisdiction_put_le64(cursor, valid_until_ms);

  er_jurisdiction_span_set(&spans[ER_ADMISSION_POLICY_OWNER_SPAN],
                           owner_identity->material,
                           owner_identity->material_len);
  er_jurisdiction_span_set(&spans[ER_ADMISSION_POLICY_NODE_SPAN],
                           admission_node->node_id.bytes,
                           ER_NODE_ID_LEN);
  er_jurisdiction_span_set(&spans[ER_ADMISSION_POLICY_HASH_SPAN],
                           policy_hash->bytes,
                           ER_HASH_LEN);
  er_jurisdiction_span_set(&spans[ER_ADMISSION_POLICY_FIELDS_SPAN],
                           fields,
                           (UINTN)sizeof(fields));
  return er_crypto_hash(crypto,
                        g_admission_policy_id_domain,
                        (UINTN)(sizeof(g_admission_policy_id_domain) - 1u),
                        spans,
                        ER_ADMISSION_POLICY_SPAN_COUNT,
                        out_policy_id);
}

UINT8 er_admission_policy_prepare(const ErCryptoProvider* crypto,
                                  UINT16 source,
                                  const ErIdentity* owner_identity,
                                  const ErNodeIdentity* admission_node,
                                  const ErHash* policy_hash,
                                  UINT64 max_budget,
                                  UINT64 valid_from_ms,
                                  UINT64 valid_until_ms,
                                  ErAdmissionPolicyRecord* out_policy) {
  ErHash policy_id;

  if (out_policy == 0 ||
      er_admission_policy_id(crypto,
                             source,
                             owner_identity,
                             admission_node,
                             policy_hash,
                             max_budget,
                             valid_from_ms,
                             valid_until_ms,
                             &policy_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_policy, (UINTN)sizeof(*out_policy));
  out_policy->abi_version = ER_JURISDICTION_ABI_VERSION;
  out_policy->source = source;
  out_policy->policy_id = policy_id;
  out_policy->owner_identity = *owner_identity;
  out_policy->admission_node = *admission_node;
  out_policy->policy_hash = *policy_hash;
  out_policy->max_budget = max_budget;
  out_policy->valid_from_ms = valid_from_ms;
  out_policy->valid_until_ms = valid_until_ms;
  return 1u;
}

UINT8 er_admission_policy_valid(const ErCryptoProvider* crypto,
                                const ErAdmissionPolicyRecord* policy) {
  ErHash expected_id;

  if (policy == 0 ||
      policy->abi_version != ER_JURISDICTION_ABI_VERSION ||
      er_admission_policy_id(crypto,
                             policy->source,
                             &policy->owner_identity,
                             &policy->admission_node,
                             &policy->policy_hash,
                             policy->max_budget,
                             policy->valid_from_ms,
                             policy->valid_until_ms,
                             &expected_id) == 0u ||
      er_hash_equal(&policy->policy_id, &expected_id) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_node_instance_id(const ErCryptoProvider* crypto,
                                 const ErIdentity* owner_identity,
                                 const ErNodeId* node_id,
                                 UINT16 role,
                                 UINT16 runtime_target,
                                 const ErHash* policy_hash,
                                 UINT64 admitted_budget,
                                 const ErHash* route_scope_hash,
                                 UINT64 valid_from_ms,
                                 UINT64 valid_until_ms,
                                 UINT16 status,
                                 ErHash* out_instance_id) {
  UINT8 fields[ER_NODE_INSTANCE_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_NODE_INSTANCE_SPAN_COUNT];

  if (crypto == 0 ||
      owner_identity == 0 ||
      node_id == 0 ||
      policy_hash == 0 ||
      route_scope_hash == 0 ||
      out_instance_id == 0 ||
      role == 0u ||
      er_runtime_target_valid(runtime_target) == 0u ||
      er_node_instance_status_valid(status) == 0u ||
      er_jurisdiction_owner_valid(owner_identity) == 0u ||
      er_node_id_nonzero(node_id) == 0u ||
      er_hash_nonzero(policy_hash) == 0u ||
      er_hash_nonzero(route_scope_hash) == 0u ||
      admitted_budget == 0u ||
      valid_until_ms < valid_from_ms) {
    return 0u;
  }

  er_jurisdiction_put_le16(cursor, role);
  cursor += ER_JURISDICTION_U16_BYTES;
  er_jurisdiction_put_le16(cursor, runtime_target);
  cursor += ER_JURISDICTION_U16_BYTES;
  er_jurisdiction_put_le16(cursor, status);
  cursor += ER_JURISDICTION_U16_BYTES;
  er_jurisdiction_put_le64(cursor, admitted_budget);
  cursor += ER_JURISDICTION_U64_BYTES;
  er_jurisdiction_put_le64(cursor, valid_from_ms);
  cursor += ER_JURISDICTION_U64_BYTES;
  er_jurisdiction_put_le64(cursor, valid_until_ms);

  er_jurisdiction_span_set(&spans[ER_NODE_INSTANCE_OWNER_SPAN],
                           owner_identity->material,
                           owner_identity->material_len);
  er_jurisdiction_span_set(&spans[ER_NODE_INSTANCE_NODE_SPAN],
                           node_id->bytes,
                           ER_NODE_ID_LEN);
  er_jurisdiction_span_set(&spans[ER_NODE_INSTANCE_SCOPE_SPAN],
                           route_scope_hash->bytes,
                           ER_HASH_LEN);
  er_jurisdiction_span_set(&spans[ER_NODE_INSTANCE_FIELDS_SPAN],
                           fields,
                           (UINTN)sizeof(fields));
  return er_crypto_hash(crypto,
                        g_node_instance_id_domain,
                        (UINTN)(sizeof(g_node_instance_id_domain) - 1u),
                        spans,
                        ER_NODE_INSTANCE_SPAN_COUNT,
                        out_instance_id);
}

UINT8 er_node_instance_prepare(const ErCryptoProvider* crypto,
                               const ErIdentity* owner_identity,
                               const ErNodeId* node_id,
                               UINT16 role,
                               UINT16 runtime_target,
                               const ErHash* policy_hash,
                               UINT64 admitted_budget,
                               const ErHash* route_scope_hash,
                               UINT64 valid_from_ms,
                               UINT64 valid_until_ms,
                               UINT16 status,
                               ErNodeInstanceRecord* out_instance) {
  ErHash instance_id;

  if (out_instance == 0 ||
      er_node_instance_id(crypto,
                          owner_identity,
                          node_id,
                          role,
                          runtime_target,
                          policy_hash,
                          admitted_budget,
                          route_scope_hash,
                          valid_from_ms,
                          valid_until_ms,
                          status,
                          &instance_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_instance, (UINTN)sizeof(*out_instance));
  out_instance->abi_version = ER_JURISDICTION_ABI_VERSION;
  out_instance->role = role;
  out_instance->instance_id = instance_id;
  out_instance->owner_identity = *owner_identity;
  out_instance->node_id = *node_id;
  out_instance->runtime_target = runtime_target;
  out_instance->status = status;
  out_instance->policy_hash = *policy_hash;
  out_instance->admitted_budget = admitted_budget;
  out_instance->route_scope_hash = *route_scope_hash;
  out_instance->valid_from_ms = valid_from_ms;
  out_instance->valid_until_ms = valid_until_ms;
  return 1u;
}

UINT8 er_node_instance_valid(const ErCryptoProvider* crypto,
                             const ErNodeInstanceRecord* instance) {
  ErHash expected_id;

  if (instance == 0 ||
      instance->abi_version != ER_JURISDICTION_ABI_VERSION ||
      er_node_instance_id(crypto,
                          &instance->owner_identity,
                          &instance->node_id,
                          instance->role,
                          instance->runtime_target,
                          &instance->policy_hash,
                          instance->admitted_budget,
                          &instance->route_scope_hash,
                          instance->valid_from_ms,
                          instance->valid_until_ms,
                          instance->status,
                          &expected_id) == 0u ||
      er_hash_equal(&instance->instance_id, &expected_id) == 0u) {
    return 0u;
  }
  return 1u;
}

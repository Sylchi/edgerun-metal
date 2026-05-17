#include "er_app.h"
#include "er_mem.h"

/*
 * Purpose: derive app and IPC identities from runtime hashes.
 * Intention: make app routing content-addressed and admission-bound; locality grants no authority.
 */

static const UINT8 g_app_node_domain[] = "edgerun:c:v1:app:node-id";
static const UINT8 g_app_route_domain[] = "edgerun:c:v1:app:ipc-route";
static const UINT8 g_app_session_domain[] = "edgerun:c:v1:app:ipc-session";
static const UINT8 g_app_budget_domain[] = "edgerun:c:v1:app:budget";
static const UINT8 g_app_schedule_domain[] = "edgerun:c:v1:app:schedule-slot";
static const UINT8 g_app_launch_allocation_domain[] = "edgerun:c:v1:app:launch-allocation";

enum {
  ER_APP_BYTE_BITS = 8u,
  ER_APP_BYTE_MASK = 0xffu,
  ER_APP_U16_FIELD_BYTES = 2u,
  ER_APP_U64_FIELD_BYTES = 8u,
  ER_APP_BUDGET_U64_FIELD_COUNT = 6u,
  ER_APP_BUDGET_FIELD_BYTES = ER_APP_U16_FIELD_BYTES + (ER_APP_U64_FIELD_BYTES * ER_APP_BUDGET_U64_FIELD_COUNT),
  ER_APP_IDENTITY_HASH_SPAN_COUNT = 4u,
  ER_APP_IDENTITY_APP_OBJECT_SPAN = 0u,
  ER_APP_IDENTITY_MANIFEST_SPAN = 1u,
  ER_APP_IDENTITY_ADMISSION_SPAN = 2u,
  ER_APP_IDENTITY_NONCE_SPAN = 3u,
  ER_APP_IDENTITY_BUDGET_SPAN_COUNT = 4u,
  ER_APP_IDENTITY_BUDGET_NODE_SPAN = 0u,
  ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN = 1u,
  ER_APP_IDENTITY_BUDGET_ID_SPAN = 2u,
  ER_APP_IDENTITY_BUDGET_FIELDS_SPAN = 3u,
  ER_APP_BUDGET_HASH_SPAN_COUNT = 4u,
  ER_APP_BUDGET_HASH_APP_OBJECT_SPAN = 0u,
  ER_APP_BUDGET_HASH_MANIFEST_SPAN = 1u,
  ER_APP_BUDGET_HASH_ADMISSION_SPAN = 2u,
  ER_APP_BUDGET_HASH_FIELDS_SPAN = 3u,
  ER_APP_ROUTE_BINDING_SPAN_COUNT = 5u,
  ER_APP_ROUTE_SOURCE_SPAN = 0u,
  ER_APP_ROUTE_TARGET_SPAN = 1u,
  ER_APP_ROUTE_CAPABILITY_SPAN = 2u,
  ER_APP_ROUTE_HASH_SPAN = 3u,
  ER_APP_ROUTE_SEQUENCE_SPAN = 4u,
  ER_APP_SESSION_SPAN_COUNT = 3u,
  ER_APP_SESSION_ADMISSION_SPAN = 0u,
  ER_APP_SESSION_ROUTE_SPAN = 1u,
  ER_APP_SESSION_NONCE_SPAN = 2u,
  ER_APP_PACKED_FIELD0_OFFSET = 0u,
  ER_APP_PACKED_FIELD1_OFFSET = 8u,
  ER_APP_PACKED_FIELD2_OFFSET = 16u,
  ER_APP_PACKED_FIELD3_OFFSET = 24u,
  ER_APP_PACKED_U64_FIELD_COUNT = 4u,
  ER_APP_PACKED_U64_FIELDS_BYTES = ER_APP_U64_FIELD_BYTES * ER_APP_PACKED_U64_FIELD_COUNT
};

static void er_app_put_be(UINT8* dst, UINT64 value, UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_APP_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_APP_BYTE_MASK);
  }
}

static void er_app_put_be16(UINT8* dst, UINT16 value) {
  er_app_put_be(dst, value, ER_APP_U16_FIELD_BYTES);
}

static void er_app_put_be64(UINT8* dst, UINT64 value) {
  er_app_put_be(dst, value, ER_APP_U64_FIELD_BYTES);
}

static void er_app_put_budget_field(UINT8** cursor, UINT64 value) {
  er_app_put_be64(*cursor, value);
  *cursor += ER_APP_U64_FIELD_BYTES;
}

static UINT8 er_app_add_overflows(UINT64 current, UINT64 amount) {
  return (UINT64)(current + amount) < current ? 1u : 0u;
}

static void er_app_prepare_identity_budget_spans(const ErAppIdentity* identity, const ErAppBudget* budget,
                                                 const UINT8* fields, UINTN fields_len, ErByteSpan* spans) {
  spans[ER_APP_IDENTITY_BUDGET_NODE_SPAN].bytes = identity->app_node_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_NODE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN].bytes = identity->admission_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_BUDGET_ID_SPAN].bytes = budget->budget_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_ID_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_BUDGET_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_IDENTITY_BUDGET_FIELDS_SPAN].len = fields_len;
}

UINT8 er_app_derive_identity(const ErCryptoProvider* crypto, const ErHash* app_object_id,
                             const ErHash* manifest_hash, const ErHash* admission_id,
                             const UINT8* instance_nonce, UINTN instance_nonce_len,
                             ErAppIdentity* out_identity) {
  ErHash app_node_hash;
  ErByteSpan spans[ER_APP_IDENTITY_HASH_SPAN_COUNT];

  if (crypto == 0 || app_object_id == 0 || manifest_hash == 0 || admission_id == 0 || out_identity == 0) {
    return 0;
  }
  if (instance_nonce_len != ER_APP_INSTANCE_NONCE_LEN || instance_nonce == 0) {
    return 0;
  }

  spans[ER_APP_IDENTITY_APP_OBJECT_SPAN].bytes = app_object_id->bytes;
  spans[ER_APP_IDENTITY_APP_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_MANIFEST_SPAN].bytes = manifest_hash->bytes;
  spans[ER_APP_IDENTITY_MANIFEST_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_ADMISSION_SPAN].bytes = admission_id->bytes;
  spans[ER_APP_IDENTITY_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_NONCE_SPAN].bytes = instance_nonce;
  spans[ER_APP_IDENTITY_NONCE_SPAN].len = instance_nonce_len;
  if (er_crypto_hash(crypto, g_app_node_domain, (UINTN)(sizeof(g_app_node_domain) - 1u),
                     spans, ER_APP_IDENTITY_HASH_SPAN_COUNT, &app_node_hash) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->abi_version = ER_APP_ABI_VERSION;
  out_identity->app_object_id = *app_object_id;
  out_identity->manifest_hash = *manifest_hash;
  out_identity->admission_id = *admission_id;
  er_mem_copy(out_identity->instance_nonce, instance_nonce, ER_APP_INSTANCE_NONCE_LEN);
  er_mem_copy(out_identity->app_node_id.bytes, app_node_hash.bytes, ER_NODE_ID_LEN);
  return 1;
}

UINT8 er_app_prepare_ipc_route_binding(const ErCryptoProvider* crypto, const ErAppIdentity* source_app,
                                       const ErNodeId* target_node_id, const ErHash* capability_id,
                                       const ErHash* route_hash, UINT64 sequence_base,
                                       UINT32 capability_risk_flags, ErAppIpcRouteBinding* out_binding) {
  UINT8 sequence_be[ER_APP_U64_FIELD_BYTES];
  ErByteSpan route_spans[ER_APP_ROUTE_BINDING_SPAN_COUNT];
  ErByteSpan session_spans[ER_APP_SESSION_SPAN_COUNT];

  if (crypto == 0 || source_app == 0 || target_node_id == 0 || capability_id == 0 ||
      route_hash == 0 || out_binding == 0) {
    return 0;
  }
  if (source_app->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (capability_risk_flags != ER_CAPABILITY_RISK_NONE) {
    return 0;
  }

  er_mem_zero((UINT8*)out_binding, (UINTN)sizeof(*out_binding));
  out_binding->abi_version = ER_APP_ABI_VERSION;
  out_binding->seal_policy = ER_APP_SEAL_POLICY_REQUIRED;
  out_binding->admission_id = source_app->admission_id;
  out_binding->source_app_node_id = source_app->app_node_id;
  out_binding->target_node_id = *target_node_id;
  out_binding->capability_id = *capability_id;
  out_binding->route_hash = *route_hash;
  out_binding->sequence_base = sequence_base;
  out_binding->capability_risk_flags = capability_risk_flags;

  er_app_put_be64(sequence_be, sequence_base);
  route_spans[ER_APP_ROUTE_SOURCE_SPAN].bytes = source_app->app_node_id.bytes;
  route_spans[ER_APP_ROUTE_SOURCE_SPAN].len = ER_NODE_ID_LEN;
  route_spans[ER_APP_ROUTE_TARGET_SPAN].bytes = target_node_id->bytes;
  route_spans[ER_APP_ROUTE_TARGET_SPAN].len = ER_NODE_ID_LEN;
  route_spans[ER_APP_ROUTE_CAPABILITY_SPAN].bytes = capability_id->bytes;
  route_spans[ER_APP_ROUTE_CAPABILITY_SPAN].len = ER_HASH_LEN;
  route_spans[ER_APP_ROUTE_HASH_SPAN].bytes = route_hash->bytes;
  route_spans[ER_APP_ROUTE_HASH_SPAN].len = ER_HASH_LEN;
  route_spans[ER_APP_ROUTE_SEQUENCE_SPAN].bytes = sequence_be;
  route_spans[ER_APP_ROUTE_SEQUENCE_SPAN].len = (UINTN)sizeof(sequence_be);
  if (er_crypto_hash(crypto, g_app_route_domain, (UINTN)(sizeof(g_app_route_domain) - 1u),
                     route_spans, ER_APP_ROUTE_BINDING_SPAN_COUNT, &out_binding->route_binding_id) == 0u) {
    return 0;
  }

  session_spans[ER_APP_SESSION_ADMISSION_SPAN].bytes = source_app->admission_id.bytes;
  session_spans[ER_APP_SESSION_ADMISSION_SPAN].len = ER_HASH_LEN;
  session_spans[ER_APP_SESSION_ROUTE_SPAN].bytes = out_binding->route_binding_id.bytes;
  session_spans[ER_APP_SESSION_ROUTE_SPAN].len = ER_HASH_LEN;
  session_spans[ER_APP_SESSION_NONCE_SPAN].bytes = source_app->instance_nonce;
  session_spans[ER_APP_SESSION_NONCE_SPAN].len = ER_APP_INSTANCE_NONCE_LEN;
  return er_crypto_hash(crypto, g_app_session_domain, (UINTN)(sizeof(g_app_session_domain) - 1u),
                        session_spans, ER_APP_SESSION_SPAN_COUNT, &out_binding->session_id);
}

UINT8 er_app_prepare_budget(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                            UINT16 app_kind, UINT64 max_cpu_steps, UINT64 max_memory_bytes,
                            UINT64 max_packet_bytes, UINT64 max_storage_bytes,
                            UINT64 max_ipc_sends, UINT64 max_ipc_recvs,
                            ErAppBudget* out_budget) {
  UINT8 fields[ER_APP_BUDGET_FIELD_BYTES];
  UINT8* field_cursor = fields;
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || out_budget == 0 || identity->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (app_kind != ER_APP_KIND_USER) {
    return 0;
  }
  if (max_cpu_steps == 0u || max_memory_bytes == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_budget, (UINTN)sizeof(*out_budget));
  out_budget->abi_version = ER_APP_ABI_VERSION;
  out_budget->app_kind = app_kind;
  out_budget->admission_id = identity->admission_id;
  out_budget->app_object_id = identity->app_object_id;
  out_budget->max_cpu_steps = max_cpu_steps;
  out_budget->max_memory_bytes = max_memory_bytes;
  out_budget->max_packet_bytes = max_packet_bytes;
  out_budget->max_storage_bytes = max_storage_bytes;
  out_budget->max_ipc_sends = max_ipc_sends;
  out_budget->max_ipc_recvs = max_ipc_recvs;

  er_app_put_be16(field_cursor, app_kind);
  field_cursor += ER_APP_U16_FIELD_BYTES;
  er_app_put_budget_field(&field_cursor, max_cpu_steps);
  er_app_put_budget_field(&field_cursor, max_memory_bytes);
  er_app_put_budget_field(&field_cursor, max_packet_bytes);
  er_app_put_budget_field(&field_cursor, max_storage_bytes);
  er_app_put_budget_field(&field_cursor, max_ipc_sends);
  er_app_put_budget_field(&field_cursor, max_ipc_recvs);

  spans[ER_APP_BUDGET_HASH_APP_OBJECT_SPAN].bytes = identity->app_object_id.bytes;
  spans[ER_APP_BUDGET_HASH_APP_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_MANIFEST_SPAN].bytes = identity->manifest_hash.bytes;
  spans[ER_APP_BUDGET_HASH_MANIFEST_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_ADMISSION_SPAN].bytes = identity->admission_id.bytes;
  spans[ER_APP_BUDGET_HASH_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_BUDGET_HASH_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_app_budget_domain, (UINTN)(sizeof(g_app_budget_domain) - 1u),
                        spans, ER_APP_BUDGET_HASH_SPAN_COUNT, &out_budget->budget_id);
}

UINT8 er_app_usage_init(const ErAppIdentity* identity, const ErAppBudget* budget, ErAppUsage* out_usage) {
  if (identity == 0 || budget == 0 || out_usage == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER) {
    return 0;
  }

  er_mem_zero((UINT8*)out_usage, (UINTN)sizeof(*out_usage));
  out_usage->abi_version = ER_APP_ABI_VERSION;
  out_usage->budget_id = budget->budget_id;
  out_usage->app_node_id = identity->app_node_id;
  return 1;
}

UINT8 er_app_usage_charge(ErAppUsage* usage, const ErAppBudget* budget, UINT32 resource_kind, UINT64 amount) {
  UINT64* current = 0;
  UINT64 limit = 0;

  if (usage == 0 || budget == 0 || usage->abi_version != ER_APP_ABI_VERSION ||
      budget->abi_version != ER_APP_ABI_VERSION || amount == 0u) {
    return 0;
  }

  switch (resource_kind) {
    case ER_APP_BUDGET_CPU_STEP:
      current = &usage->cpu_steps;
      limit = budget->max_cpu_steps;
      break;
    case ER_APP_BUDGET_MEMORY_BYTE:
      current = &usage->memory_bytes;
      limit = budget->max_memory_bytes;
      break;
    case ER_APP_BUDGET_PACKET_BYTE:
      current = &usage->packet_bytes;
      limit = budget->max_packet_bytes;
      break;
    case ER_APP_BUDGET_STORAGE_BYTE:
      current = &usage->storage_bytes;
      limit = budget->max_storage_bytes;
      break;
    case ER_APP_BUDGET_IPC_SEND:
      current = &usage->ipc_sends;
      limit = budget->max_ipc_sends;
      break;
    case ER_APP_BUDGET_IPC_RECV:
      current = &usage->ipc_recvs;
      limit = budget->max_ipc_recvs;
      break;
    default:
      return 0;
  }

  if (limit == 0u || er_app_add_overflows(*current, amount) != 0u || *current + amount > limit) {
    return 0;
  }
  *current += amount;
  return 1;
}

UINT8 er_app_prepare_schedule_slot(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                   const ErAppBudget* budget, UINT64 deterministic_tick,
                                   UINT64 sequence, ErAppScheduleSlot* out_slot) {
  UINT8 fields[ER_APP_PACKED_U64_FIELDS_BYTES];
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || budget == 0 || out_slot == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_cpu_steps == 0u || budget->max_memory_bytes == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_slot, (UINTN)sizeof(*out_slot));
  out_slot->abi_version = ER_APP_ABI_VERSION;
  out_slot->admission_id = identity->admission_id;
  out_slot->app_node_id = identity->app_node_id;
  out_slot->deterministic_tick = deterministic_tick;
  out_slot->sequence = sequence;
  out_slot->cpu_step_quanta = budget->max_cpu_steps;
  out_slot->memory_byte_limit = budget->max_memory_bytes;

  er_app_put_be64(&fields[ER_APP_PACKED_FIELD0_OFFSET], deterministic_tick);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD1_OFFSET], sequence);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD2_OFFSET], out_slot->cpu_step_quanta);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD3_OFFSET], out_slot->memory_byte_limit);
  er_app_prepare_identity_budget_spans(identity, budget, fields, (UINTN)sizeof(fields), spans);
  return er_crypto_hash(crypto, g_app_schedule_domain, (UINTN)(sizeof(g_app_schedule_domain) - 1u),
                        spans, ER_APP_IDENTITY_BUDGET_SPAN_COUNT, &out_slot->slot_id);
}

UINT8 er_app_prepare_launch_allocation(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                       const ErAppBudget* budget, UINT64 executor_memory_base,
                                       UINT64 executor_memory_len, ErAppLaunchAllocation* out_allocation) {
  UINT8 fields[ER_APP_PACKED_U64_FIELDS_BYTES];
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || budget == 0 || out_allocation == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_memory_bytes == 0u ||
      executor_memory_base == 0u || executor_memory_len != budget->max_memory_bytes) {
    return 0;
  }

  er_mem_zero((UINT8*)out_allocation, (UINTN)sizeof(*out_allocation));
  out_allocation->abi_version = ER_APP_ABI_VERSION;
  out_allocation->admission_id = identity->admission_id;
  out_allocation->budget_id = budget->budget_id;
  out_allocation->app_node_id = identity->app_node_id;
  out_allocation->executor_memory_base = executor_memory_base;
  out_allocation->executor_memory_len = executor_memory_len;
  out_allocation->app_address_base = ER_APP_ADDRESS_BASE;
  out_allocation->app_address_len = budget->max_memory_bytes;

  er_app_put_be64(&fields[ER_APP_PACKED_FIELD0_OFFSET], executor_memory_base);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD1_OFFSET], executor_memory_len);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD2_OFFSET], out_allocation->app_address_base);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD3_OFFSET], out_allocation->app_address_len);
  er_app_prepare_identity_budget_spans(identity, budget, fields, (UINTN)sizeof(fields), spans);
  return er_crypto_hash(crypto, g_app_launch_allocation_domain,
                        (UINTN)(sizeof(g_app_launch_allocation_domain) - 1u),
                        spans, ER_APP_IDENTITY_BUDGET_SPAN_COUNT, &out_allocation->allocation_id);
}

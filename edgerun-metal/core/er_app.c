#include "er_app.h"

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

static void er_app_zero(UINT8* bytes, UINTN len) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0; i < len; ++i) {
    bytes[i] = 0;
  }
}

static void er_app_copy(UINT8* dst, const UINT8* src, UINTN len) {
  UINTN i;

  for (i = 0; i < len; ++i) {
    dst[i] = src[i];
  }
}

static void er_app_put_be64(UINT8* dst, UINT64 value) {
  dst[0] = (UINT8)((value >> 56) & 0xffu);
  dst[1] = (UINT8)((value >> 48) & 0xffu);
  dst[2] = (UINT8)((value >> 40) & 0xffu);
  dst[3] = (UINT8)((value >> 32) & 0xffu);
  dst[4] = (UINT8)((value >> 24) & 0xffu);
  dst[5] = (UINT8)((value >> 16) & 0xffu);
  dst[6] = (UINT8)((value >> 8) & 0xffu);
  dst[7] = (UINT8)(value & 0xffu);
}

static UINT8 er_app_add_overflows(UINT64 current, UINT64 amount) {
  return (UINT64)(current + amount) < current ? 1u : 0u;
}

UINT8 er_app_derive_identity(const ErCryptoProvider* crypto, const ErHash* app_object_id,
                             const ErHash* manifest_hash, const ErHash* admission_id,
                             const UINT8* instance_nonce, UINTN instance_nonce_len,
                             ErAppIdentity* out_identity) {
  ErHash app_node_hash;
  ErByteSpan spans[4];

  if (crypto == 0 || app_object_id == 0 || manifest_hash == 0 || admission_id == 0 || out_identity == 0) {
    return 0;
  }
  if (instance_nonce_len != ER_APP_INSTANCE_NONCE_LEN || instance_nonce == 0) {
    return 0;
  }

  spans[0].bytes = app_object_id->bytes;
  spans[0].len = ER_HASH_LEN;
  spans[1].bytes = manifest_hash->bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = admission_id->bytes;
  spans[2].len = ER_HASH_LEN;
  spans[3].bytes = instance_nonce;
  spans[3].len = instance_nonce_len;
  if (er_crypto_hash(crypto, g_app_node_domain, (UINTN)(sizeof(g_app_node_domain) - 1u),
                     spans, 4u, &app_node_hash) == 0u) {
    return 0;
  }

  er_app_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->abi_version = ER_APP_ABI_VERSION;
  out_identity->app_object_id = *app_object_id;
  out_identity->manifest_hash = *manifest_hash;
  out_identity->admission_id = *admission_id;
  er_app_copy(out_identity->instance_nonce, instance_nonce, ER_APP_INSTANCE_NONCE_LEN);
  er_app_copy(out_identity->app_node_id.bytes, app_node_hash.bytes, ER_NODE_ID_LEN);
  return 1;
}

UINT8 er_app_prepare_ipc_route_binding(const ErCryptoProvider* crypto, const ErAppIdentity* source_app,
                                       const ErNodeId* target_node_id, const ErHash* capability_id,
                                       const ErHash* route_hash, UINT64 sequence_base,
                                       UINT32 capability_risk_flags, ErAppIpcRouteBinding* out_binding) {
  UINT8 sequence_be[8];
  ErByteSpan route_spans[5];
  ErByteSpan session_spans[3];

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

  er_app_zero((UINT8*)out_binding, (UINTN)sizeof(*out_binding));
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
  route_spans[0].bytes = source_app->app_node_id.bytes;
  route_spans[0].len = ER_NODE_ID_LEN;
  route_spans[1].bytes = target_node_id->bytes;
  route_spans[1].len = ER_NODE_ID_LEN;
  route_spans[2].bytes = capability_id->bytes;
  route_spans[2].len = ER_HASH_LEN;
  route_spans[3].bytes = route_hash->bytes;
  route_spans[3].len = ER_HASH_LEN;
  route_spans[4].bytes = sequence_be;
  route_spans[4].len = (UINTN)sizeof(sequence_be);
  if (er_crypto_hash(crypto, g_app_route_domain, (UINTN)(sizeof(g_app_route_domain) - 1u),
                     route_spans, 5u, &out_binding->route_binding_id) == 0u) {
    return 0;
  }

  session_spans[0].bytes = source_app->admission_id.bytes;
  session_spans[0].len = ER_HASH_LEN;
  session_spans[1].bytes = out_binding->route_binding_id.bytes;
  session_spans[1].len = ER_HASH_LEN;
  session_spans[2].bytes = source_app->instance_nonce;
  session_spans[2].len = ER_APP_INSTANCE_NONCE_LEN;
  return er_crypto_hash(crypto, g_app_session_domain, (UINTN)(sizeof(g_app_session_domain) - 1u),
                        session_spans, 3u, &out_binding->session_id);
}

UINT8 er_app_prepare_budget(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                            UINT16 app_kind, UINT64 max_cpu_steps, UINT64 max_memory_bytes,
                            UINT64 max_packet_bytes, UINT64 max_storage_bytes,
                            UINT64 max_ipc_sends, UINT64 max_ipc_recvs,
                            ErAppBudget* out_budget) {
  UINT8 fields[2u + (8u * 6u)];
  ErByteSpan spans[4];

  if (crypto == 0 || identity == 0 || out_budget == 0 || identity->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (app_kind != ER_APP_KIND_USER) {
    return 0;
  }
  if (max_cpu_steps == 0u || max_memory_bytes == 0u) {
    return 0;
  }

  er_app_zero((UINT8*)out_budget, (UINTN)sizeof(*out_budget));
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

  fields[0] = (UINT8)((app_kind >> 8) & 0xffu);
  fields[1] = (UINT8)(app_kind & 0xffu);
  er_app_put_be64(&fields[2], max_cpu_steps);
  er_app_put_be64(&fields[10], max_memory_bytes);
  er_app_put_be64(&fields[18], max_packet_bytes);
  er_app_put_be64(&fields[26], max_storage_bytes);
  er_app_put_be64(&fields[34], max_ipc_sends);
  er_app_put_be64(&fields[42], max_ipc_recvs);

  spans[0].bytes = identity->app_object_id.bytes;
  spans[0].len = ER_HASH_LEN;
  spans[1].bytes = identity->manifest_hash.bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = identity->admission_id.bytes;
  spans[2].len = ER_HASH_LEN;
  spans[3].bytes = fields;
  spans[3].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_app_budget_domain, (UINTN)(sizeof(g_app_budget_domain) - 1u),
                        spans, 4u, &out_budget->budget_id);
}

UINT8 er_app_usage_init(const ErAppIdentity* identity, const ErAppBudget* budget, ErAppUsage* out_usage) {
  if (identity == 0 || budget == 0 || out_usage == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER) {
    return 0;
  }

  er_app_zero((UINT8*)out_usage, (UINTN)sizeof(*out_usage));
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
  UINT8 fields[8u + 8u + 8u + 8u];
  ErByteSpan spans[4];

  if (crypto == 0 || identity == 0 || budget == 0 || out_slot == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_cpu_steps == 0u || budget->max_memory_bytes == 0u) {
    return 0;
  }

  er_app_zero((UINT8*)out_slot, (UINTN)sizeof(*out_slot));
  out_slot->abi_version = ER_APP_ABI_VERSION;
  out_slot->admission_id = identity->admission_id;
  out_slot->app_node_id = identity->app_node_id;
  out_slot->deterministic_tick = deterministic_tick;
  out_slot->sequence = sequence;
  out_slot->cpu_step_quanta = budget->max_cpu_steps;
  out_slot->memory_byte_limit = budget->max_memory_bytes;

  er_app_put_be64(&fields[0], deterministic_tick);
  er_app_put_be64(&fields[8], sequence);
  er_app_put_be64(&fields[16], out_slot->cpu_step_quanta);
  er_app_put_be64(&fields[24], out_slot->memory_byte_limit);
  spans[0].bytes = identity->app_node_id.bytes;
  spans[0].len = ER_NODE_ID_LEN;
  spans[1].bytes = identity->admission_id.bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = budget->budget_id.bytes;
  spans[2].len = ER_HASH_LEN;
  spans[3].bytes = fields;
  spans[3].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_app_schedule_domain, (UINTN)(sizeof(g_app_schedule_domain) - 1u),
                        spans, 4u, &out_slot->slot_id);
}

UINT8 er_app_prepare_launch_allocation(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                       const ErAppBudget* budget, UINT64 executor_memory_base,
                                       UINT64 executor_memory_len, ErAppLaunchAllocation* out_allocation) {
  UINT8 fields[8u + 8u + 8u + 8u];
  ErByteSpan spans[4];

  if (crypto == 0 || identity == 0 || budget == 0 || out_allocation == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_memory_bytes == 0u ||
      executor_memory_base == 0u || executor_memory_len != budget->max_memory_bytes) {
    return 0;
  }

  er_app_zero((UINT8*)out_allocation, (UINTN)sizeof(*out_allocation));
  out_allocation->abi_version = ER_APP_ABI_VERSION;
  out_allocation->admission_id = identity->admission_id;
  out_allocation->budget_id = budget->budget_id;
  out_allocation->app_node_id = identity->app_node_id;
  out_allocation->executor_memory_base = executor_memory_base;
  out_allocation->executor_memory_len = executor_memory_len;
  out_allocation->app_address_base = ER_APP_ADDRESS_BASE;
  out_allocation->app_address_len = budget->max_memory_bytes;

  er_app_put_be64(&fields[0], executor_memory_base);
  er_app_put_be64(&fields[8], executor_memory_len);
  er_app_put_be64(&fields[16], out_allocation->app_address_base);
  er_app_put_be64(&fields[24], out_allocation->app_address_len);
  spans[0].bytes = identity->app_node_id.bytes;
  spans[0].len = ER_NODE_ID_LEN;
  spans[1].bytes = identity->admission_id.bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = budget->budget_id.bytes;
  spans[2].len = ER_HASH_LEN;
  spans[3].bytes = fields;
  spans[3].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_app_launch_allocation_domain,
                        (UINTN)(sizeof(g_app_launch_allocation_domain) - 1u),
                        spans, 4u, &out_allocation->allocation_id);
}

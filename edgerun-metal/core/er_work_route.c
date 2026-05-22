#include "er_work_route.h"
#include "er_credential.h"
#include "er_mem.h"

/*
 * Purpose: bind C relay forwarding to the same admitted-route and transit-proof model as edgerun-work.
 * Intention: avoid transport-specific authority; memory, Ethernet, and VirtIO all forward the same admitted bytes.
 */

static const UINT8 g_admitted_route_domain[] = "edgerun:v1:work:admitted-capability-route";
static const UINT8 g_admission_hash_domain[] = "edgerun:c:v1:work:admission";
static const UINT8 g_ordered_message_domain[] = "edgerun:v1:work:ordered-message";
static const UINT8 g_packet_transit_domain[] = "edgerun:v1:work:packet-transit";
static const UINT8 g_route_challenge_domain[] =
    "edgerun:c:v1:work:route-challenge";
static const UINT8 g_route_start_proof_domain[] =
    "edgerun:c:v1:work:route-start-proof";

enum {
  ER_WORK_ROUTE_U16_BYTES = 2u,
  ER_WORK_ROUTE_U64_BYTES = 8u,
  ER_WORK_ROUTE_BYTE_BITS = 8u,
  ER_WORK_ROUTE_BYTE_MASK = 0xffu,
  ER_WORK_ADMISSION_FIELD_BYTES = ER_WORK_ROUTE_U16_BYTES +
                                  (ER_WORK_ROUTE_U64_BYTES * 3u),
  ER_WORK_ROUTE_FIELD_BYTES = (ER_WORK_ROUTE_U16_BYTES * 4u) +
                              (ER_WORK_ROUTE_U64_BYTES * 2u),
  ER_WORK_ORDERED_FIELD_BYTES = ER_WORK_ROUTE_U64_BYTES,
  ER_WORK_TRANSIT_FIELD_BYTES = ER_WORK_ROUTE_U64_BYTES,
  ER_WORK_ADMISSION_HASH_SPAN_COUNT = 6u,
  ER_WORK_ADMISSION_HASH_NODE_SPAN = 0u,
  ER_WORK_ADMISSION_HASH_REQUEST_SPAN = 1u,
  ER_WORK_ADMISSION_HASH_ROUTE_SPAN = 2u,
  ER_WORK_ADMISSION_HASH_CHANNEL_SPAN = 3u,
  ER_WORK_ADMISSION_HASH_RELAY_PATH_SPAN = 4u,
  ER_WORK_ADMISSION_HASH_FIELDS_SPAN = 5u,
  ER_WORK_ADMITTED_ROUTE_SPAN_COUNT = 12u,
  ER_WORK_ADMITTED_REQUEST_SPAN = 0u,
  ER_WORK_ADMITTED_ADMISSION_SPAN = 1u,
  ER_WORK_ADMITTED_USER_SPAN = 2u,
  ER_WORK_ADMITTED_SOURCE_SPAN = 3u,
  ER_WORK_ADMITTED_TARGET_SPAN = 4u,
  ER_WORK_ADMITTED_RELAY_SPAN = 5u,
  ER_WORK_ADMITTED_CHANNEL_SPAN = 6u,
  ER_WORK_ADMITTED_PATH_SPAN = 7u,
  ER_WORK_ADMITTED_ADMISSION_ROUTE_SPAN = 8u,
  ER_WORK_ADMITTED_TARGET_ROUTE_SPAN = 9u,
  ER_WORK_ADMITTED_POLICY_SPAN = 10u,
  ER_WORK_ADMITTED_FIELDS_SPAN = 11u,
  ER_WORK_ORDERED_SPAN_COUNT = 7u,
  ER_WORK_ORDERED_CHANNEL_SPAN = 0u,
  ER_WORK_ORDERED_FROM_SPAN = 1u,
  ER_WORK_ORDERED_TO_SPAN = 2u,
  ER_WORK_ORDERED_SEQUENCE_SPAN = 3u,
  ER_WORK_ORDERED_PREVIOUS_SPAN = 4u,
  ER_WORK_ORDERED_ROUTE_SPAN = 5u,
  ER_WORK_ORDERED_PACKET_SPAN = 6u,
  ER_WORK_TRANSIT_SPAN_COUNT = 8u,
  ER_WORK_TRANSIT_RELAY_SPAN = 0u,
  ER_WORK_TRANSIT_FROM_SPAN = 1u,
  ER_WORK_TRANSIT_TO_SPAN = 2u,
  ER_WORK_TRANSIT_CHANNEL_SPAN = 3u,
  ER_WORK_TRANSIT_ROUTE_SPAN = 4u,
  ER_WORK_TRANSIT_PACKET_SPAN = 5u,
  ER_WORK_TRANSIT_SEQUENCE_SPAN = 6u,
  ER_WORK_TRANSIT_PREVIOUS_SPAN = 7u,
  ER_WORK_EPOCH_FIELD_BYTES = ER_WORK_ROUTE_U64_BYTES * 4u,
  ER_WORK_ROUTE_CHALLENGE_FIELD_BYTES = ER_WORK_EPOCH_FIELD_BYTES * 2u,
  ER_WORK_ROUTE_CHALLENGE_SPAN_COUNT = 7u,
  ER_WORK_ROUTE_CHALLENGE_ROUTE_SPAN = 0u,
  ER_WORK_ROUTE_CHALLENGE_REQUEST_SPAN = 1u,
  ER_WORK_ROUTE_CHALLENGE_ADMISSION_SPAN = 2u,
  ER_WORK_ROUTE_CHALLENGE_WORKER_SPAN = 3u,
  ER_WORK_ROUTE_CHALLENGE_RELAY_SPAN = 4u,
  ER_WORK_ROUTE_CHALLENGE_PATH_SPAN = 5u,
  ER_WORK_ROUTE_CHALLENGE_FIELDS_SPAN = 6u,
  ER_WORK_ROUTE_START_PROOF_FIELD_BYTES = ER_WORK_EPOCH_FIELD_BYTES,
  ER_WORK_ROUTE_START_PROOF_SPAN_COUNT = 6u,
  ER_WORK_ROUTE_START_PROOF_CHALLENGE_SPAN = 0u,
  ER_WORK_ROUTE_START_PROOF_ROUTE_SPAN = 1u,
  ER_WORK_ROUTE_START_PROOF_WORKER_SPAN = 2u,
  ER_WORK_ROUTE_START_PROOF_RELAY_SPAN = 3u,
  ER_WORK_ROUTE_START_PROOF_IDENTITY_SPAN = 4u,
  ER_WORK_ROUTE_START_PROOF_FIELDS_SPAN = 5u,
  ER_WORK_CAPABILITY_RISK_KNOWN_MASK = ER_CAPABILITY_RISK_LOCALITY_AUTHORITY |
                                       ER_CAPABILITY_RISK_UNSEALED_TRANSPORT |
                                       ER_CAPABILITY_RISK_PLAINTEXT_DURABLE |
                                       ER_CAPABILITY_RISK_RAW_DEVICE |
                                       ER_CAPABILITY_RISK_HOST_PRIVILEGE
};

static void er_work_put_be(UINT8* dst, UINT64 value, UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_WORK_ROUTE_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_WORK_ROUTE_BYTE_MASK);
  }
}

static void er_work_put_be16(UINT8* dst, UINT16 value) {
  er_work_put_be(dst, value, ER_WORK_ROUTE_U16_BYTES);
}

static void er_work_put_be64(UINT8* dst, UINT64 value) {
  er_work_put_be(dst, value, ER_WORK_ROUTE_U64_BYTES);
}

static void er_work_put_epoch_stamp(UINT8* dst, er_clock_epoch_stamp_t stamp) {
  er_work_put_be64(dst, stamp.era);
  dst += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(dst, stamp.epoch);
  dst += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(dst, stamp.slot);
  dst += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(dst, stamp.tick);
}

static UINT8 er_work_capability_kind_valid(UINT16 kind) {
  switch (kind) {
    case ER_CAPABILITY_PACKET_REQUEST:
    case ER_CAPABILITY_PACKET_INVOKE:
    case ER_CAPABILITY_PACKET_EVENT:
    case ER_CAPABILITY_PACKET_CLOSE:
      return 1;
    default:
      return 0;
  }
}

static UINT8 er_work_capability_operation_valid(UINT16 operation) {
  switch (operation) {
    case ER_WORK_TYPE_CAPABILITY_REQUEST:
    case ER_WORK_TYPE_CAPABILITY_INVOKE:
    case ER_WORK_TYPE_CAPABILITY_EVENT:
    case ER_WORK_TYPE_CAPABILITY_CLOSE:
      return 1;
    default:
      return 0;
  }
}

static UINT8 er_work_capability_content_valid(UINT16 content_type) {
  switch (content_type) {
    case ER_CAPABILITY_CONTENT_OPAQUE:
    case ER_CAPABILITY_CONTENT_CONTROL:
    case ER_CAPABILITY_CONTENT_VIDEO:
    case ER_CAPABILITY_CONTENT_AUDIO:
    case ER_CAPABILITY_CONTENT_INPUT:
    case ER_CAPABILITY_CONTENT_RENDER:
    case ER_CAPABILITY_CONTENT_OBJECT:
      return 1;
    default:
      return 0;
  }
}

static UINT8 er_work_capability_risk_flags_valid(UINT32 risk_flags) {
  return (UINT8)((risk_flags & ~ER_WORK_CAPABILITY_RISK_KNOWN_MASK) == 0u);
}

static UINT8 er_work_endpoint_valid(const ErChannelEndpoint* endpoint) {
  if (endpoint == 0 || endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind == 0u ||
      endpoint->address_len > ER_CHANNEL_ADDRESS_MAX ||
      endpoint->label_len > ER_CHANNEL_LABEL_MAX ||
      er_hash_nonzero(&endpoint->channel_id) == 0u) {
    return 0;
  }
  return 1;
}

static UINT8 er_work_relay_path_valid(const ErWorkAdmission* admission) {
  UINT16 i;

  if (admission == 0 || admission->relay_count == 0u ||
      admission->relay_count > ER_ROUTE_RELAY_MAX) {
    return 0;
  }
  for (i = 0u; i < admission->relay_count; ++i) {
    if (er_node_id_nonzero(&admission->relay_path[i]) == 0u) {
      return 0;
    }
  }
  return 1;
}

static UINT8 er_work_relay_in_admission(const ErWorkAdmission* admission,
                                        const ErNodeId* relay_node_id) {
  UINT16 i;

  if (er_work_relay_path_valid(admission) == 0u || relay_node_id == 0) {
    return 0;
  }
  for (i = 0u; i < admission->relay_count; ++i) {
    if (er_node_id_equal(&admission->relay_path[i], relay_node_id) != 0u) {
      return 1;
    }
  }
  return 0;
}

static UINT8 er_work_admitted_route_valid(const ErAdmittedRoute* route) {
  if (route == 0 ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      route->relay_count == 0u ||
      route->relay_count > ER_ROUTE_RELAY_MAX ||
      route->role == 0u ||
      route->department == 0u ||
      route->work_type == 0u ||
      er_hash_nonzero(&route->route_id) == 0u ||
      er_hash_nonzero(&route->request_hash) == 0u ||
      er_hash_nonzero(&route->admission_hash) == 0u ||
      er_credential_valid(&route->user) == 0u ||
      er_node_id_nonzero(&route->source_node_id) == 0u ||
      er_node_id_nonzero(&route->target_node_id) == 0u ||
      er_node_id_nonzero(&route->relay_node_id) == 0u ||
      er_hash_nonzero(&route->channel_id) == 0u ||
      er_hash_nonzero(&route->admission_route_commitment) == 0u ||
      er_hash_nonzero(&route->target_route_commitment) == 0u ||
      er_hash_nonzero(&route->policy_hash) == 0u ||
      route->admitted_budget == 0u ||
      route->valid_until_ms == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_work_hash_admission(const ErCryptoProvider* crypto,
                                    const ErWorkAdmission* admission,
                                    ErHash* out_hash) {
  UINT8 fields[ER_WORK_ADMISSION_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_WORK_ADMISSION_HASH_SPAN_COUNT];

  if (crypto == 0 || admission == 0 || out_hash == 0 ||
      admission->abi_version != ER_WORK_ABI_VERSION ||
      admission->admission_node.abi_version != ER_WORK_ABI_VERSION ||
      admission->admission_node.role != ER_NODE_ROLE_ADMISSION ||
      er_credential_valid(&admission->user) == 0u ||
      er_credential_valid(&admission->admission_node.identity) == 0u ||
      er_hash_nonzero(&admission->admission_id) == 0u ||
      er_hash_nonzero(&admission->request_hash) == 0u ||
      er_hash_nonzero(&admission->route_commitment) == 0u ||
      er_work_endpoint_valid(&admission->channel) == 0u ||
      er_work_relay_path_valid(admission) == 0u ||
      admission->admitted_budget == 0u) {
    return 0;
  }

  er_work_put_be16(cursor, admission->relay_count);
  cursor += ER_WORK_ROUTE_U16_BYTES;
  er_work_put_be64(cursor, admission->admitted_budget);
  cursor += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(cursor, admission->sequence);
  cursor += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(cursor, admission->valid_until_ms);

  spans[ER_WORK_ADMISSION_HASH_NODE_SPAN].bytes = (const UINT8*)&admission->admission_node;
  spans[ER_WORK_ADMISSION_HASH_NODE_SPAN].len = (UINTN)sizeof(admission->admission_node);
  spans[ER_WORK_ADMISSION_HASH_REQUEST_SPAN].bytes = admission->request_hash.bytes;
  spans[ER_WORK_ADMISSION_HASH_REQUEST_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMISSION_HASH_ROUTE_SPAN].bytes = admission->route_commitment.bytes;
  spans[ER_WORK_ADMISSION_HASH_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMISSION_HASH_CHANNEL_SPAN].bytes = (const UINT8*)&admission->channel;
  spans[ER_WORK_ADMISSION_HASH_CHANNEL_SPAN].len = (UINTN)sizeof(admission->channel);
  spans[ER_WORK_ADMISSION_HASH_RELAY_PATH_SPAN].bytes =
      (const UINT8*)admission->relay_path;
  spans[ER_WORK_ADMISSION_HASH_RELAY_PATH_SPAN].len =
      (UINTN)admission->relay_count * (UINTN)sizeof(admission->relay_path[0]);
  spans[ER_WORK_ADMISSION_HASH_FIELDS_SPAN].bytes = fields;
  spans[ER_WORK_ADMISSION_HASH_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_admission_hash_domain,
                        (UINTN)(sizeof(g_admission_hash_domain) - 1u),
                        spans, ER_WORK_ADMISSION_HASH_SPAN_COUNT, out_hash);
}

static UINT8 er_work_route_challenge_hash(const ErCryptoProvider* crypto,
                                          const ErAdmittedRoute* route,
                                          er_clock_epoch_stamp_t issued_at,
                                          er_clock_epoch_stamp_t valid_until,
                                          ErHash* out_hash) {
  UINT8 fields[ER_WORK_ROUTE_CHALLENGE_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_WORK_ROUTE_CHALLENGE_SPAN_COUNT];

  if (crypto == 0 ||
      er_work_admitted_route_valid(route) == 0u ||
      out_hash == 0 ||
      er_clock_stamp_compare(issued_at, valid_until) >= 0) {
    return 0u;
  }

  er_work_put_epoch_stamp(cursor, issued_at);
  cursor += ER_WORK_EPOCH_FIELD_BYTES;
  er_work_put_epoch_stamp(cursor, valid_until);

  spans[ER_WORK_ROUTE_CHALLENGE_ROUTE_SPAN].bytes = route->route_id.bytes;
  spans[ER_WORK_ROUTE_CHALLENGE_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ROUTE_CHALLENGE_REQUEST_SPAN].bytes = route->request_hash.bytes;
  spans[ER_WORK_ROUTE_CHALLENGE_REQUEST_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ROUTE_CHALLENGE_ADMISSION_SPAN].bytes =
      route->admission_hash.bytes;
  spans[ER_WORK_ROUTE_CHALLENGE_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ROUTE_CHALLENGE_WORKER_SPAN].bytes =
      route->source_node_id.bytes;
  spans[ER_WORK_ROUTE_CHALLENGE_WORKER_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ROUTE_CHALLENGE_RELAY_SPAN].bytes =
      route->relay_node_id.bytes;
  spans[ER_WORK_ROUTE_CHALLENGE_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ROUTE_CHALLENGE_PATH_SPAN].bytes =
      (const UINT8*)route->relay_path;
  spans[ER_WORK_ROUTE_CHALLENGE_PATH_SPAN].len =
      (UINTN)route->relay_count * (UINTN)sizeof(route->relay_path[0]);
  spans[ER_WORK_ROUTE_CHALLENGE_FIELDS_SPAN].bytes = fields;
  spans[ER_WORK_ROUTE_CHALLENGE_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto,
                        g_route_challenge_domain,
                        (UINTN)(sizeof(g_route_challenge_domain) - 1u),
                        spans,
                        ER_WORK_ROUTE_CHALLENGE_SPAN_COUNT,
                        out_hash);
}

static UINT8 er_work_route_start_proof_hash(const ErCryptoProvider* crypto,
                                            const ErWorkRouteChallenge* challenge,
                                            const ErCredential* worker_identity,
                                            er_clock_epoch_stamp_t started_at,
                                            ErHash* out_hash) {
  UINT8 fields[ER_WORK_ROUTE_START_PROOF_FIELD_BYTES];
  ErByteSpan spans[ER_WORK_ROUTE_START_PROOF_SPAN_COUNT];

  if (crypto == 0 ||
      challenge == 0 ||
      worker_identity == 0 ||
      out_hash == 0 ||
      challenge->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&challenge->challenge_id) == 0u ||
      er_hash_nonzero(&challenge->route_id) == 0u ||
      er_node_id_nonzero(&challenge->worker_node_id) == 0u ||
      er_node_id_nonzero(&challenge->relay_node_id) == 0u ||
      er_credential_valid(worker_identity) == 0u ||
      er_clock_stamp_compare(started_at, challenge->issued_at) < 0 ||
      er_clock_stamp_compare(started_at, challenge->valid_until) >= 0) {
    return 0u;
  }

  er_work_put_epoch_stamp(fields, started_at);
  spans[ER_WORK_ROUTE_START_PROOF_CHALLENGE_SPAN].bytes =
      challenge->challenge_id.bytes;
  spans[ER_WORK_ROUTE_START_PROOF_CHALLENGE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ROUTE_START_PROOF_ROUTE_SPAN].bytes =
      challenge->route_id.bytes;
  spans[ER_WORK_ROUTE_START_PROOF_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ROUTE_START_PROOF_WORKER_SPAN].bytes =
      challenge->worker_node_id.bytes;
  spans[ER_WORK_ROUTE_START_PROOF_WORKER_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ROUTE_START_PROOF_RELAY_SPAN].bytes =
      challenge->relay_node_id.bytes;
  spans[ER_WORK_ROUTE_START_PROOF_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ROUTE_START_PROOF_IDENTITY_SPAN].bytes =
      (const UINT8*)worker_identity;
  spans[ER_WORK_ROUTE_START_PROOF_IDENTITY_SPAN].len =
      (UINTN)sizeof(*worker_identity);
  spans[ER_WORK_ROUTE_START_PROOF_FIELDS_SPAN].bytes = fields;
  spans[ER_WORK_ROUTE_START_PROOF_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto,
                        g_route_start_proof_domain,
                        (UINTN)(sizeof(g_route_start_proof_domain) - 1u),
                        spans,
                        ER_WORK_ROUTE_START_PROOF_SPAN_COUNT,
                        out_hash);
}

static UINT8 er_work_admitted_route_id(const ErCryptoProvider* crypto,
                                       const ErAdmittedRoute* route,
                                       ErHash* out_route_id) {
  UINT8 fields[ER_WORK_ROUTE_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_WORK_ADMITTED_ROUTE_SPAN_COUNT];

  if (crypto == 0 || route == 0 || out_route_id == 0 ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      route->relay_count == 0u || route->relay_count > ER_ROUTE_RELAY_MAX ||
      er_credential_valid(&route->user) == 0u ||
      er_hash_nonzero(&route->request_hash) == 0u ||
      er_hash_nonzero(&route->admission_hash) == 0u ||
      er_node_id_nonzero(&route->source_node_id) == 0u ||
      er_node_id_nonzero(&route->target_node_id) == 0u ||
      er_node_id_nonzero(&route->relay_node_id) == 0u ||
      er_hash_nonzero(&route->channel_id) == 0u ||
      er_hash_nonzero(&route->admission_route_commitment) == 0u ||
      er_hash_nonzero(&route->target_route_commitment) == 0u ||
      er_hash_nonzero(&route->policy_hash) == 0u ||
      route->admitted_budget == 0u) {
    return 0;
  }

  er_work_put_be16(cursor, route->role);
  cursor += ER_WORK_ROUTE_U16_BYTES;
  er_work_put_be16(cursor, route->department);
  cursor += ER_WORK_ROUTE_U16_BYTES;
  er_work_put_be16(cursor, route->work_type);
  cursor += ER_WORK_ROUTE_U16_BYTES;
  er_work_put_be16(cursor, route->relay_count);
  cursor += ER_WORK_ROUTE_U16_BYTES;
  er_work_put_be64(cursor, route->admitted_budget);
  cursor += ER_WORK_ROUTE_U64_BYTES;
  er_work_put_be64(cursor, route->valid_until_ms);

  spans[ER_WORK_ADMITTED_REQUEST_SPAN].bytes = route->request_hash.bytes;
  spans[ER_WORK_ADMITTED_REQUEST_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_ADMISSION_SPAN].bytes = route->admission_hash.bytes;
  spans[ER_WORK_ADMITTED_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_USER_SPAN].bytes = (const UINT8*)&route->user;
  spans[ER_WORK_ADMITTED_USER_SPAN].len = (UINTN)sizeof(route->user);
  spans[ER_WORK_ADMITTED_SOURCE_SPAN].bytes = route->source_node_id.bytes;
  spans[ER_WORK_ADMITTED_SOURCE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ADMITTED_TARGET_SPAN].bytes = route->target_node_id.bytes;
  spans[ER_WORK_ADMITTED_TARGET_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ADMITTED_RELAY_SPAN].bytes = route->relay_node_id.bytes;
  spans[ER_WORK_ADMITTED_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ADMITTED_CHANNEL_SPAN].bytes = route->channel_id.bytes;
  spans[ER_WORK_ADMITTED_CHANNEL_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_PATH_SPAN].bytes = (const UINT8*)route->relay_path;
  spans[ER_WORK_ADMITTED_PATH_SPAN].len =
      (UINTN)route->relay_count * (UINTN)sizeof(route->relay_path[0]);
  spans[ER_WORK_ADMITTED_ADMISSION_ROUTE_SPAN].bytes =
      route->admission_route_commitment.bytes;
  spans[ER_WORK_ADMITTED_ADMISSION_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_TARGET_ROUTE_SPAN].bytes =
      route->target_route_commitment.bytes;
  spans[ER_WORK_ADMITTED_TARGET_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_POLICY_SPAN].bytes = route->policy_hash.bytes;
  spans[ER_WORK_ADMITTED_POLICY_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ADMITTED_FIELDS_SPAN].bytes = fields;
  spans[ER_WORK_ADMITTED_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_admitted_route_domain,
                        (UINTN)(sizeof(g_admitted_route_domain) - 1u),
                        spans, ER_WORK_ADMITTED_ROUTE_SPAN_COUNT, out_route_id);
}

UINT8 er_work_admitted_route_from_admission(const ErCryptoProvider* crypto,
                                            const ErWorkRequest* request,
                                            const ErWorkAdmission* admission,
                                            const ErNodeId* source_node_id,
                                            const ErNodeId* relay_node_id,
                                            UINT16 target_role,
                                            ErAdmittedRoute* out_route) {
  ErHash admission_hash;

  if (crypto == 0 || request == 0 || admission == 0 || source_node_id == 0 ||
      relay_node_id == 0 || out_route == 0 ||
      request->abi_version != ER_WORK_ABI_VERSION ||
      admission->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&request->request_id) == 0u ||
      er_hash_nonzero(&admission->request_hash) == 0u ||
      er_credential_equal(&request->user, &admission->user) == 0u ||
      admission->valid_until_ms > request->valid_until_ms ||
      er_work_relay_path_valid(admission) == 0u ||
      er_node_id_equal(&admission->relay_path[0], relay_node_id) == 0u ||
      er_work_relay_in_admission(admission, &request->recipient) != 0u ||
      er_node_id_nonzero(source_node_id) == 0u ||
      er_node_id_nonzero(&request->recipient) == 0u ||
      target_role == 0u) {
    return 0;
  }
  if (er_work_hash_admission(crypto, admission, &admission_hash) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_route, (UINTN)sizeof(*out_route));
  out_route->abi_version = ER_WORK_ABI_VERSION;
  out_route->role = target_role;
  out_route->request_hash = admission->request_hash;
  out_route->admission_hash = admission_hash;
  out_route->user = request->user;
  out_route->source_node_id = *source_node_id;
  out_route->target_node_id = request->recipient;
  out_route->relay_node_id = *relay_node_id;
  out_route->channel_id = admission->channel.channel_id;
  out_route->relay_count = admission->relay_count;
  out_route->department = request->department;
  out_route->work_type = request->work_type;
  out_route->admission_route_commitment = admission->route_commitment;
  out_route->target_route_commitment = admission->route_commitment;
  out_route->policy_hash = admission->policy_hash;
  out_route->admitted_budget = admission->admitted_budget;
  out_route->valid_until_ms = admission->valid_until_ms;
  er_mem_copy((UINT8*)out_route->relay_path, (const UINT8*)admission->relay_path,
              (UINTN)admission->relay_count * (UINTN)sizeof(out_route->relay_path[0]));
  return er_work_admitted_route_id(crypto, out_route, &out_route->route_id);
}

UINT8 er_work_verify_channel_envelope_for_route(const ErChannelEnvelopeHeader* envelope,
                                                const ErAdmittedRoute* route) {
  if (envelope == 0 || route == 0 ||
      envelope->abi_version != ER_WORK_ABI_VERSION ||
      route->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_equal(&envelope->channel_id, &route->channel_id) == 0u ||
      er_node_id_equal(&envelope->from, &route->source_node_id) == 0u ||
      er_node_id_equal(&envelope->to, &route->target_node_id) == 0u ||
      er_hash_equal(&envelope->route_hash, &route->target_route_commitment) == 0u ||
      er_hash_nonzero(&envelope->packet_hash) == 0u ||
      envelope->packet_kind != route->work_type || envelope->sequence == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_work_prepare_relay_forward_intent(const ErWorkAdmission* admission,
                                           const ErChannelEnvelopeHeader* envelope,
                                           const ErNodeId* current_relay_node_id,
                                           const ErChannelEndpoint* from_endpoint,
                                           const ErChannelEndpoint* to_endpoint,
                                           ErRelayForwardIntent* out_intent) {
  if (admission == 0 || envelope == 0 || current_relay_node_id == 0 ||
      from_endpoint == 0 || to_endpoint == 0 || out_intent == 0 ||
      admission->abi_version != ER_WORK_ABI_VERSION ||
      envelope->abi_version != ER_WORK_ABI_VERSION ||
      er_work_endpoint_valid(from_endpoint) == 0u ||
      er_work_endpoint_valid(to_endpoint) == 0u ||
      er_work_relay_in_admission(admission, current_relay_node_id) == 0u ||
      er_hash_equal(&envelope->channel_id, &admission->channel.channel_id) == 0u ||
      er_hash_equal(&to_endpoint->channel_id, &admission->channel.channel_id) == 0u ||
      er_hash_equal(&envelope->route_hash, &admission->route_commitment) == 0u ||
      er_hash_nonzero(&envelope->packet_hash) == 0u ||
      envelope->sequence == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_intent, (UINTN)sizeof(*out_intent));
  out_intent->abi_version = ER_WORK_ABI_VERSION;
  out_intent->relay_node_id = *current_relay_node_id;
  out_intent->source_node_id = envelope->from;
  out_intent->target_node_id = envelope->to;
  out_intent->from = *from_endpoint;
  out_intent->to = *to_endpoint;
  out_intent->route_hash = envelope->route_hash;
  out_intent->packet_hash = envelope->packet_hash;
  out_intent->sequence = envelope->sequence;
  return 1;
}

UINT8 er_work_ordered_message_input_hash(const ErCryptoProvider* crypto,
                                         const ErChannelEnvelopeHeader* envelope,
                                         ErHash* out_hash) {
  UINT8 sequence_be[ER_WORK_ORDERED_FIELD_BYTES];
  ErByteSpan spans[ER_WORK_ORDERED_SPAN_COUNT];

  if (crypto == 0 || envelope == 0 || out_hash == 0 ||
      envelope->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&envelope->channel_id) == 0u ||
      er_node_id_nonzero(&envelope->from) == 0u ||
      er_node_id_nonzero(&envelope->to) == 0u ||
      er_hash_nonzero(&envelope->route_hash) == 0u ||
      er_hash_nonzero(&envelope->packet_hash) == 0u ||
      envelope->sequence == 0u) {
    return 0;
  }

  er_work_put_be64(sequence_be, envelope->sequence);
  spans[ER_WORK_ORDERED_CHANNEL_SPAN].bytes = envelope->channel_id.bytes;
  spans[ER_WORK_ORDERED_CHANNEL_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ORDERED_FROM_SPAN].bytes = envelope->from.bytes;
  spans[ER_WORK_ORDERED_FROM_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ORDERED_TO_SPAN].bytes = envelope->to.bytes;
  spans[ER_WORK_ORDERED_TO_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_ORDERED_SEQUENCE_SPAN].bytes = sequence_be;
  spans[ER_WORK_ORDERED_SEQUENCE_SPAN].len = (UINTN)sizeof(sequence_be);
  spans[ER_WORK_ORDERED_PREVIOUS_SPAN].bytes = envelope->previous_message_hash.bytes;
  spans[ER_WORK_ORDERED_PREVIOUS_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ORDERED_ROUTE_SPAN].bytes = envelope->route_hash.bytes;
  spans[ER_WORK_ORDERED_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_ORDERED_PACKET_SPAN].bytes = envelope->packet_hash.bytes;
  spans[ER_WORK_ORDERED_PACKET_SPAN].len = ER_HASH_LEN;
  return er_crypto_hash(crypto, g_ordered_message_domain,
                        (UINTN)(sizeof(g_ordered_message_domain) - 1u),
                        spans, ER_WORK_ORDERED_SPAN_COUNT, out_hash);
}

UINT8 er_work_prepare_relay_transit_hop(const ErCryptoProvider* crypto,
                                        const ErRelayForwardIntent* intent,
                                        const ErHash* input_hash,
                                        const ErHash* previous_transit_hash,
                                        UINT16 hop_index,
                                        ErRelayTransitHop* out_hop) {
  UINT8 sequence_be[ER_WORK_TRANSIT_FIELD_BYTES];
  ErByteSpan spans[ER_WORK_TRANSIT_SPAN_COUNT];

  if (crypto == 0 || intent == 0 || input_hash == 0 ||
      previous_transit_hash == 0 || out_hop == 0 ||
      intent->abi_version != ER_WORK_ABI_VERSION ||
      er_node_id_nonzero(&intent->relay_node_id) == 0u ||
      er_node_id_nonzero(&intent->source_node_id) == 0u ||
      er_node_id_nonzero(&intent->target_node_id) == 0u ||
      er_hash_nonzero(&intent->to.channel_id) == 0u ||
      er_hash_nonzero(&intent->route_hash) == 0u ||
      er_hash_nonzero(&intent->packet_hash) == 0u ||
      er_hash_nonzero(input_hash) == 0u ||
      intent->sequence == 0u) {
    return 0;
  }

  er_work_put_be64(sequence_be, intent->sequence);
  spans[ER_WORK_TRANSIT_RELAY_SPAN].bytes = intent->relay_node_id.bytes;
  spans[ER_WORK_TRANSIT_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_TRANSIT_FROM_SPAN].bytes = intent->source_node_id.bytes;
  spans[ER_WORK_TRANSIT_FROM_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_TRANSIT_TO_SPAN].bytes = intent->target_node_id.bytes;
  spans[ER_WORK_TRANSIT_TO_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_WORK_TRANSIT_CHANNEL_SPAN].bytes = intent->to.channel_id.bytes;
  spans[ER_WORK_TRANSIT_CHANNEL_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_TRANSIT_ROUTE_SPAN].bytes = intent->route_hash.bytes;
  spans[ER_WORK_TRANSIT_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_TRANSIT_PACKET_SPAN].bytes = intent->packet_hash.bytes;
  spans[ER_WORK_TRANSIT_PACKET_SPAN].len = ER_HASH_LEN;
  spans[ER_WORK_TRANSIT_SEQUENCE_SPAN].bytes = sequence_be;
  spans[ER_WORK_TRANSIT_SEQUENCE_SPAN].len = (UINTN)sizeof(sequence_be);
  spans[ER_WORK_TRANSIT_PREVIOUS_SPAN].bytes = previous_transit_hash->bytes;
  spans[ER_WORK_TRANSIT_PREVIOUS_SPAN].len = ER_HASH_LEN;

  er_mem_zero((UINT8*)out_hop, (UINTN)sizeof(*out_hop));
  out_hop->abi_version = ER_WORK_ABI_VERSION;
  out_hop->hop_index = hop_index;
  out_hop->relay_node_id = intent->relay_node_id;
  out_hop->from = intent->source_node_id;
  out_hop->to = intent->target_node_id;
  out_hop->channel_id = intent->to.channel_id;
  out_hop->route_hash = intent->route_hash;
  out_hop->input_hash = *input_hash;
  out_hop->packet_hash = intent->packet_hash;
  out_hop->sequence = intent->sequence;
  out_hop->previous_transit_hash = *previous_transit_hash;
  return er_crypto_hash(crypto, g_packet_transit_domain,
                        (UINTN)(sizeof(g_packet_transit_domain) - 1u),
                        spans, ER_WORK_TRANSIT_SPAN_COUNT,
                        &out_hop->transit_hash);
}

UINT8 er_work_prepare_relay_accounting_claim(const ErRelayTransitHop* hop,
                                             const ErHash* request_hash,
                                             const ErHash* admission_hash,
                                             UINT64 packet_bytes,
                                             UINT64 unit_price,
                                             UINT64 receipt_base,
                                             ErRelayAccountingClaim* out_claim) {
  UINT64 units;
  UINT64 amount;

  if (hop == 0 || request_hash == 0 || admission_hash == 0 || out_claim == 0 ||
      hop->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&hop->transit_hash) == 0u ||
      er_hash_nonzero(request_hash) == 0u ||
      er_hash_nonzero(admission_hash) == 0u ||
      packet_bytes == 0u || unit_price == 0u) {
    return 0;
  }

  units = (packet_bytes + (ER_WORK_COST_UNIT_BYTES - 1u)) / ER_WORK_COST_UNIT_BYTES;
  if (units == 0u || units > (~0ull / unit_price)) {
    return 0;
  }
  amount = units * unit_price;
  if (amount > (~0ull - receipt_base)) {
    return 0;
  }

  er_mem_zero((UINT8*)out_claim, (UINTN)sizeof(*out_claim));
  out_claim->abi_version = ER_WORK_ABI_VERSION;
  out_claim->relay_node_id = hop->relay_node_id;
  out_claim->request_hash = *request_hash;
  out_claim->admission_hash = *admission_hash;
  out_claim->transit_hash = hop->transit_hash;
  out_claim->packet_bytes = packet_bytes;
  out_claim->units_used = units;
  out_claim->unit_price = unit_price;
  out_claim->receipt_base = receipt_base;
  out_claim->total_claim = amount + receipt_base;
  out_claim->sequence = hop->sequence;
  return 1;
}

UINT8 er_work_route_challenge_prepare(const ErCryptoProvider* crypto,
                                      const ErAdmittedRoute* route,
                                      er_clock_epoch_stamp_t issued_at,
                                      er_clock_epoch_stamp_t valid_until,
                                      ErWorkRouteChallenge* out_challenge) {
  ErHash challenge_id;

  if (out_challenge == 0 ||
      er_work_route_challenge_hash(crypto,
                                   route,
                                   issued_at,
                                   valid_until,
                                   &challenge_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_challenge, (UINTN)sizeof(*out_challenge));
  out_challenge->abi_version = ER_WORK_ABI_VERSION;
  out_challenge->challenge_id = challenge_id;
  out_challenge->route_id = route->route_id;
  out_challenge->request_hash = route->request_hash;
  out_challenge->admission_hash = route->admission_hash;
  out_challenge->worker_node_id = route->source_node_id;
  out_challenge->relay_node_id = route->relay_node_id;
  out_challenge->issued_at = issued_at;
  out_challenge->valid_until = valid_until;
  return 1u;
}

UINT8 er_work_route_challenge_valid_at(const ErWorkRouteChallenge* challenge,
                                       er_clock_epoch_stamp_t now) {
  if (challenge == 0 ||
      challenge->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(&challenge->challenge_id) == 0u ||
      er_hash_nonzero(&challenge->route_id) == 0u ||
      er_hash_nonzero(&challenge->request_hash) == 0u ||
      er_hash_nonzero(&challenge->admission_hash) == 0u ||
      er_node_id_nonzero(&challenge->worker_node_id) == 0u ||
      er_node_id_nonzero(&challenge->relay_node_id) == 0u ||
      er_clock_stamp_compare(challenge->issued_at, challenge->valid_until) >= 0 ||
      er_clock_stamp_compare(now, challenge->issued_at) < 0 ||
      er_clock_stamp_compare(now, challenge->valid_until) >= 0) {
    return 0u;
  }
  return 1u;
}

UINT8 er_work_route_start_proof_sign(const ErCryptoProvider* crypto,
                                     const ErWorkRouteChallenge* challenge,
                                     const ErCredential* worker_identity,
                                     er_clock_epoch_stamp_t started_at,
                                     ErWorkRouteStartProof* out_proof) {
  ErHash proof_hash;
  ErByteSpan preimage;

  if (out_proof == 0 ||
      er_work_route_start_proof_hash(crypto,
                                     challenge,
                                     worker_identity,
                                     started_at,
                                     &proof_hash) == 0u) {
    return 0u;
  }
  preimage.bytes = proof_hash.bytes;
  preimage.len = ER_HASH_LEN;

  er_mem_zero((UINT8*)out_proof, (UINTN)sizeof(*out_proof));
  out_proof->abi_version = ER_WORK_ABI_VERSION;
  out_proof->proof_hash = proof_hash;
  out_proof->challenge_id = challenge->challenge_id;
  out_proof->route_id = challenge->route_id;
  out_proof->worker_node_id = challenge->worker_node_id;
  out_proof->relay_node_id = challenge->relay_node_id;
  out_proof->started_at = started_at;
  if (er_crypto_sign(crypto, &preimage, &out_proof->signature) == 0u ||
      er_credential_equal(&out_proof->signature.identity, worker_identity) == 0u) {
    er_mem_zero((UINT8*)out_proof, (UINTN)sizeof(*out_proof));
    return 0u;
  }
  return 1u;
}

UINT8 er_work_route_start_proof_verify(const ErCryptoProvider* crypto,
                                       const ErWorkRouteChallenge* challenge,
                                       const ErWorkRouteStartProof* proof,
                                       er_clock_epoch_stamp_t now) {
  ErHash expected_hash;
  ErByteSpan preimage;

  if (crypto == 0 ||
      challenge == 0 ||
      proof == 0 ||
      proof->abi_version != ER_WORK_ABI_VERSION ||
      er_work_route_challenge_valid_at(challenge, now) == 0u ||
      er_hash_equal(&proof->challenge_id, &challenge->challenge_id) == 0u ||
      er_hash_equal(&proof->route_id, &challenge->route_id) == 0u ||
      er_node_id_equal(&proof->worker_node_id, &challenge->worker_node_id) == 0u ||
      er_node_id_equal(&proof->relay_node_id, &challenge->relay_node_id) == 0u ||
      er_work_route_start_proof_hash(crypto,
                                     challenge,
                                     &proof->signature.identity,
                                     proof->started_at,
                                     &expected_hash) == 0u ||
      er_hash_equal(&proof->proof_hash, &expected_hash) == 0u) {
    return 0u;
  }
  preimage.bytes = expected_hash.bytes;
  preimage.len = ER_HASH_LEN;
  return er_crypto_verify(crypto,
                          &proof->signature.identity,
                          &preimage,
                          &proof->signature);
}

UINT8 er_work_capability_envelope_header_valid(const ErCapabilityEnvelopeHeader* header) {
  if (header == 0 ||
      header->abi_version != ER_WORK_ABI_VERSION ||
      er_work_capability_kind_valid(header->kind) == 0u ||
      er_work_capability_operation_valid(header->operation) == 0u ||
      er_work_capability_content_valid(header->content_type) == 0u ||
      er_work_capability_risk_flags_valid(header->risk_flags) == 0u ||
      er_hash_nonzero(&header->session_id) == 0u ||
      er_hash_nonzero(&header->invocation_id) == 0u ||
      er_hash_nonzero(&header->capability_id) == 0u ||
      er_node_id_nonzero(&header->source_node_id) == 0u ||
      er_node_id_nonzero(&header->target_node_id) == 0u ||
      header->sequence == 0u ||
      header->timestamp_ms == 0u ||
      er_hash_nonzero(&header->payload_hash) == 0u ||
      header->payload_len == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_work_prepare_capability_envelope_header(UINT16 kind,
                                                 UINT16 operation,
                                                 UINT16 content_type,
                                                 UINT32 risk_flags,
                                                 const ErHash* session_id,
                                                 const ErHash* invocation_id,
                                                 const ErHash* capability_id,
                                                 const ErNodeId* source_node_id,
                                                 const ErNodeId* target_node_id,
                                                 UINT64 sequence,
                                                 UINT64 timestamp_ms,
                                                 const ErHash* payload_hash,
                                                 UINT32 payload_len,
                                                 ErCapabilityEnvelopeHeader* out_header) {
  if (out_header == 0 ||
      session_id == 0 ||
      invocation_id == 0 ||
      capability_id == 0 ||
      source_node_id == 0 ||
      target_node_id == 0 ||
      payload_hash == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_header, (UINTN)sizeof(*out_header));
  out_header->abi_version = ER_WORK_ABI_VERSION;
  out_header->kind = kind;
  out_header->operation = operation;
  out_header->content_type = content_type;
  out_header->risk_flags = risk_flags;
  out_header->session_id = *session_id;
  out_header->invocation_id = *invocation_id;
  out_header->capability_id = *capability_id;
  out_header->source_node_id = *source_node_id;
  out_header->target_node_id = *target_node_id;
  out_header->sequence = sequence;
  out_header->timestamp_ms = timestamp_ms;
  out_header->payload_hash = *payload_hash;
  out_header->payload_len = payload_len;
  return er_work_capability_envelope_header_valid(out_header);
}

#ifndef ER_WORK_H
#define ER_WORK_H

/*
 * Purpose: define EdgeRun admitted-work and relay concepts for the C runtime.
 * Intention: keep authority explicit; the bare metal executor is only a relay node.
 */

#include "er_types.h"

#define ER_WORK_ABI_VERSION 1u

#define ER_HASH_LEN 32u
#define ER_NODE_ID_LEN 32u
#define ER_IDENTITY_MATERIAL_MAX 64u
#define ER_PUBLIC_KEY_LEN 32u
#define ER_P256_PUBLIC_KEY_LEN 64u
#define ER_SIGNATURE_LEN 64u
#define ER_CHANNEL_ADDRESS_MAX 64u
#define ER_CHANNEL_LABEL_MAX 32u
#define ER_ROUTE_RELAY_MAX 8u
#define ER_WORK_COST_UNIT_BYTES 1024u

#define ER_NODE_ROLE_RELAY 1u
#define ER_NODE_ROLE_BARE_METAL_EXECUTOR ER_NODE_ROLE_RELAY
#define ER_NODE_ROLE_STORAGE 2u
#define ER_NODE_ROLE_COMPUTE 3u
#define ER_NODE_ROLE_ADMISSION 4u
#define ER_NODE_ROLE_MESSAGE 5u
#define ER_NODE_ROLE_CAPABILITY 6u
#define ER_NODE_ROLE_NOTARY 7u
#define ER_NODE_ROLE_VERIFIER 8u
#define ER_NODE_ROLE_APP 9u

#define ER_WORK_TYPE_MESSAGE_DELIVER 1u
#define ER_WORK_TYPE_OBJECT_STORE 2u
#define ER_WORK_TYPE_OBJECT_RETRIEVE 3u
#define ER_WORK_TYPE_OBJECT_PIN 4u
#define ER_WORK_TYPE_COMPUTE_RUN 5u
#define ER_WORK_TYPE_CAPABILITY_REQUEST 11u
#define ER_WORK_TYPE_CAPABILITY_INVOKE 12u
#define ER_WORK_TYPE_CAPABILITY_EVENT 13u
#define ER_WORK_TYPE_CAPABILITY_CLOSE 14u

#define ER_DEPARTMENT_ADMISSION 1u
#define ER_DEPARTMENT_RELAY 2u
#define ER_DEPARTMENT_MESSAGE 3u
#define ER_DEPARTMENT_STORAGE 4u
#define ER_DEPARTMENT_RETRIEVAL 5u
#define ER_DEPARTMENT_COMPUTE 6u
#define ER_DEPARTMENT_CAPABILITY 7u
#define ER_DEPARTMENT_NOTARY 8u
#define ER_DEPARTMENT_VERIFICATION 9u

#define ER_CHANNEL_KIND_MEMORY 1u
#define ER_CHANNEL_KIND_FIRMWARE_UDP 10u
#define ER_CHANNEL_KIND_NATIVE_ETH 11u
#define ER_CHANNEL_KIND_VIRTIO_QUEUE 12u
#define ER_CHANNEL_KIND_TCP_IP 13u
#define ER_CHANNEL_KIND_WIFI_OPEN_L2 14u

#define ER_CAPABILITY_PACKET_REQUEST 1u
#define ER_CAPABILITY_PACKET_INVOKE 2u
#define ER_CAPABILITY_PACKET_EVENT 3u
#define ER_CAPABILITY_PACKET_CLOSE 4u

#define ER_CAPABILITY_CONTENT_OPAQUE 0u
#define ER_CAPABILITY_CONTENT_CONTROL 1u
#define ER_CAPABILITY_CONTENT_VIDEO 2u
#define ER_CAPABILITY_CONTENT_AUDIO 3u
#define ER_CAPABILITY_CONTENT_INPUT 4u
#define ER_CAPABILITY_CONTENT_RENDER 5u
#define ER_CAPABILITY_CONTENT_OBJECT 6u

#define ER_CAPABILITY_RISK_NONE 0x00000000u
#define ER_CAPABILITY_RISK_LOCALITY_AUTHORITY 0x00000001u
#define ER_CAPABILITY_RISK_UNSEALED_TRANSPORT 0x00000002u
#define ER_CAPABILITY_RISK_PLAINTEXT_DURABLE 0x00000004u
#define ER_CAPABILITY_RISK_RAW_DEVICE 0x00000008u
#define ER_CAPABILITY_RISK_HOST_PRIVILEGE 0x00000010u

#define ER_IDENTITY_TYPE_PUBLIC_KEY 1u
#define ER_IDENTITY_TYPE_HASH 2u

#define ER_IDENTITY_BACKING_ED25519 1u
#define ER_IDENTITY_BACKING_P256 2u
#define ER_IDENTITY_BACKING_TPM_P256 3u
#define ER_IDENTITY_BACKING_HASH 4u
#define ER_IDENTITY_BACKING_EPHEMERAL_HASH 5u

typedef struct {
  UINT8 bytes[ER_HASH_LEN];
} ErHash;

typedef struct {
  UINT8 bytes[ER_NODE_ID_LEN];
} ErNodeId;

static inline UINT8 er_hash_equal(const ErHash* left, const ErHash* right) {
  UINTN i;

  if (left == 0 || right == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_HASH_LEN; ++i) {
    if (left->bytes[i] != right->bytes[i]) {
      return 0u;
    }
  }
  return 1u;
}

static inline UINT8 er_hash_nonzero(const ErHash* value) {
  UINTN i;

  if (value == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_HASH_LEN; ++i) {
    if (value->bytes[i] != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static inline UINT8 er_node_id_equal(const ErNodeId* left, const ErNodeId* right) {
  UINTN i;

  if (left == 0 || right == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_NODE_ID_LEN; ++i) {
    if (left->bytes[i] != right->bytes[i]) {
      return 0u;
    }
  }
  return 1u;
}

static inline UINT8 er_node_id_nonzero(const ErNodeId* value) {
  UINTN i;

  if (value == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_NODE_ID_LEN; ++i) {
    if (value->bytes[i] != 0u) {
      return 1u;
    }
  }
  return 0u;
}

typedef struct {
  UINT16 identity_type;
  UINT16 backing_type;
  UINT16 material_len;
  UINT16 reserved;
  UINT8 material[ER_IDENTITY_MATERIAL_MAX];
} ErIdentity;

typedef struct {
  UINT16 algorithm;
  UINT16 signature_len;
  ErIdentity identity;
  UINT8 signature[ER_SIGNATURE_LEN];
} ErWorkSignature;

typedef struct {
  UINT16 abi_version;
  UINT16 role;
  ErNodeId node_id;
  ErIdentity identity;
} ErNodeIdentity;

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  ErHash channel_id;
  UINT16 address_len;
  UINT16 label_len;
  UINT8 address[ER_CHANNEL_ADDRESS_MAX];
  char label[ER_CHANNEL_LABEL_MAX];
} ErChannelEndpoint;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeId relay_node_id;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  ErChannelEndpoint from;
  ErChannelEndpoint to;
  ErHash route_hash;
  ErHash packet_hash;
  UINT64 sequence;
} ErRelayForwardIntent;

typedef struct {
  UINT16 abi_version;
  UINT16 work_type;
  UINT16 department;
  UINT16 reserved;
  ErHash request_id;
  ErIdentity user;
  UINT64 user_sequence;
  ErNodeId recipient;
  ErHash payload_hash;
  ErHash input_root;
  UINT64 max_total_cost;
  UINT64 valid_until_ms;
  ErWorkSignature signature;
} ErWorkRequest;

typedef struct {
  UINT16 abi_version;
  UINT16 relay_count;
  ErHash admission_id;
  ErIdentity user;
  ErNodeIdentity admission_node;
  ErHash request_hash;
  ErHash route_commitment;
  ErChannelEndpoint channel;
  ErNodeId relay_path[ER_ROUTE_RELAY_MAX];
  UINT64 admitted_budget;
  ErHash policy_hash;
  UINT64 sequence;
  UINT64 valid_until_ms;
  ErWorkSignature signature;
} ErWorkAdmission;

typedef struct {
  UINT16 abi_version;
  UINT16 packet_kind;
  ErHash channel_id;
  ErNodeId from;
  ErNodeId to;
  ErHash route_hash;
  ErHash packet_hash;
  UINT64 sequence;
  ErHash previous_message_hash;
} ErChannelEnvelopeHeader;

typedef struct {
  UINT16 abi_version;
  UINT16 hop_index;
  ErNodeId relay_node_id;
  ErNodeId from;
  ErNodeId to;
  ErHash channel_id;
  ErHash route_hash;
  ErHash input_hash;
  ErHash packet_hash;
  UINT64 sequence;
  ErHash previous_transit_hash;
  ErHash transit_hash;
} ErRelayTransitHop;

typedef struct {
  UINT16 abi_version;
  UINT16 role;
  ErHash route_id;
  ErHash request_hash;
  ErHash admission_hash;
  ErIdentity user;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  ErNodeId relay_node_id;
  ErHash channel_id;
  UINT16 relay_count;
  UINT16 department;
  UINT16 work_type;
  ErHash admission_route_commitment;
  ErHash target_route_commitment;
  ErHash policy_hash;
  UINT64 admitted_budget;
  UINT64 valid_until_ms;
  ErNodeId relay_path[ER_ROUTE_RELAY_MAX];
} ErAdmittedRoute;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeId relay_node_id;
  ErHash request_hash;
  ErHash admission_hash;
  ErHash transit_hash;
  UINT64 packet_bytes;
  UINT64 units_used;
  UINT64 unit_price;
  UINT64 receipt_base;
  UINT64 total_claim;
  UINT64 sequence;
} ErRelayAccountingClaim;

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  UINT16 operation;
  UINT16 content_type;
  UINT32 risk_flags;
  ErHash session_id;
  ErHash invocation_id;
  ErHash capability_id;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  UINT64 sequence;
  UINT64 timestamp_ms;
  ErHash payload_hash;
  UINT32 payload_len;
} ErCapabilityEnvelopeHeader;

#endif

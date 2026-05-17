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
#define ER_PUBLIC_KEY_LEN 32u
#define ER_SIGNATURE_LEN 64u
#define ER_CHANNEL_ADDRESS_MAX 64u
#define ER_CHANNEL_LABEL_MAX 32u
#define ER_ROUTE_RELAY_MAX 8u

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
#define ER_CHANNEL_KIND_DEVICE_RING 11u

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

typedef struct {
  UINT8 bytes[ER_HASH_LEN];
} ErHash;

typedef struct {
  UINT8 bytes[ER_NODE_ID_LEN];
} ErNodeId;

typedef struct {
  UINT8 bytes[ER_PUBLIC_KEY_LEN];
} ErPublicKey;

typedef struct {
  UINT16 algorithm;
  UINT16 signature_len;
  ErPublicKey public_key;
  UINT8 signature[ER_SIGNATURE_LEN];
} ErWorkSignature;

typedef struct {
  UINT16 abi_version;
  UINT16 role;
  ErNodeId node_id;
  ErPublicKey public_key;
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
  ErPublicKey user;
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
  ErPublicKey user;
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

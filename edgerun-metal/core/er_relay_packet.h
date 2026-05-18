#ifndef ER_RELAY_PACKET_H
#define ER_RELAY_PACKET_H

/*
 * Purpose: define the byte-level packet contract used by relay-capable programs.
 * Intention: make relay traffic accountable before it leaves an admitted memory outbox.
 */

#include "er_app.h"

#define ER_RELAY_PACKET_ABI_VERSION 1u
#define ER_RELAY_PACKET_KIND_BYTES 1u
#define ER_RELAY_PACKET_HEADER_LEN 232u

typedef struct {
  UINT16 abi_version;
  UINT16 packet_kind;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  ErHash admission_id;
  ErHash token_id;
  ErHash route_hash;
  UINT64 sequence;
  UINT64 cost_per_byte;
  UINT64 max_total_cost;
  UINT32 payload_len;
  ErHash payload_hash;
} ErRelayPacketHeader;

UINT8 er_relay_packet_prepare(UINT8* packet, UINT32 packet_capacity,
                              const ErNodeId* source_node_id,
                              const ErNodeId* target_node_id,
                              const ErHash* admission_id,
                              const ErHash* token_id,
                              const ErHash* route_hash,
                              UINT64 sequence,
                              UINT64 cost_per_byte,
                              UINT64 max_total_cost,
                              const ErHash* payload_hash,
                              const UINT8* payload,
                              UINT32 payload_len,
                              UINT32* out_packet_len);
UINT8 er_relay_packet_valid(const UINT8* packet, UINT32 packet_len);
UINT8 er_relay_packet_decode_header(const UINT8* packet, UINT32 packet_len,
                                    ErRelayPacketHeader* out_header);
UINT8 er_relay_packet_authorized_for_app(const UINT8* packet, UINT32 packet_len,
                                         const ErAppUsage* usage,
                                         const ErAppBudget* budget);
UINT8 er_relay_packet_payload(const UINT8* packet, UINT32 packet_len,
                              const UINT8** out_payload, UINT32* out_payload_len);

#endif

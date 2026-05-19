#ifndef ER_NODE_CONTROL_H
#define ER_NODE_CONTROL_H

/*
 * Purpose: define admission-time node control records for relay assignment.
 * Intention: mirror edgerun-work NodeAvailable/RelayAssignment/NodeHeartbeat
 * without binding the protocol to TCP, serial text, or host services.
 */

#include "er_work.h"

#define ER_NODE_CONTROL_ABI_VERSION ER_WORK_ABI_VERSION
#define ER_NODE_CONTROL_DEFAULT_HEARTBEAT_SECS 10u

typedef struct {
  ErNodeId relay_node_id;
  ErChannelEndpoint channel;
} ErRelayEndpoint;

typedef struct {
  UINT16 abi_version;
  UINT16 relay_endpoint_present;
  ErNodeIdentity node;
  ErRelayEndpoint relay_endpoint;
  UINT64 sequence;
  UINT64 unix_ms;
  UINT64 heartbeat_secs;
  ErHash log_head;
  ErWorkSignature signature;
} ErNodeAvailable;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeIdentity node;
  UINT64 sequence;
  UINT64 unix_ms;
  ErHash connection_hash;
  ErHash log_head;
  ErWorkSignature signature;
} ErNodeHeartbeat;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeId node_id;
  ErRelayEndpoint relay;
  ErNodeIdentity assigned_by;
  UINT64 sequence;
  UINT64 valid_until_ms;
  ErWorkSignature signature;
} ErRelayAssignment;

UINT8 er_relay_endpoint_prepare(const ErNodeId* relay_node_id,
                                const ErChannelEndpoint* channel,
                                ErRelayEndpoint* out_endpoint);
UINT8 er_relay_endpoint_valid(const ErRelayEndpoint* endpoint);
UINT8 er_node_available_prepare(const ErNodeIdentity* node,
                                const ErRelayEndpoint* relay_endpoint,
                                UINT64 sequence,
                                UINT64 unix_ms,
                                UINT64 heartbeat_secs,
                                const ErHash* log_head,
                                const ErWorkSignature* signature,
                                ErNodeAvailable* out_available);
UINT8 er_node_available_shape_valid(const ErNodeAvailable* available);
UINT8 er_node_heartbeat_prepare(const ErNodeIdentity* node,
                                UINT64 sequence,
                                UINT64 unix_ms,
                                const ErHash* connection_hash,
                                const ErHash* log_head,
                                const ErWorkSignature* signature,
                                ErNodeHeartbeat* out_heartbeat);
UINT8 er_node_heartbeat_shape_valid(const ErNodeHeartbeat* heartbeat);
UINT8 er_relay_assignment_prepare(const ErNodeId* node_id,
                                  const ErRelayEndpoint* relay,
                                  const ErNodeIdentity* assigned_by,
                                  UINT64 sequence,
                                  UINT64 valid_until_ms,
                                  const ErWorkSignature* signature,
                                  ErRelayAssignment* out_assignment);
UINT8 er_relay_assignment_shape_valid(const ErRelayAssignment* assignment);

#endif

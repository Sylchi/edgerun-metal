#include "er_node_control.h"
#include "er_credential.h"
#include "er_mem.h"
#include "er_wifi_l2.h"

/*
 * Purpose: validate relay-admission control records before transport code uses them.
 * Intention: keep relay assignment as explicit protocol state, not inferred
 * from whichever carrier happened to move the first bytes.
 */

static UINT8 er_node_identity_shape_valid(const ErNodeIdentity* node) {
  if (node == 0 ||
      node->abi_version != ER_WORK_ABI_VERSION ||
      node->role == 0u ||
      er_node_id_nonzero(&node->node_id) == 0u ||
      er_credential_valid(&node->identity) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_node_control_channel_valid(const ErChannelEndpoint* channel) {
  if (channel == 0 ||
      channel->abi_version != ER_WORK_ABI_VERSION ||
      channel->kind == 0u ||
      er_hash_nonzero(&channel->channel_id) == 0u ||
      channel->address_len > ER_CHANNEL_ADDRESS_MAX ||
      channel->label_len == 0u ||
      channel->label_len > ER_CHANNEL_LABEL_MAX) {
    return 0u;
  }
  switch (channel->kind) {
    case ER_CHANNEL_KIND_MEMORY:
      return (UINT8)(channel->address_len == 0u);
    case ER_CHANNEL_KIND_FIRMWARE_UDP:
    case ER_CHANNEL_KIND_NATIVE_ETH:
    case ER_CHANNEL_KIND_VIRTIO_QUEUE:
    case ER_CHANNEL_KIND_TCP_IP:
      return (UINT8)(channel->address_len != 0u);
    case ER_CHANNEL_KIND_WIFI_OPEN_L2:
      return er_wifi_l2_channel_endpoint_valid(channel);
    default:
      return 0u;
  }
}

UINT8 er_relay_endpoint_prepare(const ErNodeId* relay_node_id,
                                const ErChannelEndpoint* channel,
                                ErRelayEndpoint* out_endpoint) {
  if (relay_node_id == 0 ||
      channel == 0 ||
      out_endpoint == 0 ||
      er_node_id_nonzero(relay_node_id) == 0u ||
      er_node_control_channel_valid(channel) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->relay_node_id = *relay_node_id;
  out_endpoint->channel = *channel;
  return 1u;
}

UINT8 er_relay_endpoint_valid(const ErRelayEndpoint* endpoint) {
  return (UINT8)(endpoint != 0 &&
                 er_node_id_nonzero(&endpoint->relay_node_id) != 0u &&
                 er_node_control_channel_valid(&endpoint->channel) != 0u);
}

UINT8 er_node_available_prepare(const ErNodeIdentity* node,
                                const ErRelayEndpoint* relay_endpoint,
                                UINT64 sequence,
                                UINT64 unix_ms,
                                UINT64 heartbeat_secs,
                                const ErHash* log_head,
                                const ErWorkSignature* signature,
                                ErNodeAvailable* out_available) {
  if (node == 0 ||
      log_head == 0 ||
      signature == 0 ||
      out_available == 0 ||
      er_node_identity_shape_valid(node) == 0u ||
      sequence == 0u ||
      heartbeat_secs == 0u ||
      (node->role == ER_NODE_ROLE_RELAY &&
       er_relay_endpoint_valid(relay_endpoint) == 0u) ||
      (node->role != ER_NODE_ROLE_RELAY && relay_endpoint != 0)) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_available, (UINTN)sizeof(*out_available));
  out_available->abi_version = ER_NODE_CONTROL_ABI_VERSION;
  out_available->node = *node;
  if (relay_endpoint != 0) {
    out_available->relay_endpoint_present = 1u;
    out_available->relay_endpoint = *relay_endpoint;
  }
  out_available->sequence = sequence;
  out_available->unix_ms = unix_ms;
  out_available->heartbeat_secs = heartbeat_secs;
  out_available->log_head = *log_head;
  out_available->signature = *signature;
  return 1u;
}

UINT8 er_node_available_shape_valid(const ErNodeAvailable* available) {
  if (available == 0 ||
      available->abi_version != ER_NODE_CONTROL_ABI_VERSION ||
      er_node_identity_shape_valid(&available->node) == 0u ||
      available->sequence == 0u ||
      available->heartbeat_secs == 0u) {
    return 0u;
  }
  if (available->node.role == ER_NODE_ROLE_RELAY) {
    return (UINT8)(available->relay_endpoint_present == 1u &&
                   er_relay_endpoint_valid(&available->relay_endpoint) != 0u &&
                   er_node_id_equal(&available->node.node_id,
                                    &available->relay_endpoint.relay_node_id) != 0u);
  }
  return (UINT8)(available->relay_endpoint_present == 0u);
}

UINT8 er_node_heartbeat_prepare(const ErNodeIdentity* node,
                                UINT64 sequence,
                                UINT64 unix_ms,
                                const ErHash* connection_hash,
                                const ErHash* log_head,
                                const ErWorkSignature* signature,
                                ErNodeHeartbeat* out_heartbeat) {
  if (node == 0 ||
      connection_hash == 0 ||
      log_head == 0 ||
      signature == 0 ||
      out_heartbeat == 0 ||
      er_node_identity_shape_valid(node) == 0u ||
      er_hash_nonzero(connection_hash) == 0u ||
      sequence == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_heartbeat, (UINTN)sizeof(*out_heartbeat));
  out_heartbeat->abi_version = ER_NODE_CONTROL_ABI_VERSION;
  out_heartbeat->node = *node;
  out_heartbeat->sequence = sequence;
  out_heartbeat->unix_ms = unix_ms;
  out_heartbeat->connection_hash = *connection_hash;
  out_heartbeat->log_head = *log_head;
  out_heartbeat->signature = *signature;
  return 1u;
}

UINT8 er_node_heartbeat_shape_valid(const ErNodeHeartbeat* heartbeat) {
  return (UINT8)(heartbeat != 0 &&
                 heartbeat->abi_version == ER_NODE_CONTROL_ABI_VERSION &&
                 heartbeat->reserved == 0u &&
                 er_node_identity_shape_valid(&heartbeat->node) != 0u &&
                 heartbeat->sequence != 0u &&
                 er_hash_nonzero(&heartbeat->connection_hash) != 0u);
}

UINT8 er_relay_assignment_prepare(const ErNodeId* node_id,
                                  const ErRelayEndpoint* relay,
                                  const ErNodeIdentity* assigned_by,
                                  UINT64 sequence,
                                  UINT64 valid_until_ms,
                                  const ErWorkSignature* signature,
                                  ErRelayAssignment* out_assignment) {
  if (node_id == 0 ||
      relay == 0 ||
      assigned_by == 0 ||
      signature == 0 ||
      out_assignment == 0 ||
      er_node_id_nonzero(node_id) == 0u ||
      er_relay_endpoint_valid(relay) == 0u ||
      er_node_identity_shape_valid(assigned_by) == 0u ||
      assigned_by->role != ER_NODE_ROLE_ADMISSION ||
      sequence == 0u ||
      valid_until_ms == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_assignment, (UINTN)sizeof(*out_assignment));
  out_assignment->abi_version = ER_NODE_CONTROL_ABI_VERSION;
  out_assignment->node_id = *node_id;
  out_assignment->relay = *relay;
  out_assignment->assigned_by = *assigned_by;
  out_assignment->sequence = sequence;
  out_assignment->valid_until_ms = valid_until_ms;
  out_assignment->signature = *signature;
  return 1u;
}

UINT8 er_relay_assignment_shape_valid(const ErRelayAssignment* assignment) {
  return (UINT8)(assignment != 0 &&
                 assignment->abi_version == ER_NODE_CONTROL_ABI_VERSION &&
                 assignment->reserved == 0u &&
                 er_node_id_nonzero(&assignment->node_id) != 0u &&
                 er_relay_endpoint_valid(&assignment->relay) != 0u &&
                 er_node_identity_shape_valid(&assignment->assigned_by) != 0u &&
                 assignment->assigned_by.role == ER_NODE_ROLE_ADMISSION &&
                 assignment->sequence != 0u &&
                 assignment->valid_until_ms != 0u);
}

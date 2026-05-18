#include "er_relay_packet.h"
#include "er_mem.h"

/*
 * Purpose: validate serialized relay packets without trusting app-owned memory.
 * Intention: every relay send carries route, admission, token, cost, and payload accounting.
 */

enum {
  ER_RELAY_PACKET_ABI_OFFSET = 0u,
  ER_RELAY_PACKET_KIND_OFFSET = 2u,
  ER_RELAY_PACKET_HEADER_LEN_OFFSET = 4u,
  ER_RELAY_PACKET_SOURCE_OFFSET = 8u,
  ER_RELAY_PACKET_TARGET_OFFSET = ER_RELAY_PACKET_SOURCE_OFFSET + ER_NODE_ID_LEN,
  ER_RELAY_PACKET_ADMISSION_OFFSET = ER_RELAY_PACKET_TARGET_OFFSET + ER_NODE_ID_LEN,
  ER_RELAY_PACKET_TOKEN_OFFSET = ER_RELAY_PACKET_ADMISSION_OFFSET + ER_HASH_LEN,
  ER_RELAY_PACKET_ROUTE_OFFSET = ER_RELAY_PACKET_TOKEN_OFFSET + ER_HASH_LEN,
  ER_RELAY_PACKET_SEQUENCE_OFFSET = ER_RELAY_PACKET_ROUTE_OFFSET + ER_HASH_LEN,
  ER_RELAY_PACKET_COST_PER_BYTE_OFFSET = ER_RELAY_PACKET_SEQUENCE_OFFSET + 8u,
  ER_RELAY_PACKET_MAX_TOTAL_COST_OFFSET = ER_RELAY_PACKET_COST_PER_BYTE_OFFSET + 8u,
  ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET = ER_RELAY_PACKET_MAX_TOTAL_COST_OFFSET + 8u,
  ER_RELAY_PACKET_RESERVED_OFFSET = ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET + 4u,
  ER_RELAY_PACKET_PAYLOAD_HASH_OFFSET = ER_RELAY_PACKET_RESERVED_OFFSET + 4u,
  ER_RELAY_PACKET_U16_BYTES = 2u,
  ER_RELAY_PACKET_U32_BYTES = 4u,
  ER_RELAY_PACKET_U64_BYTES = 8u,
  ER_RELAY_PACKET_U32_BYTE0_OFFSET = 0u,
  ER_RELAY_PACKET_U32_BYTE1_OFFSET = 1u,
  ER_RELAY_PACKET_U32_BYTE2_OFFSET = 2u,
  ER_RELAY_PACKET_U32_BYTE3_OFFSET = 3u,
  ER_RELAY_PACKET_BYTE_BITS = 8u,
  ER_RELAY_PACKET_U8_MASK = 0xffu,
  ER_RELAY_PACKET_U32_MASK = 0xffffffffu
};

static UINT8 er_relay_packet_bytes_equal(const UINT8* left, const UINT8* right, UINT32 len) {
  if (len == 0u) {
    return 0;
  }
  return er_mem_equal(left, right, (UINTN)len);
}

static UINT16 er_relay_packet_read_u16(const UINT8* src) {
  return (UINT16)((UINT16)src[0] | ((UINT16)src[1] << ER_RELAY_PACKET_BYTE_BITS));
}

static UINT32 er_relay_packet_read_u32(const UINT8* src) {
  return (UINT32)src[ER_RELAY_PACKET_U32_BYTE0_OFFSET] |
         ((UINT32)src[ER_RELAY_PACKET_U32_BYTE1_OFFSET] << ER_RELAY_PACKET_BYTE_BITS) |
         ((UINT32)src[ER_RELAY_PACKET_U32_BYTE2_OFFSET] <<
          (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTE2_OFFSET)) |
         ((UINT32)src[ER_RELAY_PACKET_U32_BYTE3_OFFSET] <<
          (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTE3_OFFSET));
}

static UINT64 er_relay_packet_read_u64(const UINT8* src) {
  return (UINT64)er_relay_packet_read_u32(src) |
         ((UINT64)er_relay_packet_read_u32(src + ER_RELAY_PACKET_U32_BYTES) <<
          (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTES));
}

static void er_relay_packet_write_u16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & ER_RELAY_PACKET_U8_MASK);
  dst[1] = (UINT8)((value >> ER_RELAY_PACKET_BYTE_BITS) & ER_RELAY_PACKET_U8_MASK);
}

static void er_relay_packet_write_u32(UINT8* dst, UINT32 value) {
  dst[ER_RELAY_PACKET_U32_BYTE0_OFFSET] = (UINT8)(value & ER_RELAY_PACKET_U8_MASK);
  dst[ER_RELAY_PACKET_U32_BYTE1_OFFSET] = (UINT8)((value >> ER_RELAY_PACKET_BYTE_BITS) & ER_RELAY_PACKET_U8_MASK);
  dst[ER_RELAY_PACKET_U32_BYTE2_OFFSET] =
    (UINT8)((value >> (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTE2_OFFSET)) & ER_RELAY_PACKET_U8_MASK);
  dst[ER_RELAY_PACKET_U32_BYTE3_OFFSET] =
    (UINT8)((value >> (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTE3_OFFSET)) & ER_RELAY_PACKET_U8_MASK);
}

static void er_relay_packet_write_u64(UINT8* dst, UINT64 value) {
  er_relay_packet_write_u32(dst, (UINT32)(value & ER_RELAY_PACKET_U32_MASK));
  er_relay_packet_write_u32(dst + ER_RELAY_PACKET_U32_BYTES,
                            (UINT32)(value >> (ER_RELAY_PACKET_BYTE_BITS * ER_RELAY_PACKET_U32_BYTES)));
}

static UINT8 er_relay_packet_cost_valid(UINT32 payload_len, UINT64 cost_per_byte,
                                        UINT64 max_total_cost) {
  UINT64 total_cost;

  if (payload_len == 0u || cost_per_byte == 0u || max_total_cost == 0u) {
    return 0;
  }
  if ((UINT64)payload_len > (UINT64)(~0ull) / cost_per_byte) {
    return 0;
  }
  total_cost = (UINT64)payload_len * cost_per_byte;
  return (UINT8)(total_cost <= max_total_cost);
}

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
                              UINT32* out_packet_len) {
  UINT32 packet_len = ER_RELAY_PACKET_HEADER_LEN + payload_len;

  if (packet == 0 || source_node_id == 0 || target_node_id == 0 ||
      admission_id == 0 || token_id == 0 || route_hash == 0 ||
      payload_hash == 0 || payload == 0 || out_packet_len == 0) {
    return 0;
  }
  if (packet_len < ER_RELAY_PACKET_HEADER_LEN || packet_capacity < packet_len ||
      er_relay_packet_cost_valid(payload_len, cost_per_byte, max_total_cost) == 0u) {
    return 0;
  }
  if (er_node_id_nonzero(source_node_id) == 0u ||
      er_node_id_nonzero(target_node_id) == 0u ||
      er_hash_nonzero(admission_id) == 0u ||
      er_hash_nonzero(token_id) == 0u ||
      er_hash_nonzero(route_hash) == 0u ||
      er_hash_nonzero(payload_hash) == 0u) {
    return 0;
  }

  er_mem_zero(packet, packet_capacity);
  er_relay_packet_write_u16(packet + ER_RELAY_PACKET_ABI_OFFSET, ER_RELAY_PACKET_ABI_VERSION);
  er_relay_packet_write_u16(packet + ER_RELAY_PACKET_KIND_OFFSET, ER_RELAY_PACKET_KIND_BYTES);
  er_relay_packet_write_u32(packet + ER_RELAY_PACKET_HEADER_LEN_OFFSET, ER_RELAY_PACKET_HEADER_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_SOURCE_OFFSET, source_node_id->bytes, ER_NODE_ID_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_TARGET_OFFSET, target_node_id->bytes, ER_NODE_ID_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_ADMISSION_OFFSET, admission_id->bytes, ER_HASH_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_TOKEN_OFFSET, token_id->bytes, ER_HASH_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_ROUTE_OFFSET, route_hash->bytes, ER_HASH_LEN);
  er_relay_packet_write_u64(packet + ER_RELAY_PACKET_SEQUENCE_OFFSET, sequence);
  er_relay_packet_write_u64(packet + ER_RELAY_PACKET_COST_PER_BYTE_OFFSET, cost_per_byte);
  er_relay_packet_write_u64(packet + ER_RELAY_PACKET_MAX_TOTAL_COST_OFFSET, max_total_cost);
  er_relay_packet_write_u32(packet + ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET, payload_len);
  er_relay_packet_write_u32(packet + ER_RELAY_PACKET_RESERVED_OFFSET, 0u);
  er_mem_copy(packet + ER_RELAY_PACKET_PAYLOAD_HASH_OFFSET, payload_hash->bytes, ER_HASH_LEN);
  er_mem_copy(packet + ER_RELAY_PACKET_HEADER_LEN, payload, payload_len);
  *out_packet_len = packet_len;
  return 1;
}

UINT8 er_relay_packet_valid(const UINT8* packet, UINT32 packet_len) {
  UINT32 header_len;
  UINT32 payload_len;
  UINT32 expected_len;
  UINT64 cost_per_byte;
  UINT64 max_total_cost;

  if (packet == 0 || packet_len < ER_RELAY_PACKET_HEADER_LEN) {
    return 0;
  }
  header_len = er_relay_packet_read_u32(packet + ER_RELAY_PACKET_HEADER_LEN_OFFSET);
  payload_len = er_relay_packet_read_u32(packet + ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET);
  expected_len = ER_RELAY_PACKET_HEADER_LEN + payload_len;
  if (er_relay_packet_read_u16(packet + ER_RELAY_PACKET_ABI_OFFSET) != ER_RELAY_PACKET_ABI_VERSION ||
      er_relay_packet_read_u16(packet + ER_RELAY_PACKET_KIND_OFFSET) != ER_RELAY_PACKET_KIND_BYTES ||
      header_len != ER_RELAY_PACKET_HEADER_LEN ||
      expected_len < ER_RELAY_PACKET_HEADER_LEN || packet_len != expected_len ||
      er_relay_packet_read_u32(packet + ER_RELAY_PACKET_RESERVED_OFFSET) != 0u) {
    return 0;
  }
  if (er_mem_any_nonzero(packet + ER_RELAY_PACKET_SOURCE_OFFSET, ER_NODE_ID_LEN) == 0u ||
      er_mem_any_nonzero(packet + ER_RELAY_PACKET_TARGET_OFFSET, ER_NODE_ID_LEN) == 0u ||
      er_mem_any_nonzero(packet + ER_RELAY_PACKET_ADMISSION_OFFSET, ER_HASH_LEN) == 0u ||
      er_mem_any_nonzero(packet + ER_RELAY_PACKET_TOKEN_OFFSET, ER_HASH_LEN) == 0u ||
      er_mem_any_nonzero(packet + ER_RELAY_PACKET_ROUTE_OFFSET, ER_HASH_LEN) == 0u ||
      er_mem_any_nonzero(packet + ER_RELAY_PACKET_PAYLOAD_HASH_OFFSET, ER_HASH_LEN) == 0u) {
    return 0;
  }
  cost_per_byte = er_relay_packet_read_u64(packet + ER_RELAY_PACKET_COST_PER_BYTE_OFFSET);
  max_total_cost = er_relay_packet_read_u64(packet + ER_RELAY_PACKET_MAX_TOTAL_COST_OFFSET);
  return er_relay_packet_cost_valid(payload_len, cost_per_byte, max_total_cost);
}

UINT8 er_relay_packet_decode_header(const UINT8* packet, UINT32 packet_len,
                                    ErRelayPacketHeader* out_header) {
  if (out_header == 0 || er_relay_packet_valid(packet, packet_len) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_header, (UINTN)sizeof(*out_header));
  out_header->abi_version = er_relay_packet_read_u16(packet + ER_RELAY_PACKET_ABI_OFFSET);
  out_header->packet_kind = er_relay_packet_read_u16(packet + ER_RELAY_PACKET_KIND_OFFSET);
  er_mem_copy(out_header->source_node_id.bytes,
              packet + ER_RELAY_PACKET_SOURCE_OFFSET, ER_NODE_ID_LEN);
  er_mem_copy(out_header->target_node_id.bytes,
              packet + ER_RELAY_PACKET_TARGET_OFFSET, ER_NODE_ID_LEN);
  er_mem_copy(out_header->admission_id.bytes,
              packet + ER_RELAY_PACKET_ADMISSION_OFFSET, ER_HASH_LEN);
  er_mem_copy(out_header->token_id.bytes,
              packet + ER_RELAY_PACKET_TOKEN_OFFSET, ER_HASH_LEN);
  er_mem_copy(out_header->route_hash.bytes,
              packet + ER_RELAY_PACKET_ROUTE_OFFSET, ER_HASH_LEN);
  out_header->sequence = er_relay_packet_read_u64(packet + ER_RELAY_PACKET_SEQUENCE_OFFSET);
  out_header->cost_per_byte =
      er_relay_packet_read_u64(packet + ER_RELAY_PACKET_COST_PER_BYTE_OFFSET);
  out_header->max_total_cost =
      er_relay_packet_read_u64(packet + ER_RELAY_PACKET_MAX_TOTAL_COST_OFFSET);
  out_header->payload_len =
      er_relay_packet_read_u32(packet + ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET);
  er_mem_copy(out_header->payload_hash.bytes,
              packet + ER_RELAY_PACKET_PAYLOAD_HASH_OFFSET, ER_HASH_LEN);
  return 1;
}

UINT8 er_relay_packet_authorized_for_app(const UINT8* packet, UINT32 packet_len,
                                         const ErAppUsage* usage,
                                         const ErAppBudget* budget) {
  if (usage == 0 || budget == 0 ||
      usage->abi_version != ER_APP_ABI_VERSION ||
      budget->abi_version != ER_APP_ABI_VERSION ||
      budget->app_kind != ER_APP_KIND_USER ||
      er_relay_packet_valid(packet, packet_len) == 0u) {
    return 0;
  }
  if (er_relay_packet_bytes_equal(usage->budget_id.bytes, budget->budget_id.bytes,
                                  ER_HASH_LEN) == 0u) {
    return 0;
  }
  if (er_relay_packet_bytes_equal(packet + ER_RELAY_PACKET_SOURCE_OFFSET,
                                  usage->app_node_id.bytes, ER_NODE_ID_LEN) == 0u) {
    return 0;
  }
  if (er_relay_packet_bytes_equal(packet + ER_RELAY_PACKET_ADMISSION_OFFSET,
                                  budget->admission_id.bytes, ER_HASH_LEN) == 0u) {
    return 0;
  }
  return er_relay_packet_bytes_equal(packet + ER_RELAY_PACKET_TOKEN_OFFSET,
                                     budget->budget_id.bytes, ER_HASH_LEN);
}

UINT8 er_relay_packet_payload(const UINT8* packet, UINT32 packet_len,
                              const UINT8** out_payload, UINT32* out_payload_len) {
  if (out_payload == 0 || out_payload_len == 0 ||
      er_relay_packet_valid(packet, packet_len) == 0u) {
    return 0;
  }
  *out_payload = packet + ER_RELAY_PACKET_HEADER_LEN;
  *out_payload_len = er_relay_packet_read_u32(packet + ER_RELAY_PACKET_PAYLOAD_LEN_OFFSET);
  return 1;
}

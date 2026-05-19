#include "er_storage_endpoint.h"
#include "er_mem.h"

/*
 * Purpose: implement storage endpoint capture over admitted object packets.
 * Intention: prove endpoint-side object validation before adding block-device durability.
 */

static const UINT8 g_storage_capture_domain[] = "edgerun:c:v1:storage:endpoint-capture";
static const UINT8 g_storage_sealed_relay_payload_domain[] =
    "edgerun:c:v1:storage:sealed-relay-payload";
static const UINT8 g_storage_route_receipt_domain[] =
    "edgerun:c:v1:storage:route-receipt";

enum {
  ER_STORAGE_U64_BYTES = 8u,
  ER_STORAGE_BYTE_BITS = 8u,
  ER_STORAGE_BYTE_MASK = 0xffu,
  ER_STORAGE_CAPTURE_SPAN_COUNT = 4u,
  ER_STORAGE_CAPTURE_ROUTE_SPAN = 0u,
  ER_STORAGE_CAPTURE_OBJECT_SPAN = 1u,
  ER_STORAGE_CAPTURE_PACKET_SPAN = 2u,
  ER_STORAGE_CAPTURE_PAYLOAD_SPAN = 3u,
  ER_STORAGE_SEALED_RELAY_PAYLOAD_SPAN_COUNT = 1u,
  ER_STORAGE_SEALED_RELAY_PAYLOAD_SPAN = 0u,
  ER_STORAGE_RECEIPT_FIELD_BYTES = ER_STORAGE_U64_BYTES * 6u,
  ER_STORAGE_RECEIPT_SPAN_COUNT = 9u,
  ER_STORAGE_RECEIPT_ROUTE_SPAN = 0u,
  ER_STORAGE_RECEIPT_REQUEST_SPAN = 1u,
  ER_STORAGE_RECEIPT_ADMISSION_SPAN = 2u,
  ER_STORAGE_RECEIPT_RELAY_PAYLOAD_SPAN = 3u,
  ER_STORAGE_RECEIPT_SEALED_OBJECT_SPAN = 4u,
  ER_STORAGE_RECEIPT_TRANSIT_SPAN = 5u,
  ER_STORAGE_RECEIPT_RELAY_NODE_SPAN = 6u,
  ER_STORAGE_RECEIPT_CAPTURE_SEALED_PAYLOAD_SPAN = 7u,
  ER_STORAGE_RECEIPT_FIELDS_SPAN = 8u,
  ER_STORAGE_CACHE_ENTRY_EMPTY = 0u,
  ER_STORAGE_CACHE_ENTRY_FIRST = 0u
};

static void er_storage_endpoint_put_be(UINT8* dst, UINT64 value, UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_STORAGE_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_STORAGE_BYTE_MASK);
  }
}

static void er_storage_endpoint_put_be64(UINT8* dst, UINT64 value) {
  er_storage_endpoint_put_be(dst, value, ER_STORAGE_U64_BYTES);
}

static UINT8 er_storage_endpoint_route_valid(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_STORAGE &&
                 route->department == ER_DEPARTMENT_STORAGE &&
                 route->work_type == ER_WORK_TYPE_OBJECT_RETRIEVE &&
                 er_hash_nonzero(&route->route_id) != 0u &&
                 er_hash_nonzero(&route->target_route_commitment) != 0u &&
                 er_node_id_nonzero(&route->source_node_id) != 0u &&
                 er_node_id_nonzero(&route->target_node_id) != 0u);
}

static UINT8 er_storage_endpoint_relay_header_matches_route(
    const ErRelayPacketHeader* header,
    const ErAdmittedRoute* route) {
  return (UINT8)(header != 0 &&
                 route != 0 &&
                 er_node_id_equal(&header->source_node_id,
                                  &route->source_node_id) != 0u &&
                 er_node_id_equal(&header->target_node_id,
                                  &route->target_node_id) != 0u &&
                 er_hash_equal(&header->admission_id,
                               &route->admission_hash) != 0u &&
                 er_hash_equal(&header->route_hash,
                               &route->target_route_commitment) != 0u);
}

static UINT8 er_storage_endpoint_packet_matches_store(const ErStorageEndpointObjectStore* store,
                                                      const ErVfsObjectPacket* packet) {
  if (store == 0 || packet == 0) {
    return 0u;
  }
  if (store->packet_count == 0u) {
    return 1u;
  }
  return (UINT8)(store->object_len == packet->header.object_len &&
                 store->packet_count == packet->header.packet_count &&
                 er_hash_equal(&store->object_id,
                               &packet->header.object_id) != 0u);
}

static UINT8 er_storage_endpoint_capture_hash(const ErCryptoProvider* crypto,
                                              const ErAdmittedRoute* route,
                                              const ErVfsObjectPacket* packet,
                                              ErHash* out_hash) {
  ErByteSpan spans[ER_STORAGE_CAPTURE_SPAN_COUNT];

  if (crypto == 0 || route == 0 || packet == 0 || out_hash == 0) {
    return 0u;
  }
  spans[ER_STORAGE_CAPTURE_ROUTE_SPAN].bytes = route->route_id.bytes;
  spans[ER_STORAGE_CAPTURE_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_OBJECT_SPAN].bytes = packet->header.object_id.bytes;
  spans[ER_STORAGE_CAPTURE_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_PACKET_SPAN].bytes = packet->header.packet_id.bytes;
  spans[ER_STORAGE_CAPTURE_PACKET_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_CAPTURE_PAYLOAD_SPAN].bytes = packet->bytes;
  spans[ER_STORAGE_CAPTURE_PAYLOAD_SPAN].len = packet->header.bytes_len;
  return er_crypto_hash(crypto, g_storage_capture_domain,
                        (UINTN)(sizeof(g_storage_capture_domain) - 1u),
                        spans, ER_STORAGE_CAPTURE_SPAN_COUNT, out_hash);
}

static UINT8 er_storage_endpoint_route_receipt_hash(
    const ErCryptoProvider* crypto,
    const ErStorageEndpointRouteReceipt* receipt,
    const ErStorageEndpointSealedRelayCapture* capture,
    ErHash* out_hash) {
  UINT8 fields[ER_STORAGE_RECEIPT_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_STORAGE_RECEIPT_SPAN_COUNT];

  if (crypto == 0 || receipt == 0 || capture == 0 || out_hash == 0) {
    return 0u;
  }

  er_storage_endpoint_put_be64(cursor, receipt->sequence);
  cursor += ER_STORAGE_U64_BYTES;
  er_storage_endpoint_put_be64(cursor, receipt->packet_bytes);
  cursor += ER_STORAGE_U64_BYTES;
  er_storage_endpoint_put_be64(cursor, receipt->units_used);
  cursor += ER_STORAGE_U64_BYTES;
  er_storage_endpoint_put_be64(cursor, receipt->unit_price);
  cursor += ER_STORAGE_U64_BYTES;
  er_storage_endpoint_put_be64(cursor, receipt->receipt_base);
  cursor += ER_STORAGE_U64_BYTES;
  er_storage_endpoint_put_be64(cursor, receipt->total_claim);

  spans[ER_STORAGE_RECEIPT_ROUTE_SPAN].bytes = receipt->route_id.bytes;
  spans[ER_STORAGE_RECEIPT_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_REQUEST_SPAN].bytes = receipt->request_hash.bytes;
  spans[ER_STORAGE_RECEIPT_REQUEST_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_ADMISSION_SPAN].bytes = receipt->admission_id.bytes;
  spans[ER_STORAGE_RECEIPT_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_RELAY_PAYLOAD_SPAN].bytes =
      receipt->relay_payload_hash.bytes;
  spans[ER_STORAGE_RECEIPT_RELAY_PAYLOAD_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_SEALED_OBJECT_SPAN].bytes =
      receipt->sealed_object_id.bytes;
  spans[ER_STORAGE_RECEIPT_SEALED_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_TRANSIT_SPAN].bytes = receipt->transit_hash.bytes;
  spans[ER_STORAGE_RECEIPT_TRANSIT_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_RELAY_NODE_SPAN].bytes = receipt->relay_node_id.bytes;
  spans[ER_STORAGE_RECEIPT_RELAY_NODE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_STORAGE_RECEIPT_CAPTURE_SEALED_PAYLOAD_SPAN].bytes =
      capture->sealed_payload_hash.bytes;
  spans[ER_STORAGE_RECEIPT_CAPTURE_SEALED_PAYLOAD_SPAN].len = ER_HASH_LEN;
  spans[ER_STORAGE_RECEIPT_FIELDS_SPAN].bytes = fields;
  spans[ER_STORAGE_RECEIPT_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_storage_route_receipt_domain,
                        (UINTN)(sizeof(g_storage_route_receipt_domain) - 1u),
                        spans, ER_STORAGE_RECEIPT_SPAN_COUNT, out_hash);
}

UINT8 er_storage_endpoint_object_store_init(ErStorageEndpointObjectStore* store,
                                            ErVfsObjectPacket* packets,
                                            UINT32 packet_capacity) {
  if (store == 0 || packets == 0 || packet_capacity == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)store, (UINTN)sizeof(*store));
  er_mem_zero((UINT8*)packets,
              (UINTN)packet_capacity * (UINTN)sizeof(packets[0]));
  store->abi_version = ER_WORK_ABI_VERSION;
  store->packets = packets;
  store->packet_capacity = packet_capacity;
  return 1u;
}

static UINT8 er_storage_endpoint_cache_layout_valid(UINT32 entry_capacity,
                                                    UINT32 packet_capacity,
                                                    UINT32 packet_stride) {
  if (entry_capacity == 0u || packet_capacity == 0u || packet_stride == 0u) {
    return 0u;
  }
  if (entry_capacity > packet_capacity / packet_stride) {
    return 0u;
  }
  return 1u;
}

static ErVfsObjectPacket* er_storage_endpoint_cache_entry_packets(
    const ErStorageEndpointObjectCache* cache,
    const ErStorageEndpointCacheEntry* entry) {
  if (cache == 0 || entry == 0 || cache->packets == 0 ||
      entry->packet_offset >= cache->packet_capacity ||
      entry->packet_count > cache->packet_stride ||
      entry->packet_offset + cache->packet_stride > cache->packet_capacity) {
    return 0;
  }
  return cache->packets + entry->packet_offset;
}

static UINT8 er_storage_endpoint_cache_entry_used(const ErStorageEndpointCacheEntry* entry) {
  return (UINT8)(entry != 0 &&
                 entry->abi_version == ER_WORK_ABI_VERSION &&
                 entry->packet_count != ER_STORAGE_CACHE_ENTRY_EMPTY &&
                 er_hash_nonzero(&entry->object_id) != 0u);
}

static void er_storage_endpoint_cache_clear_entry(ErStorageEndpointObjectCache* cache,
                                                  UINT32 entry_index) {
  UINT32 packet_index;
  UINT32 packet_offset;

  if (cache == 0 || cache->entries == 0 || cache->packets == 0 ||
      entry_index >= cache->entry_capacity) {
    return;
  }
  packet_offset = entry_index * cache->packet_stride;
  for (packet_index = 0u; packet_index < cache->packet_stride; ++packet_index) {
    er_mem_zero((UINT8*)&cache->packets[packet_offset + packet_index],
                (UINTN)sizeof(cache->packets[0]));
  }
  er_mem_zero((UINT8*)&cache->entries[entry_index],
              (UINTN)sizeof(cache->entries[0]));
  cache->entries[entry_index].abi_version = ER_WORK_ABI_VERSION;
  cache->entries[entry_index].packet_offset = packet_offset;
}

static ErStorageEndpointCacheEntry* er_storage_endpoint_cache_find_mutable(
    ErStorageEndpointObjectCache* cache,
    const ErHash* object_id) {
  UINT32 entry_index;

  if (cache == 0 || cache->entries == 0 || object_id == 0 ||
      er_hash_nonzero(object_id) == 0u) {
    return 0;
  }
  for (entry_index = 0u; entry_index < cache->entry_capacity; ++entry_index) {
    if (er_storage_endpoint_cache_entry_used(&cache->entries[entry_index]) != 0u &&
        er_hash_equal(&cache->entries[entry_index].object_id, object_id) != 0u) {
      return &cache->entries[entry_index];
    }
  }
  return 0;
}

static ErStorageEndpointCacheEntry* er_storage_endpoint_cache_find_empty(
    ErStorageEndpointObjectCache* cache) {
  UINT32 entry_index;

  if (cache == 0 || cache->entries == 0) {
    return 0;
  }
  for (entry_index = 0u; entry_index < cache->entry_capacity; ++entry_index) {
    if (er_storage_endpoint_cache_entry_used(&cache->entries[entry_index]) == 0u) {
      return &cache->entries[entry_index];
    }
  }
  return 0;
}

static UINT8 er_storage_endpoint_cache_oldest_unpinned(
    const ErStorageEndpointObjectCache* cache,
    UINT32* out_entry_index) {
  UINT32 entry_index;
  UINT32 oldest_index = ER_STORAGE_CACHE_ENTRY_FIRST;
  UINT64 oldest_tick = 0u;
  UINT8 found = 0u;

  if (cache == 0 || cache->entries == 0 || out_entry_index == 0) {
    return 0u;
  }
  for (entry_index = 0u; entry_index < cache->entry_capacity; ++entry_index) {
    const ErStorageEndpointCacheEntry* entry = &cache->entries[entry_index];

    if (er_storage_endpoint_cache_entry_used(entry) == 0u ||
        entry->pinned != 0u) {
      continue;
    }
    if (found == 0u || entry->last_used_tick < oldest_tick) {
      oldest_tick = entry->last_used_tick;
      oldest_index = entry_index;
      found = 1u;
    }
  }
  if (found == 0u) {
    return 0u;
  }
  *out_entry_index = oldest_index;
  return 1u;
}

UINT8 er_storage_endpoint_object_cache_init(ErStorageEndpointObjectCache* cache,
                                            ErStorageEndpointCacheEntry* entries,
                                            UINT32 entry_capacity,
                                            ErVfsObjectPacket* packets,
                                            UINT32 packet_capacity,
                                            UINT32 packet_stride) {
  UINT32 entry_index;

  if (cache == 0 || entries == 0 || packets == 0 ||
      er_storage_endpoint_cache_layout_valid(entry_capacity, packet_capacity,
                                             packet_stride) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)cache, (UINTN)sizeof(*cache));
  er_mem_zero((UINT8*)entries,
              (UINTN)entry_capacity * (UINTN)sizeof(entries[0]));
  er_mem_zero((UINT8*)packets,
              (UINTN)packet_capacity * (UINTN)sizeof(packets[0]));
  cache->abi_version = ER_WORK_ABI_VERSION;
  cache->entries = entries;
  cache->entry_capacity = entry_capacity;
  cache->packets = packets;
  cache->packet_capacity = packet_capacity;
  cache->packet_stride = packet_stride;
  for (entry_index = 0u; entry_index < entry_capacity; ++entry_index) {
    cache->entries[entry_index].abi_version = ER_WORK_ABI_VERSION;
    cache->entries[entry_index].packet_offset = entry_index * packet_stride;
  }
  return 1u;
}

UINT8 er_storage_endpoint_cache_object_packet(const ErCryptoProvider* crypto,
                                              ErStorageEndpointObjectCache* cache,
                                              const ErVfsObjectPacket* packet,
                                              UINT64 use_tick,
                                              ErStorageEndpointCacheEntry* out_entry) {
  ErStorageEndpointCacheEntry* entry;
  ErVfsObjectPacket* entry_packets;
  UINT32 packet_index;

  if (crypto == 0 || cache == 0 || packet == 0 ||
      cache->abi_version != ER_WORK_ABI_VERSION ||
      cache->entries == 0 || cache->packets == 0 ||
      use_tick == 0u ||
      er_vfs_object_packet_valid(crypto, packet) == 0u ||
      packet->header.packet_count > cache->packet_stride) {
    return 0u;
  }
  entry = er_storage_endpoint_cache_find_mutable(cache,
                                                 &packet->header.object_id);
  if (entry == 0) {
    entry = er_storage_endpoint_cache_find_empty(cache);
  }
  if (entry == 0) {
    return 0u;
  }
  entry_packets = er_storage_endpoint_cache_entry_packets(cache, entry);
  packet_index = packet->header.packet_index;
  if (entry_packets == 0 ||
      packet_index >= packet->header.packet_count ||
      er_hash_nonzero(&entry_packets[packet_index].header.packet_id) != 0u) {
    return 0u;
  }
  if (entry->packet_count == ER_STORAGE_CACHE_ENTRY_EMPTY) {
    entry->object_id = packet->header.object_id;
    entry->object_len = packet->header.object_len;
    entry->packet_count = packet->header.packet_count;
  } else if (entry->object_len != packet->header.object_len ||
             entry->packet_count != packet->header.packet_count) {
    return 0u;
  }

  entry_packets[packet_index] = *packet;
  ++entry->accepted_packet_count;
  entry->last_used_tick = use_tick;
  entry->complete =
      (UINT16)(entry->accepted_packet_count == entry->packet_count);
  if (out_entry != 0) {
    *out_entry = *entry;
  }
  return 1u;
}

UINT8 er_storage_endpoint_cache_find(const ErStorageEndpointObjectCache* cache,
                                     const ErHash* object_id,
                                     ErStorageEndpointCacheEntry* out_entry) {
  UINT32 entry_index;

  if (cache == 0 || object_id == 0 || out_entry == 0 ||
      cache->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_nonzero(object_id) == 0u ||
      cache->entries == 0) {
    return 0u;
  }
  for (entry_index = 0u; entry_index < cache->entry_capacity; ++entry_index) {
    const ErStorageEndpointCacheEntry* entry = &cache->entries[entry_index];

    if (er_storage_endpoint_cache_entry_used(entry) != 0u &&
        er_hash_equal(&entry->object_id, object_id) != 0u) {
      *out_entry = *entry;
      return 1u;
    }
  }
  return 0u;
}

UINT8 er_storage_endpoint_cache_assemble_object(const ErCryptoProvider* crypto,
                                                const ErStorageEndpointObjectCache* cache,
                                                const ErHash* object_id,
                                                UINT8* object_bytes,
                                                UINTN object_capacity,
                                                UINTN* out_object_len) {
  ErStorageEndpointCacheEntry entry;
  ErVfsObjectPacket* packets;
  ErHash assembled_object_id;

  if (crypto == 0 || cache == 0 || object_id == 0 ||
      object_bytes == 0 || out_object_len == 0 ||
      er_storage_endpoint_cache_find(cache, object_id, &entry) == 0u ||
      entry.complete == 0u) {
    return 0u;
  }
  packets = er_storage_endpoint_cache_entry_packets(cache, &entry);
  if (packets == 0 ||
      er_vfs_assemble_object_packets(crypto, packets, entry.packet_count,
                                     object_bytes, object_capacity,
                                     out_object_len,
                                     &assembled_object_id) == 0u ||
      er_hash_equal(&assembled_object_id, object_id) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_storage_endpoint_cache_set_pinned(ErStorageEndpointObjectCache* cache,
                                           const ErHash* object_id,
                                           UINT8 pinned) {
  ErStorageEndpointCacheEntry* entry;

  if (cache == 0 || cache->abi_version != ER_WORK_ABI_VERSION) {
    return 0u;
  }
  entry = er_storage_endpoint_cache_find_mutable(cache, object_id);
  if (entry == 0) {
    return 0u;
  }
  entry->pinned = (UINT16)(pinned == 0u ? 0u : 1u);
  return 1u;
}

UINT8 er_storage_endpoint_cache_collect(ErStorageEndpointObjectCache* cache,
                                        UINT32 max_entries_to_collect,
                                        UINT32* out_collected) {
  UINT32 collected = 0u;
  UINT32 entry_index;

  if (cache == 0 || out_collected == 0 ||
      cache->abi_version != ER_WORK_ABI_VERSION ||
      cache->entries == 0 || cache->packets == 0 ||
      max_entries_to_collect == 0u) {
    return 0u;
  }
  while (collected < max_entries_to_collect &&
         er_storage_endpoint_cache_oldest_unpinned(cache, &entry_index) != 0u) {
    er_storage_endpoint_cache_clear_entry(cache, entry_index);
    ++collected;
  }
  *out_collected = collected;
  return 1u;
}

UINT8 er_storage_endpoint_sealed_relay_payload_hash(const ErCryptoProvider* crypto,
                                                    const UINT8* sealed_payload,
                                                    UINTN sealed_payload_len,
                                                    ErHash* out_hash) {
  ErByteSpan span;

  if (crypto == 0 || sealed_payload == 0 || sealed_payload_len == 0u ||
      out_hash == 0) {
    return 0u;
  }
  span.bytes = sealed_payload;
  span.len = sealed_payload_len;
  return er_crypto_hash(crypto, g_storage_sealed_relay_payload_domain,
                        (UINTN)(sizeof(g_storage_sealed_relay_payload_domain) - 1u),
                        &span, ER_STORAGE_SEALED_RELAY_PAYLOAD_SPAN_COUNT,
                        out_hash);
}

UINT8 er_storage_endpoint_capture_sealed_relay_packet(const ErCryptoProvider* crypto,
                                                      const ErAdmittedRoute* route,
                                                      const UINT8* relay_packet,
                                                      UINT32 relay_packet_len,
                                                      const ErByteSpan* aad,
                                                      const ErSealedContentObjectHeader* sealed_header,
                                                      ErStorageEndpointSealedRelayCapture* out_capture) {
  ErRelayPacketHeader relay_header;
  const UINT8* sealed_payload;
  UINT32 sealed_payload_len;
  ErHash relay_payload_hash;

  if (crypto == 0 || relay_packet == 0 || aad == 0 ||
      sealed_header == 0 || out_capture == 0 ||
      er_storage_endpoint_route_valid(route) == 0u ||
      er_relay_packet_decode_header(relay_packet, relay_packet_len,
                                    &relay_header) == 0u ||
      er_storage_endpoint_relay_header_matches_route(&relay_header,
                                                     route) == 0u ||
      er_relay_packet_payload(relay_packet, relay_packet_len, &sealed_payload,
                              &sealed_payload_len) == 0u ||
      er_storage_endpoint_sealed_relay_payload_hash(crypto, sealed_payload,
                                                    sealed_payload_len,
                                                    &relay_payload_hash) == 0u ||
      er_hash_equal(&relay_payload_hash, &relay_header.payload_hash) == 0u ||
      er_seal_content_object_valid(crypto, sealed_header, aad, sealed_payload,
                                   sealed_payload_len) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_capture, (UINTN)sizeof(*out_capture));
  out_capture->abi_version = ER_WORK_ABI_VERSION;
  out_capture->route_id = route->route_id;
  out_capture->admission_id = route->admission_hash;
  out_capture->relay_payload_hash = relay_payload_hash;
  out_capture->sealed_object_id = sealed_header->sealed_object_id;
  out_capture->plaintext_object_id = sealed_header->plaintext_object_id;
  out_capture->sealed_payload_hash = sealed_header->sealed_payload_hash;
  out_capture->sequence = relay_header.sequence;
  out_capture->plaintext_len = sealed_header->plaintext_len;
  out_capture->sealed_payload_len = sealed_header->sealed_payload_len;
  return 1u;
}

UINT8 er_storage_endpoint_prepare_sealed_relay_receipt(
    const ErCryptoProvider* crypto,
    const ErAdmittedRoute* route,
    const ErStorageEndpointSealedRelayCapture* capture,
    const ErRelayAccountingClaim* claim,
    ErStorageEndpointRouteReceipt* out_receipt) {
  UINT64 packet_bytes;
  UINT64 expected_units;
  UINT64 claim_amount;

  if (crypto == 0 || capture == 0 || claim == 0 || out_receipt == 0 ||
      er_storage_endpoint_route_valid(route) == 0u ||
      capture->abi_version != ER_WORK_ABI_VERSION ||
      claim->abi_version != ER_WORK_ABI_VERSION ||
      er_hash_equal(&capture->route_id, &route->route_id) == 0u ||
      er_hash_equal(&capture->admission_id, &route->admission_hash) == 0u ||
      er_hash_equal(&claim->request_hash, &route->request_hash) == 0u ||
      er_hash_equal(&claim->admission_hash, &route->admission_hash) == 0u ||
      er_node_id_equal(&claim->relay_node_id, &route->relay_node_id) == 0u ||
      er_hash_nonzero(&capture->relay_payload_hash) == 0u ||
      er_hash_nonzero(&capture->sealed_object_id) == 0u ||
      er_hash_nonzero(&capture->sealed_payload_hash) == 0u ||
      er_hash_nonzero(&claim->transit_hash) == 0u ||
      capture->sequence == 0u ||
      claim->sequence != capture->sequence ||
      claim->units_used == 0u ||
      claim->unit_price == 0u ||
      claim->total_claim == 0u) {
    return 0u;
  }

  packet_bytes = (UINT64)ER_RELAY_PACKET_HEADER_LEN + capture->sealed_payload_len;
  if (packet_bytes < (UINT64)ER_RELAY_PACKET_HEADER_LEN ||
      claim->packet_bytes != packet_bytes) {
    return 0u;
  }
  expected_units = (packet_bytes + (ER_WORK_COST_UNIT_BYTES - 1u)) /
                   ER_WORK_COST_UNIT_BYTES;
  if (expected_units == 0u ||
      claim->units_used != expected_units ||
      claim->units_used > (~0ull / claim->unit_price)) {
    return 0u;
  }
  claim_amount = claim->units_used * claim->unit_price;
  if (claim_amount > (~0ull - claim->receipt_base) ||
      claim->total_claim != claim_amount + claim->receipt_base ||
      claim->total_claim > route->admitted_budget) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_receipt, (UINTN)sizeof(*out_receipt));
  out_receipt->abi_version = ER_WORK_ABI_VERSION;
  out_receipt->route_id = route->route_id;
  out_receipt->request_hash = route->request_hash;
  out_receipt->admission_id = route->admission_hash;
  out_receipt->relay_payload_hash = capture->relay_payload_hash;
  out_receipt->sealed_object_id = capture->sealed_object_id;
  out_receipt->transit_hash = claim->transit_hash;
  out_receipt->relay_node_id = route->relay_node_id;
  out_receipt->sequence = capture->sequence;
  out_receipt->packet_bytes = claim->packet_bytes;
  out_receipt->units_used = claim->units_used;
  out_receipt->unit_price = claim->unit_price;
  out_receipt->receipt_base = claim->receipt_base;
  out_receipt->total_claim = claim->total_claim;
  return er_storage_endpoint_route_receipt_hash(crypto, out_receipt, capture,
                                                &out_receipt->receipt_hash);
}

UINT8 er_storage_endpoint_capture_object_packet(const ErCryptoProvider* crypto,
                                                const ErAdmittedRoute* route,
                                                const ErChannelEnvelopeHeader* envelope,
                                                const ErVfsObjectPacket* packet,
                                                ErStorageEndpointObjectCapture* out_capture) {
  if (crypto == 0 || out_capture == 0 ||
      er_storage_endpoint_route_valid(route) == 0u ||
      er_vfs_object_packet_valid(crypto, packet) == 0u ||
      er_work_verify_channel_envelope_for_route(envelope, route) == 0u ||
      er_hash_equal(&envelope->packet_hash, &packet->header.packet_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_capture, (UINTN)sizeof(*out_capture));
  out_capture->abi_version = ER_WORK_ABI_VERSION;
  out_capture->route_id = route->route_id;
  out_capture->object_id = packet->header.object_id;
  out_capture->object_len = packet->header.object_len;
  out_capture->packet_count = packet->header.packet_count;
  out_capture->packet_index = packet->header.packet_index;
  out_capture->bytes_len = packet->header.bytes_len;
  out_capture->packet_id = packet->header.packet_id;
  out_capture->payload_hash = packet->header.payload_hash;
  return er_storage_endpoint_capture_hash(crypto, route, packet,
                                          &out_capture->capture_hash);
}

UINT8 er_storage_endpoint_store_object_packet(const ErCryptoProvider* crypto,
                                              const ErAdmittedRoute* route,
                                              const ErChannelEnvelopeHeader* envelope,
                                              const ErVfsObjectPacket* packet,
                                              ErStorageEndpointObjectStore* store,
                                              ErStorageEndpointObjectCapture* out_capture) {
  ErStorageEndpointObjectCapture capture;
  UINT32 packet_index;

  if (store == 0 || store->abi_version != ER_WORK_ABI_VERSION ||
      store->packets == 0 ||
      er_storage_endpoint_capture_object_packet(crypto, route, envelope,
                                                packet, &capture) == 0u ||
      er_storage_endpoint_packet_matches_store(store, packet) == 0u ||
      packet->header.packet_count > store->packet_capacity ||
      er_hash_nonzero(&store->packets[packet->header.packet_index].header.packet_id) != 0u) {
    return 0u;
  }

  if (store->packet_count == 0u) {
    store->route_id = route->route_id;
    store->object_id = packet->header.object_id;
    store->object_len = packet->header.object_len;
    store->packet_count = packet->header.packet_count;
  } else if (er_hash_equal(&store->route_id, &route->route_id) == 0u) {
    return 0u;
  }

  packet_index = packet->header.packet_index;
  store->packets[packet_index] = *packet;
  ++store->accepted_packet_count;
  store->complete = (UINT16)(store->accepted_packet_count == store->packet_count);
  if (out_capture != 0) {
    *out_capture = capture;
  }
  return 1u;
}

UINT8 er_storage_endpoint_prepare_package_storage_response(const ErCryptoProvider* crypto,
                                                           const ErStorageEndpointObjectStore* store,
                                                           const ErHash* expected_route_id,
                                                           const ErHash* expected_object_id,
                                                           UINT64 expected_object_len,
                                                           UINT8* object_bytes,
                                                           UINTN object_capacity,
                                                           ErAppPackageStorageResponse* out_response) {
  UINTN object_len = 0u;
  ErHash object_id;

  if (crypto == 0 || store == 0 || expected_route_id == 0 ||
      expected_object_id == 0 || object_bytes == 0 || out_response == 0 ||
      store->abi_version != ER_WORK_ABI_VERSION ||
      store->complete == 0u ||
      store->packet_count == 0u ||
      store->packets == 0 ||
      store->accepted_packet_count != store->packet_count ||
      store->object_len != expected_object_len ||
      object_capacity < expected_object_len ||
      er_hash_equal(&store->route_id, expected_route_id) == 0u ||
      er_hash_equal(&store->object_id, expected_object_id) == 0u) {
    return 0u;
  }
  if (er_vfs_assemble_object_packets(crypto, store->packets,
                                     store->packet_count, object_bytes,
                                     object_capacity, &object_len,
                                     &object_id) == 0u ||
      object_len != (UINTN)expected_object_len ||
      er_hash_equal(&object_id, expected_object_id) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
  out_response->abi_version = ER_APP_ABI_VERSION;
  out_response->retrieve_route_id = store->route_id;
  out_response->object_id = store->object_id;
  out_response->object_len = store->object_len;
  out_response->packets = store->packets;
  out_response->packet_count = store->packet_count;
  out_response->bytes = object_bytes;
  out_response->capacity = object_capacity;
  return 1u;
}

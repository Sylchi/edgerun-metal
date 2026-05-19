#ifndef ER_STORAGE_ENDPOINT_H
#define ER_STORAGE_ENDPOINT_H

/*
 * Purpose: validate storage endpoint packets after relay route admission.
 * Intention: keep object storage as endpoint-owned content-addressed packets, not host files.
 */

#include "er_app.h"
#include "er_relay_packet.h"
#include "er_seal.h"
#include "er_vfs.h"
#include "er_work_route.h"

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash route_id;
  ErHash object_id;
  UINT64 object_len;
  UINT32 packet_count;
  UINT16 packet_index;
  UINT32 bytes_len;
  ErHash packet_id;
  ErHash payload_hash;
  ErHash capture_hash;
} ErStorageEndpointObjectCapture;

typedef struct {
  UINT16 abi_version;
  UINT16 complete;
  ErHash route_id;
  ErHash object_id;
  UINT64 object_len;
  UINT32 packet_count;
  UINT32 accepted_packet_count;
  ErVfsObjectPacket* packets;
  UINT32 packet_capacity;
} ErStorageEndpointObjectStore;

typedef struct {
  UINT16 abi_version;
  UINT16 complete;
  UINT16 pinned;
  UINT16 reserved;
  ErHash object_id;
  UINT64 object_len;
  UINT64 last_used_tick;
  UINT32 packet_count;
  UINT32 accepted_packet_count;
  UINT32 packet_offset;
} ErStorageEndpointCacheEntry;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash route_id;
  ErHash admission_id;
  ErHash relay_payload_hash;
  ErHash sealed_object_id;
  ErHash plaintext_object_id;
  ErHash sealed_payload_hash;
  UINT64 sequence;
  UINT64 plaintext_len;
  UINT64 sealed_payload_len;
} ErStorageEndpointSealedRelayCapture;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErStorageEndpointCacheEntry* entries;
  UINT32 entry_capacity;
  ErVfsObjectPacket* packets;
  UINT32 packet_capacity;
  UINT32 packet_stride;
} ErStorageEndpointObjectCache;

UINT8 er_storage_endpoint_object_store_init(ErStorageEndpointObjectStore* store,
                                            ErVfsObjectPacket* packets,
                                            UINT32 packet_capacity);
UINT8 er_storage_endpoint_object_cache_init(ErStorageEndpointObjectCache* cache,
                                            ErStorageEndpointCacheEntry* entries,
                                            UINT32 entry_capacity,
                                            ErVfsObjectPacket* packets,
                                            UINT32 packet_capacity,
                                            UINT32 packet_stride);
UINT8 er_storage_endpoint_cache_object_packet(const ErCryptoProvider* crypto,
                                              ErStorageEndpointObjectCache* cache,
                                              const ErVfsObjectPacket* packet,
                                              UINT64 use_tick,
                                              ErStorageEndpointCacheEntry* out_entry);
UINT8 er_storage_endpoint_cache_find(const ErStorageEndpointObjectCache* cache,
                                     const ErHash* object_id,
                                     ErStorageEndpointCacheEntry* out_entry);
UINT8 er_storage_endpoint_cache_assemble_object(const ErCryptoProvider* crypto,
                                                const ErStorageEndpointObjectCache* cache,
                                                const ErHash* object_id,
                                                UINT8* object_bytes,
                                                UINTN object_capacity,
                                                UINTN* out_object_len);
UINT8 er_storage_endpoint_cache_set_pinned(ErStorageEndpointObjectCache* cache,
                                           const ErHash* object_id,
                                           UINT8 pinned);
UINT8 er_storage_endpoint_cache_collect(ErStorageEndpointObjectCache* cache,
                                        UINT32 max_entries_to_collect,
                                        UINT32* out_collected);
UINT8 er_storage_endpoint_sealed_relay_payload_hash(const ErCryptoProvider* crypto,
                                                    const UINT8* sealed_payload,
                                                    UINTN sealed_payload_len,
                                                    ErHash* out_hash);
UINT8 er_storage_endpoint_capture_sealed_relay_packet(const ErCryptoProvider* crypto,
                                                      const ErAdmittedRoute* route,
                                                      const UINT8* relay_packet,
                                                      UINT32 relay_packet_len,
                                                      const ErByteSpan* aad,
                                                      const ErSealedContentObjectHeader* sealed_header,
                                                      ErStorageEndpointSealedRelayCapture* out_capture);
UINT8 er_storage_endpoint_capture_object_packet(const ErCryptoProvider* crypto,
                                                const ErAdmittedRoute* route,
                                                const ErChannelEnvelopeHeader* envelope,
                                                const ErVfsObjectPacket* packet,
                                                ErStorageEndpointObjectCapture* out_capture);
UINT8 er_storage_endpoint_store_object_packet(const ErCryptoProvider* crypto,
                                              const ErAdmittedRoute* route,
                                              const ErChannelEnvelopeHeader* envelope,
                                              const ErVfsObjectPacket* packet,
                                              ErStorageEndpointObjectStore* store,
                                              ErStorageEndpointObjectCapture* out_capture);
UINT8 er_storage_endpoint_prepare_package_storage_response(const ErCryptoProvider* crypto,
                                                           const ErStorageEndpointObjectStore* store,
                                                           const ErHash* expected_route_id,
                                                           const ErHash* expected_object_id,
                                                           UINT64 expected_object_len,
                                                           UINT8* object_bytes,
                                                           UINTN object_capacity,
                                                           ErAppPackageStorageResponse* out_response);

#endif

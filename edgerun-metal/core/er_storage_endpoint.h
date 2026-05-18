#ifndef ER_STORAGE_ENDPOINT_H
#define ER_STORAGE_ENDPOINT_H

/*
 * Purpose: validate storage endpoint packets after relay route admission.
 * Intention: keep object storage as endpoint-owned content-addressed packets, not host files.
 */

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

UINT8 er_storage_endpoint_capture_object_packet(const ErCryptoProvider* crypto,
                                                const ErAdmittedRoute* route,
                                                const ErChannelEnvelopeHeader* envelope,
                                                const ErVfsObjectPacket* packet,
                                                ErStorageEndpointObjectCapture* out_capture);

#endif

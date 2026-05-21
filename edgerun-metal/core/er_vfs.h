#ifndef ER_VFS_H
#define ER_VFS_H

/*
 * Purpose: define memory-only packet and VFS reference records for the C runtime.
 * Intention: move canonical object bytes between boundaries without giving VFS
 * its own object identity scheme.
 */

#include "er_work.h"
#include "er_crypto.h"
#include "er_object.h"

#define ER_VFS_ABI_VERSION 1u
#define ER_VFS_LABEL_MAX 160u
#define ER_VFS_OBJECT_PACKET_HEADER_BYTES 128u
#define ER_VFS_OBJECT_PACKET_BYTES 1024u

#define ER_VFS_COMPRESSION_NONE 0u
#define ER_VFS_COMPRESSION_DEFLATE_RAW 1u
#define ER_VFS_SEAL_NONE 0u
#define ER_VFS_SEAL_BLAKE3_STREAM_AUTH 1u

typedef struct {
  UINT16 abi_version;
  UINT16 packet_index;
  UINT32 packet_count;
  ErHash object_id;
  UINT64 object_len;
  UINT64 offset;
  ErHash payload_hash;
  ErHash packet_id;
  UINT32 bytes_len;
} ErVfsObjectPacketHeader;

typedef struct {
  ErVfsObjectPacketHeader header;
  UINT8 bytes[ER_VFS_OBJECT_PACKET_BYTES];
} ErVfsObjectPacket;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash object_id;
  UINT64 object_len;
} ErVfsObjectRef;

typedef struct {
  UINT16 abi_version;
  UINT16 label_len;
  char label[ER_VFS_LABEL_MAX];
  ErHash object_id;
  UINT64 object_len;
  ErHash label_hash;
} ErVfsObjectLabelRef;

typedef struct {
  UINT16 abi_version;
  UINT16 compression_kind;
  UINT16 seal_kind;
  UINT16 reserved;
  ErHash plaintext_object_id;
  UINT64 plaintext_len;
  ErHash transport_object_id;
  UINT64 transport_len;
  ErHash transform_hash;
} ErVfsObjectTransformRef;

typedef struct {
  UINT16 abi_version;
  UINT16 compression_kind;
  UINT16 seal_kind;
  UINT16 aad_len;
  ErHash plaintext_object_id;
  UINT64 plaintext_len;
  ErHash aad_hash;
  ErHash payload_hash;
  UINT64 payload_len;
} ErVfsObjectSealRequestHeader;

typedef struct {
  UINT16 abi_version;
  UINT16 compression_kind;
  UINT16 seal_kind;
  UINT16 aad_len;
  ErHash transport_object_id;
  UINT64 transport_len;
  ErHash aad_hash;
  ErHash sealed_envelope_hash;
  UINT64 sealed_envelope_len;
} ErVfsObjectUnsealRequestHeader;

UINT8 er_vfs_label_valid(const char* label, UINTN label_len);
UINT8 er_vfs_prepare_object_packet(const ErCryptoProvider* crypto,
                                   const UINT8* canonical_object_bytes,
                                   UINTN canonical_object_len,
                                   UINTN offset, UINT32 packet_index, UINT32 packet_count,
                                   ErVfsObjectPacket* out_packet);
UINT8 er_vfs_object_packet_valid(const ErCryptoProvider* crypto,
                                 const ErVfsObjectPacket* packet);
UINT8 er_vfs_assemble_object_packets(const ErCryptoProvider* crypto,
                                     const ErVfsObjectPacket* packets,
                                     UINT32 packet_count,
                                     UINT8* out_object_bytes,
                                     UINTN out_object_capacity,
                                     UINTN* out_object_len,
                                     ErHash* out_object_id);
UINT8 er_vfs_prepare_object_ref(const ErCryptoProvider* crypto,
                                const UINT8* canonical_object_bytes,
                                UINTN canonical_object_len,
                                ErVfsObjectRef* out_ref);
UINT8 er_vfs_prepare_object_ref_from_object(const ErHash* object_id,
                                            UINT64 object_len,
                                            ErVfsObjectRef* out_ref);
UINT8 er_vfs_prepare_object_label_ref(const ErCryptoProvider* crypto, const char* label, UINTN label_len,
                                      const UINT8* canonical_object_bytes,
                                      UINTN canonical_object_len,
                                      ErVfsObjectLabelRef* out_ref);
UINT8 er_vfs_prepare_object_label_ref_from_object(const ErCryptoProvider* crypto, const char* label,
                                                  UINTN label_len, const ErHash* object_id,
                                                  UINT64 object_len, ErVfsObjectLabelRef* out_ref);
UINT8 er_vfs_prepare_transform_ref(const ErCryptoProvider* crypto, const ErHash* plaintext_object_id,
                                   UINT64 plaintext_len, const ErHash* transport_object_id,
                                   UINT64 transport_len, UINT16 compression_kind, UINT16 seal_kind,
                                   ErVfsObjectTransformRef* out_ref);

#endif

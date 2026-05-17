#ifndef ER_VFS_H
#define ER_VFS_H

/*
 * Purpose: define the memory-only object/VFS records for the C runtime.
 * Intention: keep file-like work content-addressed and sealed before transport or durability.
 */

#include "er_work.h"
#include "er_crypto.h"

#define ER_VFS_ABI_VERSION 1u
#define ER_VFS_PATH_MAX 160u
#define ER_VFS_OBJECT_PACKET_BYTES 1024u

#define ER_VFS_COMPRESSION_NONE 0u
#define ER_VFS_COMPRESSION_DEFLATE_RAW 1u
#define ER_VFS_SEAL_NONE 0u
#define ER_VFS_SEAL_AES256_GCM 1u

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
  UINT16 path_len;
  char path[ER_VFS_PATH_MAX];
  ErHash object_id;
  UINT64 object_len;
  ErHash file_hash;
} ErVfsFileRef;

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

UINT8 er_vfs_path_label_valid(const char* path, UINTN path_len);
UINT8 er_vfs_prepare_object_packet(const ErCryptoProvider* crypto, const UINT8* object_bytes, UINTN object_len,
                                   UINTN offset, UINT32 packet_index, UINT32 packet_count,
                                   ErVfsObjectPacket* out_packet);
UINT8 er_vfs_prepare_file_ref(const ErCryptoProvider* crypto, const char* path, UINTN path_len,
                              const UINT8* object_bytes, UINTN object_len, ErVfsFileRef* out_ref);
UINT8 er_vfs_prepare_transform_ref(const ErCryptoProvider* crypto, const ErHash* plaintext_object_id,
                                   UINT64 plaintext_len, const ErHash* transport_object_id,
                                   UINT64 transport_len, UINT16 compression_kind, UINT16 seal_kind,
                                   ErVfsObjectTransformRef* out_ref);

#endif

#ifndef ER_PI_ZERO_W_V1_1_OTA_H
#define ER_PI_ZERO_W_V1_1_OTA_H

/*
 * Purpose: define the Pi Zero W v1.1 open L2 erwire/VFS update receiver.
 * Intention: keep the no-auth bring-up updater explicit, deterministic, and
 * scoped to the board that is using it without inventing a second wire format.
 */

#include "er_crypto.h"
#include "er_types.h"
#include "er_vfs.h"

#define ER_PI_ZERO_W_V1_1_OTA_ERWIRE_MAGIC 0x31575245u
#define ER_PI_ZERO_W_V1_1_OTA_ERWIRE_VERSION 1u
#define ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_BYTES 32u
#define ER_PI_ZERO_W_V1_1_OTA_ERWIRE_KIND_VFS_OBJECT_PACKET 48u
#define ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_BYTES_MAX \
  (ER_VFS_OBJECT_PACKET_HEADER_BYTES + ER_VFS_OBJECT_PACKET_BYTES)
#define ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES 512u
#define ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY 64u
#define ER_PI_ZERO_W_V1_1_OTA_OBJECT_BYTES_MAX \
  (ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY * ER_VFS_OBJECT_PACKET_BYTES)
#define ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK 8192u

#define ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE 0u
#define ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING 1u
#define ER_PI_ZERO_W_V1_1_OTA_STATUS_COMMITTED 2u
#define ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED 3u
#define ER_PI_ZERO_W_V1_1_OTA_STATUS_WRITE_FAILED 4u

typedef UINT8 (*ErPiZeroWV11OtaWriteBlockFn)(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES]);

typedef struct {
  UINT32 status;
  UINT64 object_len;
  UINT32 next_offset;
  UINT32 target_block;
  UINT32 next_block;
  UINT32 buffered_bytes;
  UINT32 accepted_packet_count;
  UINT32 packet_count;
  UINT8 reboot_required;
  ErHash object_id;
  UINT8 packet_present[ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY];
  ErVfsObjectPacket packets[ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY];
  UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES];
} ErPiZeroWV11OtaState;

void er_pi_zero_w_v1_1_ota_reset(ErPiZeroWV11OtaState* state);
UINT32 er_pi_zero_w_v1_1_ota_crc32(const UINT8* bytes, UINT32 len);
UINT8 er_pi_zero_w_v1_1_ota_decode_object_packet_payload(
    const UINT8* frame,
    UINT32 frame_len,
    ErVfsObjectPacket* out_packet);
UINT8 er_pi_zero_w_v1_1_ota_receive_frame(
    ErPiZeroWV11OtaState* state,
    const ErCryptoProvider* crypto,
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx);

#endif

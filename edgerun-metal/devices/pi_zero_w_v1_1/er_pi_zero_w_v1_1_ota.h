#ifndef ER_PI_ZERO_W_V1_1_OTA_H
#define ER_PI_ZERO_W_V1_1_OTA_H

/*
 * Purpose: define the Pi Zero W v1.1 open L2 update command receiver.
 * Intention: keep the no-auth bring-up updater explicit, deterministic, and
 * scoped to the board that is using it.
 */

#include "er_types.h"

#define ER_PI_ZERO_W_V1_1_OTA_ABI_VERSION 1u
#define ER_PI_ZERO_W_V1_1_OTA_MAGIC 0x50555245u
#define ER_PI_ZERO_W_V1_1_OTA_COMMAND_BEGIN 1u
#define ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA 2u
#define ER_PI_ZERO_W_V1_1_OTA_COMMAND_COMMIT 3u
#define ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES 32u
#define ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES 512u
#define ER_PI_ZERO_W_V1_1_OTA_FRAME_PAYLOAD_MAX 96u
#define ER_PI_ZERO_W_V1_1_OTA_IMAGE_BYTES_MAX 0x01000000u
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
  UINT32 magic;
  UINT16 version;
  UINT16 command;
  UINT32 sequence;
  UINT32 image_len;
  UINT32 image_crc32;
  UINT32 offset;
  UINT16 payload_len;
  UINT16 header_len;
  UINT32 target_block;
} ErPiZeroWV11OtaFrameHeader;

typedef struct {
  UINT32 status;
  UINT32 image_len;
  UINT32 image_crc32;
  UINT32 running_crc32;
  UINT32 next_offset;
  UINT32 target_block;
  UINT32 next_block;
  UINT32 buffered_bytes;
  UINT8 reboot_required;
  UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES];
} ErPiZeroWV11OtaState;

void er_pi_zero_w_v1_1_ota_reset(ErPiZeroWV11OtaState* state);
UINT32 er_pi_zero_w_v1_1_ota_crc32(const UINT8* bytes, UINT32 len);
UINT8 er_pi_zero_w_v1_1_ota_header_decode(
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaFrameHeader* out_header);
UINT8 er_pi_zero_w_v1_1_ota_receive_frame(
    ErPiZeroWV11OtaState* state,
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx);
UINT8 er_pi_zero_w_v1_1_ota_build_header(
    const ErPiZeroWV11OtaFrameHeader* header,
    UINT8 out_header[ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES]);

#endif

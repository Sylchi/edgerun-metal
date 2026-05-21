#ifndef ER_PI_ZERO_W_V1_1_BOOT_LOG_H
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_H

/*
 * Purpose: persist fixed Pi Zero W v1.1 boot milestones into reserved SD blocks.
 * Intention: make board bring-up diagnosable from the card without introducing
 * ambient storage, allocation, or a second app-facing storage API.
 */

#include "er_types.h"

#define ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES 512u
#define ER_PI_ZERO_W_V1_1_BOOT_CHECKPOINT_BLOCK 131072u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_START_BLOCK 131073u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_COUNT 127u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_PENDING_COUNT 32u
#define ER_PI_ZERO_W_V1_1_BOOT_IMAGE_ID 0x20260522u
#define ER_PI_ZERO_W_V1_1_BOOT_IMAGE_REVISION 2u

#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_BOOT_ENTRY 1u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_UART_READY 2u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_LCD_INIT 3u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_IDENTITY_READY 4u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_IDENTITY_FAILED 5u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OTA_LISTEN 6u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_STORAGE_READY 7u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_STORAGE_FAILED 8u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_WIFI_POWERED 9u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_SDIO_PROBED 10u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_READY 11u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_FAILED 12u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_NODE_AVAILABLE_SENT 13u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_UART_OTA_FRAME 14u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_OTA_FRAME 15u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OTA_BLOCK_WRITTEN 16u
#define ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_REBOOT_READY 17u

typedef UINT8 (*ErPiZeroWV11BootLogWriteBlockFn)(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES]);

typedef struct {
  UINT32 event;
  UINT32 arg0;
  UINT32 arg1;
  UINT32 arg2;
  UINT32 arg3;
} ErPiZeroWV11BootLogEvent;

typedef struct {
  UINT32 boot_id;
  UINT32 next_sequence;
  UINT32 pending_count;
  UINT32 dropped_count;
  UINT8 storage_enabled;
  ErPiZeroWV11BootLogWriteBlockFn write_block;
  void* write_ctx;
  ErPiZeroWV11BootLogEvent
      pending[ER_PI_ZERO_W_V1_1_BOOT_LOG_PENDING_COUNT];
} ErPiZeroWV11BootLog;

void er_pi_zero_w_v1_1_boot_log_init(ErPiZeroWV11BootLog* log,
                                     UINT32 boot_id);
UINT8 er_pi_zero_w_v1_1_boot_log_enable_storage(
    ErPiZeroWV11BootLog* log,
    ErPiZeroWV11BootLogWriteBlockFn write_block,
    void* write_ctx);
UINT8 er_pi_zero_w_v1_1_boot_log_append(ErPiZeroWV11BootLog* log,
                                        UINT32 event,
                                        UINT32 arg0,
                                        UINT32 arg1,
                                        UINT32 arg2,
                                        UINT32 arg3);
UINT32 er_pi_zero_w_v1_1_boot_log_crc32(const UINT8* bytes, UINT32 len);

#endif

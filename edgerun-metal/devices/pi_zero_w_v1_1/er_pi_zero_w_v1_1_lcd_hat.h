#ifndef ER_PI_ZERO_W_V1_1_LCD_HAT_H
#define ER_PI_ZERO_W_V1_1_LCD_HAT_H

#include "er_types.h"

/*
 * Purpose: bind the Waveshare 1.3inch ST7789 LCD HAT to Raspberry Pi Zero W v1.1.
 * Intention: present board debug state locally without Linux, fbcp, or vendor code.
 */

typedef struct ErPiZeroWV11DebugStatus {
  UINT32 heartbeat;
  UINT32 sdio_state;
  UINT32 storage_state;
  UINT32 ota_status;
  UINT32 ota_offset;
  UINT32 l2_ready;
} ErPiZeroWV11DebugStatus;

void er_pi_zero_w_v1_1_lcd_hat_init(void);
void er_pi_zero_w_v1_1_lcd_hat_status(const ErPiZeroWV11DebugStatus* status);

#endif

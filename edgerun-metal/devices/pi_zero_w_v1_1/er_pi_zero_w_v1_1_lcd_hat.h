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
  UINT32 input_state;
} ErPiZeroWV11DebugStatus;

#define ER_PI_ZERO_W_V1_1_LCD_INPUT_UP 0x00000001u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_DOWN 0x00000002u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_LEFT 0x00000004u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_RIGHT 0x00000008u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_PRESS 0x00000010u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY1 0x00000100u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY2 0x00000200u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY3 0x00000400u
#define ER_PI_ZERO_W_V1_1_LCD_INPUT_ALL \
  (ER_PI_ZERO_W_V1_1_LCD_INPUT_UP | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_DOWN | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_LEFT | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_RIGHT | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_PRESS | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY1 | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY2 | \
   ER_PI_ZERO_W_V1_1_LCD_INPUT_KEY3)

void er_pi_zero_w_v1_1_lcd_hat_init(void);
void er_pi_zero_w_v1_1_lcd_hat_status(const ErPiZeroWV11DebugStatus* status);
UINT32 er_pi_zero_w_v1_1_lcd_hat_input_state(void);

#endif

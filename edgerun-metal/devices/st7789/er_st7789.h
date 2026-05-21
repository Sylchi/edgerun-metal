#ifndef ER_ST7789_H
#define ER_ST7789_H

#include "er_types.h"

/*
 * Purpose: drive ST7789-family RGB565 SPI LCD controllers from firmware-owned buses.
 * Intention: keep panel command sequencing first-party and independent of host libraries.
 */

#define ER_ST7789_WIDTH 240u
#define ER_ST7789_HEIGHT 240u
#define ER_ST7789_COLOR_BLACK 0x0000u
#define ER_ST7789_COLOR_WHITE 0xffffu
#define ER_ST7789_COLOR_RED 0xf800u
#define ER_ST7789_COLOR_GREEN 0x07e0u
#define ER_ST7789_COLOR_BLUE 0x001fu
#define ER_ST7789_COLOR_CYAN 0x07ffu
#define ER_ST7789_COLOR_YELLOW 0xffe0u
#define ER_ST7789_COLOR_GRAY 0x8410u

typedef UINT8 (*ErSt7789WriteCommandFn)(void* ctx, UINT8 command);
typedef UINT8 (*ErSt7789WriteDataFn)(void* ctx,
                                     const UINT8* bytes,
                                     UINT32 len);
typedef void (*ErSt7789DelayFn)(void* ctx, UINT32 ticks);

typedef struct ErSt7789Bus {
  void* ctx;
  ErSt7789WriteCommandFn write_command;
  ErSt7789WriteDataFn write_data;
  ErSt7789DelayFn delay;
} ErSt7789Bus;

UINT8 er_st7789_init(const ErSt7789Bus* bus);
UINT8 er_st7789_fill_rect(const ErSt7789Bus* bus,
                          UINT16 x,
                          UINT16 y,
                          UINT16 width,
                          UINT16 height,
                          UINT16 color);
UINT8 er_st7789_draw_text(const ErSt7789Bus* bus,
                          UINT16 x,
                          UINT16 y,
                          const char* text,
                          UINT8 scale,
                          UINT16 fg,
                          UINT16 bg);

#endif

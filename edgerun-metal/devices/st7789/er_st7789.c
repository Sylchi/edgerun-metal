#include "er_st7789.h"

#define ER_ST7789_CMD_SWRESET 0x01u
#define ER_ST7789_CMD_SLPOUT 0x11u
#define ER_ST7789_CMD_COLMOD 0x3au
#define ER_ST7789_CMD_MADCTL 0x36u
#define ER_ST7789_CMD_CASET 0x2au
#define ER_ST7789_CMD_RASET 0x2bu
#define ER_ST7789_CMD_RAMWR 0x2cu
#define ER_ST7789_CMD_INVON 0x21u
#define ER_ST7789_CMD_NORON 0x13u
#define ER_ST7789_CMD_DISPON 0x29u
#define ER_ST7789_COLMOD_RGB565 0x55u
#define ER_ST7789_MADCTL_RGB 0x00u
#define ER_ST7789_RESET_DELAY_TICKS 120000u
#define ER_ST7789_SLEEP_OUT_DELAY_TICKS 120000u
#define ER_ST7789_DISPLAY_ON_DELAY_TICKS 120000u
#define ER_ST7789_COMMAND_BYTES_1 1u
#define ER_ST7789_ADDRESS_BYTES 4u
#define ER_ST7789_COLOR_BYTES 2u
#define ER_ST7789_GLYPH_COLUMNS 5u
#define ER_ST7789_GLYPH_ROWS 7u
#define ER_ST7789_GLYPH_ADVANCE 6u
#define ER_ST7789_GLYPH_SPACE 0x00u
#define ER_ST7789_GLYPH_COLUMN_MASK 0x7fu
#define ER_ST7789_BYTE_SHIFT 8u

static UINT8 er_st7789_bus_valid(const ErSt7789Bus* bus) {
  return bus != 0 && bus->write_command != 0 && bus->write_data != 0;
}

static void er_st7789_delay(const ErSt7789Bus* bus, UINT32 ticks) {
  if (bus->delay != 0) {
    bus->delay(bus->ctx, ticks);
  }
}

static UINT8 er_st7789_command_data(const ErSt7789Bus* bus,
                                    UINT8 command,
                                    const UINT8* data,
                                    UINT32 len) {
  if (er_st7789_bus_valid(bus) == 0u || bus->write_command(bus->ctx, command) == 0u) {
    return 0u;
  }
  if (len == 0u) {
    return 1u;
  }
  return bus->write_data(bus->ctx, data, len);
}

static void er_st7789_put_u16(UINT8* out, UINT16 value) {
  out[0] = (UINT8)(value >> ER_ST7789_BYTE_SHIFT);
  out[1] = (UINT8)value;
}

static UINT8 er_st7789_set_window(const ErSt7789Bus* bus,
                                  UINT16 x0,
                                  UINT16 y0,
                                  UINT16 x1,
                                  UINT16 y1) {
  UINT8 address[ER_ST7789_ADDRESS_BYTES];

  er_st7789_put_u16(&address[0], x0);
  er_st7789_put_u16(&address[2], x1);
  if (er_st7789_command_data(bus, ER_ST7789_CMD_CASET, address, ER_ST7789_ADDRESS_BYTES) == 0u) {
    return 0u;
  }
  er_st7789_put_u16(&address[0], y0);
  er_st7789_put_u16(&address[2], y1);
  if (er_st7789_command_data(bus, ER_ST7789_CMD_RASET, address, ER_ST7789_ADDRESS_BYTES) == 0u ||
      bus->write_command(bus->ctx, ER_ST7789_CMD_RAMWR) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_st7789_glyph_column(char ch, UINT32 column) {
  switch (ch) {
    case '0': { static const UINT8 g[] = {0x3eu, 0x51u, 0x49u, 0x45u, 0x3eu}; return g[column]; }
    case '1': { static const UINT8 g[] = {0x00u, 0x42u, 0x7fu, 0x40u, 0x00u}; return g[column]; }
    case '2': { static const UINT8 g[] = {0x42u, 0x61u, 0x51u, 0x49u, 0x46u}; return g[column]; }
    case '3': { static const UINT8 g[] = {0x21u, 0x41u, 0x45u, 0x4bu, 0x31u}; return g[column]; }
    case '4': { static const UINT8 g[] = {0x18u, 0x14u, 0x12u, 0x7fu, 0x10u}; return g[column]; }
    case '5': { static const UINT8 g[] = {0x27u, 0x45u, 0x45u, 0x45u, 0x39u}; return g[column]; }
    case '6': { static const UINT8 g[] = {0x3cu, 0x4au, 0x49u, 0x49u, 0x30u}; return g[column]; }
    case '7': { static const UINT8 g[] = {0x01u, 0x71u, 0x09u, 0x05u, 0x03u}; return g[column]; }
    case '8': { static const UINT8 g[] = {0x36u, 0x49u, 0x49u, 0x49u, 0x36u}; return g[column]; }
    case '9': { static const UINT8 g[] = {0x06u, 0x49u, 0x49u, 0x29u, 0x1eu}; return g[column]; }
    case 'A': { static const UINT8 g[] = {0x7eu, 0x11u, 0x11u, 0x11u, 0x7eu}; return g[column]; }
    case 'B': { static const UINT8 g[] = {0x7fu, 0x49u, 0x49u, 0x49u, 0x36u}; return g[column]; }
    case 'C': { static const UINT8 g[] = {0x3eu, 0x41u, 0x41u, 0x41u, 0x22u}; return g[column]; }
    case 'D': { static const UINT8 g[] = {0x7fu, 0x41u, 0x41u, 0x22u, 0x1cu}; return g[column]; }
    case 'E': { static const UINT8 g[] = {0x7fu, 0x49u, 0x49u, 0x49u, 0x41u}; return g[column]; }
    case 'F': { static const UINT8 g[] = {0x7fu, 0x09u, 0x09u, 0x09u, 0x01u}; return g[column]; }
    case 'G': { static const UINT8 g[] = {0x3eu, 0x41u, 0x49u, 0x49u, 0x7au}; return g[column]; }
    case 'H': { static const UINT8 g[] = {0x7fu, 0x08u, 0x08u, 0x08u, 0x7fu}; return g[column]; }
    case 'I': { static const UINT8 g[] = {0x00u, 0x41u, 0x7fu, 0x41u, 0x00u}; return g[column]; }
    case 'J': { static const UINT8 g[] = {0x20u, 0x40u, 0x41u, 0x3fu, 0x01u}; return g[column]; }
    case 'K': { static const UINT8 g[] = {0x7fu, 0x08u, 0x14u, 0x22u, 0x41u}; return g[column]; }
    case 'L': { static const UINT8 g[] = {0x7fu, 0x40u, 0x40u, 0x40u, 0x40u}; return g[column]; }
    case 'M': { static const UINT8 g[] = {0x7fu, 0x02u, 0x0cu, 0x02u, 0x7fu}; return g[column]; }
    case 'N': { static const UINT8 g[] = {0x7fu, 0x04u, 0x08u, 0x10u, 0x7fu}; return g[column]; }
    case 'O': { static const UINT8 g[] = {0x3eu, 0x41u, 0x41u, 0x41u, 0x3eu}; return g[column]; }
    case 'P': { static const UINT8 g[] = {0x7fu, 0x09u, 0x09u, 0x09u, 0x06u}; return g[column]; }
    case 'Q': { static const UINT8 g[] = {0x3eu, 0x41u, 0x51u, 0x21u, 0x5eu}; return g[column]; }
    case 'R': { static const UINT8 g[] = {0x7fu, 0x09u, 0x19u, 0x29u, 0x46u}; return g[column]; }
    case 'S': { static const UINT8 g[] = {0x46u, 0x49u, 0x49u, 0x49u, 0x31u}; return g[column]; }
    case 'T': { static const UINT8 g[] = {0x01u, 0x01u, 0x7fu, 0x01u, 0x01u}; return g[column]; }
    case 'U': { static const UINT8 g[] = {0x3fu, 0x40u, 0x40u, 0x40u, 0x3fu}; return g[column]; }
    case 'V': { static const UINT8 g[] = {0x1fu, 0x20u, 0x40u, 0x20u, 0x1fu}; return g[column]; }
    case 'W': { static const UINT8 g[] = {0x3fu, 0x40u, 0x38u, 0x40u, 0x3fu}; return g[column]; }
    case 'X': { static const UINT8 g[] = {0x63u, 0x14u, 0x08u, 0x14u, 0x63u}; return g[column]; }
    case 'Y': { static const UINT8 g[] = {0x07u, 0x08u, 0x70u, 0x08u, 0x07u}; return g[column]; }
    case 'Z': { static const UINT8 g[] = {0x61u, 0x51u, 0x49u, 0x45u, 0x43u}; return g[column]; }
    case '-': { static const UINT8 g[] = {0x08u, 0x08u, 0x08u, 0x08u, 0x08u}; return g[column]; }
    case ':': { static const UINT8 g[] = {0x00u, 0x36u, 0x36u, 0x00u, 0x00u}; return g[column]; }
    case '.': { static const UINT8 g[] = {0x00u, 0x60u, 0x60u, 0x00u, 0x00u}; return g[column]; }
    case '_': { static const UINT8 g[] = {0x40u, 0x40u, 0x40u, 0x40u, 0x40u}; return g[column]; }
    default:
      return ER_ST7789_GLYPH_SPACE;
  }
}

UINT8 er_st7789_init(const ErSt7789Bus* bus) {
  UINT8 data;

  if (er_st7789_bus_valid(bus) == 0u ||
      bus->write_command(bus->ctx, ER_ST7789_CMD_SWRESET) == 0u) {
    return 0u;
  }
  er_st7789_delay(bus, ER_ST7789_RESET_DELAY_TICKS);
  if (bus->write_command(bus->ctx, ER_ST7789_CMD_SLPOUT) == 0u) {
    return 0u;
  }
  er_st7789_delay(bus, ER_ST7789_SLEEP_OUT_DELAY_TICKS);
  data = ER_ST7789_COLMOD_RGB565;
  if (er_st7789_command_data(bus, ER_ST7789_CMD_COLMOD, &data, ER_ST7789_COMMAND_BYTES_1) == 0u) {
    return 0u;
  }
  data = ER_ST7789_MADCTL_RGB;
  if (er_st7789_command_data(bus, ER_ST7789_CMD_MADCTL, &data, ER_ST7789_COMMAND_BYTES_1) == 0u ||
      bus->write_command(bus->ctx, ER_ST7789_CMD_INVON) == 0u ||
      bus->write_command(bus->ctx, ER_ST7789_CMD_NORON) == 0u ||
      bus->write_command(bus->ctx, ER_ST7789_CMD_DISPON) == 0u) {
    return 0u;
  }
  er_st7789_delay(bus, ER_ST7789_DISPLAY_ON_DELAY_TICKS);
  return 1u;
}

UINT8 er_st7789_fill_rect(const ErSt7789Bus* bus,
                          UINT16 x,
                          UINT16 y,
                          UINT16 width,
                          UINT16 height,
                          UINT16 color) {
  UINT8 pixel[ER_ST7789_COLOR_BYTES];
  UINT32 pixels;
  UINT32 i;

  if (er_st7789_bus_valid(bus) == 0u || width == 0u || height == 0u ||
      (UINT32)x + (UINT32)width > ER_ST7789_WIDTH ||
      (UINT32)y + (UINT32)height > ER_ST7789_HEIGHT) {
    return 0u;
  }
  if (er_st7789_set_window(bus, x, y, (UINT16)(x + width - 1u),
                           (UINT16)(y + height - 1u)) == 0u) {
    return 0u;
  }
  er_st7789_put_u16(pixel, color);
  pixels = (UINT32)width * (UINT32)height;
  for (i = 0u; i < pixels; ++i) {
    if (bus->write_data(bus->ctx, pixel, ER_ST7789_COLOR_BYTES) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_st7789_draw_text(const ErSt7789Bus* bus,
                          UINT16 x,
                          UINT16 y,
                          const char* text,
                          UINT8 scale,
                          UINT16 fg,
                          UINT16 bg) {
  UINT32 index;
  UINT32 column;
  UINT32 row;
  UINT16 px;
  UINT16 py;
  UINT8 bits;
  UINT16 color;

  if (er_st7789_bus_valid(bus) == 0u || text == 0 || scale == 0u) {
    return 0u;
  }
  index = 0u;
  while (text[index] != '\0') {
    for (column = 0u; column < ER_ST7789_GLYPH_COLUMNS; ++column) {
      bits = er_st7789_glyph_column(text[index], column) & ER_ST7789_GLYPH_COLUMN_MASK;
      for (row = 0u; row < ER_ST7789_GLYPH_ROWS; ++row) {
        color = ((bits >> row) & 1u) != 0u ? fg : bg;
        px = (UINT16)(x + ((index * ER_ST7789_GLYPH_ADVANCE) + column) * scale);
        py = (UINT16)(y + row * scale);
        if (er_st7789_fill_rect(bus, px, py, scale, scale, color) == 0u) {
          return 0u;
        }
      }
    }
    ++index;
  }
  return 1u;
}

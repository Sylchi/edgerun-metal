#include "er_gfx_console.h"
#include "er_mem.h"

/*
 * Purpose: draw a small fixed-cell terminal directly into GOP framebuffer memory.
 * Intention: make PXE/UEFI diagnostics readable on 4K displays while preserving firmware console output.
 */

#define ER_GFX_COLS 480u
#define ER_GFX_ROWS 200u
#define ER_GFX_GLYPH_W 5u
#define ER_GFX_GLYPH_H 7u
#define ER_GFX_CELL_W 6u
#define ER_GFX_CELL_H 8u
#define ER_GFX_MIN_SCALE 1u
#define ER_GFX_RGB_SHIFT_R 16u
#define ER_GFX_RGB_SHIFT_G 8u
#define ER_GFX_COLOR_BLACK 0u
#define ER_GFX_COLOR_WHITE 255u
#define ER_GFX_CENTER_DIVISOR 2u
#define ER_GFX_ASCII_MIN_PRINTABLE 32u
#define ER_GFX_ASCII_MAX_PRINTABLE 126u
#define ER_GFX_DIGIT_COUNT 10u
#define ER_GFX_UPPER_COUNT 26u

static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au} //@optimizer-ignore UEFI graphics output protocol GUID
};

static UINT8 g_ready;
static UINT8 g_bgr;
static UINT32 g_width;
static UINT32 g_height;
static UINT32 g_stride;
static UINT32 g_scale;
static UINT32 g_origin_x;
static UINT32 g_origin_y;
static UINT32* g_pixels;
static UINTN g_col;
static UINTN g_row;
static char g_cells[ER_GFX_ROWS][ER_GFX_COLS];

static UINT32 er_gfx_rgb(UINT8 r, UINT8 g, UINT8 b) {
  if (g_bgr != 0u) {
    return ((UINT32)b << ER_GFX_RGB_SHIFT_R) | ((UINT32)g << ER_GFX_RGB_SHIFT_G) | (UINT32)r;
  }
  return ((UINT32)r << ER_GFX_RGB_SHIFT_R) | ((UINT32)g << ER_GFX_RGB_SHIFT_G) | (UINT32)b;
}

static UINT32 er_gfx_console_width(void) {
  return ER_GFX_COLS * ER_GFX_CELL_W * g_scale;
}

static UINT32 er_gfx_console_height(void) {
  return ER_GFX_ROWS * ER_GFX_CELL_H * g_scale;
}

static UINT32 er_gfx_visible_width(UINT32 x, UINT32 w) {
  if (x >= g_width) {
    return 0u;
  }
  if (w > g_width - x) {
    return g_width - x;
  }
  return w;
}

static UINT32 er_gfx_visible_height(UINT32 y, UINT32 h) {
  if (y >= g_height) {
    return 0u;
  }
  if (h > g_height - y) {
    return g_height - y;
  }
  return h;
}

//@optimizer-ignore-function GOP framebuffer fill must visit each visible pixel in the rectangle
static void er_gfx_fill_rect(UINT32 x, UINT32 y, UINT32 w, UINT32 h, UINT32 color) {
  UINT32 clipped_w = er_gfx_visible_width(x, w);
  UINT32 clipped_h = er_gfx_visible_height(y, h);
  UINT32 yy;
  UINT32 xx;

  for (yy = 0u; yy < clipped_h; ++yy) {
    UINT32* row = &g_pixels[((UINTN)(y + yy) * (UINTN)g_stride) + (UINTN)x];

    for (xx = 0u; xx < clipped_w; ++xx) {
      row[xx] = color;
    }
  }
}

static UINT8 er_gfx_row_bits(char c, UINTN row) {
  static const UINT8 space[ER_GFX_GLYPH_H] = {0, 0, 0, 0, 0, 0, 0}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 unknown[ER_GFX_GLYPH_H] = {14, 17, 1, 2, 4, 0, 4}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 digit[ER_GFX_DIGIT_COUNT][ER_GFX_GLYPH_H] = {
    {14, 17, 19, 21, 25, 17, 14}, {4, 12, 4, 4, 4, 4, 14}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 1, 2, 4, 8, 31},    {30, 1, 1, 14, 1, 1, 30}, //@optimizer-ignore 5x7 bitmap glyph rows
    {2, 6, 10, 18, 31, 2, 2},    {31, 16, 30, 1, 1, 17, 14}, //@optimizer-ignore 5x7 bitmap glyph rows
    {6, 8, 16, 30, 17, 17, 14},  {31, 1, 2, 4, 8, 8, 8}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 17, 14, 17, 17, 14}, {14, 17, 17, 15, 1, 2, 12} //@optimizer-ignore 5x7 bitmap glyph rows
  };
  static const UINT8 upper[ER_GFX_UPPER_COUNT][ER_GFX_GLYPH_H] = {
    {14, 17, 17, 31, 17, 17, 17}, {30, 17, 17, 30, 17, 17, 30}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 16, 16, 16, 17, 14}, {30, 17, 17, 17, 17, 17, 30}, //@optimizer-ignore 5x7 bitmap glyph rows
    {31, 16, 16, 30, 16, 16, 31}, {31, 16, 16, 30, 16, 16, 16}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 16, 23, 17, 17, 15}, {17, 17, 17, 31, 17, 17, 17}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 4, 4, 4, 4, 4, 14},      {7, 2, 2, 2, 18, 18, 12}, //@optimizer-ignore 5x7 bitmap glyph rows
    {17, 18, 20, 24, 20, 18, 17}, {16, 16, 16, 16, 16, 16, 31}, //@optimizer-ignore 5x7 bitmap glyph rows
    {17, 27, 21, 21, 17, 17, 17}, {17, 25, 21, 19, 17, 17, 17}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 17, 17, 17, 17, 14}, {30, 17, 17, 30, 16, 16, 16}, //@optimizer-ignore 5x7 bitmap glyph rows
    {14, 17, 17, 17, 21, 18, 13}, {30, 17, 17, 30, 20, 18, 17}, //@optimizer-ignore 5x7 bitmap glyph rows
    {15, 16, 16, 14, 1, 1, 30},   {31, 4, 4, 4, 4, 4, 4}, //@optimizer-ignore 5x7 bitmap glyph rows
    {17, 17, 17, 17, 17, 17, 14}, {17, 17, 17, 17, 17, 10, 4}, //@optimizer-ignore 5x7 bitmap glyph rows
    {17, 17, 17, 21, 21, 21, 10}, {17, 17, 10, 4, 10, 17, 17}, //@optimizer-ignore 5x7 bitmap glyph rows
    {17, 17, 10, 4, 4, 4, 4},     {31, 1, 2, 4, 8, 16, 31} //@optimizer-ignore 5x7 bitmap glyph rows
  };
  static const UINT8 colon[ER_GFX_GLYPH_H] = {0, 4, 4, 0, 4, 4, 0}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 dash[ER_GFX_GLYPH_H] = {0, 0, 0, 31, 0, 0, 0}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 dot[ER_GFX_GLYPH_H] = {0, 0, 0, 0, 0, 12, 12}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 slash[ER_GFX_GLYPH_H] = {1, 1, 2, 4, 8, 16, 16}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 eq[ER_GFX_GLYPH_H] = {0, 0, 31, 0, 31, 0, 0}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 under[ER_GFX_GLYPH_H] = {0, 0, 0, 0, 0, 0, 31}; //@optimizer-ignore 5x7 bitmap glyph rows
  static const UINT8 bang[ER_GFX_GLYPH_H] = {4, 4, 4, 4, 4, 0, 4}; //@optimizer-ignore 5x7 bitmap glyph rows
  const UINT8* glyph = unknown;

  if (row >= ER_GFX_GLYPH_H) {
    return 0;
  }
  if (c >= 'a' && c <= 'z') {
    c = (char)(c - ('a' - 'A'));
  }
  if (c == ' ') {
    glyph = space;
  } else if (c >= '0' && c <= '9') {
    glyph = digit[(UINTN)(c - '0')];
  } else if (c >= 'A' && c <= 'Z') {
    glyph = upper[(UINTN)(c - 'A')];
  } else if (c == ':') {
    glyph = colon;
  } else if (c == '-') {
    glyph = dash;
  } else if (c == '.') {
    glyph = dot;
  } else if (c == '/') {
    glyph = slash;
  } else if (c == '=') {
    glyph = eq;
  } else if (c == '_') {
    glyph = under;
  } else if (c == '!') {
    glyph = bang;
  }
  return glyph[row];
}

//@optimizer-ignore-function 5x7 glyph raster must test each glyph bit before painting framebuffer pixels
static void er_gfx_draw_cell(UINTN col, UINTN row, char c) {
  UINT32 bg = er_gfx_rgb(ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK);
  UINT32 fg = er_gfx_rgb(ER_GFX_COLOR_WHITE, ER_GFX_COLOR_WHITE, ER_GFX_COLOR_WHITE);
  UINT32 x0 = g_origin_x + (UINT32)col * ER_GFX_CELL_W * g_scale;
  UINT32 y0 = g_origin_y + (UINT32)row * ER_GFX_CELL_H * g_scale;
  UINTN gy;
  UINTN gx;

  er_gfx_fill_rect(x0, y0, ER_GFX_CELL_W * g_scale, ER_GFX_CELL_H * g_scale, bg);
  for (gy = 0; gy < ER_GFX_GLYPH_H; ++gy) {
    UINT8 bits = er_gfx_row_bits(c, gy);
    for (gx = 0; gx < ER_GFX_GLYPH_W; ++gx) {
      if ((bits & (UINT8)(1u << (ER_GFX_GLYPH_W - 1u - gx))) != 0u) {
        er_gfx_fill_rect(x0 + (UINT32)gx * g_scale, y0 + (UINT32)gy * g_scale, g_scale, g_scale, fg);
      }
    }
  }
}

//@optimizer-ignore-function full console repaint is limited to initialization after GOP discovery
static void er_gfx_redraw(void) {
  UINTN row;
  UINTN col;

  er_gfx_fill_rect(0, 0, g_width, g_height,
                   er_gfx_rgb(ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK));
  for (row = 0; row < ER_GFX_ROWS; ++row) {
    for (col = 0; col < ER_GFX_COLS; ++col) {
      er_gfx_draw_cell(col, row, g_cells[row][col]);
    }
  }
}

static void er_gfx_clear_cell_row(UINTN row) {
  UINTN col;

  for (col = 0u; col < ER_GFX_COLS; ++col) {
    g_cells[row][col] = ' ';
  }
}

static void er_gfx_scroll_cells(void) {
  er_mem_copy((UINT8*)&g_cells[0][0], (const UINT8*)&g_cells[1][0],
              (UINTN)((ER_GFX_ROWS - 1u) * ER_GFX_COLS));
  er_gfx_clear_cell_row(ER_GFX_ROWS - 1u);
}

//@optimizer-ignore-function GOP framebuffer scroll must copy each visible pixel row in place
static void er_gfx_scroll_framebuffer(void) {
  UINT32 scroll_px = ER_GFX_CELL_H * g_scale;
  UINT32 visible_w = er_gfx_visible_width(g_origin_x, er_gfx_console_width());
  UINT32 visible_h = er_gfx_visible_height(g_origin_y, er_gfx_console_height());
  UINT32 black = er_gfx_rgb(ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK, ER_GFX_COLOR_BLACK);
  UINT32 y;
  UINT32 x;

  if (visible_w == 0u || visible_h == 0u) {
    return;
  }
  if (scroll_px >= visible_h) {
    er_gfx_fill_rect(g_origin_x, g_origin_y, visible_w, visible_h, black);
    return;
  }

  for (y = 0u; y + scroll_px < visible_h; ++y) {
    UINT32* dst = &g_pixels[((UINTN)(g_origin_y + y) * (UINTN)g_stride) + (UINTN)g_origin_x];
    UINT32* src = &g_pixels[((UINTN)(g_origin_y + y + scroll_px) * (UINTN)g_stride) + (UINTN)g_origin_x];

    for (x = 0u; x < visible_w; ++x) {
      dst[x] = src[x];
    }
  }

  er_gfx_fill_rect(g_origin_x, g_origin_y + visible_h - scroll_px, visible_w, scroll_px, black);
}

static void er_gfx_scroll(void) {
  er_gfx_scroll_cells();
  er_gfx_scroll_framebuffer();
  g_row = ER_GFX_ROWS - 1u;
  g_col = 0;
}

static void er_gfx_newline(void) {
  g_col = 0;
  ++g_row;
  if (g_row >= ER_GFX_ROWS) {
    er_gfx_scroll();
  }
}

static void er_gfx_putc(char c) {
  if (c == '\r') {
    g_col = 0;
    return;
  }
  if (c == '\n') {
    er_gfx_newline();
    return;
  }
  if ((UINT8)c < ER_GFX_ASCII_MIN_PRINTABLE || (UINT8)c > ER_GFX_ASCII_MAX_PRINTABLE) {
    c = '?';
  }
  if (g_col >= ER_GFX_COLS) {
    er_gfx_newline();
  }
  g_cells[g_row][g_col] = c;
  er_gfx_draw_cell(g_col, g_row, c);
  ++g_col;
}

void er_gfx_console_init(EFI_SYSTEM_TABLE* st) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL* gop = 0;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* info;
  UINT32 scale_x;
  UINT32 scale_y;
  UINTN row;

  g_ready = 0;
  if (st == 0 || st->BootServices == 0 || st->BootServices->LocateProtocol == 0) {
    return;
  }
  if (st->BootServices->LocateProtocol(&g_gop_guid, 0, (void**)&gop) != EFI_SUCCESS ||
      gop == 0 || gop->Mode == 0 || gop->Mode->Info == 0) {
    return;
  }

  info = gop->Mode->Info;
  if (info->PixelFormat != PixelRedGreenBlueReserved8BitPerColor &&
      info->PixelFormat != PixelBlueGreenRedReserved8BitPerColor) {
    return;
  }
  if (gop->Mode->FrameBufferBase == 0u || info->HorizontalResolution == 0u ||
      info->VerticalResolution == 0u || info->PixelsPerScanLine == 0u) {
    return;
  }

  g_width = info->HorizontalResolution;
  g_height = info->VerticalResolution;
  g_stride = info->PixelsPerScanLine;
  g_bgr = (info->PixelFormat == PixelBlueGreenRedReserved8BitPerColor) ? 1u : 0u;
  g_pixels = (UINT32*)(UINTN)gop->Mode->FrameBufferBase;

  scale_x = g_width / (ER_GFX_COLS * ER_GFX_CELL_W);
  scale_y = g_height / (ER_GFX_ROWS * ER_GFX_CELL_H);
  g_scale = (scale_x < scale_y) ? scale_x : scale_y;
  if (g_scale < ER_GFX_MIN_SCALE) {
    g_scale = ER_GFX_MIN_SCALE;
  }

  g_origin_x = (g_width > (ER_GFX_COLS * ER_GFX_CELL_W * g_scale)) ?
    (g_width - (ER_GFX_COLS * ER_GFX_CELL_W * g_scale)) / ER_GFX_CENTER_DIVISOR : 0u;
  g_origin_y = (g_height > (ER_GFX_ROWS * ER_GFX_CELL_H * g_scale)) ?
    (g_height - (ER_GFX_ROWS * ER_GFX_CELL_H * g_scale)) / ER_GFX_CENTER_DIVISOR : 0u;

  for (row = 0; row < ER_GFX_ROWS; ++row) {
    er_gfx_clear_cell_row(row);
  }
  g_col = 0;
  g_row = 0;
  g_ready = 1;
  er_gfx_redraw();
}

void er_gfx_console_set_enabled(UINT8 enabled) {
  g_ready = enabled != 0u ? g_ready : 0u;
}

void er_gfx_console_write(const char* s) {
  UINTN i;

  if (g_ready == 0 || s == 0) {
    return;
  }
  for (i = 0; s[i] != 0; ++i) {
    er_gfx_putc(s[i]);
  }
}

#include "er_gfx_console.h"

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

static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au}
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
    return ((UINT32)b << 16) | ((UINT32)g << 8) | (UINT32)r;
  }
  return ((UINT32)r << 16) | ((UINT32)g << 8) | (UINT32)b;
}

static void er_gfx_put_pixel(UINT32 x, UINT32 y, UINT32 color) {
  if (x >= g_width || y >= g_height) {
    return;
  }
  g_pixels[((UINTN)y * (UINTN)g_stride) + (UINTN)x] = color;
}

static void er_gfx_fill_rect(UINT32 x, UINT32 y, UINT32 w, UINT32 h, UINT32 color) {
  UINT32 yy;
  UINT32 xx;

  for (yy = 0; yy < h; ++yy) {
    for (xx = 0; xx < w; ++xx) {
      er_gfx_put_pixel(x + xx, y + yy, color);
    }
  }
}

static UINT8 er_gfx_row_bits(char c, UINTN row) {
  static const UINT8 space[7] = {0, 0, 0, 0, 0, 0, 0};
  static const UINT8 unknown[7] = {14, 17, 1, 2, 4, 0, 4};
  static const UINT8 digit[10][7] = {
    {14, 17, 19, 21, 25, 17, 14}, {4, 12, 4, 4, 4, 4, 14},
    {14, 17, 1, 2, 4, 8, 31},    {30, 1, 1, 14, 1, 1, 30},
    {2, 6, 10, 18, 31, 2, 2},    {31, 16, 30, 1, 1, 17, 14},
    {6, 8, 16, 30, 17, 17, 14},  {31, 1, 2, 4, 8, 8, 8},
    {14, 17, 17, 14, 17, 17, 14}, {14, 17, 17, 15, 1, 2, 12}
  };
  static const UINT8 upper[26][7] = {
    {14, 17, 17, 31, 17, 17, 17}, {30, 17, 17, 30, 17, 17, 30},
    {14, 17, 16, 16, 16, 17, 14}, {30, 17, 17, 17, 17, 17, 30},
    {31, 16, 16, 30, 16, 16, 31}, {31, 16, 16, 30, 16, 16, 16},
    {14, 17, 16, 23, 17, 17, 15}, {17, 17, 17, 31, 17, 17, 17},
    {14, 4, 4, 4, 4, 4, 14},      {7, 2, 2, 2, 18, 18, 12},
    {17, 18, 20, 24, 20, 18, 17}, {16, 16, 16, 16, 16, 16, 31},
    {17, 27, 21, 21, 17, 17, 17}, {17, 25, 21, 19, 17, 17, 17},
    {14, 17, 17, 17, 17, 17, 14}, {30, 17, 17, 30, 16, 16, 16},
    {14, 17, 17, 17, 21, 18, 13}, {30, 17, 17, 30, 20, 18, 17},
    {15, 16, 16, 14, 1, 1, 30},   {31, 4, 4, 4, 4, 4, 4},
    {17, 17, 17, 17, 17, 17, 14}, {17, 17, 17, 17, 17, 10, 4},
    {17, 17, 17, 21, 21, 21, 10}, {17, 17, 10, 4, 10, 17, 17},
    {17, 17, 10, 4, 4, 4, 4},     {31, 1, 2, 4, 8, 16, 31}
  };
  static const UINT8 colon[7] = {0, 4, 4, 0, 4, 4, 0};
  static const UINT8 dash[7] = {0, 0, 0, 31, 0, 0, 0};
  static const UINT8 dot[7] = {0, 0, 0, 0, 0, 12, 12};
  static const UINT8 slash[7] = {1, 1, 2, 4, 8, 16, 16};
  static const UINT8 eq[7] = {0, 0, 31, 0, 31, 0, 0};
  static const UINT8 under[7] = {0, 0, 0, 0, 0, 0, 31};
  static const UINT8 bang[7] = {4, 4, 4, 4, 4, 0, 4};
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

static void er_gfx_draw_cell(UINTN col, UINTN row, char c) {
  UINT32 bg = er_gfx_rgb(0, 0, 0);
  UINT32 fg = er_gfx_rgb(255, 255, 255);
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

static void er_gfx_redraw(void) {
  UINTN row;
  UINTN col;

  er_gfx_fill_rect(0, 0, g_width, g_height, er_gfx_rgb(0, 0, 0));
  for (row = 0; row < ER_GFX_ROWS; ++row) {
    for (col = 0; col < ER_GFX_COLS; ++col) {
      er_gfx_draw_cell(col, row, g_cells[row][col]);
    }
  }
}

static void er_gfx_scroll(void) {
  UINTN row;
  UINTN col;

  for (row = 1; row < ER_GFX_ROWS; ++row) {
    for (col = 0; col < ER_GFX_COLS; ++col) {
      g_cells[row - 1u][col] = g_cells[row][col];
    }
  }
  for (col = 0; col < ER_GFX_COLS; ++col) {
    g_cells[ER_GFX_ROWS - 1u][col] = ' ';
  }
  g_row = ER_GFX_ROWS - 1u;
  g_col = 0;
  er_gfx_redraw();
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
  if ((UINT8)c < 32u || (UINT8)c > 126u) {
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
  UINTN col;

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
    (g_width - (ER_GFX_COLS * ER_GFX_CELL_W * g_scale)) / 2u : 0u;
  g_origin_y = (g_height > (ER_GFX_ROWS * ER_GFX_CELL_H * g_scale)) ?
    (g_height - (ER_GFX_ROWS * ER_GFX_CELL_H * g_scale)) / 2u : 0u;

  for (row = 0; row < ER_GFX_ROWS; ++row) {
    for (col = 0; col < ER_GFX_COLS; ++col) {
      g_cells[row][col] = ' ';
    }
  }
  g_col = 0;
  g_row = 0;
  g_ready = 1;
  er_gfx_redraw();
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

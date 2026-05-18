#include "er_ui_gop_renderer.h"
#include "er_ui_icon.h"
#include "er_math.h"

#define ER_UI_GOP_BYTES_PER_PIXEL 4u
#define ER_UI_GOP_COLOR_BYTE_MASK 0xffu
#define ER_UI_GOP_COLOR_BYTE_MAX 255u
#define ER_UI_GOP_BLEND_ROUND_BIAS 127u
#define ER_UI_GOP_COLOR_GREEN_SHIFT 8u
#define ER_UI_GOP_COLOR_RED_SHIFT 16u
#define ER_UI_GOP_SHADOW_LAYERS 3u
#define ER_UI_GOP_ICON_GRID_SIZE 24u
#define ER_UI_GOP_ICON_GRID_HALF 12u
#define ER_UI_GOP_ICON_STROKE_DIVISOR 7u
#define ER_UI_GOP_MSDF_RGB_CHANNELS 3u
#define ER_UI_GOP_MSDF_ALPHA_LOW 96u
#define ER_UI_GOP_MSDF_ALPHA_HIGH 160u
#define ER_UI_GOP_MSDF_ALPHA_RANGE (ER_UI_GOP_MSDF_ALPHA_HIGH - ER_UI_GOP_MSDF_ALPHA_LOW)
#define ER_UI_GOP_DIRTY_TILE_ID_BYTES 4u

//@optimizer-ignore-constant UEFI GOP protocol GUID is ABI-defined by firmware
static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au}
};

static ErUiGopSurface g_surface;
static UINT8 g_ready;

static UINT8 er_ui_gop_surface_render_scene_with_atlas_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas, ErUiGopRenderStats* stats);
static UINT8 er_ui_gop_clip_rect_to(const ErUiGopSurface* surface, const ErUiGopPixelRect* clip,
                                    float x, float y, float w, float h,
                                    UINT32* out_x0, UINT32* out_y0, UINT32* out_x1, UINT32* out_y1);
static void er_ui_gop_border_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                  er_ui_color4_t color, ErUiGopRenderStats* stats);

static float er_ui_gop_clamp01(float value) {
  return er_math_clamp01f(value);
}

static UINT8 er_ui_gop_u8_from_unit(float value) {
  return (UINT8)er_math_u8_from_unitf(value);
}

static UINT32 er_ui_gop_texel_coord(float coord, UINT32 limit) {
  UINT32 out;

  if (limit == 0u) return 0u;
  coord = er_ui_gop_clamp01(coord);
  out = (UINT32)(coord * (float)limit);
  if (out >= limit) out = limit - 1u;
  return out;
}

static void er_ui_gop_stats_add_pixels(ErUiGopRenderStats* stats, UINT64 pixels, UINT8 blended, UINT8 text) {
  if (stats == 0 || pixels == 0u) return;
  stats->pixels_written += pixels;
  stats->bytes_written += pixels * ER_UI_GOP_BYTES_PER_PIXEL;
  if (blended != 0u) stats->blend_pixels += pixels;
  if (text != 0u) stats->text_pixels += pixels;
}

static void er_ui_gop_stats_add(ErUiGopRenderStats* dst, const ErUiGopRenderStats* src) {
  if (dst == 0 || src == 0) return;
  dst->pixels_written += src->pixels_written;
  dst->bytes_written += src->bytes_written;
  dst->blend_pixels += src->blend_pixels;
  dst->text_pixels += src->text_pixels;
  dst->clears += src->clears;
  dst->rects += src->rects;
  dst->solid_rects += src->solid_rects;
  dst->gradient_rects += src->gradient_rects;
  dst->border_rects += src->border_rects;
  dst->icon_quads += src->icon_quads;
  dst->text_quads += src->text_quads;
  dst->tiles_rendered += src->tiles_rendered;
  dst->dirty_tiles_requested += src->dirty_tiles_requested;
  dst->clipped_primitives += src->clipped_primitives;
  dst->rejected_primitives += src->rejected_primitives;
}

static UINT8 er_ui_gop_memory_violation(const char* name, UINT64 actual, UINT64 limit,
                                        ErUiGopMemoryBudgetViolation* out_violation) {
  if (actual <= limit) {
    return 0u;
  }
  if (out_violation != 0) {
    out_violation->name = name;
    out_violation->actual = actual;
    out_violation->limit = limit;
  }
  return 1u;
}

static UINT8 er_ui_gop_frame_violation(const char* name, UINT64 actual, UINT64 limit,
                                       ErUiGopFrameBudgetViolation* out_violation) {
  if (actual <= limit) {
    return 0u;
  }
  if (out_violation != 0) {
    out_violation->name = name;
    out_violation->actual = actual;
    out_violation->limit = limit;
  }
  return 1u;
}

static INT64 er_ui_gop_floor_i64(float value) {
  return (INT64)er_math_floor_i64(value);
}

static INT64 er_ui_gop_ceil_i64(float value) {
  return (INT64)er_math_ceil_i64(value);
}

static UINT8 er_ui_gop_clip_rect_to(const ErUiGopSurface* surface, const ErUiGopPixelRect* clip,
                                    float x, float y, float w, float h,
                                    UINT32* out_x0, UINT32* out_y0, UINT32* out_x1, UINT32* out_y1) {
  INT64 x0;
  INT64 y0;
  INT64 x1;
  INT64 y1;
  UINT32 clip_x0 = 0u;
  UINT32 clip_y0 = 0u;
  UINT32 clip_x1;
  UINT32 clip_y1;

  if (!er_ui_gop_surface_valid(surface) || out_x0 == 0 || out_y0 == 0 || out_x1 == 0 || out_y1 == 0 ||
      !(w > 0.0f) || !(h > 0.0f)) {
    return 0u;
  }
  clip_x1 = surface->width;
  clip_y1 = surface->height;
  if (clip != 0) {
    clip_x0 = clip->x0;
    clip_y0 = clip->y0;
    clip_x1 = clip->x1;
    clip_y1 = clip->y1;
    if (clip_x0 > surface->width) clip_x0 = surface->width;
    if (clip_y0 > surface->height) clip_y0 = surface->height;
    if (clip_x1 > surface->width) clip_x1 = surface->width;
    if (clip_y1 > surface->height) clip_y1 = surface->height;
    if (clip_x0 >= clip_x1 || clip_y0 >= clip_y1) return 0u;
  }

  x0 = er_ui_gop_floor_i64(x);
  y0 = er_ui_gop_floor_i64(y);
  x1 = er_ui_gop_ceil_i64(x + w);
  y1 = er_ui_gop_ceil_i64(y + h);

  if (x0 < (INT64)clip_x0) x0 = (INT64)clip_x0;
  if (y0 < (INT64)clip_y0) y0 = (INT64)clip_y0;
  if (x1 > (INT64)clip_x1) x1 = (INT64)clip_x1;
  if (y1 > (INT64)clip_y1) y1 = (INT64)clip_y1;
  if (x0 >= x1 || y0 >= y1) return 0u;

  *out_x0 = (UINT32)x0;
  *out_y0 = (UINT32)y0;
  *out_x1 = (UINT32)x1;
  *out_y1 = (UINT32)y1;
  return 1u;
}

static void er_ui_gop_unpack(ErUiGopPixelFormat format, UINT32 pixel, UINT8* r, UINT8* g, UINT8* b) {
  if (format == ER_UI_GOP_PIXEL_BGRX) {
    *b = (UINT8)((pixel >> ER_UI_GOP_COLOR_RED_SHIFT) & ER_UI_GOP_COLOR_BYTE_MASK);
    *g = (UINT8)((pixel >> ER_UI_GOP_COLOR_GREEN_SHIFT) & ER_UI_GOP_COLOR_BYTE_MASK);
    *r = (UINT8)(pixel & ER_UI_GOP_COLOR_BYTE_MASK);
    return;
  }
  *r = (UINT8)((pixel >> ER_UI_GOP_COLOR_RED_SHIFT) & ER_UI_GOP_COLOR_BYTE_MASK);
  *g = (UINT8)((pixel >> ER_UI_GOP_COLOR_GREEN_SHIFT) & ER_UI_GOP_COLOR_BYTE_MASK);
  *b = (UINT8)(pixel & ER_UI_GOP_COLOR_BYTE_MASK);
}

static UINT32 er_ui_gop_blend_pixel(ErUiGopPixelFormat format, UINT32 dst, er_ui_color4_t src) {
  UINT8 dr;
  UINT8 dg;
  UINT8 db;
  UINT8 sr = er_ui_gop_u8_from_unit(src.r);
  UINT8 sg = er_ui_gop_u8_from_unit(src.g);
  UINT8 sb = er_ui_gop_u8_from_unit(src.b);
  UINT32 a = (UINT32)er_ui_gop_u8_from_unit(src.a);
  UINT32 inv = ER_UI_GOP_COLOR_BYTE_MAX - a;

  if (a >= ER_UI_GOP_COLOR_BYTE_MAX) {
    return er_ui_gop_pack_rgb(format, sr, sg, sb);
  }

  er_ui_gop_unpack(format, dst, &dr, &dg, &db);
  return er_ui_gop_pack_rgb(format,
                            (UINT8)(((UINT32)sr * a + (UINT32)dr * inv +
                                     ER_UI_GOP_BLEND_ROUND_BIAS) /
                                    ER_UI_GOP_COLOR_BYTE_MAX),
                            (UINT8)(((UINT32)sg * a + (UINT32)dg * inv +
                                     ER_UI_GOP_BLEND_ROUND_BIAS) /
                                    ER_UI_GOP_COLOR_BYTE_MAX),
                            (UINT8)(((UINT32)sb * a + (UINT32)db * inv +
                                     ER_UI_GOP_BLEND_ROUND_BIAS) /
                                    ER_UI_GOP_COLOR_BYTE_MAX));
}

//@optimizer-ignore-function GOP rectangle raster must blend each covered framebuffer pixel
static void er_ui_gop_fill_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                er_ui_color4_t color, ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  UINT64 pixels;

  pixels = (UINT64)(x1 - x0) * (UINT64)(y1 - y0);
  er_ui_gop_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
    }
  }
}

static INT64 er_ui_gop_abs_i64(INT64 value) {
  return value < 0 ? -value : value;
}

static UINT8 er_ui_gop_point_in_round_rect(INT64 x, INT64 y, INT64 x0, INT64 y0, INT64 x1, INT64 y1, INT64 radius) {
  INT64 cx;
  INT64 cy;
  INT64 dx;
  INT64 dy;

  if (x < x0 || y < y0 || x >= x1 || y >= y1) return 0u;
  if (radius <= 0 || radius * 2 >= x1 - x0 || radius * 2 >= y1 - y0) {
    if (radius <= 0) return 1u;
    radius = (x1 - x0 < y1 - y0 ? x1 - x0 : y1 - y0) / 2;
  }
  if (x >= x0 + radius && x < x1 - radius) return 1u;
  if (y >= y0 + radius && y < y1 - radius) return 1u;

  cx = x < x0 + radius ? x0 + radius : x1 - radius - 1;
  cy = y < y0 + radius ? y0 + radius : y1 - radius - 1;
  dx = x - cx;
  dy = y - cy;
  return (dx * dx + dy * dy <= radius * radius) ? 1u : 0u;
}

//@optimizer-ignore-function rounded GOP raster must test and blend each covered framebuffer pixel
static void er_ui_gop_fill_round_rect(ErUiGopSurface* surface,
                                      UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                      UINT32 full_x0, UINT32 full_y0, UINT32 full_x1, UINT32 full_y1,
                                      float radius, er_ui_color4_t color, ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  INT64 r = er_ui_gop_ceil_i64(radius);
  UINT64 pixels = 0u;

  if (r <= 0) {
    er_ui_gop_fill_rect(surface, x0, y0, x1, y1, color, stats);
    return;
  }
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      if (er_ui_gop_point_in_round_rect((INT64)x, (INT64)y, (INT64)full_x0, (INT64)full_y0, (INT64)full_x1, (INT64)full_y1, r) != 0u) {
        row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
        ++pixels;
      }
    }
  }
  er_ui_gop_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
}

//@optimizer-ignore-function rounded GOP border raster must test outer and inner bounds per covered framebuffer pixel
static void er_ui_gop_border_round_rect(ErUiGopSurface* surface,
                                        UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                        UINT32 full_x0, UINT32 full_y0, UINT32 full_x1, UINT32 full_y1,
                                        float radius, er_ui_color4_t color, ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  INT64 r = er_ui_gop_ceil_i64(radius);
  INT64 inner_r = r > 0 ? r - 1 : 0;
  UINT64 pixels = 0u;

  if (r <= 0) {
    er_ui_gop_border_rect(surface, x0, y0, x1, y1, color, stats);
    return;
  }
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      UINT8 outer = er_ui_gop_point_in_round_rect((INT64)x, (INT64)y, (INT64)full_x0, (INT64)full_y0, (INT64)full_x1, (INT64)full_y1, r);
      UINT8 inner = er_ui_gop_point_in_round_rect((INT64)x, (INT64)y, (INT64)full_x0 + 1, (INT64)full_y0 + 1,
                                                  (INT64)full_x1 - 1, (INT64)full_y1 - 1, inner_r);
      if (outer != 0u && inner == 0u) {
        row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
        ++pixels;
      }
    }
  }
  er_ui_gop_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
}

//@optimizer-ignore-function shadow rendering uses a fixed three-layer raster pass for deterministic GOP output
static void er_ui_gop_shadow_round_rect(ErUiGopSurface* surface, const ErUiGopPixelRect* clip,
                                        er_ui_rect_t rect, ErUiGopRenderStats* stats) {
  UINT32 layer;
  float spread = rect.shadow > 0.0f ? rect.shadow : 14.0f;

  for (layer = ER_UI_GOP_SHADOW_LAYERS; layer > 0u; --layer) {
    UINT32 x0;
    UINT32 y0;
    UINT32 x1;
    UINT32 y1;
    UINT32 full_x0;
    UINT32 full_y0;
    UINT32 full_x1;
    UINT32 full_y1;
    float k = (float)layer / (float)ER_UI_GOP_SHADOW_LAYERS;
    float inset = spread * k * 0.40f;
    float alpha = 0.065f * k;
    er_ui_color4_t color = er_ui_color_rgba(0.0f, 0.0f, 0.0f, alpha);
    float sx = rect.x - inset * 0.55f;
    float sy = rect.y + inset * 0.35f;
    float sw = rect.w + inset * 1.10f;
    float sh = rect.h + inset * 1.10f;

    if (er_ui_gop_clip_rect_to(surface, clip, sx, sy, sw, sh, &x0, &y0, &x1, &y1) == 0u ||
        er_ui_gop_clip_rect_to(surface, 0, sx, sy, sw, sh, &full_x0, &full_y0, &full_x1, &full_y1) == 0u) {
      continue;
    }
    er_ui_gop_border_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius + inset, color, stats);
  }
}

static er_ui_color4_t er_ui_gop_lerp_color(er_ui_color4_t a, er_ui_color4_t b, float t) {
  er_ui_color4_t out;
  float k = er_ui_gop_clamp01(t);
  out.r = a.r + (b.r - a.r) * k;
  out.g = a.g + (b.g - a.g) * k;
  out.b = a.b + (b.b - a.b) * k;
  out.a = a.a + (b.a - a.a) * k;
  return out;
}

//@optimizer-ignore-function GOP gradient raster must interpolate and blend each covered framebuffer pixel
static void er_ui_gop_gradient_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                    float source_x, float source_w,
                                    er_ui_color4_t from, er_ui_color4_t to, ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  float span = source_w > 1.0f ? source_w - 1.0f : 1.0f;
  UINT64 pixels = (UINT64)(x1 - x0) * (UINT64)(y1 - y0);

  er_ui_gop_stats_add_pixels(stats, pixels, (from.a < 1.0f || to.a < 1.0f) ? 1u : 0u, 0u);
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      er_ui_color4_t color = er_ui_gop_lerp_color(from, to, ((float)x - source_x) / span);
      row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
    }
  }
}

static void er_ui_gop_border_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                  er_ui_color4_t color, ErUiGopRenderStats* stats) {
  if (x0 >= x1 || y0 >= y1) return;
  er_ui_gop_fill_rect(surface, x0, y0, x1, y0 + 1u, color, stats);
  if (y1 > y0 + 1u) er_ui_gop_fill_rect(surface, x0, y1 - 1u, x1, y1, color, stats);
  if (y1 > y0 + 2u) {
    er_ui_gop_fill_rect(surface, x0, y0 + 1u, x0 + 1u, y1 - 1u, color, stats);
    if (x1 > x0 + 1u) er_ui_gop_fill_rect(surface, x1 - 1u, y0 + 1u, x1, y1 - 1u, color, stats);
  }
}

static void er_ui_gop_render_rect(ErUiGopSurface* surface, er_ui_rect_t rect,
                                  const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  UINT32 full_x0;
  UINT32 full_y0;
  UINT32 full_x1;
  UINT32 full_y1;

  if (er_ui_gop_clip_rect_to(surface, clip, rect.x, rect.y, rect.w, rect.h, &x0, &y0, &x1, &y1) == 0u) {
    if (clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (clip != 0 && stats != 0 &&
      er_ui_gop_clip_rect_to(surface, 0, rect.x, rect.y, rect.w, rect.h,
                             &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }

  if (stats != 0) ++stats->rects;
  switch (rect.mode) {
    case ER_UI_RECT_BORDER:
      if (stats != 0) ++stats->border_rects;
      er_ui_gop_border_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      break;
    case ER_UI_RECT_LINEAR_GRADIENT:
      if (stats != 0) ++stats->gradient_rects;
      if (rect.radius > 0.0f) {
        er_ui_gop_fill_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      } else {
        er_ui_gop_gradient_rect(surface, x0, y0, x1, y1, rect.x, rect.w, rect.color, rect.color2, stats);
      }
      break;
    case ER_UI_RECT_SHADOW:
      er_ui_gop_shadow_round_rect(surface, clip, rect, stats);
      break;
    case ER_UI_RECT_FILL:
    default:
      if (stats != 0) ++stats->solid_rects;
      er_ui_gop_fill_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      break;
  }
}

static void er_ui_gop_draw_point(ErUiGopSurface* surface, INT32 x, INT32 y, UINT32 stroke,
                                 er_ui_color4_t color, const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  UINT32 half = stroke / 2u;
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  if (er_ui_gop_clip_rect_to(surface, clip, (float)x - (float)half, (float)y - (float)half,
                             (float)stroke, (float)stroke, &x0, &y0, &x1, &y1) == 0u) {
    return;
  }
  er_ui_gop_fill_rect(surface, x0, y0, x1, y1, color, stats);
}

//@optimizer-ignore-function Bresenham icon line raster must emit each covered point in order
static void er_ui_gop_draw_line(ErUiGopSurface* surface, INT32 x0, INT32 y0, INT32 x1, INT32 y1,
                                UINT32 stroke, er_ui_color4_t color, const ErUiGopPixelRect* clip,
                                ErUiGopRenderStats* stats) {
  INT32 dx = (INT32)er_ui_gop_abs_i64((INT64)x1 - (INT64)x0);
  INT32 sx = x0 < x1 ? 1 : -1;
  INT32 dy = -(INT32)er_ui_gop_abs_i64((INT64)y1 - (INT64)y0);
  INT32 sy = y0 < y1 ? 1 : -1;
  INT32 err = dx + dy;

  for (;;) {
    INT32 e2;
    er_ui_gop_draw_point(surface, x0, y0, stroke, color, clip, stats);
    if (x0 == x1 && y0 == y1) break;
    e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
}

static INT32 er_ui_gop_icon_x(UINT32 x0, UINT32 w, INT32 value) {
  return (INT32)x0 + (INT32)(((UINT64)w * (UINT64)(UINT32)value + ER_UI_GOP_ICON_GRID_HALF) /
                             ER_UI_GOP_ICON_GRID_SIZE);
}

static INT32 er_ui_gop_icon_y(UINT32 y0, UINT32 h, INT32 value) {
  return (INT32)y0 + (INT32)(((UINT64)h * (UINT64)(UINT32)value + ER_UI_GOP_ICON_GRID_HALF) /
                             ER_UI_GOP_ICON_GRID_SIZE);
}

static void er_ui_gop_icon_line(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 w, UINT32 h,
                                INT32 ax, INT32 ay, INT32 bx, INT32 by, UINT32 stroke,
                                er_ui_color4_t color, const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  er_ui_gop_draw_line(surface, er_ui_gop_icon_x(x0, w, ax), er_ui_gop_icon_y(y0, h, ay),
                      er_ui_gop_icon_x(x0, w, bx), er_ui_gop_icon_y(y0, h, by), stroke, color, clip, stats);
}

static void er_ui_gop_icon_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 w, UINT32 h,
                                INT32 ax, INT32 ay, INT32 bx, INT32 by, UINT32 stroke,
                                er_ui_color4_t color, const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  er_ui_gop_icon_line(surface, x0, y0, w, h, ax, ay, bx, ay, stroke, color, clip, stats);
  er_ui_gop_icon_line(surface, x0, y0, w, h, bx, ay, bx, by, stroke, color, clip, stats);
  er_ui_gop_icon_line(surface, x0, y0, w, h, bx, by, ax, by, stroke, color, clip, stats);
  er_ui_gop_icon_line(surface, x0, y0, w, h, ax, by, ax, ay, stroke, color, clip, stats);
}

//@optimizer-ignore-function icon circle raster must test each pixel in the bounded icon radius box
static void er_ui_gop_icon_circle(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 w, UINT32 h,
                                  INT32 cx24, INT32 cy24, INT32 r24, UINT32 stroke,
                                  er_ui_color4_t color, const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  INT32 cx = er_ui_gop_icon_x(x0, w, cx24);
  INT32 cy = er_ui_gop_icon_y(y0, h, cy24);
  INT32 rx = (INT32)(((UINT64)w * (UINT64)(UINT32)r24 + ER_UI_GOP_ICON_GRID_HALF) /
                     ER_UI_GOP_ICON_GRID_SIZE);
  INT32 ry = (INT32)(((UINT64)h * (UINT64)(UINT32)r24 + ER_UI_GOP_ICON_GRID_HALF) /
                     ER_UI_GOP_ICON_GRID_SIZE);
  INT32 r = rx < ry ? rx : ry;
  INT32 inner = r - (INT32)stroke;
  INT32 y;
  INT32 x;
  if (inner < 0) inner = 0;
  for (y = cy - r; y <= cy + r; ++y) {
    for (x = cx - r; x <= cx + r; ++x) {
      INT64 dx = (INT64)x - (INT64)cx;
      INT64 dy = (INT64)y - (INT64)cy;
      INT64 d = dx * dx + dy * dy;
      if (d <= (INT64)r * (INT64)r && d >= (INT64)inner * (INT64)inner) {
        er_ui_gop_draw_point(surface, x, y, 1u, color, clip, stats);
      }
    }
  }
}

//@optimizer-ignore-function icon vector coordinates are literal points on a 24-unit art grid
static void er_ui_gop_render_icon_quad(ErUiGopSurface* surface, const er_ui_quad_t* quad,
                                       const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  UINT32 w;
  UINT32 h;
  UINT32 stroke;
  er_ui_icon_t icon;
  UINT32 full_x0;
  UINT32 full_y0;
  UINT32 full_x1;
  UINT32 full_y1;

  if (quad == 0 || er_ui_gop_clip_rect_to(surface, clip, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    if (clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (x1 <= x0 || y1 <= y0) return;
  if (clip != 0 && stats != 0 &&
      er_ui_gop_clip_rect_to(surface, 0, quad->x, quad->y, quad->w, quad->h, &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }
  if (stats != 0) ++stats->icon_quads;

  w = x1 - x0;
  h = y1 - y0;
  stroke = w < h ? w / ER_UI_GOP_ICON_STROKE_DIVISOR : h / ER_UI_GOP_ICON_STROKE_DIVISOR;
  if (stroke == 0u) stroke = 1u;
  icon = er_ui_icon_from_atlas_id(quad->atlas_id);

  switch (icon) {
    case ER_UI_ICON_ACTIVITY:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 3, 12, 8, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 8, 12, 10, 5, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 10, 5, 14, 19, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 14, 19, 16, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 16, 12, 21, 12, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_APP:
      er_ui_gop_icon_rect(surface, x0, y0, w, h, 4, 5, 20, 19, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 9, 20, 9, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 8, 15, 11, 15, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SEARCH:
      er_ui_gop_icon_circle(surface, x0, y0, w, h, 10, 10, 6, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 15, 15, 21, 21, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CPU:
      er_ui_gop_icon_rect(surface, x0, y0, w, h, 7, 7, 17, 17, stroke, quad->color, clip, stats);
      er_ui_gop_icon_rect(surface, x0, y0, w, h, 10, 10, 14, 14, 1u, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 9, 7, 9, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 15, 7, 15, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 17, 9, 20, 9, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 17, 15, 20, 15, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 9, 4, 9, 7, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 15, 4, 15, 7, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 9, 17, 9, 20, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 15, 17, 15, 20, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_NETWORK:
      er_ui_gop_icon_circle(surface, x0, y0, w, h, 12, 5, 2, stroke, quad->color, clip, stats);
      er_ui_gop_icon_circle(surface, x0, y0, w, h, 6, 18, 2, stroke, quad->color, clip, stats);
      er_ui_gop_icon_circle(surface, x0, y0, w, h, 18, 18, 2, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 7, 6, 16, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 7, 18, 16, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 8, 18, 16, 18, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SHIELD:
    case ER_UI_ICON_TRUST:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 3, 20, 7, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 20, 7, 18, 16, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 18, 16, 12, 21, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 21, 6, 16, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 6, 16, 4, 7, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 7, 12, 3, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 8, 12, 11, 15, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 11, 15, 17, 9, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SETTINGS:
      er_ui_gop_icon_circle(surface, x0, y0, w, h, 12, 12, 4, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 2, 12, 6, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 18, 12, 22, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 2, 12, 6, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 18, 12, 22, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 5, 5, 8, 8, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 16, 16, 19, 19, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 19, 5, 16, 8, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 8, 16, 5, 19, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CHECK:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 5, 13, 10, 18, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 10, 18, 20, 7, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_X:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 6, 6, 18, 18, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 18, 6, 6, 18, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CHEVRON_RIGHT:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 9, 5, 16, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 16, 12, 9, 19, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_MENU:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 7, 20, 7, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 12, 20, 12, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 4, 17, 20, 17, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_WARNING:
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 4, 21, 20, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 21, 20, 3, 20, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 3, 20, 12, 4, stroke, quad->color, clip, stats);
      er_ui_gop_icon_line(surface, x0, y0, w, h, 12, 9, 12, 14, stroke, quad->color, clip, stats);
      er_ui_gop_draw_point(surface, er_ui_gop_icon_x(x0, w, 12), er_ui_gop_icon_y(y0, h, 17), stroke, quad->color, clip, stats);
      break;
    default:
      er_ui_gop_icon_rect(surface, x0, y0, w, h, 5, 5, 19, 19, stroke, quad->color, clip, stats);
      break;
  }
}

static const UINT8* er_ui_gop_sample_texel(const UINT8* pixels, UINT32 width, UINT32 height,
                                           UINT32 bytes_per_pixel, float u, float v) {
  UINT32 x;
  UINT32 y;

  if (pixels == 0 || width == 0u || height == 0u || bytes_per_pixel == 0u) {
    return 0;
  }
  x = er_ui_gop_texel_coord(u, width);
  y = er_ui_gop_texel_coord(v, height);
  return pixels + (((UINTN)y * (UINTN)width + (UINTN)x) * bytes_per_pixel);
}

static UINT8 er_ui_gop_sample_alpha8(const vr_font_atlas_view_t* atlas, float u, float v) {
  const UINT8* px;

  if (atlas == 0) {
    return 0u;
  }
  px = er_ui_gop_sample_texel(atlas->pixels, atlas->width, atlas->height, atlas->bytes_per_pixel, u, v);
  if (px == 0) {
    return 0u;
  }
  return px[0];
}

static UINT8 er_ui_gop_sample_msdf_alpha(const vr_font_atlas_view_t* atlas, float u, float v) {
  const UINT8* px;
  UINT8 r;
  UINT8 g;
  UINT8 b;
  UINT8 lo;
  UINT8 hi;
  UINT8 mid;

  if (atlas == 0 || atlas->pixels == 0 || atlas->width == 0u || atlas->height == 0u ||
      atlas->bytes_per_pixel < ER_UI_GOP_MSDF_RGB_CHANNELS) {
    return 0u;
  }

  px = er_ui_gop_sample_texel(atlas->pixels, atlas->width, atlas->height, atlas->bytes_per_pixel, u, v);
  if (px == 0) {
    return 0u;
  }
  r = px[0];
  g = px[1];
  b = px[2];
  lo = r < g ? r : g;
  lo = lo < b ? lo : b;
  hi = r > g ? r : g;
  hi = hi > b ? hi : b;
  mid = (UINT8)((UINT32)r + (UINT32)g + (UINT32)b - (UINT32)lo - (UINT32)hi);
  if (mid <= ER_UI_GOP_MSDF_ALPHA_LOW) return 0u;
  if (mid >= ER_UI_GOP_MSDF_ALPHA_HIGH) return ER_UI_GOP_COLOR_BYTE_MAX;
  return (UINT8)(((UINT32)(mid - ER_UI_GOP_MSDF_ALPHA_LOW) * ER_UI_GOP_COLOR_BYTE_MAX) /
                 ER_UI_GOP_MSDF_ALPHA_RANGE);
}

static UINT8 er_ui_gop_sample_atlas_alpha(const vr_font_atlas_view_t* atlas, float u, float v) {
  if (atlas == 0) return 0u;
  if (atlas->format == VR_FONT_ATLAS_FORMAT_ALPHA8) {
    return er_ui_gop_sample_alpha8(atlas, u, v);
  }
  if (atlas->format == VR_FONT_ATLAS_FORMAT_MSDF_RGB) {
    return er_ui_gop_sample_msdf_alpha(atlas, u, v);
  }
  return 0u;
}

static UINT8 er_ui_gop_sample_boot_atlas_alpha(const ErUiGopAlphaAtlas* atlas, float u, float v) {
  const UINT8* px;

  if (atlas == 0) {
    return 0u;
  }
  px = er_ui_gop_sample_texel(atlas->pixels, atlas->width, atlas->height, atlas->bytes_per_pixel, u, v);
  if (px == 0) {
    return 0u;
  }
  return px[0];
}

typedef UINT8 (*ErUiGopTextAlphaSampler)(const void* context, float u, float v);

static UINT8 er_ui_gop_sample_text_boot_alpha(const void* context, float u, float v) {
  return er_ui_gop_sample_boot_atlas_alpha((const ErUiGopAlphaAtlas*)context, u, v);
}

static UINT8 er_ui_gop_sample_text_font_alpha(const void* context, float u, float v) {
  return er_ui_gop_sample_atlas_alpha((const vr_font_atlas_view_t*)context, u, v);
}

//@optimizer-ignore-function text alpha raster must sample and blend each covered framebuffer pixel
static void er_ui_gop_render_text_quad_sampled(ErUiGopSurface* surface, const er_ui_quad_t* quad,
                                               ErUiGopTextAlphaSampler sampler, const void* sampler_context,
                                               const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  UINT32 y;
  UINT32 x;
  float width;
  float height;
  UINT32 full_x0;
  UINT32 full_y0;
  UINT32 full_x1;
  UINT32 full_y1;

  if (quad == 0 || sampler == 0 || sampler_context == 0 ||
      er_ui_gop_clip_rect_to(surface, clip, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    if (quad != 0 && sampler != 0 && sampler_context != 0 && clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (clip != 0 && stats != 0 &&
      er_ui_gop_clip_rect_to(surface, 0, quad->x, quad->y, quad->w, quad->h,
                             &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }

  width = quad->w > 1.0f ? quad->w : 1.0f;
  height = quad->h > 1.0f ? quad->h : 1.0f;
  if (stats != 0) ++stats->text_quads;
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    float ty = ((float)y + 0.5f - quad->y) / height;
    float v = quad->v0 + (quad->v1 - quad->v0) * er_ui_gop_clamp01(ty);
    for (x = x0; x < x1; ++x) {
      float tx = ((float)x + 0.5f - quad->x) / width;
      float u = quad->u0 + (quad->u1 - quad->u0) * er_ui_gop_clamp01(tx);
      UINT8 alpha = sampler(sampler_context, u, v);
      if (alpha != 0u) {
        er_ui_color4_t color = quad->color;
        color.a *= (float)alpha / 255.0f;
        er_ui_gop_stats_add_pixels(stats, 1u, color.a < 1.0f ? 1u : 0u, 1u);
        row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
      }
    }
  }
}

static void er_ui_gop_render_text_quad_with_alpha_atlas(ErUiGopSurface* surface, const er_ui_quad_t* quad,
                                                        const ErUiGopAlphaAtlas* atlas,
                                                        const ErUiGopPixelRect* clip,
                                                        ErUiGopRenderStats* stats) {
  er_ui_gop_render_text_quad_sampled(surface, quad, er_ui_gop_sample_text_boot_alpha, atlas, clip, stats);
}

static void er_ui_gop_render_text_quad(ErUiGopSurface* surface, const er_ui_quad_t* quad,
                                       const vr_font_face_t* font, const ErUiGopPixelRect* clip,
                                       ErUiGopRenderStats* stats) {
  vr_font_atlas_view_t atlas;

  if (quad == 0 || font == 0) {
    if (quad != 0 && font != 0 && clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (vr_font_atlas_view(font, quad->atlas_id, &atlas) != VR_OK) {
    return;
  }
  er_ui_gop_render_text_quad_sampled(surface, quad, er_ui_gop_sample_text_font_alpha, &atlas, clip, stats);
}

#include "er_ui_gop_planning.h"

#include "er_ui_gop_surface_render.h"
#include "er_ui_gop_backend.h"

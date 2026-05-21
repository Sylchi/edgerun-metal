#include "er_ui_surface_renderer.h"
#include "er_ui_icon.h"
#include "er_ui_tabler_icon_atlas.h"
#include "er_math.h"

#define ER_UI_SURFACE_BYTES_PER_PIXEL 4u
#define ER_UI_SURFACE_COLOR_BYTE_MASK 0xffu
#define ER_UI_SURFACE_COLOR_BYTE_MAX 255u
#define ER_UI_SURFACE_BLEND_ROUND_BIAS 127u
#define ER_UI_SURFACE_COLOR_GREEN_SHIFT 8u
#define ER_UI_SURFACE_COLOR_RED_SHIFT 16u
#define ER_UI_SURFACE_SHADOW_LAYERS 3u
#define ER_UI_SURFACE_ICON_GRID_SIZE 24u
#define ER_UI_SURFACE_ICON_GRID_HALF 12u
#define ER_UI_SURFACE_ICON_STROKE_DIVISOR 7u
#define ER_UI_SURFACE_MSDF_RGB_CHANNELS 3u
#define ER_UI_SURFACE_MSDF_ALPHA_LOW 96u
#define ER_UI_SURFACE_MSDF_ALPHA_HIGH 160u
#define ER_UI_SURFACE_MSDF_ALPHA_RANGE (ER_UI_SURFACE_MSDF_ALPHA_HIGH - ER_UI_SURFACE_MSDF_ALPHA_LOW)
#define ER_UI_SURFACE_DIRTY_TILE_ID_BYTES 4u

static uint8_t er_ui_surface_render_scene_with_atlas_stats(ErUiSurface* surface, const er_ui_scene_t* scene, const ErUiSurfaceAlphaAtlas* atlas, ErUiSurfaceRenderStats* stats);
static uint8_t er_ui_surface_clip_rect_to(const ErUiSurface* surface, const ErUiSurfacePixelRect* clip,
                                    float x, float y, float w, float h,
                                    uint32_t* out_x0, uint32_t* out_y0, uint32_t* out_x1, uint32_t* out_y1);
static const uint8_t* er_ui_surface_sample_texel(const uint8_t* pixels, uint32_t width, uint32_t height,
                                           uint32_t bytes_per_pixel, float u, float v);
static void er_ui_surface_border_rect(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                  er_ui_color4_t color, ErUiSurfaceRenderStats* stats);

static float er_ui_surface_clamp01(float value) {
  return er_math_clamp01f(value);
}

static uint8_t er_ui_surface_u8_from_unit(float value) {
  return (uint8_t)er_math_u8_from_unitf(value);
}

static uint32_t er_ui_surface_texel_coord(float coord, uint32_t limit) {
  uint32_t out;

  if (limit == 0u) return 0u;
  coord = er_ui_surface_clamp01(coord);
  out = (uint32_t)(coord * (float)limit);
  if (out >= limit) out = limit - 1u;
  return out;
}

static void er_ui_surface_stats_add_pixels(ErUiSurfaceRenderStats* stats, uint64_t pixels, uint8_t blended, uint8_t text) {
  if (stats == 0 || pixels == 0u) return;
  stats->pixels_written += pixels;
  stats->bytes_written += pixels * ER_UI_SURFACE_BYTES_PER_PIXEL;
  if (blended != 0u) stats->blend_pixels += pixels;
  if (text != 0u) stats->text_pixels += pixels;
}

static void er_ui_surface_stats_add(ErUiSurfaceRenderStats* dst, const ErUiSurfaceRenderStats* src) {
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

static uint8_t er_ui_surface_budget_violation(const char* name, uint64_t actual, uint64_t limit,
                                        ErUiSurfaceBudgetViolation* out_violation) {
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

static uint8_t er_ui_surface_memory_violation(const char* name, uint64_t actual, uint64_t limit,
                                        ErUiSurfaceMemoryBudgetViolation* out_violation) {
  return er_ui_surface_budget_violation(name, actual, limit, out_violation);
}

static uint8_t er_ui_surface_frame_violation(const char* name, uint64_t actual, uint64_t limit,
                                       ErUiSurfaceFrameBudgetViolation* out_violation) {
  return er_ui_surface_budget_violation(name, actual, limit, out_violation);
}

static int64_t er_ui_surface_floor_i64(float value) {
  return (int64_t)er_math_floor_i64(value);
}

static int64_t er_ui_surface_ceil_i64(float value) {
  return (int64_t)er_math_ceil_i64(value);
}

static uint8_t er_ui_surface_clip_rect_to(const ErUiSurface* surface, const ErUiSurfacePixelRect* clip,
                                    float x, float y, float w, float h,
                                    uint32_t* out_x0, uint32_t* out_y0, uint32_t* out_x1, uint32_t* out_y1) {
  int64_t x0;
  int64_t y0;
  int64_t x1;
  int64_t y1;
  uint32_t clip_x0 = 0u;
  uint32_t clip_y0 = 0u;
  uint32_t clip_x1;
  uint32_t clip_y1;

  if (!er_ui_surface_valid(surface) || out_x0 == 0 || out_y0 == 0 || out_x1 == 0 || out_y1 == 0 ||
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

  x0 = er_ui_surface_floor_i64(x);
  y0 = er_ui_surface_floor_i64(y);
  x1 = er_ui_surface_ceil_i64(x + w);
  y1 = er_ui_surface_ceil_i64(y + h);

  if (x0 < (int64_t)clip_x0) x0 = (int64_t)clip_x0;
  if (y0 < (int64_t)clip_y0) y0 = (int64_t)clip_y0;
  if (x1 > (int64_t)clip_x1) x1 = (int64_t)clip_x1;
  if (y1 > (int64_t)clip_y1) y1 = (int64_t)clip_y1;
  if (x0 >= x1 || y0 >= y1) return 0u;

  *out_x0 = (uint32_t)x0;
  *out_y0 = (uint32_t)y0;
  *out_x1 = (uint32_t)x1;
  *out_y1 = (uint32_t)y1;
  return 1u;
}

static void er_ui_surface_unpack(ErUiSurfacePixelFormat format, uint32_t pixel, uint8_t* r, uint8_t* g, uint8_t* b) {
  if (format == ER_UI_SURFACE_PIXEL_BGRX) {
    *b = (uint8_t)((pixel >> ER_UI_SURFACE_COLOR_RED_SHIFT) & ER_UI_SURFACE_COLOR_BYTE_MASK);
    *g = (uint8_t)((pixel >> ER_UI_SURFACE_COLOR_GREEN_SHIFT) & ER_UI_SURFACE_COLOR_BYTE_MASK);
    *r = (uint8_t)(pixel & ER_UI_SURFACE_COLOR_BYTE_MASK);
    return;
  }
  *r = (uint8_t)((pixel >> ER_UI_SURFACE_COLOR_RED_SHIFT) & ER_UI_SURFACE_COLOR_BYTE_MASK);
  *g = (uint8_t)((pixel >> ER_UI_SURFACE_COLOR_GREEN_SHIFT) & ER_UI_SURFACE_COLOR_BYTE_MASK);
  *b = (uint8_t)(pixel & ER_UI_SURFACE_COLOR_BYTE_MASK);
}

static uint32_t er_ui_surface_blend_pixel(ErUiSurfacePixelFormat format, uint32_t dst, er_ui_color4_t src) {
  uint8_t dr;
  uint8_t dg;
  uint8_t db;
  uint8_t sr = er_ui_surface_u8_from_unit(src.r);
  uint8_t sg = er_ui_surface_u8_from_unit(src.g);
  uint8_t sb = er_ui_surface_u8_from_unit(src.b);
  uint32_t a = (uint32_t)er_ui_surface_u8_from_unit(src.a);
  uint32_t inv = ER_UI_SURFACE_COLOR_BYTE_MAX - a;

  if (a >= ER_UI_SURFACE_COLOR_BYTE_MAX) {
    return er_ui_surface_pack_rgb(format, sr, sg, sb);
  }

  er_ui_surface_unpack(format, dst, &dr, &dg, &db);
  return er_ui_surface_pack_rgb(format,
                            (uint8_t)(((uint32_t)sr * a + (uint32_t)dr * inv +
                                     ER_UI_SURFACE_BLEND_ROUND_BIAS) /
                                    ER_UI_SURFACE_COLOR_BYTE_MAX),
                            (uint8_t)(((uint32_t)sg * a + (uint32_t)dg * inv +
                                     ER_UI_SURFACE_BLEND_ROUND_BIAS) /
                                    ER_UI_SURFACE_COLOR_BYTE_MAX),
                            (uint8_t)(((uint32_t)sb * a + (uint32_t)db * inv +
                                     ER_UI_SURFACE_BLEND_ROUND_BIAS) /
                                    ER_UI_SURFACE_COLOR_BYTE_MAX));
}

//@optimizer-ignore-function surface rectangle raster must blend each covered framebuffer pixel
static void er_ui_surface_fill_rect(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                er_ui_color4_t color, ErUiSurfaceRenderStats* stats) {
  uint32_t y;
  uint32_t x;
  uint64_t pixels;

  pixels = (uint64_t)(x1 - x0) * (uint64_t)(y1 - y0);
  er_ui_surface_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
    }
  }
}

static int64_t er_ui_surface_abs_i64(int64_t value) {
  return value < 0 ? -value : value;
}

static uint8_t er_ui_surface_point_in_round_rect(int64_t x, int64_t y, int64_t x0, int64_t y0, int64_t x1, int64_t y1, int64_t radius) {
  int64_t cx;
  int64_t cy;
  int64_t dx;
  int64_t dy;

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

//@optimizer-ignore-function rounded surface raster must test and blend each covered framebuffer pixel
static void er_ui_surface_fill_round_rect(ErUiSurface* surface,
                                      uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                      uint32_t full_x0, uint32_t full_y0, uint32_t full_x1, uint32_t full_y1,
                                      float radius, er_ui_color4_t color, ErUiSurfaceRenderStats* stats) {
  uint32_t y;
  uint32_t x;
  int64_t r = er_ui_surface_ceil_i64(radius);
  uint64_t pixels = 0u;

  if (r <= 0) {
    er_ui_surface_fill_rect(surface, x0, y0, x1, y1, color, stats);
    return;
  }
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    for (x = x0; x < x1; ++x) {
      if (er_ui_surface_point_in_round_rect((int64_t)x, (int64_t)y, (int64_t)full_x0, (int64_t)full_y0, (int64_t)full_x1, (int64_t)full_y1, r) != 0u) {
        row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
        ++pixels;
      }
    }
  }
  er_ui_surface_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
}

//@optimizer-ignore-function rounded surface border raster must test outer and inner bounds per covered framebuffer pixel
static void er_ui_surface_border_round_rect(ErUiSurface* surface,
                                        uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                        uint32_t full_x0, uint32_t full_y0, uint32_t full_x1, uint32_t full_y1,
                                        float radius, er_ui_color4_t color, ErUiSurfaceRenderStats* stats) {
  uint32_t y;
  uint32_t x;
  int64_t r = er_ui_surface_ceil_i64(radius);
  int64_t inner_r = r > 0 ? r - 1 : 0;
  uint64_t pixels = 0u;

  if (r <= 0) {
    er_ui_surface_border_rect(surface, x0, y0, x1, y1, color, stats);
    return;
  }
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    for (x = x0; x < x1; ++x) {
      uint8_t outer = er_ui_surface_point_in_round_rect((int64_t)x, (int64_t)y, (int64_t)full_x0, (int64_t)full_y0, (int64_t)full_x1, (int64_t)full_y1, r);
      uint8_t inner = er_ui_surface_point_in_round_rect((int64_t)x, (int64_t)y, (int64_t)full_x0 + 1, (int64_t)full_y0 + 1,
                                                  (int64_t)full_x1 - 1, (int64_t)full_y1 - 1, inner_r);
      if (outer != 0u && inner == 0u) {
        row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
        ++pixels;
      }
    }
  }
  er_ui_surface_stats_add_pixels(stats, pixels, color.a < 1.0f ? 1u : 0u, 0u);
}

//@optimizer-ignore-function shadow rendering uses a fixed three-layer raster pass for deterministic surface output
static void er_ui_surface_shadow_round_rect(ErUiSurface* surface, const ErUiSurfacePixelRect* clip,
                                        er_ui_rect_t rect, ErUiSurfaceRenderStats* stats) {
  uint32_t layer;
  float spread = rect.shadow > 0.0f ? rect.shadow : 14.0f;

  for (layer = ER_UI_SURFACE_SHADOW_LAYERS; layer > 0u; --layer) {
    uint32_t x0;
    uint32_t y0;
    uint32_t x1;
    uint32_t y1;
    uint32_t full_x0;
    uint32_t full_y0;
    uint32_t full_x1;
    uint32_t full_y1;
    float k = (float)layer / (float)ER_UI_SURFACE_SHADOW_LAYERS;
    float inset = spread * k * 0.40f;
    float alpha = 0.065f * k;
    er_ui_color4_t color = er_ui_color_rgba(0.0f, 0.0f, 0.0f, alpha);
    float sx = rect.x - inset * 0.55f;
    float sy = rect.y + inset * 0.35f;
    float sw = rect.w + inset * 1.10f;
    float sh = rect.h + inset * 1.10f;

    if (er_ui_surface_clip_rect_to(surface, clip, sx, sy, sw, sh, &x0, &y0, &x1, &y1) == 0u ||
        er_ui_surface_clip_rect_to(surface, 0, sx, sy, sw, sh, &full_x0, &full_y0, &full_x1, &full_y1) == 0u) {
      continue;
    }
    er_ui_surface_border_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius + inset, color, stats);
  }
}

static er_ui_color4_t er_ui_surface_lerp_color(er_ui_color4_t a, er_ui_color4_t b, float t) {
  er_ui_color4_t out;
  float k = er_ui_surface_clamp01(t);
  out.r = a.r + (b.r - a.r) * k;
  out.g = a.g + (b.g - a.g) * k;
  out.b = a.b + (b.b - a.b) * k;
  out.a = a.a + (b.a - a.a) * k;
  return out;
}

//@optimizer-ignore-function surface gradient raster must interpolate and blend each covered framebuffer pixel
static void er_ui_surface_gradient_rect(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                    float source_x, float source_w,
                                    er_ui_color4_t from, er_ui_color4_t to, ErUiSurfaceRenderStats* stats) {
  uint32_t y;
  uint32_t x;
  float span = source_w > 1.0f ? source_w - 1.0f : 1.0f;
  uint64_t pixels = (uint64_t)(x1 - x0) * (uint64_t)(y1 - y0);

  er_ui_surface_stats_add_pixels(stats, pixels, (from.a < 1.0f || to.a < 1.0f) ? 1u : 0u, 0u);
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    for (x = x0; x < x1; ++x) {
      er_ui_color4_t color = er_ui_surface_lerp_color(from, to, ((float)x - source_x) / span);
      row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
    }
  }
}

static void er_ui_surface_border_rect(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1,
                                  er_ui_color4_t color, ErUiSurfaceRenderStats* stats) {
  if (x0 >= x1 || y0 >= y1) return;
  er_ui_surface_fill_rect(surface, x0, y0, x1, y0 + 1u, color, stats);
  if (y1 > y0 + 1u) er_ui_surface_fill_rect(surface, x0, y1 - 1u, x1, y1, color, stats);
  if (y1 > y0 + 2u) {
    er_ui_surface_fill_rect(surface, x0, y0 + 1u, x0 + 1u, y1 - 1u, color, stats);
    if (x1 > x0 + 1u) er_ui_surface_fill_rect(surface, x1 - 1u, y0 + 1u, x1, y1 - 1u, color, stats);
  }
}

static void er_ui_surface_render_rect(ErUiSurface* surface, er_ui_rect_t rect,
                                  const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  uint32_t x0;
  uint32_t y0;
  uint32_t x1;
  uint32_t y1;
  uint32_t full_x0;
  uint32_t full_y0;
  uint32_t full_x1;
  uint32_t full_y1;

  if (er_ui_surface_clip_rect_to(surface, clip, rect.x, rect.y, rect.w, rect.h, &x0, &y0, &x1, &y1) == 0u) {
    if (clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (clip != 0 && stats != 0 &&
      er_ui_surface_clip_rect_to(surface, 0, rect.x, rect.y, rect.w, rect.h,
                             &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }

  if (stats != 0) ++stats->rects;
  switch (rect.mode) {
    case ER_UI_RECT_BORDER:
      if (stats != 0) ++stats->border_rects;
      er_ui_surface_border_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      break;
    case ER_UI_RECT_LINEAR_GRADIENT:
      if (stats != 0) ++stats->gradient_rects;
      if (rect.radius > 0.0f) {
        er_ui_surface_fill_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      } else {
        er_ui_surface_gradient_rect(surface, x0, y0, x1, y1, rect.x, rect.w, rect.color, rect.color2, stats);
      }
      break;
    case ER_UI_RECT_SHADOW:
      er_ui_surface_shadow_round_rect(surface, clip, rect, stats);
      break;
    case ER_UI_RECT_FILL:
    default:
      if (stats != 0) ++stats->solid_rects;
      er_ui_surface_fill_round_rect(surface, x0, y0, x1, y1, full_x0, full_y0, full_x1, full_y1, rect.radius, rect.color, stats);
      break;
  }
}

static void er_ui_surface_draw_point(ErUiSurface* surface, int32_t x, int32_t y, uint32_t stroke,
                                 er_ui_color4_t color, const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  uint32_t half = stroke / 2u;
  uint32_t x0;
  uint32_t y0;
  uint32_t x1;
  uint32_t y1;
  if (er_ui_surface_clip_rect_to(surface, clip, (float)x - (float)half, (float)y - (float)half,
                             (float)stroke, (float)stroke, &x0, &y0, &x1, &y1) == 0u) {
    return;
  }
  er_ui_surface_fill_rect(surface, x0, y0, x1, y1, color, stats);
}

//@optimizer-ignore-function Bresenham icon line raster must emit each covered point in order
static void er_ui_surface_draw_line(ErUiSurface* surface, int32_t x0, int32_t y0, int32_t x1, int32_t y1,
                                uint32_t stroke, er_ui_color4_t color, const ErUiSurfacePixelRect* clip,
                                ErUiSurfaceRenderStats* stats) {
  int32_t dx = (int32_t)er_ui_surface_abs_i64((int64_t)x1 - (int64_t)x0);
  int32_t sx = x0 < x1 ? 1 : -1;
  int32_t dy = -(int32_t)er_ui_surface_abs_i64((int64_t)y1 - (int64_t)y0);
  int32_t sy = y0 < y1 ? 1 : -1;
  int32_t err = dx + dy;

  for (;;) {
    int32_t e2;
    er_ui_surface_draw_point(surface, x0, y0, stroke, color, clip, stats);
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

static int32_t er_ui_surface_icon_x(uint32_t x0, uint32_t w, int32_t value) {
  return (int32_t)x0 + (int32_t)(((uint64_t)w * (uint64_t)(uint32_t)value + ER_UI_SURFACE_ICON_GRID_HALF) /
                             ER_UI_SURFACE_ICON_GRID_SIZE);
}

static int32_t er_ui_surface_icon_y(uint32_t y0, uint32_t h, int32_t value) {
  return (int32_t)y0 + (int32_t)(((uint64_t)h * (uint64_t)(uint32_t)value + ER_UI_SURFACE_ICON_GRID_HALF) /
                             ER_UI_SURFACE_ICON_GRID_SIZE);
}

static void er_ui_surface_icon_line(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t w, uint32_t h,
                                int32_t ax, int32_t ay, int32_t bx, int32_t by, uint32_t stroke,
                                er_ui_color4_t color, const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  er_ui_surface_draw_line(surface, er_ui_surface_icon_x(x0, w, ax), er_ui_surface_icon_y(y0, h, ay),
                      er_ui_surface_icon_x(x0, w, bx), er_ui_surface_icon_y(y0, h, by), stroke, color, clip, stats);
}

static void er_ui_surface_icon_rect(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t w, uint32_t h,
                                int32_t ax, int32_t ay, int32_t bx, int32_t by, uint32_t stroke,
                                er_ui_color4_t color, const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  er_ui_surface_icon_line(surface, x0, y0, w, h, ax, ay, bx, ay, stroke, color, clip, stats);
  er_ui_surface_icon_line(surface, x0, y0, w, h, bx, ay, bx, by, stroke, color, clip, stats);
  er_ui_surface_icon_line(surface, x0, y0, w, h, bx, by, ax, by, stroke, color, clip, stats);
  er_ui_surface_icon_line(surface, x0, y0, w, h, ax, by, ax, ay, stroke, color, clip, stats);
}

//@optimizer-ignore-function icon circle raster must test each pixel in the bounded icon radius box
static void er_ui_surface_icon_circle(ErUiSurface* surface, uint32_t x0, uint32_t y0, uint32_t w, uint32_t h,
                                  int32_t cx24, int32_t cy24, int32_t r24, uint32_t stroke,
                                  er_ui_color4_t color, const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  int32_t cx = er_ui_surface_icon_x(x0, w, cx24);
  int32_t cy = er_ui_surface_icon_y(y0, h, cy24);
  int32_t rx = (int32_t)(((uint64_t)w * (uint64_t)(uint32_t)r24 + ER_UI_SURFACE_ICON_GRID_HALF) /
                     ER_UI_SURFACE_ICON_GRID_SIZE);
  int32_t ry = (int32_t)(((uint64_t)h * (uint64_t)(uint32_t)r24 + ER_UI_SURFACE_ICON_GRID_HALF) /
                     ER_UI_SURFACE_ICON_GRID_SIZE);
  int32_t r = rx < ry ? rx : ry;
  int32_t inner = r - (int32_t)stroke;
  int32_t y;
  int32_t x;
  if (inner < 0) inner = 0;
  for (y = cy - r; y <= cy + r; ++y) {
    for (x = cx - r; x <= cx + r; ++x) {
      int64_t dx = (int64_t)x - (int64_t)cx;
      int64_t dy = (int64_t)y - (int64_t)cy;
      int64_t d = dx * dx + dy * dy;
      if (d <= (int64_t)r * (int64_t)r && d >= (int64_t)inner * (int64_t)inner) {
        er_ui_surface_draw_point(surface, x, y, 1u, color, clip, stats);
      }
    }
  }
}

//@optimizer-ignore-function icon vector coordinates are literal points on a 24-unit art grid
static void er_ui_surface_render_icon_quad(ErUiSurface* surface, const er_ui_quad_t* quad,
                                       const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  uint32_t x0;
  uint32_t y0;
  uint32_t x1;
  uint32_t y1;
  uint32_t w;
  uint32_t h;
  uint32_t stroke;
  er_ui_icon_t icon;
  uint32_t full_x0;
  uint32_t full_y0;
  uint32_t full_x1;
  uint32_t full_y1;

  if (quad == 0 || er_ui_surface_clip_rect_to(surface, clip, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    if (clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (x1 <= x0 || y1 <= y0) return;
  if (clip != 0 && stats != 0 &&
      er_ui_surface_clip_rect_to(surface, 0, quad->x, quad->y, quad->w, quad->h, &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }
  if (stats != 0) ++stats->icon_quads;

  if (!er_ui_icon_from_atlas_id(quad->atlas_id, &icon)) {
    if (stats != 0) ++stats->rejected_primitives;
    return;
  }
  {
    ErUiTablerIconRect rect;
    if (er_ui_tabler_icon_rect(icon, &rect) != 0u) {
      float width = quad->w > 1.0f ? quad->w : 1.0f;
      float height = quad->h > 1.0f ? quad->h : 1.0f;
      uint32_t y;
      uint32_t x;
      for (y = y0; y < y1; ++y) {
        uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
        float ty = ((float)y + 0.5f - quad->y) / height;
        float local_v = quad->v0 + (quad->v1 - quad->v0) * er_ui_surface_clamp01(ty);
        float atlas_v = ((float)rect.y + (float)rect.h * local_v) / (float)ER_UI_TABLER_ICON_ATLAS_HEIGHT;
        for (x = x0; x < x1; ++x) {
          float tx = ((float)x + 0.5f - quad->x) / width;
          float local_u = quad->u0 + (quad->u1 - quad->u0) * er_ui_surface_clamp01(tx);
          float atlas_u = ((float)rect.x + (float)rect.w * local_u) / (float)ER_UI_TABLER_ICON_ATLAS_WIDTH;
          const uint8_t* px = er_ui_surface_sample_texel(g_er_ui_tabler_icon_atlas_alpha, ER_UI_TABLER_ICON_ATLAS_WIDTH,
                                                   ER_UI_TABLER_ICON_ATLAS_HEIGHT, ER_UI_TABLER_ICON_ATLAS_BYTES_PER_PIXEL,
                                                   atlas_u, atlas_v);
          uint8_t alpha = px == 0 ? 0u : px[0];
          if (alpha != 0u) {
            er_ui_color4_t color = quad->color;
            color.a *= (float)alpha / 255.0f;
            er_ui_surface_stats_add_pixels(stats, 1u, color.a < 1.0f ? 1u : 0u, 0u);
            row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
          }
        }
      }
      return;
    }
  }

  w = x1 - x0;
  h = y1 - y0;
  stroke = w < h ? w / ER_UI_SURFACE_ICON_STROKE_DIVISOR : h / ER_UI_SURFACE_ICON_STROKE_DIVISOR;
  if (stroke == 0u) stroke = 1u;

  switch (icon) {
    case ER_UI_ICON_ACTIVITY:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 3, 12, 8, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 8, 12, 10, 5, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 10, 5, 14, 19, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 14, 19, 16, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 16, 12, 21, 12, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_APP:
      er_ui_surface_icon_rect(surface, x0, y0, w, h, 4, 5, 20, 19, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 9, 20, 9, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 8, 15, 11, 15, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SEARCH:
      er_ui_surface_icon_circle(surface, x0, y0, w, h, 10, 10, 6, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 15, 15, 21, 21, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CPU:
      er_ui_surface_icon_rect(surface, x0, y0, w, h, 7, 7, 17, 17, stroke, quad->color, clip, stats);
      er_ui_surface_icon_rect(surface, x0, y0, w, h, 10, 10, 14, 14, 1u, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 9, 7, 9, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 15, 7, 15, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 17, 9, 20, 9, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 17, 15, 20, 15, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 9, 4, 9, 7, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 15, 4, 15, 7, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 9, 17, 9, 20, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 15, 17, 15, 20, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_NETWORK:
      er_ui_surface_icon_circle(surface, x0, y0, w, h, 12, 5, 2, stroke, quad->color, clip, stats);
      er_ui_surface_icon_circle(surface, x0, y0, w, h, 6, 18, 2, stroke, quad->color, clip, stats);
      er_ui_surface_icon_circle(surface, x0, y0, w, h, 18, 18, 2, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 7, 6, 16, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 7, 18, 16, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 8, 18, 16, 18, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SHIELD:
    case ER_UI_ICON_TRUST:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 3, 20, 7, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 20, 7, 18, 16, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 18, 16, 12, 21, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 21, 6, 16, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 6, 16, 4, 7, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 7, 12, 3, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 8, 12, 11, 15, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 11, 15, 17, 9, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_SETTINGS:
      er_ui_surface_icon_circle(surface, x0, y0, w, h, 12, 12, 4, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 2, 12, 6, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 18, 12, 22, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 2, 12, 6, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 18, 12, 22, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 5, 5, 8, 8, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 16, 16, 19, 19, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 19, 5, 16, 8, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 8, 16, 5, 19, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CHECK:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 5, 13, 10, 18, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 10, 18, 20, 7, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_X:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 6, 6, 18, 18, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 18, 6, 6, 18, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_CHEVRON_RIGHT:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 9, 5, 16, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 16, 12, 9, 19, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_MENU:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 7, 20, 7, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 12, 20, 12, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 4, 17, 20, 17, stroke, quad->color, clip, stats);
      break;
    case ER_UI_ICON_WARNING:
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 4, 21, 20, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 21, 20, 3, 20, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 3, 20, 12, 4, stroke, quad->color, clip, stats);
      er_ui_surface_icon_line(surface, x0, y0, w, h, 12, 9, 12, 14, stroke, quad->color, clip, stats);
      er_ui_surface_draw_point(surface, er_ui_surface_icon_x(x0, w, 12), er_ui_surface_icon_y(y0, h, 17), stroke, quad->color, clip, stats);
      break;
    default:
      er_ui_surface_icon_rect(surface, x0, y0, w, h, 5, 5, 19, 19, stroke, quad->color, clip, stats);
      break;
  }
}

static const uint8_t* er_ui_surface_sample_texel(const uint8_t* pixels, uint32_t width, uint32_t height,
                                           uint32_t bytes_per_pixel, float u, float v) {
  uint32_t x;
  uint32_t y;

  if (pixels == 0 || width == 0u || height == 0u || bytes_per_pixel == 0u) {
    return 0;
  }
  x = er_ui_surface_texel_coord(u, width);
  y = er_ui_surface_texel_coord(v, height);
  return pixels + (((size_t)y * (size_t)width + (size_t)x) * bytes_per_pixel);
}

static uint8_t er_ui_surface_sample_alpha_texel(const uint8_t* pixels, uint32_t width, uint32_t height,
                                          uint32_t bytes_per_pixel, float u, float v) {
  const uint8_t* px = er_ui_surface_sample_texel(pixels, width, height, bytes_per_pixel, u, v);
  if (px == 0) {
    return 0u;
  }
  return px[0];
}

static uint8_t er_ui_surface_sample_alpha8(const vr_font_atlas_view_t* atlas, float u, float v) {
  if (atlas == 0) {
    return 0u;
  }
  return er_ui_surface_sample_alpha_texel(atlas->pixels, atlas->width, atlas->height,
                                      atlas->bytes_per_pixel, u, v);
}

static uint8_t er_ui_surface_sample_msdf_alpha(const vr_font_atlas_view_t* atlas, float u, float v) {
  const uint8_t* px;
  uint8_t r;
  uint8_t g;
  uint8_t b;
  uint8_t lo;
  uint8_t hi;
  uint8_t mid;

  if (atlas == 0 || atlas->pixels == 0 || atlas->width == 0u || atlas->height == 0u ||
      atlas->bytes_per_pixel < ER_UI_SURFACE_MSDF_RGB_CHANNELS) {
    return 0u;
  }

  px = er_ui_surface_sample_texel(atlas->pixels, atlas->width, atlas->height, atlas->bytes_per_pixel, u, v);
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
  mid = (uint8_t)((uint32_t)r + (uint32_t)g + (uint32_t)b - (uint32_t)lo - (uint32_t)hi);
  if (mid <= ER_UI_SURFACE_MSDF_ALPHA_LOW) return 0u;
  if (mid >= ER_UI_SURFACE_MSDF_ALPHA_HIGH) return ER_UI_SURFACE_COLOR_BYTE_MAX;
  return (uint8_t)(((uint32_t)(mid - ER_UI_SURFACE_MSDF_ALPHA_LOW) * ER_UI_SURFACE_COLOR_BYTE_MAX) /
                 ER_UI_SURFACE_MSDF_ALPHA_RANGE);
}

static uint8_t er_ui_surface_sample_atlas_alpha(const vr_font_atlas_view_t* atlas, float u, float v) {
  if (atlas == 0) return 0u;
  if (atlas->format == VR_FONT_ATLAS_FORMAT_ALPHA8) {
    return er_ui_surface_sample_alpha8(atlas, u, v);
  }
  if (atlas->format == VR_FONT_ATLAS_FORMAT_MSDF_RGB) {
    return er_ui_surface_sample_msdf_alpha(atlas, u, v);
  }
  return 0u;
}

static uint8_t er_ui_surface_sample_boot_atlas_alpha(const ErUiSurfaceAlphaAtlas* atlas, float u, float v) {
  if (atlas == 0) {
    return 0u;
  }
  return er_ui_surface_sample_alpha_texel(atlas->pixels, atlas->width, atlas->height,
                                      atlas->bytes_per_pixel, u, v);
}

typedef uint8_t (*ErUiSurfaceTextAlphaSampler)(const void* context, float u, float v);

static uint8_t er_ui_surface_sample_text_boot_alpha(const void* context, float u, float v) {
  return er_ui_surface_sample_boot_atlas_alpha((const ErUiSurfaceAlphaAtlas*)context, u, v);
}

static uint8_t er_ui_surface_sample_text_font_alpha(const void* context, float u, float v) {
  return er_ui_surface_sample_atlas_alpha((const vr_font_atlas_view_t*)context, u, v);
}

//@optimizer-ignore-function text alpha raster must sample and blend each covered framebuffer pixel
static void er_ui_surface_render_text_quad_sampled(ErUiSurface* surface, const er_ui_quad_t* quad,
                                               ErUiSurfaceTextAlphaSampler sampler, const void* sampler_context,
                                               const ErUiSurfacePixelRect* clip, ErUiSurfaceRenderStats* stats) {
  uint32_t x0;
  uint32_t y0;
  uint32_t x1;
  uint32_t y1;
  uint32_t y;
  uint32_t x;
  float width;
  float height;
  uint32_t full_x0;
  uint32_t full_y0;
  uint32_t full_x1;
  uint32_t full_y1;

  if (quad == 0 || sampler == 0 || sampler_context == 0 ||
      er_ui_surface_clip_rect_to(surface, clip, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    if (quad != 0 && sampler != 0 && sampler_context != 0 && clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (clip != 0 && stats != 0 &&
      er_ui_surface_clip_rect_to(surface, 0, quad->x, quad->y, quad->w, quad->h,
                             &full_x0, &full_y0, &full_x1, &full_y1) != 0u &&
      (x0 != full_x0 || y0 != full_y0 || x1 != full_x1 || y1 != full_y1)) {
    ++stats->clipped_primitives;
  }

  width = quad->w > 1.0f ? quad->w : 1.0f;
  height = quad->h > 1.0f ? quad->h : 1.0f;
  if (stats != 0) ++stats->text_quads;
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    float ty = ((float)y + 0.5f - quad->y) / height;
    float v = quad->v0 + (quad->v1 - quad->v0) * er_ui_surface_clamp01(ty);
    for (x = x0; x < x1; ++x) {
      float tx = ((float)x + 0.5f - quad->x) / width;
      float u = quad->u0 + (quad->u1 - quad->u0) * er_ui_surface_clamp01(tx);
      uint8_t alpha = sampler(sampler_context, u, v);
      if (alpha != 0u) {
        er_ui_color4_t color = quad->color;
        color.a *= (float)alpha / 255.0f;
        er_ui_surface_stats_add_pixels(stats, 1u, color.a < 1.0f ? 1u : 0u, 1u);
        row[x] = er_ui_surface_blend_pixel(surface->pixel_format, row[x], color);
      }
    }
  }
}

static void er_ui_surface_render_text_quad_with_alpha_atlas(ErUiSurface* surface, const er_ui_quad_t* quad,
                                                        const ErUiSurfaceAlphaAtlas* atlas,
                                                        const ErUiSurfacePixelRect* clip,
                                                        ErUiSurfaceRenderStats* stats) {
  er_ui_surface_render_text_quad_sampled(surface, quad, er_ui_surface_sample_text_boot_alpha, atlas, clip, stats);
}

static void er_ui_surface_render_text_quad(ErUiSurface* surface, const er_ui_quad_t* quad,
                                       const vr_font_face_t* font, const ErUiSurfacePixelRect* clip,
                                       ErUiSurfaceRenderStats* stats) {
  vr_font_atlas_view_t atlas;

  if (quad == 0 || font == 0) {
    if (quad != 0 && font != 0 && clip != 0 && stats != 0) ++stats->rejected_primitives;
    return;
  }
  if (vr_font_atlas_view(font, quad->atlas_id, &atlas) != VR_OK) {
    return;
  }
  er_ui_surface_render_text_quad_sampled(surface, quad, er_ui_surface_sample_text_font_alpha, &atlas, clip, stats);
}

#include "er_ui_surface_planning.h"

#include "er_ui_surface_render.h"

#include "er_ui_gop_renderer.h"
#include "er_ui_icon.h"

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
  if (value < 0.0f) return 0.0f;
  if (value > 1.0f) return 1.0f;
  return value;
}

static UINT8 er_ui_gop_u8_from_unit(float value) {
  float scaled = er_ui_gop_clamp01(value) * 255.0f + 0.5f;
  if (scaled <= 0.0f) return 0u;
  if (scaled >= 255.0f) return 255u;
  return (UINT8)scaled;
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
  stats->bytes_written += pixels * 4u;
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

static INT64 er_ui_gop_floor_i64(float value) {
  INT64 truncated = (INT64)value;
  if (value < 0.0f && (float)truncated != value) {
    --truncated;
  }
  return truncated;
}

static INT64 er_ui_gop_ceil_i64(float value) {
  INT64 truncated = (INT64)value;
  if (value > 0.0f && (float)truncated != value) {
    ++truncated;
  }
  return truncated;
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
    *b = (UINT8)((pixel >> 16) & 0xffu);
    *g = (UINT8)((pixel >> 8) & 0xffu);
    *r = (UINT8)(pixel & 0xffu);
    return;
  }
  *r = (UINT8)((pixel >> 16) & 0xffu);
  *g = (UINT8)((pixel >> 8) & 0xffu);
  *b = (UINT8)(pixel & 0xffu);
}

static UINT32 er_ui_gop_blend_pixel(ErUiGopPixelFormat format, UINT32 dst, er_ui_color4_t src) {
  UINT8 dr;
  UINT8 dg;
  UINT8 db;
  UINT8 sr = er_ui_gop_u8_from_unit(src.r);
  UINT8 sg = er_ui_gop_u8_from_unit(src.g);
  UINT8 sb = er_ui_gop_u8_from_unit(src.b);
  UINT32 a = (UINT32)er_ui_gop_u8_from_unit(src.a);
  UINT32 inv = 255u - a;

  if (a >= 255u) {
    return er_ui_gop_pack_rgb(format, sr, sg, sb);
  }

  er_ui_gop_unpack(format, dst, &dr, &dg, &db);
  return er_ui_gop_pack_rgb(format,
                            (UINT8)(((UINT32)sr * a + (UINT32)dr * inv + 127u) / 255u),
                            (UINT8)(((UINT32)sg * a + (UINT32)dg * inv + 127u) / 255u),
                            (UINT8)(((UINT32)sb * a + (UINT32)db * inv + 127u) / 255u));
}

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

static void er_ui_gop_shadow_round_rect(ErUiGopSurface* surface, const ErUiGopPixelRect* clip,
                                        er_ui_rect_t rect, ErUiGopRenderStats* stats) {
  UINT32 layer;
  float spread = rect.shadow > 0.0f ? rect.shadow : 14.0f;

  for (layer = 3u; layer > 0u; --layer) {
    UINT32 x0;
    UINT32 y0;
    UINT32 x1;
    UINT32 y1;
    UINT32 full_x0;
    UINT32 full_y0;
    UINT32 full_x1;
    UINT32 full_y1;
    float k = (float)layer / 3.0f;
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
  return (INT32)x0 + (INT32)(((UINT64)w * (UINT64)(UINT32)value + 12u) / 24u);
}

static INT32 er_ui_gop_icon_y(UINT32 y0, UINT32 h, INT32 value) {
  return (INT32)y0 + (INT32)(((UINT64)h * (UINT64)(UINT32)value + 12u) / 24u);
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

static void er_ui_gop_icon_circle(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 w, UINT32 h,
                                  INT32 cx24, INT32 cy24, INT32 r24, UINT32 stroke,
                                  er_ui_color4_t color, const ErUiGopPixelRect* clip, ErUiGopRenderStats* stats) {
  INT32 cx = er_ui_gop_icon_x(x0, w, cx24);
  INT32 cy = er_ui_gop_icon_y(y0, h, cy24);
  INT32 rx = (INT32)(((UINT64)w * (UINT64)(UINT32)r24 + 12u) / 24u);
  INT32 ry = (INT32)(((UINT64)h * (UINT64)(UINT32)r24 + 12u) / 24u);
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
  stroke = w < h ? w / 7u : h / 7u;
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
      atlas->bytes_per_pixel < 3u) {
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
  if (mid <= 96u) return 0u;
  if (mid >= 160u) return 255u;
  return (UINT8)(((UINT32)(mid - 96u) * 255u) / 64u);
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

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface) {
  return surface != 0 && surface->pixels != 0 && surface->width > 0u && surface->height > 0u &&
         surface->stride >= surface->width &&
         (surface->pixel_format == ER_UI_GOP_PIXEL_RGBX || surface->pixel_format == ER_UI_GOP_PIXEL_BGRX);
}

UINT8 er_ui_gop_mode_valid(const ErUiGopMode* mode) {
  return mode != 0 && mode->width > 0u && mode->height > 0u && mode->stride >= mode->width &&
         mode->refresh_hz > 0u &&
         (mode->pixel_format == ER_UI_GOP_PIXEL_RGBX || mode->pixel_format == ER_UI_GOP_PIXEL_BGRX);
}

static UINT32 er_ui_gop_div_ceil_u32(UINT32 value, UINT32 divisor) {
  return (value + divisor - 1u) / divisor;
}

static UINT8 er_ui_gop_add_u64(UINT64 a, UINT64 b, UINT64* out) {
  if (out == 0 || a > 0xffffffffffffffffull - b) {
    return 0u;
  }
  *out = a + b;
  return 1u;
}

static UINT8 er_ui_gop_mul_u64(UINT64 a, UINT64 b, UINT64* out) {
  if (out == 0 || (a != 0u && b > 0xffffffffffffffffull / a)) {
    return 0u;
  }
  *out = a * b;
  return 1u;
}

UINT8 er_ui_gop_tile_plan_from_mode(const ErUiGopMode* mode, UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  UINT32 columns;
  UINT32 rows;
  UINT64 tile_count;

  if (out_plan != 0) {
    *out_plan = (ErUiGopTilePlan){0};
  }
  if (er_ui_gop_mode_valid(mode) == 0u || tile_width == 0u || tile_height == 0u ||
      max_dirty_tiles == 0u || out_plan == 0) {
    return 0u;
  }

  columns = er_ui_gop_div_ceil_u32(mode->width, tile_width);
  rows = er_ui_gop_div_ceil_u32(mode->height, tile_height);
  tile_count = (UINT64)columns * (UINT64)rows;
  if ((UINT64)max_dirty_tiles > tile_count) {
    max_dirty_tiles = (UINT32)tile_count;
  }

  out_plan->width = mode->width;
  out_plan->height = mode->height;
  out_plan->stride = mode->stride;
  out_plan->bytes_per_pixel = 4u;
  out_plan->tile_width = tile_width;
  out_plan->tile_height = tile_height;
  out_plan->columns = columns;
  out_plan->rows = rows;
  out_plan->max_dirty_tiles = max_dirty_tiles;
  out_plan->tile_count = tile_count;
  out_plan->scanout_bytes = (UINT64)mode->stride * (UINT64)mode->height * 4u;
  out_plan->full_frame_bytes = (UINT64)mode->width * (UINT64)mode->height * 4u;
  out_plan->max_tile_bytes = (UINT64)tile_width * (UINT64)tile_height * 4u;
  out_plan->tile_state_bytes = tile_count;
  out_plan->dirty_queue_bytes = (UINT64)max_dirty_tiles * 4u;
  return 1u;
}

UINT8 er_ui_gop_tile_plan(const ErUiGopSurface* surface, UINT32 tile_width, UINT32 tile_height,
                          UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  ErUiGopMode mode;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    if (out_plan != 0) {
      *out_plan = (ErUiGopTilePlan){0};
    }
    return 0u;
  }

  mode.width = surface->width;
  mode.height = surface->height;
  mode.stride = surface->stride;
  mode.refresh_hz = 1u;
  mode.pixel_format = surface->pixel_format;
  return er_ui_gop_tile_plan_from_mode(&mode, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_bandwidth_plan_from_mode(const ErUiGopMode* mode, UINT32 overdraw_budget,
                                         ErUiGopBandwidthPlan* out_plan) {
  UINT64 scanout_bytes;
  UINT64 full_frame_bytes;
  UINT64 scanout_bytes_per_second;
  UINT64 full_frame_bytes_per_second;
  UINT64 budget_bytes_per_second;

  if (out_plan != 0) {
    *out_plan = (ErUiGopBandwidthPlan){0};
  }
  if (er_ui_gop_mode_valid(mode) == 0u || overdraw_budget == 0u || out_plan == 0) {
    return 0u;
  }
  if (er_ui_gop_mul_u64((UINT64)mode->stride, (UINT64)mode->height, &scanout_bytes) == 0u ||
      er_ui_gop_mul_u64(scanout_bytes, 4u, &scanout_bytes) == 0u ||
      er_ui_gop_mul_u64((UINT64)mode->width, (UINT64)mode->height, &full_frame_bytes) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes, 4u, &full_frame_bytes) == 0u ||
      er_ui_gop_mul_u64(scanout_bytes, (UINT64)mode->refresh_hz, &scanout_bytes_per_second) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes, (UINT64)mode->refresh_hz, &full_frame_bytes_per_second) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes_per_second, (UINT64)overdraw_budget, &budget_bytes_per_second) == 0u) {
    return 0u;
  }

  out_plan->refresh_hz = mode->refresh_hz;
  out_plan->overdraw_budget = overdraw_budget;
  out_plan->scanout_bytes_per_second = scanout_bytes_per_second;
  out_plan->full_frame_bytes_per_second = full_frame_bytes_per_second;
  out_plan->budget_bytes_per_second = budget_bytes_per_second;
  return 1u;
}

UINT8 er_ui_gop_memory_plan_from_tile_plan(const ErUiGopTilePlan* tile_plan, UINT32 backing_buffer_count,
                                           UINT64 command_bytes, UINT64 glyph_cache_bytes,
                                           UINT64 surface_bytes, ErUiGopMemoryPlan* out_plan) {
  UINT64 backing_bytes;
  UINT64 total;

  if (out_plan != 0) {
    *out_plan = (ErUiGopMemoryPlan){0};
  }
  if (tile_plan == 0 || out_plan == 0 || tile_plan->tile_count == 0u) {
    return 0u;
  }
  if (er_ui_gop_mul_u64(tile_plan->scanout_bytes, (UINT64)backing_buffer_count, &backing_bytes) == 0u) {
    return 0u;
  }

  total = tile_plan->scanout_bytes;
  if (er_ui_gop_add_u64(total, backing_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, tile_plan->tile_state_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, tile_plan->dirty_queue_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, command_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, glyph_cache_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, surface_bytes, &total) == 0u) {
    return 0u;
  }

  out_plan->backing_buffer_count = backing_buffer_count;
  out_plan->scanout_bytes = tile_plan->scanout_bytes;
  out_plan->backing_bytes = backing_bytes;
  out_plan->tile_state_bytes = tile_plan->tile_state_bytes;
  out_plan->dirty_queue_bytes = tile_plan->dirty_queue_bytes;
  out_plan->command_bytes = command_bytes;
  out_plan->glyph_cache_bytes = glyph_cache_bytes;
  out_plan->surface_bytes = surface_bytes;
  out_plan->total_bytes = total;
  return 1u;
}

UINT8 er_ui_gop_memory_plan_first_budget_violation(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget,
                                                   ErUiGopMemoryBudgetViolation* out_violation) {
  static const char* const names[] = {
    "scanout_bytes",
    "backing_bytes",
    "tile_state_bytes",
    "dirty_queue_bytes",
    "command_bytes",
    "glyph_cache_bytes",
    "surface_bytes",
    "total_bytes"
  };
  const UINT64 actual[] = {
    plan.scanout_bytes,
    plan.backing_bytes,
    plan.tile_state_bytes,
    plan.dirty_queue_bytes,
    plan.command_bytes,
    plan.glyph_cache_bytes,
    plan.surface_bytes,
    plan.total_bytes
  };
  const UINT64 limits[] = {
    budget.scanout_bytes,
    budget.backing_bytes,
    budget.tile_state_bytes,
    budget.dirty_queue_bytes,
    budget.command_bytes,
    budget.glyph_cache_bytes,
    budget.surface_bytes,
    budget.total_bytes
  };
  const UINTN count = (UINTN)(sizeof(actual) / sizeof(actual[0]));
  UINTN i;

  for (i = 0u; i < count; ++i) {
    if (actual[i] > limits[i]) {
      if (out_violation != 0) {
        out_violation->name = names[i];
        out_violation->actual = actual[i];
        out_violation->limit = limits[i];
      }
      return 1u;
    }
  }
  return 0u;
}

UINT8 er_ui_gop_memory_plan_fits_budget(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget) {
  return er_ui_gop_memory_plan_first_budget_violation(plan, budget, 0) == 0u;
}

UINT8 er_ui_gop_tile_rect(const ErUiGopTilePlan* plan, UINT32 tile_id, ErUiGopPixelRect* out_rect) {
  UINT32 tx;
  UINT32 ty;

  if (out_rect != 0) {
    *out_rect = (ErUiGopPixelRect){0};
  }
  if (plan == 0 || out_rect == 0 || plan->tile_count == 0u || (UINT64)tile_id >= plan->tile_count ||
      plan->columns == 0u || plan->tile_width == 0u || plan->tile_height == 0u) {
    return 0u;
  }

  tx = tile_id % plan->columns;
  ty = tile_id / plan->columns;
  out_rect->x0 = tx * plan->tile_width;
  out_rect->y0 = ty * plan->tile_height;
  out_rect->x1 = out_rect->x0 + plan->tile_width;
  out_rect->y1 = out_rect->y0 + plan->tile_height;
  if (out_rect->x1 > plan->width) out_rect->x1 = plan->width;
  if (out_rect->y1 > plan->height) out_rect->y1 = plan->height;
  return out_rect->x0 < out_rect->x1 && out_rect->y0 < out_rect->y1;
}

UINT8 er_ui_gop_dirty_tiles_reset(const ErUiGopTilePlan* plan, UINT8* tile_marks,
                                  UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  UINT64 i;

  if (plan == 0 || tile_marks == 0 || list == 0 || list->tile_ids == 0 ||
      plan->tile_count == 0u || plan->tile_count > tile_mark_count ||
      plan->tile_count > 0xffffffffu || list->capacity < plan->max_dirty_tiles) {
    return 0u;
  }

  for (i = 0u; i < plan->tile_count; ++i) {
    tile_marks[i] = 0u;
  }
  list->count = 0u;
  list->overflowed = 0u;
  return 1u;
}

UINT8 er_ui_gop_dirty_tiles_mark_rect(const ErUiGopTilePlan* plan, float x, float y, float w, float h,
                                      UINT8* tile_marks, UINT64 tile_mark_count,
                                      ErUiGopDirtyTileList* list) {
  INT64 x0;
  INT64 y0;
  INT64 x1;
  INT64 y1;
  UINT32 tx0;
  UINT32 ty0;
  UINT32 tx1;
  UINT32 ty1;
  UINT32 ty;
  UINT32 tx;

  if (plan == 0 || tile_marks == 0 || list == 0 || list->tile_ids == 0 ||
      plan->tile_count == 0u || plan->tile_count > tile_mark_count ||
      plan->tile_count > 0xffffffffu || !(w > 0.0f) || !(h > 0.0f)) {
    return 0u;
  }

  x0 = er_ui_gop_floor_i64(x);
  y0 = er_ui_gop_floor_i64(y);
  x1 = er_ui_gop_ceil_i64(x + w);
  y1 = er_ui_gop_ceil_i64(y + h);
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > (INT64)plan->width) x1 = (INT64)plan->width;
  if (y1 > (INT64)plan->height) y1 = (INT64)plan->height;
  if (x0 >= x1 || y0 >= y1) {
    return 1u;
  }

  tx0 = (UINT32)x0 / plan->tile_width;
  ty0 = (UINT32)y0 / plan->tile_height;
  tx1 = er_ui_gop_div_ceil_u32((UINT32)x1, plan->tile_width);
  ty1 = er_ui_gop_div_ceil_u32((UINT32)y1, plan->tile_height);
  if (tx1 > plan->columns) tx1 = plan->columns;
  if (ty1 > plan->rows) ty1 = plan->rows;

  for (ty = ty0; ty < ty1; ++ty) {
    for (tx = tx0; tx < tx1; ++tx) {
      UINT64 tile_id64 = (UINT64)ty * (UINT64)plan->columns + (UINT64)tx;
      UINT32 tile_id = (UINT32)tile_id64;
      if (tile_id64 >= plan->tile_count || tile_marks[tile_id] != 0u) {
        continue;
      }
      tile_marks[tile_id] = 1u;
      if (list->count < list->capacity && list->count < plan->max_dirty_tiles) {
        list->tile_ids[list->count++] = tile_id;
      } else {
        list->overflowed = 1u;
      }
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_color_equal(er_ui_color4_t a, er_ui_color4_t b) {
  return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

static UINT8 er_ui_gop_rect_equal(er_ui_rect_t a, er_ui_rect_t b) {
  return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h &&
         a.radius == b.radius && a.mode == b.mode && a.shadow == b.shadow &&
         er_ui_gop_color_equal(a.color, b.color) != 0u &&
         er_ui_gop_color_equal(a.color2, b.color2) != 0u;
}

static UINT8 er_ui_gop_quad_equal(er_ui_quad_t a, er_ui_quad_t b) {
  return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h &&
         a.u0 == b.u0 && a.v0 == b.v0 && a.u1 == b.u1 && a.v1 == b.v1 &&
         a.atlas_id == b.atlas_id && er_ui_gop_color_equal(a.color, b.color) != 0u;
}

static UINT8 er_ui_gop_dirty_mark_quad(const ErUiGopTilePlan* plan, er_ui_quad_t quad,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_mark_rect(plan, quad.x, quad.y, quad.w, quad.h,
                                         tile_marks, tile_mark_count, list);
}

UINT8 er_ui_gop_dirty_tiles_mark_scene(const ErUiGopTilePlan* plan, const er_ui_scene_t* scene,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list) {
  size_t i;

  if (plan == 0 || scene == 0) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_rect_t rect = scene->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = 0u; i < scene->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, scene->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = 0u; i < scene->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, scene->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_ui_gop_dirty_tiles_mark_scene_diff(const ErUiGopTilePlan* plan, const er_ui_scene_t* prev,
                                            const er_ui_scene_t* next, UINT8* tile_marks,
                                            UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  size_t i;
  size_t common;

  if (plan == 0 || prev == 0 || next == 0) {
    return 0u;
  }

  if (er_ui_gop_color_equal(prev->clear, next->clear) == 0u) {
    return er_ui_gop_dirty_tiles_mark_rect(plan, 0.0f, 0.0f, (float)plan->width, (float)plan->height,
                                           tile_marks, tile_mark_count, list);
  }

  common = prev->rect_count < next->rect_count ? prev->rect_count : next->rect_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_rect_equal(prev->rects[i], next->rects[i]) == 0u) {
      er_ui_rect_t prev_rect = prev->rects[i];
      er_ui_rect_t next_rect = next->rects[i];
      if (er_ui_gop_dirty_tiles_mark_rect(plan, prev_rect.x, prev_rect.y, prev_rect.w, prev_rect.h,
                                          tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_tiles_mark_rect(plan, next_rect.x, next_rect.y, next_rect.w, next_rect.h,
                                          tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->rect_count; ++i) {
    er_ui_rect_t rect = prev->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->rect_count; ++i) {
    er_ui_rect_t rect = next->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  common = prev->icon_quad_count < next->icon_quad_count ? prev->icon_quad_count : next->icon_quad_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_quad_equal(prev->icon_quads[i], next->icon_quads[i]) == 0u) {
      if (er_ui_gop_dirty_mark_quad(plan, prev->icon_quads[i], tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_mark_quad(plan, next->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, prev->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, next->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  common = prev->text_quad_count < next->text_quad_count ? prev->text_quad_count : next->text_quad_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_quad_equal(prev->text_quads[i], next->text_quads[i]) == 0u) {
      if (er_ui_gop_dirty_mark_quad(plan, prev->text_quads[i], tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_mark_quad(plan, next->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, prev->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, next->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  return 1u;
}

void er_ui_gop_frame_state_reset(ErUiGopFrameState* state) {
  if (state != 0) {
    *state = (ErUiGopFrameState){0};
  }
}

UINT8 er_ui_gop_frame_dirty_tiles(const ErUiGopFrameState* state, const ErUiGopTilePlan* plan,
                                  const er_ui_scene_t* prev, const er_ui_scene_t* next,
                                  UINT8* tile_marks, UINT64 tile_mark_count,
                                  ErUiGopDirtyTileList* list) {
  UINT8 has_previous;

  if (state == 0 || plan == 0 || next == 0) {
    return 0u;
  }
  if (er_ui_gop_dirty_tiles_reset(plan, tile_marks, tile_mark_count, list) == 0u) {
    return 0u;
  }

  has_previous = state->has_previous_scene != 0u && prev != 0;
  if (has_previous == 0u) {
    return er_ui_gop_dirty_tiles_mark_rect(plan, 0.0f, 0.0f, (float)plan->width, (float)plan->height,
                                           tile_marks, tile_mark_count, list) != 0u &&
           er_ui_gop_dirty_tiles_mark_scene(plan, next, tile_marks, tile_mark_count, list) != 0u;
  }

  return er_ui_gop_dirty_tiles_mark_scene_diff(plan, prev, next, tile_marks, tile_mark_count, list);
}

void er_ui_gop_frame_state_commit(ErUiGopFrameState* state) {
  if (state != 0) {
    state->has_previous_scene = 1u;
  }
}

ErUiGopFrameBudget er_ui_gop_frame_budget_from_plan(const ErUiGopTilePlan* tile_plan,
                                                    er_ui_scene_budget_t scene_budget,
                                                    UINT32 overdraw_budget) {
  ErUiGopFrameBudget budget = {0};
  UINT64 frame_pixels;
  UINT64 primitive_limit;

  if (tile_plan == 0 || overdraw_budget == 0u) {
    return budget;
  }

  frame_pixels = (UINT64)tile_plan->width * (UINT64)tile_plan->height;
  primitive_limit = (UINT64)scene_budget.rects + (UINT64)scene_budget.icon_quads + (UINT64)scene_budget.text_quads;
  budget.pixels_written = frame_pixels * (UINT64)overdraw_budget;
  budget.bytes_written = tile_plan->full_frame_bytes * (UINT64)overdraw_budget;
  budget.blend_pixels = frame_pixels * (UINT64)overdraw_budget;
  budget.text_pixels = frame_pixels;
  budget.rects = (UINT64)scene_budget.rects;
  budget.icon_quads = (UINT64)scene_budget.icon_quads;
  budget.text_quads = (UINT64)scene_budget.text_quads;
  budget.tiles_rendered = tile_plan->tile_count;
  budget.dirty_tiles_requested = (UINT64)tile_plan->max_dirty_tiles;
  budget.clipped_primitives = primitive_limit * tile_plan->tile_count;
  budget.rejected_primitives = primitive_limit * tile_plan->tile_count;
  return budget;
}

UINT8 er_ui_gop_render_stats_first_budget_violation(ErUiGopRenderStats stats, ErUiGopFrameBudget budget,
                                                    ErUiGopFrameBudgetViolation* out_violation) {
  static const char* const names[] = {
    "pixels_written",
    "bytes_written",
    "blend_pixels",
    "text_pixels",
    "rects",
    "icon_quads",
    "text_quads",
    "tiles_rendered",
    "dirty_tiles_requested",
    "clipped_primitives",
    "rejected_primitives"
  };
  const UINT64 actual[] = {
    stats.pixels_written,
    stats.bytes_written,
    stats.blend_pixels,
    stats.text_pixels,
    stats.rects,
    stats.icon_quads,
    stats.text_quads,
    stats.tiles_rendered,
    stats.dirty_tiles_requested,
    stats.clipped_primitives,
    stats.rejected_primitives
  };
  const UINT64 limits[] = {
    budget.pixels_written,
    budget.bytes_written,
    budget.blend_pixels,
    budget.text_pixels,
    budget.rects,
    budget.icon_quads,
    budget.text_quads,
    budget.tiles_rendered,
    budget.dirty_tiles_requested,
    budget.clipped_primitives,
    budget.rejected_primitives
  };
  const UINTN count = (UINTN)(sizeof(actual) / sizeof(actual[0]));
  UINTN i;

  for (i = 0u; i < count; ++i) {
    if (actual[i] > limits[i]) {
      if (out_violation != 0) {
        out_violation->name = names[i];
        out_violation->actual = actual[i];
        out_violation->limit = limits[i];
      }
      return 1u;
    }
  }
  return 0u;
}

UINT8 er_ui_gop_render_stats_fits_budget(ErUiGopRenderStats stats, ErUiGopFrameBudget budget) {
  return er_ui_gop_render_stats_first_budget_violation(stats, budget, 0) == 0u;
}

UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b) {
  if (format == ER_UI_GOP_PIXEL_BGRX) {
    return ((UINT32)b << 16) | ((UINT32)g << 8) | (UINT32)r;
  }
  return ((UINT32)r << 16) | ((UINT32)g << 8) | (UINT32)b;
}

static UINT8 er_ui_gop_surface_clear_rect_stats(ErUiGopSurface* surface, er_ui_color4_t color,
                                                const ErUiGopPixelRect* clip,
                                                ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  UINT32 packed;
  UINT32 x0 = 0u;
  UINT32 y0 = 0u;
  UINT32 x1;
  UINT32 y1;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    return 0u;
  }
  x1 = surface->width;
  y1 = surface->height;
  if (clip != 0) {
    x0 = clip->x0;
    y0 = clip->y0;
    x1 = clip->x1;
    y1 = clip->y1;
    if (x0 > surface->width) x0 = surface->width;
    if (y0 > surface->height) y0 = surface->height;
    if (x1 > surface->width) x1 = surface->width;
    if (y1 > surface->height) y1 = surface->height;
    if (x0 >= x1 || y0 >= y1) return 0u;
  }

  packed = er_ui_gop_pack_rgb(surface->pixel_format,
                              er_ui_gop_u8_from_unit(color.r),
                              er_ui_gop_u8_from_unit(color.g),
                              er_ui_gop_u8_from_unit(color.b));
  if (stats != 0) {
    ++stats->clears;
    er_ui_gop_stats_add_pixels(stats, (UINT64)(x1 - x0) * (UINT64)(y1 - y0), 0u, 0u);
  }
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = packed;
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_surface_clear_stats(ErUiGopSurface* surface, er_ui_color4_t color,
                                           ErUiGopRenderStats* stats) {
  return er_ui_gop_surface_clear_rect_stats(surface, color, 0, stats);
}

UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color) {
  return er_ui_gop_surface_clear_stats(surface, color, 0);
}

UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene) {
  return er_ui_gop_surface_render_scene_with_atlas(surface, scene, 0);
}

UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas) {
  return er_ui_gop_surface_render_scene_with_atlas_stats(surface, scene, atlas, 0);
}

static UINT8 er_ui_gop_surface_render_scene_with_atlas_clip_stats(ErUiGopSurface* surface,
                                                                  const er_ui_scene_t* scene,
                                                                  const ErUiGopAlphaAtlas* atlas,
                                                                  const ErUiGopPixelRect* clip,
                                                                  ErUiGopRenderStats* stats) {
  size_t i;

  if (stats != 0) {
    *stats = (ErUiGopRenderStats){0};
  }
  if (er_ui_gop_surface_valid(surface) == 0u || scene == 0) {
    return 0u;
  }

  if (er_ui_gop_surface_clear_rect_stats(surface, scene->clear, clip, stats) == 0u) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_gop_render_rect(surface, scene->rects[i], clip, stats);
  }
  for (i = 0u; i < scene->icon_quad_count; ++i) {
    er_ui_gop_render_icon_quad(surface, &scene->icon_quads[i], clip, stats);
  }
  if (atlas != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad_with_alpha_atlas(surface, &scene->text_quads[i], atlas, clip, stats);
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_surface_render_scene_with_atlas_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                             const ErUiGopAlphaAtlas* atlas,
                                                             ErUiGopRenderStats* stats) {
  return er_ui_gop_surface_render_scene_with_atlas_clip_stats(surface, scene, atlas, 0, stats);
}

UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font) {
  return er_ui_gop_surface_render_scene_with_font_stats(surface, scene, font, 0);
}

UINT8 er_ui_gop_surface_render_scene_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font, ErUiGopRenderStats* out_stats) {
  return er_ui_gop_surface_render_scene_tile_with_font_stats(surface, scene, font, 0, 0u, out_stats);
}

UINT8 er_ui_gop_surface_render_scene_tile_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                          const vr_font_face_t* font,
                                                          const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                          ErUiGopRenderStats* out_stats) {
  size_t i;
  ErUiGopPixelRect clip;
  const ErUiGopPixelRect* clip_ptr = 0;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  if (plan != 0) {
    if (er_ui_gop_tile_rect(plan, tile_id, &clip) == 0u ||
        plan->width != surface->width || plan->height != surface->height || plan->stride != surface->stride) {
      if (out_stats != 0) {
        *out_stats = (ErUiGopRenderStats){0};
      }
      return 0u;
    }
    clip_ptr = &clip;
  }

  if (er_ui_gop_surface_render_scene_with_atlas_clip_stats(surface, scene, 0, clip_ptr, out_stats) == 0u) {
    return 0u;
  }
  if (clip_ptr != 0 && out_stats != 0) {
    out_stats->tiles_rendered = 1u;
  }
  if (font != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad(surface, &scene->text_quads[i], font, clip_ptr, out_stats);
    }
  }
  return 1u;
}

UINT8 er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(ErUiGopSurface* surface,
                                                                 const er_ui_scene_t* scene,
                                                                 const vr_font_face_t* font,
                                                                 const ErUiGopTilePlan* plan,
                                                                 const ErUiGopDirtyTileList* dirty_tiles,
                                                                 ErUiGopRenderStats* out_stats) {
  UINT32 i;
  ErUiGopRenderStats total;

  if (out_stats != 0) {
    *out_stats = (ErUiGopRenderStats){0};
  }
  if (surface == 0 || scene == 0 || plan == 0 || dirty_tiles == 0 || dirty_tiles->tile_ids == 0 ||
      dirty_tiles->overflowed != 0u || dirty_tiles->count > dirty_tiles->capacity) {
    return 0u;
  }

  total = (ErUiGopRenderStats){0};
  total.dirty_tiles_requested = dirty_tiles->count;
  for (i = 0u; i < dirty_tiles->count; ++i) {
    ErUiGopRenderStats tile_stats;
    if (er_ui_gop_surface_render_scene_tile_with_font_stats(surface, scene, font, plan,
                                                            dirty_tiles->tile_ids[i], &tile_stats) == 0u) {
      if (out_stats != 0) {
        *out_stats = (ErUiGopRenderStats){0};
      }
      return 0u;
    }
    er_ui_gop_stats_add(&total, &tile_stats);
  }
  if (out_stats != 0) {
    total.dirty_tiles_requested = dirty_tiles->count;
    *out_stats = total;
  }
  return 1u;
}

UINT8 er_ui_gop_renderer_init(EFI_SYSTEM_TABLE* st) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL* gop = 0;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* info;

  g_ready = 0u;
  if (st == 0 || st->BootServices == 0 || st->BootServices->LocateProtocol == 0) {
    return 0u;
  }
  if (st->BootServices->LocateProtocol(&g_gop_guid, 0, (void**)&gop) != EFI_SUCCESS ||
      gop == 0 || gop->Mode == 0 || gop->Mode->Info == 0) {
    return 0u;
  }

  info = gop->Mode->Info;
  if (info->PixelFormat != PixelRedGreenBlueReserved8BitPerColor &&
      info->PixelFormat != PixelBlueGreenRedReserved8BitPerColor) {
    return 0u;
  }
  if (gop->Mode->FrameBufferBase == 0u || info->HorizontalResolution == 0u ||
      info->VerticalResolution == 0u || info->PixelsPerScanLine == 0u) {
    return 0u;
  }

  g_surface.pixels = (UINT32*)(UINTN)gop->Mode->FrameBufferBase;
  g_surface.width = info->HorizontalResolution;
  g_surface.height = info->VerticalResolution;
  g_surface.stride = info->PixelsPerScanLine;
  g_surface.pixel_format = info->PixelFormat == PixelBlueGreenRedReserved8BitPerColor ?
    ER_UI_GOP_PIXEL_BGRX : ER_UI_GOP_PIXEL_RGBX;
  g_ready = er_ui_gop_surface_valid(&g_surface);
  return g_ready;
}

UINT8 er_ui_gop_renderer_ready(void) {
  return g_ready;
}

UINT8 er_ui_gop_renderer_mode(ErUiGopMode* out_mode) {
  if (out_mode != 0) {
    *out_mode = (ErUiGopMode){0};
  }
  if (g_ready == 0u || out_mode == 0) {
    return 0u;
  }
  out_mode->width = g_surface.width;
  out_mode->height = g_surface.height;
  out_mode->stride = g_surface.stride;
  out_mode->refresh_hz = 1u;
  out_mode->pixel_format = g_surface.pixel_format;
  return er_ui_gop_mode_valid(out_mode);
}

UINT8 er_ui_gop_renderer_tile_plan(UINT32 tile_width, UINT32 tile_height,
                                   UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  if (g_ready == 0u) {
    if (out_plan != 0) {
      *out_plan = (ErUiGopTilePlan){0};
    }
    return 0u;
  }
  return er_ui_gop_tile_plan(&g_surface, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_renderer_render_scene(const er_ui_scene_t* scene) {
  return er_ui_gop_renderer_render_scene_with_atlas(scene, 0);
}

UINT8 er_ui_gop_renderer_render_scene_with_atlas(const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas) {
  if (g_ready == 0u) {
    return 0u;
  }
  return er_ui_gop_surface_render_scene_with_atlas(&g_surface, scene, atlas);
}

UINT8 er_ui_gop_renderer_render_scene_with_font(const er_ui_scene_t* scene, const vr_font_face_t* font) {
  return er_ui_gop_renderer_render_scene_with_font_stats(scene, font, 0);
}

UINT8 er_ui_gop_renderer_render_scene_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font, ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    return 0u;
  }
  return er_ui_gop_surface_render_scene_with_font_stats(&g_surface, scene, font, out_stats);
}

UINT8 er_ui_gop_renderer_render_scene_tile_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                           const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                           ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  return er_ui_gop_surface_render_scene_tile_with_font_stats(&g_surface, scene, font, plan, tile_id, out_stats);
}

UINT8 er_ui_gop_renderer_render_scene_dirty_tiles_with_font_stats(const er_ui_scene_t* scene,
                                                                  const vr_font_face_t* font,
                                                                  const ErUiGopTilePlan* plan,
                                                                  const ErUiGopDirtyTileList* dirty_tiles,
                                                                  ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  return er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(&g_surface, scene, font, plan,
                                                                    dirty_tiles, out_stats);
}

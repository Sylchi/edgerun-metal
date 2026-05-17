#include "er_ui_gop_renderer.h"

static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au}
};

static ErUiGopSurface g_surface;
static UINT8 g_ready;

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

static UINT8 er_ui_gop_clip_rect(const ErUiGopSurface* surface, float x, float y, float w, float h,
                                 UINT32* out_x0, UINT32* out_y0, UINT32* out_x1, UINT32* out_y1) {
  INT64 x0;
  INT64 y0;
  INT64 x1;
  INT64 y1;

  if (!er_ui_gop_surface_valid(surface) || out_x0 == 0 || out_y0 == 0 || out_x1 == 0 || out_y1 == 0 ||
      !(w > 0.0f) || !(h > 0.0f)) {
    return 0u;
  }

  x0 = er_ui_gop_floor_i64(x);
  y0 = er_ui_gop_floor_i64(y);
  x1 = er_ui_gop_ceil_i64(x + w);
  y1 = er_ui_gop_ceil_i64(y + h);

  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > (INT64)surface->width) x1 = (INT64)surface->width;
  if (y1 > (INT64)surface->height) y1 = (INT64)surface->height;
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
                                er_ui_color4_t color) {
  UINT32 y;
  UINT32 x;

  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
    }
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
                                    er_ui_color4_t from, er_ui_color4_t to) {
  UINT32 y;
  UINT32 x;
  UINT32 span = x1 > x0 + 1u ? x1 - x0 - 1u : 1u;

  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      er_ui_color4_t color = er_ui_gop_lerp_color(from, to, (float)(x - x0) / (float)span);
      row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
    }
  }
}

static void er_ui_gop_border_rect(ErUiGopSurface* surface, UINT32 x0, UINT32 y0, UINT32 x1, UINT32 y1,
                                  er_ui_color4_t color) {
  if (x0 >= x1 || y0 >= y1) return;
  er_ui_gop_fill_rect(surface, x0, y0, x1, y0 + 1u, color);
  if (y1 > y0 + 1u) er_ui_gop_fill_rect(surface, x0, y1 - 1u, x1, y1, color);
  if (y1 > y0 + 2u) {
    er_ui_gop_fill_rect(surface, x0, y0 + 1u, x0 + 1u, y1 - 1u, color);
    if (x1 > x0 + 1u) er_ui_gop_fill_rect(surface, x1 - 1u, y0 + 1u, x1, y1 - 1u, color);
  }
}

static void er_ui_gop_render_rect(ErUiGopSurface* surface, er_ui_rect_t rect) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;

  if (er_ui_gop_clip_rect(surface, rect.x, rect.y, rect.w, rect.h, &x0, &y0, &x1, &y1) == 0u) {
    return;
  }

  switch (rect.mode) {
    case ER_UI_RECT_BORDER:
      er_ui_gop_border_rect(surface, x0, y0, x1, y1, rect.color);
      break;
    case ER_UI_RECT_LINEAR_GRADIENT:
      er_ui_gop_gradient_rect(surface, x0, y0, x1, y1, rect.color, rect.color2);
      break;
    case ER_UI_RECT_SHADOW:
    case ER_UI_RECT_FILL:
    default:
      er_ui_gop_fill_rect(surface, x0, y0, x1, y1, rect.color);
      break;
  }
}

static UINT8 er_ui_gop_sample_alpha8(const vr_font_atlas_view_t* atlas, float u, float v) {
  UINT32 x;
  UINT32 y;

  if (atlas == 0 || atlas->pixels == 0 || atlas->width == 0u || atlas->height == 0u ||
      atlas->bytes_per_pixel == 0u) {
    return 0u;
  }

  x = er_ui_gop_texel_coord(u, atlas->width);
  y = er_ui_gop_texel_coord(v, atlas->height);
  return atlas->pixels[((UINTN)y * (UINTN)atlas->width + (UINTN)x) * atlas->bytes_per_pixel];
}

static UINT8 er_ui_gop_sample_msdf_alpha(const vr_font_atlas_view_t* atlas, float u, float v) {
  UINT32 x;
  UINT32 y;
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

  x = er_ui_gop_texel_coord(u, atlas->width);
  y = er_ui_gop_texel_coord(v, atlas->height);
  px = atlas->pixels + (((UINTN)y * (UINTN)atlas->width + (UINTN)x) * atlas->bytes_per_pixel);
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
  UINT32 x;
  UINT32 y;

  if (atlas == 0 || atlas->pixels == 0 || atlas->width == 0u || atlas->height == 0u ||
      atlas->bytes_per_pixel == 0u) {
    return 0u;
  }
  x = er_ui_gop_texel_coord(u, atlas->width);
  y = er_ui_gop_texel_coord(v, atlas->height);
  return atlas->pixels[((UINTN)y * (UINTN)atlas->width + (UINTN)x) * atlas->bytes_per_pixel];
}

static void er_ui_gop_render_text_quad_with_alpha_atlas(ErUiGopSurface* surface, const er_ui_quad_t* quad, const ErUiGopAlphaAtlas* atlas) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  UINT32 y;
  UINT32 x;
  float width;
  float height;

  if (quad == 0 || atlas == 0 || er_ui_gop_clip_rect(surface, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    return;
  }

  width = quad->w > 1.0f ? quad->w : 1.0f;
  height = quad->h > 1.0f ? quad->h : 1.0f;
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    float ty = ((float)y + 0.5f - quad->y) / height;
    float v = quad->v0 + (quad->v1 - quad->v0) * er_ui_gop_clamp01(ty);
    for (x = x0; x < x1; ++x) {
      float tx = ((float)x + 0.5f - quad->x) / width;
      float u = quad->u0 + (quad->u1 - quad->u0) * er_ui_gop_clamp01(tx);
      UINT8 alpha = er_ui_gop_sample_boot_atlas_alpha(atlas, u, v);
      if (alpha != 0u) {
        er_ui_color4_t color = quad->color;
        color.a *= (float)alpha / 255.0f;
        row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
      }
    }
  }
}

static void er_ui_gop_render_text_quad(ErUiGopSurface* surface, const er_ui_quad_t* quad, const vr_font_face_t* font) {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
  vr_font_atlas_view_t atlas;
  UINT32 y;
  UINT32 x;
  float width;
  float height;

  if (quad == 0 || font == 0 || er_ui_gop_clip_rect(surface, quad->x, quad->y, quad->w, quad->h, &x0, &y0, &x1, &y1) == 0u) {
    return;
  }
  if (vr_font_atlas_view(font, quad->atlas_id, &atlas) != VR_OK) {
    return;
  }

  width = quad->w > 1.0f ? quad->w : 1.0f;
  height = quad->h > 1.0f ? quad->h : 1.0f;
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    float ty = ((float)y + 0.5f - quad->y) / height;
    float v = quad->v0 + (quad->v1 - quad->v0) * er_ui_gop_clamp01(ty);
    for (x = x0; x < x1; ++x) {
      float tx = ((float)x + 0.5f - quad->x) / width;
      float u = quad->u0 + (quad->u1 - quad->u0) * er_ui_gop_clamp01(tx);
      UINT8 alpha = er_ui_gop_sample_atlas_alpha(&atlas, u, v);
      if (alpha != 0u) {
        er_ui_color4_t color = quad->color;
        color.a *= (float)alpha / 255.0f;
        row[x] = er_ui_gop_blend_pixel(surface->pixel_format, row[x], color);
      }
    }
  }
}

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface) {
  return surface != 0 && surface->pixels != 0 && surface->width > 0u && surface->height > 0u &&
         surface->stride >= surface->width &&
         (surface->pixel_format == ER_UI_GOP_PIXEL_RGBX || surface->pixel_format == ER_UI_GOP_PIXEL_BGRX);
}

UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b) {
  if (format == ER_UI_GOP_PIXEL_BGRX) {
    return ((UINT32)b << 16) | ((UINT32)g << 8) | (UINT32)r;
  }
  return ((UINT32)r << 16) | ((UINT32)g << 8) | (UINT32)b;
}

UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color) {
  UINT32 y;
  UINT32 x;
  UINT32 packed;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    return 0u;
  }

  packed = er_ui_gop_pack_rgb(surface->pixel_format,
                              er_ui_gop_u8_from_unit(color.r),
                              er_ui_gop_u8_from_unit(color.g),
                              er_ui_gop_u8_from_unit(color.b));
  for (y = 0; y < surface->height; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = 0; x < surface->width; ++x) {
      row[x] = packed;
    }
  }
  return 1u;
}

UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene) {
  return er_ui_gop_surface_render_scene_with_atlas(surface, scene, 0);
}

UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas) {
  size_t i;

  if (er_ui_gop_surface_valid(surface) == 0u || scene == 0) {
    return 0u;
  }

  if (er_ui_gop_surface_clear(surface, scene->clear) == 0u) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_gop_render_rect(surface, scene->rects[i]);
  }
  if (atlas != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad_with_alpha_atlas(surface, &scene->text_quads[i], atlas);
    }
  }
  return 1u;
}

UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font) {
  size_t i;

  if (er_ui_gop_surface_render_scene_with_atlas(surface, scene, 0) == 0u) {
    return 0u;
  }
  if (font != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad(surface, &scene->text_quads[i], font);
    }
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
  if (g_ready == 0u) {
    return 0u;
  }
  return er_ui_gop_surface_render_scene_with_font(&g_surface, scene, font);
}

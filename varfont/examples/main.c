#include "vr_font.h"
#include "er_math.h"

#include <SDL2/SDL.h>

#include <stdbool.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  SDL_Renderer* renderer;
  SDL_Texture** textures;
  size_t texture_cap;
  uint32_t next_texture_id;
  vr_font_atlas_format_t atlas_format;
} sdl_gl_iface_t;

typedef struct {
  float px_size;
  float weight;
  float render_x;
  float render_y;
} demo_layer_t;

typedef struct {
  vr_vertex_t* verts;
  size_t vertex_count;
  vr_vertex_atlas_range_t* ranges;
  size_t range_count;
} demo_layer_render_t;

typedef struct {
  SDL_Window* window;
  SDL_Renderer* renderer;
  sdl_gl_iface_t gl_iface;
  vr_font_face_t* face;
  uint32_t* codepoints;
  size_t codepoint_count;
  demo_layer_render_t* layer_render_data;
  SDL_Vertex** layer_vertices;
  size_t* layer_vertex_counts;
  bool sdl_ready;
  const char* snapshot_path;
} sdl_demo_app_t;

static const uint16_t VR_UI_WINDOW_WIDTH = 1120u;
static const uint16_t VR_UI_WINDOW_HEIGHT = 320u;
static const uint32_t VR_TEXTURE_SLOT_INITIAL_CAP = 16u;
static const uint32_t VR_RENDER_DELAY_MS = 16u;
static const uint32_t VR_UTF8_MAX_ASCII = 0x80u;
static const uint8_t VR_RGBA_CHANNEL_MAX = 255u;
static const char* const VR_WEIGHT_AXIS_TAG = "wght";
static const uint8_t VR_UI_BACKGROUND_RED = 0u;
static const uint8_t VR_UI_BACKGROUND_GREEN = 0u;
static const uint8_t VR_UI_BACKGROUND_BLUE = 0u;
static const uint8_t VR_UI_BACKGROUND_ALPHA = 255u;
static const uint8_t VR_MSDF_RECON_TEXTURE_CHANNELS = 3u;
static const float VR_MSDF_RECON_SPREAD = 2.0f;
static const float VR_MSDF_RECON_MID_ALPHA = 128.0f;
static const float VR_MSDF_RECON_EDGE_SCALE = 255.0f;
static const uint8_t VR_MSDF_RECON_AA_SUBSAMPLES = 8u;
static const float VR_MSDF_RECON_AA_WIDTH = 0.65f;
static const float VR_MSDF_RECON_AA_SCALE = 1.00f;
static const float VR_MSDF_RECON_ALPHA_MAX = 255.0f;
static const uint8_t VR_MSDF_RECON_BORDER_SAMPLE_COUNT = 4u;
static const char* const VR_FALLBACK_FONT_PATH = "fonts/Geist[wght].ttf";
static const char* const VR_DEFAULT_TEXT = "Geist variable font in SDL";
static const char* const VR_DEMO_SNAPSHOT_FLAG = "--snapshot";
static const char* const VR_DEMO_ALPHA8_FLAG = "--alpha8";
static const char* const VR_DEMO_MSDF_FLAG = "--msdf";
static const float VR_TEXT_RENDER_X = 40.0f;
static const int32_t VR_SDL_RENDERER_INDEX_AUTO = -1;
static const uint8_t VR_SDL_BYTES_PER_PIXEL_RGBA = 4u;
static const size_t VR_DEMO_MAX_FILE_BYTES = 64u * 1024u * 1024u;
typedef enum {
  VR_DEMO_LAYER_COUNT = 4u
} vr_demo_constants_t;

static const demo_layer_t VR_DEMO_LAYERS[VR_DEMO_LAYER_COUNT] = {
  {26.0f, 250.0f, VR_TEXT_RENDER_X, 54.0f},
  {38.0f, 400.0f, VR_TEXT_RENDER_X, 112.0f},
  {52.0f, 700.0f, VR_TEXT_RENDER_X, 188.0f},
  {68.0f, 900.0f, VR_TEXT_RENDER_X, 282.0f},
};

static void* demo_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* demo_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void demo_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static uint8_t* demo_read_file_bytes(const char* path, size_t* out_size) {
  if (!path || !out_size) {
    return NULL;
  }
  *out_size = 0u;
  FILE* file = fopen(path, "rb");
  if (!file) {
    return NULL;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  long file_size = ftell(file);
  if (file_size <= 0 || (size_t)file_size > VR_DEMO_MAX_FILE_BYTES) {
    fclose(file);
    return NULL;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return NULL;
  }

  uint8_t* bytes = (uint8_t*)malloc((size_t)file_size);
  if (!bytes) {
    fclose(file);
    return NULL;
  }
  size_t read_count = fread(bytes, 1u, (size_t)file_size, file);
  fclose(file);
  if (read_count != (size_t)file_size) {
    free(bytes);
    return NULL;
  }
  *out_size = (size_t)file_size;
  return bytes;
}

static vr_status_t demo_create_face_from_path(vr_font_face_t** out_face, const char* path, const vr_font_config_t* cfg) {
  if (!out_face || !path || !cfg) {
    return VR_ERR_INVALID_FONT;
  }
  *out_face = NULL;
  size_t font_size = 0u;
  uint8_t* font_bytes = demo_read_file_bytes(path, &font_size);
  if (!font_bytes) {
    return VR_ERR_IO;
  }
  vr_status_t st = vr_font_face_create_from_memory(out_face, font_bytes, font_size, cfg);
  free(font_bytes);
  return st;
}

static void sdl_free_demo_layers(vr_font_face_t* face, demo_layer_render_t* layers, size_t count);

static void sdl_demo_release(sdl_demo_app_t* app) {
  if (!app) {
    return;
  }

  if (app->layer_vertices) {
    //@optimizer-ignore demo teardown must release each optional layer allocation
    for (size_t i = 0u; i < VR_DEMO_LAYER_COUNT; ++i) {
      //@optimizer-ignore demo teardown must release each optional layer allocation
      free(app->layer_vertices[i]);
      app->layer_vertices[i] = NULL;
    }
    free(app->layer_vertices);
    app->layer_vertices = NULL;
  }
  if (app->layer_vertex_counts) {
    free(app->layer_vertex_counts);
    app->layer_vertex_counts = NULL;
  }

  if (app->layer_render_data) {
    sdl_free_demo_layers(app->face, app->layer_render_data, VR_DEMO_LAYER_COUNT);
    free(app->layer_render_data);
    app->layer_render_data = NULL;
  }

  free(app->codepoints);
  app->codepoints = NULL;
  app->codepoint_count = 0u;

  if (app->face) {
    vr_font_face_destroy(app->face);
    app->face = NULL;
  }

  if (app->gl_iface.textures) {
    free(app->gl_iface.textures);
    app->gl_iface.textures = NULL;
  }
  app->gl_iface.texture_cap = 0u;
  app->gl_iface.next_texture_id = 1u;

  if (app->renderer) {
    SDL_DestroyRenderer(app->renderer);
    app->renderer = NULL;
  }
  if (app->window) {
    SDL_DestroyWindow(app->window);
    app->window = NULL;
  }
  if (app->sdl_ready) {
    SDL_Quit();
    app->sdl_ready = false;
  }
}

static void sdl_free_demo_layers(vr_font_face_t* face, demo_layer_render_t* layers, size_t count) {
  for (size_t i = 0u; i < count; ++i) {
    vr_font_free_vertices(face, layers[i].verts, layers[i].vertex_count);
    (void)vr_font_free_vertex_atlas_ranges(face, layers[i].ranges, layers[i].range_count);
    layers[i].verts = NULL;
    layers[i].vertex_count = 0u;
    layers[i].ranges = NULL;
    layers[i].range_count = 0u;
  }
}

//@optimizer-ignore-function demo intentionally rebuilds fixed visual layers for size and weight samples
static vr_status_t sdl_build_demo_layers(
  vr_font_face_t* face,
  const uint32_t* cps,
  size_t cp_count,
  demo_layer_render_t* out_layers,
  size_t layer_count) {
  for (size_t i = 0u; i < layer_count; ++i) {
    const demo_layer_t* layer_spec = &VR_DEMO_LAYERS[i];
    demo_layer_render_t* layer = &out_layers[i];
    layer->verts = NULL;
    layer->ranges = NULL;
    layer->vertex_count = 0u;
    layer->range_count = 0u;

    vr_status_t st = vr_font_set_size(face, layer_spec->px_size);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: failed to set font size %.2f: %u\n", layer_spec->px_size, st);
      return st;
    }
    st = vr_font_set_axis(face, VR_WEIGHT_AXIS_TAG, layer_spec->weight);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: failed to set wght %.1f: %u\n", layer_spec->weight, st);
      return st;
    }

    vr_shaped_glyph_t* shaped = NULL;
    size_t shaped_count = 0u;
    st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: shape failed for sample %zu status=%u\n", i, st);
      vr_font_free_shaped(face, shaped, shaped_count);
      return st;
    }
    if (shaped_count == 0u) {
      vr_font_free_shaped(face, shaped, shaped_count);
      return VR_ERR_INVALID_FONT;
    }

    st = vr_font_build_vertex_batches_by_atlas(
      face,
      shaped,
      shaped_count,
      layer_spec->render_x,
      layer_spec->render_y,
      &layer->verts,
      &layer->vertex_count,
      &layer->ranges,
      &layer->range_count);
    vr_font_free_shaped(face, shaped, shaped_count);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: batch failed for sample %zu status=%u\n", i, st);
      return st;
    }
  }
  return VR_OK;
}

static float sdl_sorted_median_3(float a, float b, float c) {
  if (a > b) {
    float swap = a;
    a = b;
    b = swap;
  }
  if (b > c) {
    float swap = b;
    b = c;
    c = swap;
  }
  if (a > b) {
    float swap = a;
    a = b;
    b = swap;
  }
  return b;
}

static float sdl_smoothstep_float(float edge0, float edge1, float value) {
  if (edge0 >= edge1) return 0.0f;

  float t = (value - edge0) / (edge1 - edge0);
  t = er_math_clamp01f(t);
  return t * t * (3.0f - 2.0f * t);
}

static float sdl_decode_msdf_channel(uint8_t encoded, float spread) {
  return ((float)encoded - VR_MSDF_RECON_MID_ALPHA) * (spread / VR_MSDF_RECON_EDGE_SCALE);
}

static float sdl_msdf_sample_distance(
  const uint8_t* msdf,
  int x,
  int y,
  int width,
  int height,
  float spread) {
  int cx = (x < 0) ? 0 : ((x >= width) ? (width - 1) : x);
  int cy = (y < 0) ? 0 : ((y >= height) ? (height - 1) : y);

  size_t pixel_index = (size_t)cy * (size_t)width + (size_t)cx;
  const uint8_t* pixel = msdf + pixel_index * (size_t)VR_MSDF_RECON_TEXTURE_CHANNELS;
  float d0 = sdl_decode_msdf_channel(pixel[0u], spread);
  float d1 = sdl_decode_msdf_channel(pixel[1u], spread);
  float d2 = sdl_decode_msdf_channel(pixel[2u], spread);
  return sdl_sorted_median_3(d0, d1, d2);
}

static float sdl_msdf_sample_distance_f(
  const uint8_t* msdf,
  float x,
  float y,
  int width,
  int height,
  float spread) {
  if (!msdf || width <= 0 || height <= 0) {
    return 0.0f;
  }
  float fx = er_math_clampf(x, 0.0f, (float)(width - 1));
  float fy = er_math_clampf(y, 0.0f, (float)(height - 1));

  int x0 = (int)er_math_floorf(fx);
  int y0 = (int)er_math_floorf(fy);
  int x1 = (x0 >= (width - 1)) ? x0 : (x0 + 1);
  int y1 = (y0 >= (height - 1)) ? y0 : (y0 + 1);

  float tx = fx - (float)x0;
  float ty = fy - (float)y0;

  float d00 = sdl_msdf_sample_distance(msdf, x0, y0, width, height, spread);
  float d10 = sdl_msdf_sample_distance(msdf, x1, y0, width, height, spread);
  float d01 = sdl_msdf_sample_distance(msdf, x0, y1, width, height, spread);
  float d11 = sdl_msdf_sample_distance(msdf, x1, y1, width, height, spread);

  float d0 = d00 + (d10 - d00) * tx;
  float d1 = d01 + (d11 - d01) * tx;
  return d0 + (d1 - d0) * ty;
}

static uint8_t sdl_msdf_to_alpha(
  const uint8_t* msdf,
  int x,
  int y,
  int width,
  int height,
  float spread,
  bool invert_sign) {
  if (width <= 0 || height <= 0 || spread <= 0.0f) {
    return 0u;
  }

  float aa_step = 1.0f / (float)VR_MSDF_RECON_AA_SUBSAMPLES;
  float coverage = 0.0f;
  float half = 0.5f;
  float aa_width = VR_MSDF_RECON_AA_WIDTH / spread;

  for (uint8_t sy = 0u; sy < VR_MSDF_RECON_AA_SUBSAMPLES; ++sy) {
    float fy = (float)sy * aa_step + aa_step * 0.5f - half;
    //@optimizer-ignore msdf reconstruction samples a fixed subsample grid for visual fidelity
    for (uint8_t sx = 0u; sx < VR_MSDF_RECON_AA_SUBSAMPLES; ++sx) {
      float fx = (float)sx * aa_step + aa_step * 0.5f - half;
      float d = sdl_msdf_sample_distance_f(msdf, (float)x + fx, (float)y + fy, width, height, spread);
      if (invert_sign) {
        d = -d;
      }
      float sub_alpha = sdl_smoothstep_float(-aa_width, aa_width, d);
      coverage += er_math_clamp01f(sub_alpha);
    }
  }

  float sample_count = (float)(VR_MSDF_RECON_AA_SUBSAMPLES * VR_MSDF_RECON_AA_SUBSAMPLES);
  float alpha_norm = coverage / sample_count * VR_MSDF_RECON_ALPHA_MAX;
  alpha_norm *= VR_MSDF_RECON_AA_SCALE;
  alpha_norm = er_math_clampf(alpha_norm, 0.0f, VR_MSDF_RECON_ALPHA_MAX);

  return (uint8_t)(alpha_norm + 0.5f);
}

static bool sdl_msdf_is_inverted(const uint8_t* msdf, int width, int height, float spread) {
  if (!msdf || width <= 0 || height <= 0) {
    return false;
  }

  static const int sample_points[4u][2] = {{0, 0}, {-1, 0}, {0, -1}, {-1, -1}};
  float sample_sum = 0.0f;
  for (uint8_t i = 0u; i < VR_MSDF_RECON_BORDER_SAMPLE_COUNT; ++i) {
    int sample_x = (sample_points[i][0u] < 0) ? (width - 1) : sample_points[i][0u];
    int sample_y = (sample_points[i][1u] < 0) ? (height - 1) : sample_points[i][1u];
    sample_sum += sdl_msdf_sample_distance(msdf, sample_x, sample_y, width, height, spread);
  }
  return sample_sum > 0.0f;
}

static SDL_PixelFormat* sdl_alloc_rgba_format_or_exit(void) {
  SDL_PixelFormat* rgba_format = SDL_AllocFormat(SDL_PIXELFORMAT_RGBA8888);
  if (!rgba_format) {
    fprintf(stderr, "fatal: failed to allocate pixel format: %s\n", SDL_GetError());
    exit(1);
  }
  return rgba_format;
}

static uint32_t sdl_map_white_alpha(SDL_PixelFormat* rgba_format, uint8_t alpha) {
  return SDL_MapRGBA(
    rgba_format,
    VR_RGBA_CHANNEL_MAX,
    VR_RGBA_CHANNEL_MAX,
    VR_RGBA_CHANNEL_MAX,
    alpha);
}

static void sdl_convert_msdf_to_rgba(const uint8_t* msdf, int width, int height, uint8_t* rgba) {
  SDL_PixelFormat* rgba_format = sdl_alloc_rgba_format_or_exit();
  bool invert_sign = sdl_msdf_is_inverted(msdf, width, height, VR_MSDF_RECON_SPREAD);
  size_t pixel_count = (size_t)width * (size_t)height;
  uint32_t* out = (uint32_t*)rgba;
  int x = 0;
  int y = 0;
  for (size_t i = 0; i < pixel_count; ++i) {
    uint8_t alpha = msdf ? sdl_msdf_to_alpha(msdf, x, y, width, height, VR_MSDF_RECON_SPREAD, invert_sign) : 0u;
    out[i] = sdl_map_white_alpha(rgba_format, alpha);
    ++x;
    if (x == width) {
      x = 0;
      ++y;
    }
  }
  SDL_FreeFormat(rgba_format);
}

static void sdl_convert_gray_to_rgba(const uint8_t* gray, int width, int height, uint8_t* rgba) {
  SDL_PixelFormat* rgba_format = sdl_alloc_rgba_format_or_exit();
  size_t pixel_count = (size_t)width * (size_t)height;
  uint32_t* out = (uint32_t*)rgba;
  for (size_t i = 0; i < pixel_count; ++i) {
    uint8_t alpha = gray ? gray[i] : 0u;
    out[i] = sdl_map_white_alpha(rgba_format, alpha);
  }
  SDL_FreeFormat(rgba_format);
}

static void sdl_convert_bitmap_to_rgba(
  const uint8_t* pixels,
  int width,
  int height,
  uint8_t* rgba,
  vr_font_atlas_format_t atlas_format) {
  if (atlas_format == VR_FONT_ATLAS_FORMAT_MSDF_RGB) {
    sdl_convert_msdf_to_rgba(pixels, width, height, rgba);
  } else {
    sdl_convert_gray_to_rgba(pixels, width, height, rgba);
  }
}

static void sdl_ensure_texture_slot(sdl_gl_iface_t* iface, uint32_t texture_id) {
  if ((size_t)texture_id < iface->texture_cap) {
    return;
  }
  size_t next_cap = iface->texture_cap == 0u ? VR_TEXTURE_SLOT_INITIAL_CAP : iface->texture_cap * 2u;
  while (next_cap <= (size_t)texture_id) {
    next_cap *= 2u;
  }
  SDL_Texture** next = (SDL_Texture**)realloc(iface->textures, next_cap * sizeof(SDL_Texture*));
  if (!next) {
    fprintf(stderr, "fatal: out of memory while allocating texture slots\n");
    exit(1);
  }
  if (next_cap > iface->texture_cap) {
    memset(
      next + iface->texture_cap,
      0,
      (next_cap - iface->texture_cap) * sizeof(SDL_Texture*));
  }
  iface->textures = next;
  iface->texture_cap = next_cap;
}

static void sdl_create_texture(void* user, uint32_t* out_texture, int width, int height, const void* pixels) {
  sdl_gl_iface_t* iface = (sdl_gl_iface_t*)user;
  SDL_Texture* tex = SDL_CreateTexture(
    iface->renderer,
    SDL_PIXELFORMAT_RGBA8888,
    SDL_TEXTUREACCESS_STREAMING,
    width,
    height);
  if (!tex) {
    fprintf(stderr, "fatal: failed to create SDL texture: %s\n", SDL_GetError());
    exit(1);
  }
  SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);

  uint8_t* rgba = (uint8_t*)malloc((size_t)width * (size_t)height * 4u);
  if (!rgba) {
    SDL_DestroyTexture(tex);
    fprintf(stderr, "fatal: out of memory while staging atlas upload\n");
    exit(1);
  }
  sdl_convert_bitmap_to_rgba(
    (const uint8_t*)pixels,
    width,
    height,
    rgba,
    iface->atlas_format);
  if (SDL_UpdateTexture(tex, NULL, rgba, width * 4u) != 0) {
    free(rgba);
    SDL_DestroyTexture(tex);
    fprintf(stderr, "fatal: failed to upload atlas to SDL texture: %s\n", SDL_GetError());
    exit(1);
  }
  free(rgba);

  uint32_t id = iface->next_texture_id++;
  if (id == 0u) {
    id = iface->next_texture_id++;
  }
  sdl_ensure_texture_slot(iface, id);
  iface->textures[id] = tex;
  *out_texture = id;
}

static void sdl_update_texture(void* user, uint32_t texture, int x, int y, int w, int h, const void* pixels) {
  sdl_gl_iface_t* iface = (sdl_gl_iface_t*)user;
  if (texture >= iface->texture_cap || !iface->textures[texture]) {
    fprintf(stderr, "fatal: invalid atlas texture id %u in update callback\n", texture);
    exit(1);
  }

  uint8_t* rgba = (uint8_t*)malloc((size_t)w * (size_t)h * 4u);
  if (!rgba) {
    fprintf(stderr, "fatal: out of memory while staging atlas update\n");
    exit(1);
  }
  sdl_convert_bitmap_to_rgba(
    (const uint8_t*)pixels,
    w,
    h,
    rgba,
    iface->atlas_format);
  SDL_Rect rect = {x, y, w, h};
  if (SDL_UpdateTexture(iface->textures[texture], &rect, rgba, w * 4u) != 0) {
    free(rgba);
    fprintf(stderr, "fatal: failed to update atlas texture %u: %s\n", texture, SDL_GetError());
    exit(1);
  }
  free(rgba);
}

static void sdl_destroy_texture(void* user, uint32_t texture) {
  sdl_gl_iface_t* iface = (sdl_gl_iface_t*)user;
  if (!iface->textures || texture >= iface->texture_cap) {
    return;
  }
  if (iface->textures[texture]) {
    SDL_DestroyTexture(iface->textures[texture]);
    iface->textures[texture] = NULL;
  }
}

static SDL_Vertex* build_render_vertices(const vr_vertex_t* verts, size_t vertex_count, size_t* out_count) {
  SDL_Vertex* rv = (SDL_Vertex*)malloc(vertex_count * sizeof(SDL_Vertex));
  if (!rv) {
    fprintf(stderr, "fatal: out of memory while building render vertices\n");
    exit(1);
  }

  SDL_Color white = {
    VR_RGBA_CHANNEL_MAX,
    VR_RGBA_CHANNEL_MAX,
    VR_RGBA_CHANNEL_MAX,
    VR_RGBA_CHANNEL_MAX};
  for (size_t i = 0; i < vertex_count; ++i) {
    rv[i].position.x = verts[i].x;
    rv[i].position.y = verts[i].y;
    rv[i].tex_coord.x = verts[i].u;
    rv[i].tex_coord.y = verts[i].v;
    rv[i].color = white;
  }

  *out_count = vertex_count;
  return rv;
}

static bool sdl_render_demo_frame(sdl_demo_app_t* app) {
  SDL_SetRenderDrawColor(
    app->renderer,
    VR_UI_BACKGROUND_RED,
    VR_UI_BACKGROUND_GREEN,
    VR_UI_BACKGROUND_BLUE,
    VR_UI_BACKGROUND_ALPHA);
  SDL_RenderClear(app->renderer);

  for (size_t l = 0u; l < VR_DEMO_LAYER_COUNT; ++l) {
    //@optimizer-ignore demo render loop checks each fixed visual layer for visible ranges
    if (app->layer_render_data[l].range_count == 0u || app->layer_vertex_counts[l] == 0u) {
      continue;
    }
    //@optimizer-ignore demo render loop must submit each atlas range in each visible layer
    for (size_t r = 0u; r < app->layer_render_data[l].range_count; ++r) {
      //@optimizer-ignore demo render loop indexes per-layer atlas ranges for draw submission
      const vr_vertex_atlas_range_t* range = &app->layer_render_data[l].ranges[r];
      if (range->vertex_count == 0u) {
        continue;
      }
      //@optimizer-ignore demo render loop validates each atlas range against layer vertex bounds
      if (range->start_vertex + range->vertex_count > app->layer_render_data[l].vertex_count) {
        fprintf(stderr, "fatal: malformed atlas range\n");
        return false;
      }

      uint32_t tex = 0u;
      if (vr_font_atlas_texture(app->face, range->atlas_id, &tex) != VR_OK) {
        fprintf(stderr, "fatal: invalid atlas id in range %zu\n", r);
        return false;
      }
      if (tex >= app->gl_iface.texture_cap || !app->gl_iface.textures[tex]) {
        fprintf(stderr, "fatal: missing texture for atlas id %u\n", range->atlas_id);
        return false;
      }

      SDL_Vertex* batch_start = app->layer_vertices[l] + range->start_vertex;
      int batch_count = (int)range->vertex_count;
      //@optimizer-ignore demo render loop submits each atlas-backed geometry batch
      if (SDL_RenderGeometry(
            //@optimizer-ignore demo render loop passes the SDL renderer for each geometry batch
            app->renderer,
            app->gl_iface.textures[tex],
            batch_start,
            batch_count,
            NULL,
            0) != 0) {
        fprintf(stderr, "fatal: SDL_RenderGeometry failed: %s\n", SDL_GetError());
        return false;
      }
    }
  }

  SDL_RenderPresent(app->renderer);
  return true;
}

static bool sdl_save_snapshot(SDL_Renderer* renderer, const char* path) {
  if (!renderer || !path) {
    return false;
  }
  SDL_Surface* surface = SDL_CreateRGBSurfaceWithFormat(0, VR_UI_WINDOW_WIDTH, VR_UI_WINDOW_HEIGHT, VR_SDL_BYTES_PER_PIXEL_RGBA * CHAR_BIT, SDL_PIXELFORMAT_RGBA8888);
  if (!surface) {
    fprintf(stderr, "fatal: failed to allocate snapshot surface: %s\n", SDL_GetError());
    return false;
  }
  if (SDL_RenderReadPixels(renderer, NULL, SDL_PIXELFORMAT_RGBA8888, surface->pixels, surface->pitch) != 0) {
    fprintf(stderr, "fatal: failed to read snapshot pixels: %s\n", SDL_GetError());
    SDL_FreeSurface(surface);
    return false;
  }
  if (SDL_SaveBMP(surface, path) != 0) {
    fprintf(stderr, "fatal: failed to save snapshot '%s': %s\n", path, SDL_GetError());
    SDL_FreeSurface(surface);
    return false;
  }
  SDL_FreeSurface(surface);
  return true;
}

static uint32_t utf8_to_codepoints(const char* text, uint32_t** out_codepoints, size_t* out_count) {
  if (!text || !out_codepoints || !out_count) return 0u;

  size_t len = strlen(text);
  if (len == 0) {
    *out_codepoints = NULL;
    *out_count = 0u;
    return VR_OK;
  }

  uint32_t* cps = (uint32_t*)malloc(len * sizeof(uint32_t));
  if (!cps) {
    return VR_ERR_OOM;
  }
  for (size_t i = 0; i < len; ++i) {
    unsigned char ch = (unsigned char)text[i];
    if (ch >= VR_UTF8_MAX_ASCII) {
      //@optimizer-ignore demo ASCII conversion releases output buffer on unsupported input
      free(cps);
      return VR_ERR_UNSUPPORTED;
    }
    cps[i] = (uint32_t)ch;
  }
  *out_codepoints = cps;
  *out_count = len;
  return VR_OK;
}

int main(int argc, char** argv) {
  const char* font_path = NULL;
  const char* text = NULL;
  const char* snapshot_path = NULL;
  vr_font_atlas_format_t demo_atlas_format = VR_FONT_DEFAULT_ATLAS_FORMAT;
  for (int arg = 1; arg < argc; ++arg) {
    if (strcmp(argv[arg], VR_DEMO_SNAPSHOT_FLAG) == 0) {
      if (arg + 1 >= argc) {
        fprintf(stderr, "fatal: --snapshot requires an output BMP path\n");
        return 1;
      }
      snapshot_path = argv[++arg];
    } else if (strcmp(argv[arg], VR_DEMO_ALPHA8_FLAG) == 0) {
      demo_atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
    } else if (strcmp(argv[arg], VR_DEMO_MSDF_FLAG) == 0) {
      demo_atlas_format = VR_FONT_ATLAS_FORMAT_MSDF_RGB;
    } else if (!font_path) {
      font_path = argv[arg];
    } else if (!text) {
      text = argv[arg];
    } else {
      fprintf(stderr, "fatal: unexpected argument '%s'\n", argv[arg]);
      return 1;
    }
  }
  const bool using_default_font = (font_path == NULL);
  if (!font_path) {
    font_path = VR_FALLBACK_FONT_PATH;
  }
  if (!text) {
    text = VR_DEFAULT_TEXT;
  }
  int exit_code = 1;

  sdl_demo_app_t app = {
    .gl_iface = {0},
    .window = NULL,
    .renderer = NULL,
    .face = NULL,
    .codepoints = NULL,
    .codepoint_count = 0u,
    .layer_render_data = NULL,
    .layer_vertices = NULL,
    .layer_vertex_counts = NULL,
    .sdl_ready = false,
    .snapshot_path = snapshot_path,
  };
  app.gl_iface.next_texture_id = 1u;

  vr_status_t st = VR_OK;
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    fprintf(stderr, "fatal: SDL_Init failed: %s\n", SDL_GetError());
    goto cleanup;
  }
  app.sdl_ready = true;

  app.window = SDL_CreateWindow(
    "VR Font SDL Demo",
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    VR_UI_WINDOW_WIDTH,
    VR_UI_WINDOW_HEIGHT,
    app.snapshot_path ? SDL_WINDOW_HIDDEN : SDL_WINDOW_SHOWN);
  if (!app.window) {
    fprintf(stderr, "fatal: SDL_CreateWindow failed: %s\n", SDL_GetError());
    goto cleanup;
  }

  app.renderer = SDL_CreateRenderer(
    app.window,
    VR_SDL_RENDERER_INDEX_AUTO,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!app.renderer) {
    fprintf(stderr, "fatal: SDL_CreateRenderer failed: %s\n", SDL_GetError());
    goto cleanup;
  }
  if (SDL_SetRenderDrawBlendMode(app.renderer, SDL_BLENDMODE_BLEND) != 0) {
    fprintf(stderr, "fatal: failed to configure draw blend mode: %s\n", SDL_GetError());
    goto cleanup;
  }

  app.gl_iface.renderer = app.renderer;
  vr_gl_iface_t gi = {0};
  gi.create_texture = sdl_create_texture;
  gi.update_texture = sdl_update_texture;
  gi.destroy_texture = sdl_destroy_texture;
  gi.user = &app.gl_iface;

  vr_font_config_t cfg = {
    .px_size = VR_FONT_DEFAULT_PX_SIZE,
    .atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION,
    .atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION,
    .atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING,
    .atlas_format = demo_atlas_format,
    .allocator = {NULL, demo_alloc, demo_realloc, demo_free},
    .gl = gi,
  };
  app.gl_iface.atlas_format = cfg.atlas_format;
  st = demo_create_face_from_path(&app.face, font_path, &cfg);
  if (st != VR_OK) {
    fprintf(stderr, "fatal: failed to load face '%s' status=%u\n", font_path, st);
    if (using_default_font) {
      fprintf(stderr, "download source: https://raw.githubusercontent.com/vercel/geist-font/main/fonts/Geist/variable/Geist%%5Bwght%%5D.ttf\n");
      fprintf(stderr, "save it as fonts/Geist[wght].ttf\n");
    }
    goto cleanup;
  }

  st = utf8_to_codepoints(text, &app.codepoints, &app.codepoint_count);
  if (st != VR_OK) {
    fprintf(stderr, "fatal: unsupported characters in text\n");
    goto cleanup;
  }

  app.layer_render_data = (demo_layer_render_t*)calloc(VR_DEMO_LAYER_COUNT, sizeof(demo_layer_render_t));
  if (!app.layer_render_data) {
    goto cleanup;
  }

  st = sdl_build_demo_layers(
    app.face,
    app.codepoints,
    app.codepoint_count,
    app.layer_render_data,
    VR_DEMO_LAYER_COUNT);
  if (st != VR_OK) {
    goto cleanup;
  }

  app.layer_vertices = (SDL_Vertex**)calloc(VR_DEMO_LAYER_COUNT, sizeof(SDL_Vertex*));
  app.layer_vertex_counts = (size_t*)calloc(VR_DEMO_LAYER_COUNT, sizeof(size_t));
  if (!app.layer_vertices || !app.layer_vertex_counts) {
    goto cleanup;
  }

  for (size_t i = 0u; i < VR_DEMO_LAYER_COUNT; ++i) {
    //@optimizer-ignore demo vertex upload checks each fixed visual layer
    if (app.layer_render_data[i].range_count == 0u) {
      continue;
    }
    //@optimizer-ignore demo vertex upload builds one SDL vertex buffer per visual layer
    app.layer_vertices[i] = build_render_vertices(
      //@optimizer-ignore demo vertex upload consumes per-layer render vertices
      app.layer_render_data[i].verts,
      //@optimizer-ignore demo vertex upload consumes per-layer render vertex counts
      app.layer_render_data[i].vertex_count,
      &app.layer_vertex_counts[i]);
    if (!app.layer_vertices[i]) {
      goto cleanup;
    }
  }

  if (app.snapshot_path) {
    if (!sdl_render_demo_frame(&app)) {
      goto cleanup;
    }
    if (!sdl_save_snapshot(app.renderer, app.snapshot_path)) {
      goto cleanup;
    }
    exit_code = 0;
    goto cleanup;
  }

  bool running = true;
  while (running) {
    SDL_Event e;
    //@optimizer-ignore demo event pump must drain queued SDL events every frame
    while (SDL_PollEvent(&e) == 1) {
      if (e.type == SDL_QUIT) {
        running = false;
      } else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) {
        running = false;
      }
    }

    //@optimizer-ignore demo main loop renders one frame per SDL tick
    running = sdl_render_demo_frame(&app);
    SDL_Delay(VR_RENDER_DELAY_MS);
  }

  exit_code = 0;

cleanup:
  sdl_demo_release(&app);
  return exit_code;
}

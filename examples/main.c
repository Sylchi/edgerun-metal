#include "vr_font.h"

#include <SDL2/SDL.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  SDL_Renderer* renderer;
  SDL_Texture** textures;
  size_t texture_cap;
  uint32_t next_texture_id;
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

static const uint16_t VR_UI_WINDOW_WIDTH = 960u;
static const uint16_t VR_UI_WINDOW_HEIGHT = 240u;
static const uint8_t VR_UI_BACKGROUND_RED = 0u;
static const uint8_t VR_UI_BACKGROUND_GREEN = 0u;
static const uint8_t VR_UI_BACKGROUND_BLUE = 0u;
static const uint8_t VR_UI_BACKGROUND_ALPHA = 255u;
static const char* const VR_FALLBACK_FONT_PATH = "fonts/Geist[wght].ttf";
static const char* const VR_DEFAULT_TEXT = "Geist variable font in SDL";
static const float VR_TEXT_RENDER_X = 40.0f;
static const size_t VR_DEMO_LAYER_COUNT = 4u;

static const demo_layer_t VR_DEMO_LAYERS[VR_DEMO_LAYER_COUNT] = {
  {26.0f, 250.0f, VR_TEXT_RENDER_X, 48.0f},
  {34.0f, 400.0f, VR_TEXT_RENDER_X, 86.0f},
  {46.0f, 700.0f, VR_TEXT_RENDER_X, 128.0f},
  {58.0f, 900.0f, VR_TEXT_RENDER_X, 176.0f},
};

static void sdl_free_demo_layers(demo_layer_render_t* layers, size_t count) {
  for (size_t i = 0u; i < count; ++i) {
    vr_font_free_vertices(NULL, layers[i].verts);
    vr_font_free_vertex_atlas_ranges(layers[i].ranges);
    layers[i].verts = NULL;
    layers[i].vertex_count = 0u;
    layers[i].ranges = NULL;
    layers[i].range_count = 0u;
  }
}

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
    st = vr_font_set_axis(face, "wght", layer_spec->weight);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: failed to set wght %.1f: %u\n", layer_spec->weight, st);
      return st;
    }

    vr_shaped_glyph_t* shaped = NULL;
    size_t shaped_count = 0u;
    st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: shape failed for sample %zu status=%u\n", i, st);
      vr_font_free_shaped(face, shaped);
      return st;
    }
    if (shaped_count == 0u) {
      vr_font_free_shaped(face, shaped);
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
    vr_font_free_shaped(face, shaped);
    if (st != VR_OK) {
      fprintf(stderr, "fatal: batch failed for sample %zu status=%u\n", i, st);
      return st;
    }
  }
  return VR_OK;
}

static void sdl_convert_gray_to_rgba(const uint8_t* gray, int width, int height, uint8_t* rgba) {
  SDL_PixelFormat* rgba_format = SDL_AllocFormat(SDL_PIXELFORMAT_RGBA8888);
  if (!rgba_format) {
    fprintf(stderr, "fatal: failed to allocate pixel format: %s\n", SDL_GetError());
    exit(1);
  }
  size_t pixel_count = (size_t)width * (size_t)height;
  uint32_t* out = (uint32_t*)rgba;
  for (size_t i = 0; i < pixel_count; ++i) {
    uint8_t g = gray ? gray[i] : 0u;
    out[i] = SDL_MapRGBA(rgba_format, 255u, 255u, 255u, g);
  }
  SDL_FreeFormat(rgba_format);
}

static void sdl_ensure_texture_slot(sdl_gl_iface_t* iface, uint32_t texture_id) {
  if ((size_t)texture_id < iface->texture_cap) {
    return;
  }
  size_t next_cap = iface->texture_cap == 0 ? 16u : iface->texture_cap * 2u;
  while (next_cap <= (size_t)texture_id) {
    next_cap *= 2u;
  }
  SDL_Texture** next = (SDL_Texture**)realloc(iface->textures, next_cap * sizeof(SDL_Texture*));
  if (!next) {
    fprintf(stderr, "fatal: out of memory while allocating texture slots\n");
    exit(1);
  }
  if (next_cap > iface->texture_cap) {
    memset(next + iface->texture_cap, 0, (next_cap - iface->texture_cap) * sizeof(SDL_Texture*));
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
  sdl_convert_gray_to_rgba((const uint8_t*)pixels, width, height, rgba);
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
  sdl_convert_gray_to_rgba((const uint8_t*)pixels, w, h, rgba);
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

  SDL_Color white = {255, 255, 255, 255};
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
    if (ch >= 0x80u) {
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
  const char* font_path = argc > 1 ? argv[1] : VR_FALLBACK_FONT_PATH;
  const char* text = argc > 2 ? argv[2] : VR_DEFAULT_TEXT;

  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    fprintf(stderr, "fatal: SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }

  SDL_Window* window = SDL_CreateWindow(
    "VR Font SDL Demo",
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    VR_UI_WINDOW_WIDTH,
    VR_UI_WINDOW_HEIGHT,
    SDL_WINDOW_SHOWN);
  if (!window) {
    fprintf(stderr, "fatal: SDL_CreateWindow failed: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Renderer* renderer = SDL_CreateRenderer(
    window,
    -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!renderer) {
    fprintf(stderr, "fatal: SDL_CreateRenderer failed: %s\n", SDL_GetError());
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }
  if (SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_NONE) != 0) {
    fprintf(stderr, "fatal: failed to configure draw blend mode: %s\n", SDL_GetError());
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

  sdl_gl_iface_t iface = {
    .renderer = renderer,
    .textures = NULL,
    .texture_cap = 0,
    .next_texture_id = 1u,
  };

  vr_gl_iface_t gi = {0};
  gi.create_texture = sdl_create_texture;
  gi.update_texture = sdl_update_texture;
  gi.destroy_texture = sdl_destroy_texture;
  gi.user = &iface;

  vr_font_config_t cfg = {
    .px_size = VR_FONT_DEFAULT_PX_SIZE,
    .atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION,
    .atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION,
    .atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING,
    .gl = gi,
  };

  vr_font_face_t* face = NULL;
  vr_status_t st = vr_font_face_create(&face, font_path, &cfg);
  if (st != VR_OK) {
    fprintf(stderr, "fatal: failed to load face '%s' status=%u\n", font_path, st);
    if (argc <= 1) {
      fprintf(stderr, "download source: https://raw.githubusercontent.com/vercel/geist-font/main/fonts/Geist/variable/Geist%%5Bwght%%5D.ttf\n");
      fprintf(stderr, "save it as fonts/Geist[wght].ttf\n");
    }
    free(iface.textures);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

  uint32_t* cps = NULL;
  size_t cp_count = 0;
  if (utf8_to_codepoints(text, &cps, &cp_count) != VR_OK) {
    fprintf(stderr, "fatal: unsupported characters in text\n");
    vr_font_face_destroy(face);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    free(iface.textures);
    return 1;
  }

  demo_layer_render_t* demo_layers = (demo_layer_render_t*)calloc(VR_DEMO_LAYER_COUNT, sizeof(demo_layer_render_t));
  if (!demo_layers) {
    free(cps);
    vr_font_face_destroy(face);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    free(iface.textures);
    return 1;
  }

  st = sdl_build_demo_layers(face, cps, cp_count, demo_layers, VR_DEMO_LAYER_COUNT);
  free(cps);
  if (st != VR_OK) {
    sdl_free_demo_layers(demo_layers, VR_DEMO_LAYER_COUNT);
    free(demo_layers);
    vr_font_face_destroy(face);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    free(iface.textures);
    return 1;
  }

  SDL_Vertex** layer_render_verts = (SDL_Vertex**)calloc(VR_DEMO_LAYER_COUNT, sizeof(SDL_Vertex*));
  size_t* layer_render_counts = (size_t*)calloc(VR_DEMO_LAYER_COUNT, sizeof(size_t));
  if (!layer_render_verts || !layer_render_counts) {
    free(layer_render_verts);
    free(layer_render_counts);
    sdl_free_demo_layers(demo_layers, VR_DEMO_LAYER_COUNT);
    free(demo_layers);
    vr_font_face_destroy(face);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    free(iface.textures);
    return 1;
  }

  for (size_t i = 0u; i < VR_DEMO_LAYER_COUNT; ++i) {
    if (demo_layers[i].range_count == 0u) {
      continue;
    }
    layer_render_verts[i] = build_render_vertices(
      demo_layers[i].verts,
      demo_layers[i].vertex_count,
      &layer_render_counts[i]);
    if (!layer_render_verts[i]) {
      for (size_t j = 0u; j < i; ++j) {
        free(layer_render_verts[j]);
      }
      free(layer_render_verts);
      free(layer_render_counts);
      sdl_free_demo_layers(demo_layers, VR_DEMO_LAYER_COUNT);
      free(demo_layers);
      vr_font_face_destroy(face);
      SDL_DestroyRenderer(renderer);
      SDL_DestroyWindow(window);
      SDL_Quit();
      free(iface.textures);
      return 1;
    }
  }

  bool running = true;
  while (running) {
    SDL_Event e;
    while (SDL_PollEvent(&e) == 1) {
      if (e.type == SDL_QUIT) {
        running = false;
      } else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) {
        running = false;
      }
    }

    SDL_SetRenderDrawColor(
      renderer,
      VR_UI_BACKGROUND_RED,
      VR_UI_BACKGROUND_GREEN,
      VR_UI_BACKGROUND_BLUE,
      VR_UI_BACKGROUND_ALPHA);
    SDL_RenderClear(renderer);

    for (size_t l = 0u; l < VR_DEMO_LAYER_COUNT; ++l) {
      if (demo_layers[l].range_count == 0u || layer_render_counts[l] == 0u) {
        continue;
      }
      for (size_t r = 0u; r < demo_layers[l].range_count; ++r) {
        const vr_vertex_atlas_range_t* range = &demo_layers[l].ranges[r];
        if (range->vertex_count == 0u) {
          continue;
        }
        if (range->start_vertex + range->vertex_count > demo_layers[l].vertex_count) {
          fprintf(stderr, "fatal: malformed atlas range\n");
          running = false;
          break;
        }

        uint32_t tex = 0u;
        if (vr_font_atlas_texture(face, range->atlas_id, &tex) != VR_OK) {
          fprintf(stderr, "fatal: invalid atlas id in range %zu\n", r);
          running = false;
          break;
        }
        if (tex >= iface.texture_cap || !iface.textures[tex]) {
          fprintf(stderr, "fatal: missing texture for atlas id %u\n", range->atlas_id);
          running = false;
          break;
        }

        SDL_Vertex* batch_start = layer_render_verts[l] + range->start_vertex;
        int batch_count = (int)range->vertex_count;
        if (SDL_RenderGeometry(
              renderer,
              iface.textures[tex],
              batch_start,
              batch_count,
              NULL,
              0) != 0) {
          fprintf(stderr, "fatal: SDL_RenderGeometry failed: %s\n", SDL_GetError());
          running = false;
          break;
        }
      }
      if (!running) {
        break;
      }
    }

    SDL_RenderPresent(renderer);
    SDL_Delay(16);
  }

  for (size_t i = 0u; i < VR_DEMO_LAYER_COUNT; ++i) {
    free(layer_render_verts[i]);
    vr_font_free_vertices(face, demo_layers[i].verts);
    vr_font_free_vertex_atlas_ranges(demo_layers[i].ranges);
  }
  free(layer_render_verts);
  free(layer_render_counts);
  free(demo_layers);
  vr_font_face_destroy(face);

  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  free(iface.textures);
  return 0;
}

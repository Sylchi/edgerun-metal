#include "er_ui_painter.h"
#include "er_ui_scene.h"
#include "er_ui_shell.h"
#include "er_ui_text.h"
#include "er_ui_theme.h"
#include "vr_font.h"

#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ER_UI_SDL_WINDOW_WIDTH 1280
#define ER_UI_SDL_WINDOW_HEIGHT 800
#define ER_UI_SDL_WINDOW_FLAGS (SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE)
#define ER_UI_SDL_RENDERER_AUTO (-1)
#define ER_UI_SDL_FONT_ATLAS_SIZE 1024u
#define ER_UI_SDL_FONT_SIZE 18.0f
#define ER_UI_SDL_FONT_PAD 2u
#define ER_UI_SDL_BYTES_PER_PIXEL 4u
#define ER_UI_SDL_RGBA_R 0u
#define ER_UI_SDL_RGBA_G 1u
#define ER_UI_SDL_RGBA_B 2u
#define ER_UI_SDL_RGBA_A 3u
#define ER_UI_SDL_COLOR_MAX 255.0f
#define ER_UI_SDL_COLOR_FULL 255u
#define ER_UI_SDL_SURFACE_MAIN 1u
#define ER_UI_SDL_SURFACE_LOG 2u
#define ER_UI_SDL_SURFACE_DIFF 3u
#define ER_UI_SDL_TEXT_BUDGET 96u
#define ER_UI_SDL_QUAD_VERTICES 6u
#define ER_UI_SDL_TERMINAL_LINE_COUNT 7u
#define ER_UI_SDL_STATUS_COUNT 3u
#define ER_UI_SDL_ICON_ATLAS_WIDTH 1
#define ER_UI_SDL_ICON_ATLAS_HEIGHT 1
#define ER_UI_SDL_MOUSE_PRIMARY 1u
#define ER_UI_SDL_FRAME_DELAY_MS 16u
#define ER_UI_SDL_CENTER_DIVISOR 2.0f
#define ER_UI_SDL_HEADER_H 64.0f
#define ER_UI_SDL_COMPOSER_H 132.0f
#define ER_UI_SDL_PAD 16.0f
#define ER_UI_SDL_GAP 12.0f
#define ER_UI_SDL_RADIUS 18.0f
#define ER_UI_SDL_SMALL_RADIUS 10.0f
#define ER_UI_SDL_STATUS_DOT 10.0f
#define ER_UI_SDL_BUTTON_W 120.0f
#define ER_UI_SDL_BUTTON_H 38.0f
#define ER_UI_SDL_CARD_W 216.0f
#define ER_UI_SDL_CARD_H 74.0f
#define ER_UI_SDL_CARD_TITLE_Y 28.0f
#define ER_UI_SDL_CARD_BODY_Y 56.0f
#define ER_UI_SDL_LINE_H 26.0f
#define ER_UI_SDL_SURFACE_TITLE_Y 34.0f
#define ER_UI_SDL_SURFACE_BODY_Y 62.0f
#define ER_UI_SDL_TRANSCRIPT_Y 170.0f
#define ER_UI_SDL_TRANSCRIPT_BOTTOM_PAD 190.0f
#define ER_UI_SDL_TRANSCRIPT_FIRST_LINE_Y 32.0f
#define ER_UI_SDL_COMPOSER_LABEL_Y 34.0f
#define ER_UI_SDL_COMPOSER_PROMPT_Y 70.0f
#define ER_UI_SDL_SEND_TEXT_X 38.0f
#define ER_UI_SDL_SEND_TEXT_Y 25.0f
#define ER_UI_SDL_TEXTURE_INITIAL_CAPACITY 8u
#define ER_UI_SDL_WINDOW_EVENT_IGNORED 0u
#define ER_UI_SDL_SELF_TEST_ARG "--self-test"
#define ER_UI_SDL_SELF_TEST_FRAMES 2u

typedef struct {
  SDL_Texture** textures;
  size_t texture_capacity;
  SDL_Renderer* renderer;
} ErUiSdlTextureStore;

typedef struct {
  SDL_Window* window;
  SDL_Renderer* renderer;
  SDL_Texture* icon_texture;
  ErUiSdlTextureStore textures;
  er_ui_scene_t scene;
  er_ui_shell_state_t shell;
  vr_font_face_t* font;
  int width;
  int height;
  bool running;
  bool self_test;
  uint32_t rendered_frames;
} ErUiSdlApp;

static void* er_ui_sdl_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* er_ui_sdl_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void er_ui_sdl_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static uint8_t er_ui_sdl_channel(float value) {
  if (value <= 0.0f) return 0u;
  if (value >= 1.0f) return ER_UI_SDL_COLOR_FULL;
  return (uint8_t)(value * ER_UI_SDL_COLOR_MAX);
}

static SDL_Color er_ui_sdl_color(er_ui_color4_t color) {
  SDL_Color out = {
    er_ui_sdl_channel(color.r),
    er_ui_sdl_channel(color.g),
    er_ui_sdl_channel(color.b),
    er_ui_sdl_channel(color.a)};
  return out;
}

static void er_ui_sdl_set_color(SDL_Renderer* renderer, er_ui_color4_t color) {
  SDL_Color c = er_ui_sdl_color(color);
  if (SDL_SetRenderDrawColor(renderer, c.r, c.g, c.b, c.a) != 0) {
    fprintf(stderr, "fatal: SDL_SetRenderDrawColor failed: %s\n", SDL_GetError());
    exit(1);
  }
}

static void er_ui_sdl_ensure_texture(ErUiSdlTextureStore* store, uint32_t texture_id) {
  if ((size_t)texture_id < store->texture_capacity) return;
  size_t next_capacity = store->texture_capacity == 0u ? ER_UI_SDL_TEXTURE_INITIAL_CAPACITY : store->texture_capacity;
  while (next_capacity <= (size_t)texture_id) next_capacity *= 2u;
  SDL_Texture** next = (SDL_Texture**)realloc(store->textures, next_capacity * sizeof(*next));
  if (!next) {
    fprintf(stderr, "fatal: out of memory while growing texture table\n");
    exit(1);
  }
  for (size_t i = store->texture_capacity; i < next_capacity; ++i) next[i] = NULL;
  store->textures = next;
  store->texture_capacity = next_capacity;
}

static void er_ui_sdl_upload_alpha_rgba(const uint8_t* pixels, int width, int height, uint8_t* rgba) {
  size_t pixel_count = (size_t)width * (size_t)height;
  for (size_t i = 0u; i < pixel_count; ++i) {
    size_t offset = i * ER_UI_SDL_BYTES_PER_PIXEL;
    rgba[offset + ER_UI_SDL_RGBA_R] = ER_UI_SDL_COLOR_FULL;
    rgba[offset + ER_UI_SDL_RGBA_G] = ER_UI_SDL_COLOR_FULL;
    rgba[offset + ER_UI_SDL_RGBA_B] = ER_UI_SDL_COLOR_FULL;
    rgba[offset + ER_UI_SDL_RGBA_A] = pixels ? pixels[i] : 0u;
  }
}

static SDL_Texture* er_ui_sdl_create_alpha_texture(SDL_Renderer* renderer, int width, int height, const uint8_t* pixels) {
  SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, width, height);
  if (!texture) {
    fprintf(stderr, "fatal: SDL_CreateTexture failed: %s\n", SDL_GetError());
    exit(1);
  }
  if (SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND) != 0) {
    fprintf(stderr, "fatal: SDL_SetTextureBlendMode failed: %s\n", SDL_GetError());
    exit(1);
  }
  uint8_t* rgba = (uint8_t*)malloc((size_t)width * (size_t)height * ER_UI_SDL_BYTES_PER_PIXEL);
  if (!rgba) {
    fprintf(stderr, "fatal: out of memory while staging texture upload\n");
    exit(1);
  }
  er_ui_sdl_upload_alpha_rgba(pixels, width, height, rgba);
  if (SDL_UpdateTexture(texture, NULL, rgba, width * ER_UI_SDL_BYTES_PER_PIXEL) != 0) {
    fprintf(stderr, "fatal: SDL_UpdateTexture failed: %s\n", SDL_GetError());
    exit(1);
  }
  free(rgba);
  return texture;
}

static void er_ui_sdl_create_font_texture(void* user, uint32_t* out_texture, int width, int height, const void* pixels) {
  ErUiSdlTextureStore* store = (ErUiSdlTextureStore*)user;
  uint32_t texture_id = (uint32_t)store->texture_capacity;
  if (texture_id == 0u) texture_id = 1u;
  er_ui_sdl_ensure_texture(store, texture_id);
  while (store->textures[texture_id]) {
    texture_id++;
    er_ui_sdl_ensure_texture(store, texture_id);
  }
  store->textures[texture_id] = er_ui_sdl_create_alpha_texture(store->renderer, width, height, (const uint8_t*)pixels);
  *out_texture = texture_id;
}

static void er_ui_sdl_update_font_texture(void* user, uint32_t texture, int x, int y, int width, int height, const void* pixels) {
  ErUiSdlTextureStore* store = (ErUiSdlTextureStore*)user;
  if ((size_t)texture >= store->texture_capacity || !store->textures[texture]) {
    fprintf(stderr, "fatal: invalid font texture id %u\n", texture);
    exit(1);
  }
  uint8_t* rgba = (uint8_t*)malloc((size_t)width * (size_t)height * ER_UI_SDL_BYTES_PER_PIXEL);
  if (!rgba) {
    fprintf(stderr, "fatal: out of memory while staging texture update\n");
    exit(1);
  }
  er_ui_sdl_upload_alpha_rgba((const uint8_t*)pixels, width, height, rgba);
  SDL_Rect rect = {x, y, width, height};
  if (SDL_UpdateTexture(store->textures[texture], &rect, rgba, width * ER_UI_SDL_BYTES_PER_PIXEL) != 0) {
    fprintf(stderr, "fatal: SDL_UpdateTexture update failed: %s\n", SDL_GetError());
    exit(1);
  }
  free(rgba);
}

static void er_ui_sdl_destroy_font_texture(void* user, uint32_t texture) {
  ErUiSdlTextureStore* store = (ErUiSdlTextureStore*)user;
  if ((size_t)texture >= store->texture_capacity || !store->textures[texture]) return;
  SDL_DestroyTexture(store->textures[texture]);
  store->textures[texture] = NULL;
}

static uint8_t* er_ui_sdl_read_file(const char* path, size_t* out_size) {
  if (!path || !out_size) {
    fprintf(stderr, "fatal: invalid file read request\n");
    exit(1);
  }
  *out_size = 0u;
  FILE* file = fopen(path, "rb");
  if (!file) {
    fprintf(stderr, "fatal: failed to open %s\n", path);
    exit(1);
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    fprintf(stderr, "fatal: failed to seek %s\n", path);
    exit(1);
  }
  long signed_size = ftell(file);
  if (signed_size <= 0) {
    fclose(file);
    fprintf(stderr, "fatal: invalid size for %s\n", path);
    exit(1);
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    fprintf(stderr, "fatal: failed to rewind %s\n", path);
    exit(1);
  }
  size_t size = (size_t)signed_size;
  uint8_t* data = (uint8_t*)malloc(size);
  if (!data) {
    fclose(file);
    fprintf(stderr, "fatal: out of memory while reading %s\n", path);
    exit(1);
  }
  size_t read = fread(data, 1u, size, file);
  fclose(file);
  if (read != size) {
    free(data);
    fprintf(stderr, "fatal: failed to read %s\n", path);
    exit(1);
  }
  *out_size = size;
  return data;
}

static void er_ui_sdl_draw_rect(SDL_Renderer* renderer, er_ui_rect_t rect) {
  SDL_FRect dst = {rect.x, rect.y, rect.w, rect.h};
  er_ui_sdl_set_color(renderer, rect.color);
  switch (rect.mode) {
    case ER_UI_RECT_FILL:
    case ER_UI_RECT_SHADOW:
    case ER_UI_RECT_LINEAR_GRADIENT:
      if (SDL_RenderFillRectF(renderer, &dst) != 0) {
        fprintf(stderr, "fatal: SDL_RenderFillRectF failed: %s\n", SDL_GetError());
        exit(1);
      }
      break;
    case ER_UI_RECT_BORDER:
      if (SDL_RenderDrawRectF(renderer, &dst) != 0) {
        fprintf(stderr, "fatal: SDL_RenderDrawRectF failed: %s\n", SDL_GetError());
        exit(1);
      }
      break;
  }
}

static void er_ui_sdl_draw_text_quad(ErUiSdlApp* app, const er_ui_quad_t* quad) {
  uint32_t texture_id = 0u;
  if (vr_font_atlas_texture(app->font, quad->atlas_id, &texture_id) != VR_OK) return;
  if ((size_t)texture_id >= app->textures.texture_capacity || !app->textures.textures[texture_id]) return;
  SDL_FRect dst = {quad->x, quad->y, quad->w, quad->h};
  SDL_Rect src = {0, 0, 0, 0};
  vr_font_atlas_view_t atlas = {0};
  if (vr_font_atlas_view(app->font, quad->atlas_id, &atlas) != VR_OK) return;
  src.x = (int)(quad->u0 * (float)atlas.width);
  src.y = (int)(quad->v0 * (float)atlas.height);
  src.w = (int)((quad->u1 - quad->u0) * (float)atlas.width);
  src.h = (int)((quad->v1 - quad->v0) * (float)atlas.height);
  SDL_Color color = er_ui_sdl_color(quad->color);
  SDL_SetTextureColorMod(app->textures.textures[texture_id], color.r, color.g, color.b);
  SDL_SetTextureAlphaMod(app->textures.textures[texture_id], color.a);
  if (SDL_RenderCopyF(app->renderer, app->textures.textures[texture_id], &src, &dst) != 0) {
    fprintf(stderr, "fatal: SDL_RenderCopyF text failed: %s\n", SDL_GetError());
    exit(1);
  }
}

static void er_ui_sdl_draw_icon_quad(ErUiSdlApp* app, const er_ui_quad_t* quad) {
  SDL_FRect dst = {quad->x, quad->y, quad->w, quad->h};
  SDL_Rect src = {0, 0, ER_UI_SDL_ICON_ATLAS_WIDTH, ER_UI_SDL_ICON_ATLAS_HEIGHT};
  SDL_Color color = er_ui_sdl_color(quad->color);
  SDL_SetTextureColorMod(app->icon_texture, color.r, color.g, color.b);
  SDL_SetTextureAlphaMod(app->icon_texture, color.a);
  if (SDL_RenderCopyF(app->renderer, app->icon_texture, &src, &dst) != 0) {
    fprintf(stderr, "fatal: SDL_RenderCopyF icon failed: %s\n", SDL_GetError());
    exit(1);
  }
}

static er_ui_status_t er_ui_sdl_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, float x, float y, er_ui_color4_t color) {
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_SDL_TEXT_BUDGET, x, y, color);
}

static er_ui_status_t er_ui_sdl_emit_card(er_ui_scene_t* scene, vr_font_face_t* font, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, const char* title, const char* body) {
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, ER_UI_SDL_SMALL_RADIUS, theme.colors.row));
  if (status != ER_UI_OK) return status;
  status = er_ui_sdl_text(scene, font, title, bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_CARD_TITLE_Y, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_sdl_text(scene, font, body, bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_CARD_BODY_Y, theme.colors.muted);
}

static const char* er_ui_sdl_terminal_line(size_t index) {
  switch (index) {
    case 0u:
      return "user  lets use edgerun-ui-core to create actual sdl ui";
    case 1u:
      return "agent inspecting shell, scene, text, and renderer primitives";
    case 2u:
      return "tool  proposed opt-in ER_UI_CORE_BUILD_SDL_HOST target";
    case 3u:
      return "agent rendering this surface from er_ui_shell_emit_scene";
    case 4u:
      return "plan  wire prompt entry, streaming events, and proposal review panes";
    case 5u:
      return "guard no terminal-only fallback in the graphical path";
    case 6u:
      return "next  replace placeholder transport with Codex client adapter";
    default:
      fprintf(stderr, "fatal: invalid terminal line index %zu\n", index);
      exit(1);
  }
}

static er_ui_status_t er_ui_sdl_emit_codex_surface(uint32_t surface_id, er_ui_scene_t* scene, vr_font_face_t* font, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, void* user) {
  (void)surface_id;
  (void)user;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, ER_UI_SDL_RADIUS, er_ui_color_with_alpha(theme.colors.panel, 0.72f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_sdl_text(scene, font, "Codex workspace", bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_SURFACE_TITLE_Y, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_sdl_text(scene, font, "Graphical shell over the existing deterministic agent workflow", bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_SURFACE_BODY_Y, theme.colors.muted);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t card = er_ui_bounds(bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_HEADER_H + ER_UI_SDL_PAD, ER_UI_SDL_CARD_W, ER_UI_SDL_CARD_H);
  status = er_ui_sdl_emit_card(scene, font, card, theme, "Context", "repo snapshot loaded");
  if (status != ER_UI_OK) return status;
  card.x += ER_UI_SDL_CARD_W + ER_UI_SDL_GAP;
  status = er_ui_sdl_emit_card(scene, font, card, theme, "Proposals", "staged in memory");
  if (status != ER_UI_OK) return status;
  card.x += ER_UI_SDL_CARD_W + ER_UI_SDL_GAP;
  status = er_ui_sdl_emit_card(scene, font, card, theme, "Verify", "repo-progress gated");
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t transcript = er_ui_bounds(bounds.x + ER_UI_SDL_PAD, bounds.y + ER_UI_SDL_TRANSCRIPT_Y, bounds.w - ER_UI_SDL_PAD * 2.0f, bounds.h - ER_UI_SDL_COMPOSER_H - ER_UI_SDL_TRANSCRIPT_BOTTOM_PAD);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(transcript.x, transcript.y, transcript.w, transcript.h, ER_UI_SDL_SMALL_RADIUS, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  for (size_t i = 0u; i < ER_UI_SDL_TERMINAL_LINE_COUNT; ++i) {
    status = er_ui_sdl_text(scene, font, er_ui_sdl_terminal_line(i), transcript.x + ER_UI_SDL_PAD, transcript.y + ER_UI_SDL_TRANSCRIPT_FIRST_LINE_Y + (float)i * ER_UI_SDL_LINE_H, theme.colors.text);
    if (status != ER_UI_OK) return status;
  }

  er_ui_bounds_t composer = er_ui_bounds(bounds.x + ER_UI_SDL_PAD, bounds.y + bounds.h - ER_UI_SDL_COMPOSER_H, bounds.w - ER_UI_SDL_PAD * 2.0f, ER_UI_SDL_COMPOSER_H - ER_UI_SDL_PAD);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(composer.x, composer.y, composer.w, composer.h, ER_UI_SDL_RADIUS, theme.colors.composer));
  if (status != ER_UI_OK) return status;
  status = er_ui_sdl_text(scene, font, "Prompt", composer.x + ER_UI_SDL_PAD, composer.y + ER_UI_SDL_COMPOSER_LABEL_Y, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_sdl_text(scene, font, "Build the SDL UI as the primary Codex experience", composer.x + ER_UI_SDL_PAD, composer.y + ER_UI_SDL_COMPOSER_PROMPT_Y, theme.colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t send = er_ui_bounds(composer.x + composer.w - ER_UI_SDL_BUTTON_W - ER_UI_SDL_PAD, composer.y + composer.h - ER_UI_SDL_BUTTON_H - ER_UI_SDL_PAD, ER_UI_SDL_BUTTON_W, ER_UI_SDL_BUTTON_H);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(send.x, send.y, send.w, send.h, ER_UI_SDL_SMALL_RADIUS, theme.colors.accent));
  if (status != ER_UI_OK) return status;
  return er_ui_sdl_text(scene, font, "Send", send.x + ER_UI_SDL_SEND_TEXT_X, send.y + ER_UI_SDL_SEND_TEXT_Y, theme.colors.accent_text);
}

static void er_ui_sdl_refresh_size(ErUiSdlApp* app) {
  int width = ER_UI_SDL_WINDOW_WIDTH;
  int height = ER_UI_SDL_WINDOW_HEIGHT;
  if (SDL_GetRendererOutputSize(app->renderer, &width, &height) != 0) {
    fprintf(stderr, "fatal: SDL_GetRendererOutputSize failed: %s\n", SDL_GetError());
    exit(1);
  }
  app->width = width;
  app->height = height;
}

static void er_ui_sdl_render(ErUiSdlApp* app) {
  er_ui_scene_clear_commands(&app->scene);
  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  er_ui_bounds_t bounds = er_ui_bounds(0.0f, 0.0f, (float)app->width, (float)app->height);
  er_ui_status_t status = er_ui_shell_emit_scene_with_font_and_surfaces(&app->shell, &app->scene, bounds, theme, app->font, er_ui_sdl_emit_codex_surface, NULL);
  if (status != ER_UI_OK) {
    fprintf(stderr, "fatal: failed to emit UI scene: %d\n", (int)status);
    exit(1);
  }

  er_ui_sdl_set_color(app->renderer, app->scene.clear);
  if (SDL_RenderClear(app->renderer) != 0) {
    fprintf(stderr, "fatal: SDL_RenderClear failed: %s\n", SDL_GetError());
    exit(1);
  }
  for (size_t i = 0u; i < app->scene.rect_count; ++i) er_ui_sdl_draw_rect(app->renderer, app->scene.rects[i]);
  for (size_t i = 0u; i < app->scene.icon_quad_count; ++i) er_ui_sdl_draw_icon_quad(app, &app->scene.icon_quads[i]);
  for (size_t i = 0u; i < app->scene.text_quad_count; ++i) er_ui_sdl_draw_text_quad(app, &app->scene.text_quads[i]);
  SDL_RenderPresent(app->renderer);
  app->rendered_frames++;
  if (app->self_test && app->rendered_frames >= ER_UI_SDL_SELF_TEST_FRAMES) app->running = false;
}

static void er_ui_sdl_activate_hit(ErUiSdlApp* app, int x, int y) {
  er_ui_hit_t hit = {0};
  if (!er_ui_scene_hit_test(&app->scene, (float)x, (float)y, &hit)) return;
  er_ui_action_t action = {0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = hit;
  bool changed = false;
  er_ui_status_t status = er_ui_shell_apply_action(&app->shell, action, &changed);
  if (status != ER_UI_OK) {
    fprintf(stderr, "fatal: shell action failed: %d\n", (int)status);
    exit(1);
  }
  (void)changed;
}

static void er_ui_sdl_handle_window_event(ErUiSdlApp* app, const SDL_WindowEvent* event) {
  switch (event->event) {
    case SDL_WINDOWEVENT_SIZE_CHANGED:
      er_ui_sdl_refresh_size(app);
      break;
    default:
      (void)ER_UI_SDL_WINDOW_EVENT_IGNORED;
      break;
  }
}

static void er_ui_sdl_handle_event(ErUiSdlApp* app, const SDL_Event* event) {
  switch (event->type) {
    case SDL_QUIT:
      app->running = false;
      break;
    case SDL_WINDOWEVENT:
      er_ui_sdl_handle_window_event(app, &event->window);
      break;
    case SDL_KEYDOWN:
      if (event->key.keysym.sym == SDLK_ESCAPE) app->running = false;
      break;
    case SDL_MOUSEBUTTONDOWN:
      if (event->button.button == ER_UI_SDL_MOUSE_PRIMARY) er_ui_sdl_activate_hit(app, event->button.x, event->button.y);
      break;
    default:
      break;
  }
}

static vr_font_face_t* er_ui_sdl_load_font(ErUiSdlApp* app) {
  vr_gl_iface_t gl = {0};
  gl.user = &app->textures;
  gl.create_texture = er_ui_sdl_create_font_texture;
  gl.update_texture = er_ui_sdl_update_font_texture;
  gl.destroy_texture = er_ui_sdl_destroy_font_texture;
  vr_font_config_t config = {0};
  config.px_size = ER_UI_SDL_FONT_SIZE;
  config.atlas_width = ER_UI_SDL_FONT_ATLAS_SIZE;
  config.atlas_height = ER_UI_SDL_FONT_ATLAS_SIZE;
  config.atlas_pad = ER_UI_SDL_FONT_PAD;
  config.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  config.allocator.user = NULL;
  config.allocator.alloc = er_ui_sdl_alloc;
  config.allocator.realloc = er_ui_sdl_realloc;
  config.allocator.free = er_ui_sdl_free;
  config.gl = gl;
  vr_font_face_t* font = NULL;
  size_t font_size = 0u;
  uint8_t* font_data = er_ui_sdl_read_file(ER_UI_REPO_ROOT "/varfont/fonts/Geist[wght].ttf", &font_size);
  vr_status_t status = vr_font_face_create_from_memory(&font, font_data, font_size, &config);
  free(font_data);
  if (status != VR_OK) {
    fprintf(stderr, "fatal: failed to load Geist font: %u\n", (unsigned)status);
    exit(1);
  }
  return font;
}

static void er_ui_sdl_init(ErUiSdlApp* app) {
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    fprintf(stderr, "fatal: SDL_Init failed: %s\n", SDL_GetError());
    exit(1);
  }
  app->window = SDL_CreateWindow("EdgeRun Codex", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, ER_UI_SDL_WINDOW_WIDTH, ER_UI_SDL_WINDOW_HEIGHT, ER_UI_SDL_WINDOW_FLAGS);
  if (!app->window) {
    fprintf(stderr, "fatal: SDL_CreateWindow failed: %s\n", SDL_GetError());
    exit(1);
  }
  app->renderer = SDL_CreateRenderer(app->window, ER_UI_SDL_RENDERER_AUTO, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!app->renderer) {
    fprintf(stderr, "fatal: SDL_CreateRenderer failed: %s\n", SDL_GetError());
    exit(1);
  }
  if (SDL_SetRenderDrawBlendMode(app->renderer, SDL_BLENDMODE_BLEND) != 0) {
    fprintf(stderr, "fatal: SDL_SetRenderDrawBlendMode failed: %s\n", SDL_GetError());
    exit(1);
  }
  app->textures.renderer = app->renderer;
  er_ui_sdl_refresh_size(app);
  static const uint8_t white_pixel[1] = {ER_UI_SDL_COLOR_FULL};
  app->icon_texture = er_ui_sdl_create_alpha_texture(app->renderer, ER_UI_SDL_ICON_ATLAS_WIDTH, ER_UI_SDL_ICON_ATLAS_HEIGHT, white_pixel);
  er_ui_allocator_t allocator = {NULL, er_ui_sdl_alloc, er_ui_sdl_free};
  if (er_ui_scene_init_with_allocator(&app->scene, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f), allocator) != ER_UI_OK) {
    fprintf(stderr, "fatal: scene init failed\n");
    exit(1);
  }
  if (er_ui_shell_state_init_with_allocator(&app->shell, allocator) != ER_UI_OK) {
    fprintf(stderr, "fatal: shell init failed\n");
    exit(1);
  }
  if (er_ui_workspace_add_named_surface(&app->shell, ER_UI_SDL_SURFACE_MAIN, "Codex") != ER_UI_OK ||
      er_ui_workspace_add_named_surface(&app->shell, ER_UI_SDL_SURFACE_LOG, "Run log") != ER_UI_OK ||
      er_ui_workspace_add_named_surface(&app->shell, ER_UI_SDL_SURFACE_DIFF, "Diff") != ER_UI_OK) {
    fprintf(stderr, "fatal: workspace init failed\n");
    exit(1);
  }
  app->font = er_ui_sdl_load_font(app);
  app->running = true;
}

static void er_ui_sdl_destroy(ErUiSdlApp* app) {
  if (app->font) vr_font_face_destroy(app->font);
  er_ui_shell_state_destroy(&app->shell);
  er_ui_scene_destroy(&app->scene);
  if (app->icon_texture) SDL_DestroyTexture(app->icon_texture);
  for (size_t i = 0u; i < app->textures.texture_capacity; ++i) {
    if (app->textures.textures[i]) SDL_DestroyTexture(app->textures.textures[i]);
  }
  free(app->textures.textures);
  if (app->renderer) SDL_DestroyRenderer(app->renderer);
  if (app->window) SDL_DestroyWindow(app->window);
  SDL_Quit();
}

int main(int argc, char** argv) {
  ErUiSdlApp app = {0};
  if (argc > 1 && strcmp(argv[1], ER_UI_SDL_SELF_TEST_ARG) == 0) app.self_test = true;
  er_ui_sdl_init(&app);
  while (app.running) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) er_ui_sdl_handle_event(&app, &event);
    er_ui_sdl_render(&app);
    SDL_Delay(ER_UI_SDL_FRAME_DELAY_MS);
  }
  er_ui_sdl_destroy(&app);
  return 0;
}

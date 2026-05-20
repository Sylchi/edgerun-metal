#include "er_ui_gop_renderer.h"
#include "er_ui_metal.h"
#include "er_ui_scene.h"
#include "er_ui_theme.h"
#include "vr_font.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ER_UI_SNAPSHOT_DEFAULT_WIDTH 1280u
#define ER_UI_SNAPSHOT_DEFAULT_HEIGHT 720u
#define ER_UI_SNAPSHOT_MAX_DIMENSION 8192u
#define ER_UI_SNAPSHOT_STRIDE_EXTRA 0u
#define ER_UI_SNAPSHOT_FONT_SIZE 18.0f
#define ER_UI_SNAPSHOT_FONT_ATLAS_SIZE 1024u
#define ER_UI_SNAPSHOT_FONT_PAD 2u
#define ER_UI_SNAPSHOT_BMP_CHANNELS 3u
#define ER_UI_SNAPSHOT_BMP_FILE_HEADER_BYTES 14u
#define ER_UI_SNAPSHOT_BMP_INFO_HEADER_BYTES 40u
#define ER_UI_SNAPSHOT_BMP_HEADER_BYTES \
  (ER_UI_SNAPSHOT_BMP_FILE_HEADER_BYTES + ER_UI_SNAPSHOT_BMP_INFO_HEADER_BYTES)
#define ER_UI_SNAPSHOT_BMP_ROW_ALIGN 4u
#define ER_UI_SNAPSHOT_BMP_BITS_PER_PIXEL 24u
#define ER_UI_SNAPSHOT_BMP_PLANES 1u
#define ER_UI_SNAPSHOT_BMP_COMPRESSION_RGB 0u
#define ER_UI_SNAPSHOT_BMP_RESOLUTION 2835u
#define ER_UI_SNAPSHOT_BMP_PALETTE_COLORS 0u
#define ER_UI_SNAPSHOT_BMP_IMPORTANT_COLORS 0u
#define ER_UI_SNAPSHOT_BMP_MAGIC_B 'B'
#define ER_UI_SNAPSHOT_BMP_MAGIC_M 'M'
#define ER_UI_SNAPSHOT_BMP_OFFSET_FILE_SIZE 2u
#define ER_UI_SNAPSHOT_BMP_OFFSET_PIXEL_DATA 10u
#define ER_UI_SNAPSHOT_BMP_OFFSET_INFO_SIZE 14u
#define ER_UI_SNAPSHOT_BMP_OFFSET_WIDTH 18u
#define ER_UI_SNAPSHOT_BMP_OFFSET_HEIGHT 22u
#define ER_UI_SNAPSHOT_BMP_OFFSET_PLANES 26u
#define ER_UI_SNAPSHOT_BMP_OFFSET_BITS_PER_PIXEL 28u
#define ER_UI_SNAPSHOT_BMP_OFFSET_COMPRESSION 30u
#define ER_UI_SNAPSHOT_BMP_OFFSET_IMAGE_BYTES 34u
#define ER_UI_SNAPSHOT_BMP_OFFSET_X_RESOLUTION 38u
#define ER_UI_SNAPSHOT_BMP_OFFSET_Y_RESOLUTION 42u
#define ER_UI_SNAPSHOT_BMP_OFFSET_PALETTE_COLORS 46u
#define ER_UI_SNAPSHOT_BMP_OFFSET_IMPORTANT_COLORS 50u
#define ER_UI_SNAPSHOT_BYTE0 0u
#define ER_UI_SNAPSHOT_BYTE1 1u
#define ER_UI_SNAPSHOT_BYTE2 2u
#define ER_UI_SNAPSHOT_BYTE3 3u
#define ER_UI_SNAPSHOT_PIXEL_RED_SHIFT 16u
#define ER_UI_SNAPSHOT_PIXEL_GREEN_SHIFT 8u
#define ER_UI_SNAPSHOT_PIXEL_MASK 0xffu
#define ER_UI_SNAPSHOT_SCENE_CLEAR_R 8u
#define ER_UI_SNAPSHOT_SCENE_CLEAR_G 10u
#define ER_UI_SNAPSHOT_SCENE_CLEAR_B 14u
#define ER_UI_SNAPSHOT_PARSE_BASE_DECIMAL 10
#define ER_UI_SNAPSHOT_ARG_WIDTH "--width"
#define ER_UI_SNAPSHOT_ARG_HEIGHT "--height"
#define ER_UI_SNAPSHOT_ARG_OUTPUT "--output"
#define ER_UI_SNAPSHOT_ARG_SELF_TEST "--self-test"
#define ER_UI_SNAPSHOT_DEFAULT_OUTPUT ER_UI_REPO_ROOT "/.build/edgerun-ui-core/snapshot.bmp"
#define ER_UI_SNAPSHOT_FONT_PATH ER_UI_REPO_ROOT "/edgerun-ui-core/varfont/fonts/Geist[wght].ttf"

typedef struct {
  uint32_t width;
  uint32_t height;
  const char* output_path;
  uint8_t self_test;
} ErUiSnapshotConfig;

static void* er_ui_snapshot_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* er_ui_snapshot_realloc(void* user,
                                    void* ptr,
                                    size_t old_size,
                                    size_t new_size,
                                    size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void er_ui_snapshot_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static er_ui_allocator_t er_ui_snapshot_scene_allocator(void) {
  er_ui_allocator_t allocator;

  allocator.user = 0;
  allocator.alloc = er_ui_snapshot_alloc;
  allocator.free = er_ui_snapshot_free;
  return allocator;
}

static vr_font_allocator_t er_ui_snapshot_font_allocator(void) {
  vr_font_allocator_t allocator;

  allocator.user = 0;
  allocator.alloc = er_ui_snapshot_alloc;
  allocator.realloc = er_ui_snapshot_realloc;
  allocator.free = er_ui_snapshot_free;
  return allocator;
}

static uint8_t er_ui_snapshot_streq(const char* left, const char* right) {
  if (left == 0 || right == 0) return 0u;
  return strcmp(left, right) == 0 ? 1u : 0u;
}

static uint8_t er_ui_snapshot_parse_u32(const char* text, uint32_t* out_value) {
  char* end = 0;
  unsigned long parsed;

  if (text == 0 || out_value == 0 || *text == 0) return 0u;
  errno = 0;
  parsed = strtoul(text, &end, ER_UI_SNAPSHOT_PARSE_BASE_DECIMAL);
  if (errno != 0 || end == text || *end != 0 ||
      parsed == 0u || parsed > ER_UI_SNAPSHOT_MAX_DIMENSION) {
    return 0u;
  }
  *out_value = (uint32_t)parsed;
  return 1u;
}

static uint8_t er_ui_snapshot_parse_args(int argc,
                                         char** argv,
                                         ErUiSnapshotConfig* out_config) {
  int i;

  if (out_config == 0) return 0u;
  *out_config = (ErUiSnapshotConfig){
    ER_UI_SNAPSHOT_DEFAULT_WIDTH,
    ER_UI_SNAPSHOT_DEFAULT_HEIGHT,
    ER_UI_SNAPSHOT_DEFAULT_OUTPUT,
    0u
  };
  for (i = 1; i < argc; ++i) {
    const char* arg = argv[i];

    if (er_ui_snapshot_streq(arg, ER_UI_SNAPSHOT_ARG_SELF_TEST) != 0u) {
      out_config->self_test = 1u;
      continue;
    }
    if (er_ui_snapshot_streq(arg, ER_UI_SNAPSHOT_ARG_WIDTH) != 0u) {
      if (i + 1 >= argc ||
          er_ui_snapshot_parse_u32(argv[++i], &out_config->width) == 0u) {
        return 0u;
      }
      continue;
    }
    if (er_ui_snapshot_streq(arg, ER_UI_SNAPSHOT_ARG_HEIGHT) != 0u) {
      if (i + 1 >= argc ||
          er_ui_snapshot_parse_u32(argv[++i], &out_config->height) == 0u) {
        return 0u;
      }
      continue;
    }
    if (er_ui_snapshot_streq(arg, ER_UI_SNAPSHOT_ARG_OUTPUT) != 0u) {
      if (i + 1 >= argc || argv[i + 1] == 0 || argv[i + 1][0] == 0) {
        return 0u;
      }
      out_config->output_path = argv[++i];
      continue;
    }
    return 0u;
  }
  return 1u;
}

static uint8_t* er_ui_snapshot_read_file(const char* path, size_t* out_size) {
  FILE* file;
  long signed_size;
  size_t size;
  uint8_t* data;

  if (path == 0 || out_size == 0) return 0;
  *out_size = 0u;
  file = fopen(path, "rb");
  if (file == 0) return 0;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return 0;
  }
  signed_size = ftell(file);
  if (signed_size <= 0) {
    fclose(file);
    return 0;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return 0;
  }
  size = (size_t)signed_size;
  data = (uint8_t*)malloc(size);
  if (data == 0) {
    fclose(file);
    return 0;
  }
  if (fread(data, 1u, size, file) != size) {
    free(data);
    fclose(file);
    return 0;
  }
  fclose(file);
  *out_size = size;
  return data;
}

static vr_font_face_t* er_ui_snapshot_load_font(void) {
  size_t font_size = 0u;
  uint8_t* font_data;
  vr_font_config_t config;
  vr_font_face_t* font = 0;

  font_data = er_ui_snapshot_read_file(ER_UI_SNAPSHOT_FONT_PATH, &font_size);
  if (font_data == 0) return 0;
  config = (vr_font_config_t){0};
  config.px_size = ER_UI_SNAPSHOT_FONT_SIZE;
  config.atlas_width = ER_UI_SNAPSHOT_FONT_ATLAS_SIZE;
  config.atlas_height = ER_UI_SNAPSHOT_FONT_ATLAS_SIZE;
  config.atlas_pad = ER_UI_SNAPSHOT_FONT_PAD;
  config.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  config.allocator = er_ui_snapshot_font_allocator();
  if (vr_font_face_create_from_memory(&font, font_data, font_size, &config) != VR_OK) {
    free(font_data);
    return 0;
  }
  free(font_data);
  return font;
}

static void er_ui_snapshot_put_u16le(uint8_t* bytes, size_t offset, uint16_t value) {
  bytes[offset + ER_UI_SNAPSHOT_BYTE0] =
      (uint8_t)(value & ER_UI_SNAPSHOT_PIXEL_MASK);
  bytes[offset + ER_UI_SNAPSHOT_BYTE1] =
      (uint8_t)((value >> ER_UI_SNAPSHOT_PIXEL_GREEN_SHIFT) &
                ER_UI_SNAPSHOT_PIXEL_MASK);
}

static void er_ui_snapshot_put_u32le(uint8_t* bytes, size_t offset, uint32_t value) {
  bytes[offset + ER_UI_SNAPSHOT_BYTE0] =
      (uint8_t)(value & ER_UI_SNAPSHOT_PIXEL_MASK);
  bytes[offset + ER_UI_SNAPSHOT_BYTE1] =
      (uint8_t)((value >> ER_UI_SNAPSHOT_PIXEL_GREEN_SHIFT) &
                ER_UI_SNAPSHOT_PIXEL_MASK);
  bytes[offset + ER_UI_SNAPSHOT_BYTE2] =
      (uint8_t)((value >> ER_UI_SNAPSHOT_PIXEL_RED_SHIFT) &
                ER_UI_SNAPSHOT_PIXEL_MASK);
  bytes[offset + ER_UI_SNAPSHOT_BYTE3] =
      (uint8_t)((value >> (ER_UI_SNAPSHOT_PIXEL_GREEN_SHIFT +
                           ER_UI_SNAPSHOT_PIXEL_RED_SHIFT)) &
                ER_UI_SNAPSHOT_PIXEL_MASK);
}

static uint8_t er_ui_snapshot_write_bmp(const char* path,
                                        const uint32_t* pixels,
                                        uint32_t width,
                                        uint32_t height,
                                        uint32_t stride) {
  FILE* file;
  uint8_t header[ER_UI_SNAPSHOT_BMP_HEADER_BYTES] = {0};
  uint8_t* row;
  uint32_t row_bytes;
  uint32_t padded_row_bytes;
  uint32_t image_bytes;
  uint32_t file_bytes;
  uint32_t y;
  uint32_t x;

  if (path == 0 || pixels == 0 || width == 0u || height == 0u || stride < width) {
    return 0u;
  }
  row_bytes = width * ER_UI_SNAPSHOT_BMP_CHANNELS;
  padded_row_bytes = (row_bytes + ER_UI_SNAPSHOT_BMP_ROW_ALIGN - 1u) &
                     ~(ER_UI_SNAPSHOT_BMP_ROW_ALIGN - 1u);
  if (height > (UINT32_MAX / padded_row_bytes) ||
      (UINT32_MAX - ER_UI_SNAPSHOT_BMP_HEADER_BYTES) <
          padded_row_bytes * height) {
    return 0u;
  }
  image_bytes = padded_row_bytes * height;
  file_bytes = ER_UI_SNAPSHOT_BMP_HEADER_BYTES + image_bytes;
  row = (uint8_t*)calloc(padded_row_bytes, 1u);
  if (row == 0) return 0u;
  header[0] = ER_UI_SNAPSHOT_BMP_MAGIC_B;
  header[1] = ER_UI_SNAPSHOT_BMP_MAGIC_M;
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_FILE_SIZE, file_bytes);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_PIXEL_DATA,
                           ER_UI_SNAPSHOT_BMP_HEADER_BYTES);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_INFO_SIZE,
                           ER_UI_SNAPSHOT_BMP_INFO_HEADER_BYTES);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_WIDTH, width);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_HEIGHT, height);
  er_ui_snapshot_put_u16le(header, ER_UI_SNAPSHOT_BMP_OFFSET_PLANES,
                           ER_UI_SNAPSHOT_BMP_PLANES);
  er_ui_snapshot_put_u16le(header, ER_UI_SNAPSHOT_BMP_OFFSET_BITS_PER_PIXEL,
                           ER_UI_SNAPSHOT_BMP_BITS_PER_PIXEL);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_COMPRESSION,
                           ER_UI_SNAPSHOT_BMP_COMPRESSION_RGB);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_IMAGE_BYTES, image_bytes);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_X_RESOLUTION,
                           ER_UI_SNAPSHOT_BMP_RESOLUTION);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_Y_RESOLUTION,
                           ER_UI_SNAPSHOT_BMP_RESOLUTION);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_PALETTE_COLORS,
                           ER_UI_SNAPSHOT_BMP_PALETTE_COLORS);
  er_ui_snapshot_put_u32le(header, ER_UI_SNAPSHOT_BMP_OFFSET_IMPORTANT_COLORS,
                           ER_UI_SNAPSHOT_BMP_IMPORTANT_COLORS);
  file = fopen(path, "wb");
  if (file == 0) {
    free(row);
    return 0u;
  }
  if (fwrite(header, 1u, sizeof(header), file) != sizeof(header)) {
    free(row);
    fclose(file);
    return 0u;
  }
  for (y = 0u; y < height; ++y) {
    const uint32_t* source_row = pixels + ((size_t)(height - 1u - y) * (size_t)stride);

    for (x = 0u; x < width; ++x) {
      uint32_t pixel = source_row[x];
      size_t offset = (size_t)x * ER_UI_SNAPSHOT_BMP_CHANNELS;

      row[offset] = (uint8_t)(pixel & ER_UI_SNAPSHOT_PIXEL_MASK);
      row[offset + 1u] = (uint8_t)((pixel >> ER_UI_SNAPSHOT_PIXEL_GREEN_SHIFT) &
                                   ER_UI_SNAPSHOT_PIXEL_MASK);
      row[offset + 2u] = (uint8_t)((pixel >> ER_UI_SNAPSHOT_PIXEL_RED_SHIFT) &
                                   ER_UI_SNAPSHOT_PIXEL_MASK);
    }
    if (fwrite(row, 1u, padded_row_bytes, file) != padded_row_bytes) {
      free(row);
      fclose(file);
      return 0u;
    }
  }
  free(row);
  return fclose(file) == 0 ? 1u : 0u;
}

int main(int argc, char** argv) {
  ErUiSnapshotConfig config;
  er_ui_scene_t scene;
  er_ui_component_gallery_state_t gallery;
  er_ui_resolved_theme_t theme;
  vr_font_face_t* font;
  uint32_t* pixels;
  ErUiGopSurface surface;
  ErUiGopRenderStats stats;
  size_t pixel_count;
  uint8_t ok;

  if (er_ui_snapshot_parse_args(argc, argv, &config) == 0u) {
    fprintf(stderr,
            "usage: %s [--width N] [--height N] [--output PATH] [--self-test]\n",
            argv[0]);
    return 2;
  }
  if ((size_t)config.width > SIZE_MAX / (size_t)config.height ||
      (size_t)config.width * (size_t)config.height >
          SIZE_MAX / sizeof(*pixels)) {
    fprintf(stderr, "fatal: snapshot dimensions overflow\n");
    return 1;
  }
  pixel_count = (size_t)config.width * (size_t)config.height;
  pixels = (uint32_t*)calloc(pixel_count, sizeof(*pixels));
  if (pixels == 0) {
    fprintf(stderr, "fatal: out of memory for snapshot framebuffer\n");
    return 1;
  }
  font = er_ui_snapshot_load_font();
  if (font == 0) {
    free(pixels);
    fprintf(stderr, "fatal: failed to load bundled Geist font\n");
    return 1;
  }
  if (er_ui_scene_init_with_allocator(
          &scene,
          er_ui_color_rgb_u8(ER_UI_SNAPSHOT_SCENE_CLEAR_R,
                             ER_UI_SNAPSHOT_SCENE_CLEAR_G,
                             ER_UI_SNAPSHOT_SCENE_CLEAR_B),
          er_ui_snapshot_scene_allocator()) != ER_UI_OK) {
    vr_font_face_destroy(font);
    free(pixels);
    fprintf(stderr, "fatal: failed to initialize UI scene\n");
    return 1;
  }

  er_ui_component_gallery_state_init(&gallery);
  theme = er_ui_resolved_theme_user_default();
  if (er_ui_edgerun_metal_surface_emit(
          &scene,
          font,
          er_ui_bounds(0.0f, 0.0f, (float)config.width, (float)config.height),
          theme,
          &gallery) != ER_UI_OK) {
    er_ui_scene_destroy(&scene);
    vr_font_face_destroy(font);
    free(pixels);
    fprintf(stderr, "fatal: failed to emit EdgeRun UI scene\n");
    return 1;
  }

  surface = (ErUiGopSurface){
    pixels,
    config.width,
    config.height,
    config.width + ER_UI_SNAPSHOT_STRIDE_EXTRA,
    ER_UI_GOP_PIXEL_RGBX
  };
  if (er_ui_gop_surface_render_scene_with_font_stats(
          &surface, &scene, font, &stats) == 0u) {
    er_ui_scene_destroy(&scene);
    vr_font_face_destroy(font);
    free(pixels);
    fprintf(stderr, "fatal: failed to rasterize EdgeRun UI scene\n");
    return 1;
  }
  ok = config.self_test != 0u ? 1u :
       er_ui_snapshot_write_bmp(config.output_path,
                                pixels,
                                config.width,
                                config.height,
                                surface.stride);
  if (ok == 0u) {
    er_ui_scene_destroy(&scene);
    vr_font_face_destroy(font);
    free(pixels);
    fprintf(stderr, "fatal: failed to write %s\n", config.output_path);
    return 1;
  }
  if (config.self_test == 0u) {
    printf("wrote %s %ux%u rects=%llu icons=%llu text=%llu pixels=%llu\n",
           config.output_path,
           config.width,
           config.height,
           (unsigned long long)stats.rects,
           (unsigned long long)stats.icon_quads,
           (unsigned long long)stats.text_quads,
           (unsigned long long)stats.pixels_written);
  }
  er_ui_scene_destroy(&scene);
  vr_font_face_destroy(font);
  free(pixels);
  return 0;
}

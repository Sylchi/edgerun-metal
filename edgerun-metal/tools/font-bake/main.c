#include "vr_font.h"

/*
 * Purpose: bake the bundled Geist TTF into a build-local coverage atlas header.
 * Intention: let the metal UI draw real glyphs without expensive rasterization during boot.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
  uint32_t codepoint;
  vr_baked_glyph_t baked;
} BakedGlyph;

static void* host_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return size == 0u ? NULL : malloc(size);
}

static void* host_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void host_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static uint8_t* read_file(const char* path, size_t* out_size) {
  FILE* f = fopen(path, "rb");
  uint8_t* data;
  long size;

  if (!f || !out_size) {
    if (f) fclose(f);
    return NULL;
  }
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return NULL;
  }
  size = ftell(f);
  if (size <= 0) {
    fclose(f);
    return NULL;
  }
  if (fseek(f, 0, SEEK_SET) != 0) {
    fclose(f);
    return NULL;
  }
  data = (uint8_t*)malloc((size_t)size);
  if (!data) {
    fclose(f);
    return NULL;
  }
  if (fread(data, 1u, (size_t)size, f) != (size_t)size) {
    free(data);
    fclose(f);
    return NULL;
  }
  fclose(f);
  *out_size = (size_t)size;
  return data;
}

static int write_u8_array(FILE* out, const char* name, const uint8_t* bytes, size_t count) {
  size_t i;

  if (fprintf(out, "static const UINT8 %s[] = {\n", name) < 0) return 0;
  for (i = 0u; i < count; ++i) {
    if ((i % 16u) == 0u && fprintf(out, "  ") < 0) return 0;
    if (fprintf(out, "0x%02x,", bytes[i]) < 0) return 0;
    if ((i % 16u) == 15u || i + 1u == count) {
      if (fprintf(out, "\n") < 0) return 0;
    } else if (fprintf(out, " ") < 0) {
      return 0;
    }
  }
  return fprintf(out, "};\n\n") >= 0;
}

static int write_float(FILE* out, float value) {
  if (value == (float)(int)value) {
    return fprintf(out, "%d.0f", (int)value) >= 0;
  }
  return fprintf(out, "%.9gf", value) >= 0;
}

int main(int argc, char** argv) {
  if (argc != 3) {
    fprintf(stderr, "usage: %s <font.ttf> <output.h>\n", argv[0]);
    return 2;
  }

  size_t font_size = 0u;
  uint8_t* font_data = read_file(argv[1], &font_size);
  if (!font_data) {
    fprintf(stderr, "font-bake: failed to read %s\n", argv[1]);
    return 1;
  }

  vr_font_config_t cfg = {0};
  cfg.px_size = 72.0f;
  cfg.atlas_width = 1024u;
  cfg.atlas_height = 1024u;
  cfg.atlas_pad = 2u;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator.user = NULL;
  cfg.allocator.alloc = host_alloc;
  cfg.allocator.realloc = host_realloc;
  cfg.allocator.free = host_free;

  vr_font_face_t* face = NULL;
  if (vr_font_face_create_from_memory(&face, font_data, font_size, &cfg) != VR_OK || !face) {
    fprintf(stderr, "font-bake: failed to create font face\n");
    free(font_data);
    return 1;
  }

  BakedGlyph glyphs[95];
  size_t glyph_count = 0u;
  for (uint32_t cp = 32u; cp <= 126u; ++cp) {
    vr_shaped_glyph_t* shaped = NULL;
    size_t shaped_count = 0u;
    if (vr_font_shape_text(face, &cp, 1u, &shaped, &shaped_count) != VR_OK || shaped_count == 0u) {
      continue;
    }
    vr_baked_glyph_t baked = {0};
    if (vr_font_bake_glyph(face, shaped[0].glyph, &baked) == VR_OK) {
      glyphs[glyph_count].codepoint = cp;
      glyphs[glyph_count].baked = baked;
      ++glyph_count;
    }
    (void)vr_font_free_shaped(face, shaped, shaped_count);
  }

  vr_font_atlas_view_t atlas = {0};
  if (vr_font_atlas_view(face, 0u, &atlas) != VR_OK || !atlas.pixels || atlas.bytes_per_pixel != 1u) {
    fprintf(stderr, "font-bake: failed to read alpha atlas\n");
    vr_font_face_destroy(face);
    free(font_data);
    return 1;
  }

  FILE* out = fopen(argv[2], "wb");
  if (!out) {
    fprintf(stderr, "font-bake: failed to open %s\n", argv[2]);
    vr_font_face_destroy(face);
    free(font_data);
    return 1;
  }

  fprintf(out, "#ifndef ER_FONT_GEIST_BAKED_H\n");
  fprintf(out, "#define ER_FONT_GEIST_BAKED_H\n\n");
  fprintf(out, "#include \"er_types.h\"\n\n");
  fprintf(out, "typedef struct {\n");
  fprintf(out, "  UINT32 codepoint;\n");
  fprintf(out, "  INT32 width;\n");
  fprintf(out, "  INT32 height;\n");
  fprintf(out, "  INT32 left;\n");
  fprintf(out, "  INT32 top;\n");
  fprintf(out, "  float advance;\n");
  fprintf(out, "  float u0;\n");
  fprintf(out, "  float v0;\n");
  fprintf(out, "  float u1;\n");
  fprintf(out, "  float v1;\n");
  fprintf(out, "} ErBakedFontGlyph;\n\n");
  fprintf(out, "#define ER_FONT_GEIST_BAKED_ATLAS_WIDTH %uu\n", atlas.width);
  fprintf(out, "#define ER_FONT_GEIST_BAKED_ATLAS_HEIGHT %uu\n", atlas.height);
  fprintf(out, "#define ER_FONT_GEIST_BAKED_ATLAS_BYTES_PER_PIXEL %zuu\n\n", atlas.bytes_per_pixel);
  if (!write_u8_array(out, "g_er_font_geist_baked_atlas", atlas.pixels,
                      (size_t)atlas.width * (size_t)atlas.height * atlas.bytes_per_pixel)) {
    fclose(out);
    vr_font_face_destroy(face);
    free(font_data);
    return 1;
  }
  fprintf(out, "static const ErBakedFontGlyph g_er_font_geist_baked_glyphs[] = {\n");
  for (size_t i = 0u; i < glyph_count; ++i) {
    const vr_baked_glyph_t* g = &glyphs[i].baked;
    fprintf(out, "  {%uu, %d, %d, %d, %d, ", glyphs[i].codepoint, g->width, g->height, g->left, g->top);
    if (!write_float(out, g->advance) || fprintf(out, ", ") < 0 ||
        !write_float(out, g->atlas_u0) || fprintf(out, ", ") < 0 ||
        !write_float(out, g->atlas_v0) || fprintf(out, ", ") < 0 ||
        !write_float(out, g->atlas_u1) || fprintf(out, ", ") < 0 ||
        !write_float(out, g->atlas_v1) || fprintf(out, "},\n") < 0) {
      fclose(out);
      vr_font_face_destroy(face);
      free(font_data);
      return 1;
    }
  }
  fprintf(out, "};\n\n");
  fprintf(out, "#define ER_FONT_GEIST_BAKED_GLYPH_COUNT ((UINTN)(sizeof(g_er_font_geist_baked_glyphs) / sizeof(g_er_font_geist_baked_glyphs[0])))\n\n");
  fprintf(out, "#endif\n");
  fclose(out);

  vr_font_face_destroy(face);
  free(font_data);
  return 0;
}

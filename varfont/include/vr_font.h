#ifndef VR_FONT_H
#define VR_FONT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VR_MAX_AXES 16
#define VR_MAX_NAME 64

typedef enum {
  VR_OK = 0,
  VR_ERR_OOM,
  VR_ERR_IO,
  VR_ERR_INVALID_FONT,
  VR_ERR_UNSUPPORTED,
  VR_ERR_NOT_FOUND,
  VR_ERR_NO_SPACE
} vr_status_t;

typedef enum {
  VR_AXIS_NAME_LEN = 4
} vr_axis_name_t;

#define VR_FONT_DEFAULT_PX_SIZE 64.0f
#define VR_FONT_DEFAULT_ATLAS_DIMENSION 1024u
#define VR_FONT_DEFAULT_ATLAS_PADDING 2u
#define VR_FONT_PARSER_DEFAULT_PX_SIZE 32.0f
#define VR_FONT_VERTICES_PER_GLYPH 6u

typedef enum {
  VR_FONT_ATLAS_FORMAT_UNSPECIFIED = 0,
  VR_FONT_ATLAS_FORMAT_ALPHA8 = 1,
  VR_FONT_ATLAS_FORMAT_MSDF_RGB = 2
} vr_font_atlas_format_t;

#define VR_FONT_DEFAULT_ATLAS_FORMAT VR_FONT_ATLAS_FORMAT_MSDF_RGB

typedef struct {
  char name[VR_AXIS_NAME_LEN + 1];
  float min_value;
  float default_value;
  float max_value;
  float value;
} vr_font_axis_t;

typedef struct {
  uint32_t glyph;
  uint32_t codepoint;
  float x_advance;
  float x_offset;
  float y_offset;
  uint32_t cluster;
} vr_shaped_glyph_t;

typedef struct {
  float x;
  float y;
  float u;
  float v;
  float r;
  float g;
  float b;
  float a;
  uint32_t atlas_id;
} vr_vertex_t;

typedef struct {
  uint32_t atlas_id;
  size_t start_vertex;
  size_t vertex_count;
} vr_vertex_atlas_range_t;

typedef struct {
  uint32_t glyph;
  int width;
  int height;
  int left;
  int top;
  float advance;
  float atlas_u0;
  float atlas_v0;
  float atlas_u1;
  float atlas_v1;
  uint32_t atlas_id;
} vr_baked_glyph_t;

typedef struct {
  uint16_t units_per_em;
  float px_size;
  float ascender;
  float descender;
  float line_gap;
  float line_height;
  float y_min;
  float y_max;
} vr_font_metrics_t;

typedef struct {
  void* user;
  void (*create_texture)(void* user, uint32_t* out_texture, int width, int height, const void* pixels);
  void (*update_texture)(void* user, uint32_t texture, int x, int y, int width, int height, const void* pixels);
  void (*destroy_texture)(void* user, uint32_t texture);
} vr_gl_iface_t;

typedef void* (*vr_font_alloc_fn)(void* user, size_t size, size_t align);
typedef void* (*vr_font_realloc_fn)(void* user, void* ptr, size_t old_size, size_t new_size, size_t align);
typedef void (*vr_font_free_fn)(void* user, void* ptr, size_t size, size_t align);

typedef struct {
  void* user;
  vr_font_alloc_fn alloc;
  vr_font_realloc_fn realloc;
  vr_font_free_fn free;
} vr_font_allocator_t;

typedef struct {
  float px_size;
  uint32_t atlas_width;
  uint32_t atlas_height;
  uint32_t atlas_pad;
  vr_font_atlas_format_t atlas_format;
  vr_font_allocator_t allocator;
  vr_gl_iface_t gl;
} vr_font_config_t;

typedef struct vr_font_face_t vr_font_face_t;

vr_status_t vr_font_face_create_from_memory(vr_font_face_t** out, const void* data, size_t size, const vr_font_config_t* cfg);
vr_status_t vr_font_face_create(vr_font_face_t** out, const char* path, const vr_font_config_t* cfg);
void vr_font_face_destroy(vr_font_face_t* face);

vr_status_t vr_font_set_size(vr_font_face_t* face, float px_size);
vr_status_t vr_font_set_axis(vr_font_face_t* face, const char* tag, float user_value);
int vr_font_axis_count(const vr_font_face_t* face);
const vr_font_axis_t* vr_font_axes(const vr_font_face_t* face);
vr_status_t vr_font_metrics(const vr_font_face_t* face, vr_font_metrics_t* out_metrics);

vr_status_t vr_font_shape_text(
  vr_font_face_t* face,
  const uint32_t* codepoints,
  size_t codepoint_count,
  vr_shaped_glyph_t** out_glyphs,
  size_t* out_count);

vr_status_t vr_font_free_shaped(vr_font_face_t* face, vr_shaped_glyph_t* glyphs, size_t glyph_count);

vr_status_t vr_font_bake_glyph(vr_font_face_t* face, uint32_t glyph_id, vr_baked_glyph_t* out);

vr_status_t vr_font_clear_cache(vr_font_face_t* face);

vr_status_t vr_font_build_vertex_batch(
  vr_font_face_t* face,
  const vr_shaped_glyph_t* shaped,
  size_t shaped_count,
  float x,
  float y,
  vr_vertex_t** out_vertices,
  size_t* out_vertex_count);

vr_status_t vr_font_build_vertex_batches_by_atlas(
  vr_font_face_t* face,
  const vr_shaped_glyph_t* shaped,
  size_t shaped_count,
  float x,
  float y,
  vr_vertex_t** out_vertices,
  size_t* out_vertex_count,
  vr_vertex_atlas_range_t** out_ranges,
  size_t* out_range_count);

vr_status_t vr_font_free_vertices(vr_font_face_t* face, vr_vertex_t* verts, size_t vertex_count);
vr_status_t vr_font_free_vertex_atlas_ranges(vr_font_face_t* face, vr_vertex_atlas_range_t* ranges, size_t range_count);

uint32_t vr_font_last_error(const vr_font_face_t* face);

size_t vr_font_atlas_count(const vr_font_face_t* face);
vr_status_t vr_font_atlas_texture(const vr_font_face_t* face, uint32_t atlas_id, uint32_t* out_texture);

#ifdef __cplusplus
}
#endif

#endif

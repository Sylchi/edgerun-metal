#ifndef VR_FONT_INTERNAL_H
#define VR_FONT_INTERNAL_H

#include "vr_font.h"

#include <stdbool.h>

#define VR_FONT_BYTE_SHIFT_1 8u
#define VR_FONT_BYTE_SHIFT_2 16u
#define VR_FONT_BYTE_SHIFT_3 24u
#define VR_FONT_BYTE_INDEX_0 0u
#define VR_FONT_BYTE_INDEX_1 1u
#define VR_FONT_BYTE_INDEX_2 2u
#define VR_FONT_BYTE_INDEX_3 3u
#define VR_TABLE_TAG(a,b,c,d) \
  (((uint32_t)(a) << VR_FONT_BYTE_SHIFT_3) | ((uint32_t)(b) << VR_FONT_BYTE_SHIFT_2) | \
   ((uint32_t)(c) << VR_FONT_BYTE_SHIFT_1) | ((uint32_t)(d)))
#define VR_FONT_ALIGN_U8 1u
#define VR_FONT_ALIGN_U16 2u
#define VR_FONT_ALIGN_U32 4u
#define VR_FONT_ALIGN_PTR 8u
#define VR_FONT_AXIS_TAG_STORAGE_LEN (VR_AXIS_NAME_LEN + 1u)
#define VR_FONT_PHANTOM_POINT_COUNT 4u
#define VR_FONT_CMAP_FORMAT_4 4u
#define VR_FONT_CMAP_FORMAT_12 12u
#define VR_FONT_HASH_MIX_LEFT_SHIFT 6u
#define VR_FONT_HASH_MIX_RIGHT_SHIFT 2u

typedef struct {
  uint32_t tag;
  uint32_t checksum;
  uint32_t offset;
  uint32_t length;
} vr_table_record_t;

typedef struct {
  uint16_t platform_id;
  uint16_t encoding_id;
  uint32_t offset;
} vr_cmap_subtable_t;

typedef struct {
  uint32_t format;
  uint16_t length;
  uint16_t language;
  union {
    struct {
      uint16_t seg_count_x2;
      uint16_t search_range;
      uint16_t entry_selector;
      uint16_t range_shift;
      uint16_t* end_code;
      uint16_t* start_code;
      int16_t* id_delta;
      uint16_t* id_range_offset;
      uint16_t* glyph_id_array;
      size_t glyph_id_array_count;
    } format4;
    struct {
      uint16_t n_groups;
      uint32_t* start_char_code;
      uint32_t* end_char_code;
      uint32_t* start_glyph_id;
    } format12;
  } u;
} vr_cmap_table_t;

typedef struct {
  uint16_t axis_count;
  struct {
    char tag[VR_FONT_AXIS_TAG_STORAGE_LEN];
    float min;
    float default_value;
    float max;
  } descriptors[VR_MAX_AXES];
  int default_instance_index;
  uint32_t axis_value_record_count;
} vr_fvar_table_t;

typedef struct {
  uint16_t glyph_id;
  float x_min;
  float y_min;
  float x_max;
  float y_max;
} vr_hmtx_metric_t;

typedef struct {
  uint16_t left;
  uint16_t right;
  float adjust;
} vr_kern_pair_t;

typedef struct {
  vr_kern_pair_t* pairs;
  size_t count;
  size_t cap;
} vr_kern_table_t;

typedef struct {
  uint16_t glyph_count;
  uint16_t flags;
  uint16_t axis_count;
  uint16_t shared_tuple_count;
  uint32_t shared_tuples_offset;
  uint32_t glyph_data_array_offset;
  uint16_t offset_format; /* 0=Offset16, 1=Offset32 */
  uint32_t* glyph_variation_offsets;
  float* shared_tuples;
} vr_gvar_table_t;

typedef struct {
  uint16_t axis_count;
  uint16_t* segment_count;
  size_t* segment_offset;
  size_t total_segment_count;
  float* map_from;
  float* map_to;
} vr_avar_table_t;

typedef struct {
  uint16_t number_of_contours;
  int32_t x_min;
  int32_t y_min;
  int32_t x_max;
  int32_t y_max;
  int contour_count;
  int point_count;
  uint16_t* contour_end_pts;
  int16_t* x;
  int16_t* y;
  bool* on_curve;
  size_t point_count_alloc;
  bool has_phantom_points;
  int32_t phantom_x[VR_FONT_PHANTOM_POINT_COUNT];
  int32_t phantom_y[VR_FONT_PHANTOM_POINT_COUNT];
} vr_glyph_outline_t;

typedef struct {
  int x1, y1, x2, y2;
} vr_i32_segment_t;

typedef struct {
  float x, y;
  uint8_t on_curve;
} vr_outline_point_t;

typedef struct {
  float x1, y1, x2, y2;
} vr_segment_t;

typedef struct {
  uint16_t glyph_id;
  uint32_t atlas_id;
  int width;
  int height;
  int left;
  int top;
  float advance;
  float u0;
  float v0;
  float u1;
  float v1;
  uint8_t* bitmap;
  uint32_t cache_key_axis_mask;
} vr_glyph_cache_entry_t;

typedef struct {
  int x;
  int y;
  int h;
  int row_h;
  int width;
  int height;
  uint8_t* pixels;
  size_t bytes_per_pixel;
  uint32_t texture_id;
  uint32_t id;
} vr_atlas_page_t;

struct vr_font_face_t {
  vr_font_allocator_t allocator;
  vr_table_record_t* tables;
  size_t table_count;
  uint8_t* file_data;
  size_t file_size;

  uint16_t units_per_em;
  int16_t index_to_loc_format;
  uint16_t num_glyphs;
  int16_t ascender;
  int16_t descender;
  int16_t line_gap;
  int16_t yMin;
  int16_t yMax;
  uint16_t num_h_metrics;
  uint32_t* loca_offsets;
  uint32_t maxp_num_glyphs;

  uint32_t* cmap_offsets;
  size_t cmap_offset_count;
  vr_cmap_table_t cmap;

  vr_kern_table_t kern;
  vr_gvar_table_t gvar;
  vr_avar_table_t avar;

  vr_fvar_table_t fvar;
  float axis_values[VR_MAX_AXES];

  uint8_t* head;
  uint8_t* glyf;
  uint8_t* hhea;
  uint8_t* hmtx;
  uint8_t* maxp;

  vr_font_config_t cfg;

  uint32_t last_error;

  vr_font_axis_t axes[VR_MAX_AXES];

  vr_atlas_page_t* atlases;
  size_t atlas_count;
  size_t atlas_cap;

  vr_glyph_cache_entry_t* glyph_cache;
  size_t glyph_cache_count;
  size_t glyph_cache_cap;

  uint32_t next_glyph_cache_id;
};

static inline uint16_t vr_u16(const uint8_t* p) {
  return (uint16_t)(((uint16_t)p[VR_FONT_BYTE_INDEX_0] << VR_FONT_BYTE_SHIFT_1) |
                    (uint16_t)p[VR_FONT_BYTE_INDEX_1]);
}

static inline int16_t vr_i16(const uint8_t* p) {
  return (int16_t)vr_u16(p);
}

static inline uint32_t vr_u32(const uint8_t* p) {
  return ((uint32_t)p[VR_FONT_BYTE_INDEX_0] << VR_FONT_BYTE_SHIFT_3) |
         ((uint32_t)p[VR_FONT_BYTE_INDEX_1] << VR_FONT_BYTE_SHIFT_2) |
         ((uint32_t)p[VR_FONT_BYTE_INDEX_2] << VR_FONT_BYTE_SHIFT_1) |
         (uint32_t)p[VR_FONT_BYTE_INDEX_3];
}

static inline uint32_t vr_tag(const uint8_t* p) {
  return ((uint32_t)p[VR_FONT_BYTE_INDEX_0] << VR_FONT_BYTE_SHIFT_3) |
         ((uint32_t)p[VR_FONT_BYTE_INDEX_1] << VR_FONT_BYTE_SHIFT_2) |
         ((uint32_t)p[VR_FONT_BYTE_INDEX_2] << VR_FONT_BYTE_SHIFT_1) |
         (uint32_t)p[VR_FONT_BYTE_INDEX_3];
}

bool vr_allocator_valid(vr_font_allocator_t allocator);
void* vr_alloc(const vr_font_face_t* face, size_t size, size_t align);
void* vr_calloc(const vr_font_face_t* face, size_t count, size_t size, size_t align);
void* vr_realloc(const vr_font_face_t* face, void* ptr, size_t old_size, size_t new_size, size_t align);
void vr_dealloc(const vr_font_face_t* face, void* ptr, size_t size, size_t align);
void vr_zero(void* ptr, size_t size);
void vr_copy(void* dst, const void* src, size_t size);
void vr_move(void* dst, const void* src, size_t size);
int vr_mem_compare(const void* left, const void* right, size_t size);
int vr_tag_compare(const char* left, const char* right);
float vr_absf(float value);
float vr_clampf(float value, float min_value, float max_value);
float vr_floorf(float value);
float vr_ceilf(float value);
float vr_sqrtf(float value);
uint8_t vr_u8_from_unitf(float value);
long vr_lrintf(float value);
float vr_atan2f(float y, float x);
bool vr_float_is_finite(float value);
vr_status_t vr_parse_font(vr_font_face_t* face);
vr_status_t vr_parse_cmap(vr_font_face_t* face);
vr_status_t vr_parse_kern(vr_font_face_t* face);
vr_status_t vr_parse_avar(vr_font_face_t* face);
vr_status_t vr_parse_gvar(vr_font_face_t* face);
uint16_t vr_find_glyph_id(vr_font_face_t* face, uint32_t codepoint);
float vr_map_axis_value(const vr_font_face_t* face, const char* tag, float user_value, float* out_norm);
float vr_apply_avar_mapping(const vr_font_face_t* face, uint16_t axis_index, float value);
float vr_find_kern_adjust(const vr_font_face_t* face, uint16_t left, uint16_t right);
vr_status_t vr_apply_gvar_variation(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* outline);

vr_status_t vr_load_glyph_outline(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* out);
uint16_t vr_get_glyph_h_advance_units(const vr_font_face_t* face, uint16_t glyph_id);
int16_t vr_get_glyph_h_lsb_units(const vr_font_face_t* face, uint16_t glyph_id);
void vr_free_outline(const vr_font_face_t* face, vr_glyph_outline_t* outline);
vr_status_t vr_rasterize_outline(const vr_font_face_t* face, const vr_glyph_outline_t* outline,
                                 uint8_t** out_bitmap, int* out_w, int* out_h, int* out_left, int* out_top);
vr_status_t vr_rasterize_outline_with_mode(const vr_font_face_t* face,
                                 const vr_glyph_outline_t* outline,
                                 vr_font_atlas_format_t atlas_format,
                                 uint8_t** out_bitmap,
                                 int* out_w,
                                 int* out_h,
                                 int* out_left,
                                 int* out_top);
vr_status_t vr_free_bitmap(const vr_font_face_t* face, uint8_t* bitmap, int width, int height, vr_font_atlas_format_t atlas_format);
float vr_get_glyph_advance(const vr_font_face_t* face, uint16_t glyph_id);
vr_status_t vr_ensure_atlas(vr_font_face_t* face, int required_w, int required_h, uint32_t* out_atlas_id, int* out_x, int* out_y);
vr_status_t vr_upload_bitmap_to_atlas(vr_font_face_t* face, uint32_t atlas_id, int x, int y, int w, int h, const uint8_t* bitmap);
vr_status_t vr_cache_lookup(vr_font_face_t* face, uint16_t glyph_id, vr_baked_glyph_t* out);
void vr_cache_remove(vr_font_face_t* face);

#endif

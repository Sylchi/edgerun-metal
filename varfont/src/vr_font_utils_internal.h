#ifndef VR_FONT_UTILS_INTERNAL_H
#define VR_FONT_UTILS_INTERNAL_H

#include "vr_font_internal.h"

#include "er_math.h"

#define VR_GVAR_TUPLE_SHARED_POINTS 0x8000
#define VR_GVAR_TUPLE_EMBEDDED_PEAK 0x8000
#define VR_GVAR_TUPLE_INTERMEDIATE 0x4000
#define VR_GVAR_TUPLE_PRIVATE_POINTS 0x2000
#define VR_GVAR_TUPLE_COUNT_MASK 0x0FFF

#define VR_GVAR_TUPLE_DATA_OFFSET_16 0x0000
#define VR_GVAR_TUPLE_DATA_OFFSET_32 0x0001

#define VR_SFNT_SCALAR_TTF 0x00010000u
#define VR_SFNT_SCALAR_OTTO VR_TABLE_TAG('t','r','u','e')
#define VR_SFNT_SCALAR_TTCF VR_TABLE_TAG('t','t','c','f')

#define VR_CMAP_TABLE_VERSION 0u
#define VR_CMAP_FORMAT_0 0u
#define VR_CMAP_FORMAT_4 4u
#define VR_CMAP_FORMAT_12 12u
static const uint16_t VR_GVAR_MAJOR_VERSION = 1u;
static const uint16_t VR_GVAR_MINOR_VERSION = 0u;
static const uint32_t VR_GVAR_OFFSET_MULTIPLIER_16 = 2u;
static const uint16_t VR_CMAP_PLATFORM_ID_UNICODE = 0u;
static const uint16_t VR_CMAP_PLATFORM_ID_WINDOWS = 3u;
static const uint16_t VR_GVAR_OFFSET_FORMAT_32 = 1u;
static const uint32_t VR_SFNT_VERSION_MAGIC = 0x00010000u;

void* vr_face_alloc_array(vr_font_face_t* face, size_t count, size_t item_size, size_t align);
void* vr_face_realloc_array(vr_font_face_t* face, void* ptr, size_t old_count, size_t new_count, size_t item_size, size_t align);
void vr_face_free_array(vr_font_face_t* face, void* ptr, size_t count, size_t item_size, size_t align);
vr_status_t vr_parse_table_directory(vr_font_face_t* face);
const vr_table_record_t* vr_find_table(const vr_font_face_t* face, uint32_t tag);
void vr_set_axis_data(vr_font_face_t* face);
vr_status_t vr_parse_head(vr_font_face_t* face, const uint8_t* p, size_t len);
vr_status_t vr_parse_maxp(vr_font_face_t* face, const uint8_t* p, size_t len);
vr_status_t vr_parse_hhea(vr_font_face_t* face, const uint8_t* p, size_t len);
vr_status_t vr_parse_loca(vr_font_face_t* face);
float vr_utils_f2dot14_to_float(uint16_t v);
float vr_fixed_to_float(uint32_t v);
void vr_init_gvar_phantoms(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* outline);
vr_status_t vr_decode_point_indices(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  size_t all_points_hint,
  bool* out_all_points,
  uint16_t** out_points,
  size_t* out_count,
  size_t* out_consumed);
vr_status_t vr_decode_delta_runs(
  const uint8_t* p,
  const uint8_t* end,
  int16_t* out_deltas,
  size_t out_count,
  size_t* out_used);
float vr_compute_tuple_scalar(const vr_font_face_t* face, uint16_t axis_count, const float* start, const float* peak, const float* end);
void vr_iup_interpolate_outline_deltas(
  const vr_glyph_outline_t* outline,
  const int16_t* base_x,
  const int16_t* base_y,
  int32_t* dx,
  int32_t* dy,
  const uint8_t* touched);
vr_status_t vr_read_fvar(vr_font_face_t* face);
vr_status_t vr_parse_cmap_format4(vr_font_face_t* face, const uint8_t* sub, uint16_t length);
vr_status_t vr_parse_cmap_format12(vr_font_face_t* face, const uint8_t* sub, uint16_t length);
uint32_t vr_find_preferred_cmap_offset(const vr_font_face_t* face, const uint8_t* p);

#endif

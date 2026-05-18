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
static void* vr_face_alloc_array(vr_font_face_t* face, size_t count, size_t item_size, size_t align) {
  return vr_calloc(face, count, item_size, align);
}

static void* vr_face_realloc_array(vr_font_face_t* face, void* ptr, size_t old_count, size_t new_count, size_t item_size, size_t align) {
  if (item_size != 0u && (old_count > ((size_t)-1) / item_size || new_count > ((size_t)-1) / item_size)) return NULL;
  return vr_realloc(face, ptr, old_count * item_size, new_count * item_size, align);
}

static void vr_face_free_array(vr_font_face_t* face, void* ptr, size_t count, size_t item_size, size_t align) {
  if (item_size != 0u && count > ((size_t)-1) / item_size) return;
  vr_dealloc(face, ptr, count * item_size, align);
}

bool vr_allocator_valid(vr_font_allocator_t allocator) {
  return allocator.alloc != 0 && allocator.free != 0;
}

void vr_zero(void* ptr, size_t size) {
  uint8_t* bytes = (uint8_t*)ptr;
  for (size_t i = 0u; i < size; ++i) bytes[i] = 0u;
}

void vr_copy(void* dst, const void* src, size_t size) {
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;
  for (size_t i = 0u; i < size; ++i) out[i] = in[i];
}

void vr_move(void* dst, const void* src, size_t size) {
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;
  if (out == in || size == 0u) return;
  if (out < in) {
    for (size_t i = 0u; i < size; ++i) out[i] = in[i];
  } else {
    for (size_t i = size; i > 0u; --i) out[i - 1u] = in[i - 1u];
  }
}

int vr_mem_compare(const void* left, const void* right, size_t size) {
  const uint8_t* a = (const uint8_t*)left;
  const uint8_t* b = (const uint8_t*)right;
  for (size_t i = 0u; i < size; ++i) {
    if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return 0;
}

int vr_tag_compare(const char* left, const char* right) {
  return vr_mem_compare(left, right, 4u);
}

void* vr_alloc(const vr_font_face_t* face, size_t size, size_t align) {
  if (!face || !vr_allocator_valid(face->allocator) || size == 0u) return NULL;
  return face->allocator.alloc(face->allocator.user, size, align);
}

void* vr_calloc(const vr_font_face_t* face, size_t count, size_t size, size_t align) {
  if (size != 0u && count > ((size_t)-1) / size) return NULL;
  size_t bytes = count * size;
  void* ptr = vr_alloc(face, bytes, align);
  if (ptr) vr_zero(ptr, bytes);
  return ptr;
}

void* vr_realloc(const vr_font_face_t* face, void* ptr, size_t old_size, size_t new_size, size_t align) {
  if (!face || !vr_allocator_valid(face->allocator)) return NULL;
  if (new_size == 0u) {
    vr_dealloc(face, ptr, old_size, align);
    return NULL;
  }
  if (face->allocator.realloc) return face->allocator.realloc(face->allocator.user, ptr, old_size, new_size, align);
  void* next = vr_alloc(face, new_size, align);
  if (!next) return NULL;
  if (ptr && old_size > 0u) vr_copy(next, ptr, old_size < new_size ? old_size : new_size);
  vr_dealloc(face, ptr, old_size, align);
  return next;
}

void vr_dealloc(const vr_font_face_t* face, void* ptr, size_t size, size_t align) {
  if (!face || !ptr || !vr_allocator_valid(face->allocator)) return;
  face->allocator.free(face->allocator.user, ptr, size, align);
}

float vr_absf(float value) {
  return er_math_absf(value);
}

float vr_clampf(float value, float min_value, float max_value) {
  return er_math_clampf(value, min_value, max_value);
}

float vr_floorf(float value) {
  return er_math_floorf(value);
}

float vr_ceilf(float value) {
  return er_math_ceilf(value);
}

float vr_sqrtf(float value) {
  return er_math_sqrtf(value);
}

uint8_t vr_u8_from_unitf(float value) {
  return er_math_u8_from_unitf(value);
}

long vr_lrintf(float value) {
  return er_math_lrintf(value);
}

bool vr_float_is_finite(float value) {
  return er_math_isfinitef(value) != 0;
}

float vr_atan2f(float y, float x) {
  return er_math_atan2f(y, x);
}

static vr_status_t vr_parse_table_directory(vr_font_face_t* face) {
  const uint8_t* p = face->file_data;
  if (face->file_size < 12) {
    return VR_ERR_INVALID_FONT;
  }

  uint32_t scalar_type = vr_u32(p);
  uint16_t numTables = vr_u16(p + 4);
  if (scalar_type != VR_SFNT_SCALAR_TTF && scalar_type != VR_SFNT_SCALAR_OTTO && scalar_type != VR_SFNT_SCALAR_TTCF) {
    return VR_ERR_INVALID_FONT;
  }

  face->table_count = numTables;
  face->tables = (vr_table_record_t*)vr_face_alloc_array(face, numTables, sizeof(vr_table_record_t), 8u);
  if (!face->tables) {
    return VR_ERR_OOM;
  }

  const uint8_t* rec = p + 12;
  for (size_t i = 0; i < numTables; ++i) {
    if ((size_t)(rec - p) + 16 > face->file_size) {
      return VR_ERR_INVALID_FONT;
    }
    face->tables[i].tag = vr_tag(rec);
    face->tables[i].checksum = vr_u32(rec + 4);
    face->tables[i].offset = vr_u32(rec + 8);
    face->tables[i].length = vr_u32(rec + 12);
    rec += 16;
  }

  (void)face->table_count;
  (void)face->tables;
  return VR_OK;
}

static const vr_table_record_t* vr_find_table(const vr_font_face_t* face, uint32_t tag) {
  for (size_t i = 0; i < face->table_count; ++i) {
    if (face->tables[i].tag == tag) {
      return &face->tables[i];
    }
  }
  return NULL;
}

static void vr_set_axis_data(vr_font_face_t* face) {
  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    const char* src = face->fvar.descriptors[i].tag;
    face->axes[i].name[0] = src[0];
    face->axes[i].name[1] = src[1];
    face->axes[i].name[2] = src[2];
    face->axes[i].name[3] = src[3];
    face->axes[i].name[4] = '\0';
    face->axes[i].min_value = face->fvar.descriptors[i].min;
    face->axes[i].default_value = face->fvar.descriptors[i].default_value;
    face->axes[i].max_value = face->fvar.descriptors[i].max;
    face->axes[i].value = face->fvar.descriptors[i].default_value;
  }
}

static vr_status_t vr_parse_head(vr_font_face_t* face, const uint8_t* p, size_t len) {
  if (!p || len < 54u) {
    return VR_ERR_INVALID_FONT;
  }
  face->head = (uint8_t*)p;

  uint16_t units = vr_u16(p + 18);
  int16_t xMin = vr_i16(p + 36);
  int16_t yMin = vr_i16(p + 38);
  int16_t xMax = vr_i16(p + 40);
  int16_t yMax = vr_i16(p + 42);
  int16_t index_to_loc_format = (int16_t)vr_i16(p + 50);

  face->units_per_em = units;
  face->yMin = yMin;
  face->yMax = yMax;
  face->index_to_loc_format = index_to_loc_format;
  (void)xMin;
  (void)xMax;
  return VR_OK;
}

static vr_status_t vr_parse_maxp(vr_font_face_t* face, const uint8_t* p, size_t len) {
  (void)len;
  if (!p) return VR_ERR_INVALID_FONT;
  face->maxp = (uint8_t*)p;
  face->maxp_num_glyphs = vr_u16(p + 4);
  face->num_glyphs = (uint16_t)face->maxp_num_glyphs;
  return VR_OK;
}

static vr_status_t vr_parse_hhea(vr_font_face_t* face, const uint8_t* p, size_t len) {
  if (!p || len < 36u) return VR_ERR_INVALID_FONT;
  face->hhea = (uint8_t*)p;
  face->ascender = vr_i16(p + 4);
  face->descender = vr_i16(p + 6);
  face->line_gap = vr_i16(p + 8);
  face->num_h_metrics = vr_u16(p + 34);
  return VR_OK;
}

static vr_status_t vr_parse_loca(vr_font_face_t* face) {
  const vr_table_record_t* loc = vr_find_table(face, VR_TABLE_TAG('l','o','c','a'));
  if (!loc) return VR_ERR_NOT_FOUND;
  if (loc->offset + loc->length > face->file_size) return VR_ERR_INVALID_FONT;

  if (loc->length == 0 || face->num_glyphs == 0) {
    return VR_ERR_INVALID_FONT;
  }

  size_t count = face->num_glyphs + 1;
  face->loca_offsets = (uint32_t*)vr_face_alloc_array(face, count, sizeof(uint32_t), 4u);
  if (!face->loca_offsets) return VR_ERR_OOM;

  const uint8_t* p = face->file_data + loc->offset;
  if (face->index_to_loc_format == 0) {
    for (size_t i = 0; i < count; ++i) {
      uint16_t v = vr_u16(p + i * 2);
      face->loca_offsets[i] = (uint32_t)v * 2u;
    }
  } else {
    for (size_t i = 0; i < count; ++i) {
      face->loca_offsets[i] = vr_u32(p + i * 4);
    }
  }

  return VR_OK;
}

static float vr_f2dot14_to_float(uint16_t v) {
  return (float)(int16_t)v / 16384.0f;
}

static float vr_fixed_to_float(uint32_t v) {
  return (float)(int32_t)v / 65536.0f;
}

uint16_t vr_get_glyph_h_advance_units(const vr_font_face_t* face, uint16_t glyph_id) {
  if (!face || !face->hmtx || face->num_h_metrics == 0) return 0;
  if (glyph_id < face->num_h_metrics) {
    return vr_u16(face->hmtx + ((size_t)glyph_id * 4u));
  }
  if (glyph_id < face->maxp_num_glyphs) {
    return vr_u16(face->hmtx + ((size_t)(face->num_h_metrics - 1u) * 4u));
  }
  return 0;
}

int16_t vr_get_glyph_h_lsb_units(const vr_font_face_t* face, uint16_t glyph_id) {
  if (!face || !face->hmtx || face->num_h_metrics == 0) return 0;
  if (glyph_id < face->num_h_metrics) {
    return vr_i16(face->hmtx + ((size_t)glyph_id * 4u) + 2u);
  }
  if (glyph_id < face->maxp_num_glyphs) {
    size_t index = (size_t)face->num_h_metrics * 4u + ((size_t)(glyph_id - face->num_h_metrics) * 2u);
    return vr_i16(face->hmtx + index);
  }
  return 0;
}

static void vr_init_gvar_phantoms(
  const vr_font_face_t* face,
  uint16_t glyph_id,
  vr_glyph_outline_t* outline) {
  int16_t lsb = vr_get_glyph_h_lsb_units(face, glyph_id);
  uint16_t adv = vr_get_glyph_h_advance_units(face, glyph_id);

  outline->has_phantom_points = true;
  outline->phantom_x[0] = (int32_t)lsb;
  outline->phantom_x[1] = (int32_t)lsb + (int32_t)adv;
  outline->phantom_y[0] = 0;
  outline->phantom_y[1] = 0;
  outline->phantom_x[2] = 0;
  outline->phantom_x[3] = 0;
  outline->phantom_y[2] = (int32_t)outline->y_max;
  outline->phantom_y[3] = (int32_t)outline->y_min;
}

//@optimizer-ignore-function gvar point index decoding must expand compressed point runs from the font table
static vr_status_t vr_decode_point_indices(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  size_t all_points_hint,
  bool* out_all_points,
  uint16_t** out_points,
  size_t* out_count,
  size_t* out_consumed) {
  const uint8_t* start = p;
  if (!p || !end || !out_all_points || !out_count || !out_consumed) return VR_ERR_INVALID_FONT;
  if (p >= end) return VR_ERR_INVALID_FONT;

  *out_points = NULL;
  *out_count = 0;
  *out_all_points = false;
  *out_consumed = 0;

  uint8_t first = *p++;
  size_t count = 0;

  if (first == 0) {
    *out_all_points = true;
    count = all_points_hint;
    *out_count = count;
    *out_consumed = (size_t)(p - start);
    return VR_OK;
  }

  if ((first & 0x80u) != 0) {
    if (p >= end) return VR_ERR_INVALID_FONT;
    count = ((size_t)(first & 0x7Fu) << 8) | (size_t)(*p++);
  } else {
    count = (size_t)first;
  }
  if (count > ((SIZE_MAX - 1) / sizeof(uint16_t))) return VR_ERR_INVALID_FONT;

  uint16_t* points = (uint16_t*)vr_alloc(face, count * sizeof(uint16_t), 2u);
  if (!points && count > 0) return VR_ERR_OOM;
  if (count == 0) {
    *out_points = NULL;
    *out_count = 0;
    *out_consumed = (size_t)(p - start);
    return VR_OK;
  }

  size_t parsed = 0;
  uint16_t last = 0;
  while (parsed < count) {
    if (p >= end) {
      vr_dealloc(face, points, count * sizeof(*points), 2u);
      return VR_ERR_INVALID_FONT;
    }

    uint8_t run_ctl = *p++;
    size_t run_count = (size_t)(run_ctl & 0x7Fu) + 1;
    bool words = (run_ctl & 0x80u) != 0;

    for (size_t i = 0; i < run_count; ++i) {
      uint16_t delta = 0;
      if (words) {
        if (p + 2 > end) {
          vr_dealloc(face, points, count * sizeof(*points), 2u);
          return VR_ERR_INVALID_FONT;
        }
        delta = vr_u16(p);
        p += 2;
      } else {
        if (p >= end) {
          vr_dealloc(face, points, count * sizeof(*points), 2u);
          return VR_ERR_INVALID_FONT;
        }
        delta = (uint16_t)(*p++);
      }

      last = (uint16_t)(last + delta);
      if (parsed < count) {
        points[parsed++] = last;
      }
    }
  }

  *out_points = points;
  *out_count = count;
  *out_consumed = (size_t)(p - start);
  return VR_OK;
}

//@optimizer-ignore-function gvar delta decoding must expand zero, byte, and word run encodings point-by-point
static vr_status_t vr_decode_delta_runs(
  const uint8_t* p,
  const uint8_t* end,
  int16_t* out_deltas,
  size_t out_count,
  size_t* out_used) {
  if (!p || !end || !out_deltas || !out_used) return VR_ERR_INVALID_FONT;
  if (out_count == 0) {
    *out_used = 0;
    return VR_OK;
  }

  size_t produced = 0;
  const uint8_t* start = p;

  while (produced < out_count) {
    if (p >= end) {
      return VR_ERR_INVALID_FONT;
    }
    uint8_t ctl = *p++;
    size_t run_count = (size_t)(ctl & 0x3Fu) + 1;

    if ((ctl & 0x80u) != 0) {
      for (size_t i = 0; i < run_count && produced < out_count; ++i) {
        out_deltas[produced++] = 0;
      }
      continue;
    }

    if ((ctl & 0x40u) != 0) {
      size_t bytes = run_count * 2;
      if ((size_t)(end - p) < bytes) return VR_ERR_INVALID_FONT;
      for (size_t i = 0; i < run_count; ++i) {
        int16_t v = (int16_t)vr_u16(p);
        p += 2;
        if (produced < out_count) out_deltas[produced] = v;
        produced++;
      }
      continue;
    }

    if ((size_t)(end - p) < run_count) return VR_ERR_INVALID_FONT;
    for (size_t i = 0; i < run_count; ++i) {
      int16_t v = (int8_t)(*p++);
      if (produced < out_count) out_deltas[produced] = v;
      produced++;
    }
  }

  *out_used = (size_t)(p - start);
  return produced == out_count ? VR_OK : VR_ERR_INVALID_FONT;
}

//@optimizer-ignore-function variation tuple scalar must evaluate each active axis support interval
static float vr_compute_tuple_scalar(const vr_font_face_t* face, uint16_t axis_count,
                                    const float* start, const float* peak, const float* end) {
  float scalar = 1.0f;
  for (uint16_t i = 0; i < axis_count; ++i) {
    float as = 1.0f;
    float sc = start[i];
    float pk = peak[i];
    float en = end[i];
    float n = face->axis_values[i];

    if (!(sc <= pk && pk <= en)) {
      return 0.0f;
    }

    if (n < sc || n > en) {
      as = 0.0f;
    } else if (pk == sc || pk == en) {
      as = (n == pk) ? 1.0f : 0.0f;
    } else if (n < pk) {
      as = (pk - sc > 0.0f) ? ((n - sc) / (pk - sc)) : 0.0f;
    } else if (n > pk) {
      as = (en - pk > 0.0f) ? ((en - n) / (en - pk)) : 0.0f;
    } else {
      as = 1.0f;
    }

    scalar *= as;
    if (scalar <= 0.0f) {
      return 0.0f;
    }
  }
  return scalar;
}

static size_t vr_iup_next_index(size_t index, size_t start, size_t end) {
  return (index >= end) ? start : (index + 1u);
}

static int32_t vr_iup_interpolate_delta(int16_t coord, int16_t coord_a, int16_t coord_b, int32_t delta_a, int32_t delta_b) {
  if (coord_a == coord_b) {
    return delta_a;
  }

  int16_t min_coord = coord_a;
  int16_t max_coord = coord_b;
  int32_t min_delta = delta_a;
  int32_t max_delta = delta_b;
  if (coord_a > coord_b) {
    min_coord = coord_b;
    max_coord = coord_a;
    min_delta = delta_b;
    max_delta = delta_a;
  }

  if (coord <= min_coord) {
    return min_delta;
  }
  if (coord >= max_coord) {
    return max_delta;
  }

  float ratio = (float)(coord - min_coord) / (float)(max_coord - min_coord);
  return (int32_t)vr_lrintf((float)min_delta + ((float)(max_delta - min_delta) * ratio));
}

static void vr_iup_interpolate_contour_axis(
  const int16_t* coords,
  int32_t* deltas,
  const uint8_t* touched,
  size_t start,
  size_t end) {
  size_t first_touched = end + 1u;
  size_t touched_count = 0u;
  for (size_t i = start; i <= end; ++i) {
    if (touched[i] != 0u) {
      if (first_touched > end) {
        first_touched = i;
      }
      ++touched_count;
    }
  }

  if (touched_count == 0u) {
    return;
  }
  if (touched_count == 1u) {
    int32_t delta = deltas[first_touched];
    for (size_t i = start; i <= end; ++i) {
      if (touched[i] == 0u) {
        deltas[i] = delta;
      }
    }
    return;
  }

  size_t left = first_touched;
  do {
    size_t right = vr_iup_next_index(left, start, end);
    while (right != left && touched[right] == 0u) {
      right = vr_iup_next_index(right, start, end);
    }

    size_t fill = vr_iup_next_index(left, start, end);
    while (fill != right) {
      deltas[fill] = vr_iup_interpolate_delta(coords[fill], coords[left], coords[right], deltas[left], deltas[right]);
      fill = vr_iup_next_index(fill, start, end);
    }
    left = right;
  } while (left != first_touched);
}

static void vr_iup_interpolate_outline_deltas(
  const vr_glyph_outline_t* outline,
  const int16_t* base_x,
  const int16_t* base_y,
  int32_t* dx,
  int32_t* dy,
  const uint8_t* touched) {
  if (!outline || !base_x || !base_y || !dx || !dy || !touched || outline->point_count <= 0) {
    return;
  }

  for (uint16_t c = 0u; c < outline->number_of_contours; ++c) {
    size_t start = (c == 0u) ? 0u : ((size_t)outline->contour_end_pts[c - 1u] + 1u);
    size_t end = (size_t)outline->contour_end_pts[c];
    if (start > end || end >= (size_t)outline->point_count) {
      continue;
    }
    vr_iup_interpolate_contour_axis(base_x, dx, touched, start, end);
    vr_iup_interpolate_contour_axis(base_y, dy, touched, start, end);
  }
}

//@optimizer-ignore-function avar mapping must scan ordered axis segments and interpolate the containing interval
float vr_apply_avar_mapping(const vr_font_face_t* face, uint16_t axis_index, float value) {
  if (!face || face->avar.axis_count == 0 || axis_index >= face->avar.axis_count) return value;
  if (!face->avar.map_from || !face->avar.map_to || !face->avar.segment_count || !face->avar.segment_offset) {
    return value;
  }

  uint16_t seg_count = face->avar.segment_count[axis_index];
  if (seg_count == 0) return value;

  size_t base = face->avar.segment_offset[axis_index];
  if (base >= face->avar.total_segment_count) return value;

  if (seg_count == 1) {
    return face->avar.map_to[base];
  }

  float first_in = face->avar.map_from[base];
  float last_in = face->avar.map_from[base + (size_t)seg_count - 1u];
  if (value <= first_in) return face->avar.map_to[base];
  if (value >= last_in) return face->avar.map_to[base + (size_t)seg_count - 1u];

  for (uint16_t i = 0; i + 1 < seg_count; ++i) {
    size_t k = base + (size_t)i;
    float in0 = face->avar.map_from[k];
    float in1 = face->avar.map_from[k + 1];
    float out0 = face->avar.map_to[k];
    float out1 = face->avar.map_to[k + 1];
    if (value >= in0 && value <= in1) {
      float denom = in1 - in0;
      if (denom == 0.0f) return out1;
      return out0 + (value - in0) * (out1 - out0) / denom;
    }
  }

  return value;
}

//@optimizer-ignore-function gvar parsing must decode glyph offsets and shared tuples from variable-font tables
vr_status_t vr_parse_gvar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('g', 'v', 'a', 'r'));
  if (!t) {
    face->gvar.axis_count = 0;
    face->gvar.glyph_count = face->num_glyphs;
    return VR_ERR_NOT_FOUND;
  }
  if (t->length < 20 || t->offset + t->length > face->file_size) return VR_ERR_INVALID_FONT;

  const uint8_t* p = face->file_data + t->offset;
  uint16_t major = vr_u16(p);
  uint16_t minor = vr_u16(p + 2);
  uint16_t axis_count = vr_u16(p + 4);
  uint16_t shared_tuple_count = vr_u16(p + 6);
  uint32_t shared_tuples_offset = vr_u32(p + 8);
  uint16_t glyph_count = vr_u16(p + 12);
  uint16_t flags = vr_u16(p + 14);
  uint32_t glyph_data_array_offset = vr_u32(p + 16);

  if (major != VR_GVAR_MAJOR_VERSION || minor != VR_GVAR_MINOR_VERSION) return VR_ERR_INVALID_FONT;
  if (axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  if (face->fvar.axis_count != 0 && axis_count != face->fvar.axis_count) return VR_ERR_INVALID_FONT;
  if (glyph_count != face->num_glyphs) return VR_ERR_INVALID_FONT;

  bool use32 = (flags & VR_GVAR_OFFSET_FORMAT_32) != 0u;
  size_t offset_size = use32 ? 4u : 2u;
  size_t offset_count = (size_t)glyph_count + 1;
  size_t header_len = 20;
  size_t offset_bytes = offset_count * offset_size;

  if (shared_tuples_offset > t->length) return VR_ERR_INVALID_FONT;
  if (glyph_data_array_offset > t->length) return VR_ERR_INVALID_FONT;
  if (header_len + offset_bytes > t->length) return VR_ERR_INVALID_FONT;
  if (shared_tuples_offset < header_len + offset_bytes) return VR_ERR_INVALID_FONT;
  if (glyph_data_array_offset < shared_tuples_offset) return VR_ERR_INVALID_FONT;

  uint32_t* glyph_off = (uint32_t*)vr_face_alloc_array(face, offset_count, sizeof(uint32_t), 4u);
  if (!glyph_off) return VR_ERR_OOM;

  const uint8_t* offset_base = p + header_len;
  for (size_t i = 0; i < offset_count; ++i) {
    uint32_t rel = use32 ? vr_u32(offset_base + i * 4u) :
                           ((uint32_t)vr_u16(offset_base + i * 2u) * VR_GVAR_OFFSET_MULTIPLIER_16);
    uint64_t abs = (uint64_t)glyph_data_array_offset + rel;
    if (abs > (uint64_t)t->length) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }
    glyph_off[i] = (uint32_t)abs;
  }

  if (shared_tuple_count > 0 && axis_count > 0) {
    size_t shared_bytes = (size_t)shared_tuple_count * (size_t)axis_count * 2u;
    uint32_t shared_end = shared_tuples_offset + (uint32_t)shared_bytes;
    if (shared_end > glyph_data_array_offset) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }
    if (shared_end > t->length) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }

    size_t tuple_values = (size_t)shared_tuple_count * (size_t)axis_count;
    float* shared_tuples = (float*)vr_face_alloc_array(face, tuple_values, sizeof(float), 8u);
    if (!shared_tuples) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_OOM;
    }

    const uint8_t* tuple = p + shared_tuples_offset;
    for (uint16_t i = 0; i < shared_tuple_count; ++i) {
      for (uint16_t a = 0; a < axis_count; ++a) {
        shared_tuples[(size_t)i * axis_count + a] = vr_f2dot14_to_float(vr_u16(tuple));
        tuple += 2;
      }
    }
    face->gvar.shared_tuples = shared_tuples;
  }

  face->gvar.glyph_count = glyph_count;
  face->gvar.axis_count = axis_count;
  face->gvar.flags = flags;
  face->gvar.shared_tuple_count = shared_tuple_count;
  face->gvar.shared_tuples_offset = shared_tuples_offset;
  face->gvar.glyph_data_array_offset = glyph_data_array_offset;
  face->gvar.offset_format = use32 ? VR_GVAR_TUPLE_DATA_OFFSET_32 : VR_GVAR_TUPLE_DATA_OFFSET_16;
  face->gvar.glyph_variation_offsets = glyph_off;
  return VR_OK;
}

//@optimizer-ignore-function avar parsing must decode each axis segment map from variable-font tables
vr_status_t vr_parse_avar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('a', 'v', 'a', 'r'));
  if (!t) {
    face->avar.axis_count = face->fvar.axis_count;
    return VR_ERR_NOT_FOUND;
  }
  if (t->offset + t->length > face->file_size) return VR_ERR_INVALID_FONT;
  if (t->length < 8) return VR_ERR_INVALID_FONT;

  const uint8_t* p = face->file_data + t->offset;
  uint32_t version = vr_u32(p);
  uint16_t axis_count = vr_u16(p + 6);

  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  if (face->fvar.axis_count != 0 && face->fvar.axis_count != axis_count) return VR_ERR_INVALID_FONT;
  if (t->length < 8u + (size_t)axis_count * 2u) return VR_ERR_INVALID_FONT;

  face->avar.axis_count = axis_count;
  if (axis_count == 0) {
    return VR_OK;
  }

  uint16_t* seg_counts = (uint16_t*)vr_face_alloc_array(face, axis_count, sizeof(uint16_t), 2u);
  size_t* seg_offsets = (size_t*)vr_face_alloc_array(face, axis_count, sizeof(size_t), 8u);
  if (!seg_counts || !seg_offsets) {
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_ERR_OOM;
  }

  uint32_t total_segments = 0;
  const uint8_t* map_offsets = p + 8;
  for (uint16_t a = 0; a < axis_count; ++a) {
    uint16_t off = vr_u16(map_offsets + (size_t)a * 2u);
    if (off == 0) {
      continue;
    }
    if ((size_t)off + 2 > t->length) {
      vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
      vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
      return VR_ERR_INVALID_FONT;
    }
    seg_counts[a] = vr_u16(p + off);
    total_segments += seg_counts[a];
  }

  if (total_segments == 0) {
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_OK;
  }

  float* map_from = (float*)vr_face_alloc_array(face, (size_t)total_segments, sizeof(float), 8u);
  float* map_to = (float*)vr_face_alloc_array(face, (size_t)total_segments, sizeof(float), 8u);
  if (!map_from || !map_to) {
    vr_face_free_array(face, map_from, (size_t)total_segments, sizeof(float), 8u);
    vr_face_free_array(face, map_to, (size_t)total_segments, sizeof(float), 8u);
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_ERR_OOM;
  }

  uint32_t cursor = 0;
  for (uint16_t a = 0; a < axis_count; ++a) {
    uint16_t off = vr_u16(map_offsets + (size_t)a * 2u);
    uint16_t sc = seg_counts[a];
    seg_offsets[a] = (size_t)cursor;

    if (off == 0 || sc == 0) {
      continue;
    }

    const uint8_t* map = p + off;
    size_t needed = 2u + (size_t)sc * 4u;
    if (off + needed > t->length) {
      vr_face_free_array(face, map_from, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, map_to, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
      vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
      return VR_ERR_INVALID_FONT;
    }

    const uint8_t* from = map + 2;
    const uint8_t* to = from + (size_t)sc * 2u;
    for (uint16_t i = 0; i < sc; ++i) {
      map_from[cursor + i] = vr_f2dot14_to_float(vr_u16(from + ((size_t)i * 2u)));
      map_to[cursor + i] = vr_f2dot14_to_float(vr_u16(to + ((size_t)i * 2u)));
    }
    cursor += sc;
  }

  face->avar.segment_count = seg_counts;
  face->avar.segment_offset = seg_offsets;
  face->avar.total_segment_count = (size_t)total_segments;
  face->avar.map_from = map_from;
  face->avar.map_to = map_to;
  return VR_OK;
}

//@optimizer-ignore-function gvar application must walk each tuple variation and apply per-point deltas
vr_status_t vr_apply_gvar_variation(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* outline) {
  if (!face || !outline) return VR_ERR_INVALID_FONT;
  if (face->gvar.axis_count == 0 || face->gvar.glyph_count == 0) return VR_OK;
  if (face->gvar.glyph_variation_offsets == NULL || glyph_id >= face->gvar.glyph_count) return VR_OK;
  if (outline->point_count < 0) return VR_OK;
  if (face->gvar.axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  vr_init_gvar_phantoms(face, glyph_id, outline);

  const vr_table_record_t* gvar = vr_find_table(face, VR_TABLE_TAG('g', 'v', 'a', 'r'));
  if (!gvar) return VR_OK;

  uint32_t start = face->gvar.glyph_variation_offsets[glyph_id];
  uint32_t end = face->gvar.glyph_variation_offsets[glyph_id + 1];
  if (start >= end || gvar->offset + gvar->length < gvar->offset + end) return VR_OK;

  const uint8_t* p = face->file_data + gvar->offset;
  const uint8_t* glyph_data = p + start;
  const uint8_t* glyph_data_end = p + end;
  if (glyph_data + 4 > glyph_data_end) return VR_OK;

  size_t total_points = (size_t)outline->point_count + 4u;
  int16_t* base_x = NULL;
  int16_t* base_y = NULL;
  if (outline->point_count > 0) {
    base_x = (int16_t*)vr_alloc(face, (size_t)outline->point_count * sizeof(*base_x), 2u);
    base_y = (int16_t*)vr_alloc(face, (size_t)outline->point_count * sizeof(*base_y), 2u);
    if (!base_x || !base_y) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_OOM;
    }
    for (size_t i = 0u; i < (size_t)outline->point_count; ++i) {
      base_x[i] = outline->x[i];
      base_y[i] = outline->y[i];
    }
  }
  uint16_t tuple_count = vr_u16(glyph_data) & VR_GVAR_TUPLE_COUNT_MASK;
  uint16_t table_flags = vr_u16(glyph_data) & 0xF000u;
  size_t data_offset = (size_t)vr_u16(glyph_data + 2);
  const uint8_t* serialized = glyph_data + data_offset;
  if (serialized > glyph_data_end) {
    vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
    vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
    return VR_OK;
  }

  uint16_t* shared_points = NULL;
  bool shared_points_all = false;
  size_t shared_point_count = 0;
  size_t shared_consumed = 0;
  const uint8_t* tuple_data = serialized;

  if ((table_flags & VR_GVAR_TUPLE_SHARED_POINTS) != 0) {
    vr_status_t st = vr_decode_point_indices(face, serialized, glyph_data_end, total_points, &shared_points_all,
                                             &shared_points, &shared_point_count, &shared_consumed);
    if (st != VR_OK) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return st;
    }
    tuple_data += shared_consumed;
    if (shared_points == NULL && shared_point_count > 0) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_OOM;
    }
  }

  const uint8_t* header = glyph_data + 4;
  for (uint16_t tvi = 0; tvi < tuple_count; ++tvi) {
    if (tuple_data > glyph_data_end) {
      break;
    }
    if (header + 4 > glyph_data_end) {
      vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_INVALID_FONT;
    }

    uint16_t tuple_data_size = vr_u16(header);
    uint16_t tuple_index = vr_u16(header + 2);
    header += 4;
    if (tuple_data + tuple_data_size > glyph_data_end) {
      vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_INVALID_FONT;
    }

    bool embedded_peak = (tuple_index & VR_GVAR_TUPLE_EMBEDDED_PEAK) != 0;
    bool intermediate = (tuple_index & VR_GVAR_TUPLE_INTERMEDIATE) != 0;
    bool private_points = (tuple_index & VR_GVAR_TUPLE_PRIVATE_POINTS) != 0;

    float peak[VR_MAX_AXES];
    float start_curve[VR_MAX_AXES];
    float end_curve[VR_MAX_AXES];

    if (embedded_peak) {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (header + 2 > glyph_data_end) {
          vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
          vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
          vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
          return VR_ERR_INVALID_FONT;
        }
        peak[i] = vr_f2dot14_to_float(vr_u16(header));
        header += 2;
      }
    } else {
      uint16_t shared_index = tuple_index & VR_GVAR_TUPLE_COUNT_MASK;
      if (shared_index >= face->gvar.shared_tuple_count || face->gvar.shared_tuples == NULL) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_INVALID_FONT;
      }
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        peak[i] = face->gvar.shared_tuples[(size_t)shared_index * face->gvar.axis_count + i];
      }
    }

    if (intermediate) {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (header + 2 > glyph_data_end || header + 4 > glyph_data_end) {
          vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
          vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
          vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
          return VR_ERR_INVALID_FONT;
        }
        start_curve[i] = vr_f2dot14_to_float(vr_u16(header));
        end_curve[i] = vr_f2dot14_to_float(vr_u16(header + 2));
        header += 4;
      }
    } else {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (peak[i] > 0.0f) {
          start_curve[i] = 0.0f;
          end_curve[i] = peak[i];
        } else if (peak[i] < 0.0f) {
          start_curve[i] = peak[i];
          end_curve[i] = 0.0f;
        } else {
          start_curve[i] = 0.0f;
          end_curve[i] = 0.0f;
        }
      }
    }

    bool tuple_all = false;
    uint16_t* tuple_points = NULL;
    size_t tuple_point_count = 0;
    size_t local_bytes = 0;

    if (private_points) {
      vr_status_t st = vr_decode_point_indices(face, tuple_data, glyph_data_end, total_points, &tuple_all,
                                               &tuple_points, &tuple_point_count, &local_bytes);
      if (st != VR_OK) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return st;
      }
      if (tuple_points == NULL && tuple_point_count > 0) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_OOM;
      }
    } else if ((table_flags & VR_GVAR_TUPLE_SHARED_POINTS) != 0) {
      tuple_all = shared_points_all;
      tuple_points = shared_points;
      tuple_point_count = shared_point_count;
      local_bytes = 0;
    } else {
      tuple_all = true;
      tuple_point_count = total_points;
    }

    const uint8_t* delta_data = tuple_data + local_bytes;
    size_t point_apply_count = tuple_all ? total_points : tuple_point_count;
    if (point_apply_count > (size_t)UINT16_MAX) point_apply_count = (size_t)UINT16_MAX;

    int16_t* raw_dx = NULL;
    int16_t* raw_dy = NULL;
    int32_t* dx = NULL;
    int32_t* dy = NULL;
    uint8_t* touched = NULL;
    size_t used_x = 0;
    size_t used_y = 0;

    if (point_apply_count > 0) {
      raw_dx = (int16_t*)vr_calloc(face, point_apply_count, sizeof(int16_t), 2u);
      raw_dy = (int16_t*)vr_calloc(face, point_apply_count, sizeof(int16_t), 2u);
      dx = (int32_t*)vr_calloc(face, total_points, sizeof(int32_t), 4u);
      dy = (int32_t*)vr_calloc(face, total_points, sizeof(int32_t), 4u);
      touched = (uint8_t*)vr_calloc(face, total_points, sizeof(uint8_t), 1u);
      if (!raw_dx || !raw_dy || !dx || !dy || !touched) {
        vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
        vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
        vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
        vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
        vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
        if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_OOM;
      }

      vr_status_t sx = vr_decode_delta_runs(delta_data, glyph_data_end, raw_dx, point_apply_count, &used_x);
      vr_status_t sy = vr_decode_delta_runs(delta_data + used_x, glyph_data_end, raw_dy, point_apply_count, &used_y);
      if (sx != VR_OK || sy != VR_OK || (delta_data + used_x + used_y > tuple_data + tuple_data_size)) {
        vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
        vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
        vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
        vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
        vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
        if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_INVALID_FONT;
      }

      for (size_t i = 0; i < point_apply_count; ++i) {
        uint16_t pi = tuple_all ? (uint16_t)i : tuple_points[i];
        if (pi >= total_points) {
          continue;
        }
        dx[pi] = raw_dx[i];
        dy[pi] = raw_dy[i];
        touched[pi] = 1u;
      }
      if (!tuple_all && outline->point_count > 0) {
        vr_iup_interpolate_outline_deltas(outline, base_x, base_y, dx, dy, touched);
      }
    }

    float scalar = vr_compute_tuple_scalar(face, face->gvar.axis_count, start_curve, peak, end_curve);
    if (scalar > 0.0f && point_apply_count > 0) {
      for (size_t pi = 0; pi < total_points; ++pi) {
        int32_t nx = (int32_t)vr_lrintf((float)dx[pi] * scalar);
        int32_t ny = (int32_t)vr_lrintf((float)dy[pi] * scalar);

        if (pi < (uint16_t)outline->point_count) {
          int32_t next_x = (int32_t)outline->x[pi] + nx;
          int32_t next_y = (int32_t)outline->y[pi] + ny;
          if (next_x < INT16_MIN || next_x > INT16_MAX || next_y < INT16_MIN || next_y > INT16_MAX) {
            vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
            vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
            vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
            vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
            vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
            if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
            vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
            vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
            vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
            return VR_ERR_INVALID_FONT;
          }
          outline->x[pi] = (int16_t)next_x;
          outline->y[pi] = (int16_t)next_y;
          continue;
        }
        if (outline->has_phantom_points && pi >= (uint16_t)outline->point_count && pi < (uint16_t)(outline->point_count + 4)) {
          size_t pp = (size_t)(pi - (uint16_t)outline->point_count);
          outline->phantom_x[pp] = outline->phantom_x[pp] + (int32_t)nx;
          outline->phantom_y[pp] = outline->phantom_y[pp] + (int32_t)ny;
        }
      }
    }

    vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
    vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
    vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
    vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
    vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
    if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);

    tuple_data += tuple_data_size;
    (void)tuple_data_size;
  }

  vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
  vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
  vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
  return VR_OK;
}

static vr_status_t vr_read_fvar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('f','v','a','r'));
  if (!t) {
    face->fvar.axis_count = 0;
    return VR_OK;
  }
  if (t->offset + t->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + t->offset;
  uint32_t version = vr_u32(p);
  uint16_t axis_offset = vr_u16(p + 4);
  uint16_t axis_count = vr_u16(p + 8);
  uint16_t axis_size = vr_u16(p + 10);
  uint16_t instance_count = vr_u16(p + 12);
  uint16_t instance_size = vr_u16(p + 14);
  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES || axis_size < 20) {
    return VR_ERR_INVALID_FONT;
  }
  if (axis_offset > t->length || axis_offset < 16u) {
    return VR_ERR_INVALID_FONT;
  }
  if (instance_size < 4u && instance_count != 0u) {
    return VR_ERR_INVALID_FONT;
  }
  size_t instance_records_size = (size_t)instance_count * (size_t)instance_size;
  if (instance_records_size > (size_t)t->length || axis_offset + instance_records_size > t->length) {
    return VR_ERR_INVALID_FONT;
  }

  face->fvar.axis_count = axis_count;
  face->fvar.default_instance_index = 0;
  face->fvar.axis_value_record_count = 0;

  const uint8_t* a = p + axis_offset;
  for (uint16_t i = 0; i < axis_count; ++i) {
    if ((size_t)(a - p) + 20 > t->length) {
      return VR_ERR_INVALID_FONT;
    }
    uint32_t tag = vr_u32(a);
    float minValue = vr_fixed_to_float(vr_u32(a + 4));
    float defaultValue = vr_fixed_to_float(vr_u32(a + 8));
    float maxValue = vr_fixed_to_float(vr_u32(a + 12));
    float step = vr_fixed_to_float(vr_u32(a + 16));
    (void)step;

    face->fvar.descriptors[i].tag[0] = (char)(tag >> 24);
    face->fvar.descriptors[i].tag[1] = (char)(tag >> 16);
    face->fvar.descriptors[i].tag[2] = (char)(tag >> 8);
    face->fvar.descriptors[i].tag[3] = (char)tag;
    face->fvar.descriptors[i].tag[4] = '\0';
    face->fvar.descriptors[i].min = minValue;
    face->fvar.descriptors[i].default_value = defaultValue;
    face->fvar.descriptors[i].max = maxValue;

    a += axis_size;
  }

  vr_set_axis_data(face);
  return VR_OK;
}

static vr_status_t vr_parse_cmap_format4(
  vr_font_face_t* face,
  const uint8_t* sub,
  uint16_t length) {
  face->cmap.format = VR_CMAP_FORMAT_4;
  face->cmap.length = length;
  face->cmap.language = vr_u16(sub + 4);
  uint16_t seg_count_x2 = vr_u16(sub + 6);
  face->cmap.u.format4.seg_count_x2 = seg_count_x2;

  uint16_t seg_count = (uint16_t)(seg_count_x2 / 2u);
  const uint8_t* q = sub + 14;
  size_t headers = (size_t)4u * 2u * (size_t)seg_count;
  if ((size_t)length < (size_t)(q - sub) + headers) return VR_ERR_INVALID_FONT;

  uint16_t* end_code = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  uint16_t* start_code = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  int16_t* id_delta = (int16_t*)vr_face_alloc_array(face, seg_count, sizeof(int16_t), 2u);
  uint16_t* id_range_offset = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  if (!end_code || !start_code || !id_delta || !id_range_offset) {
    vr_face_free_array(face, end_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, start_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, id_delta, seg_count, sizeof(int16_t), 2u);
    vr_face_free_array(face, id_range_offset, seg_count, sizeof(uint16_t), 2u);
    return VR_ERR_OOM;
  }

  for (uint16_t i = 0; i < seg_count; ++i) {
    end_code[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u + 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    start_code[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    id_delta[i] = (int16_t)vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    id_range_offset[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;

  size_t remaining = (size_t)length - (size_t)(q - sub);
  size_t glyph_count = remaining / 2u;
  uint16_t* glyph_id_array = NULL;
  if (glyph_count > 0u) {
    glyph_id_array = (uint16_t*)vr_face_alloc_array(face, glyph_count, sizeof(uint16_t), 2u);
  }
  if (glyph_count > 0u && !glyph_id_array) {
    vr_face_free_array(face, end_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, start_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, id_delta, seg_count, sizeof(int16_t), 2u);
    vr_face_free_array(face, id_range_offset, seg_count, sizeof(uint16_t), 2u);
    return VR_ERR_OOM;
  }
  for (size_t i = 0; i < glyph_count; ++i) {
    glyph_id_array[i] = vr_u16(q + i * 2u);
  }

  face->cmap.u.format4.end_code = end_code;
  face->cmap.u.format4.start_code = start_code;
  face->cmap.u.format4.id_delta = id_delta;
  face->cmap.u.format4.id_range_offset = id_range_offset;
  face->cmap.u.format4.glyph_id_array_count = glyph_count;
  face->cmap.u.format4.glyph_id_array = glyph_id_array;
  return VR_OK;
}

static vr_status_t vr_parse_cmap_format12(
  vr_font_face_t* face,
  const uint8_t* sub,
  uint16_t length) {
  face->cmap.format = VR_CMAP_FORMAT_12;
  face->cmap.language = vr_u16(sub + 4);

  if (length < 16u) return VR_ERR_INVALID_FONT;
  uint32_t n_groups = vr_u32(sub + 12);
  const uint8_t* q = sub + 16;
  size_t needed = 16u + (size_t)n_groups * 12u;
  if (needed > (size_t)length) return VR_ERR_INVALID_FONT;

  uint32_t* start_char = NULL;
  uint32_t* end_char = NULL;
  uint32_t* start_glyph = NULL;
  if (n_groups > 0u) {
    start_char = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
    end_char = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
    start_glyph = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
  }
  if (n_groups > 0u && (!start_char || !end_char || !start_glyph)) {
    vr_face_free_array(face, start_char, n_groups, sizeof(uint32_t), 4u);
    vr_face_free_array(face, end_char, n_groups, sizeof(uint32_t), 4u);
    vr_face_free_array(face, start_glyph, n_groups, sizeof(uint32_t), 4u);
    return VR_ERR_OOM;
  }

  for (uint32_t i = 0; i < n_groups; ++i) {
    start_char[i] = vr_u32(q + i * 12u);
    end_char[i] = vr_u32(q + i * 12u + 4u);
    start_glyph[i] = vr_u32(q + i * 12u + 8u);
  }

  face->cmap.u.format12.n_groups = n_groups;
  face->cmap.u.format12.start_char_code = start_char;
  face->cmap.u.format12.end_char_code = end_char;
  face->cmap.u.format12.start_glyph_id = start_glyph;
  return VR_OK;
}

static uint32_t vr_find_preferred_cmap_offset(const vr_font_face_t* face, const uint8_t* p) {
  uint16_t count = vr_u16(p + 2);
  const uint8_t* enc = p + 4;
  uint32_t selected = 0u;
  bool preferred_found = false;

  for (uint16_t i = 0; i < count; ++i) {
    uint16_t platform_id = vr_u16(enc + (size_t)i * 8u);
    uint32_t offset = vr_u32(enc + (size_t)i * 8u + 4u);
    face->cmap_offsets[i] = offset;
    if (!preferred_found && (platform_id == VR_CMAP_PLATFORM_ID_WINDOWS || platform_id == VR_CMAP_PLATFORM_ID_UNICODE)) {
      selected = offset;
      preferred_found = true;
    }
  }
  if (!preferred_found && face->cmap_offset_count > 0) {
    selected = face->cmap_offsets[0];
  }
  return selected;
}

vr_status_t vr_parse_cmap(vr_font_face_t* face) {
  const vr_table_record_t* cmap = vr_find_table(face, VR_TABLE_TAG('c','m','a','p'));
  if (!cmap) {
    return VR_ERR_NOT_FOUND;
  }
  if (cmap->offset + cmap->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + cmap->offset;
  uint16_t version = vr_u16(p);
  if (version != VR_CMAP_TABLE_VERSION) {
    return VR_ERR_INVALID_FONT;
  }
  uint16_t numTables = vr_u16(p + 2);

  face->cmap_offset_count = numTables;
  face->cmap_offsets = NULL;
  if (numTables > 0u) {
    face->cmap_offsets = (uint32_t*)vr_face_alloc_array(face, numTables, sizeof(uint32_t), 4u);
  }
  if (numTables > 0u && !face->cmap_offsets) {
    return VR_ERR_OOM;
  }

  uint32_t sel = vr_find_preferred_cmap_offset(face, p);
  if (sel == 0) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* sub = p + sel;
  uint16_t length = vr_u16(sub + 2);
  vr_zero(&face->cmap, sizeof(vr_cmap_table_t));
  if (length == 0u || sub + length > p + cmap->length) {
    return VR_ERR_INVALID_FONT;
  }

  uint16_t format = vr_u16(sub);

  switch (format) {
    case VR_CMAP_FORMAT_4: {
      return vr_parse_cmap_format4(face, sub, length);
    }
    case VR_CMAP_FORMAT_12: {
      return vr_parse_cmap_format12(face, sub, length);
    }
    case VR_CMAP_FORMAT_0:
      return VR_ERR_UNSUPPORTED;
    default:
      return VR_ERR_UNSUPPORTED;
  }
}

//@optimizer-ignore-function kern parsing must allocate and decode each legacy kerning pair from font tables
vr_status_t vr_parse_kern(vr_font_face_t* face) {
  const vr_table_record_t* kern = vr_find_table(face, VR_TABLE_TAG('k','e','r','n'));
  if (!kern) {
    return VR_ERR_NOT_FOUND;
  }
  if (kern->offset + kern->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + kern->offset;
  uint16_t version = vr_u16(p);
  uint16_t n_tables = vr_u16(p + 2);
  (void)version;

  const uint8_t* tables = p + 4;
  for (uint16_t i = 0; i < n_tables; ++i) {
    const uint8_t* sub = tables + i * 8;
    if ((size_t)(sub - p) + 8 > kern->length) {
      return VR_ERR_INVALID_FONT;
    }

    uint16_t sub_version = vr_u16(sub);
    uint16_t sub_len = vr_u16(sub + 2);
    uint16_t coverage = vr_u16(sub + 4);
    (void)vr_u16(sub + 6);

    if (sub_version != 0) {
      continue;
    }
    if (sub_len < 12) {
      continue;
    }
    if (sub + sub_len > p + kern->length) {
      continue;
    }

    uint16_t coverage_type = coverage & 0xFF;
    if (coverage_type != 0) {
      continue;
    }

    uint16_t n_pairs = vr_u16(sub + 8);
    const uint8_t* q = sub + 12;
    size_t needed = (size_t)n_pairs * 6 + 12;
    if (sub + needed > p + kern->length || needed > sub_len) {
      return VR_ERR_INVALID_FONT;
    }

    if (n_pairs == 0) {
      continue;
    }

    size_t new_cap = face->kern.count + n_pairs;
    vr_kern_pair_t* pairs = (vr_kern_pair_t*)vr_face_realloc_array(face, face->kern.pairs, face->kern.cap, new_cap, sizeof(vr_kern_pair_t), 8u);
    if (!pairs && n_pairs > 0) {
      return VR_ERR_OOM;
    }
    face->kern.pairs = pairs;
    face->kern.cap = new_cap;
    for (uint16_t j = 0; j < n_pairs; ++j) {
      uint16_t left = vr_u16(q + j * 6);
      uint16_t right = vr_u16(q + j * 6 + 2);
      int16_t adjust = vr_i16(q + j * 6 + 4);
      face->kern.pairs[face->kern.count + j].left = left;
      face->kern.pairs[face->kern.count + j].right = right;
      face->kern.pairs[face->kern.count + j].adjust = (float)adjust;
    }
    face->kern.count = new_cap;
  }

  return VR_OK;
}

//@optimizer-ignore-function axis mapping must scan each fvar axis and normalize against min/default/max
float vr_map_axis_value(const vr_font_face_t* face, const char* tag, float user_value, float* out_norm) {
  *out_norm = 0.0f;
  for (uint16_t i = 0; i < face->fvar.axis_count; ++i) {
    if (vr_tag_compare(face->fvar.descriptors[i].tag, tag) == 0) {
      float clamped = user_value;
      if (clamped < face->fvar.descriptors[i].min) clamped = face->fvar.descriptors[i].min;
      if (clamped > face->fvar.descriptors[i].max) clamped = face->fvar.descriptors[i].max;
      float dmin = face->fvar.descriptors[i].min;
      float dfl = face->fvar.descriptors[i].default_value;
      float dmax = face->fvar.descriptors[i].max;
      if (clamped >= dfl) {
        float denom = (dmax - dfl);
        *out_norm = (denom != 0.0f) ? ((clamped - dfl) / denom) : 0.0f;
      } else {
        float denom = (dfl - dmin);
        *out_norm = (denom != 0.0f) ? -((dfl - clamped) / denom) : 0.0f;
      }
      if (*out_norm > 1.0f) *out_norm = 1.0f;
      if (*out_norm < -1.0f) *out_norm = -1.0f;
      return clamped;
    }
  }
  return user_value;
}

float vr_find_kern_adjust(const vr_font_face_t* face, uint16_t left, uint16_t right) {
  for (size_t i = 0; i < face->kern.count; ++i) {
    if (face->kern.pairs[i].left == left && face->kern.pairs[i].right == right) {
      return face->kern.pairs[i].adjust;
    }
  }
  return 0.0f;
}

vr_status_t vr_parse_font(vr_font_face_t* face) {
  vr_status_t st = vr_parse_table_directory(face);
  if (st != VR_OK) return st;

  const vr_table_record_t* head = vr_find_table(face, VR_TABLE_TAG('h','e','a','d'));
  if (!head || head->offset + head->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_head(face, face->file_data + head->offset, head->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* maxp = vr_find_table(face, VR_TABLE_TAG('m','a','x','p'));
  if (!maxp || maxp->offset + maxp->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_maxp(face, face->file_data + maxp->offset, maxp->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* hhea = vr_find_table(face, VR_TABLE_TAG('h','h','e','a'));
  if (!hhea || hhea->offset + hhea->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_hhea(face, face->file_data + hhea->offset, hhea->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* hmtx = vr_find_table(face, VR_TABLE_TAG('h','m','t','x'));
  if (!hmtx || hmtx->offset + hmtx->length > face->file_size) {
    return VR_ERR_NOT_FOUND;
  }
  face->hmtx = (uint8_t*)face->file_data + hmtx->offset;

  const vr_table_record_t* glyf = vr_find_table(face, VR_TABLE_TAG('g','l','y','f'));
  if (!glyf || glyf->offset + glyf->length > face->file_size) return VR_ERR_INVALID_FONT;
  face->glyf = (uint8_t*)face->file_data + glyf->offset;

  st = vr_parse_loca(face);
  if (st != VR_OK) return st;

  st = vr_parse_cmap(face);
  if (st != VR_OK) return st;

  st = vr_parse_kern(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND && st != VR_ERR_UNSUPPORTED) return st;

  st = vr_read_fvar(face);
  if (st != VR_OK) return st;
  st = vr_parse_avar(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND) return st;
  st = vr_parse_gvar(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND) return st;

  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    face->axis_values[i] = vr_apply_avar_mapping(face, i, 0.0f);
  }

  if (face->cfg.px_size <= 0.0f) {
    face->cfg.px_size = VR_FONT_PARSER_DEFAULT_PX_SIZE;
  }

  if (face->cfg.atlas_width == 0) {
    face->cfg.atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  }
  if (face->cfg.atlas_height == 0) {
    face->cfg.atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  }
  if (face->cfg.atlas_pad == 0) {
    face->cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  }
  if (face->cfg.atlas_format == VR_FONT_ATLAS_FORMAT_UNSPECIFIED) {
    face->cfg.atlas_format = VR_FONT_DEFAULT_ATLAS_FORMAT;
  }

  return VR_OK;
}

//@optimizer-ignore-function cmap lookup must scan encoded format 4 or 12 ranges and apply table offsets
uint16_t vr_find_glyph_id(vr_font_face_t* face, uint32_t codepoint) {
  if (!face || !face->cmap.format) return 0;
  switch (face->cmap.format) {
    case VR_CMAP_FORMAT_4: {
      uint16_t seg_count = face->cmap.u.format4.seg_count_x2 / 2u;
      for (uint16_t i = 0; i < seg_count; ++i) {
        uint16_t end_code = face->cmap.u.format4.end_code[i];
        uint16_t start_code = face->cmap.u.format4.start_code[i];
        if (codepoint < start_code || codepoint > end_code) continue;
        int16_t delta = face->cmap.u.format4.id_delta[i];
        uint16_t range_offset = face->cmap.u.format4.id_range_offset[i];
        if (range_offset == 0u) {
          return (uint16_t)(codepoint + delta);
        }

        size_t idx = (size_t)(range_offset / 2u) + (size_t)(codepoint - start_code) - (size_t)(seg_count - i);
        if (idx < face->cmap.u.format4.glyph_id_array_count) {
          uint16_t g = face->cmap.u.format4.glyph_id_array[idx];
          if (g == 0u) return 0u;
          return (uint16_t)(g + delta);
        }
        return 0u;
      }
      return 0u;
    }
    case VR_CMAP_FORMAT_12:
      for (uint32_t i = 0; i < face->cmap.u.format12.n_groups; ++i) {
        uint32_t s = face->cmap.u.format12.start_char_code[i];
        uint32_t e = face->cmap.u.format12.end_char_code[i];
        if (codepoint < s || codepoint > e) continue;
        uint32_t g = face->cmap.u.format12.start_glyph_id[i] + (codepoint - s);
        return (uint16_t)(g & 0xFFFFu);
      }
      return 0u;
    default:
      return 0u;
  }
}

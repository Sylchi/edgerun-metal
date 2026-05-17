#include "test_common.h"

#include "vr_font_internal.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define VR_UTILS_CMAP_VERSION 0u
#define VR_UTILS_CMAP_TABLE_OFFSET 12u
#define VR_UTILS_CMAP_HEADER_SIZE 12u
#define VR_UTILS_CMAP_PLATFORM_OFFSET_ENTRY 4u
#define VR_UTILS_CMAP_ENCODING_OFFSET_ENTRY 6u
#define VR_UTILS_CMAP_RECORD_OFFSET 8u
#define VR_UTILS_CMAP_FORMAT_ID_0 0u
#define VR_UTILS_CMAP_FORMAT_ID_4 4u
#define VR_UTILS_CMAP_FORMAT_ID_12 12u
#define VR_UTILS_CMAP_PLATFORM_WINDOWS 3u
#define VR_UTILS_CMAP_PLATFORM_UNICODE 0u
#define VR_UTILS_CMAP_PLATFORM_NON_PREFERRED 1u
#define VR_UTILS_CMAP_ENCODING_UNICODE 0u
#define VR_UTILS_CMAP_SEGMENT_COUNT_X2 2u
#define VR_UTILS_CMAP_SEGMENT_COUNT 1u
#define VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN 24u
#define VR_UTILS_CMAP_TABLE_WITH_ZERO_GROUPS_LEN 12u
#define VR_UTILS_CMAP_FORMAT12_TABLE_LEN 32u
#define VR_UTILS_CMAP_FORMAT12_INVALID_LEN 16u
#define VR_UTILS_CMAP_MIN_CMAP_SUBTABLE_LEN 8u
#define VR_UTILS_CMAP_FORMAT12_GROUP_COUNT 100u
#define VR_UTILS_CMAP_UNKNOWN_VERSION 1u
#define VR_UTILS_CMAP_GLYPH_DELTA_OFFSET 2u
#define VR_UTILS_CMAP_SEARCH_RANGE 2u
#define VR_UTILS_CMAP_ENTRY_SELECTOR 1u
#define VR_UTILS_CMAP_CODEPOINT_A 0x004Au
#define VR_UTILS_CMAP_CODEPOINT_B 0x004Bu
#define VR_UTILS_CMAP_CODEPOINT_MISSING 0x00FFu
#define VR_UTILS_CMAP_CODEPOINT_64 0x0040u
#define VR_UTILS_CMAP_FORMAT12_CODEPOINT_START 65u
#define VR_UTILS_CMAP_FORMAT12_CODEPOINT_END 66u
#define VR_UTILS_CMAP_FORMAT12_GLYPH_START 7u
#define VR_UTILS_CMAP_FORMAT12_GLYPH_SECOND 8u
#define VR_UTILS_CMAP_FORMAT12_GLYPH_BASE VR_UTILS_CMAP_FORMAT12_GLYPH_START
#define VR_UTILS_GLYPH_NOT_FOUND 0u
#define VR_UTILS_CMAP_ONE_TABLE 1u
#define VR_UTILS_ZERO_COUNT 0u
#define VR_UTILS_FONT_TAG_CMAP VR_TABLE_TAG('c', 'm', 'a', 'p')
#define VR_UTILS_CMAP_FORMAT_12_N_GROUPS 1u
#define VR_UTILS_CMAP_FORMAT_4_SEGMENT_X2_TOO_LARGE 20u
#define VR_UTILS_CMAP_FORMAT4_ID_DELTA_NONE 0
#define VR_UTILS_CMAP_FORMAT4_ID_DELTA_SUCCESS 1
#define VR_UTILS_CMAP_UNKNOWN_FORMAT_ID 99u
#define VR_UTILS_TEST_GLYPH_ID_MAPPED 0x005Au
#define VR_UTILS_TEST_CODEPOINT_42 42u

static void set_u16_be(uint8_t* out, size_t offset, uint16_t value) {
  out[offset] = (uint8_t)(value >> 8u);
  out[offset + 1u] = (uint8_t)value;
}

static void set_u32_be(uint8_t* out, size_t offset, uint32_t value) {
  out[offset] = (uint8_t)(value >> 24u);
  out[offset + 1u] = (uint8_t)(value >> 16u);
  out[offset + 2u] = (uint8_t)(value >> 8u);
  out[offset + 3u] = (uint8_t)value;
}

static void test_free_cmap_payload(vr_font_face_t* face, uint8_t* storage) {
  if (!face) return;

  if (face->cmap.format == VR_UTILS_CMAP_FORMAT_ID_4) {
    free(face->cmap.u.format4.end_code);
    free(face->cmap.u.format4.start_code);
    free(face->cmap.u.format4.id_delta);
    free(face->cmap.u.format4.id_range_offset);
    free(face->cmap.u.format4.glyph_id_array);
    face->cmap.u.format4.end_code = NULL;
    face->cmap.u.format4.start_code = NULL;
    face->cmap.u.format4.id_delta = NULL;
    face->cmap.u.format4.id_range_offset = NULL;
    face->cmap.u.format4.glyph_id_array = NULL;
    face->cmap.u.format4.glyph_id_array_count = VR_UTILS_ZERO_COUNT;
  } else if (face->cmap.format == VR_UTILS_CMAP_FORMAT_ID_12) {
    free(face->cmap.u.format12.start_char_code);
    free(face->cmap.u.format12.end_char_code);
    free(face->cmap.u.format12.start_glyph_id);
    face->cmap.u.format12.start_char_code = NULL;
    face->cmap.u.format12.end_char_code = NULL;
    face->cmap.u.format12.start_glyph_id = NULL;
    face->cmap.u.format12.n_groups = VR_UTILS_ZERO_COUNT;
  }
  memset(&face->cmap, 0, sizeof(vr_cmap_table_t));

  free(face->cmap_offsets);
  face->cmap_offsets = NULL;
  face->cmap_offset_count = VR_UTILS_ZERO_COUNT;
  free(storage);
  free(face->tables);
  face->tables = NULL;
  face->table_count = VR_UTILS_ZERO_COUNT;
  face->file_data = NULL;
  face->file_size = VR_UTILS_ZERO_COUNT;
}

static void test_build_format4_single_segment_subtable(
  uint8_t* subtable,
  int16_t id_delta,
  uint16_t id_range_offset) {
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_4);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN);
  set_u16_be(subtable, 6u, VR_UTILS_CMAP_SEGMENT_COUNT_X2);
  set_u16_be(subtable, 8u, VR_UTILS_CMAP_SEARCH_RANGE);
  set_u16_be(subtable, 10u, VR_UTILS_CMAP_ENTRY_SELECTOR);
  set_u16_be(subtable, 12u, VR_UTILS_ZERO_COUNT);
  set_u16_be(subtable, 14u, VR_UTILS_CMAP_CODEPOINT_A);
  set_u16_be(subtable, 18u, VR_UTILS_CMAP_CODEPOINT_A);
  set_u16_be(subtable, 20u, (uint16_t)id_delta);
  set_u16_be(subtable, 22u, id_range_offset);
}

static void test_attach_allocator(vr_font_face_t* face) {
  vr_font_config_t cfg = test_default_font_config();
  face->allocator = cfg.allocator;
  vr_allocator_scope_enter(face);
}

static vr_status_t test_build_face_with_single_cmap(
  const uint8_t* subtable,
  size_t sub_len,
  uint16_t platform_id,
  uint16_t encoding_id,
  vr_font_face_t* out_face,
  uint8_t** out_storage) {
  if (!subtable || sub_len == VR_UTILS_ZERO_COUNT || !out_face || !out_storage) return VR_ERR_INVALID_FONT;

  size_t cmap_body = (size_t)VR_UTILS_CMAP_HEADER_SIZE + sub_len;
  size_t total = (size_t)VR_UTILS_CMAP_TABLE_OFFSET + cmap_body;
  uint8_t* data = (uint8_t*)calloc(total, 1u);
  if (!data) return VR_ERR_OOM;

  uint8_t* cmap = data + VR_UTILS_CMAP_TABLE_OFFSET;
  set_u16_be(cmap, 0u, VR_UTILS_CMAP_VERSION);
  set_u16_be(cmap, 2u, VR_UTILS_CMAP_ONE_TABLE);
  set_u16_be(cmap, VR_UTILS_CMAP_PLATFORM_OFFSET_ENTRY, platform_id);
  set_u16_be(cmap, VR_UTILS_CMAP_ENCODING_OFFSET_ENTRY, encoding_id);
  set_u32_be(cmap, VR_UTILS_CMAP_RECORD_OFFSET, VR_UTILS_CMAP_HEADER_SIZE);

  memcpy(cmap + VR_UTILS_CMAP_HEADER_SIZE, subtable, sub_len);

  vr_table_record_t* tables = (vr_table_record_t*)malloc(sizeof(vr_table_record_t));
  if (!tables) {
    free(data);
    return VR_ERR_OOM;
  }
  tables[0].tag = VR_UTILS_FONT_TAG_CMAP;
  tables[0].checksum = VR_UTILS_ZERO_COUNT;
  tables[0].offset = VR_UTILS_CMAP_TABLE_OFFSET;
  tables[0].length = (uint32_t)cmap_body;

  memset(out_face, 0, sizeof(vr_font_face_t));
  test_attach_allocator(out_face);
  out_face->tables = tables;
  out_face->table_count = VR_UTILS_CMAP_ONE_TABLE;
  out_face->file_data = data;
  out_face->file_size = total;
  *out_storage = data;
  return VR_OK;
}

static void test_glyph_lookup_format4_delta(void) {
  uint16_t end_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  uint16_t start_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  int16_t id_delta[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT4_ID_DELTA_NONE};
  uint16_t id_range_offset[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_ZERO_COUNT};

  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.cmap.format = VR_UTILS_CMAP_FORMAT_ID_4;
  face.cmap.length = VR_UTILS_ZERO_COUNT;
  face.cmap.language = VR_UTILS_ZERO_COUNT;
  face.cmap.u.format4.seg_count_x2 = VR_UTILS_CMAP_SEGMENT_COUNT_X2;
  face.cmap.u.format4.end_code = end_code;
  face.cmap.u.format4.start_code = start_code;
  face.cmap.u.format4.id_delta = id_delta;
  face.cmap.u.format4.id_range_offset = id_range_offset;
  face.cmap.u.format4.glyph_id_array_count = VR_UTILS_ZERO_COUNT;
  face.cmap.u.format4.glyph_id_array = NULL;

  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_A) == VR_UTILS_CMAP_CODEPOINT_A, "cmap: format4 with delta maps glyph");
  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_B) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: format4 with delta misses unknown codepoint");
}

static void test_glyph_lookup_format4_range_offset(void) {
  uint16_t end_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  uint16_t start_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  int16_t id_delta[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT4_ID_DELTA_NONE};
  uint16_t id_range_offset[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_GLYPH_DELTA_OFFSET};

  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.cmap.format = VR_UTILS_CMAP_FORMAT_ID_4;
  face.cmap.u.format4.seg_count_x2 = VR_UTILS_CMAP_SEGMENT_COUNT_X2;
  face.cmap.u.format4.end_code = end_code;
  face.cmap.u.format4.start_code = start_code;
  face.cmap.u.format4.id_delta = id_delta;
  face.cmap.u.format4.id_range_offset = id_range_offset;
  face.cmap.u.format4.glyph_id_array_count = VR_UTILS_CMAP_ONE_TABLE;
  uint16_t glyph_id_array[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_TEST_GLYPH_ID_MAPPED};
  face.cmap.u.format4.glyph_id_array = glyph_id_array;

  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_A) == VR_UTILS_TEST_GLYPH_ID_MAPPED, "cmap: format4 with range offset maps glyph id");
}

static void test_glyph_lookup_format4_missing_range_offset_entry(void) {
  uint16_t end_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  uint16_t start_code[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_CODEPOINT_A};
  int16_t id_delta[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT4_ID_DELTA_NONE};
  uint16_t id_range_offset[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_SEGMENT_COUNT_X2};

  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.cmap.format = VR_UTILS_CMAP_FORMAT_ID_4;
  face.cmap.u.format4.seg_count_x2 = VR_UTILS_CMAP_SEGMENT_COUNT_X2;
  face.cmap.u.format4.end_code = end_code;
  face.cmap.u.format4.start_code = start_code;
  face.cmap.u.format4.id_delta = id_delta;
  face.cmap.u.format4.id_range_offset = id_range_offset;
  face.cmap.u.format4.glyph_id_array_count = VR_UTILS_ZERO_COUNT;
  face.cmap.u.format4.glyph_id_array = NULL;

  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_A) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: format4 missing glyph array index returns zero");
}

static void test_glyph_lookup_format12(void) {
  uint32_t starts[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT12_CODEPOINT_START};
  uint32_t ends[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT12_CODEPOINT_END};
  uint32_t start_glyphs[VR_UTILS_CMAP_SEGMENT_COUNT] = {VR_UTILS_CMAP_FORMAT12_GLYPH_BASE};

  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.cmap.format = VR_UTILS_CMAP_FORMAT_ID_12;
  face.cmap.language = VR_UTILS_ZERO_COUNT;
  face.cmap.u.format12.n_groups = VR_UTILS_CMAP_ONE_TABLE;
  face.cmap.u.format12.start_char_code = starts;
  face.cmap.u.format12.end_char_code = ends;
  face.cmap.u.format12.start_glyph_id = start_glyphs;

  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_FORMAT12_CODEPOINT_START) == VR_UTILS_CMAP_FORMAT12_GLYPH_START, "cmap: format12 lookup maps within range");
  test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_MISSING) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: format12 lookup misses outside range");
}

static void test_glyph_lookup_other_cases(void) {
  vr_font_face_t null_face = {0};
  test_expect(vr_find_glyph_id(&null_face, VR_UTILS_TEST_CODEPOINT_42) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: missing cmap returns zero");

  vr_font_face_t unsupported = {0};
  unsupported.cmap.format = VR_UTILS_CMAP_UNKNOWN_FORMAT_ID;
  test_expect(vr_find_glyph_id(&unsupported, VR_UTILS_TEST_CODEPOINT_42) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: unknown format returns zero");
}

static void test_parse_cmap_unsupported_format(void) {
  uint8_t subtable[VR_UTILS_CMAP_MIN_CMAP_SUBTABLE_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_0);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_MIN_CMAP_SUBTABLE_LEN);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_UNICODE,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  test_expect_status(st, VR_OK, "cmap: helper builds format0 table");
  if (st == VR_OK) {
    st = vr_parse_cmap(&face);
    test_expect_status(st, VR_ERR_UNSUPPORTED, "cmap: format 0 parsing is unsupported");
  }
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_format4_rejects_too_small_header(void) {
  uint8_t subtable[VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_4);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN);
  set_u16_be(subtable, 6u, VR_UTILS_CMAP_FORMAT_4_SEGMENT_X2_TOO_LARGE);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds malformed format4 table");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: format4 rejects segment header larger than table length");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_rejects_subtable_length_outside_parent_table(void) {
  uint8_t subtable[VR_UTILS_CMAP_TABLE_WITH_ZERO_GROUPS_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_12);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_FORMAT12_GROUP_COUNT);
  set_u16_be(subtable, 4u, VR_UTILS_CMAP_PLATFORM_WINDOWS);
  set_u16_be(subtable, 6u, VR_UTILS_CMAP_ENCODING_UNICODE);
  set_u32_be(subtable, 8u, VR_UTILS_CMAP_TABLE_OFFSET);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds too-small header table");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: subtable length outside cmap table range rejected");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_rejects_zero_subtable_length(void) {
  uint8_t subtable[VR_UTILS_CMAP_TABLE_WITH_ZERO_GROUPS_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_12);
  set_u16_be(subtable, 2u, VR_UTILS_ZERO_COUNT);
  set_u16_be(subtable, 4u, VR_UTILS_CMAP_PLATFORM_WINDOWS);
  set_u16_be(subtable, 6u, VR_UTILS_CMAP_ENCODING_UNICODE);
  set_u32_be(subtable, 8u, VR_UTILS_CMAP_TABLE_OFFSET);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds zero-length subtable");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: zero subtable length is rejected");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_unknown_version(void) {
  uint8_t subtable[VR_UTILS_CMAP_MIN_CMAP_SUBTABLE_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_12);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_MIN_CMAP_SUBTABLE_LEN);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds table for version check");
    return;
  }

  set_u16_be(storage, 0u, VR_UTILS_CMAP_UNKNOWN_VERSION);
  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: invalid table version is rejected");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_missing_table(void) {
  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.file_data = (uint8_t*)calloc(VR_UTILS_CMAP_ONE_TABLE, 1u);
  face.file_size = VR_UTILS_CMAP_ONE_TABLE;
  uint8_t* storage = face.file_data;
  vr_status_t st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_NOT_FOUND, "cmap: missing table entry returns not found");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_no_offsets_selected(void) {
  size_t data_size = VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN;
  uint8_t* storage = (uint8_t*)calloc(data_size, 1u);
  if (!storage) {
    test_expect_status(VR_ERR_OOM, VR_OK, "cmap: allocates no-offset table fixture");
    return;
  }

  vr_table_record_t* tables = (vr_table_record_t*)malloc(sizeof(vr_table_record_t));
  if (!tables) {
    free(storage);
    test_expect_status(VR_ERR_OOM, VR_OK, "cmap: allocates table record for no-offset fixture");
    return;
  }
  tables[0].tag = VR_UTILS_FONT_TAG_CMAP;
  tables[0].checksum = VR_UTILS_ZERO_COUNT;
  tables[0].offset = VR_UTILS_CMAP_TABLE_OFFSET;
  tables[0].length = VR_UTILS_CMAP_TABLE_OFFSET;

  vr_font_face_t face = {0};
  test_attach_allocator(&face);
  face.tables = tables;
  face.table_count = VR_UTILS_CMAP_ONE_TABLE;
  face.file_data = storage;
  face.file_size = data_size;

  set_u16_be(storage + VR_UTILS_CMAP_TABLE_OFFSET, 0u, VR_UTILS_CMAP_VERSION);
  set_u16_be(storage + VR_UTILS_CMAP_TABLE_OFFSET + 2u, 0u, VR_UTILS_ZERO_COUNT);

  vr_status_t st = vr_parse_cmap(&face);
  test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: selects no offset when directory is empty");
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_format12_happy_path(void) {
  uint8_t subtable[VR_UTILS_CMAP_FORMAT12_TABLE_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_12);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_FORMAT12_TABLE_LEN);
  set_u16_be(subtable, 4u, VR_UTILS_ZERO_COUNT);
  set_u32_be(subtable, 12u, VR_UTILS_CMAP_FORMAT_12_N_GROUPS);
  set_u32_be(subtable, 16u, VR_UTILS_CMAP_FORMAT12_CODEPOINT_START);
  set_u32_be(subtable, 20u, VR_UTILS_CMAP_FORMAT12_CODEPOINT_END);
  set_u32_be(subtable, 24u, VR_UTILS_CMAP_FORMAT12_GLYPH_START);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds format12 table");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_OK, "cmap: format12 parsing succeeds");
  if (st == VR_OK) {
    test_expect(face.cmap.format == VR_UTILS_CMAP_FORMAT_ID_12, "cmap: parsed format is 12");
    test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_FORMAT12_CODEPOINT_START) == VR_UTILS_CMAP_FORMAT12_GLYPH_START, "cmap: parsed format12 maps first codepoint");
    test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_FORMAT12_CODEPOINT_END) == VR_UTILS_CMAP_FORMAT12_GLYPH_SECOND, "cmap: parsed format12 maps second codepoint");
    test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_64) == VR_UTILS_GLYPH_NOT_FOUND, "cmap: parsed format12 misses below range");
  }
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_format4_happy_path(void) {
  uint8_t subtable[VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN] = {0};
  test_build_format4_single_segment_subtable(subtable, VR_UTILS_CMAP_FORMAT4_ID_DELTA_SUCCESS, VR_UTILS_ZERO_COUNT);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds format4 table");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_OK, "cmap: format4 parsing succeeds");
  if (st == VR_OK) {
    test_expect(face.cmap.format == VR_UTILS_CMAP_FORMAT_ID_4, "cmap: parsed format is 4");
    test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_A) == VR_UTILS_CMAP_CODEPOINT_B, "cmap: parsed format4 maps codepoint by delta");
  }
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_non_preferred_platform_is_fallback(void) {
  uint8_t subtable[VR_UTILS_CMAP_TABLE_WITH_ONE_SEGMENT_LEN] = {0};
  test_build_format4_single_segment_subtable(subtable, VR_UTILS_CMAP_FORMAT4_ID_DELTA_SUCCESS, VR_UTILS_ZERO_COUNT);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_NON_PREFERRED,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "cmap: helper builds non-preferred table");
    return;
  }

  st = vr_parse_cmap(&face);
  test_expect_status(st, VR_OK, "cmap: non-preferred platform still parsed via fallback");
  if (st == VR_OK) {
    test_expect(vr_find_glyph_id(&face, VR_UTILS_CMAP_CODEPOINT_A) == VR_UTILS_CMAP_CODEPOINT_B, "cmap: fallback-selected table is used");
  }
  test_free_cmap_payload(&face, storage);
}

static void test_parse_cmap_invalid_offset_rejected(void) {
  uint8_t subtable[VR_UTILS_CMAP_FORMAT12_INVALID_LEN] = {VR_UTILS_ZERO_COUNT};
  set_u16_be(subtable, 0u, VR_UTILS_CMAP_FORMAT_ID_12);
  set_u16_be(subtable, 2u, VR_UTILS_CMAP_FORMAT12_INVALID_LEN);
  set_u16_be(subtable, 4u, 0u);
  set_u32_be(subtable, 12u, VR_UTILS_CMAP_ONE_TABLE);

  uint8_t* storage = NULL;
  vr_font_face_t face;
  vr_status_t st = test_build_face_with_single_cmap(
    subtable,
    sizeof(subtable),
    VR_UTILS_CMAP_PLATFORM_WINDOWS,
    VR_UTILS_CMAP_ENCODING_UNICODE,
    &face,
    &storage);
  test_expect_status(st, VR_OK, "cmap: helper builds truncated format12 table");
  if (st == VR_OK) {
    st = vr_parse_cmap(&face);
    test_expect_status(st, VR_ERR_INVALID_FONT, "cmap: malformed format12 length is rejected");
  }
  test_free_cmap_payload(&face, storage);
}

void run_cmap_tests(void) {
  test_glyph_lookup_format4_delta();
  test_glyph_lookup_format4_range_offset();
  test_glyph_lookup_format4_missing_range_offset_entry();
  test_glyph_lookup_format12();
  test_glyph_lookup_other_cases();
  test_parse_cmap_missing_table();
  test_parse_cmap_no_offsets_selected();
  test_parse_cmap_rejects_subtable_length_outside_parent_table();
  test_parse_cmap_rejects_zero_subtable_length();
  test_parse_cmap_unsupported_format();
  test_parse_cmap_format4_rejects_too_small_header();
  test_parse_cmap_unknown_version();
  test_parse_cmap_format4_happy_path();
  test_parse_cmap_format12_happy_path();
  test_parse_cmap_invalid_offset_rejected();
  test_parse_cmap_non_preferred_platform_is_fallback();
}

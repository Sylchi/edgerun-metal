#ifndef ER_UI_RUNTIME_INTERNAL_H
#define ER_UI_RUNTIME_INTERNAL_H

#include "er_ui_runtime.h"
#include "er_ui_internal.h"
#include "er_math.h"

static const size_t ER_UI_TEXT_INITIAL_CAPACITY = 32u;
static const size_t ER_UI_RUNTIME_INITIAL_CAPACITY = 8u;
static const float ER_UI_DRAG_START_THRESHOLD_PX = 5.0f;
static const float ER_UI_WHEEL_SCROLL_SCALE = 900.0f;
static const float ER_UI_KEY_SLIDER_STEP = 0.05f;
static const uint32_t ER_UI_CODEPOINT_C0_LAST = 0x1Fu;
static const uint32_t ER_UI_CODEPOINT_ASCII_DELETE = 0x7Fu;
static const uint32_t ER_UI_CODEPOINT_C1_FIRST = 0x80u;
static const uint32_t ER_UI_CODEPOINT_C1_LAST = 0x9Fu;

enum {
  ER_UI_UTF8_ASCII_MAX = 0x7Fu,
  ER_UI_UTF8_CONT_MASK = 0xC0u,
  ER_UI_UTF8_CONT_TAG = 0x80u,
  ER_UI_UTF8_2_MIN = 0xC2u,
  ER_UI_UTF8_2_MAX = 0xDFu,
  ER_UI_UTF8_3_MIN = 0xE0u,
  ER_UI_UTF8_3_MAX = 0xEFu,
  ER_UI_UTF8_SURROGATE_MIN = 0xEDu,
  ER_UI_UTF8_4_MIN = 0xF0u,
  ER_UI_UTF8_4_MAX = 0xF4u,
  ER_UI_UTF8_E0_CONT_MIN = 0xA0u,
  ER_UI_UTF8_F0_CONT_MIN = 0x90u,
  ER_UI_UTF8_F4_CONT_MAX = 0x8Fu,
  ER_UI_UTF8_2_BYTES = 2u,
  ER_UI_UTF8_3_BYTES = 3u,
  ER_UI_UTF8_4_BYTES = 4u,
  ER_UI_UTF8_2_PAYLOAD_MASK = 0x1Fu,
  ER_UI_UTF8_3_PAYLOAD_MASK = 0x0Fu,
  ER_UI_UTF8_4_PAYLOAD_MASK = 0x07u,
  ER_UI_UTF8_CONT_PAYLOAD_MASK = 0x3Fu,
  ER_UI_UTF8_CONT_SHIFT = 6u,
  ER_UI_UTF8_3_LEAD_SHIFT = 12u,
  ER_UI_UTF8_4_LEAD_SHIFT = 18u
};

enum { ER_UI_RUNTIME_RESERVE_GROWTH_FACTOR = 4u };

typedef struct {
  uint32_t codepoint;
  size_t byte_len;
} er_ui_utf8_char_t;

size_t er_ui_cstr_len(const char* text);
bool er_ui_runtime_reserve(er_ui_allocator_t allocator, void** data, size_t* capacity, size_t count, size_t item_size);
float er_ui_runtime_clamp_float(float value, float min_value, float max_value);
void er_ui_runtime_begin_drag(er_ui_runtime_state_t* state,
                              er_ui_drag_source_t source,
                              float x,
                              float y);
er_ui_status_t er_ui_set_pair_f32(
  er_ui_allocator_t allocator,
  er_ui_pair_f32_t** values,
  size_t* count,
  size_t* capacity,
  uint32_t id,
  float value);
er_ui_status_t er_ui_set_pair_bool(
  er_ui_allocator_t allocator,
  er_ui_pair_bool_t** values,
  size_t* count,
  size_t* capacity,
  uint32_t id,
  bool value);
er_ui_status_t er_ui_strdup_validated(er_ui_allocator_t allocator, const char* value, char** out_value);
bool er_ui_utf8_decode_one(const char* text, size_t available, er_ui_utf8_char_t* out_char);
bool er_ui_utf8_validate_and_count(const char* text, size_t* out_byte_len, size_t* out_char_count);

#endif

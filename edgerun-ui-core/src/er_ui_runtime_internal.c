#include "er_ui_runtime_internal.h"

size_t er_ui_cstr_len(const char* text) {
  size_t len = 0u;
  if (!text) return 0u;
  const char* cursor = text;
  while (*cursor != '\0') {
    len++;
    cursor++;
  }
  return len;
}

bool er_ui_runtime_reserve(er_ui_allocator_t allocator, void** data, size_t* capacity, size_t count, size_t item_size) {
  return er_ui_allocator_reserve(allocator, data, capacity, count, item_size, ER_UI_RUNTIME_INITIAL_CAPACITY, ER_UI_RUNTIME_RESERVE_GROWTH_FACTOR);
}

float er_ui_runtime_clamp_float(float value, float min_value, float max_value) {
  return er_math_clampf(value, min_value, max_value);
}

er_ui_status_t er_ui_set_pair_f32(er_ui_allocator_t allocator, er_ui_pair_f32_t** values, size_t* count, size_t* capacity, uint32_t id, float value) {
  if (!values || !count || !capacity) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < *count; ++i) {
    if ((*values)[i].id == id) {
      (*values)[i].value = value;
      return ER_UI_OK;
    }
  }
  if (!er_ui_runtime_reserve(allocator, (void**)values, capacity, *count, sizeof(**values))) return ER_UI_ERR_OOM;
  (*values)[*count].id = id;
  (*values)[*count].value = value;
  (*count)++;
  return ER_UI_OK;
}

er_ui_status_t er_ui_set_pair_bool(er_ui_allocator_t allocator, er_ui_pair_bool_t** values, size_t* count, size_t* capacity, uint32_t id, bool value) {
  if (!values || !count || !capacity) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < *count; ++i) {
    if ((*values)[i].id == id) {
      (*values)[i].value = value;
      return ER_UI_OK;
    }
  }
  if (!er_ui_runtime_reserve(allocator, (void**)values, capacity, *count, sizeof(**values))) return ER_UI_ERR_OOM;
  (*values)[*count].id = id;
  (*values)[*count].value = value;
  (*count)++;
  return ER_UI_OK;
}

er_ui_status_t er_ui_strdup_validated(er_ui_allocator_t allocator, const char* value, char** out_value) {
  if (!value || !out_value) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_allocator_is_valid(allocator)) return ER_UI_ERR_OOM;
  size_t byte_len = 0u;
  size_t char_count = 0u;
  if (!er_ui_utf8_validate_and_count(value, &byte_len, &char_count)) return ER_UI_ERR_INVALID_ARGUMENT;
  (void)char_count;
  char* copy = (char*)allocator.alloc(allocator.user, byte_len + 1u, 1u);
  if (!copy) return ER_UI_ERR_OOM;
  er_ui_mem_copy(copy, value, byte_len + 1u);
  *out_value = copy;
  return ER_UI_OK;
}

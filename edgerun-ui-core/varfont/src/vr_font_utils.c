#include "vr_font_utils_internal.h"

void* vr_face_alloc_array(vr_font_face_t* face, size_t count, size_t item_size, size_t align) {
  return vr_calloc(face, count, item_size, align);
}

void* vr_face_realloc_array(vr_font_face_t* face, void* ptr, size_t old_count, size_t new_count, size_t item_size, size_t align) {
  if (item_size != 0u && (old_count > ((size_t)-1) / item_size || new_count > ((size_t)-1) / item_size)) return NULL;
  return vr_realloc(face, ptr, old_count * item_size, new_count * item_size, align);
}

void vr_face_free_array(vr_font_face_t* face, void* ptr, size_t count, size_t item_size, size_t align) {
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

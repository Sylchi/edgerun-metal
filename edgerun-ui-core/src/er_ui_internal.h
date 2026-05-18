#ifndef ER_UI_INTERNAL_H
#define ER_UI_INTERNAL_H

/*
 * Purpose: share small freestanding helpers across UI-core implementation files.
 * Intention: keep byte movement and allocator policy explicit without depending on host libc.
 */

#include "er_ui_scene.h"

#include <stdbool.h>
#include <stddef.h>

static inline void er_ui_mem_zero(void* ptr, size_t size) {
  unsigned char* bytes = (unsigned char*)ptr;
  if (!bytes) return;
  for (size_t i = 0u; i < size; ++i) bytes[i] = 0u;
}

static inline void er_ui_mem_copy(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  if (!out || !in) return;
  for (size_t i = 0u; i < size; ++i) out[i] = in[i];
}

static inline void er_ui_mem_move(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  if (!out || !in || out == in || size == 0u) return;
  if (out < in) {
    for (size_t i = 0u; i < size; ++i) out[i] = in[i];
  } else {
    for (size_t i = size; i > 0u; --i) out[i - 1u] = in[i - 1u];
  }
}

static inline bool er_ui_allocator_is_valid(er_ui_allocator_t allocator) {
  return allocator.alloc != 0 && allocator.free != 0;
}

static inline void er_ui_allocator_free(er_ui_allocator_t allocator, void* ptr, size_t size, size_t align) {
  if (ptr && er_ui_allocator_is_valid(allocator)) allocator.free(allocator.user, ptr, size, align);
}

//@optimizer-ignore-function allocator reserve grows capacity geometrically with overflow checks
static inline bool er_ui_allocator_reserve(er_ui_allocator_t allocator, void** data, size_t* capacity, size_t count, size_t item_size,
                                           size_t initial_capacity, size_t align) {
  if (!data || !capacity) return false;
  if (count < *capacity) return true;
  if (!er_ui_allocator_is_valid(allocator)) return false;

  size_t next_capacity = *capacity == 0u ? initial_capacity : *capacity;
  if (next_capacity == 0u) return false;
  while (next_capacity <= count) {
    if (next_capacity > ((size_t)-1) / 2u) return false;
    next_capacity *= 2u;
  }
  if (item_size != 0u && *capacity > ((size_t)-1) / item_size) return false;
  if (item_size != 0u && next_capacity > ((size_t)-1) / item_size) return false;

  size_t old_size = *capacity * item_size;
  size_t next_size = next_capacity * item_size;
  void* next = allocator.alloc(allocator.user, next_size, align);
  if (!next) return false;
  if (*data && old_size > 0u) er_ui_mem_copy(next, *data, old_size);
  er_ui_allocator_free(allocator, *data, old_size, align);
  *data = next;
  *capacity = next_capacity;
  return true;
}

#endif

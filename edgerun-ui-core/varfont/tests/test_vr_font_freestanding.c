#include "test_common.h"

#include <stddef.h>
#include <string.h>

enum {
  VR_FREESTANDING_BUFFER_SIZE = 8u,
  VR_FREESTANDING_MOVE_SIZE = 5u,
  VR_FREESTANDING_FILL_BYTE = 0x5a
};

void run_vr_font_freestanding_tests(void) {
  unsigned char bytes[VR_FREESTANDING_BUFFER_SIZE] = {0u};
  unsigned char source[VR_FREESTANDING_BUFFER_SIZE] = {1u, 2u, 3u, 4u, 5u, 6u, 7u, 8u};
  unsigned char expected_move[VR_FREESTANDING_BUFFER_SIZE] = {1u, 1u, 2u, 3u, 4u, 5u, 7u, 8u};

  void* (*memset_fn)(void*, int, size_t) = memset;
  void* (*memcpy_fn)(void*, const void*, size_t) = memcpy;
  void* (*memmove_fn)(void*, const void*, size_t) = memmove;
  int (*memcmp_fn)(const void*, const void*, size_t) = memcmp;

  test_expect(memset_fn(bytes, VR_FREESTANDING_FILL_BYTE, sizeof(bytes)) == bytes,
              "freestanding: memset returns destination");
  for (size_t i = 0u; i < sizeof(bytes); ++i) {
    test_expect(bytes[i] == (unsigned char)VR_FREESTANDING_FILL_BYTE,
                "freestanding: memset writes requested byte");
  }

  test_expect(memcpy_fn(bytes, source, sizeof(bytes)) == bytes,
              "freestanding: memcpy returns destination");
  test_expect(memcmp_fn(bytes, source, sizeof(bytes)) == 0,
              "freestanding: memcpy copies all bytes");

  test_expect(memmove_fn(bytes + 1u, bytes, VR_FREESTANDING_MOVE_SIZE) == bytes + 1u,
              "freestanding: memmove returns destination");
  test_expect(memcmp_fn(bytes, expected_move, sizeof(bytes)) == 0,
              "freestanding: memmove handles overlapping forward copy");

  test_expect(memcmp_fn(bytes, source, sizeof(bytes)) < 0,
              "freestanding: memcmp reports less-than ordering");
  test_expect(memcmp_fn(source, bytes, sizeof(bytes)) > 0,
              "freestanding: memcmp reports greater-than ordering");
}

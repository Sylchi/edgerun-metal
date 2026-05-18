#include <stdio.h>

#include "test_suites.h"

int main(void) {
  run_validation_tests();
  run_axis_tests();
  run_shape_tests();
  run_atlas_tests();
  run_cache_tests();
  run_api_tests();
  run_cmap_tests();
  run_raster_tests();
  run_vr_font_freestanding_tests();

  extern int g_tests_failed;
  extern int g_tests_total;

  if (g_tests_failed > 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_tests_failed, g_tests_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_tests_total);
  return 0;
}

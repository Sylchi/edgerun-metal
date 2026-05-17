#include "test_common.h"

#include <stdio.h>
#include <string.h>

static void test_axis_metadata(vr_font_face_t* face) {
  int axis_count = vr_font_axis_count(face);
  test_expect(axis_count > 0, "axes: font exposes axis count");

  const vr_font_axis_t* axes = vr_font_axes(face);
  test_expect(axes != NULL, "axes: axis table is queryable");

  if (axis_count > 0 && axes) {
    char name[5] = {0};
    memcpy(name, axes[0].name, 4);
    test_expect(strncmp(name, "", 1) != 0, "axes: first axis name is non-empty");

    test_expect(
      axes[0].value >= axes[0].min_value && axes[0].value <= axes[0].max_value,
      "axes: default value is inside axis range");

    float new_value = axes[0].min_value;
    if (new_value == axes[0].max_value) {
      new_value = axes[0].max_value;
    } else {
      new_value = (axes[0].min_value + axes[0].max_value) * 0.5f;
    }

    vr_status_t st = vr_font_set_axis(face, axes[0].name, new_value);
    test_expect_status(st, VR_OK, "axes: setting known axis succeeds");

    const vr_font_axis_t* after = vr_font_axes(face);
    test_expect(after != NULL, "axes: axis table still available after set");
    if (after) {
      test_expect(
        after[0].value >= after[0].min_value && after[0].value <= after[0].max_value,
        "axes: axis value remains within bounds after set");
    }

    st = vr_font_set_axis(face, "fake", new_value);
    test_expect_status(st, VR_ERR_NOT_FOUND, "axes: unknown axis returns not found");

    st = vr_font_set_axis(face, "w", new_value);
    test_expect_status(st, VR_ERR_INVALID_FONT, "axes: short axis tag is invalid");

    st = vr_font_set_axis(face, "wghtx", new_value);
    test_expect_status(st, VR_ERR_INVALID_FONT, "axes: long axis tag is invalid");
  }
}

void run_axis_tests(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "axes: test font opens");
  if (!face) return;

  test_axis_metadata(face);
  test_close_face(face);
}

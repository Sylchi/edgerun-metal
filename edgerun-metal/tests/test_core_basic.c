#include "test_core_internal.h"

static void test_wasm_ui_command_stats_records(void) {
  UINT8 bytes[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
              ER_WASM_UI_RECT_RECORD_LEN +
              ER_WASM_UI_HIT_RECORD_LEN +
              ER_WASM_UI_QUAD_RECORD_LEN];
  er_ui_scene_t scene;
  er_ui_scene_stats_t stats;
  UINT32 rect_offset = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  UINT32 hit_offset = rect_offset + ER_WASM_UI_RECT_RECORD_LEN;
  UINT32 quad_offset = hit_offset + ER_WASM_UI_HIT_RECORD_LEN;

  test_write_wasm_ui_scene_packet(bytes, (UINT32)sizeof(bytes));
  check_int64("wasm ui scene packet validates",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), 0);
  check_uint64("wasm ui scene packet rect stats", stats.rects, 1u);
  check_uint64("wasm ui scene packet hit stats", stats.hits, 1u);
  check_uint64("wasm ui scene packet text stats", stats.text_quads, 1u);
  check_int64("wasm ui decode scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("wasm ui scene packet decodes",
              er_wasm_ui_command_decode(bytes, (UINT32)sizeof(bytes), &scene, &stats), 0);
  check_uint64("wasm ui decoded rect count", scene.rect_count, 1u);
  check_uint64("wasm ui decoded hit count", scene.hit_count, 1u);
  check_uint64("wasm ui decoded text count", scene.text_quad_count, 1u);
  check_int64("wasm ui decoded rect mode", scene.rects[0].mode, ER_UI_RECT_FILL);
  check_int64("wasm ui decoded hit kind", scene.hits[0].kind, ER_UI_HIT_BUTTON);
  check_uint64("wasm ui decoded hit id", scene.hits[0].id, 7u);
  check_uint64("wasm ui decoded text atlas", scene.text_quads[0].atlas_id, 2u);
  er_ui_scene_destroy(&scene);

  check_int64("wasm ui scene rejects short packet",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes) - 1u, &stats), -1);

  test_put_le32(bytes + rect_offset + 52u, 4u);
  check_int64("wasm ui scene rejects rect mode",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
  test_put_le32(bytes + rect_offset + 52u, 0u);

  test_put_le32(bytes + hit_offset, 25u);
  check_int64("wasm ui scene rejects hit kind",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
  test_put_le32(bytes + hit_offset, 3u);

  test_put_le32(bytes + quad_offset, 0x7f800000u);
  check_int64("wasm ui scene rejects infinite float",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
}

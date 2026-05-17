#ifndef ER_UI_TEXT_H
#define ER_UI_TEXT_H

#include "er_ui_scene.h"
#include "vr_font.h"

#ifdef __cplusplus
extern "C" {
#endif

er_ui_status_t er_ui_scene_push_varfont_vertices(er_ui_scene_t* scene, const vr_vertex_t* vertices, size_t vertex_count, er_ui_color4_t color);
er_ui_status_t er_ui_scene_push_varfont_text(
  er_ui_scene_t* scene,
  vr_font_face_t* face,
  const uint32_t* codepoints,
  size_t codepoint_count,
  float x,
  float y,
  er_ui_color4_t color);

#ifdef __cplusplus
}
#endif

#endif

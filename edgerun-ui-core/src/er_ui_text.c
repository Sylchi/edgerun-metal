#include "er_ui_text.h"

static const size_t ER_UI_TEXT_ASCII_STACK_CAPACITY = 256u;

static er_ui_status_t er_ui_status_from_vr(vr_status_t status) {
  switch (status) {
    case VR_OK:
      return ER_UI_OK;
    case VR_ERR_OOM:
      return ER_UI_ERR_OOM;
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}

er_ui_status_t er_ui_varfont_measure_text(
  vr_font_face_t* face,
  const uint32_t* codepoints,
  size_t codepoint_count,
  er_ui_varfont_text_metrics_t* out_metrics) {
  if (!face || !out_metrics || (!codepoints && codepoint_count > 0u)) return ER_UI_ERR_INVALID_ARGUMENT;

  vr_font_metrics_t font_metrics = {0};
  vr_status_t vr_status = vr_font_metrics(face, &font_metrics);
  if (vr_status != VR_OK) return er_ui_status_from_vr(vr_status);

  out_metrics->advance_width = 0.0f;
  out_metrics->ascender = font_metrics.ascender;
  out_metrics->descender = font_metrics.descender;
  out_metrics->line_gap = font_metrics.line_gap;
  out_metrics->line_height = font_metrics.line_height;
  if (codepoint_count == 0u) return ER_UI_OK;

  vr_shaped_glyph_t* shaped = 0;
  size_t shaped_count = 0u;
  vr_status = vr_font_shape_text(face, codepoints, codepoint_count, &shaped, &shaped_count);
  if (vr_status != VR_OK) return er_ui_status_from_vr(vr_status);

  float width = 0.0f;
  for (size_t i = 0u; i < shaped_count; ++i) width += shaped[i].x_advance;
  (void)vr_font_free_shaped(face, shaped, shaped_count);
  out_metrics->advance_width = width;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_varfont_vertices(er_ui_scene_t* scene, const vr_vertex_t* vertices, size_t vertex_count, er_ui_color4_t color) {
  if (!scene || (!vertices && vertex_count > 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
  if ((vertex_count % VR_FONT_VERTICES_PER_GLYPH) != 0u) return ER_UI_ERR_INVALID_ARGUMENT;

  for (size_t i = 0u; i < vertex_count; i += VR_FONT_VERTICES_PER_GLYPH) {
    const vr_vertex_t* v0 = &vertices[i];
    const vr_vertex_t* v2 = &vertices[i + 2u];
    float x = v0->x;
    float y = v0->y;
    float w = v2->x - v0->x;
    float h = v2->y - v0->y;
    er_ui_status_t status = er_ui_scene_push_text_quad(scene, er_ui_quad_atlas(x, y, w, h, v0->u, v0->v, v2->u, v2->v, v0->atlas_id, color));
    if (status != ER_UI_OK) return status;
  }

  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_varfont_text(
  er_ui_scene_t* scene,
  vr_font_face_t* face,
  const uint32_t* codepoints,
  size_t codepoint_count,
  float x,
  float y,
  er_ui_color4_t color) {
  if (!scene || !face || (!codepoints && codepoint_count > 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (codepoint_count == 0u) return ER_UI_OK;

  vr_shaped_glyph_t* shaped = 0;
  size_t shaped_count = 0u;
  vr_status_t vr_status = vr_font_shape_text(face, codepoints, codepoint_count, &shaped, &shaped_count);
  if (vr_status != VR_OK) return er_ui_status_from_vr(vr_status);

  vr_vertex_t* vertices = 0;
  size_t vertex_count = 0u;
  vr_status = vr_font_build_vertex_batch(face, shaped, shaped_count, x, y, &vertices, &vertex_count);
  if (vr_status != VR_OK) {
    (void)vr_font_free_shaped(face, shaped, shaped_count);
    return er_ui_status_from_vr(vr_status);
  }

  er_ui_status_t status = er_ui_scene_push_varfont_vertices(scene, vertices, vertex_count, color);
  (void)vr_font_free_vertices(face, vertices, vertex_count);
  (void)vr_font_free_shaped(face, shaped, shaped_count);
  return status;
}

er_ui_status_t er_ui_scene_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* face,
  const char* text,
  size_t max_codepoints,
  float x,
  float y,
  er_ui_color4_t color) {
  if (!scene || !face || !text || max_codepoints > ER_UI_TEXT_ASCII_STACK_CAPACITY) return ER_UI_ERR_INVALID_ARGUMENT;

  uint32_t codepoints[ER_UI_TEXT_ASCII_STACK_CAPACITY];
  size_t count = 0u;
  while (text[count] != '\0') {
    if (count >= max_codepoints) return ER_UI_ERR_INVALID_ARGUMENT;
    unsigned char byte = (unsigned char)text[count];
    codepoints[count] = byte < 0x80u ? (uint32_t)byte : (uint32_t)'?';
    count++;
  }
  return er_ui_scene_push_varfont_text(scene, face, codepoints, count, x, y, color);
}

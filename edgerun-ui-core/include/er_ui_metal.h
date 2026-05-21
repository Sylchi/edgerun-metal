#ifndef ER_UI_METAL_H
#define ER_UI_METAL_H

#include "../src/er_ui_components_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

er_ui_status_t er_ui_edgerun_metal_surface_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_gallery_state_t* state);

#ifdef __cplusplus
}
#endif

#endif

#ifndef ER_UI_PRESET_CODE_H
#define ER_UI_PRESET_CODE_H

#include "er_ui_scene.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_PRESET_CODE_MAX_LEN 11u

typedef enum {
  ER_UI_STYLE_FAMILY_VEGA = 0,
  ER_UI_STYLE_FAMILY_NOVA,
  ER_UI_STYLE_FAMILY_MAIA,
  ER_UI_STYLE_FAMILY_LYRA,
  ER_UI_STYLE_FAMILY_MIRA,
  ER_UI_STYLE_FAMILY_LUMA,
  ER_UI_STYLE_FAMILY_SERA,
  ER_UI_STYLE_FAMILY_COUNT
} er_ui_style_family_t;

typedef struct {
  const char* style;
  const char* base_color;
  const char* theme;
  const char* chart_color;
  const char* icon_library;
  const char* font;
  const char* font_heading;
  const char* encoded_radius;
  const char* effective_radius;
  const char* menu_color;
  const char* menu_accent;
} er_ui_preset_recipe_t;

typedef struct {
  const char* path;
  bool has_style_family;
  er_ui_style_family_t style_family;
  const char* preset_code;
  er_ui_preset_recipe_t preset_recipe;
  const char* project_slug;
  const char* role;
} er_ui_extracted_source_capture_t;

er_ui_preset_recipe_t er_ui_preset_recipe_for_style_family(er_ui_style_family_t family);
er_ui_status_t er_ui_preset_encode(er_ui_preset_recipe_t recipe, char* out, size_t capacity, size_t* out_len);
er_ui_status_t er_ui_preset_decode(const char* preset_code, er_ui_preset_recipe_t* out_recipe);
bool er_ui_preset_recipe_matches_code(er_ui_preset_recipe_t recipe, const char* preset_code);
bool er_ui_preset_is_code(const char* preset_code);
size_t er_ui_extracted_source_capture_count(void);
const er_ui_extracted_source_capture_t* er_ui_extracted_source_capture_at(size_t index);

#ifdef __cplusplus
}
#endif

#endif

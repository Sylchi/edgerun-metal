#ifndef ER_UI_ASSETS_H
#define ER_UI_ASSETS_H

#include "er_ui_icon.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_COMPONENT_KIND_SHELL = 0,
  ER_UI_COMPONENT_KIND_LAYOUT,
  ER_UI_COMPONENT_KIND_NAVIGATION,
  ER_UI_COMPONENT_KIND_OVERLAY,
  ER_UI_COMPONENT_KIND_CARD,
  ER_UI_COMPONENT_KIND_FORM,
  ER_UI_COMPONENT_KIND_INPUT_GROUP,
  ER_UI_COMPONENT_KIND_CHART,
  ER_UI_COMPONENT_KIND_DATA_ROW,
  ER_UI_COMPONENT_KIND_CONTROL,
  ER_UI_COMPONENT_KIND_SELECTION,
  ER_UI_COMPONENT_KIND_FEEDBACK,
  ER_UI_COMPONENT_KIND_EDGERUN_DOMAIN,
  ER_UI_COMPONENT_KIND_COUNT
} er_ui_component_kind_t;

typedef enum {
  ER_UI_ASSET_PACK_OK = 0,
  ER_UI_ASSET_PACK_EMPTY_NAME,
  ER_UI_ASSET_PACK_NAME_TOO_LONG,
  ER_UI_ASSET_PACK_ICON_COUNT_EXCEEDED,
  ER_UI_ASSET_PACK_MISSING_REQUIRED_ICON,
  ER_UI_ASSET_PACK_DUPLICATE_ICON,
  ER_UI_ASSET_PACK_ICON_PROVIDER_NAME_MISMATCH,
  ER_UI_ASSET_PACK_INVALID_ICON_ATLAS,
  ER_UI_ASSET_PACK_FONT_FACE_COUNT_EXCEEDED,
  ER_UI_ASSET_PACK_MISSING_DEFAULT_FONT_FACE,
  ER_UI_ASSET_PACK_MISSING_FONT_CHAR,
  ER_UI_ASSET_PACK_INVALID_FONT_ATLAS,
  ER_UI_ASSET_PACK_EMOJI_COUNT_EXCEEDED,
  ER_UI_ASSET_PACK_MISSING_REQUIRED_EMOJI,
  ER_UI_ASSET_PACK_DUPLICATE_EMOJI,
  ER_UI_ASSET_PACK_COMPONENT_COUNT_EXCEEDED,
  ER_UI_ASSET_PACK_MISSING_COMPONENT_KIND,
  ER_UI_ASSET_PACK_DUPLICATE_COMPONENT
} er_ui_asset_pack_status_t;

typedef struct {
  size_t max_icon_count;
  uint32_t max_icon_atlas_side;
  size_t max_icon_atlas_bytes;
  size_t max_font_faces;
  uint32_t max_font_atlas_side;
  size_t max_font_atlas_bytes;
  size_t max_emoji_count;
  size_t max_component_count;
  size_t max_name_len;
} er_ui_asset_limits_t;

typedef struct {
  er_ui_icon_t icon;
  const char* provider_name;
} er_ui_icon_pack_entry_t;

typedef struct {
  const char* name;
  er_ui_icon_provider_t provider;
  const er_ui_icon_pack_entry_t* entries;
  size_t entry_count;
  uint32_t atlas_width;
  uint32_t atlas_height;
  size_t atlas_bytes;
} er_ui_icon_pack_spec_t;

typedef struct {
  const char* name;
  bool default_face;
  const char* covered_chars;
} er_ui_font_face_spec_t;

typedef struct {
  const char* name;
  const er_ui_font_face_spec_t* faces;
  size_t face_count;
  uint32_t atlas_width;
  uint32_t atlas_height;
  size_t atlas_bytes;
} er_ui_font_pack_spec_t;

typedef struct {
  const char* key;
  const char* label;
} er_ui_emoji_spec_t;

typedef struct {
  const char* name;
  const er_ui_emoji_spec_t* emoji;
  size_t emoji_count;
} er_ui_emoji_pack_spec_t;

typedef struct {
  const char* name;
  er_ui_component_kind_t kind;
} er_ui_component_pack_entry_t;

typedef struct {
  const char* name;
  const er_ui_component_pack_entry_t* components;
  size_t component_count;
} er_ui_component_pack_spec_t;

typedef struct {
  const char* name;
  er_ui_icon_pack_spec_t icons;
  er_ui_font_pack_spec_t fonts;
  er_ui_emoji_pack_spec_t emoji;
  er_ui_component_pack_spec_t components;
} er_ui_asset_pack_spec_t;

typedef struct {
  er_ui_asset_pack_spec_t active;
  er_ui_asset_limits_t limits;
} er_ui_asset_pack_runtime_t;

const char* er_ui_component_kind_label(er_ui_component_kind_t kind);
er_ui_asset_limits_t er_ui_asset_limits_default(void);
const char* er_ui_required_font_chars(void);

er_ui_asset_pack_status_t er_ui_icon_pack_validate(er_ui_icon_pack_spec_t pack, er_ui_asset_limits_t limits);
er_ui_asset_pack_status_t er_ui_font_pack_validate(er_ui_font_pack_spec_t pack, er_ui_asset_limits_t limits);
er_ui_asset_pack_status_t er_ui_emoji_pack_validate(er_ui_emoji_pack_spec_t pack, er_ui_asset_limits_t limits);
er_ui_asset_pack_status_t er_ui_component_pack_validate(er_ui_component_pack_spec_t pack, er_ui_asset_limits_t limits);
er_ui_asset_pack_status_t er_ui_asset_pack_validate(er_ui_asset_pack_spec_t pack, er_ui_asset_limits_t limits);

er_ui_asset_pack_spec_t er_ui_tabler_inter_asset_pack(void);
er_ui_asset_pack_spec_t er_ui_lucide_geist_asset_pack(void);
er_ui_asset_pack_status_t er_ui_asset_pack_runtime_init(
  er_ui_asset_pack_runtime_t* runtime,
  er_ui_asset_pack_spec_t active,
  er_ui_asset_limits_t limits);
er_ui_asset_pack_status_t er_ui_asset_pack_runtime_replace(
  er_ui_asset_pack_runtime_t* runtime,
  er_ui_asset_pack_spec_t replacement);

#ifdef __cplusplus
}
#endif

#endif

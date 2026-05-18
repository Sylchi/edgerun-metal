#include "er_ui_assets.h"

enum {
  ER_UI_DEFAULT_MAX_ICON_COUNT = 256u,
  ER_UI_DEFAULT_ICON_ATLAS_SIDE = 4096u,
  ER_UI_DEFAULT_ICON_ATLAS_BYTES = 16777216u,
  ER_UI_DEFAULT_MAX_FONT_FACES = 8u,
  ER_UI_DEFAULT_FONT_ATLAS_SIDE = 4096u,
  ER_UI_DEFAULT_FONT_ATLAS_BYTES = 16777216u,
  ER_UI_DEFAULT_MAX_EMOJI_COUNT = 256u,
  ER_UI_DEFAULT_MAX_COMPONENT_COUNT = 512u,
  ER_UI_DEFAULT_MAX_NAME_LEN = 96u,
  ER_UI_BUNDLED_ICON_ATLAS_W = 672u,
  ER_UI_BUNDLED_ICON_ATLAS_H = 560u,
  ER_UI_BUNDLED_FONT_ATLAS_SIDE = 1024u
};

static const char ER_UI_REQUIRED_FONT_CHARS[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:/#@[](){}<>+=%$!?&, ";

//@optimizer-ignore-constant provider manifest is indexed by the guarded er_ui_icon_t enum and mirrors the bundled Tabler asset contract
static const er_ui_icon_pack_entry_t ER_UI_TABLER_ICON_ENTRIES[ER_UI_ICON_COUNT] = {
  {ER_UI_ICON_ACTIVITY, "activity"},      {ER_UI_ICON_APP, "apps"},           {ER_UI_ICON_BELL, "bell"},
  {ER_UI_ICON_CHAT, "message-circle"},    {ER_UI_ICON_CHECK, "check"},        {ER_UI_ICON_CHEVRON_RIGHT, "chevron-right"},
  {ER_UI_ICON_CODE, "code"},              {ER_UI_ICON_CPU, "cpu"},            {ER_UI_ICON_DATABASE, "database"},
  {ER_UI_ICON_EYE, "eye"},                {ER_UI_ICON_FILE, "file"},          {ER_UI_ICON_KEY, "key"},
  {ER_UI_ICON_LOCK, "lock"},              {ER_UI_ICON_MENU, "menu-2"},        {ER_UI_ICON_MESSAGE_PLUS, "message-plus"},
  {ER_UI_ICON_NETWORK, "network"},        {ER_UI_ICON_ROUTE, "route"},        {ER_UI_ICON_SEARCH, "search"},
  {ER_UI_ICON_SEND, "arrow-up"},          {ER_UI_ICON_SERVER, "server"},      {ER_UI_ICON_SETTINGS, "settings"},
  {ER_UI_ICON_SHIELD, "shield-check"},    {ER_UI_ICON_SPARKLES, "sparkles"},  {ER_UI_ICON_STORAGE, "database"},
  {ER_UI_ICON_TERMINAL, "terminal-2"},    {ER_UI_ICON_TRUST, "shield-check"}, {ER_UI_ICON_TRASH, "trash"},
  {ER_UI_ICON_USER, "user"},              {ER_UI_ICON_WALLET, "wallet"},      {ER_UI_ICON_WARNING, "alert-triangle"},
  {ER_UI_ICON_X, "x"}
};

//@optimizer-ignore-constant provider manifest is indexed by the guarded er_ui_icon_t enum and mirrors the bundled Lucide asset contract
static const er_ui_icon_pack_entry_t ER_UI_LUCIDE_ICON_ENTRIES[ER_UI_ICON_COUNT] = {
  {ER_UI_ICON_ACTIVITY, "activity"},       {ER_UI_ICON_APP, "app-window"},        {ER_UI_ICON_BELL, "bell"},
  {ER_UI_ICON_CHAT, "message-circle"},     {ER_UI_ICON_CHECK, "check"},           {ER_UI_ICON_CHEVRON_RIGHT, "chevron-right"},
  {ER_UI_ICON_CODE, "code"},               {ER_UI_ICON_CPU, "cpu"},               {ER_UI_ICON_DATABASE, "database"},
  {ER_UI_ICON_EYE, "eye"},                 {ER_UI_ICON_FILE, "file"},             {ER_UI_ICON_KEY, "key"},
  {ER_UI_ICON_LOCK, "lock"},               {ER_UI_ICON_MENU, "menu"},             {ER_UI_ICON_MESSAGE_PLUS, "message-circle-plus"},
  {ER_UI_ICON_NETWORK, "network"},         {ER_UI_ICON_ROUTE, "route"},           {ER_UI_ICON_SEARCH, "search"},
  {ER_UI_ICON_SEND, "arrow-up"},           {ER_UI_ICON_SERVER, "server"},         {ER_UI_ICON_SETTINGS, "settings"},
  {ER_UI_ICON_SHIELD, "shield-check"},     {ER_UI_ICON_SPARKLES, "sparkles"},     {ER_UI_ICON_STORAGE, "database"},
  {ER_UI_ICON_TERMINAL, "square-terminal"}, {ER_UI_ICON_TRUST, "shield-check"},    {ER_UI_ICON_TRASH, "trash-2"},
  {ER_UI_ICON_USER, "user"},               {ER_UI_ICON_WALLET, "wallet"},         {ER_UI_ICON_WARNING, "triangle-alert"},
  {ER_UI_ICON_X, "x"}
};

static const er_ui_font_face_spec_t ER_UI_INTER_FONT_FACES[] = {{"Inter", true, ER_UI_REQUIRED_FONT_CHARS}};
static const er_ui_font_face_spec_t ER_UI_GEIST_FONT_FACES[] = {{"Geist", true, ER_UI_REQUIRED_FONT_CHARS}};

static const er_ui_emoji_spec_t ER_UI_REQUIRED_EMOJI[] = {{"check", "check"},     {"warning", "warning"}, {"locked", "locked"},
                                                         {"unlocked", "unlocked"}, {"route", "route"},     {"storage", "storage"},
                                                         {"payment", "payment"},   {"proof", "proof"}};

static const er_ui_component_pack_entry_t ER_UI_COMPONENT_ENTRIES[ER_UI_COMPONENT_KIND_COUNT] = {
  {"shell", ER_UI_COMPONENT_KIND_SHELL},
  {"layout", ER_UI_COMPONENT_KIND_LAYOUT},
  {"navigation", ER_UI_COMPONENT_KIND_NAVIGATION},
  {"overlay", ER_UI_COMPONENT_KIND_OVERLAY},
  {"card", ER_UI_COMPONENT_KIND_CARD},
  {"form", ER_UI_COMPONENT_KIND_FORM},
  {"input-group", ER_UI_COMPONENT_KIND_INPUT_GROUP},
  {"chart", ER_UI_COMPONENT_KIND_CHART},
  {"data-row", ER_UI_COMPONENT_KIND_DATA_ROW},
  {"control", ER_UI_COMPONENT_KIND_CONTROL},
  {"selection", ER_UI_COMPONENT_KIND_SELECTION},
  {"feedback", ER_UI_COMPONENT_KIND_FEEDBACK},
  {"domain", ER_UI_COMPONENT_KIND_EDGERUN_DOMAIN}
};

static bool er_ui_assets_cstr_eq(const char* a, const char* b) {
  size_t i = 0u;
  if (!a || !b) return false;
  while (a[i] != '\0' && b[i] != '\0') {
    if (a[i] != b[i]) return false;
    i++;
  }
  return a[i] == b[i];
}

static size_t er_ui_assets_cstr_len(const char* value) {
  size_t len = 0u;
  if (!value) return 0u;
  while (value[len] != '\0') len++;
  return len;
}

static bool er_ui_assets_cstr_contains_char(const char* value, char required) {
  size_t i = 0u;
  if (!value) return false;
  while (value[i] != '\0') {
    if (value[i] == required) return true;
    i++;
  }
  return false;
}

static er_ui_asset_pack_status_t er_ui_asset_validate_name(const char* name, er_ui_asset_limits_t limits) {
  size_t len = er_ui_assets_cstr_len(name);
  if (len == 0u) return ER_UI_ASSET_PACK_EMPTY_NAME;
  if (len > limits.max_name_len) return ER_UI_ASSET_PACK_NAME_TOO_LONG;
  return ER_UI_ASSET_PACK_OK;
}

const char* er_ui_component_kind_label(er_ui_component_kind_t kind) {
  switch (kind) {
    case ER_UI_COMPONENT_KIND_SHELL:
      return "Shell";
    case ER_UI_COMPONENT_KIND_LAYOUT:
      return "Layout";
    case ER_UI_COMPONENT_KIND_NAVIGATION:
      return "Navigation";
    case ER_UI_COMPONENT_KIND_OVERLAY:
      return "Overlay";
    case ER_UI_COMPONENT_KIND_CARD:
      return "Card";
    case ER_UI_COMPONENT_KIND_FORM:
      return "Form";
    case ER_UI_COMPONENT_KIND_INPUT_GROUP:
      return "Input Group";
    case ER_UI_COMPONENT_KIND_CHART:
      return "Chart";
    case ER_UI_COMPONENT_KIND_DATA_ROW:
      return "Data Row";
    case ER_UI_COMPONENT_KIND_CONTROL:
      return "Control";
    case ER_UI_COMPONENT_KIND_SELECTION:
      return "Selection";
    case ER_UI_COMPONENT_KIND_FEEDBACK:
      return "Feedback";
    case ER_UI_COMPONENT_KIND_EDGERUN_DOMAIN:
      return "EdgeRun Domain";
    case ER_UI_COMPONENT_KIND_COUNT:
      return "Unknown";
  }
  return "Unknown";
}

er_ui_asset_limits_t er_ui_asset_limits_default(void) {
  return (er_ui_asset_limits_t){ER_UI_DEFAULT_MAX_ICON_COUNT,
                                ER_UI_DEFAULT_ICON_ATLAS_SIDE,
                                ER_UI_DEFAULT_ICON_ATLAS_BYTES,
                                ER_UI_DEFAULT_MAX_FONT_FACES,
                                ER_UI_DEFAULT_FONT_ATLAS_SIDE,
                                ER_UI_DEFAULT_FONT_ATLAS_BYTES,
                                ER_UI_DEFAULT_MAX_EMOJI_COUNT,
                                ER_UI_DEFAULT_MAX_COMPONENT_COUNT,
                                ER_UI_DEFAULT_MAX_NAME_LEN};
}

const char* er_ui_required_font_chars(void) {
  return ER_UI_REQUIRED_FONT_CHARS;
}

//@optimizer-ignore-function icon manifest validation is bounded by explicit asset-pack limits and must compare caller-owned entries for duplicate coverage
er_ui_asset_pack_status_t er_ui_icon_pack_validate(er_ui_icon_pack_spec_t pack, er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status = er_ui_asset_validate_name(pack.name, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  if (pack.entry_count > limits.max_icon_count) return ER_UI_ASSET_PACK_ICON_COUNT_EXCEEDED;
  if (pack.atlas_width == 0u || pack.atlas_height == 0u || pack.atlas_width > limits.max_icon_atlas_side ||
      pack.atlas_height > limits.max_icon_atlas_side || pack.atlas_bytes == 0u || pack.atlas_bytes > limits.max_icon_atlas_bytes) {
    return ER_UI_ASSET_PACK_INVALID_ICON_ATLAS;
  }
  for (size_t i = 0u; i < pack.entry_count; i++) {
    for (size_t j = i + 1u; j < pack.entry_count; j++) {
      if (pack.entries[i].icon == pack.entries[j].icon) return ER_UI_ASSET_PACK_DUPLICATE_ICON;
    }
    if (!er_ui_assets_cstr_eq(pack.entries[i].provider_name, er_ui_icon_provider_name(pack.entries[i].icon, pack.provider))) {
      return ER_UI_ASSET_PACK_ICON_PROVIDER_NAME_MISMATCH;
    }
  }
  for (uint32_t icon = 0u; icon < (uint32_t)ER_UI_ICON_COUNT; icon++) {
    bool found = false;
    for (size_t i = 0u; i < pack.entry_count; i++) {
      if ((uint32_t)pack.entries[i].icon == icon) found = true;
    }
    if (!found) return ER_UI_ASSET_PACK_MISSING_REQUIRED_ICON;
  }
  return ER_UI_ASSET_PACK_OK;
}

er_ui_asset_pack_status_t er_ui_font_pack_validate(er_ui_font_pack_spec_t pack, er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status = er_ui_asset_validate_name(pack.name, limits);
  const er_ui_font_face_spec_t* default_face = 0;
  if (status != ER_UI_ASSET_PACK_OK) return status;
  if (pack.face_count == 0u || pack.face_count > limits.max_font_faces) return ER_UI_ASSET_PACK_FONT_FACE_COUNT_EXCEEDED;
  if (pack.atlas_width == 0u || pack.atlas_height == 0u || pack.atlas_width > limits.max_font_atlas_side ||
      pack.atlas_height > limits.max_font_atlas_side || pack.atlas_bytes == 0u || pack.atlas_bytes > limits.max_font_atlas_bytes) {
    return ER_UI_ASSET_PACK_INVALID_FONT_ATLAS;
  }
  for (size_t i = 0u; i < pack.face_count; i++) {
    if (pack.faces[i].default_face) default_face = &pack.faces[i];
  }
  if (!default_face) return ER_UI_ASSET_PACK_MISSING_DEFAULT_FONT_FACE;
  for (size_t i = 0u; ER_UI_REQUIRED_FONT_CHARS[i] != '\0'; i++) {
    if (!er_ui_assets_cstr_contains_char(default_face->covered_chars, ER_UI_REQUIRED_FONT_CHARS[i])) return ER_UI_ASSET_PACK_MISSING_FONT_CHAR;
  }
  return ER_UI_ASSET_PACK_OK;
}

//@optimizer-ignore-function emoji manifest validation is bounded by explicit asset-pack limits and must compare caller-owned semantic keys
er_ui_asset_pack_status_t er_ui_emoji_pack_validate(er_ui_emoji_pack_spec_t pack, er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status = er_ui_asset_validate_name(pack.name, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  if (pack.emoji_count > limits.max_emoji_count) return ER_UI_ASSET_PACK_EMOJI_COUNT_EXCEEDED;
  for (size_t i = 0u; i < pack.emoji_count; i++) {
    for (size_t j = i + 1u; j < pack.emoji_count; j++) {
      if (er_ui_assets_cstr_eq(pack.emoji[i].key, pack.emoji[j].key)) return ER_UI_ASSET_PACK_DUPLICATE_EMOJI;
    }
  }
  for (size_t required = 0u; required < (sizeof(ER_UI_REQUIRED_EMOJI) / sizeof(ER_UI_REQUIRED_EMOJI[0])); required++) {
    bool found = false;
    for (size_t i = 0u; i < pack.emoji_count; i++) {
      if (er_ui_assets_cstr_eq(pack.emoji[i].key, ER_UI_REQUIRED_EMOJI[required].key)) found = true;
    }
    if (!found) return ER_UI_ASSET_PACK_MISSING_REQUIRED_EMOJI;
  }
  return ER_UI_ASSET_PACK_OK;
}

//@optimizer-ignore-function component manifest validation is bounded by explicit asset-pack limits and must compare caller-owned component names
er_ui_asset_pack_status_t er_ui_component_pack_validate(er_ui_component_pack_spec_t pack, er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status = er_ui_asset_validate_name(pack.name, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  if (pack.component_count > limits.max_component_count) return ER_UI_ASSET_PACK_COMPONENT_COUNT_EXCEEDED;
  for (size_t i = 0u; i < pack.component_count; i++) {
    for (size_t j = i + 1u; j < pack.component_count; j++) {
      if (er_ui_assets_cstr_eq(pack.components[i].name, pack.components[j].name)) return ER_UI_ASSET_PACK_DUPLICATE_COMPONENT;
    }
  }
  for (uint32_t kind = 0u; kind < (uint32_t)ER_UI_COMPONENT_KIND_COUNT; kind++) {
    bool found = false;
    for (size_t i = 0u; i < pack.component_count; i++) {
      if ((uint32_t)pack.components[i].kind == kind) found = true;
    }
    if (!found) return ER_UI_ASSET_PACK_MISSING_COMPONENT_KIND;
  }
  return ER_UI_ASSET_PACK_OK;
}

er_ui_asset_pack_status_t er_ui_asset_pack_validate(er_ui_asset_pack_spec_t pack, er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status = er_ui_asset_validate_name(pack.name, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  status = er_ui_icon_pack_validate(pack.icons, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  status = er_ui_font_pack_validate(pack.fonts, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  status = er_ui_emoji_pack_validate(pack.emoji, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  return er_ui_component_pack_validate(pack.components, limits);
}

er_ui_asset_pack_spec_t er_ui_tabler_inter_asset_pack(void) {
  return (er_ui_asset_pack_spec_t){
    "edgerun-tabler-inter",
    {"tabler-svg", ER_UI_ICON_PROVIDER_TABLER, ER_UI_TABLER_ICON_ENTRIES, ER_UI_ICON_COUNT, ER_UI_BUNDLED_ICON_ATLAS_W, ER_UI_BUNDLED_ICON_ATLAS_H,
     ER_UI_BUNDLED_ICON_ATLAS_W * ER_UI_BUNDLED_ICON_ATLAS_H},
    {"inter", ER_UI_INTER_FONT_FACES, sizeof(ER_UI_INTER_FONT_FACES) / sizeof(ER_UI_INTER_FONT_FACES[0]), ER_UI_BUNDLED_FONT_ATLAS_SIDE,
     ER_UI_BUNDLED_FONT_ATLAS_SIDE, ER_UI_BUNDLED_FONT_ATLAS_SIDE * ER_UI_BUNDLED_FONT_ATLAS_SIDE},
    {"edgerun-semantic-emoji", ER_UI_REQUIRED_EMOJI, sizeof(ER_UI_REQUIRED_EMOJI) / sizeof(ER_UI_REQUIRED_EMOJI[0])},
    {"edgerun-components", ER_UI_COMPONENT_ENTRIES, ER_UI_COMPONENT_KIND_COUNT}};
}

er_ui_asset_pack_spec_t er_ui_lucide_geist_asset_pack(void) {
  return (er_ui_asset_pack_spec_t){
    "edgerun-lucide-geist",
    {"lucide-svg", ER_UI_ICON_PROVIDER_LUCIDE, ER_UI_LUCIDE_ICON_ENTRIES, ER_UI_ICON_COUNT, ER_UI_BUNDLED_ICON_ATLAS_W, ER_UI_BUNDLED_ICON_ATLAS_H,
     ER_UI_BUNDLED_ICON_ATLAS_W * ER_UI_BUNDLED_ICON_ATLAS_H},
    {"geist", ER_UI_GEIST_FONT_FACES, sizeof(ER_UI_GEIST_FONT_FACES) / sizeof(ER_UI_GEIST_FONT_FACES[0]), ER_UI_BUNDLED_FONT_ATLAS_SIDE,
     ER_UI_BUNDLED_FONT_ATLAS_SIDE, ER_UI_BUNDLED_FONT_ATLAS_SIDE * ER_UI_BUNDLED_FONT_ATLAS_SIDE},
    {"edgerun-semantic-emoji", ER_UI_REQUIRED_EMOJI, sizeof(ER_UI_REQUIRED_EMOJI) / sizeof(ER_UI_REQUIRED_EMOJI[0])},
    {"edgerun-components", ER_UI_COMPONENT_ENTRIES, ER_UI_COMPONENT_KIND_COUNT}};
}

er_ui_asset_pack_status_t er_ui_asset_pack_runtime_init(er_ui_asset_pack_runtime_t* runtime, er_ui_asset_pack_spec_t active,
                                                        er_ui_asset_limits_t limits) {
  er_ui_asset_pack_status_t status;
  if (!runtime) return ER_UI_ASSET_PACK_EMPTY_NAME;
  status = er_ui_asset_pack_validate(active, limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  runtime->active = active;
  runtime->limits = limits;
  return ER_UI_ASSET_PACK_OK;
}

er_ui_asset_pack_status_t er_ui_asset_pack_runtime_replace(er_ui_asset_pack_runtime_t* runtime, er_ui_asset_pack_spec_t replacement) {
  er_ui_asset_pack_status_t status;
  if (!runtime) return ER_UI_ASSET_PACK_EMPTY_NAME;
  status = er_ui_asset_pack_validate(replacement, runtime->limits);
  if (status != ER_UI_ASSET_PACK_OK) return status;
  runtime->active = replacement;
  return ER_UI_ASSET_PACK_OK;
}

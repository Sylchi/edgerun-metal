#include "er_ui_preset_code.h"

enum {
  ER_UI_PRESET_BASE62 = 62u,
  ER_UI_PRESET_PREFIX_LEN = 1u,
  ER_UI_PRESET_MIN_CODE_LEN = 2u,
  ER_UI_PRESET_MAX_CODE_LEN = 10u,
  ER_UI_PRESET_FIELD_COUNT = 10u,
  ER_UI_PRESET_BASE62_BUFFER_LEN = 11u,
  ER_UI_PRESET_BITS_COMPACT = 3u,
  ER_UI_PRESET_BITS_RADIUS = 4u,
  ER_UI_PRESET_BITS_STANDARD = 6u,
  ER_UI_PRESET_BITS_HEADING_FONT = 5u,
  ER_UI_PRESET_BASE62_UPPER_OFFSET = 10u,
  ER_UI_PRESET_BASE62_LOWER_OFFSET = 36u
};

typedef enum {
  ER_UI_PRESET_FIELD_MENU_COLOR = 0,
  ER_UI_PRESET_FIELD_MENU_ACCENT,
  ER_UI_PRESET_FIELD_RADIUS,
  ER_UI_PRESET_FIELD_FONT,
  ER_UI_PRESET_FIELD_ICON_LIBRARY,
  ER_UI_PRESET_FIELD_THEME,
  ER_UI_PRESET_FIELD_BASE_COLOR,
  ER_UI_PRESET_FIELD_STYLE,
  ER_UI_PRESET_FIELD_CHART_COLOR,
  ER_UI_PRESET_FIELD_FONT_HEADING
} er_ui_preset_field_index_t;

typedef struct {
  const char* key;
  const char* const* values;
  size_t value_count;
  uint32_t bits;
} er_ui_preset_field_t;

static const char ER_UI_PRESET_ALPHABET[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
static const char ER_UI_PRESET_RADIUS_NONE_STYLE[] = "none";

static const char *const ER_UI_PRESET_THEME_COLORS[] = {
  "neutral", "stone", "zinc", "gray", "amber", "blue", "cyan", "emerald", "fuchsia", "green", "indigo", "lime", "orange",
  "pink", "purple", "red", "rose", "sky", "teal", "violet", "yellow", "mauve", "olive", "mist", "taupe"
};
static const char *const ER_UI_PRESET_BASE_COLORS[] = {"neutral", "stone", "zinc", "gray", "mauve", "olive", "mist", "taupe"};
static const char *const ER_UI_PRESET_FONTS[] = {
  "inter", "noto-sans", "nunito-sans", "figtree", "roboto", "raleway", "dm-sans", "public-sans", "outfit", "jetbrains-mono",
  "geist", "geist-mono", "lora", "merriweather", "playfair-display", "noto-serif", "roboto-slab", "oxanium", "manrope",
  "space-grotesk", "montserrat", "ibm-plex-sans", "source-sans-3", "instrument-sans", "eb-garamond", "instrument-serif"
};
static const char *const ER_UI_PRESET_HEADING_FONTS[] = {
  "inherit", "inter", "noto-sans", "nunito-sans", "figtree", "roboto", "raleway", "dm-sans", "public-sans", "outfit",
  "jetbrains-mono", "geist", "geist-mono", "lora", "merriweather", "playfair-display", "noto-serif", "roboto-slab",
  "oxanium", "manrope", "space-grotesk", "montserrat", "ibm-plex-sans", "source-sans-3", "instrument-sans", "eb-garamond",
  "instrument-serif"
};
static const char *const ER_UI_PRESET_MENU_COLORS[] = {"default", "inverted", "default-translucent", "inverted-translucent"};
static const char *const ER_UI_PRESET_MENU_ACCENTS[] = {"subtle", "bold"};
static const char *const ER_UI_PRESET_RADII[] = {"default", "none", "small", "medium", "large"};
static const char *const ER_UI_PRESET_ICON_LIBRARIES[] = {"lucide", "hugeicons", "tabler", "phosphor", "remixicon"};
static const char *const ER_UI_PRESET_STYLES[] = {"nova", "vega", "maia", "lyra", "mira", "luma", "sera"};

#define ER_UI_PRESET_RECIPE_VEGA {"vega", "neutral", "neutral", "neutral", "lucide", "inter", "inherit", "default", "default", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_NOVA {"nova", "neutral", "neutral", "neutral", "lucide", "geist", "inherit", "default", "default", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_MAIA {"maia", "neutral", "neutral", "neutral", "hugeicons", "figtree", "inherit", "default", "default", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_LYRA {"lyra", "neutral", "neutral", "neutral", "phosphor", "jetbrains-mono", "inherit", "default", "none", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_MIRA {"mira", "neutral", "neutral", "neutral", "hugeicons", "inter", "inherit", "default", "default", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_LUMA {"luma", "neutral", "neutral", "neutral", "lucide", "inter", "inherit", "default", "default", "default", "subtle"}
#define ER_UI_PRESET_RECIPE_SERA {"sera", "taupe", "taupe", "taupe", "lucide", "noto-sans", "playfair-display", "default", "none", "default", "subtle"}
#define ER_UI_PRESET_COLOR(r, g, b, a) ((er_ui_color4_t){(r), (g), (b), (a)})
#define ER_UI_PRESET_COLORS_MIRA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.035f, 0.035f, 0.035f, 1.0f), ER_UI_PRESET_COLOR(0.055f, 0.055f, 0.055f, 0.98f),                                                 \
      ER_UI_PRESET_COLOR(0.048f, 0.048f, 0.048f, 0.98f), ER_UI_PRESET_COLOR(0.091f, 0.091f, 0.091f, 0.96f),                                             \
      ER_UI_PRESET_COLOR(0.125f, 0.125f, 0.125f, 0.92f), ER_UI_PRESET_COLOR(0.245f, 0.245f, 0.245f, 0.88f),                                             \
      ER_UI_PRESET_COLOR(0.118f, 0.118f, 0.118f, 0.98f), ER_UI_PRESET_COLOR(0.925f, 0.925f, 0.925f, 1.0f),                                             \
      ER_UI_PRESET_COLOR(0.63f, 0.63f, 0.63f, 1.0f), ER_UI_PRESET_COLOR(0.235f, 0.235f, 0.235f, 0.78f),                                                 \
      ER_UI_PRESET_COLOR(0.82f, 0.82f, 0.82f, 1.0f), ER_UI_PRESET_COLOR(0.055f, 0.055f, 0.055f, 1.0f),                                                  \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_VEGA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.026f, 0.034f, 0.046f, 1.0f), ER_UI_PRESET_COLOR(0.035f, 0.045f, 0.062f, 0.98f),                                                \
      ER_UI_PRESET_COLOR(0.031f, 0.04f, 0.056f, 0.98f), ER_UI_PRESET_COLOR(0.065f, 0.079f, 0.103f, 0.96f),                                             \
      ER_UI_PRESET_COLOR(0.094f, 0.113f, 0.145f, 0.92f), ER_UI_PRESET_COLOR(0.1f, 0.22f, 0.36f, 0.78f),                                                 \
      ER_UI_PRESET_COLOR(0.055f, 0.068f, 0.091f, 0.98f), ER_UI_PRESET_COLOR(0.92f, 0.95f, 0.98f, 1.0f),                                                 \
      ER_UI_PRESET_COLOR(0.59f, 0.66f, 0.74f, 1.0f), ER_UI_PRESET_COLOR(0.19f, 0.25f, 0.34f, 0.78f),                                                    \
      ER_UI_PRESET_COLOR(0.3f, 0.63f, 0.95f, 1.0f), ER_UI_PRESET_COLOR(0.02f, 0.04f, 0.07f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.44f, 0.58f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_NOVA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.028f, 0.028f, 0.031f, 1.0f), ER_UI_PRESET_COLOR(0.042f, 0.042f, 0.047f, 0.98f),                                                \
      ER_UI_PRESET_COLOR(0.039f, 0.039f, 0.043f, 0.98f), ER_UI_PRESET_COLOR(0.083f, 0.083f, 0.092f, 0.96f),                                             \
      ER_UI_PRESET_COLOR(0.121f, 0.121f, 0.134f, 0.92f), ER_UI_PRESET_COLOR(0.02f, 0.27f, 0.32f, 0.72f),                                                \
      ER_UI_PRESET_COLOR(0.105f, 0.105f, 0.115f, 0.98f), ER_UI_PRESET_COLOR(0.94f, 0.95f, 0.96f, 1.0f),                                                 \
      ER_UI_PRESET_COLOR(0.63f, 0.65f, 0.68f, 1.0f), ER_UI_PRESET_COLOR(0.23f, 0.24f, 0.26f, 0.78f),                                                    \
      ER_UI_PRESET_COLOR(0.08f, 0.76f, 0.86f, 1.0f), ER_UI_PRESET_COLOR(0.02f, 0.04f, 0.05f, 1.0f),                                                     \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_MAIA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.028f, 0.035f, 0.031f, 1.0f), ER_UI_PRESET_COLOR(0.037f, 0.048f, 0.042f, 0.98f),                                                \
      ER_UI_PRESET_COLOR(0.034f, 0.044f, 0.039f, 0.98f), ER_UI_PRESET_COLOR(0.071f, 0.091f, 0.08f, 0.96f),                                              \
      ER_UI_PRESET_COLOR(0.103f, 0.133f, 0.116f, 0.92f), ER_UI_PRESET_COLOR(0.0f, 0.32f, 0.2f, 0.72f),                                                  \
      ER_UI_PRESET_COLOR(0.063f, 0.083f, 0.072f, 0.98f), ER_UI_PRESET_COLOR(0.92f, 0.96f, 0.93f, 1.0f),                                                 \
      ER_UI_PRESET_COLOR(0.6f, 0.69f, 0.63f, 1.0f), ER_UI_PRESET_COLOR(0.18f, 0.29f, 0.22f, 0.78f),                                                     \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.02f, 0.05f, 0.035f, 1.0f),                                                     \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_LYRA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.033f, 0.03f, 0.049f, 1.0f), ER_UI_PRESET_COLOR(0.046f, 0.041f, 0.066f, 0.98f),                                                 \
      ER_UI_PRESET_COLOR(0.042f, 0.037f, 0.061f, 0.98f), ER_UI_PRESET_COLOR(0.084f, 0.075f, 0.119f, 0.96f),                                             \
      ER_UI_PRESET_COLOR(0.122f, 0.108f, 0.17f, 0.92f), ER_UI_PRESET_COLOR(0.28f, 0.18f, 0.52f, 0.72f),                                                 \
      ER_UI_PRESET_COLOR(0.073f, 0.064f, 0.103f, 0.98f), ER_UI_PRESET_COLOR(0.95f, 0.93f, 0.99f, 1.0f),                                                 \
      ER_UI_PRESET_COLOR(0.67f, 0.62f, 0.76f, 1.0f), ER_UI_PRESET_COLOR(0.25f, 0.2f, 0.36f, 0.78f),                                                     \
      ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f), ER_UI_PRESET_COLOR(0.03f, 0.02f, 0.05f, 1.0f),                                                     \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_LUMA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.047f, 0.04f, 0.032f, 1.0f), ER_UI_PRESET_COLOR(0.066f, 0.055f, 0.042f, 0.98f),                                                 \
      ER_UI_PRESET_COLOR(0.06f, 0.051f, 0.039f, 0.98f), ER_UI_PRESET_COLOR(0.118f, 0.097f, 0.07f, 0.96f),                                               \
      ER_UI_PRESET_COLOR(0.166f, 0.132f, 0.09f, 0.92f), ER_UI_PRESET_COLOR(0.42f, 0.26f, 0.04f, 0.72f),                                                  \
      ER_UI_PRESET_COLOR(0.104f, 0.085f, 0.061f, 0.98f), ER_UI_PRESET_COLOR(0.98f, 0.94f, 0.88f, 1.0f),                                                 \
      ER_UI_PRESET_COLOR(0.75f, 0.67f, 0.56f, 1.0f), ER_UI_PRESET_COLOR(0.34f, 0.25f, 0.15f, 0.78f),                                                    \
      ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f), ER_UI_PRESET_COLOR(0.06f, 0.04f, 0.01f, 1.0f),                                                     \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }
#define ER_UI_PRESET_COLORS_SERA                                                                                                                        \
  {                                                                                                                                                      \
    ER_UI_PRESET_COLOR(0.047f, 0.039f, 0.036f, 1.0f), ER_UI_PRESET_COLOR(0.114f, 0.094f, 0.086f, 0.98f),                                                \
      ER_UI_PRESET_COLOR(0.047f, 0.039f, 0.036f, 0.98f), ER_UI_PRESET_COLOR(0.114f, 0.094f, 0.086f, 0.96f),                                             \
      ER_UI_PRESET_COLOR(0.169f, 0.142f, 0.134f, 0.92f), ER_UI_PRESET_COLOR(0.169f, 0.142f, 0.134f, 0.88f),                                             \
      ER_UI_PRESET_COLOR(0.114f, 0.094f, 0.086f, 0.98f), ER_UI_PRESET_COLOR(0.985f, 0.981f, 0.976f, 1.0f),                                              \
      ER_UI_PRESET_COLOR(0.67f, 0.628f, 0.612f, 1.0f), ER_UI_PRESET_COLOR(1.0f, 1.0f, 1.0f, 0.1f),                                                      \
      ER_UI_PRESET_COLOR(0.911f, 0.894f, 0.89f, 1.0f), ER_UI_PRESET_COLOR(0.114f, 0.094f, 0.086f, 1.0f),                                                \
      ER_UI_PRESET_COLOR(0.0f, 0.74f, 0.54f, 1.0f), ER_UI_PRESET_COLOR(0.93f, 0.62f, 0.06f, 1.0f),                                                      \
      ER_UI_PRESET_COLOR(0.86f, 0.15f, 0.15f, 1.0f), ER_UI_PRESET_COLOR(0.55f, 0.43f, 0.95f, 1.0f)                                                      \
  }

static const er_ui_preset_field_t ER_UI_PRESET_FIELDS[ER_UI_PRESET_FIELD_COUNT] = {
  {"menuColor", ER_UI_PRESET_MENU_COLORS, sizeof(ER_UI_PRESET_MENU_COLORS) / sizeof(ER_UI_PRESET_MENU_COLORS[0]), ER_UI_PRESET_BITS_COMPACT},
  {"menuAccent", ER_UI_PRESET_MENU_ACCENTS, sizeof(ER_UI_PRESET_MENU_ACCENTS) / sizeof(ER_UI_PRESET_MENU_ACCENTS[0]), ER_UI_PRESET_BITS_COMPACT},
  {"radius", ER_UI_PRESET_RADII, sizeof(ER_UI_PRESET_RADII) / sizeof(ER_UI_PRESET_RADII[0]), ER_UI_PRESET_BITS_RADIUS},
  {"font", ER_UI_PRESET_FONTS, sizeof(ER_UI_PRESET_FONTS) / sizeof(ER_UI_PRESET_FONTS[0]), ER_UI_PRESET_BITS_STANDARD},
  {"iconLibrary", ER_UI_PRESET_ICON_LIBRARIES, sizeof(ER_UI_PRESET_ICON_LIBRARIES) / sizeof(ER_UI_PRESET_ICON_LIBRARIES[0]), ER_UI_PRESET_BITS_STANDARD},
  {"theme", ER_UI_PRESET_THEME_COLORS, sizeof(ER_UI_PRESET_THEME_COLORS) / sizeof(ER_UI_PRESET_THEME_COLORS[0]), ER_UI_PRESET_BITS_STANDARD},
  {"baseColor", ER_UI_PRESET_BASE_COLORS, sizeof(ER_UI_PRESET_BASE_COLORS) / sizeof(ER_UI_PRESET_BASE_COLORS[0]), ER_UI_PRESET_BITS_STANDARD},
  {"style", ER_UI_PRESET_STYLES, sizeof(ER_UI_PRESET_STYLES) / sizeof(ER_UI_PRESET_STYLES[0]), ER_UI_PRESET_BITS_STANDARD},
  {"chartColor", ER_UI_PRESET_THEME_COLORS, sizeof(ER_UI_PRESET_THEME_COLORS) / sizeof(ER_UI_PRESET_THEME_COLORS[0]), ER_UI_PRESET_BITS_STANDARD},
  {"fontHeading", ER_UI_PRESET_HEADING_FONTS, sizeof(ER_UI_PRESET_HEADING_FONTS) / sizeof(ER_UI_PRESET_HEADING_FONTS[0]), ER_UI_PRESET_BITS_HEADING_FONT}
};

static const er_ui_semantic_colors_t ER_UI_STYLE_FAMILY_COLORS[ER_UI_STYLE_FAMILY_COUNT] = {
  ER_UI_PRESET_COLORS_VEGA,
  ER_UI_PRESET_COLORS_NOVA,
  ER_UI_PRESET_COLORS_MAIA,
  ER_UI_PRESET_COLORS_LYRA,
  ER_UI_PRESET_COLORS_MIRA,
  ER_UI_PRESET_COLORS_LUMA,
  ER_UI_PRESET_COLORS_SERA
};

static const er_ui_style_family_spec_t ER_UI_STYLE_FAMILY_SPECS[ER_UI_STYLE_FAMILY_COUNT] = {
  {ER_UI_STYLE_FAMILY_VEGA, "Vega", "bIkeymG", "neutral", "structured blue-black system surface"},
  {ER_UI_STYLE_FAMILY_NOVA, "Nova", "b2fA", "neutral", "neutral graphite system surface"},
  {ER_UI_STYLE_FAMILY_MAIA, "Maia", "bbVKFP6", "neutral", "green policy and trust surface"},
  {ER_UI_STYLE_FAMILY_LYRA, "Lyra", "buFznsW", "neutral", "violet creative and agent surface"},
  {ER_UI_STYLE_FAMILY_MIRA, "Mira", "b1D0eCA4", "neutral", "neutral high-contrast default surface"},
  {ER_UI_STYLE_FAMILY_LUMA, "Luma", "b1VlIttI", "neutral", "warm finance and publishing surface"},
  {ER_UI_STYLE_FAMILY_SERA, "Sera", "b4xFeBLg4O", "taupe", "warm rose collaboration surface"}
};

static const char *const ER_UI_STYLE_TOKEN_CLASSES_BACKGROUND[] = {"bg-background"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CARD[] = {"bg-card", "bg-panel"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CARD_FOREGROUND[] = {"text-card-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_POPOVER[] = {"bg-popover"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_POPOVER_FOREGROUND[] = {"text-popover-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_MUTED[] = {"bg-muted", "bg-row"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_FOREGROUND[] = {"text-foreground", "text-text"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_MUTED_FOREGROUND[] = {"text-muted-foreground", "text-muted"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_BORDER[] = {"border-border", "border"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_PRIMARY[] = {"bg-primary", "text-primary"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_PRIMARY_FOREGROUND[] = {"text-primary-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_SECONDARY[] = {"bg-secondary"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_SECONDARY_FOREGROUND[] = {"text-secondary-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_ACCENT[] = {"bg-accent", "text-accent"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_ACCENT_FOREGROUND[] = {"text-accent-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_DESTRUCTIVE[] = {"text-destructive", "aria-invalid:border-destructive"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_DESTRUCTIVE_FOREGROUND[] = {"text-destructive-foreground"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_SUCCESS[] = {"text-success", "bg-success"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_WARNING[] = {"text-warning", "bg-warning"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_INFO[] = {"text-info", "bg-info"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_INPUT[] = {"border-input", "bg-input"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_RING[] = {"border-ring", "focus-visible:ring-ring/50"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CHART_1[] = {"bg-chart-1", "text-chart-1"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CHART_2[] = {"bg-chart-2", "text-chart-2"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CHART_3[] = {"bg-chart-3", "text-chart-3"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CHART_4[] = {"bg-chart-4", "text-chart-4"};
static const char *const ER_UI_STYLE_TOKEN_CLASSES_CHART_5[] = {"bg-chart-5", "text-chart-5"};

#define ER_UI_STYLE_TOKEN(name, kind, css_var, classes, role) \
  {(name), (kind), (css_var), (classes), sizeof(classes) / sizeof((classes)[0]), (role)}

static const er_ui_extracted_style_token_t ER_UI_EXTRACTED_STYLE_TOKENS[] = {
  ER_UI_STYLE_TOKEN("background", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--background", ER_UI_STYLE_TOKEN_CLASSES_BACKGROUND, "page and canvas background"),
  ER_UI_STYLE_TOKEN("card", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--card", ER_UI_STYLE_TOKEN_CLASSES_CARD, "dashboard cards, modals, and framed tools"),
  ER_UI_STYLE_TOKEN("card foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--card-foreground", ER_UI_STYLE_TOKEN_CLASSES_CARD_FOREGROUND,
                    "primary text on card surfaces"),
  ER_UI_STYLE_TOKEN("popover", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--popover", ER_UI_STYLE_TOKEN_CLASSES_POPOVER,
                    "floating menus, tooltips, and anchored overlays"),
  ER_UI_STYLE_TOKEN("popover foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--popover-foreground", ER_UI_STYLE_TOKEN_CLASSES_POPOVER_FOREGROUND,
                    "primary text inside floating overlays"),
  ER_UI_STYLE_TOKEN("muted", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--muted", ER_UI_STYLE_TOKEN_CLASSES_MUTED,
                    "secondary rows, icon wells, subdued controls"),
  ER_UI_STYLE_TOKEN("foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--foreground", ER_UI_STYLE_TOKEN_CLASSES_FOREGROUND, "primary text"),
  ER_UI_STYLE_TOKEN("muted foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--muted-foreground", ER_UI_STYLE_TOKEN_CLASSES_MUTED_FOREGROUND,
                    "labels, descriptions, helper text"),
  ER_UI_STYLE_TOKEN("border", ER_UI_EXTRACTED_STYLE_TOKEN_BORDER, "--border", ER_UI_STYLE_TOKEN_CLASSES_BORDER,
                    "card, input, separator, and control outlines"),
  ER_UI_STYLE_TOKEN("primary", ER_UI_EXTRACTED_STYLE_TOKEN_ACTION, "--primary", ER_UI_STYLE_TOKEN_CLASSES_PRIMARY, "main action and high-emphasis state"),
  ER_UI_STYLE_TOKEN("primary foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--primary-foreground", ER_UI_STYLE_TOKEN_CLASSES_PRIMARY_FOREGROUND,
                    "text on primary action surfaces"),
  ER_UI_STYLE_TOKEN("secondary", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--secondary", ER_UI_STYLE_TOKEN_CLASSES_SECONDARY,
                    "low-emphasis button and row surfaces"),
  ER_UI_STYLE_TOKEN("secondary foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--secondary-foreground", ER_UI_STYLE_TOKEN_CLASSES_SECONDARY_FOREGROUND,
                    "text on low-emphasis secondary surfaces"),
  ER_UI_STYLE_TOKEN("accent", ER_UI_EXTRACTED_STYLE_TOKEN_ACTION, "--accent", ER_UI_STYLE_TOKEN_CLASSES_ACCENT,
                    "hover, selected, and emphasized interactive state"),
  ER_UI_STYLE_TOKEN("accent foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--accent-foreground", ER_UI_STYLE_TOKEN_CLASSES_ACCENT_FOREGROUND,
                    "text on accent hover and selected surfaces"),
  ER_UI_STYLE_TOKEN("destructive", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--destructive", ER_UI_STYLE_TOKEN_CLASSES_DESTRUCTIVE,
                    "danger zone and validation state"),
  ER_UI_STYLE_TOKEN("destructive foreground", ER_UI_EXTRACTED_STYLE_TOKEN_TEXT, "--destructive-foreground", ER_UI_STYLE_TOKEN_CLASSES_DESTRUCTIVE_FOREGROUND,
                    "text on destructive action surfaces"),
  ER_UI_STYLE_TOKEN("success", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--success", ER_UI_STYLE_TOKEN_CLASSES_SUCCESS,
                    "verified, paid, completed, and positive receipt states"),
  ER_UI_STYLE_TOKEN("warning", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--warning", ER_UI_STYLE_TOKEN_CLASSES_WARNING, "pending, budget, and caution states"),
  ER_UI_STYLE_TOKEN("info", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--info", ER_UI_STYLE_TOKEN_CLASSES_INFO,
                    "neutral informational and policy reference states"),
  ER_UI_STYLE_TOKEN("input", ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "--input", ER_UI_STYLE_TOKEN_CLASSES_INPUT, "input border and disabled input fill"),
  ER_UI_STYLE_TOKEN("ring", ER_UI_EXTRACTED_STYLE_TOKEN_BORDER, "--ring", ER_UI_STYLE_TOKEN_CLASSES_RING, "keyboard focus and validation ring"),
  ER_UI_STYLE_TOKEN("chart 1", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--chart-1", ER_UI_STYLE_TOKEN_CLASSES_CHART_1, "first chart series color"),
  ER_UI_STYLE_TOKEN("chart 2", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--chart-2", ER_UI_STYLE_TOKEN_CLASSES_CHART_2, "second chart series color"),
  ER_UI_STYLE_TOKEN("chart 3", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--chart-3", ER_UI_STYLE_TOKEN_CLASSES_CHART_3, "third chart series color"),
  ER_UI_STYLE_TOKEN("chart 4", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--chart-4", ER_UI_STYLE_TOKEN_CLASSES_CHART_4, "fourth chart series color"),
  ER_UI_STYLE_TOKEN("chart 5", ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "--chart-5", ER_UI_STYLE_TOKEN_CLASSES_CHART_5, "fifth chart series color")
};

static bool er_ui_preset_cstr_eq(const char* a, const char* b) {
  if (!a || !b) return false;
  size_t i = 0u;
  while (a[i] != '\0' && b[i] != '\0') {
    if (a[i] != b[i]) return false;
    i++;
  }
  return a[i] == b[i];
}

static size_t er_ui_preset_cstr_len(const char* value) {
  if (!value) return 0u;
  size_t len = 0u;
  while (value[len] != '\0') len++;
  return len;
}

static const char* er_ui_preset_recipe_value(er_ui_preset_recipe_t recipe, const char* key) {
  if (er_ui_preset_cstr_eq(key, "menuColor")) return recipe.menu_color;
  if (er_ui_preset_cstr_eq(key, "menuAccent")) return recipe.menu_accent;
  if (er_ui_preset_cstr_eq(key, "radius")) return recipe.encoded_radius;
  if (er_ui_preset_cstr_eq(key, "font")) return recipe.font;
  if (er_ui_preset_cstr_eq(key, "iconLibrary")) return recipe.icon_library;
  if (er_ui_preset_cstr_eq(key, "theme")) return recipe.theme;
  if (er_ui_preset_cstr_eq(key, "baseColor")) return recipe.base_color;
  if (er_ui_preset_cstr_eq(key, "style")) return recipe.style;
  if (er_ui_preset_cstr_eq(key, "chartColor")) return recipe.chart_color;
  if (er_ui_preset_cstr_eq(key, "fontHeading")) return recipe.font_heading;
  return 0;
}

static bool er_ui_preset_lookup_index(const char* const* values, size_t count, const char* selected, size_t* out_index) {
  if (!out_index) return false;
  for (size_t i = 0u; i < count; ++i) {
    if (er_ui_preset_cstr_eq(values[i], selected)) {
      *out_index = i;
      return true;
    }
  }
  return false;
}

static bool er_ui_preset_alphabet_index(char byte, size_t* out_index) {
  if (!out_index) return false;
  if (byte >= '0' && byte <= '9') {
    *out_index = (size_t)(byte - '0');
    return true;
  }
  if (byte >= 'A' && byte <= 'Z') {
    *out_index = (size_t)(byte - 'A') + ER_UI_PRESET_BASE62_UPPER_OFFSET;
    return true;
  }
  if (byte >= 'a' && byte <= 'z') {
    *out_index = (size_t)(byte - 'a') + ER_UI_PRESET_BASE62_LOWER_OFFSET;
    return true;
  }
  return false;
}

static er_ui_status_t er_ui_preset_encode_base62(uint64_t value, char* out, size_t capacity, size_t* out_len) {
  char reversed[ER_UI_PRESET_BASE62_BUFFER_LEN];
  size_t len = 0u;
  if (!out || !out_len || capacity == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (value == 0u) {
    if (capacity < ER_UI_PRESET_MIN_CODE_LEN) return ER_UI_ERR_OOM;
    out[0] = ER_UI_PRESET_ALPHABET[0];
    out[1] = '\0';
    *out_len = ER_UI_PRESET_PREFIX_LEN;
    return ER_UI_OK;
  }
  while (value > 0u) {
    if (len >= sizeof(reversed)) return ER_UI_ERR_INVALID_ARGUMENT;
    reversed[len] = ER_UI_PRESET_ALPHABET[value % ER_UI_PRESET_BASE62]; //@optimizer-ignore base62 encoding requires repeated modulo by radix
    value /= ER_UI_PRESET_BASE62; //@optimizer-ignore base62 encoding requires repeated division by radix
    len++;
  }
  if (capacity < len + 1u) return ER_UI_ERR_OOM;
  for (size_t i = 0u; i < len; ++i) out[i] = reversed[len - i - 1u];
  out[len] = '\0';
  *out_len = len;
  return ER_UI_OK;
}

static bool er_ui_preset_decode_base62(const char* value, uint64_t* out_value) {
  if (!value || !out_value) return false;
  uint64_t decoded = 0u;
  for (size_t i = 0u; value[i] != '\0'; ++i) {
    size_t index = 0u;
    if (!er_ui_preset_alphabet_index(value[i], &index)) return false;
    decoded = decoded * ER_UI_PRESET_BASE62 + (uint64_t)index; //@optimizer-ignore base62 decoding requires repeated multiply by radix
  }
  *out_value = decoded;
  return true;
}

er_ui_preset_recipe_t er_ui_preset_recipe_for_style_family(er_ui_style_family_t family) {
  switch (family) {
    case ER_UI_STYLE_FAMILY_VEGA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_VEGA;
    case ER_UI_STYLE_FAMILY_MAIA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_MAIA;
    case ER_UI_STYLE_FAMILY_LYRA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_LYRA;
    case ER_UI_STYLE_FAMILY_MIRA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_MIRA;
    case ER_UI_STYLE_FAMILY_LUMA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_LUMA;
    case ER_UI_STYLE_FAMILY_SERA:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_SERA;
    case ER_UI_STYLE_FAMILY_NOVA:
    default:
      return (er_ui_preset_recipe_t)ER_UI_PRESET_RECIPE_NOVA;
  }
}

er_ui_semantic_colors_t er_ui_colors_for_style_family(er_ui_style_family_t family) {
  if ((size_t)family >= ER_UI_STYLE_FAMILY_COUNT) return ER_UI_STYLE_FAMILY_COLORS[ER_UI_STYLE_FAMILY_NOVA];
  return ER_UI_STYLE_FAMILY_COLORS[family];
}

size_t er_ui_style_family_spec_count(void) {
  return ER_UI_STYLE_FAMILY_COUNT;
}

const er_ui_style_family_spec_t* er_ui_style_family_spec_at(size_t index) {
  if (index >= er_ui_style_family_spec_count()) return 0;
  return &ER_UI_STYLE_FAMILY_SPECS[index];
}

const er_ui_style_family_spec_t* er_ui_style_family_spec_for_family(er_ui_style_family_t family) {
  if ((size_t)family >= ER_UI_STYLE_FAMILY_COUNT) return 0;
  return &ER_UI_STYLE_FAMILY_SPECS[family];
}

const char* er_ui_extracted_style_token_kind_label(er_ui_extracted_style_token_kind_t kind) {
  switch (kind) {
    case ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE: return "Surface";
    case ER_UI_EXTRACTED_STYLE_TOKEN_TEXT: return "Text";
    case ER_UI_EXTRACTED_STYLE_TOKEN_BORDER: return "Border";
    case ER_UI_EXTRACTED_STYLE_TOKEN_ACTION: return "Action";
    case ER_UI_EXTRACTED_STYLE_TOKEN_STATUS: return "Status";
    default: return "";
  }
}

size_t er_ui_extracted_style_token_count(void) {
  return sizeof(ER_UI_EXTRACTED_STYLE_TOKENS) / sizeof(ER_UI_EXTRACTED_STYLE_TOKENS[0]);
}

const er_ui_extracted_style_token_t* er_ui_extracted_style_token_at(size_t index) {
  if (index >= er_ui_extracted_style_token_count()) return 0;
  return &ER_UI_EXTRACTED_STYLE_TOKENS[index];
}

bool er_ui_extracted_style_token_has_class(const er_ui_extracted_style_token_t* token, const char* class_name) {
  if (!token || !class_name) return false;
  for (size_t i = 0u; i < token->class_name_count; ++i) {
    if (er_ui_preset_cstr_eq(token->class_names[i], class_name)) return true;
  }
  return false;
}

er_ui_status_t er_ui_preset_encode(er_ui_preset_recipe_t recipe, char* out, size_t capacity, size_t* out_len) {
  uint64_t value = 0u;
  uint32_t shift = 0u;
  char base62[ER_UI_PRESET_BASE62_BUFFER_LEN];
  size_t base62_len = 0u;
  if (!out || !out_len || capacity < ER_UI_PRESET_MIN_CODE_LEN) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < ER_UI_PRESET_FIELD_COUNT; ++i) {
    size_t index = 0u;
    const char* selected = er_ui_preset_recipe_value(recipe, ER_UI_PRESET_FIELDS[i].key);
    if (!er_ui_preset_lookup_index(ER_UI_PRESET_FIELDS[i].values, ER_UI_PRESET_FIELDS[i].value_count, selected, &index)) return ER_UI_ERR_INVALID_ARGUMENT;
    value += ((uint64_t)index) << shift;
    shift += ER_UI_PRESET_FIELDS[i].bits;
  }
  er_ui_status_t status = er_ui_preset_encode_base62(value, base62, sizeof(base62), &base62_len);
  if (status != ER_UI_OK) return status;
  if (capacity < base62_len + 2u) return ER_UI_ERR_OOM;
  out[0] = 'b';
  for (size_t i = 0u; i < base62_len; ++i) out[i + ER_UI_PRESET_PREFIX_LEN] = base62[i];
  out[base62_len + ER_UI_PRESET_PREFIX_LEN] = '\0';
  *out_len = base62_len + ER_UI_PRESET_PREFIX_LEN;
  return ER_UI_OK;
}

//@optimizer-ignore-function preset-code decode must walk the fixed component bitfield schema in wire order
er_ui_status_t er_ui_preset_decode(const char* preset_code, er_ui_preset_recipe_t* out_recipe) {
  if (!preset_code || !out_recipe || preset_code[0] != 'b') return ER_UI_ERR_INVALID_ARGUMENT;
  uint64_t value = 0u;
  if (!er_ui_preset_decode_base62(preset_code + ER_UI_PRESET_PREFIX_LEN, &value)) return ER_UI_ERR_INVALID_ARGUMENT;
  uint32_t shift = 0u;
  er_ui_preset_recipe_t decoded = er_ui_preset_recipe_for_style_family(ER_UI_STYLE_FAMILY_NOVA);
  for (size_t i = 0u; i < ER_UI_PRESET_FIELD_COUNT; ++i) {
    uint64_t mask = (((uint64_t)1u) << ER_UI_PRESET_FIELDS[i].bits) - 1u;
    size_t index = (size_t)((value >> shift) & mask);
    if (index >= ER_UI_PRESET_FIELDS[i].value_count) return ER_UI_ERR_INVALID_ARGUMENT;
    const char* selected = ER_UI_PRESET_FIELDS[i].values[index];
    switch (i) {
      case ER_UI_PRESET_FIELD_MENU_COLOR:
        decoded.menu_color = selected;
        break;
      case ER_UI_PRESET_FIELD_MENU_ACCENT:
        decoded.menu_accent = selected;
        break;
      case ER_UI_PRESET_FIELD_RADIUS:
        decoded.encoded_radius = selected;
        decoded.effective_radius =
          er_ui_preset_cstr_eq(decoded.style, "lyra") || er_ui_preset_cstr_eq(decoded.style, "sera") ? ER_UI_PRESET_RADIUS_NONE_STYLE : selected;
        break;
      case ER_UI_PRESET_FIELD_FONT:
        decoded.font = selected;
        break;
      case ER_UI_PRESET_FIELD_ICON_LIBRARY:
        decoded.icon_library = selected;
        break;
      case ER_UI_PRESET_FIELD_THEME:
        decoded.theme = selected;
        break;
      case ER_UI_PRESET_FIELD_BASE_COLOR:
        decoded.base_color = selected;
        break;
      case ER_UI_PRESET_FIELD_STYLE:
        decoded.style = selected;
        if (er_ui_preset_cstr_eq(selected, "lyra") || er_ui_preset_cstr_eq(selected, "sera")) decoded.effective_radius = ER_UI_PRESET_RADIUS_NONE_STYLE;
        break;
      case ER_UI_PRESET_FIELD_CHART_COLOR:
        decoded.chart_color = selected;
        break;
      case ER_UI_PRESET_FIELD_FONT_HEADING:
        decoded.font_heading = selected;
        break;
      default:
        return ER_UI_ERR_INVALID_ARGUMENT;
    }
    shift += ER_UI_PRESET_FIELDS[i].bits;
  }
  *out_recipe = decoded;
  return ER_UI_OK;
}

bool er_ui_preset_recipe_matches_code(er_ui_preset_recipe_t recipe, const char* preset_code) {
  char encoded[ER_UI_PRESET_CODE_MAX_LEN];
  size_t len = 0u;
  if (er_ui_preset_encode(recipe, encoded, sizeof(encoded), &len) != ER_UI_OK) return false;
  (void)len;
  return er_ui_preset_cstr_eq(encoded, preset_code);
}

bool er_ui_preset_is_code(const char* preset_code) {
  size_t len = er_ui_preset_cstr_len(preset_code);
  if (len < ER_UI_PRESET_MIN_CODE_LEN || len > ER_UI_PRESET_MAX_CODE_LEN) return false;
  if (preset_code[0] != 'b') return false;
  for (size_t i = ER_UI_PRESET_PREFIX_LEN; i < len; ++i) {
    size_t index = 0u;
    if (!er_ui_preset_alphabet_index(preset_code[i], &index)) return false;
  }
  return true;
}

static const er_ui_extracted_source_capture_t ER_UI_SOURCE_CAPTURES[] = {
  {"ui.html", true, ER_UI_STYLE_FAMILY_MIRA, "b1D0eCA4", ER_UI_PRESET_RECIPE_MIRA, "radix-mira", "original screenshot source mapped to the neutral Mira style family"},
  {"vega.html", true, ER_UI_STYLE_FAMILY_VEGA, "bIkeymG", ER_UI_PRESET_RECIPE_VEGA, "radix-vega", "blue-black style-family capture"},
  {"nova.html", true, ER_UI_STYLE_FAMILY_NOVA, "b2fA", ER_UI_PRESET_RECIPE_NOVA, "radix-nova", "graphite style-family capture"},
  {"maia.html", true, ER_UI_STYLE_FAMILY_MAIA, "bbVKFP6", ER_UI_PRESET_RECIPE_MAIA, "radix-maia", "green trust style-family capture"},
  {"lyra.html", true, ER_UI_STYLE_FAMILY_LYRA, "buFznsW", ER_UI_PRESET_RECIPE_LYRA, "radix-lyra", "violet agent style-family capture"},
  {"luma.html", true, ER_UI_STYLE_FAMILY_LUMA, "b1VlIttI", ER_UI_PRESET_RECIPE_LUMA, "radix-luma", "warm finance style-family capture"},
  {"sera.html", true, ER_UI_STYLE_FAMILY_SERA, "b4xFeBLg4O", ER_UI_PRESET_RECIPE_SERA, "radix-sera", "rose collaboration style-family capture"}
};

size_t er_ui_extracted_source_capture_count(void) {
  return sizeof(ER_UI_SOURCE_CAPTURES) / sizeof(ER_UI_SOURCE_CAPTURES[0]);
}

const er_ui_extracted_source_capture_t* er_ui_extracted_source_capture_at(size_t index) {
  if (index >= er_ui_extracted_source_capture_count()) return 0;
  return &ER_UI_SOURCE_CAPTURES[index];
}

#include "er_ui_components.h"

#include <stdint.h>

#define ER_UI_SHADCN_TEXT_CAPACITY 128u

static bool er_ui_shadcn_streq(const char* a, const char* b) {
  if (!a || !b) return false;
  while (*a && *b) { if (*a != *b) return false; a++; b++; }
  return *a == *b;
}

static bool er_ui_shadcn_list_contains(const char* const* values, size_t count, const char* value) {
  if (!values || !value) return false;
  for (size_t i = 0u; i < count; ++i) if (er_ui_shadcn_streq(values[i], value)) return true;
  return false;
}

static er_ui_status_t er_ui_shadcn_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color) {
  if (!scene || !font || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  uint32_t codepoints[ER_UI_SHADCN_TEXT_CAPACITY];
  size_t count = 0u;
  while (text[count] && count < ER_UI_SHADCN_TEXT_CAPACITY) {
    unsigned char byte = (unsigned char)text[count];
    codepoints[count] = byte < 0x80u ? (uint32_t)byte : (uint32_t)'?';
    count++;
  }
  return er_ui_scene_push_varfont_text(scene, font, codepoints, count, x, y, color);
}

static er_ui_color4_t er_ui_shadcn_button_fill(er_ui_resolved_theme_t theme, er_ui_shadcn_button_variant_t variant) {
  switch (variant) {
    case ER_UI_SHADCN_BUTTON_DESTRUCTIVE: return er_ui_color_with_alpha(theme.colors.danger, 0.18f);
    case ER_UI_SHADCN_BUTTON_OUTLINE: return er_ui_color_with_alpha(theme.colors.panel, 0.74f);
    case ER_UI_SHADCN_BUTTON_SECONDARY: return er_ui_color_with_alpha(theme.colors.row, 0.82f);
    case ER_UI_SHADCN_BUTTON_GHOST:
    case ER_UI_SHADCN_BUTTON_LINK: return er_ui_color_with_alpha(theme.colors.panel, 0.0f);
    case ER_UI_SHADCN_BUTTON_DEFAULT:
    default: return theme.colors.accent;
  }
}

static er_ui_color4_t er_ui_shadcn_button_border(er_ui_resolved_theme_t theme, er_ui_shadcn_button_variant_t variant) {
  switch (variant) {
    case ER_UI_SHADCN_BUTTON_DESTRUCTIVE: return theme.colors.danger;
    case ER_UI_SHADCN_BUTTON_DEFAULT: return theme.colors.accent;
    default: return theme.colors.border;
  }
}

static er_ui_color4_t er_ui_shadcn_button_text(er_ui_resolved_theme_t theme, er_ui_shadcn_button_variant_t variant) {
  switch (variant) {
    case ER_UI_SHADCN_BUTTON_DEFAULT: return theme.colors.accent_text;
    case ER_UI_SHADCN_BUTTON_DESTRUCTIVE: return theme.colors.danger;
    case ER_UI_SHADCN_BUTTON_GHOST:
    case ER_UI_SHADCN_BUTTON_LINK: return theme.colors.muted;
    default: return theme.colors.text;
  }
}

static er_ui_color4_t er_ui_shadcn_badge_fill(er_ui_resolved_theme_t theme, er_ui_shadcn_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_SHADCN_BADGE_SECONDARY: return er_ui_color_with_alpha(theme.colors.row, 0.86f);
    case ER_UI_SHADCN_BADGE_DESTRUCTIVE: return er_ui_color_with_alpha(theme.colors.danger, 0.18f);
    case ER_UI_SHADCN_BADGE_OUTLINE: return er_ui_color_with_alpha(theme.colors.panel, 0.0f);
    case ER_UI_SHADCN_BADGE_DEFAULT:
    default: return theme.colors.accent;
  }
}

static er_ui_color4_t er_ui_shadcn_badge_text(er_ui_resolved_theme_t theme, er_ui_shadcn_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_SHADCN_BADGE_DEFAULT: return theme.colors.accent_text;
    case ER_UI_SHADCN_BADGE_DESTRUCTIVE: return theme.colors.danger;
    default: return theme.colors.text;
  }
}

static const char* const no_variants[] = {0};
static const char* const no_keyboard[] = {0};
static const char* const static_interactions[] = {"render"};
static const char* const click_interactions[] = {"render", "click"};
static const char* const input_interactions[] = {"render", "focus", "input", "disabled"};
static const char* const disclosure_interactions[] = {"render", "open", "close", "focus", "disabled"};
static const char* const overlay_interactions[] = {"render", "trigger", "open", "close", "focus-trap"};
static const char* const menu_interactions[] = {"render", "trigger", "open", "close", "select", "disabled"};
static const char* const collection_interactions[] = {"render", "select", "keyboard-nav", "disabled"};
static const char* const drag_interactions[] = {"render", "drag", "keyboard-nav", "disabled"};
static const char* const text_input_keyboard[] = {"Tab", "Shift+Tab", "Input"};
static const char* const menu_keyboard[] = {"Enter", "Space", "Escape", "ArrowUp", "ArrowDown", "Home", "End"};
static const char* const horizontal_keyboard[] = {"Enter", "Space", "ArrowLeft", "ArrowRight", "Home", "End"};
static const char* const overlay_keyboard[] = {"Escape", "Tab", "Shift+Tab"};
static const char* const dialog_keyboard[] = {"Escape", "Tab", "Shift+Tab", "Enter"};
static const char* const input_otp_keyboard[] = {"Tab", "Shift+Tab", "ArrowLeft", "ArrowRight", "Backspace", "Input", "Paste"};
static const char* const slider_keyboard[] = {"ArrowLeft", "ArrowRight", "Home", "End", "PageUp", "PageDown"};
static const char* const button_variants[] = {"default", "destructive", "outline", "secondary", "ghost", "link"};
static const char* const badge_variants[] = {"default", "secondary", "destructive", "outline"};
static const char* const alert_variants[] = {"default", "destructive"};
static const char* const sheet_sides[] = {"top", "right", "bottom", "left"};
static const char* const field_variants[] = {"default", "invalid"};
static const char* const orientation_variants[] = {"horizontal", "vertical"};
static const char* const toast_variants[] = {"default", "destructive", "success", "warning", "info"};
static const char* const direction_variants[] = {"ltr", "rtl"};

static const char* const slots_accordion[] = {"accordion", "accordion-item", "accordion-trigger", "accordion-content"};
static const char* const states_accordion[] = {"data-state=open", "data-state=closed", "disabled"};
static const char* const slots_alert[] = {"alert", "alert-title", "alert-description"};
static const char* const states_alert[] = {"default", "destructive"};
static const char* const slots_alert_dialog[] = {"alert-dialog", "alert-dialog-trigger", "alert-dialog-content", "alert-dialog-header", "alert-dialog-footer", "alert-dialog-title", "alert-dialog-description", "alert-dialog-action", "alert-dialog-cancel"};
static const char* const states_alert_dialog[] = {"open", "closed", "focus-trap"};
static const char* const slots_aspect_ratio[] = {"aspect-ratio"};
static const char* const states_aspect_ratio[] = {0};
static const char* const slots_avatar[] = {"avatar", "avatar-image", "avatar-fallback"};
static const char* const states_avatar[] = {"loaded", "fallback"};
static const char* const slots_badge[] = {"badge"};
static const char* const states_badge[] = {"default", "secondary", "outline", "destructive"};
static const char* const slots_breadcrumb[] = {"breadcrumb", "breadcrumb-list", "breadcrumb-item", "breadcrumb-link", "breadcrumb-page", "breadcrumb-separator", "breadcrumb-ellipsis"};
static const char* const states_breadcrumb[] = {"current-page"};
static const char* const slots_button[] = {"button"};
static const char* const states_button[] = {"default", "destructive", "outline", "secondary", "ghost", "link", "disabled", "loading"};
static const char* const slots_button_group[] = {"button-group", "button-group-item", "button-group-separator"};
static const char* const states_button_group[] = {"horizontal", "vertical", "attached"};
static const char* const slots_calendar[] = {"calendar", "calendar-month", "calendar-day", "calendar-caption"};
static const char* const states_calendar[] = {"selected", "today", "disabled", "range-start", "range-end"};
static const char* const slots_card[] = {"card", "card-header", "card-title", "card-description", "card-content", "card-footer"};
static const char* const states_card[] = {"default", "sm"};
static const char* const slots_carousel[] = {"carousel", "carousel-content", "carousel-item", "carousel-previous", "carousel-next"};
static const char* const states_carousel[] = {"can-scroll-prev", "can-scroll-next"};
static const char* const slots_chart[] = {"chart-container", "chart-tooltip", "chart-legend"};
static const char* const states_chart[] = {"hovered", "active"};
static const char* const slots_checkbox[] = {"checkbox"};
static const char* const states_checkbox[] = {"checked", "unchecked", "indeterminate", "disabled"};
static const char* const slots_collapsible[] = {"collapsible", "collapsible-trigger", "collapsible-content"};
static const char* const states_collapsible[] = {"open", "closed", "disabled"};
static const char* const slots_combobox[] = {"combobox", "popover", "command", "command-input", "command-item"};
static const char* const states_combobox[] = {"open", "closed", "selected", "empty"};
static const char* const slots_command[] = {"command", "command-input", "command-list", "command-group", "command-item", "command-empty"};
static const char* const states_command[] = {"selected", "empty", "disabled"};
static const char* const slots_context_menu[] = {"context-menu", "context-menu-trigger", "context-menu-content", "context-menu-item"};
static const char* const states_context_menu[] = {"open", "closed", "checked", "disabled"};
static const char* const slots_data_table[] = {"table", "table-header", "table-body", "table-row", "table-cell"};
static const char* const states_data_table[] = {"sorted", "selected", "loading", "empty"};
static const char* const slots_date_picker[] = {"popover", "calendar", "button", "field"};
static const char* const states_date_picker[] = {"open", "selected", "empty"};
static const char* const slots_dialog[] = {"dialog", "dialog-trigger", "dialog-content", "dialog-header", "dialog-footer"};
static const char* const states_dialog[] = {"open", "closed", "focus-trap"};
static const char* const slots_direction[] = {"direction-provider"};
static const char* const states_direction[] = {"ltr", "rtl"};
static const char* const slots_drawer[] = {"drawer", "drawer-trigger", "drawer-content", "drawer-header", "drawer-footer"};
static const char* const states_drawer[] = {"open", "closed", "dragging"};
static const char* const slots_dropdown_menu[] = {"dropdown-menu", "dropdown-menu-trigger", "dropdown-menu-content", "dropdown-menu-item"};
static const char* const states_dropdown_menu[] = {"open", "closed", "checked", "disabled"};
static const char* const slots_empty[] = {"empty", "empty-header", "empty-icon", "empty-title", "empty-description", "empty-content"};
static const char* const states_empty[] = {"default", "loading"};
static const char* const slots_field[] = {"field", "field-label", "field-title", "field-description", "field-error"};
static const char* const states_field[] = {"invalid", "disabled", "required"};
static const char* const slots_hover_card[] = {"hover-card", "hover-card-trigger", "hover-card-content"};
static const char* const states_hover_card[] = {"open", "closed"};
static const char* const slots_input[] = {"input"};
static const char* const states_input[] = {"placeholder", "focus", "disabled", "invalid"};
static const char* const slots_input_group[] = {"input-group", "input-group-input", "input-group-addon", "input-group-button"};
static const char* const states_input_group[] = {"focus-within", "disabled", "invalid"};
static const char* const slots_input_otp[] = {"input-otp", "input-otp-group", "input-otp-slot", "input-otp-separator"};
static const char* const states_input_otp[] = {"active", "filled", "disabled"};
static const char* const slots_item[] = {"item", "item-media", "item-content", "item-title", "item-description", "item-actions"};
static const char* const states_item[] = {"selected", "disabled"};
static const char* const slots_kbd[] = {"kbd"};
static const char* const states_kbd[] = {0};
static const char* const slots_label[] = {"label"};
static const char* const states_label[] = {"disabled"};
static const char* const slots_menubar[] = {"menubar", "menubar-menu", "menubar-trigger", "menubar-content", "menubar-item"};
static const char* const states_menubar[] = {"open", "closed", "checked", "disabled"};
static const char* const slots_native_select[] = {"native-select"};
static const char* const states_native_select[] = {"disabled", "invalid"};
static const char* const slots_navigation_menu[] = {"navigation-menu", "navigation-menu-list", "navigation-menu-item", "navigation-menu-content"};
static const char* const states_navigation_menu[] = {"open", "closed", "active"};
static const char* const slots_pagination[] = {"pagination", "pagination-content", "pagination-item", "pagination-link"};
static const char* const states_pagination[] = {"active", "disabled"};
static const char* const slots_popover[] = {"popover", "popover-trigger", "popover-content", "popover-anchor"};
static const char* const states_popover[] = {"open", "closed"};
static const char* const slots_progress[] = {"progress", "progress-indicator"};
static const char* const states_progress[] = {"determinate", "indeterminate"};
static const char* const slots_radio_group[] = {"radio-group", "radio-group-item"};
static const char* const states_radio_group[] = {"checked", "unchecked", "disabled"};
static const char* const slots_resizable[] = {"resizable-panel-group", "resizable-panel", "resizable-handle"};
static const char* const states_resizable[] = {"dragging", "horizontal", "vertical"};
static const char* const slots_scroll_area[] = {"scroll-area", "scroll-area-viewport", "scroll-area-scrollbar", "scroll-area-thumb"};
static const char* const states_scroll_area[] = {"scrolling", "horizontal", "vertical"};
static const char* const slots_select[] = {"select", "select-trigger", "select-content", "select-item", "select-value"};
static const char* const states_select[] = {"open", "closed", "selected", "disabled"};
static const char* const slots_separator[] = {"separator"};
static const char* const states_separator[] = {"horizontal", "vertical"};
static const char* const slots_sheet[] = {"sheet", "sheet-trigger", "sheet-content", "sheet-header", "sheet-footer"};
static const char* const states_sheet[] = {"open", "closed", "side-top", "side-right", "side-bottom", "side-left"};
static const char* const slots_sidebar[] = {"sidebar", "sidebar-header", "sidebar-content", "sidebar-footer", "sidebar-menu"};
static const char* const states_sidebar[] = {"expanded", "collapsed", "mobile", "active"};
static const char* const slots_skeleton[] = {"skeleton"};
static const char* const states_skeleton[] = {"loading"};
static const char* const slots_slider[] = {"slider", "slider-track", "slider-range", "slider-thumb"};
static const char* const states_slider[] = {"dragging", "disabled"};
static const char* const slots_sonner[] = {"toaster", "toast", "toast-title", "toast-description", "toast-action"};
static const char* const states_sonner[] = {"success", "info", "warning", "error", "loading"};
static const char* const slots_switch[] = {"switch", "switch-thumb"};
static const char* const states_switch[] = {"checked", "unchecked", "disabled"};
static const char* const slots_table[] = {"table", "table-header", "table-body", "table-footer", "table-row", "table-cell"};
static const char* const states_table[] = {"selected", "sortable"};
static const char* const slots_tabs[] = {"tabs", "tabs-list", "tabs-trigger", "tabs-content"};
static const char* const states_tabs[] = {"active", "inactive", "disabled"};
static const char* const slots_textarea[] = {"textarea"};
static const char* const states_textarea[] = {"placeholder", "focus", "disabled", "invalid"};
static const char* const slots_toast[] = {"toast", "toast-title", "toast-description", "toast-action", "toast-close"};
static const char* const states_toast[] = {"open", "closed", "success", "destructive"};
static const char* const slots_toggle[] = {"toggle"};
static const char* const states_toggle[] = {"pressed", "unpressed", "disabled"};
static const char* const slots_toggle_group[] = {"toggle-group", "toggle-group-item"};
static const char* const states_toggle_group[] = {"single", "multiple", "pressed", "disabled"};
static const char* const slots_tooltip[] = {"tooltip", "tooltip-trigger", "tooltip-content"};
static const char* const states_tooltip[] = {"open", "closed", "side-top", "side-right", "side-bottom", "side-left"};

static const er_ui_shadcn_demo_spec_t shadcn_demo_components[] = {
  {"Accordion", "accordion", "/docs/components/accordion", ER_UI_SHADCN_CATEGORY_LAYOUT, "Accordion", "accordion_node", slots_accordion, 4u, states_accordion, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Alert", "alert", "/docs/components/alert", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Alert", "alert_node", slots_alert, 3u, states_alert, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Alert Dialog", "alert-dialog", "/docs/components/alert-dialog", ER_UI_SHADCN_CATEGORY_OVERLAY, "AlertDialog", "alert_dialog_node", slots_alert_dialog, 9u, states_alert_dialog, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Aspect Ratio", "aspect-ratio", "/docs/components/aspect-ratio", ER_UI_SHADCN_CATEGORY_MEDIA, "AspectRatio", "aspect_ratio_node", slots_aspect_ratio, 1u, states_aspect_ratio, 0u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Avatar", "avatar", "/docs/components/avatar", ER_UI_SHADCN_CATEGORY_DATA_DISPLAY, "Avatar", "avatar_node", slots_avatar, 3u, states_avatar, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Badge", "badge", "/docs/components/badge", ER_UI_SHADCN_CATEGORY_FOUNDATION, "Badge", "badge", slots_badge, 1u, states_badge, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Breadcrumb", "breadcrumb", "/docs/components/breadcrumb", ER_UI_SHADCN_CATEGORY_NAVIGATION, "Breadcrumb", "breadcrumb", slots_breadcrumb, 7u, states_breadcrumb, 1u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Button", "button", "/docs/components/button", ER_UI_SHADCN_CATEGORY_FOUNDATION, "Button", "button", slots_button, 1u, states_button, 8u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Button Group", "button-group", "/docs/components/button-group", ER_UI_SHADCN_CATEGORY_FOUNDATION, "ButtonGroup", "button_group_node", slots_button_group, 3u, states_button_group, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Calendar", "calendar", "/docs/components/calendar", ER_UI_SHADCN_CATEGORY_FORM, "Calendar", "calendar_node", slots_calendar, 4u, states_calendar, 5u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Card", "card", "/docs/components/card", ER_UI_SHADCN_CATEGORY_LAYOUT, "Card", "card", slots_card, 6u, states_card, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Carousel", "carousel", "/docs/components/carousel", ER_UI_SHADCN_CATEGORY_MEDIA, "Carousel", "carousel_node", slots_carousel, 5u, states_carousel, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Chart", "chart", "/docs/components/chart", ER_UI_SHADCN_CATEGORY_DATA_DISPLAY, "Chart", "chart_node", slots_chart, 3u, states_chart, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Checkbox", "checkbox", "/docs/components/checkbox", ER_UI_SHADCN_CATEGORY_FORM, "Checkbox", "checkbox", slots_checkbox, 1u, states_checkbox, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Collapsible", "collapsible", "/docs/components/collapsible", ER_UI_SHADCN_CATEGORY_LAYOUT, "Collapsible", "collapsible_node", slots_collapsible, 3u, states_collapsible, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Combobox", "combobox", "/docs/components/combobox", ER_UI_SHADCN_CATEGORY_FORM, "Combobox", "combobox_node", slots_combobox, 5u, states_combobox, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Command", "command", "/docs/components/command", ER_UI_SHADCN_CATEGORY_OVERLAY, "Command", "command_palette", slots_command, 6u, states_command, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Context Menu", "context-menu", "/docs/components/context-menu", ER_UI_SHADCN_CATEGORY_OVERLAY, "ContextMenu", "context_menu_node", slots_context_menu, 4u, states_context_menu, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Data Table", "data-table", "/docs/components/data-table", ER_UI_SHADCN_CATEGORY_DATA_DISPLAY, "DataTable", "data_table_node", slots_data_table, 5u, states_data_table, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Date Picker", "date-picker", "/docs/components/date-picker", ER_UI_SHADCN_CATEGORY_FORM, "DatePicker", "date_picker_node", slots_date_picker, 4u, states_date_picker, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Dialog", "dialog", "/docs/components/dialog", ER_UI_SHADCN_CATEGORY_OVERLAY, "Dialog", "dialog", slots_dialog, 5u, states_dialog, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Direction", "direction", "/docs/components/direction", ER_UI_SHADCN_CATEGORY_FOUNDATION, "DirectionProvider", "direction_node", slots_direction, 1u, states_direction, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Drawer", "drawer", "/docs/components/drawer", ER_UI_SHADCN_CATEGORY_OVERLAY, "Drawer", "drawer_node", slots_drawer, 5u, states_drawer, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Dropdown Menu", "dropdown-menu", "/docs/components/dropdown-menu", ER_UI_SHADCN_CATEGORY_OVERLAY, "DropdownMenu", "dropdown_menu_node", slots_dropdown_menu, 4u, states_dropdown_menu, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Empty", "empty", "/docs/components/empty", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Empty", "empty_state", slots_empty, 6u, states_empty, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Field", "field", "/docs/components/field", ER_UI_SHADCN_CATEGORY_FORM, "Field", "field_node", slots_field, 5u, states_field, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Hover Card", "hover-card", "/docs/components/hover-card", ER_UI_SHADCN_CATEGORY_OVERLAY, "HoverCard", "hover_card_node", slots_hover_card, 3u, states_hover_card, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Input", "input", "/docs/components/input", ER_UI_SHADCN_CATEGORY_FORM, "Input", "field_node", slots_input, 1u, states_input, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Input Group", "input-group", "/docs/components/input-group", ER_UI_SHADCN_CATEGORY_FORM, "InputGroup", "input_group_node", slots_input_group, 4u, states_input_group, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Input OTP", "input-otp", "/docs/components/input-otp", ER_UI_SHADCN_CATEGORY_FORM, "InputOTP", "input_otp_node", slots_input_otp, 4u, states_input_otp, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Item", "item", "/docs/components/item", ER_UI_SHADCN_CATEGORY_DATA_DISPLAY, "Item", "list_row_node", slots_item, 6u, states_item, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Kbd", "kbd", "/docs/components/kbd", ER_UI_SHADCN_CATEGORY_FOUNDATION, "Kbd", "kbd_node", slots_kbd, 1u, states_kbd, 0u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Label", "label", "/docs/components/label", ER_UI_SHADCN_CATEGORY_FORM, "Label", "text", slots_label, 1u, states_label, 1u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Menubar", "menubar", "/docs/components/menubar", ER_UI_SHADCN_CATEGORY_NAVIGATION, "Menubar", "menubar_node", slots_menubar, 5u, states_menubar, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Native Select", "native-select", "/docs/components/native-select", ER_UI_SHADCN_CATEGORY_FORM, "NativeSelect", "select_node", slots_native_select, 1u, states_native_select, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Navigation Menu", "navigation-menu", "/docs/components/navigation-menu", ER_UI_SHADCN_CATEGORY_NAVIGATION, "NavigationMenu", "navigation_menu_node", slots_navigation_menu, 4u, states_navigation_menu, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Pagination", "pagination", "/docs/components/pagination", ER_UI_SHADCN_CATEGORY_NAVIGATION, "Pagination", "pagination_node", slots_pagination, 4u, states_pagination, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Popover", "popover", "/docs/components/popover", ER_UI_SHADCN_CATEGORY_OVERLAY, "Popover", "popover_node", slots_popover, 4u, states_popover, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Progress", "progress", "/docs/components/progress", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Progress", "progress_bar_node", slots_progress, 2u, states_progress, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Radio Group", "radio-group", "/docs/components/radio-group", ER_UI_SHADCN_CATEGORY_FORM, "RadioGroup", "radio", slots_radio_group, 2u, states_radio_group, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Resizable", "resizable", "/docs/components/resizable", ER_UI_SHADCN_CATEGORY_LAYOUT, "Resizable", "resizable_node", slots_resizable, 3u, states_resizable, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Scroll Area", "scroll-area", "/docs/components/scroll-area", ER_UI_SHADCN_CATEGORY_LAYOUT, "ScrollArea", "scroll_area", slots_scroll_area, 4u, states_scroll_area, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Select", "select", "/docs/components/select", ER_UI_SHADCN_CATEGORY_FORM, "Select", "select_node", slots_select, 5u, states_select, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Separator", "separator", "/docs/components/separator", ER_UI_SHADCN_CATEGORY_LAYOUT, "Separator", "divider", slots_separator, 1u, states_separator, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Sheet", "sheet", "/docs/components/sheet", ER_UI_SHADCN_CATEGORY_OVERLAY, "Sheet", "sheet_node", slots_sheet, 5u, states_sheet, 6u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Sidebar", "sidebar", "/docs/components/sidebar", ER_UI_SHADCN_CATEGORY_NAVIGATION, "Sidebar", "sidebar_node", slots_sidebar, 5u, states_sidebar, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Skeleton", "skeleton", "/docs/components/skeleton", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Skeleton", "skeleton", slots_skeleton, 1u, states_skeleton, 1u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Slider", "slider", "/docs/components/slider", ER_UI_SHADCN_CATEGORY_FORM, "Slider", "slider_node", slots_slider, 4u, states_slider, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Sonner", "sonner", "/docs/components/sonner", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Sonner", "toast", slots_sonner, 5u, states_sonner, 5u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Switch", "switch", "/docs/components/switch", ER_UI_SHADCN_CATEGORY_FORM, "Switch", "toggle_node", slots_switch, 2u, states_switch, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Table", "table", "/docs/components/table", ER_UI_SHADCN_CATEGORY_DATA_DISPLAY, "Table", "table_node", slots_table, 6u, states_table, 2u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Tabs", "tabs", "/docs/components/tabs", ER_UI_SHADCN_CATEGORY_NAVIGATION, "Tabs", "tabs_node", slots_tabs, 4u, states_tabs, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Textarea", "textarea", "/docs/components/textarea", ER_UI_SHADCN_CATEGORY_FORM, "Textarea", "text_area_node", slots_textarea, 1u, states_textarea, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Toast", "toast", "/docs/components/toast", ER_UI_SHADCN_CATEGORY_FEEDBACK, "Toast", "toast", slots_toast, 5u, states_toast, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Toggle", "toggle", "/docs/components/toggle", ER_UI_SHADCN_CATEGORY_FOUNDATION, "Toggle", "toggle_node", slots_toggle, 1u, states_toggle, 3u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Toggle Group", "toggle-group", "/docs/components/toggle-group", ER_UI_SHADCN_CATEGORY_FOUNDATION, "ToggleGroup", "toggle_group_node", slots_toggle_group, 2u, states_toggle_group, 4u, ER_UI_SHADCN_STATUS_EXACT_PORT},
  {"Tooltip", "tooltip", "/docs/components/tooltip", ER_UI_SHADCN_CATEGORY_OVERLAY, "Tooltip", "tooltip", slots_tooltip, 3u, states_tooltip, 6u, ER_UI_SHADCN_STATUS_EXACT_PORT},
};

const char* er_ui_shadcn_demo_category_label(er_ui_shadcn_demo_category_t category) {
  switch (category) {
    case ER_UI_SHADCN_CATEGORY_FOUNDATION: return "Foundation";
    case ER_UI_SHADCN_CATEGORY_FORM: return "Form";
    case ER_UI_SHADCN_CATEGORY_OVERLAY: return "Overlay";
    case ER_UI_SHADCN_CATEGORY_NAVIGATION: return "Navigation";
    case ER_UI_SHADCN_CATEGORY_DATA_DISPLAY: return "Data Display";
    case ER_UI_SHADCN_CATEGORY_FEEDBACK: return "Feedback";
    case ER_UI_SHADCN_CATEGORY_LAYOUT: return "Layout";
    case ER_UI_SHADCN_CATEGORY_MEDIA: return "Media";
    default: return "";
  }
}

const char* er_ui_shadcn_demo_status_label(er_ui_shadcn_demo_status_t status) {
  switch (status) {
    case ER_UI_SHADCN_STATUS_CATALOGED: return "Cataloged";
    case ER_UI_SHADCN_STATUS_NATIVE_PRIMITIVE: return "Native primitive";
    case ER_UI_SHADCN_STATUS_EXACT_PORT: return "Exact port";
    default: return "";
  }
}

const char* er_ui_shadcn_resolve_kind_label(er_ui_shadcn_resolve_kind_t kind) {
  switch (kind) {
    case ER_UI_SHADCN_RESOLVE_SLUG: return "Slug";
    case ER_UI_SHADCN_RESOLVE_SOURCE_COMPONENT: return "Source component";
    case ER_UI_SHADCN_RESOLVE_MODULE_PATH: return "Module path";
    case ER_UI_SHADCN_RESOLVE_SLOT: return "Slot";
    default: return "";
  }
}

const er_ui_shadcn_demo_spec_t* er_ui_shadcn_demo_at(size_t index) {
  return index < ER_UI_SHADCN_DEMO_COUNT ? &shadcn_demo_components[index] : 0;
}

size_t er_ui_shadcn_demo_count(void) { return ER_UI_SHADCN_DEMO_COUNT; }

bool er_ui_shadcn_demo_has_native_renderer(const er_ui_shadcn_demo_spec_t* spec) {
  return spec && (spec->status == ER_UI_SHADCN_STATUS_NATIVE_PRIMITIVE || spec->status == ER_UI_SHADCN_STATUS_EXACT_PORT);
}

bool er_ui_shadcn_demo_is_exact_port(const er_ui_shadcn_demo_spec_t* spec) {
  return spec && spec->status == ER_UI_SHADCN_STATUS_EXACT_PORT;
}

bool er_ui_shadcn_demo_uses_slot(const er_ui_shadcn_demo_spec_t* spec, const char* slot) {
  return spec && er_ui_shadcn_list_contains(spec->slots, spec->slot_count, slot);
}

bool er_ui_shadcn_demo_uses_state(const er_ui_shadcn_demo_spec_t* spec, const char* state) {
  return spec && er_ui_shadcn_list_contains(spec->states, spec->state_count, state);
}

const er_ui_shadcn_demo_spec_t* er_ui_shadcn_find_demo_by_slug(const char* slug) {
  for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (er_ui_shadcn_streq(shadcn_demo_components[i].slug, slug)) return &shadcn_demo_components[i];
  return 0;
}

const er_ui_shadcn_demo_spec_t* er_ui_shadcn_find_demo_by_source_component(const char* source_component) {
  for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (er_ui_shadcn_streq(shadcn_demo_components[i].source_component, source_component)) return &shadcn_demo_components[i];
  return 0;
}

static bool er_ui_shadcn_is_upper(char c) { return c >= 'A' && c <= 'Z'; }
static char er_ui_shadcn_lower(char c) { return er_ui_shadcn_is_upper(c) ? (char)(c + 32) : c; }

static bool er_ui_shadcn_normalize_identifier(const char* identifier, char* out, size_t cap, bool* out_from_path) {
  if (!identifier || !out || cap == 0u || !out_from_path) return false;
  const char* start = identifier;
  while (*start == ' ' || *start == '\t' || *start == '\n' || *start == '\r') start++;
  const char* end = start;
  while (*end) end++;
  while (end > start && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\n' || end[-1] == '\r')) end--;
  if ((size_t)(end - start) >= 10u && start[0]=='d' && start[1]=='a' && start[2]=='t' && start[3]=='a' && start[4]=='-' && start[5]=='s' && start[6]=='l' && start[7]=='o' && start[8]=='t' && start[9]=='=') {
    start += 10u;
    while (start < end && (*start == '\"' || *start == '\'')) start++;
    while (end > start && (end[-1] == '\"' || end[-1] == '\'')) end--;
  }
  *out_from_path = false;
  const char* last = start;
  for (const char* p = start; p < end; ++p) {
    if (*p == '/') { *out_from_path = true; last = p + 1; }
  }
  start = last;
  const char* suffixes[] = {".tsx", ".ts", ".jsx", ".js"};
  for (size_t i = 0u; i < 4u; ++i) {
    const char* suffix = suffixes[i];
    size_t suffix_len = 0u;
    while (suffix[suffix_len]) suffix_len++;
    if ((size_t)(end - start) > suffix_len) {
      bool match = true;
      for (size_t j = 0u; j < suffix_len; ++j) if (end[-(int)suffix_len + (int)j] != suffix[j]) match = false;
      if (match) { end -= suffix_len; break; }
    }
  }
  bool needs_kebab = false;
  for (const char* p = start; p < end; ++p) if (er_ui_shadcn_is_upper(*p) || *p == '_' || *p == ' ') needs_kebab = true;
  size_t n = 0u;
  bool previous_was_separator = true;
  for (const char* p = start; p < end; ++p) {
    char ch = *p;
    if (needs_kebab && (ch == '_' || ch == ' ')) {
      if (!previous_was_separator) { if (n + 1u >= cap) return false; out[n++] = '-'; }
      previous_was_separator = true;
      continue;
    }
    if (needs_kebab && er_ui_shadcn_is_upper(ch)) {
      if (!previous_was_separator) { if (n + 1u >= cap) return false; out[n++] = '-'; }
      if (n + 1u >= cap) return false;
      out[n++] = er_ui_shadcn_lower(ch);
      previous_was_separator = false;
      continue;
    }
    if (n + 1u >= cap) return false;
    out[n++] = er_ui_shadcn_lower(ch);
    previous_was_separator = ch == '-';
  }
  out[n] = '\0';
  return n > 0u;
}

bool er_ui_shadcn_resolve_demo_identifier(const char* identifier, er_ui_shadcn_resolved_demo_t* out_resolved) {
  if (!identifier || !out_resolved) return false;
  const char* trimmed = identifier;
  while (*trimmed == ' ' || *trimmed == '\t' || *trimmed == '\n' || *trimmed == '\r') trimmed++;
  const er_ui_shadcn_demo_spec_t* direct_source = er_ui_shadcn_find_demo_by_source_component(trimmed);
  if (direct_source) { out_resolved->spec = direct_source; out_resolved->kind = ER_UI_SHADCN_RESOLVE_SOURCE_COMPONENT; return true; }
  char normalized[128u];
  bool from_path = false;
  if (!er_ui_shadcn_normalize_identifier(identifier, normalized, sizeof(normalized), &from_path)) return false;
  const er_ui_shadcn_demo_spec_t* by_slug = er_ui_shadcn_find_demo_by_slug(normalized);
  if (by_slug) { out_resolved->spec = by_slug; out_resolved->kind = from_path ? ER_UI_SHADCN_RESOLVE_MODULE_PATH : ER_UI_SHADCN_RESOLVE_SLUG; return true; }
  const er_ui_shadcn_demo_spec_t* by_source = er_ui_shadcn_find_demo_by_source_component(normalized);
  if (by_source) { out_resolved->spec = by_source; out_resolved->kind = ER_UI_SHADCN_RESOLVE_SOURCE_COMPONENT; return true; }
  for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) {
    if (er_ui_shadcn_demo_uses_slot(&shadcn_demo_components[i], normalized)) { out_resolved->spec = &shadcn_demo_components[i]; out_resolved->kind = ER_UI_SHADCN_RESOLVE_SLOT; return true; }
  }
  return false;
}

bool er_ui_shadcn_port_mapping_for_identifier(const char* identifier, er_ui_shadcn_port_mapping_t* out_mapping) {
  if (!identifier || !out_mapping) return false;
  er_ui_shadcn_resolved_demo_t resolved = {0};
  if (!er_ui_shadcn_resolve_demo_identifier(identifier, &resolved)) return false;
  out_mapping->identifier = identifier;
  out_mapping->resolve_kind = resolved.kind;
  out_mapping->slug = resolved.spec->slug;
  out_mapping->source_component = resolved.spec->source_component;
  out_mapping->edge_builder = resolved.spec->edge_builder;
  out_mapping->category = resolved.spec->category;
  out_mapping->status = resolved.spec->status;
  out_mapping->native_renderer = er_ui_shadcn_demo_has_native_renderer(resolved.spec);
  out_mapping->exact_port = er_ui_shadcn_demo_is_exact_port(resolved.spec);
  return true;
}

size_t er_ui_shadcn_native_demo_count(void) {
  size_t count = 0u; for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (er_ui_shadcn_demo_has_native_renderer(&shadcn_demo_components[i])) count++; return count;
}
size_t er_ui_shadcn_exact_demo_count(void) {
  size_t count = 0u; for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (er_ui_shadcn_demo_is_exact_port(&shadcn_demo_components[i])) count++; return count;
}
size_t er_ui_shadcn_count_by_category(er_ui_shadcn_demo_category_t category) {
  size_t count = 0u; for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (shadcn_demo_components[i].category == category) count++; return count;
}
size_t er_ui_shadcn_count_by_status(er_ui_shadcn_demo_status_t status) {
  size_t count = 0u; for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) if (shadcn_demo_components[i].status == status) count++; return count;
}
static const char* const* er_ui_shadcn_variants_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_shadcn_streq(slug, "alert")) { *out_count = sizeof(alert_variants) / sizeof(alert_variants[0]); return alert_variants; }
  if (er_ui_shadcn_streq(slug, "badge")) { *out_count = sizeof(badge_variants) / sizeof(badge_variants[0]); return badge_variants; }
  if (er_ui_shadcn_streq(slug, "button")) { *out_count = sizeof(button_variants) / sizeof(button_variants[0]); return button_variants; }
  if (er_ui_shadcn_streq(slug, "button-group")) { *out_count = sizeof(orientation_variants) / sizeof(orientation_variants[0]); return orientation_variants; }
  if (er_ui_shadcn_streq(slug, "separator")) { *out_count = sizeof(orientation_variants) / sizeof(orientation_variants[0]); return orientation_variants; }
  if (er_ui_shadcn_streq(slug, "resizable")) { *out_count = sizeof(orientation_variants) / sizeof(orientation_variants[0]); return orientation_variants; }
  static const char* const card_variants[] = {"default", "sm"};
  if (er_ui_shadcn_streq(slug, "card")) { *out_count = sizeof(card_variants) / sizeof(card_variants[0]); return card_variants; }
  if (er_ui_shadcn_streq(slug, "direction")) { *out_count = sizeof(direction_variants) / sizeof(direction_variants[0]); return direction_variants; }
  if (er_ui_shadcn_streq(slug, "field")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "input")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "input-group")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "native-select")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "select")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "textarea")) { *out_count = sizeof(field_variants) / sizeof(field_variants[0]); return field_variants; }
  if (er_ui_shadcn_streq(slug, "sheet")) { *out_count = sizeof(sheet_sides) / sizeof(sheet_sides[0]); return sheet_sides; }
  if (er_ui_shadcn_streq(slug, "sonner")) { *out_count = sizeof(toast_variants) / sizeof(toast_variants[0]); return toast_variants; }
  if (er_ui_shadcn_streq(slug, "toast")) { *out_count = sizeof(toast_variants) / sizeof(toast_variants[0]); return toast_variants; }
  static const char* const toggle_group_variants[] = {"single", "multiple"};
  if (er_ui_shadcn_streq(slug, "toggle-group")) { *out_count = sizeof(toggle_group_variants) / sizeof(toggle_group_variants[0]); return toggle_group_variants; }
  *out_count = 0u; return no_variants;
}

static const char* const* er_ui_shadcn_interactions_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_shadcn_streq(slug, "accordion") || er_ui_shadcn_streq(slug, "collapsible")) { *out_count = sizeof(disclosure_interactions) / sizeof(disclosure_interactions[0]); return disclosure_interactions; }
  if (er_ui_shadcn_streq(slug, "alert-dialog") || er_ui_shadcn_streq(slug, "dialog") || er_ui_shadcn_streq(slug, "drawer") || er_ui_shadcn_streq(slug, "hover-card") || er_ui_shadcn_streq(slug, "popover") || er_ui_shadcn_streq(slug, "sheet") || er_ui_shadcn_streq(slug, "tooltip")) { *out_count = sizeof(overlay_interactions) / sizeof(overlay_interactions[0]); return overlay_interactions; }
  if (er_ui_shadcn_streq(slug, "button") || er_ui_shadcn_streq(slug, "button-group") || er_ui_shadcn_streq(slug, "pagination") || er_ui_shadcn_streq(slug, "toggle") || er_ui_shadcn_streq(slug, "toggle-group")) { *out_count = sizeof(click_interactions) / sizeof(click_interactions[0]); return click_interactions; }
  if (er_ui_shadcn_streq(slug, "calendar") || er_ui_shadcn_streq(slug, "carousel") || er_ui_shadcn_streq(slug, "checkbox") || er_ui_shadcn_streq(slug, "combobox") || er_ui_shadcn_streq(slug, "command") || er_ui_shadcn_streq(slug, "date-picker") || er_ui_shadcn_streq(slug, "menubar") || er_ui_shadcn_streq(slug, "navigation-menu") || er_ui_shadcn_streq(slug, "radio-group") || er_ui_shadcn_streq(slug, "select") || er_ui_shadcn_streq(slug, "tabs")) { *out_count = sizeof(collection_interactions) / sizeof(collection_interactions[0]); return collection_interactions; }
  if (er_ui_shadcn_streq(slug, "context-menu") || er_ui_shadcn_streq(slug, "dropdown-menu")) { *out_count = sizeof(menu_interactions) / sizeof(menu_interactions[0]); return menu_interactions; }
  if (er_ui_shadcn_streq(slug, "field") || er_ui_shadcn_streq(slug, "input") || er_ui_shadcn_streq(slug, "input-group") || er_ui_shadcn_streq(slug, "input-otp") || er_ui_shadcn_streq(slug, "native-select") || er_ui_shadcn_streq(slug, "textarea")) { *out_count = sizeof(input_interactions) / sizeof(input_interactions[0]); return input_interactions; }
  if (er_ui_shadcn_streq(slug, "resizable") || er_ui_shadcn_streq(slug, "slider")) { *out_count = sizeof(drag_interactions) / sizeof(drag_interactions[0]); return drag_interactions; }
  *out_count = sizeof(static_interactions) / sizeof(static_interactions[0]); return static_interactions;
}

static const char* const* er_ui_shadcn_keyboard_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  static const char* const enter_space_keyboard[] = {"Enter", "Space"};
  if (er_ui_shadcn_streq(slug, "accordion") || er_ui_shadcn_streq(slug, "button") || er_ui_shadcn_streq(slug, "button-group") || er_ui_shadcn_streq(slug, "checkbox") || er_ui_shadcn_streq(slug, "collapsible") || er_ui_shadcn_streq(slug, "toggle")) { *out_count = sizeof(enter_space_keyboard) / sizeof(enter_space_keyboard[0]); return enter_space_keyboard; }
  if (er_ui_shadcn_streq(slug, "alert-dialog") || er_ui_shadcn_streq(slug, "dialog")) { *out_count = sizeof(dialog_keyboard) / sizeof(dialog_keyboard[0]); return dialog_keyboard; }
  if (er_ui_shadcn_streq(slug, "context-menu") || er_ui_shadcn_streq(slug, "dropdown-menu") || er_ui_shadcn_streq(slug, "command") || er_ui_shadcn_streq(slug, "combobox") || er_ui_shadcn_streq(slug, "select")) { *out_count = sizeof(menu_keyboard) / sizeof(menu_keyboard[0]); return menu_keyboard; }
  if (er_ui_shadcn_streq(slug, "calendar") || er_ui_shadcn_streq(slug, "carousel") || er_ui_shadcn_streq(slug, "menubar") || er_ui_shadcn_streq(slug, "navigation-menu") || er_ui_shadcn_streq(slug, "pagination") || er_ui_shadcn_streq(slug, "radio-group") || er_ui_shadcn_streq(slug, "tabs") || er_ui_shadcn_streq(slug, "toggle-group")) { *out_count = sizeof(horizontal_keyboard) / sizeof(horizontal_keyboard[0]); return horizontal_keyboard; }
  if (er_ui_shadcn_streq(slug, "date-picker") || er_ui_shadcn_streq(slug, "drawer") || er_ui_shadcn_streq(slug, "hover-card") || er_ui_shadcn_streq(slug, "popover") || er_ui_shadcn_streq(slug, "sheet") || er_ui_shadcn_streq(slug, "tooltip")) { *out_count = sizeof(overlay_keyboard) / sizeof(overlay_keyboard[0]); return overlay_keyboard; }
  if (er_ui_shadcn_streq(slug, "field") || er_ui_shadcn_streq(slug, "input") || er_ui_shadcn_streq(slug, "input-group") || er_ui_shadcn_streq(slug, "native-select") || er_ui_shadcn_streq(slug, "textarea")) { *out_count = sizeof(text_input_keyboard) / sizeof(text_input_keyboard[0]); return text_input_keyboard; }
  if (er_ui_shadcn_streq(slug, "input-otp")) { *out_count = sizeof(input_otp_keyboard) / sizeof(input_otp_keyboard[0]); return input_otp_keyboard; }
  if (er_ui_shadcn_streq(slug, "resizable") || er_ui_shadcn_streq(slug, "slider")) { *out_count = sizeof(slider_keyboard) / sizeof(slider_keyboard[0]); return slider_keyboard; }
  *out_count = 0u; return no_keyboard;
}

static const char* er_ui_shadcn_aria_pattern_for_slug(const char* slug) {
  if (er_ui_shadcn_streq(slug, "accordion")) return "accordion";
  if (er_ui_shadcn_streq(slug, "alert")) return "alert";
  if (er_ui_shadcn_streq(slug, "alert-dialog")) return "alertdialog";
  if (er_ui_shadcn_streq(slug, "breadcrumb")) return "breadcrumb-navigation";
  if (er_ui_shadcn_streq(slug, "button")) return "button";
  if (er_ui_shadcn_streq(slug, "button-group")) return "button";
  if (er_ui_shadcn_streq(slug, "toggle")) return "button";
  if (er_ui_shadcn_streq(slug, "toggle-group")) return "button";
  if (er_ui_shadcn_streq(slug, "calendar")) return "grid";
  if (er_ui_shadcn_streq(slug, "date-picker")) return "grid";
  if (er_ui_shadcn_streq(slug, "carousel")) return "region";
  if (er_ui_shadcn_streq(slug, "chart")) return "figure";
  if (er_ui_shadcn_streq(slug, "checkbox")) return "checkbox";
  if (er_ui_shadcn_streq(slug, "collapsible")) return "disclosure";
  if (er_ui_shadcn_streq(slug, "combobox")) return "combobox";
  if (er_ui_shadcn_streq(slug, "command")) return "command-menu";
  if (er_ui_shadcn_streq(slug, "context-menu")) return "menu";
  if (er_ui_shadcn_streq(slug, "dropdown-menu")) return "menu";
  if (er_ui_shadcn_streq(slug, "menubar")) return "menu";
  if (er_ui_shadcn_streq(slug, "data-table")) return "table";
  if (er_ui_shadcn_streq(slug, "table")) return "table";
  if (er_ui_shadcn_streq(slug, "dialog")) return "dialog";
  if (er_ui_shadcn_streq(slug, "drawer")) return "dialog";
  if (er_ui_shadcn_streq(slug, "sheet")) return "dialog";
  if (er_ui_shadcn_streq(slug, "field")) return "form-control";
  if (er_ui_shadcn_streq(slug, "input")) return "form-control";
  if (er_ui_shadcn_streq(slug, "input-group")) return "form-control";
  if (er_ui_shadcn_streq(slug, "input-otp")) return "form-control";
  if (er_ui_shadcn_streq(slug, "textarea")) return "form-control";
  if (er_ui_shadcn_streq(slug, "hover-card")) return "non-modal-dialog";
  if (er_ui_shadcn_streq(slug, "popover")) return "non-modal-dialog";
  if (er_ui_shadcn_streq(slug, "navigation-menu")) return "navigation";
  if (er_ui_shadcn_streq(slug, "pagination")) return "navigation";
  if (er_ui_shadcn_streq(slug, "sidebar")) return "navigation";
  if (er_ui_shadcn_streq(slug, "native-select")) return "listbox";
  if (er_ui_shadcn_streq(slug, "select")) return "listbox";
  if (er_ui_shadcn_streq(slug, "progress")) return "progressbar";
  if (er_ui_shadcn_streq(slug, "radio-group")) return "radiogroup";
  if (er_ui_shadcn_streq(slug, "resizable")) return "slider";
  if (er_ui_shadcn_streq(slug, "slider")) return "slider";
  if (er_ui_shadcn_streq(slug, "scroll-area")) return "scroll-region";
  if (er_ui_shadcn_streq(slug, "separator")) return "separator";
  if (er_ui_shadcn_streq(slug, "tabs")) return "tabs";
  if (er_ui_shadcn_streq(slug, "toast")) return "status";
  if (er_ui_shadcn_streq(slug, "sonner")) return "status";
  if (er_ui_shadcn_streq(slug, "tooltip")) return "tooltip";
  return "presentation";
}

bool er_ui_shadcn_parity_contract_for_slug(const char* slug, er_ui_shadcn_parity_contract_t* out_contract) {
  if (!slug || !out_contract) return false;
  const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_find_demo_by_slug(slug);
  if (!spec) return false;
  *out_contract = (er_ui_shadcn_parity_contract_t){0};
  out_contract->slug = spec->slug;
  out_contract->slots = spec->slots;
  out_contract->slot_count = spec->slot_count;
  out_contract->states = spec->states;
  out_contract->state_count = spec->state_count;
  out_contract->variants = er_ui_shadcn_variants_for_slug(spec->slug, &out_contract->variant_count);
  out_contract->interactions = er_ui_shadcn_interactions_for_slug(spec->slug, &out_contract->interaction_count);
  out_contract->keyboard = er_ui_shadcn_keyboard_for_slug(spec->slug, &out_contract->keyboard_count);
  out_contract->aria_pattern = er_ui_shadcn_aria_pattern_for_slug(spec->slug);
  out_contract->compound = spec->slot_count > 1u;
  return true;
}

size_t er_ui_shadcn_exact_parity_count(void) {
  size_t count = 0u;
  for (size_t i = 0u; i < ER_UI_SHADCN_DEMO_COUNT; ++i) {
    er_ui_shadcn_parity_contract_t contract = {0};
    if (er_ui_shadcn_demo_is_exact_port(&shadcn_demo_components[i]) && er_ui_shadcn_parity_contract_for_slug(shadcn_demo_components[i].slug, &contract)) count++;
  }
  return count;
}

bool er_ui_shadcn_contract_supports_slot(const er_ui_shadcn_parity_contract_t* contract, const char* slot) {
  return contract && er_ui_shadcn_list_contains(contract->slots, contract->slot_count, slot);
}
bool er_ui_shadcn_contract_supports_state(const er_ui_shadcn_parity_contract_t* contract, const char* state) {
  return contract && er_ui_shadcn_list_contains(contract->states, contract->state_count, state);
}
bool er_ui_shadcn_contract_supports_variant(const er_ui_shadcn_parity_contract_t* contract, const char* variant) {
  return contract && er_ui_shadcn_list_contains(contract->variants, contract->variant_count, variant);
}
bool er_ui_shadcn_contract_supports_interaction(const er_ui_shadcn_parity_contract_t* contract, const char* interaction) {
  return contract && er_ui_shadcn_list_contains(contract->interactions, contract->interaction_count, interaction);
}

static bool er_ui_shadcn_preview_select_id(uint32_t id) {
  return id == ER_UI_SHADCN_SELECT_PREFERRED_CURRENCY_ID ||
         id == ER_UI_SHADCN_SELECT_ORDER_TYPE_ID ||
         id == ER_UI_SHADCN_SELECT_DEFAULT_CURRENCY_ID ||
         id == ER_UI_SHADCN_SELECT_TICKER_ID;
}

static float er_ui_shadcn_clamp01(float value) {
  if (value < 0.0f) return 0.0f;
  if (value > 1.0f) return 1.0f;
  return value;
}

static bool er_ui_shadcn_gallery_set_slider(er_ui_shadcn_demo_gallery_state_t* state, uint32_t id, float value) {
  if (!state) return false;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) {
      state->sliders[i].value = er_ui_shadcn_clamp01(value);
      return true;
    }
  }
  if (state->slider_count >= ER_UI_SHADCN_GALLERY_SLIDER_CAPACITY) return false;
  state->sliders[state->slider_count++] = (er_ui_shadcn_slider_value_t){id, er_ui_shadcn_clamp01(value)};
  return true;
}

void er_ui_shadcn_demo_gallery_state_init(er_ui_shadcn_demo_gallery_state_t* state) {
  if (!state) return;
  *state = (er_ui_shadcn_demo_gallery_state_t){0};
  state->contribution_bar = 5u;
  state->stock_bar = 5u;
  state->power_bar = 6u;
}

size_t er_ui_shadcn_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index) {
  if (out_has_index) *out_has_index = false;
  if (id < base) return 0u;
  uint32_t offset = id - base;
  if ((size_t)offset >= len) return 0u;
  if (out_has_index) *out_has_index = true;
  return (size_t)offset;
}

bool er_ui_shadcn_demo_gallery_apply_action(er_ui_shadcn_demo_gallery_state_t* state, er_ui_action_t action) {
  if (!state) return false;
  if (action.kind == ER_UI_ACTION_OPEN_CHANGED) {
    if (!er_ui_shadcn_preview_select_id(action.id)) return false;
    state->has_open_select = action.bool_value;
    state->open_select = action.bool_value ? action.id : 0u;
    return true;
  }
  if (action.kind == ER_UI_ACTION_SLIDER_CHANGED) {
    return er_ui_shadcn_gallery_set_slider(state, action.id, action.float_value);
  }
  if (action.kind != ER_UI_ACTION_ACTIVATED || !action.has_hit) return false;
  if (action.hit.kind == ER_UI_HIT_MENU_ITEM) {
    bool has_index = false;
    size_t index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_SELECT_CURRENCY_BASE_ID, 3u, &has_index);
    if (has_index) {
      state->currency_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_SELECT_ORDER_BASE_ID, 3u, &has_index);
    if (has_index) {
      state->order_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_SELECT_TICKER_BASE_ID, 4u, &has_index);
    if (has_index) {
      state->ticker_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
  }
  if (action.hit.kind == ER_UI_HIT_BUTTON) {
    bool has_index = false;
    size_t index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_CHART_CONTRIBUTION_BASE_ID, 7u, &has_index);
    if (has_index) {
      state->contribution_bar = index;
      return true;
    }
    index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_CHART_STOCK_BASE_ID, 8u, &has_index);
    if (has_index) {
      state->stock_bar = index;
      return true;
    }
    index = er_ui_shadcn_option_index(action.hit.id, ER_UI_SHADCN_CHART_POWER_BASE_ID, 8u, &has_index);
    if (has_index) {
      state->power_bar = index;
      return true;
    }
  }
  return false;
}

bool er_ui_shadcn_demo_gallery_select_open(const er_ui_shadcn_demo_gallery_state_t* state, uint32_t id) {
  return state && state->has_open_select && state->open_select == id;
}

float er_ui_shadcn_demo_gallery_slider(const er_ui_shadcn_demo_gallery_state_t* state, uint32_t id, float fallback) {
  if (!state) return fallback;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) return state->sliders[i].value;
  }
  return fallback;
}

bool er_ui_shadcn_component_preview_available(const char* slug) {
  const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_find_demo_by_slug(slug);
  return er_ui_shadcn_demo_has_native_renderer(spec);
}

bool er_ui_shadcn_demo_preview_available(const char* slug) {
  return er_ui_shadcn_component_preview_available(slug);
}

bool er_ui_shadcn_component_preview_available_by_source_component(const char* source_component) {
  const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_find_demo_by_source_component(source_component);
  return er_ui_shadcn_demo_has_native_renderer(spec);
}

bool er_ui_shadcn_component_preview_available_by_identifier(const char* identifier) {
  er_ui_shadcn_resolved_demo_t resolved = {0};
  if (!er_ui_shadcn_resolve_demo_identifier(identifier, &resolved)) return false;
  return er_ui_shadcn_demo_has_native_renderer(resolved.spec);
}

bool er_ui_shadcn_demo_preview_available_by_identifier(const char* identifier) {
  return er_ui_shadcn_component_preview_available_by_identifier(identifier);
}

er_ui_bounds_t er_ui_shadcn_button_bounds(er_ui_bounds_t bounds, er_ui_shadcn_button_size_t size) {
  switch (size) {
    case ER_UI_SHADCN_BUTTON_SIZE_SM: return er_ui_bounds_with_height_centered(bounds, 36.0f);
    case ER_UI_SHADCN_BUTTON_SIZE_LG: return er_ui_bounds_with_height_centered(bounds, 44.0f);
    case ER_UI_SHADCN_BUTTON_SIZE_ICON: {
      er_ui_bounds_t centered = er_ui_bounds_with_height_centered(bounds, 40.0f);
      return er_ui_bounds_with_width_centered(centered, 40.0f);
    }
    case ER_UI_SHADCN_BUTTON_SIZE_DEFAULT:
    default: return er_ui_bounds_with_height_centered(bounds, 40.0f);
  }
}

er_ui_status_t er_ui_shadcn_card_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
}

er_ui_status_t er_ui_shadcn_button_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  uint32_t id,
  er_ui_shadcn_button_variant_t variant,
  er_ui_shadcn_button_size_t size,
  bool active) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t rect = er_ui_shadcn_button_bounds(bounds, size);
  er_ui_color4_t fill = er_ui_shadcn_button_fill(theme, variant);
  if (!active) fill = er_ui_color_with_alpha(fill, fill.a * 0.74f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, rect.x, rect.y, rect.w, rect.h));
  if (status != ER_UI_OK) return status;
  if (variant != ER_UI_SHADCN_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(rect.x, rect.y, rect.w, rect.h, theme.radius.control, fill));
    if (status != ER_UI_OK) return status;
  }
  if (variant != ER_UI_SHADCN_BUTTON_GHOST && variant != ER_UI_SHADCN_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(rect.x, rect.y, rect.w, rect.h, theme.radius.control,
                                                           er_ui_color_with_alpha(er_ui_shadcn_button_border(theme, variant), active ? 0.32f : 0.18f)));
    if (status != ER_UI_OK) return status;
  }
  return er_ui_shadcn_push_ascii_text(scene, font, label, rect.x + 14.0f, rect.y + rect.h * 0.62f, er_ui_shadcn_button_text(theme, variant));
}

er_ui_status_t er_ui_shadcn_select_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool open) {
  if (!scene || !font || !label || !value || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t control = er_ui_bounds(bounds.x, bounds.y + 18.0f, bounds.w, er_ui_float_min(bounds.h - 18.0f, 40.0f));
  if (!er_ui_bounds_valid(control)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SELECT, id, control.x, control.y, control.w, control.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = open ? er_ui_color_with_alpha(theme.colors.active, 0.58f) : er_ui_color_with_alpha(theme.colors.row, 0.74f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(control.x, control.y, control.w, control.h, theme.radius.control, fill));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(control.x, control.y, control.w, control.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.40f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, value, control.x + 12.0f, control.y + 26.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, open ? "^" : "v", control.x + control.w - 22.0f, control.y + 26.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_slider_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  float value,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_shadcn_clamp01(value);
  er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t track = er_ui_bounds(bounds.x, bounds.y + bounds.h - 18.0f, bounds.w, 6.0f);
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SLIDER, id, track.x, track.y - 12.0f, track.w, 30.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w, track.h, 999.0f, er_ui_color_with_alpha(theme.colors.row, 0.86f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w * clamped, track.h, 999.0f, theme.colors.accent));
  if (status != ER_UI_OK) return status;
  float thumb_x = track.x + track.w * clamped - 7.0f;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(thumb_x, track.y - 5.0f, 16.0f, 16.0f, 8.0f, theme.colors.accent_text));
}

er_ui_status_t er_ui_shadcn_badge_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_shadcn_badge_variant_t variant) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = er_ui_shadcn_badge_fill(theme, variant);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, fill));
  if (status != ER_UI_OK) return status;
  if (variant == ER_UI_SHADCN_BADGE_OUTLINE) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, er_ui_color_with_alpha(theme.colors.border, 0.52f)));
    if (status != ER_UI_OK) return status;
  }
  return er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + 10.0f, bounds.y + bounds.h * 0.64f, er_ui_shadcn_badge_text(theme, variant));
}

er_ui_status_t er_ui_shadcn_field_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool text_area) {
  if (!scene || !font || !label || !value || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t control = er_ui_bounds(bounds.x, bounds.y + 18.0f, bounds.w, er_ui_float_max(bounds.h - 18.0f, 24.0f));
  er_ui_hit_kind_t hit_kind = text_area ? ER_UI_HIT_TEXT_AREA : ER_UI_HIT_INPUT;
  status = er_ui_scene_push_hit(scene, er_ui_hit(hit_kind, id, control.x, control.y, control.w, control.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(control.x, control.y, control.w, control.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.62f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(control.x, control.y, control.w, control.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.44f)));
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, value, control.x + 12.0f, control.y + 25.0f, theme.colors.text);
}

er_ui_status_t er_ui_shadcn_checkbox_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool checked,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t box = er_ui_bounds(bounds.x, bounds.y + (bounds.h - 18.0f) * 0.5f, 18.0f, 18.0f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_CHECKBOX, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(box.x, box.y, box.w, box.h, 4.0f, checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.row, 0.74f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(box.x, box.y, box.w, box.h, 4.0f, checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.border, 0.54f)));
  if (status != ER_UI_OK) return status;
  if (checked) {
    status = er_ui_shadcn_push_ascii_text(scene, font, "x", box.x + 5.0f, box.y + 14.0f, theme.colors.accent_text);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + 28.0f, bounds.y + bounds.h * 0.62f, theme.colors.text);
}

er_ui_status_t er_ui_shadcn_progress_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, float value) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_shadcn_clamp01(value);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, er_ui_color_with_alpha(theme.colors.row, 0.86f)));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w * clamped, bounds.h, theme.radius.pill, theme.colors.accent));
}

er_ui_status_t er_ui_shadcn_switch_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, bool checked, uint32_t id) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TOGGLE, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.row, 0.84f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, fill));
  if (status != ER_UI_OK) return status;
  float thumb = er_ui_float_min(bounds.h - 6.0f, 20.0f);
  float thumb_x = checked ? bounds.x + bounds.w - thumb - 3.0f : bounds.x + 3.0f;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(thumb_x, bounds.y + (bounds.h - thumb) * 0.5f, thumb, thumb, thumb * 0.5f, theme.colors.accent_text));
}

er_ui_status_t er_ui_shadcn_separator_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, er_ui_color_with_alpha(theme.colors.border, 0.56f)));
}

er_ui_status_t er_ui_shadcn_tabs_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id) {
  if (!scene || !font || (!labels && label_count > 0u) || !er_ui_bounds_valid(bounds) || label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.42f)));
  if (status != ER_UI_OK) return status;
  float tab_w = bounds.w / (float)label_count;
  for (size_t i = 0u; i < label_count; ++i) {
    er_ui_bounds_t tab = er_ui_bounds(bounds.x + tab_w * (float)i, bounds.y, tab_w, bounds.h);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TAB, base_id + (uint32_t)i, tab.x, tab.y, tab.w, tab.h));
    if (status != ER_UI_OK) return status;
    if (i == selected) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tab.x + 3.0f, tab.y + 3.0f, tab.w - 6.0f, tab.h - 6.0f, theme.radius.control, theme.colors.panel));
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_shadcn_push_ascii_text(scene, font, labels[i], tab.x + 12.0f, tab.y + tab.h * 0.62f, i == selected ? theme.colors.text : theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_shadcn_list_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail,
  uint32_t id,
  bool selected) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = selected ? er_ui_color_with_alpha(theme.colors.active, 0.54f) : er_ui_color_with_alpha(theme.colors.row, 0.34f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, fill));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 12.0f, bounds.y + 20.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, detail, bounds.x + 12.0f, bounds.y + 40.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_radio_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool selected,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t dot = er_ui_bounds(bounds.x, bounds.y + (bounds.h - 18.0f) * 0.5f, 18.0f, 18.0f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_RADIO, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(dot.x, dot.y, dot.w, dot.h, 9.0f, selected ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.border, 0.58f)));
  if (status != ER_UI_OK) return status;
  if (selected) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(dot.x + 5.0f, dot.y + 5.0f, 8.0f, 8.0f, 4.0f, theme.colors.accent));
    if (status != ER_UI_OK) return status;
  }
  return er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + 28.0f, bounds.y + bounds.h * 0.62f, theme.colors.text);
}

er_ui_status_t er_ui_shadcn_table_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* headers,
  size_t header_count,
  const char* const* cells,
  size_t row_count,
  uint32_t id_base) {
  if (!scene || !font || !headers || !cells || header_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float col_w = (bounds.w - 24.0f) / (float)header_count;
  float y = bounds.y + 24.0f;
  for (size_t h = 0u; h < header_count; ++h) {
    status = er_ui_shadcn_push_ascii_text(scene, font, headers[h], bounds.x + 12.0f + col_w * (float)h, y, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x + 10.0f, bounds.y + 34.0f, bounds.w - 20.0f, 1.0f), theme);
  if (status != ER_UI_OK) return status;
  for (size_t r = 0u; r < row_count; ++r) {
    er_ui_bounds_t row = er_ui_bounds(bounds.x + 8.0f, bounds.y + 42.0f + (float)r * 28.0f, bounds.w - 16.0f, 26.0f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TRANSACTION_ROW, id_base + (uint32_t)r, row.x, row.y, row.w, row.h));
    if (status != ER_UI_OK) return status;
    for (size_t h = 0u; h < header_count; ++h) {
      const char* value = cells[r * header_count + h];
      status = er_ui_shadcn_push_ascii_text(scene, font, value, bounds.x + 12.0f + col_w * (float)h, row.y + 18.0f, theme.colors.text);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_shadcn_skeleton_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.64f)));
}

er_ui_status_t er_ui_shadcn_toast_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* message,
  er_ui_color4_t accent) {
  if (!scene || !font || !message || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + (bounds.h - 10.0f) * 0.5f, 10.0f, 10.0f, 5.0f, accent));
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, message, bounds.x + 32.0f, bounds.y + bounds.h * 0.60f, theme.colors.text);
}

er_ui_status_t er_ui_shadcn_empty_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body) {
  if (!scene || !font || !title || !body || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + (bounds.w - 44.0f) * 0.5f, bounds.y, 44.0f, 44.0f, 22.0f,
                                                                     er_ui_color_with_alpha(theme.colors.row, 0.62f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 10.0f, bounds.y + 70.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, body, bounds.x + 10.0f, bounds.y + 94.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_alert_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent) {
  if (!scene || !font || !title || !body || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.row, 0.28f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.border, 0.46f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 15.0f, 10.0f, 10.0f, 5.0f, accent));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 34.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, body, bounds.x + 34.0f, bounds.y + 46.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_avatar_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_color4_t color,
  bool online) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float size = er_ui_float_min(bounds.w, bounds.h);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, size, size, size * 0.5f, er_ui_color_with_alpha(color, 0.54f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + size * 0.30f, bounds.y + size * 0.62f, color);
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + size - 8.0f, bounds.y + size - 8.0f, 8.0f, 8.0f, 4.0f,
                                                     online ? theme.colors.success : theme.colors.muted));
}

er_ui_status_t er_ui_shadcn_breadcrumb_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id) {
  if (!scene || !font || (!labels && label_count > 0u) || label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float x = bounds.x;
  for (size_t i = 0u; i < label_count; ++i) {
    er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BREADCRUMB, base_id + (uint32_t)i, x, bounds.y, 96.0f, bounds.h));
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, labels[i], x, bounds.y + bounds.h * 0.62f, i == selected ? theme.colors.text : theme.colors.muted);
    if (status != ER_UI_OK) return status;
    x += 82.0f;
    if (i + 1u < label_count) {
      status = er_ui_shadcn_push_ascii_text(scene, font, "/", x - 18.0f, bounds.y + bounds.h * 0.62f, theme.colors.muted);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_shadcn_command_palette_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* placeholder,
  uint32_t id) {
  if (!scene || !font || !placeholder || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_INPUT, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, theme.colors.composer));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.54f)));
  if (status != ER_UI_OK) return status;
  float icon_y = bounds.y + (bounds.h - 14.0f) * 0.5f;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x + 14.0f, icon_y, 10.0f, 10.0f, 5.0f, theme.colors.muted));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 23.0f, icon_y + 10.0f, 7.0f, 2.0f, 1.0f, theme.colors.muted));
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, placeholder, bounds.x + 44.0f, bounds.y + bounds.h * 0.62f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_tree_item_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  uint8_t depth,
  bool expanded,
  uint32_t id) {
  if (!scene || !font || !label || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TREE_ITEM, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  float indent = 12.0f + (float)depth * 18.0f;
  const char* icon = expanded ? ">" : "-";
  status = er_ui_shadcn_push_ascii_text(scene, font, icon, bounds.x + indent, bounds.y + bounds.h * 0.62f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + indent + 24.0f, bounds.y + bounds.h * 0.45f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, detail, bounds.x + bounds.w * 0.58f, bounds.y + bounds.h * 0.45f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_section_header_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x, bounds.y + 18.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, detail, bounds.x + bounds.w * 0.58f, bounds.y + 18.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f), theme);
}

er_ui_status_t er_ui_shadcn_identity_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* node,
  const char* policy,
  uint32_t id) {
  if (!scene || !font || !name || !node || !policy || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 16.0f, bounds.y + 18.0f, 34.0f, 34.0f, 10.0f, er_ui_color_with_alpha(theme.colors.accent, 0.28f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, "T", bounds.x + 28.0f, bounds.y + 40.0f, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, name, bounds.x + 62.0f, bounds.y + 30.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, node, bounds.x + 62.0f, bounds.y + 53.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 34.0f, 120.0f, 24.0f), theme, policy, ER_UI_SHADCN_BADGE_SECONDARY);
}

er_ui_status_t er_ui_shadcn_contact_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* detail,
  uint32_t id) {
  if (!scene || !font || !name || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x + 12.0f, bounds.y + 12.0f, 36.0f, 36.0f), theme, name, theme.colors.accent, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, name, bounds.x + 58.0f, bounds.y + 27.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, detail, bounds.x + 58.0f, bounds.y + 49.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_thread_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* last_message,
  bool unread,
  uint32_t id) {
  if (!scene || !font || !title || !last_message || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = unread ? er_ui_color_with_alpha(theme.colors.active, 0.58f) : theme.colors.panel;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, fill));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 18.0f, 22.0f, 18.0f, 6.0f, unread ? theme.colors.accent : theme.colors.muted));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 48.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, last_message, bounds.x + 48.0f, bounds.y + 46.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_attachment_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* kind,
  uint32_t id) {
  if (!scene || !font || !name || !kind || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, theme.colors.row));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.border, 0.68f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 12.0f, 28.0f, 28.0f, 6.0f, er_ui_color_with_alpha(theme.colors.accent, 0.24f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, name, bounds.x + 52.0f, bounds.y + 25.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_push_ascii_text(scene, font, kind, bounds.x + 52.0f, bounds.y + 47.0f, theme.colors.muted);
}

er_ui_status_t er_ui_shadcn_capability_grant_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* app,
  const char* capability,
  const char* state,
  uint32_t id) {
  if (!scene || !font || !app || !capability || !state || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 17.0f, 24.0f, 24.0f, 7.0f, er_ui_color_with_alpha(theme.colors.info, 0.25f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, app, bounds.x + 48.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, capability, bounds.x + 48.0f, bounds.y + 46.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 96.0f, bounds.y + 18.0f, 84.0f, 24.0f), theme, state, ER_UI_SHADCN_BADGE_DEFAULT);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f), theme);
}

er_ui_status_t er_ui_shadcn_proof_event_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* hash,
  const char* status_text,
  uint32_t id) {
  if (!scene || !font || !title || !hash || !status_text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 17.0f, 24.0f, 24.0f, 12.0f, er_ui_color_with_alpha(theme.colors.success, 0.25f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 48.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, hash, bounds.x + 48.0f, bounds.y + 46.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 96.0f, bounds.y + 18.0f, 84.0f, 24.0f), theme, status_text, ER_UI_SHADCN_BADGE_DEFAULT);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f), theme);
}

er_ui_status_t er_ui_shadcn_route_path_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* const* hops,
  size_t hop_count) {
  if (!scene || !font || !label || (!hops && hop_count > 0u) || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + 14.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  float x = bounds.x + 16.0f;
  float y = bounds.y + 45.0f;
  for (size_t i = 0u; i < hop_count; ++i) {
    if (x > bounds.x + bounds.w - 80.0f) break;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(x, y, 22.0f, 22.0f, 11.0f, er_ui_color_with_alpha(theme.colors.accent, 0.28f)));
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, hops[i], x + 28.0f, y + 18.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    x += 112.0f;
    if (i + 1u < hop_count) {
      status = er_ui_shadcn_push_ascii_text(scene, font, ">", x - 22.0f, y + 18.0f, theme.colors.muted);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_shadcn_package_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* policy,
  const char* hash,
  uint32_t id) {
  if (!scene || !font || !name || !policy || !hash || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 16.0f, bounds.y + 18.0f, 30.0f, 30.0f, 7.0f, er_ui_color_with_alpha(theme.colors.accent, 0.28f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, name, bounds.x + 58.0f, bounds.y + 30.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, hash, bounds.x + 58.0f, bounds.y + 53.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + 16.0f, bounds.y + bounds.h - 34.0f, 120.0f, 24.0f), theme, policy, ER_UI_SHADCN_BADGE_SECONDARY);
}

er_ui_status_t er_ui_shadcn_receipt_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* amount,
  const char* status_text,
  uint32_t id) {
  if (!scene || !font || !label || !amount || !status_text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TRANSACTION_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + 12.0f, bounds.y + 17.0f, 24.0f, 24.0f, 12.0f, er_ui_color_with_alpha(theme.colors.success, 0.25f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, label, bounds.x + 48.0f, bounds.y + 34.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, status_text, bounds.x + bounds.w - 150.0f, bounds.y + 34.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, amount, bounds.x + bounds.w - 76.0f, bounds.y + 34.0f, theme.colors.success);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f), theme);
}

er_ui_status_t er_ui_shadcn_bar_chart_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* const* labels,
  const float* values,
  size_t value_count,
  uint32_t base_id,
  size_t selected) {
  if (!scene || !font || !title || !labels || !values || value_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x, bounds.y + 14.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  float gap = 8.0f;
  float bar_w = (bounds.w - gap * (float)(value_count - 1u)) / (float)value_count;
  if (bar_w < 4.0f) bar_w = 4.0f;
  float base_y = bounds.y + bounds.h - 22.0f;
  float max_h = er_ui_float_max(bounds.h - 48.0f, 8.0f);
  for (size_t i = 0u; i < value_count; ++i) {
    float v = er_ui_shadcn_clamp01(values[i]);
    float h = er_ui_float_max(max_h * v, 2.0f);
    float x = bounds.x + (bar_w + gap) * (float)i;
    er_ui_color4_t fill = i == selected ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.accent, 0.48f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, base_id + (uint32_t)i, x, base_y - h, bar_w, h));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(x, base_y - h, bar_w, h, 4.0f, fill));
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, labels[i], x, base_y + 14.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

bool er_ui_shadcn_component_scene_preview_available(const char* slug) {
  return er_ui_shadcn_streq(slug, "accordion") ||
         er_ui_shadcn_streq(slug, "alert") ||
         er_ui_shadcn_streq(slug, "alert-dialog") ||
         er_ui_shadcn_streq(slug, "aspect-ratio") ||
         er_ui_shadcn_streq(slug, "avatar") ||
         er_ui_shadcn_streq(slug, "badge") ||
         er_ui_shadcn_streq(slug, "breadcrumb") ||
         er_ui_shadcn_streq(slug, "button") ||
         er_ui_shadcn_streq(slug, "button-group") ||
         er_ui_shadcn_streq(slug, "calendar") ||
         er_ui_shadcn_streq(slug, "card") ||
         er_ui_shadcn_streq(slug, "carousel") ||
         er_ui_shadcn_streq(slug, "chart") ||
         er_ui_shadcn_streq(slug, "checkbox") ||
         er_ui_shadcn_streq(slug, "collapsible") ||
         er_ui_shadcn_streq(slug, "combobox") ||
         er_ui_shadcn_streq(slug, "command") ||
         er_ui_shadcn_streq(slug, "context-menu") ||
         er_ui_shadcn_streq(slug, "data-table") ||
         er_ui_shadcn_streq(slug, "date-picker") ||
         er_ui_shadcn_streq(slug, "dialog") ||
         er_ui_shadcn_streq(slug, "direction") ||
         er_ui_shadcn_streq(slug, "drawer") ||
         er_ui_shadcn_streq(slug, "dropdown-menu") ||
         er_ui_shadcn_streq(slug, "empty") ||
         er_ui_shadcn_streq(slug, "field") ||
         er_ui_shadcn_streq(slug, "hover-card") ||
         er_ui_shadcn_streq(slug, "input") ||
         er_ui_shadcn_streq(slug, "input-group") ||
         er_ui_shadcn_streq(slug, "input-otp") ||
         er_ui_shadcn_streq(slug, "item") ||
         er_ui_shadcn_streq(slug, "kbd") ||
         er_ui_shadcn_streq(slug, "label") ||
         er_ui_shadcn_streq(slug, "menubar") ||
         er_ui_shadcn_streq(slug, "native-select") ||
         er_ui_shadcn_streq(slug, "navigation-menu") ||
         er_ui_shadcn_streq(slug, "pagination") ||
         er_ui_shadcn_streq(slug, "popover") ||
         er_ui_shadcn_streq(slug, "progress") ||
         er_ui_shadcn_streq(slug, "radio-group") ||
         er_ui_shadcn_streq(slug, "resizable") ||
         er_ui_shadcn_streq(slug, "scroll-area") ||
         er_ui_shadcn_streq(slug, "select") ||
         er_ui_shadcn_streq(slug, "separator") ||
         er_ui_shadcn_streq(slug, "sheet") ||
         er_ui_shadcn_streq(slug, "sidebar") ||
         er_ui_shadcn_streq(slug, "skeleton") ||
         er_ui_shadcn_streq(slug, "slider") ||
         er_ui_shadcn_streq(slug, "sonner") ||
         er_ui_shadcn_streq(slug, "switch") ||
         er_ui_shadcn_streq(slug, "table") ||
         er_ui_shadcn_streq(slug, "tabs") ||
         er_ui_shadcn_streq(slug, "textarea") ||
         er_ui_shadcn_streq(slug, "toast") ||
         er_ui_shadcn_streq(slug, "toggle") ||
         er_ui_shadcn_streq(slug, "toggle-group") ||
         er_ui_shadcn_streq(slug, "tooltip");
}

er_ui_status_t er_ui_shadcn_component_scene_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* slug,
  const er_ui_shadcn_demo_gallery_state_t* state) {
  if (!scene || !font || !slug || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_shadcn_streq(slug, "accordion")) {
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 110.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Is it accessible?", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Yes. It follows the WAI-ARIA design pattern.", bounds.x + 14.0f, bounds.y + 50.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x + 12.0f, bounds.y + 64.0f, er_ui_float_min(bounds.w, 360.0f) - 24.0f, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Is it styled?", bounds.x + 14.0f, bounds.y + 88.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "alert")) {
    return er_ui_shadcn_alert_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 390.0f), 76.0f), theme, "Heads up",
                                   "You can add components to your app using the CLI.", theme.colors.warning);
  }
  if (er_ui_shadcn_streq(slug, "alert-dialog") || er_ui_shadcn_streq(slug, "dialog")) {
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f), theme);
    if (status != ER_UI_OK) return status;
    const char* title = er_ui_shadcn_streq(slug, "alert-dialog") ? "Are you absolutely sure?" : "Edit profile";
    const char* body = er_ui_shadcn_streq(slug, "alert-dialog") ? "This action cannot be undone." : "Make changes to your profile here.";
    status = er_ui_shadcn_push_ascii_text(scene, font, title, bounds.x + 18.0f, bounds.y + 32.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, body, bounds.x + 18.0f, bounds.y + 56.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 160.0f, bounds.y + 96.0f, 80.0f, 40.0f), theme, "Cancel",
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 90u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 248.0f, bounds.y + 96.0f, 84.0f, 40.0f), theme, "Confirm",
                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 91u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  }
  if (er_ui_shadcn_streq(slug, "aspect-ratio")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 146.0f);
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(card.x + 12.0f, card.y + 12.0f, card.w - 24.0f, card.h - 24.0f, theme.radius.control,
                                                         er_ui_color_with_alpha(theme.colors.row, 0.52f)));
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "16:9", card.x + card.w * 0.45f, card.y + card.h * 0.56f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "avatar")) {
    er_ui_status_t status = er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "CN", theme.colors.accent, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x + 52.0f, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.success, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x + 104.0f, bounds.y, 42.0f, 42.0f), theme, "UI", theme.colors.info, false);
  }
  if (er_ui_shadcn_streq(slug, "badge")) {
    er_ui_status_t status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 82.0f, 26.0f), theme, "Default", ER_UI_SHADCN_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + 92.0f, bounds.y, 96.0f, 26.0f), theme, "Secondary", ER_UI_SHADCN_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, 112.0f, 26.0f), theme, "Destructive", ER_UI_SHADCN_BADGE_DESTRUCTIVE);
  }
  if (er_ui_shadcn_streq(slug, "button")) {
    er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 96.0f, 42.0f), theme, "Button", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 2u,
                                                     ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 106.0f, bounds.y, 116.0f, 42.0f), theme, "Secondary",
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 3u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 232.0f, bounds.y, 86.0f, 42.0f), theme, "Ghost",
                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4u, ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_shadcn_streq(slug, "breadcrumb")) {
    const char* const labels[] = {"Docs", "Components", "Breadcrumb"};
    return er_ui_shadcn_breadcrumb_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 320.0f), 34.0f), theme, labels, 3u, 2u,
                                        ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 1u);
  }
  if (er_ui_shadcn_streq(slug, "button-group")) {
    const char* const labels[] = {"Copy", "Paste", "More"};
    return er_ui_shadcn_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 210.0f, 38.0f), theme, labels, 3u, 0u, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 27u);
  }
  if (er_ui_shadcn_streq(slug, "calendar") || er_ui_shadcn_streq(slug, "date-picker")) {
    er_ui_status_t status = ER_UI_OK;
    if (er_ui_shadcn_streq(slug, "date-picker")) {
      status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 120.0f, 38.0f), theme, "Pick a date", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 66u,
                                        ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
      bounds.y += 46.0f;
    }
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, 260.0f, 132.0f);
    status = er_ui_shadcn_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "June 2025", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    const char* const days[] = {"8", "9", "10", "11", "12", "13", "14"};
    for (size_t i = 0u; i < 7u; ++i) {
      status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(card.x + 10.0f + (float)i * 34.0f, card.y + 58.0f, 30.0f, 34.0f), theme, days[i],
                                        ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 48u + (uint32_t)i,
                                        i == 2u ? ER_UI_SHADCN_BUTTON_SECONDARY : ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
    }
    return ER_UI_OK;
  }
  if (er_ui_shadcn_streq(slug, "card")) {
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Create project", bounds.x + 16.0f, bounds.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Deploy your new project in one click.", bounds.x + 16.0f, bounds.y + 52.0f, theme.colors.muted);
  }
  if (er_ui_shadcn_streq(slug, "carousel")) {
    er_ui_status_t status = ER_UI_OK;
    for (size_t i = 0u; i < 3u; ++i) {
      er_ui_bounds_t card = er_ui_bounds(bounds.x + (float)i * 72.0f, bounds.y, 60.0f, 72.0f);
      status = er_ui_shadcn_card_emit(scene, card, theme);
      if (status != ER_UI_OK) return status;
      char label[2] = {(char)('1' + (char)i), '\0'};
      status = er_ui_shadcn_push_ascii_text(scene, font, label, card.x + 26.0f, card.y + 42.0f, theme.colors.text);
      if (status != ER_UI_OK) return status;
    }
    return ER_UI_OK;
  }
  if (er_ui_shadcn_streq(slug, "chart")) {
    const char* const labels[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun"};
    const float values[] = {0.42f, 0.68f, 0.51f, 0.82f, 0.56f, 0.74f};
    return er_ui_shadcn_bar_chart_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 160.0f), theme, "Visitors", labels, values, 6u,
                                       ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 120u, 3u);
  }
  if (er_ui_shadcn_streq(slug, "checkbox")) {
    er_ui_status_t status = er_ui_shadcn_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 32.0f), theme, "Accept terms and conditions", true,
                                                       ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 6u);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 38.0f, bounds.w, 32.0f), theme, "Receive security emails", false,
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 7u);
  }
  if (er_ui_shadcn_streq(slug, "context-menu") || er_ui_shadcn_streq(slug, "dropdown-menu")) {
    er_ui_status_t status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Profile", "Command P",
                                                       ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 9u, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Billing", "Command B",
                                        ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 10u, true);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Log out", "Shift Command Q",
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 11u, false);
  }
  if (er_ui_shadcn_streq(slug, "collapsible")) {
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "@peduarte starred 3 repositories", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 44.0f, 300.0f, 44.0f), theme, "@radix-ui/primitives",
                                        "Open source UI components", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 31u, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 92.0f, 300.0f, 44.0f), theme, "@radix-ui/colors",
                                      "Beautiful color scales", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 32u, false);
  }
  if (er_ui_shadcn_streq(slug, "combobox")) {
    er_ui_status_t status = er_ui_shadcn_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 240.0f, 62.0f), theme, "Framework", "Select framework...",
                                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 59u, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 70.0f, 240.0f, 54.0f), theme, "Search", "Search framework...",
                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 60u, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 130.0f, 240.0f, 44.0f), theme, "Next.js", "selected",
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 61u, true);
  }
  if (er_ui_shadcn_streq(slug, "command")) {
    return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 300.0f), 58.0f), theme, "Command",
                                   "Type a command or search...", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 8u, false);
  }
  if (er_ui_shadcn_streq(slug, "data-table") || er_ui_shadcn_streq(slug, "table")) {
    const char* const headers[] = {"Invoice", "Status", "Amount"};
    const char* const cells[] = {"INV001", "Paid", "$250.00", "INV002", "Pending", "$150.00"};
    return er_ui_shadcn_table_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 112.0f), theme, headers, 3u, cells, 2u,
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 43u);
  }
  if (er_ui_shadcn_streq(slug, "empty")) {
    return er_ui_shadcn_empty_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 120.0f), theme, "No results found",
                                   "Try adjusting your search or filters.");
  }
  if (er_ui_shadcn_streq(slug, "direction")) {
    er_ui_status_t status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 44.0f, 26.0f), theme, "LTR", ER_UI_SHADCN_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Left to right content", bounds.x + 56.0f, bounds.y + 19.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Right to left content", bounds.x, bounds.y + 56.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + 160.0f, bounds.y + 36.0f, 44.0f, 26.0f), theme, "RTL", ER_UI_SHADCN_BADGE_SECONDARY);
  }
  if (er_ui_shadcn_streq(slug, "drawer")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 150.0f);
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Move goal", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Set your daily activity target.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_slider_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 70.0f, card.w - 32.0f, 42.0f), theme, "Calories", 0.58f,
                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 34u);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 112.0f, 88.0f, 34.0f), theme, "Submit",
                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 35u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  }
  if (er_ui_shadcn_streq(slug, "field") || er_ui_shadcn_streq(slug, "input")) {
    return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 58.0f), theme, "Email", "name@example.com",
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 11u, false);
  }
  if (er_ui_shadcn_streq(slug, "hover-card")) {
    er_ui_status_t status = er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.accent, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "ER", bounds.x + 54.0f, bounds.y + 18.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "UI infrastructure", bounds.x + 54.0f, bounds.y + 38.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "User-owned app surfaces with reusable native components.", bounds.x, bounds.y + 72.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "input-group")) {
    er_ui_status_t status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_max(bounds.w - 92.0f, 96.0f), 58.0f), theme, "URL",
                                                    "https://example.com", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 12u, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + er_ui_float_max(bounds.w - 84.0f, 104.0f), bounds.y + 18.0f, 80.0f, 40.0f), theme, "Copy",
                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 13u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  }
  if (er_ui_shadcn_streq(slug, "input-otp")) {
    const char* const values[] = {"1", "2", "3", "-", "", "", ""};
    for (size_t i = 0u; i < 7u; ++i) {
      if (er_ui_shadcn_streq(values[i], "-")) {
        er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, "-", bounds.x + (float)i * 42.0f + 12.0f, bounds.y + 36.0f, theme.colors.muted);
        if (status != ER_UI_OK) return status;
        continue;
      }
      er_ui_status_t status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x + (float)i * 42.0f, bounds.y, 36.0f, 52.0f), theme, "", values[i],
                                                      ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 80u + (uint32_t)i, false);
      if (status != ER_UI_OK) return status;
    }
    return ER_UI_OK;
  }
  if (er_ui_shadcn_streq(slug, "item")) {
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 52.0f), theme, "Payment successful",
                                      "Stripe payout completed", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 13u, false);
  }
  if (er_ui_shadcn_streq(slug, "kbd")) {
    er_ui_status_t status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 34.0f, 28.0f), theme, "Cmd", ER_UI_SHADCN_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(bounds.x + 42.0f, bounds.y, 28.0f, 28.0f), theme, "K", ER_UI_SHADCN_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Command menu", bounds.x + 84.0f, bounds.y + 20.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "label")) {
    er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, "Email", bounds.x, bounds.y + 16.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 24.0f, er_ui_float_min(bounds.w, 260.0f), 58.0f), theme, "", "name@example.com",
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 92u, false);
  }
  if (er_ui_shadcn_streq(slug, "menubar")) {
    const char* const labels[] = {"File", "Edit", "View", "Profiles"};
    return er_ui_shadcn_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels, 4u, 0u,
                                  ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 70u);
  }
  if (er_ui_shadcn_streq(slug, "native-select") || er_ui_shadcn_streq(slug, "select")) {
    uint32_t id = ER_UI_SHADCN_SELECT_TICKER_ID;
    bool open = er_ui_shadcn_demo_gallery_select_open(state, id);
    return er_ui_shadcn_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 62.0f), theme, "Framework", "Next.js", id, open);
  }
  if (er_ui_shadcn_streq(slug, "pagination")) {
    er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 90.0f, 40.0f), theme, "Previous", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 37u,
                                                     ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 96.0f, bounds.y, 42.0f, 40.0f), theme, "1", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 38u,
                                      ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 144.0f, bounds.y, 68.0f, 40.0f), theme, "Next", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 39u,
                                    ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_shadcn_streq(slug, "navigation-menu")) {
    const char* const labels[] = {"Getting started", "Components", "Docs"};
    er_ui_status_t status = er_ui_shadcn_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels, 3u, 0u,
                                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 74u);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 50.0f, er_ui_float_min(bounds.w, 320.0f), 52.0f), theme, "Installation",
                                      "Add components to your app", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 77u, false);
  }
  if (er_ui_shadcn_streq(slug, "popover")) {
    er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 136.0f, 38.0f), theme, "Open popover",
                                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 41u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 300.0f), 120.0f);
    status = er_ui_shadcn_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Dimensions", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Set the dimensions for the layer.", card.x + 14.0f, card.y + 48.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(card.x + 14.0f, card.y + 58.0f, card.w - 28.0f, 54.0f), theme, "Width", "100%",
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 42u, false);
  }
  if (er_ui_shadcn_streq(slug, "progress")) {
    return er_ui_shadcn_progress_emit(scene, er_ui_bounds(bounds.x, bounds.y + 20.0f, bounds.w, 8.0f), theme, 0.66f);
  }
  if (er_ui_shadcn_streq(slug, "radio-group")) {
    er_ui_status_t status = er_ui_shadcn_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 30.0f), theme, "Default", true,
                                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 14u);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, bounds.w, 30.0f), theme, "Comfortable", false,
                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 15u);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 68.0f, bounds.w, 30.0f), theme, "Compact", false,
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 16u);
  }
  if (er_ui_shadcn_streq(slug, "resizable")) {
    er_ui_bounds_t first = er_ui_bounds(bounds.x, bounds.y, 90.0f, 92.0f);
    er_ui_bounds_t second = er_ui_bounds(bounds.x + 100.0f, bounds.y, 120.0f, 42.0f);
    er_ui_bounds_t third = er_ui_bounds(bounds.x + 100.0f, bounds.y + 50.0f, 120.0f, 42.0f);
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, first, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "One", first.x + 14.0f, first.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_card_emit(scene, second, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Two", second.x + 14.0f, second.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_card_emit(scene, third, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Three", third.x + 14.0f, third.y + 28.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "scroll-area")) {
    er_ui_status_t status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.0.0",
                                                       "Initial release", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 17u, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.1.0",
                                        "Component updates", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 18u, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.2.0",
                                      "Preset builder", ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 19u, false);
  }
  if (er_ui_shadcn_streq(slug, "separator")) {
    er_ui_status_t status = er_ui_shadcn_push_ascii_text(scene, font, "Radix Primitives", bounds.x, bounds.y + 12.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Styled with EdgeRun UI tokens", bounds.x, bounds.y + 52.0f, theme.colors.muted);
  }
  if (er_ui_shadcn_streq(slug, "sheet")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 166.0f);
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Edit profile", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "Make changes to your profile here.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 62.0f, card.w - 32.0f, 58.0f), theme, "Name", "EdgeRun",
                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 42u, false);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 124.0f, 120.0f, 36.0f), theme, "Save changes",
                                    ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 43u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  }
  if (er_ui_shadcn_streq(slug, "sidebar")) {
    er_ui_bounds_t side = er_ui_bounds(bounds.x, bounds.y, 150.0f, 154.0f);
    er_ui_status_t status = er_ui_shadcn_card_emit(scene, side, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_push_ascii_text(scene, font, "App", side.x + 12.0f, side.y + 24.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 40.0f, side.w - 16.0f, 34.0f), theme, "Dashboard", "",
                                        ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 78u, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 78.0f, side.w - 16.0f, 34.0f), theme, "Transactions", "",
                                        ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 79u, false);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t main = er_ui_bounds(bounds.x + 162.0f, bounds.y, er_ui_float_min(bounds.w - 170.0f, 220.0f), 154.0f);
    status = er_ui_shadcn_card_emit(scene, main, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Dashboard", main.x + 16.0f, main.y + 28.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "skeleton")) {
    er_ui_status_t status = er_ui_shadcn_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y, bounds.w, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w * 0.66f, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 56.0f, bounds.w * 0.50f, 18.0f), theme);
  }
  if (er_ui_shadcn_streq(slug, "slider")) {
    float value = er_ui_shadcn_demo_gallery_slider(state, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 21u, 0.42f);
    return er_ui_shadcn_slider_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 48.0f), theme, "Volume", value, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 21u);
  }
  if (er_ui_shadcn_streq(slug, "switch")) {
    er_ui_status_t status = er_ui_shadcn_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 22u);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Airplane mode", bounds.x + 56.0f, bounds.y + 18.0f, theme.colors.text);
  }
  if (er_ui_shadcn_streq(slug, "sonner")) {
    er_ui_status_t status = er_ui_shadcn_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Event has been created",
                                                    theme.colors.success);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 56.0f, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Upload failed",
                                   theme.colors.danger);
  }
  if (er_ui_shadcn_streq(slug, "tabs")) {
    const char* const labels[] = {"Account", "Password", "Settings"};
    return er_ui_shadcn_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 330.0f), 38.0f), theme, labels, 3u, 0u,
                                  ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 23u);
  }
  if (er_ui_shadcn_streq(slug, "textarea")) {
    return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 84.0f), theme, "Message", "Type your message here.",
                                   ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 45u, true);
  }
  if (er_ui_shadcn_streq(slug, "toast")) {
    return er_ui_shadcn_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Scheduled: Catch up",
                                   theme.colors.accent);
  }
  if (er_ui_shadcn_streq(slug, "toggle")) {
    return er_ui_shadcn_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 24u);
  }
  if (er_ui_shadcn_streq(slug, "toggle-group")) {
    const char* const labels[] = {"B", "I", "U"};
    return er_ui_shadcn_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 126.0f, 38.0f), theme, labels, 3u, 0u,
                                  ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 44u);
  }
  if (er_ui_shadcn_streq(slug, "tooltip")) {
    er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 80.0f, 38.0f), theme, "Hover",
                                                     ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 26u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t tip = er_ui_bounds(bounds.x + 94.0f, bounds.y + 2.0f, 112.0f, 34.0f);
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.panel, 0.96f)));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_push_ascii_text(scene, font, "Add to library", tip.x + 10.0f, tip.y + 22.0f, theme.colors.text);
  }
  return ER_UI_ERR_INVALID_ARGUMENT;
}

er_ui_status_t er_ui_shadcn_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* selected_slug,
  const er_ui_shadcn_demo_gallery_state_t* state) {
  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  const er_ui_shadcn_demo_spec_t* selected = er_ui_shadcn_find_demo_by_slug(selected_slug ? selected_slug : "button");
  if (!selected) selected = er_ui_shadcn_find_demo_by_slug("button");
  if (!selected) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t list = er_ui_bounds(bounds.x + 16.0f, bounds.y + 16.0f, er_ui_float_min(260.0f, bounds.w * 0.36f), bounds.h - 32.0f);
  er_ui_bounds_t preview = er_ui_bounds(list.x + list.w + 16.0f, bounds.y + 16.0f, bounds.w - list.w - 48.0f, bounds.h - 32.0f);
  status = er_ui_shadcn_card_emit(scene, list, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, "shadcn components", list.x + 14.0f, list.y + 28.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  size_t visible = er_ui_float_min((float)ER_UI_SHADCN_DEMO_COUNT, (list.h - 48.0f) / 24.0f);
  for (size_t i = 0u; i < visible; ++i) {
    const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_demo_at(i);
    if (!spec) continue;
    er_ui_bounds_t row = er_ui_bounds(list.x + 8.0f, list.y + 44.0f + (float)i * 24.0f, list.w - 16.0f, 22.0f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, ER_UI_SHADCN_SHOWCASE_ROW_BASE_ID + (uint32_t)i, row.x, row.y, row.w, row.h));
    if (status != ER_UI_OK) return status;
    if (er_ui_shadcn_streq(spec->slug, selected->slug)) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(row.x, row.y, row.w, row.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.active, 0.54f)));
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_shadcn_push_ascii_text(scene, font, spec->name, row.x + 8.0f, row.y + 16.0f,
                                          er_ui_shadcn_component_scene_preview_available(spec->slug) ? theme.colors.text : theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }

  status = er_ui_shadcn_card_emit(scene, preview, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, selected->name, preview.x + 18.0f, preview.y + 30.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_push_ascii_text(scene, font, er_ui_shadcn_demo_category_label(selected->category), preview.x + 18.0f, preview.y + 54.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t body = er_ui_bounds(preview.x + 18.0f, preview.y + 76.0f, preview.w - 36.0f, preview.h - 94.0f);
  if (er_ui_shadcn_component_scene_preview_available(selected->slug)) {
    return er_ui_shadcn_component_scene_preview_emit(scene, font, body, theme, selected->slug, state);
  }
  return er_ui_shadcn_push_ascii_text(scene, font, "Cataloged; native C scene preview not ported yet.", body.x, body.y + 18.0f, theme.colors.muted);
}

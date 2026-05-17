#include "er_ui_components.h"

#include <stdint.h>

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

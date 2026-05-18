#include "er_ui_components_internal.h"

static const char* const slots_accordion[] = {
  "accordion",
  "accordion-item",
  "accordion-trigger",
  "accordion-content",
};
static const char* const states_accordion[] = {
  "data-state=open",
  "data-state=closed",
  "disabled",
};
static const char* const slots_alert[] = {
  "alert",
  "alert-title",
  "alert-description",
};
static const char* const states_alert[] = {
  "default",
  "destructive",
};
static const char* const slots_alert_dialog[] = {
  "alert-dialog",
  "alert-dialog-trigger",
  "alert-dialog-content",
  "alert-dialog-header",
  "alert-dialog-footer",
  "alert-dialog-title",
  "alert-dialog-description",
  "alert-dialog-action",
  "alert-dialog-cancel",
};
static const char* const states_alert_dialog[] = {
  "open",
  "closed",
  "focus-trap",
};
static const char* const slots_aspect_ratio[] = {
  "aspect-ratio",
};
static const char* const states_aspect_ratio[] = {
  0,
};
static const char* const slots_avatar[] = {
  "avatar",
  "avatar-image",
  "avatar-fallback",
};
static const char* const states_avatar[] = {
  "loaded",
  "fallback",
};
static const char* const slots_badge[] = {
  "badge",
};
static const char* const states_badge[] = {
  "default",
  "secondary",
  "outline",
  "destructive",
};
static const char* const slots_breadcrumb[] = {
  "breadcrumb",
  "breadcrumb-list",
  "breadcrumb-item",
  "breadcrumb-link",
  "breadcrumb-page",
  "breadcrumb-separator",
  "breadcrumb-ellipsis",
};
static const char* const states_breadcrumb[] = {
  "current-page",
};
static const char* const slots_button[] = {
  "button",
};
static const char* const states_button[] = {
  "default",
  "destructive",
  "outline",
  "secondary",
  "ghost",
  "link",
  "disabled",
  "loading",
};
static const char* const slots_button_group[] = {
  "button-group",
  "button-group-item",
  "button-group-separator",
};
static const char* const states_button_group[] = {
  "horizontal",
  "vertical",
  "attached",
};
static const char* const slots_calendar[] = {
  "calendar",
  "calendar-month",
  "calendar-day",
  "calendar-caption",
};
static const char* const states_calendar[] = {
  "selected",
  "today",
  "disabled",
  "range-start",
  "range-end",
};
static const char* const slots_card[] = {
  "card",
  "card-header",
  "card-title",
  "card-description",
  "card-content",
  "card-footer",
};
static const char* const states_card[] = {
  "default",
  "sm",
};
static const char* const slots_carousel[] = {
  "carousel",
  "carousel-content",
  "carousel-item",
  "carousel-previous",
  "carousel-next",
};
static const char* const states_carousel[] = {
  "can-scroll-prev",
  "can-scroll-next",
};
static const char* const slots_chart[] = {
  "chart-container",
  "chart-tooltip",
  "chart-legend",
};
static const char* const states_chart[] = {
  "hovered",
  "active",
};
static const char* const slots_checkbox[] = {
  "checkbox",
};
static const char* const states_checkbox[] = {
  "checked",
  "unchecked",
  "indeterminate",
  "disabled",
};
static const char* const slots_collapsible[] = {
  "collapsible",
  "collapsible-trigger",
  "collapsible-content",
};
static const char* const states_collapsible[] = {
  "open",
  "closed",
  "disabled",
};
static const char* const slots_combobox[] = {
  "combobox",
  "popover",
  "command",
  "command-input",
  "command-item",
};
static const char* const states_combobox[] = {
  "open",
  "closed",
  "selected",
  "empty",
};
static const char* const slots_command[] = {
  "command",
  "command-input",
  "command-list",
  "command-group",
  "command-item",
  "command-empty",
};
static const char* const states_command[] = {
  "selected",
  "empty",
  "disabled",
};
static const char* const slots_context_menu[] = {
  "context-menu",
  "context-menu-trigger",
  "context-menu-content",
  "context-menu-item",
};
static const char* const states_context_menu[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_data_table[] = {
  "table",
  "table-header",
  "table-body",
  "table-row",
  "table-cell",
};
static const char* const states_data_table[] = {
  "sorted",
  "selected",
  "loading",
  "empty",
};
static const char* const slots_date_picker[] = {
  "popover",
  "calendar",
  "button",
  "field",
};
static const char* const states_date_picker[] = {
  "open",
  "selected",
  "empty",
};
static const char* const slots_dialog[] = {
  "dialog",
  "dialog-trigger",
  "dialog-content",
  "dialog-header",
  "dialog-footer",
};
static const char* const states_dialog[] = {
  "open",
  "closed",
  "focus-trap",
};
static const char* const slots_direction[] = {
  "direction-provider",
};
static const char* const states_direction[] = {
  "ltr",
  "rtl",
};
static const char* const slots_drawer[] = {
  "drawer",
  "drawer-trigger",
  "drawer-content",
  "drawer-header",
  "drawer-footer",
};
static const char* const states_drawer[] = {
  "open",
  "closed",
  "dragging",
};
static const char* const slots_dropdown_menu[] = {
  "dropdown-menu",
  "dropdown-menu-trigger",
  "dropdown-menu-content",
  "dropdown-menu-item",
};
static const char* const states_dropdown_menu[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_empty[] = {
  "empty",
  "empty-header",
  "empty-icon",
  "empty-title",
  "empty-description",
  "empty-content",
};
static const char* const states_empty[] = {
  "default",
  "loading",
};
static const char* const slots_field[] = {
  "field",
  "field-label",
  "field-title",
  "field-description",
  "field-error",
};
static const char* const states_field[] = {
  "invalid",
  "disabled",
  "required",
};
static const char* const slots_hover_card[] = {
  "hover-card",
  "hover-card-trigger",
  "hover-card-content",
};
static const char* const states_hover_card[] = {
  "open",
  "closed",
};
static const char* const slots_input[] = {
  "input",
};
static const char* const states_input[] = {
  "placeholder",
  "focus",
  "disabled",
  "invalid",
};
static const char* const slots_input_group[] = {
  "input-group",
  "input-group-input",
  "input-group-addon",
  "input-group-button",
};
static const char* const states_input_group[] = {
  "focus-within",
  "disabled",
  "invalid",
};
static const char* const slots_input_otp[] = {
  "input-otp",
  "input-otp-group",
  "input-otp-slot",
  "input-otp-separator",
};
static const char* const states_input_otp[] = {
  "active",
  "filled",
  "disabled",
};
static const char* const slots_item[] = {
  "item",
  "item-media",
  "item-content",
  "item-title",
  "item-description",
  "item-actions",
};
static const char* const states_item[] = {
  "selected",
  "disabled",
};
static const char* const slots_kbd[] = {
  "kbd",
};
static const char* const states_kbd[] = {
  0,
};
static const char* const slots_label[] = {
  "label",
};
static const char* const states_label[] = {
  "disabled",
};
static const char* const slots_menubar[] = {
  "menubar",
  "menubar-menu",
  "menubar-trigger",
  "menubar-content",
  "menubar-item",
};
static const char* const states_menubar[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_native_select[] = {
  "native-select",
};
static const char* const states_native_select[] = {
  "disabled",
  "invalid",
};
static const char* const slots_navigation_menu[] = {
  "navigation-menu",
  "navigation-menu-list",
  "navigation-menu-item",
  "navigation-menu-content",
};
static const char* const states_navigation_menu[] = {
  "open",
  "closed",
  "active",
};
static const char* const slots_pagination[] = {
  "pagination",
  "pagination-content",
  "pagination-item",
  "pagination-link",
};
static const char* const states_pagination[] = {
  "active",
  "disabled",
};
static const char* const slots_popover[] = {
  "popover",
  "popover-trigger",
  "popover-content",
  "popover-anchor",
};
static const char* const states_popover[] = {
  "open",
  "closed",
};
static const char* const slots_progress[] = {
  "progress",
  "progress-indicator",
};
static const char* const states_progress[] = {
  "determinate",
  "indeterminate",
};
static const char* const slots_radio_group[] = {
  "radio-group",
  "radio-group-item",
};
static const char* const states_radio_group[] = {
  "checked",
  "unchecked",
  "disabled",
};
static const char* const slots_resizable[] = {
  "resizable-panel-group",
  "resizable-panel",
  "resizable-handle",
};
static const char* const states_resizable[] = {
  "dragging",
  "horizontal",
  "vertical",
};
static const char* const slots_scroll_area[] = {
  "scroll-area",
  "scroll-area-viewport",
  "scroll-area-scrollbar",
  "scroll-area-thumb",
};
static const char* const states_scroll_area[] = {
  "scrolling",
  "horizontal",
  "vertical",
};
static const char* const slots_select[] = {
  "select",
  "select-trigger",
  "select-content",
  "select-item",
  "select-value",
};
static const char* const states_select[] = {
  "open",
  "closed",
  "selected",
  "disabled",
};
static const char* const slots_separator[] = {
  "separator",
};
static const char* const states_separator[] = {
  "horizontal",
  "vertical",
};
static const char* const slots_sheet[] = {
  "sheet",
  "sheet-trigger",
  "sheet-content",
  "sheet-header",
  "sheet-footer",
};
static const char* const states_sheet[] = {
  "open",
  "closed",
  "side-top",
  "side-right",
  "side-bottom",
  "side-left",
};
static const char* const slots_sidebar[] = {
  "sidebar",
  "sidebar-header",
  "sidebar-content",
  "sidebar-footer",
  "sidebar-menu",
};
static const char* const states_sidebar[] = {
  "expanded",
  "collapsed",
  "mobile",
  "active",
};
static const char* const slots_skeleton[] = {
  "skeleton",
};
static const char* const states_skeleton[] = {
  "loading",
};
static const char* const slots_slider[] = {
  "slider",
  "slider-track",
  "slider-range",
  "slider-thumb",
};
static const char* const states_slider[] = {
  "dragging",
  "disabled",
};
static const char* const slots_sonner[] = {
  "toaster",
  "toast",
  "toast-title",
  "toast-description",
  "toast-action",
};
static const char* const states_sonner[] = {
  "success",
  "info",
  "warning",
  "error",
  "loading",
};
static const char* const slots_switch[] = {
  "switch",
  "switch-thumb",
};
static const char* const states_switch[] = {
  "checked",
  "unchecked",
  "disabled",
};
static const char* const slots_table[] = {
  "table",
  "table-header",
  "table-body",
  "table-footer",
  "table-row",
  "table-cell",
};
static const char* const states_table[] = {
  "selected",
  "sortable",
};
static const char* const slots_tabs[] = {
  "tabs",
  "tabs-list",
  "tabs-trigger",
  "tabs-content",
};
static const char* const states_tabs[] = {
  "active",
  "inactive",
  "disabled",
};
static const char* const slots_textarea[] = {
  "textarea",
};
static const char* const states_textarea[] = {
  "placeholder",
  "focus",
  "disabled",
  "invalid",
};
static const char* const slots_toast[] = {
  "toast",
  "toast-title",
  "toast-description",
  "toast-action",
  "toast-close",
};
static const char* const states_toast[] = {
  "open",
  "closed",
  "success",
  "destructive",
};
static const char* const slots_toggle[] = {
  "toggle",
};
static const char* const states_toggle[] = {
  "pressed",
  "unpressed",
  "disabled",
};
static const char* const slots_toggle_group[] = {
  "toggle-group",
  "toggle-group-item",
};
static const char* const states_toggle_group[] = {
  "single",
  "multiple",
  "pressed",
  "disabled",
};
static const char* const slots_tooltip[] = {
  "tooltip",
  "tooltip-trigger",
  "tooltip-content",
};
static const char* const states_tooltip[] = {
  "open",
  "closed",
  "side-top",
  "side-right",
  "side-bottom",
  "side-left",
};

static const er_ui_component_spec_t component_catalog[] = {
  ER_UI_COMPONENT_ENTRY(
    "Accordion",
    "accordion",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Accordion",
    "accordion_node",
    slots_accordion,
    states_accordion),
  ER_UI_COMPONENT_ENTRY(
    "Alert",
    "alert",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Alert",
    "alert_node",
    slots_alert,
    states_alert),
  ER_UI_COMPONENT_ENTRY(
    "Alert Dialog",
    "alert-dialog",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "AlertDialog",
    "alert_dialog_node",
    slots_alert_dialog,
    states_alert_dialog),
  ER_UI_COMPONENT_EMPTY(
    "Aspect Ratio",
    "aspect-ratio",
    ER_UI_COMPONENT_CATEGORY_MEDIA,
    "AspectRatio",
    "aspect_ratio_node",
    slots_aspect_ratio,
    states_aspect_ratio),
  ER_UI_COMPONENT_ENTRY(
    "Avatar",
    "avatar",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Avatar",
    "avatar_node",
    slots_avatar,
    states_avatar),
  ER_UI_COMPONENT_ENTRY(
    "Badge",
    "badge",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Badge",
    "badge",
    slots_badge,
    states_badge),
  ER_UI_COMPONENT_ENTRY(
    "Breadcrumb",
    "breadcrumb",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Breadcrumb",
    "breadcrumb",
    slots_breadcrumb,
    states_breadcrumb),
  ER_UI_COMPONENT_ENTRY(
    "Button",
    "button",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Button",
    "button",
    slots_button,
    states_button),
  ER_UI_COMPONENT_ENTRY(
    "Button Group",
    "button-group",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "ButtonGroup",
    "button_group_node",
    slots_button_group,
    states_button_group),
  ER_UI_COMPONENT_ENTRY(
    "Calendar",
    "calendar",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Calendar",
    "calendar_node",
    slots_calendar,
    states_calendar),
  ER_UI_COMPONENT_ENTRY(
    "Card",
    "card",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Card",
    "card",
    slots_card,
    states_card),
  ER_UI_COMPONENT_ENTRY(
    "Carousel",
    "carousel",
    ER_UI_COMPONENT_CATEGORY_MEDIA,
    "Carousel",
    "carousel_node",
    slots_carousel,
    states_carousel),
  ER_UI_COMPONENT_ENTRY(
    "Chart",
    "chart",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Chart",
    "chart_node",
    slots_chart,
    states_chart),
  ER_UI_COMPONENT_ENTRY(
    "Checkbox",
    "checkbox",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Checkbox",
    "checkbox",
    slots_checkbox,
    states_checkbox),
  ER_UI_COMPONENT_ENTRY(
    "Collapsible",
    "collapsible",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Collapsible",
    "collapsible_node",
    slots_collapsible,
    states_collapsible),
  ER_UI_COMPONENT_ENTRY(
    "Combobox",
    "combobox",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Combobox",
    "combobox_node",
    slots_combobox,
    states_combobox),
  ER_UI_COMPONENT_ENTRY(
    "Command",
    "command",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Command",
    "command_palette",
    slots_command,
    states_command),
  ER_UI_COMPONENT_ENTRY(
    "Context Menu",
    "context-menu",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "ContextMenu",
    "context_menu_node",
    slots_context_menu,
    states_context_menu),
  ER_UI_COMPONENT_ENTRY(
    "Data Table",
    "data-table",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "DataTable",
    "data_table_node",
    slots_data_table,
    states_data_table),
  ER_UI_COMPONENT_ENTRY(
    "Date Picker",
    "date-picker",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "DatePicker",
    "date_picker_node",
    slots_date_picker,
    states_date_picker),
  ER_UI_COMPONENT_ENTRY(
    "Dialog",
    "dialog",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Dialog",
    "dialog",
    slots_dialog,
    states_dialog),
  ER_UI_COMPONENT_ENTRY(
    "Direction",
    "direction",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "DirectionProvider",
    "direction_node",
    slots_direction,
    states_direction),
  ER_UI_COMPONENT_ENTRY(
    "Drawer",
    "drawer",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Drawer",
    "drawer_node",
    slots_drawer,
    states_drawer),
  ER_UI_COMPONENT_ENTRY(
    "Dropdown Menu",
    "dropdown-menu",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "DropdownMenu",
    "dropdown_menu_node",
    slots_dropdown_menu,
    states_dropdown_menu),
  ER_UI_COMPONENT_ENTRY(
    "Empty",
    "empty",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Empty",
    "empty_state",
    slots_empty,
    states_empty),
  ER_UI_COMPONENT_ENTRY(
    "Field",
    "field",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Field",
    "field_node",
    slots_field,
    states_field),
  ER_UI_COMPONENT_ENTRY(
    "Hover Card",
    "hover-card",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "HoverCard",
    "hover_card_node",
    slots_hover_card,
    states_hover_card),
  ER_UI_COMPONENT_ENTRY(
    "Input",
    "input",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Input",
    "field_node",
    slots_input,
    states_input),
  ER_UI_COMPONENT_ENTRY(
    "Input Group",
    "input-group",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "InputGroup",
    "input_group_node",
    slots_input_group,
    states_input_group),
  ER_UI_COMPONENT_ENTRY(
    "Input OTP",
    "input-otp",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "InputOTP",
    "input_otp_node",
    slots_input_otp,
    states_input_otp),
  ER_UI_COMPONENT_ENTRY(
    "Item",
    "item",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Item",
    "list_row_node",
    slots_item,
    states_item),
  ER_UI_COMPONENT_EMPTY(
    "Kbd",
    "kbd",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Kbd",
    "kbd_node",
    slots_kbd,
    states_kbd),
  ER_UI_COMPONENT_ENTRY(
    "Label",
    "label",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Label",
    "text",
    slots_label,
    states_label),
  ER_UI_COMPONENT_ENTRY(
    "Menubar",
    "menubar",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Menubar",
    "menubar_node",
    slots_menubar,
    states_menubar),
  ER_UI_COMPONENT_ENTRY(
    "Native Select",
    "native-select",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "NativeSelect",
    "select_node",
    slots_native_select,
    states_native_select),
  ER_UI_COMPONENT_ENTRY(
    "Navigation Menu",
    "navigation-menu",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "NavigationMenu",
    "navigation_menu_node",
    slots_navigation_menu,
    states_navigation_menu),
  ER_UI_COMPONENT_ENTRY(
    "Pagination",
    "pagination",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Pagination",
    "pagination_node",
    slots_pagination,
    states_pagination),
  ER_UI_COMPONENT_ENTRY(
    "Popover",
    "popover",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Popover",
    "popover_node",
    slots_popover,
    states_popover),
  ER_UI_COMPONENT_ENTRY(
    "Progress",
    "progress",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Progress",
    "progress_bar_node",
    slots_progress,
    states_progress),
  ER_UI_COMPONENT_ENTRY(
    "Radio Group",
    "radio-group",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "RadioGroup",
    "radio",
    slots_radio_group,
    states_radio_group),
  ER_UI_COMPONENT_ENTRY(
    "Resizable",
    "resizable",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Resizable",
    "resizable_node",
    slots_resizable,
    states_resizable),
  ER_UI_COMPONENT_ENTRY(
    "Scroll Area",
    "scroll-area",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "ScrollArea",
    "scroll_area",
    slots_scroll_area,
    states_scroll_area),
  ER_UI_COMPONENT_ENTRY(
    "Select",
    "select",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Select",
    "select_node",
    slots_select,
    states_select),
  ER_UI_COMPONENT_ENTRY(
    "Separator",
    "separator",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Separator",
    "divider",
    slots_separator,
    states_separator),
  ER_UI_COMPONENT_ENTRY(
    "Sheet",
    "sheet",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Sheet",
    "sheet_node",
    slots_sheet,
    states_sheet),
  ER_UI_COMPONENT_ENTRY(
    "Sidebar",
    "sidebar",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Sidebar",
    "sidebar_node",
    slots_sidebar,
    states_sidebar),
  ER_UI_COMPONENT_ENTRY(
    "Skeleton",
    "skeleton",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Skeleton",
    "skeleton",
    slots_skeleton,
    states_skeleton),
  ER_UI_COMPONENT_ENTRY(
    "Slider",
    "slider",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Slider",
    "slider_node",
    slots_slider,
    states_slider),
  ER_UI_COMPONENT_ENTRY(
    "Sonner",
    "sonner",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Sonner",
    "toast",
    slots_sonner,
    states_sonner),
  ER_UI_COMPONENT_ENTRY(
    "Switch",
    "switch",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Switch",
    "toggle_node",
    slots_switch,
    states_switch),
  ER_UI_COMPONENT_ENTRY(
    "Table",
    "table",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Table",
    "table_node",
    slots_table,
    states_table),
  ER_UI_COMPONENT_ENTRY(
    "Tabs",
    "tabs",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Tabs",
    "tabs_node",
    slots_tabs,
    states_tabs),
  ER_UI_COMPONENT_ENTRY(
    "Textarea",
    "textarea",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Textarea",
    "text_area_node",
    slots_textarea,
    states_textarea),
  ER_UI_COMPONENT_ENTRY(
    "Toast",
    "toast",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Toast",
    "toast",
    slots_toast,
    states_toast),
  ER_UI_COMPONENT_ENTRY(
    "Toggle",
    "toggle",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Toggle",
    "toggle_node",
    slots_toggle,
    states_toggle),
  ER_UI_COMPONENT_ENTRY(
    "Toggle Group",
    "toggle-group",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "ToggleGroup",
    "toggle_group_node",
    slots_toggle_group,
    states_toggle_group),
  ER_UI_COMPONENT_ENTRY(
    "Tooltip",
    "tooltip",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Tooltip",
    "tooltip",
    slots_tooltip,
    states_tooltip),
};

const char* er_ui_component_category_label(er_ui_component_category_t category) {
  switch (category) {
    case ER_UI_COMPONENT_CATEGORY_FOUNDATION: return "Foundation";
    case ER_UI_COMPONENT_CATEGORY_FORM: return "Form";
    case ER_UI_COMPONENT_CATEGORY_OVERLAY: return "Overlay";
    case ER_UI_COMPONENT_CATEGORY_NAVIGATION: return "Navigation";
    case ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY: return "Data Display";
    case ER_UI_COMPONENT_CATEGORY_FEEDBACK: return "Feedback";
    case ER_UI_COMPONENT_CATEGORY_LAYOUT: return "Layout";
    case ER_UI_COMPONENT_CATEGORY_MEDIA: return "Media";
    default: return "";
  }
}

const char* er_ui_component_status_label(er_ui_component_status_t status) {
  switch (status) {
    case ER_UI_COMPONENT_STATUS_CATALOGED: return "Cataloged";
    case ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE: return "Native primitive";
    case ER_UI_COMPONENT_STATUS_EXACT_PORT: return "Exact port";
    default: return "";
  }
}

const char* er_ui_component_resolve_kind_label(er_ui_component_resolve_kind_t kind) {
  switch (kind) {
    case ER_UI_COMPONENT_RESOLVE_SLUG: return "Slug";
    case ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT: return "Source component";
    case ER_UI_COMPONENT_RESOLVE_MODULE_PATH: return "Module path";
    case ER_UI_COMPONENT_RESOLVE_SLOT: return "Slot";
    default: return "";
  }
}

const er_ui_component_spec_t* er_ui_component_at(size_t index) {
  return index < ER_UI_COMPONENT_COUNT ? &component_catalog[index] : 0;
}

size_t er_ui_component_count(void) { return ER_UI_COMPONENT_COUNT; }

bool er_ui_component_has_native_renderer(const er_ui_component_spec_t* spec) {
  return spec
    && (spec->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
      || spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT);
}

bool er_ui_component_is_exact_port(const er_ui_component_spec_t* spec) {
  return spec && spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT;
}

bool er_ui_component_uses_slot(const er_ui_component_spec_t* spec, const char* slot) {
  return spec && er_ui_component_list_contains(spec->slots, spec->slot_count, slot);
}

bool er_ui_component_uses_state(const er_ui_component_spec_t* spec, const char* state) {
  return spec && er_ui_component_list_contains(spec->states, spec->state_count, state);
}

const er_ui_component_spec_t* er_ui_component_find_by_slug(const char* slug) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    if (er_ui_component_streq(component_catalog[i].slug, slug)) {
      return &component_catalog[i];
    }
  }
  return 0;
}

const er_ui_component_spec_t* er_ui_component_find_by_source_component(const char* source_component) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    if (er_ui_component_streq(component_catalog[i].source_component, source_component)) {
      return &component_catalog[i];
    }
  }
  return 0;
}

static bool er_ui_component_is_upper(char c) { return c >= 'A' && c <= 'Z'; }
static char er_ui_component_lower(char c) {
  return er_ui_component_is_upper(c) ? (char)(c + 32) : c;
}

static bool er_ui_component_normalize_identifier(const char* identifier, char* out, size_t cap, bool* out_from_path) {
  if (!identifier || !out || cap == 0u || !out_from_path) return false;
  static const char data_slot_prefix[] = "data-slot=";
  const size_t data_slot_prefix_len = ER_UI_COMPONENT_ARRAY_COUNT(data_slot_prefix) - 1u;
  const char* start = identifier;
  while (*start == ' ' || *start == '\t' || *start == '\n' || *start == '\r') start++;
  const char* end = start;
  while (*end) end++;
  while (end > start && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\n' || end[-1] == '\r')) end--;
  if (er_ui_component_range_starts_with(start, end, data_slot_prefix, data_slot_prefix_len)) {
    start += data_slot_prefix_len;
    while (start < end && (*start == '\"' || *start == '\'')) start++;
    while (end > start && (end[-1] == '\"' || end[-1] == '\'')) end--;
  }
  *out_from_path = false;
  const char* last = start;
  for (const char* p = start; p < end; ++p) {
    if (*p == '/') { *out_from_path = true; last = p + 1; }
  }
  start = last;
  if (er_ui_component_ends_with_len(start, end, ".tsx", ER_UI_COMPONENT_SUFFIX_TSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".jsx", ER_UI_COMPONENT_SUFFIX_JSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".ts", ER_UI_COMPONENT_SUFFIX_TS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TS_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".js", ER_UI_COMPONENT_SUFFIX_JS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JS_LEN;
  }
  bool needs_kebab = false;
  for (const char* p = start; p < end; ++p) {
    if (er_ui_component_is_upper(*p) || *p == '_' || *p == ' ') needs_kebab = true;
  }
  size_t n = 0u;
  bool previous_was_separator = true;
  for (const char* p = start; p < end; ++p) {
    char ch = *p;
    if (needs_kebab && (ch == '_' || ch == ' ')) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      previous_was_separator = true;
      continue;
    }
    if (needs_kebab && er_ui_component_is_upper(ch)) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      if (n + 1u >= cap) return false;
      out[n++] = er_ui_component_lower(ch);
      previous_was_separator = false;
      continue;
    }
    if (n + 1u >= cap) return false;
    out[n++] = er_ui_component_lower(ch);
    previous_was_separator = ch == '-';
  }
  out[n] = '\0';
  return n > 0u;
}

bool er_ui_component_resolve_identifier(const char* identifier, er_ui_component_resolved_t* out_resolved) {
  if (!identifier || !out_resolved) return false;
  const char* trimmed = identifier;
  while (*trimmed == ' ' || *trimmed == '\t' || *trimmed == '\n' || *trimmed == '\r') trimmed++;
  const er_ui_component_spec_t* direct_source = er_ui_component_find_by_source_component(trimmed);
  if (direct_source) {
    out_resolved->spec = direct_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  char normalized[ER_UI_COMPONENT_IDENTIFIER_CAPACITY];
  bool from_path = false;
  if (!er_ui_component_normalize_identifier(identifier, normalized, sizeof(normalized), &from_path)) return false;
  const er_ui_component_spec_t* by_slug = er_ui_component_find_by_slug(normalized);
  if (by_slug) {
    out_resolved->spec = by_slug;
    out_resolved->kind = from_path ? ER_UI_COMPONENT_RESOLVE_MODULE_PATH : ER_UI_COMPONENT_RESOLVE_SLUG;
    return true;
  }
  const er_ui_component_spec_t* by_source = er_ui_component_find_by_source_component(normalized);
  if (by_source) {
    out_resolved->spec = by_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (er_ui_component_uses_slot(component, normalized)) {
      out_resolved->spec = component;
      out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SLOT;
      return true;
    }
    component++;
  }
  return false;
}

bool er_ui_component_port_mapping_for_identifier(const char* identifier, er_ui_component_port_mapping_t* out_mapping) {
  if (!identifier || !out_mapping) return false;
  er_ui_component_resolved_t resolved = {0};
  if (!er_ui_component_resolve_identifier(identifier, &resolved)) return false;
  out_mapping->identifier = identifier;
  out_mapping->resolve_kind = resolved.kind;
  out_mapping->slug = resolved.spec->slug;
  out_mapping->source_component = resolved.spec->source_component;
  out_mapping->edge_builder = resolved.spec->edge_builder;
  out_mapping->category = resolved.spec->category;
  out_mapping->status = resolved.spec->status;
  out_mapping->native_renderer = er_ui_component_has_native_renderer(resolved.spec);
  out_mapping->exact_port = er_ui_component_is_exact_port(resolved.spec);
  return true;
}

size_t er_ui_component_native_count(void) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
      || component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT) {
      count++;
    }
    component++;
  }
  return count;
}
size_t er_ui_component_exact_count(void) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT) count++;
    component++;
  }
  return count;
}
size_t er_ui_component_count_by_category(er_ui_component_category_t category) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->category == category) count++;
    component++;
  }
  return count;
}
size_t er_ui_component_count_by_status(er_ui_component_status_t status) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == status) count++;
    component++;
  }
  return count;
}

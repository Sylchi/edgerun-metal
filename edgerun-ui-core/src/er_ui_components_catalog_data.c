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
static const char* const slots_invoice_card[] = {
  "card",
  "card-header",
  "badge",
  "table",
  "scroll-area",
  "card-footer",
  "button",
};
static const char* const states_invoice_card[] = {
  "pending",
  "paid",
  "overflow-x",
  "actionable",
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
static const char* const slots_spinner[] = {
  "spinner",
};
static const char* const states_spinner[] = {
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
  ER_UI_COMPONENT_NATIVE(
    "Data Table",
    "data-table",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "DataTable",
    "data_table_node",
    slots_data_table,
    states_data_table),
  ER_UI_COMPONENT_NATIVE(
    "Invoice Card",
    "invoice-card",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Card",
    "invoice_card",
    slots_invoice_card,
    states_invoice_card),
  ER_UI_COMPONENT_NATIVE(
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
    "Spinner",
    "spinner",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Spinner",
    "spinner",
    slots_spinner,
    states_spinner),
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
  ER_UI_COMPONENT_NATIVE(
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

const er_ui_component_spec_t* er_ui_component_catalog_data_at(size_t index) {
  return index < ER_UI_COMPONENT_COUNT ? &component_catalog[index] : 0;
}

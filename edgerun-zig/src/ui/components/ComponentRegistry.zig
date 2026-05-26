const component_contract = @import("ComponentContract.zig");

const accordion_component = @import("Accordion.zig");
const alert_component = @import("Alert.zig");
const alert_dialog_component = @import("AlertDialog.zig");
const aspect_ratio_component = @import("AspectRatio.zig");
const avatar_component = @import("Avatar.zig");
const badge_component = @import("Badge.zig");
const breadcrumb_component = @import("Breadcrumb.zig");
const button_component = @import("Button.zig");
const button_group_component = @import("ButtonGroup.zig");
const calendar_component = @import("Calendar.zig");
const card_component = @import("Card.zig");
const carousel_component = @import("Carousel.zig");
const chart_component = @import("Chart.zig");
const checkbox_component = @import("Checkbox.zig");
const combobox_component = @import("Combobox.zig");
const command_component = @import("Command.zig");
const context_menu_component = @import("ContextMenu.zig");
const dialog_component = @import("Dialog.zig");
const direction_component = @import("Direction.zig");
const drawer_component = @import("Drawer.zig");
const dropdown_menu_component = @import("DropdownMenu.zig");
const empty_component = @import("Empty.zig");
const field_component = @import("Field.zig");
const hover_card_component = @import("HoverCard.zig");
const icon_component = @import("Icon.zig");
const input_component = @import("Input.zig");
const input_group_component = @import("InputGroup.zig");
const input_otp_component = @import("InputOtp.zig");
const kbd_component = @import("Kbd.zig");
const label_component = @import("Label.zig");
const menubar_component = @import("Menubar.zig");
const navigation_menu_component = @import("NavigationMenu.zig");
const pagination_component = @import("Pagination.zig");
const popover_component = @import("Popover.zig");
const progress_component = @import("Progress.zig");
const radio_group_component = @import("RadioGroup.zig");
const resizable_component = @import("Resizable.zig");
const row_item_component = @import("RowItem.zig");
const scroll_area_component = @import("ScrollArea.zig");
const select_component = @import("Select.zig");
const separator_component = @import("Separator.zig");
const sheet_component = @import("Sheet.zig");
const sidebar_component = @import("Sidebar.zig");
const skeleton_component = @import("Skeleton.zig");
const slider_component = @import("Slider.zig");
const spinner_component = @import("Spinner.zig");
const switch_component = @import("Switch.zig");
const table_component = @import("Table.zig");
const tabs_component = @import("Tabs.zig");
const textarea_component = @import("Textarea.zig");
const text_component = @import("Text.zig");
const toast_component = @import("Toast.zig");
const toggle_component = @import("Toggle.zig");
const toggle_group_component = @import("ToggleGroup.zig");
const tooltip_component = @import("Tooltip.zig");

pub const registrations = .{
    text_component.registration,
    accordion_component.registration,
    alert_component.registration,
    alert_dialog_component.registration,
    aspect_ratio_component.registration,
    calendar_component.registration,
    carousel_component.registration,
    chart_component.registration,
    combobox_component.registration,
    card_component.registration,
    empty_component.registration,
    badge_component.registration,
    avatar_component.registration,
    kbd_component.registration,
    label_component.registration,
    separator_component.registration,
    scroll_area_component.registration,
    skeleton_component.registration,
    spinner_component.registration,
    breadcrumb_component.registration,
    menubar_component.registration,
    navigation_menu_component.registration,
    command_component.registration,
    context_menu_component.registration,
    dialog_component.registration,
    direction_component.registration,
    drawer_component.registration,
    dropdown_menu_component.registration,
    field_component.registration,
    hover_card_component.registration,
    input_otp_component.registration,
    icon_component.registration,
    button_component.registration,
    button_component.icon_button_registration,
    button_group_component.registration,
    toggle_group_component.registration,
    toggle_component.registration,
    input_component.registration,
    input_group_component.registration,
    textarea_component.registration,
    select_component.registration,
    checkbox_component.registration,
    radio_group_component.registration,
    switch_component.registration,
    pagination_component.registration,
    popover_component.registration,
    resizable_component.registration,
    sheet_component.registration,
    sidebar_component.registration,
    progress_component.registration,
    slider_component.registration,
    tabs_component.registration,
    table_component.registration,
    tooltip_component.registration,
    toast_component.registration,
    row_item_component.registration,
};

pub fn Payload(comptime name: []const u8) type {
    return component_contract.payload(registrations, name);
}

pub fn assertMatches(comptime Component: type) void {
    component_contract.assertMatches(registrations, Component);
}

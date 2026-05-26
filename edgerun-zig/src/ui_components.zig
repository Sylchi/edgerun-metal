const interaction = @import("ui_interaction.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const component_common = @import("ui_component_common.zig");
const component_union = @import("ui/components/Component.zig");
const component_io = @import("ui/components/ComponentIO.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const tree_component = @import("ui/components/Tree.zig");
const stack_component = @import("ui/components/Stack.zig");
const slot_component = @import("ui/components/Slot.zig");
const text_component = @import("ui/components/Text.zig");
const accordion_component = @import("ui/components/Accordion.zig");
const alert_component = @import("ui/components/Alert.zig");
const alert_dialog_component = @import("ui/components/AlertDialog.zig");
const aspect_ratio_component = @import("ui/components/AspectRatio.zig");
const calendar_component = @import("ui/components/Calendar.zig");
const carousel_component = @import("ui/components/Carousel.zig");
const chart_component = @import("ui/components/Chart.zig");
const combobox_component = @import("ui/components/Combobox.zig");
const card_component = @import("ui/components/Card.zig");
const empty_component = @import("ui/components/Empty.zig");
const button_component = @import("ui/components/Button.zig");
const button_group_component = @import("ui/components/ButtonGroup.zig");
const toggle_group_component = @import("ui/components/ToggleGroup.zig");
const badge_component = @import("ui/components/Badge.zig");
const avatar_component = @import("ui/components/Avatar.zig");
const kbd_component = @import("ui/components/Kbd.zig");
const label_component = @import("ui/components/Label.zig");
const separator_component = @import("ui/components/Separator.zig");
const scroll_area_component = @import("ui/components/ScrollArea.zig");
const skeleton_component = @import("ui/components/Skeleton.zig");
const spinner_component = @import("ui/components/Spinner.zig");
const breadcrumb_component = @import("ui/components/Breadcrumb.zig");
const menubar_component = @import("ui/components/Menubar.zig");
const navigation_menu_component = @import("ui/components/NavigationMenu.zig");
const command_component = @import("ui/components/Command.zig");
const context_menu_component = @import("ui/components/ContextMenu.zig");
const dialog_component = @import("ui/components/Dialog.zig");
const direction_component = @import("ui/components/Direction.zig");
const drawer_component = @import("ui/components/Drawer.zig");
const dropdown_menu_component = @import("ui/components/DropdownMenu.zig");
const field_component = @import("ui/components/Field.zig");
const hover_card_component = @import("ui/components/HoverCard.zig");
const input_otp_component = @import("ui/components/InputOtp.zig");
const input_component = @import("ui/components/Input.zig");
const input_group_component = @import("ui/components/InputGroup.zig");
const textarea_component = @import("ui/components/Textarea.zig");
const select_component = @import("ui/components/Select.zig");
const checkbox_component = @import("ui/components/Checkbox.zig");
const radio_group_component = @import("ui/components/RadioGroup.zig");
const switch_component = @import("ui/components/Switch.zig");
const pagination_component = @import("ui/components/Pagination.zig");
const popover_component = @import("ui/components/Popover.zig");
const resizable_component = @import("ui/components/Resizable.zig");
const sheet_component = @import("ui/components/Sheet.zig");
const sidebar_component = @import("ui/components/Sidebar.zig");
const toggle_component = @import("ui/components/Toggle.zig");
const progress_component = @import("ui/components/Progress.zig");
const slider_component = @import("ui/components/Slider.zig");
const tabs_component = @import("ui/components/Tabs.zig");
const table_component = @import("ui/components/Table.zig");
const tooltip_component = @import("ui/components/Tooltip.zig");
const toast_component = @import("ui/components/Toast.zig");
const row_item_component = @import("ui/components/RowItem.zig");
pub const layouts = @import("layouts.zig");

pub const Error = component_common.Error;

pub const Component = component_union.Component;

pub const ButtonVariant = component_common.ButtonVariant;
pub const BadgeVariant = component_common.BadgeVariant;
pub const SurfaceVariant = component_common.SurfaceVariant;
pub const RenderOptions = component_common.RenderOptions;
pub const Accessibility = component_common.Accessibility;
pub const AccessibilityNode = component_common.AccessibilityNode;
pub const AccessibilityTree = component_common.AccessibilityTree;
pub const encoded_icon_count = component_common.encoded_icon_count;

pub const Text = text_component.Text;

pub const Accordion = accordion_component.Accordion;

pub const Alert = alert_component.Alert;

pub const AlertDialog = alert_dialog_component.AlertDialog;

pub const AspectRatio = aspect_ratio_component.AspectRatio;

pub const Calendar = calendar_component.Calendar;

pub const Carousel = carousel_component.Carousel;

pub const Chart = chart_component.Chart;

pub const Combobox = combobox_component.Combobox;

pub const Card = card_component.Card;

pub const Empty = empty_component.Empty;

pub const Button = button_component.Button;

pub const IconButton = button_component.IconButton;

pub const ButtonGroup = button_group_component.ButtonGroup;

pub const ToggleGroup = toggle_group_component.ToggleGroup;

pub const Badge = badge_component.Badge;

pub const Avatar = avatar_component.Avatar;

pub const Kbd = kbd_component.Kbd;

pub const Label = label_component.Label;

pub const Separator = separator_component.Separator;

pub const ScrollArea = scroll_area_component.ScrollArea;

pub const Skeleton = skeleton_component.Skeleton;

pub const Spinner = spinner_component.Spinner;

pub const Breadcrumb = breadcrumb_component.Breadcrumb;

pub const Menubar = menubar_component.Menubar;

pub const NavigationMenu = navigation_menu_component.NavigationMenu;

pub const Command = command_component.Command;

pub const ContextMenu = context_menu_component.ContextMenu;

pub const Dialog = dialog_component.Dialog;

pub const Direction = direction_component.Direction;

pub const Drawer = drawer_component.Drawer;

pub const DropdownMenu = dropdown_menu_component.DropdownMenu;

pub const Field = field_component.Field;

pub const HoverCard = hover_card_component.HoverCard;

pub const InputOtp = input_otp_component.InputOtp;

pub const Input = input_component.Input;

pub const InputGroup = input_group_component.InputGroup;

pub const Textarea = textarea_component.Textarea;

pub const Select = select_component.Select;

pub const Checkbox = checkbox_component.Checkbox;

pub const RadioGroup = radio_group_component.RadioGroup;

pub const Switch = switch_component.Switch;

pub const Pagination = pagination_component.Pagination;

pub const Popover = popover_component.Popover;

pub const Resizable = resizable_component.Resizable;

pub const Sheet = sheet_component.Sheet;

pub const Sidebar = sidebar_component.Sidebar;

pub const Toggle = toggle_component.Toggle;

pub const Progress = progress_component.Progress;

pub const Slider = slider_component.Slider;

pub const Tabs = tabs_component.Tabs;

pub const Table = table_component.Table;

pub const Tooltip = tooltip_component.Tooltip;

pub const Toast = toast_component.Toast;

pub const RowItem = row_item_component.RowItem;

pub fn renderComponent(scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    return component.render(scene, bounds, options);
}

pub fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    return node_renderer.renderNode(Component, scene, bounds, node, options);
}

pub fn collectComponentInteractions(collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    return component.collectInteractions(collector, bounds);
}

pub fn accessibility(component: Component) Accessibility {
    return component.accessibility();
}

pub fn collectAccessibility(tree: *AccessibilityTree, bounds: ui.Rect, component: Component, options: RenderOptions) component_common.AccessibilityError!void {
    return component.collectAccessibility(tree, bounds, options);
}

pub fn measureNode(node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return node_renderer.measureNode(Component, node, constraints, options);
}

pub const Stack = stack_component.Stack(Component);
pub const StackTree = stack_component.StackTree(Component);

pub const Slot = slot_component.Slot(Component);
pub const SlotTree = slot_component.SlotTree(Component);

pub const Tree = tree_component.Tree(Component);
pub const TreeObjects = tree_component.TreeObjects;

pub fn objectRequirements() object.Requirements {
    return component_io.requirements();
}

comptime {
    _ = @import("ui/components/ComponentTests.zig");
}

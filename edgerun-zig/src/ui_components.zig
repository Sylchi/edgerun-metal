const std = @import("std");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const ui_input = @import("input.zig");
const interaction = @import("ui_interaction.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const ui_tokens = @import("ui_tokens.zig");
const component_common = @import("ui_component_common.zig");
const component_codec = @import("ui/components/Codec.zig");
const component_io = @import("ui/components/ComponentIO.zig");
const component_test = @import("ui/components/TestSupport.zig");
const tree_codec = @import("ui/components/TreeCodec.zig");
const component_render = @import("ui/components/Render.zig");
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

const tree_layout_size = tree_codec.tree_layout_size;
const slot_layout_size = tree_codec.slot_layout_size;

pub const Error = component_common.Error;

pub const Component = union(enum) {
    text: Text,
    accordion: Accordion,
    alert: Alert,
    alert_dialog: AlertDialog,
    aspect_ratio: AspectRatio,
    calendar: Calendar,
    carousel: Carousel,
    chart: Chart,
    combobox: Combobox,
    card: Card,
    empty: Empty,
    badge: Badge,
    avatar: Avatar,
    kbd: Kbd,
    label: Label,
    separator: Separator,
    scroll_area: ScrollArea,
    skeleton: Skeleton,
    spinner: Spinner,
    breadcrumb: Breadcrumb,
    menubar: Menubar,
    navigation_menu: NavigationMenu,
    command: Command,
    context_menu: ContextMenu,
    dialog: Dialog,
    direction: Direction,
    drawer: Drawer,
    dropdown_menu: DropdownMenu,
    field: Field,
    hover_card: HoverCard,
    input_otp: InputOtp,
    button: Button,
    icon_button: IconButton,
    button_group: ButtonGroup,
    toggle_group: ToggleGroup,
    toggle: Toggle,
    input: Input,
    input_group: InputGroup,
    textarea: Textarea,
    select: Select,
    checkbox: Checkbox,
    radio_group: RadioGroup,
    switch_control: Switch,
    pagination: Pagination,
    popover: Popover,
    resizable: Resizable,
    sheet: Sheet,
    sidebar: Sidebar,
    progress: Progress,
    slider: Slider,
    tabs: Tabs,
    table: Table,
    tooltip: Tooltip,
    toast: Toast,
    row_item: RowItem,

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            .text => |component| component.node(),
            .accordion => |component| component.node(),
            .alert => |component| component.node(),
            .alert_dialog => |component| component.node(),
            .aspect_ratio => |component| component.node(),
            .calendar => |component| component.node(),
            .carousel => |component| component.node(),
            .chart => |component| component.node(),
            .combobox => |component| component.node(),
            .card => |component| component.node(),
            .empty => |component| component.node(),
            .badge => |component| component.node(),
            .avatar => |component| component.node(),
            .kbd => |component| component.node(),
            .label => |component| component.node(),
            .separator => |component| component.node(),
            .scroll_area => |component| component.node(),
            .skeleton => |component| component.node(),
            .spinner => |component| component.node(),
            .breadcrumb => |component| component.node(),
            .menubar => |component| component.node(),
            .navigation_menu => |component| component.node(),
            .command => |component| component.node(),
            .context_menu => |component| component.node(),
            .dialog => |component| component.node(),
            .direction => |component| component.node(),
            .drawer => |component| component.node(),
            .dropdown_menu => |component| component.node(),
            .field => |component| component.node(),
            .hover_card => |component| component.node(),
            .input_otp => |component| component.node(),
            .button => |component| component.node(),
            .icon_button => |component| component.node(),
            .button_group => |component| component.node(),
            .toggle_group => |component| component.node(),
            .toggle => |component| component.node(),
            .input => |component| component.node(),
            .input_group => |component| component.node(),
            .textarea => |component| component.node(),
            .select => |component| component.node(),
            .checkbox => |component| component.node(),
            .radio_group => |component| component.node(),
            .switch_control => |component| component.node(),
            .pagination => |component| component.node(),
            .popover => |component| component.node(),
            .resizable => |component| component.node(),
            .sheet => |component| component.node(),
            .sidebar => |component| component.node(),
            .progress => |component| component.node(),
            .slider => |component| component.node(),
            .tabs => |component| component.node(),
            .table => |component| component.node(),
            .tooltip => |component| component.node(),
            .toast => |component| component.node(),
            .row_item => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderComponent(scene, bounds, self, options);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectComponentInteractions(collector, bounds, self);
    }

    pub fn measure(self: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
        return component_render.measureComponent(Component, self, constraints, options);
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_io.writeObject(Component, self, ui_out, object_out, epoch);
    }

    pub fn fromObject(canonical: []const u8) Error!Component {
        const view = object.View.decode(canonical) catch return error.Corrupt;
        return fromView(view);
    }

    pub fn fromView(view: object.View) Error!Component {
        return fromNode(try component_codec.singleNode(view));
    }

    pub fn fromNode(node_value: ui.Node) Error!Component {
        return switch (node_value) {
            .text => |text| .{ .text = .{ .value = text.value } },
            .accordion => |accordion| .{ .accordion = .{ .id = accordion.id, .title = accordion.title, .detail = accordion.detail, .open = accordion.open } },
            .alert => |alert| .{ .alert = .{ .title = alert.title, .detail = alert.detail, .destructive = alert.destructive } },
            .alert_dialog => |dialog| .{ .alert_dialog = .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail } },
            .aspect_ratio => |aspect_ratio| .{ .aspect_ratio = .{ .ratio_w = aspect_ratio.ratio_w, .ratio_h = aspect_ratio.ratio_h } },
            .calendar => |calendar| .{ .calendar = .{ .id = calendar.id, .month = calendar.month, .selected_day = calendar.selected_day } },
            .carousel => |carousel| .{ .carousel = .{ .id = carousel.id, .label = carousel.label } },
            .chart => |chart| .{ .chart = .{ .id = chart.id, .label = chart.label } },
            .combobox => |combobox| .{ .combobox = .{ .id = combobox.id, .placeholder = combobox.placeholder, .selected = combobox.selected } },
            .card => |card| .{ .card = .{ .title = card.title, .detail = card.detail, .variant = card_component.variantFromTag(card.variant) catch return error.Corrupt } },
            .empty => |empty| .{ .empty = .{ .title = empty.title, .detail = empty.detail } },
            .badge => |badge| .{ .badge = .{ .label = badge.label, .variant = badge_component.variantFromTag(badge.variant) catch return error.Corrupt } },
            .avatar => |avatar| .{ .avatar = .{ .label = avatar.label } },
            .kbd => |kbd| .{ .kbd = .{ .label = kbd.label } },
            .label => |label| .{ .label = .{ .value = label.value } },
            .separator => .{ .separator = .{} },
            .scroll_area => .{ .scroll_area = .{} },
            .skeleton => .{ .skeleton = .{} },
            .spinner => .{ .spinner = .{} },
            .breadcrumb => |breadcrumb| .{ .breadcrumb = .{ .id = breadcrumb.id, .first = breadcrumb.first, .current = breadcrumb.current } },
            .menubar => |menubar| .{ .menubar = .{ .id = menubar.id, .first = menubar.first, .second = menubar.second, .active = menubar.active } },
            .navigation_menu => |menu| .{ .navigation_menu = .{ .id = menu.id, .first = menu.first, .second = menu.second, .active = menu.active } },
            .command => |command| .{ .command = .{ .id = command.id, .placeholder = command.placeholder } },
            .context_menu => |menu| .{ .context_menu = .{ .id = menu.id, .first = menu.first, .second = menu.second } },
            .dialog => |dialog| .{ .dialog = .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail } },
            .direction => |direction| .{ .direction = .{ .id = direction.id, .active = direction.active } },
            .drawer => |drawer| .{ .drawer = .{ .id = drawer.id, .title = drawer.title, .detail = drawer.detail } },
            .dropdown_menu => |menu| .{ .dropdown_menu = .{ .id = menu.id, .first = menu.first, .second = menu.second } },
            .field => |field| .{ .field = .{ .id = field.id, .label = field.label, .placeholder = field.placeholder } },
            .hover_card => |hover_card| .{ .hover_card = .{ .id = hover_card.id, .trigger = hover_card.trigger, .content = hover_card.content } },
            .input_otp => |otp| .{ .input_otp = .{ .id = otp.id, .value = otp.value } },
            .button => |button| .{ .button = .{ .id = button.id, .label = button.label, .variant = button_component.variantFromTag(button.variant) catch return error.Corrupt, .leading_icon = component_common.optionalIconFromTag(button.leading_icon) catch return error.Corrupt, .trailing_icon = component_common.optionalIconFromTag(button.trailing_icon) catch return error.Corrupt } },
            .icon_button => |button| .{ .icon_button = .{ .id = button.id, .label = button.label, .variant = button_component.variantFromTag(button.variant) catch return error.Corrupt, .icon_value = (component_common.optionalIconFromTag(button.icon) catch return error.Corrupt) orelse return error.Corrupt } },
            .button_group => |group| .{ .button_group = .{ .id = group.id, .first = group.first, .second = group.second, .active = group.active } },
            .toggle_group => |group| .{ .toggle_group = .{ .id = group.id, .first = group.first, .second = group.second, .active = group.active } },
            .toggle => |toggle| .{ .toggle = .{ .id = toggle.id, .label = toggle.label, .pressed = toggle.pressed } },
            .input => |input| .{ .input = .{ .id = input.id, .placeholder = input.placeholder, .leading_icon = component_common.optionalIconFromTag(input.leading_icon) catch return error.Corrupt } },
            .input_group => |input_group| .{ .input_group = .{ .id = input_group.id, .addon = input_group.addon, .placeholder = input_group.placeholder } },
            .textarea => |textarea| .{ .textarea = .{ .id = textarea.id, .placeholder = textarea.placeholder } },
            .select => |select| .{ .select = .{ .id = select.id, .label = select.label } },
            .checkbox => |checkbox| .{ .checkbox = .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked } },
            .radio_group => |radio| .{ .radio_group = .{ .id = radio.id, .first = radio.first, .second = radio.second, .selected = radio.selected } },
            .switch_control => |switch_control| .{ .switch_control = .{ .id = switch_control.id, .label = switch_control.label, .checked = switch_control.checked } },
            .pagination => |pagination| .{ .pagination = .{ .id = pagination.id, .page = pagination.page } },
            .popover => |popover| .{ .popover = .{ .id = popover.id, .trigger = popover.trigger, .content = popover.content } },
            .resizable => |resizable| .{ .resizable = .{ .id = resizable.id, .ratio = resizable.ratio } },
            .sheet => |sheet| .{ .sheet = .{ .id = sheet.id, .title = sheet.title, .detail = sheet.detail } },
            .sidebar => |sidebar| .{ .sidebar = .{ .id = sidebar.id, .title = sidebar.title, .item = sidebar.item } },
            .progress => |progress| .{ .progress = .{ .value = progress.value } },
            .slider => |slider| .{ .slider = .{ .id = slider.id, .label = slider.label, .value = slider.value } },
            .tabs => |tabs| .{ .tabs = .{ .id = tabs.id, .first = tabs.first, .second = tabs.second, .active = tabs.active } },
            .table => |table| .{ .table = .{ .id = table.id, .name = table.name, .role = table.role } },
            .tooltip => |tooltip| .{ .tooltip = .{ .id = tooltip.id, .trigger = tooltip.trigger, .content = tooltip.content } },
            .toast => |toast| .{ .toast = .{ .id = toast.id, .title = toast.title, .detail = toast.detail } },
            .row_item => |row| .{ .row_item = .{ .id = row.id, .title = row.title, .detail = row.detail } },
            else => error.UnsupportedComponent,
        };
    }
};

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
    return component_render.renderComponent(Component, scene, bounds, component, options);
}

pub fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    if (!bounds.valid()) return error.InvalidBounds;
    switch (node) {
        .rect => |rect| try scene.pushRect(bounds, rect.color, .fill, 0.0, 0.0),
        .text => |text| try scene.pushText(bounds, text.value, text.color orelse options.style.text),
        .slot => |slot| try renderNode(scene, bounds, slot.child.*, options),
        .stack => |stack| try renderNodeStack(scene, bounds, stack, options),
        else => {
            const component = Component.fromNode(node) catch return error.UnsupportedComponent;
            try renderComponent(scene, bounds, component, options);
        },
    }
}

pub fn collectComponentInteractions(collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    return component_render.collectComponentInteractions(Component, collector, bounds, component);
}

pub fn accessibility(component: Component) Accessibility {
    return component_render.accessibility(Component, component);
}

pub fn collectAccessibility(tree: *AccessibilityTree, bounds: ui.Rect, component: Component, options: RenderOptions) component_common.AccessibilityError!void {
    return component_render.collectAccessibility(Component, tree, bounds, component, options);
}

pub fn measureNode(node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return switch (node) {
        .rect, .text => primitiveNodeMeasurement(node, constraints),
        .slot => |slot| measureNode(slot.child.*, constraints, options),
        .stack => |stack| measureNodeStack(stack, constraints, options),
        else => if (Component.fromNode(node)) |component|
            component_render.measureComponent(Component, component, constraints, options)
        else |_|
            primitiveNodeMeasurement(node, constraints),
    };
}

fn renderNodeStack(scene: *ui.Scene, bounds: ui.Rect, stack: ui.Layout, options: RenderOptions) ui.RenderError!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > node_stack_max_children) return error.CommandBudgetExceeded;

    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    var child_bounds: [node_stack_max_children]ui.Rect = undefined;
    const placed_children = placeNodeStackChildren(bounds, stack, options, &child_measurements, &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderNode(scene, child_rect, child, options);
    }
}

fn measureNodeStack(stack: ui.Layout, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    const child_constraints = component_render.stackChildConstraintsFor(stack.axis, stack.padding, constraints);
    const measured_children = measureNodeChildren(stack.children, child_constraints, options, &child_measurements);
    return layouts.Flex.measure(measured_children, constraints, nodeStackLayoutOptionsFor(stack));
}

fn placeNodeStackChildren(bounds: ui.Rect, stack: ui.Layout, options: RenderOptions, measurements: *[node_stack_max_children]layouts.types.Measurement, out: *[node_stack_max_children]ui.Rect) []ui.Rect {
    const constraints = component_render.constraintsFromBounds(bounds);
    const child_constraints = component_render.stackChildConstraintsFor(stack.axis, stack.padding, constraints);
    const measured_children = measureNodeChildren(stack.children, child_constraints, options, measurements);
    return layouts.Flex.place(bounds, measured_children, nodeStackLayoutOptionsFor(stack), out);
}

fn measureNodeChildren(children: []const ui.Node, constraints: layouts.types.Constraints, options: RenderOptions, out: []layouts.types.Measurement) []layouts.types.Measurement {
    const count = @min(children.len, @min(out.len, node_stack_max_children));
    for (children[0..count], 0..) |child, index| {
        out[index] = measureNode(child, constraints, options);
    }
    return out[0..count];
}

fn nodeStackLayoutOptionsFor(stack: ui.Layout) layouts.Flex.Options {
    return component_render.stackLayoutOptionsFor(stack.axis, stack.gap, stack.padding, nodeStackCrossAlign(stack.cross_align));
}

fn nodeStackCrossAlign(value: ui.Align) layouts.Flex.Align {
    return switch (value) {
        .start => .start,
        .center, .end => .start,
        .stretch => .stretch,
    };
}

fn primitiveNodeMeasurement(node: ui.Node, constraints: layouts.types.Constraints) layouts.types.Measurement {
    const size = node.preferredSize();
    const preferred = component_render.constrainPreferredSize(size, constraints);
    return layouts.types.Measurement.flexible(
        .{ .w = @min(size.w, preferred.w), .h = @min(size.h, preferred.h) },
        preferred,
        .{ .w = node_measure_max_width, .h = size.h },
    ).applyExact(constraints);
}

const node_stack_max_children: usize = 64;
const node_measure_max_width: f32 = 4096.0;

pub const Tree = union(enum) {
    stack: Stack,
    slot: Slot,

    pub fn node(self: Tree, out_nodes: []ui.Node) ?ui.Node {
        return switch (self) {
            .stack => |stack| stack.node(out_nodes),
            .slot => |slot| slot.node(out_nodes),
        };
    }

    pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!Tree {
        try component_io.validateTreeView(tree);
        if (tree.header.kind != .tree or resolved_children.len == 0) return error.Corrupt;
        if (tree_codec.isTreeLayout(resolved_children[0])) {
            return .{ .stack = try StackTree.fromTree(tree, resolved_children, out_components) };
        }
        if (tree_codec.isSlotLayout(resolved_children[0])) {
            return .{ .slot = try SlotTree.fromTree(tree, resolved_children) };
        }
        return error.UnsupportedComponent;
    }
};

pub const TreeObjects = tree_codec.TreeObjects;

pub const Stack = stack_component.Stack(Component);
pub const StackTree = stack_component.StackTree(Component);

pub const Slot = slot_component.Slot(Component);
pub const SlotTree = slot_component.SlotTree(Component);

pub fn objectRequirements() object.Requirements {
    return component_io.requirements();
}

fn testReq() object.Requirements {
    return objectRequirements();
}

fn testEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}

test "component deserializer rejects wrong component kind" {
    const text = Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}

test "component union roundtrips concrete component objects" {
    const component = Component{ .icon_button = .{ .id = 14, .label = "Search", .icon_value = .search } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const decoded = try Component.fromObject(canonical);

    try std.testing.expectEqual(@as(u32, 14), decoded.icon_button.id);
    try std.testing.expectEqualStrings("Search", decoded.icon_button.label);
    try std.testing.expectEqual(icon.Icon.search, decoded.icon_button.icon_value);
}

test "component union decodes only canonical component objects" {
    const component = Component{ .badge = .{ .label = "Object", .variant = .secondary } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.meta.eql(component_io.requirements(), view.header.requirements));
    try std.testing.expectError(error.Corrupt, Component.fromObject(view.body));
}

test "component union rejects objects without component requirements" {
    const component = Component{ .button = .{ .id = 7, .label = "Wrong req" } };
    var req = testReq();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_io.writeRecord(Component, &writer, 0, component));
    const canonical = writer.objectNode(&object_raw, req, testEpoch()).?;

    try std.testing.expectError(error.Corrupt, Component.fromObject(canonical));
}

test "stack component serializes leaf composition to canonical object" {
    const children = [_]Component{
        .{ .text = .{ .value = "Title" } },
        .{ .badge = .{ .label = "Ready" } },
        .{ .input = .{ .id = 1, .placeholder = "Filter" } },
        .{ .checkbox = .{ .id = 3, .label = "Only active", .checked = true } },
        .{ .button = .{ .id = 2, .label = "Apply" } },
    };
    const stack = Stack{ .axis = .column, .gap = 10, .padding = 16, .children = &children };
    var ui_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;

    const canonical = stack.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    var decoded_children: [5]Component = undefined;
    const decoded = try Stack.fromView(view, &decoded_children);
    try std.testing.expectEqual(ui.Axis.column, decoded.axis);
    try std.testing.expectEqual(@as(u16, 10), decoded.gap);
    try std.testing.expectEqual(@as(u16, 16), decoded.padding);
    try std.testing.expectEqual(@as(usize, 5), decoded.children.len);
    try std.testing.expectEqualStrings("Title", decoded.children[0].text.value);
    try std.testing.expectEqualStrings("Ready", decoded.children[1].badge.label);
    try std.testing.expectEqual(@as(u32, 1), decoded.children[2].input.id);
    try std.testing.expect(decoded.children[3].checkbox.checked);
    try std.testing.expectEqualStrings("Apply", decoded.children[4].button.label);
}

test "stack measure render and interaction collection use layout placement" {
    const children = [_]Component{
        .{ .text = .{ .value = "Intro" } },
        .{ .button = .{ .id = 41002, .label = "Continue" } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
    const measured = stack.measure(.{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try std.testing.expectEqual(@as(f32, 160), measured.preferred.w);
    try std.testing.expect(measured.preferred.h > 0);
    try stack.render(&scene, ui.Rect.init(0, 0, 160, measured.preferred.h), .{});
    try stack.collectInteractions(&collector, ui.Rect.init(0, 0, 160, measured.preferred.h), .{});
    const hit = ui_input.hitTest(collector.written(), 16, 40).?;
    try std.testing.expectEqual(@as(u32, 41002), hit.id);
}

test "primitive node measurement respects at-most constraints" {
    const node = ui.inputNode(1, "Filter");
    const measured = measureNode(node, .{ .width = .{ .at_most = 96.0 }, .height = .{ .at_most = 28.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 96.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 28.0), measured.preferred.h);
}

test "node stack layout keeps existing cross alignment policy" {
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.start));
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.center));
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.end));
    try std.testing.expectEqual(layouts.Flex.Align.stretch, nodeStackCrossAlign(.stretch));
}

test "primitive node rendering uses scene command helpers" {
    var commands: [4]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try std.testing.expect(try scene.pushClip(ui.Rect.init(0, 0, 40, 40)));

    try renderNode(&scene, ui.Rect.init(30, 30, 20, 20), .{ .rect = .{ .color = .accent } }, .{});
    try renderNode(&scene, ui.Rect.init(2, 4, 20, 12), .{ .text = .{ .value = "node", .color = .muted } }, .{});

    try std.testing.expectEqual(ui.Rect.init(30, 30, 10, 10), scene.commandAt(0).?.rect.bounds);
    try std.testing.expectEqual(ui.Rect.init(2, 4, 20, 12), scene.commandAt(1).?.text.origin);
    try std.testing.expectEqual(ui.Color.muted, scene.commandAt(1).?.text.color);
}

test "slot component wraps a leaf component and renders the child" {
    const slot = Slot{
        .id = 99,
        .child = .{ .button = .{ .id = 12, .label = "Inside" } },
    };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slot.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const decoded = try Slot.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(@as(u32, 99), decoded.id);
    try std.testing.expectEqual(@as(u32, 12), decoded.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = decoded.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderNode(&scene, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, root, .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Inside"));
}

test "slot component rejects non-slot object roots" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    const canonical = (Button{ .id = 12, .label = "Plain" }).toObject(&ui_raw, &object_raw, testEpoch()).?;

    try std.testing.expectError(error.UnsupportedComponent, Slot.fromView(try object.View.decode(canonical)));
}

test "stack tree composes child component objects with explicit resolver input" {
    var title_ui: [128]u8 = undefined;
    var title_object_raw: [object.header_size + 128]u8 = undefined;
    const title_object = (Text{ .value = "Tree" }).toObject(&title_ui, &title_object_raw, testEpoch()).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 77, .label = "Open" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;

    const child_views = [_]object.View{
        try object.View.decode(title_object),
        try object.View.decode(button_object),
    };
    const tree_builder = StackTree{ .axis = .column, .gap = 6, .padding = 10, .children = &child_views };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;
    const tree_view = try object.View.decode(tree_objects.tree);
    const layout_view = try object.View.decode(tree_objects.layout);

    const resolved = [_]object.View{ layout_view, child_views[0], child_views[1] };
    var components: [2]Component = undefined;
    const stack = try StackTree.fromTree(tree_view, &resolved, &components);

    try std.testing.expectEqual(ui.Axis.column, stack.axis);
    try std.testing.expectEqual(@as(u16, 6), stack.gap);
    try std.testing.expectEqual(@as(u16, 10), stack.padding);
    try std.testing.expectEqual(@as(usize, 2), stack.children.len);
    try std.testing.expectEqualStrings("Tree", stack.children[0].text.value);
    try std.testing.expectEqual(@as(u32, 77), stack.children[1].button.id);
}

test "stack tree rejects resolved children that do not match tree records" {
    var left_ui: [128]u8 = undefined;
    var left_object_raw: [object.header_size + 128]u8 = undefined;
    const left_object = (Text{ .value = "Left" }).toObject(&left_ui, &left_object_raw, testEpoch()).?;

    var right_ui: [128]u8 = undefined;
    var right_object_raw: [object.header_size + 128]u8 = undefined;
    const right_object = (Button{ .id = 1, .label = "Right" }).toObject(&right_ui, &right_object_raw, testEpoch()).?;

    const tree_children = [_]object.View{try object.View.decode(left_object)};
    const tree_builder = StackTree{ .axis = .column, .children = &tree_children };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        try object.View.decode(right_object),
    };
    var components: [1]Component = undefined;
    try std.testing.expectError(error.ChildMismatch, StackTree.fromTree(try object.View.decode(tree_objects.tree), &resolved, &components));
}

test "stack tree rejects non component tree objects and descriptors" {
    var child_ui: [128]u8 = undefined;
    var child_object_raw: [object.header_size + 128]u8 = undefined;
    const child_object = (Button{ .id = 5, .label = "Child" }).toObject(&child_ui, &child_object_raw, testEpoch()).?;
    const child_view = try object.View.decode(child_object);

    var layout_body: [tree_layout_size]u8 = undefined;
    tree_codec.encodeTreeLayout(.column, 8, 0, 1, &layout_body).?;

    var bad_req = testReq();
    bad_req.visibility = .private;
    var bad_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    const bad_layout = try (object.NodeWriter{ .out = &bad_layout_raw }).bytesNode(bad_req, testEpoch(), &layout_body);
    const bad_layout_view = try object.View.decode(bad_layout);

    var children: [2]object.Child = undefined;
    children[0] = try object.Child.fromView(bad_layout_view, 0);
    children[1] = try object.Child.fromView(child_view, children[0].logical_len);

    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree = try (object.NodeWriter{ .out = &tree_raw }).treeNode(testReq(), testEpoch(), &children);
    var components: [1]Component = undefined;
    try std.testing.expectError(error.UnsupportedComponent, Tree.fromTree(try object.View.decode(tree), &.{ bad_layout_view, child_view }, &components));

    var wrong_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const wrong_tree = try (object.NodeWriter{ .out = &wrong_tree_raw }).treeNode(bad_req, testEpoch(), &children);
    try std.testing.expectError(error.Corrupt, Tree.fromTree(try object.View.decode(wrong_tree), &.{ bad_layout_view, child_view }, &components));
}

test "stack tree writer rejects non component child objects" {
    const component = Component{ .button = .{ .id = 19, .label = "Wrong child" } };
    var req = testReq();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_io.writeRecord(Component, &writer, 0, component));
    const child = writer.objectNode(&object_raw, req, testEpoch()).?;
    const child_view = try object.View.decode(child);

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    try std.testing.expect((StackTree{ .axis = .column, .children = &.{child_view} }).toTreeObjects(&layout_raw, &tree_raw, testEpoch()) == null);
}

test "slot tree composes one child component object" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 3, .label = "Slot child" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (SlotTree{ .id = 44, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        button_view,
    };
    const slot = try SlotTree.fromTree(try object.View.decode(tree_objects.tree), &resolved);
    try std.testing.expectEqual(@as(u32, 44), slot.id);
    try std.testing.expectEqual(@as(u32, 3), slot.child.button.id);
}

test "tree union detects stack and slot descriptors" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 10, .label = "Child" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var stack_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var stack_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const stack_objects = (StackTree{ .axis = .column, .children = &.{button_view} }).toTreeObjects(&stack_layout_raw, &stack_tree_raw, testEpoch()).?;
    const stack_resolved = [_]object.View{ try object.View.decode(stack_objects.layout), button_view };
    var stack_components: [1]Component = undefined;
    const stack_tree = try Tree.fromTree(try object.View.decode(stack_objects.tree), &stack_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 10), stack_tree.stack.children[0].button.id);

    var slot_layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var slot_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const slot_objects = (SlotTree{ .id = 88, .child = button_view }).toTreeObjects(&slot_layout_raw, &slot_tree_raw, testEpoch()).?;
    const slot_resolved = [_]object.View{ try object.View.decode(slot_objects.layout), button_view };
    const slot_tree = try Tree.fromTree(try object.View.decode(slot_objects.tree), &slot_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 88), slot_tree.slot.id);
    try std.testing.expectEqual(@as(u32, 10), slot_tree.slot.child.button.id);
}

test "component render helper owns button variants and collects hit targets" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const primary = Component{ .button = .{ .id = 501, .label = "Primary" } };
    const outline = Component{ .button = .{ .id = 502, .label = "Outline", .variant = .outline, .leading_icon = .search } };
    try renderComponent(&scene, ui.Rect.init(0, 0, 120, 36), primary, .{});
    try collectComponentInteractions(&collector, ui.Rect.init(0, 0, 120, 36), primary);
    try renderComponent(&scene, ui.Rect.init(0, 44, 120, 36), outline, .{});
    try collectComponentInteractions(&collector, ui.Rect.init(0, 44, 120, 36), outline);
    const primary_hit = ui_input.hitTest(collector.written(), 12, 12).?;
    try std.testing.expectEqual(@as(u32, 501), primary_hit.id);
    const outline_hit = ui_input.hitTest(collector.written(), 12, 56).?;
    try std.testing.expectEqual(@as(u32, 502), outline_hit.id);
    try std.testing.expect(component_test.hasText(scene.written(), "Primary"));
    try std.testing.expect(component_test.hasText(scene.written(), "Outline"));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.search)));
}

test "component renderer exports shared sizing tokens for measurements" {
    try std.testing.expectEqual(ui_tokens.Component.surface_radius, component_render.surface_radius);
    try std.testing.expectEqual(ui_tokens.Component.surface_padding, component_render.surface_padding);
    try std.testing.expectEqual(ui_tokens.Component.surface_detail_gap, component_render.surface_detail_gap);
    try std.testing.expectEqual(ui_tokens.Component.badge_height, component_render.badge_height);
    try std.testing.expectEqual(ui_tokens.Component.badge_padding_x, component_render.badge_padding_x);
}

test "component accessibility metadata comes from component identity and labels" {
    const button_meta = accessibility(.{ .button = .{ .id = 91, .label = "Save" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.button, button_meta.role);
    try std.testing.expectEqual(@as(u32, 91), button_meta.control_id.?);
    try std.testing.expectEqualStrings("Save", button_meta.label);

    const input_meta = accessibility(.{ .input = .{ .id = 92, .placeholder = "Email" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.input, input_meta.role);
    try std.testing.expectEqual(@as(u32, 92), input_meta.control_id.?);
    try std.testing.expectEqualStrings("Email", input_meta.label);

    const table_meta = accessibility(.{ .table = .{ .id = 93, .name = "Ada", .role = "Engineer" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.table, table_meta.role);
    try std.testing.expectEqual(@as(u32, 93), table_meta.control_id.?);
    try std.testing.expectEqualStrings("Ada", table_meta.label);
}

test "component accessibility tree emitter follows stack layout bounds" {
    const children = [_]Component{
        .{ .text = .{ .value = "Intro" } },
        .{ .button = .{ .id = 94, .label = "Continue" } },
        .{ .input = .{ .id = 95, .placeholder = "Filter" } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
    var raw_nodes: [4]AccessibilityNode = undefined;
    var tree = AccessibilityTree.init(&raw_nodes);

    try stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 160, 120), .{});

    try std.testing.expectEqual(@as(usize, 3), tree.written().len);
    try std.testing.expectEqual(component_common.AccessibilityRole.text, tree.written()[0].metadata.role);
    try std.testing.expectEqualStrings("Intro", tree.written()[0].metadata.label);
    try std.testing.expectEqual(component_common.AccessibilityRole.button, tree.written()[1].metadata.role);
    try std.testing.expectEqual(@as(u32, 94), tree.written()[1].metadata.control_id.?);
    try std.testing.expect(tree.written()[1].bounds.y > tree.written()[0].bounds.y);
    try std.testing.expectEqual(component_common.AccessibilityRole.input, tree.written()[2].metadata.role);
    try std.testing.expectEqual(@as(u32, 95), tree.written()[2].metadata.control_id.?);
}

test "component accessibility tree emitter enforces caller budget" {
    const children = [_]Component{
        .{ .button = .{ .id = 96, .label = "One" } },
        .{ .button = .{ .id = 97, .label = "Two" } },
    };
    const stack = Stack{ .axis = .column, .children = &children };
    var raw_nodes: [1]AccessibilityNode = undefined;
    var tree = AccessibilityTree.init(&raw_nodes);

    try std.testing.expectError(error.AccessibilityBudgetExceeded, stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 120, 80), .{}));
}

test "component render helper applies shared interactive states by component id" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const button = Component{ .button = .{ .id = 701, .label = "Save" } };
    try renderComponent(&scene, ui.Rect.init(10, 12, 120, 36), button, .{
        .interaction = .{
            .hovered_id = 701,
            .active_id = 701,
            .focused_id = 701,
            .disabled_id = 701,
            .loading_id = 701,
            .invalid_id = 701,
        },
    });

    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_hover_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_active_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_focus_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_invalid_border));
    try std.testing.expect(component_test.hasFillColor(scene.written(), component_common.state_disabled_tint));
    try std.testing.expect(component_test.hasFillColor(scene.written(), component_common.state_loading_fill));
}

test "component render helper does not leak interactive state to other ids" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const button = Component{ .button = .{ .id = 702, .label = "Save" } };
    try renderComponent(&scene, ui.Rect.init(10, 12, 120, 36), button, .{
        .interaction = .{ .focused_id = 701 },
    });

    try std.testing.expect(!component_test.hasRectColor(scene.written(), component_common.state_focus_border));
}

test "component interaction collection covers primitive controls" {
    const primitives = [_]Component{
        .{ .input = .{ .id = 601, .placeholder = "Filter" } },
        .{ .textarea = .{ .id = 602, .placeholder = "Explain" } },
        .{ .select = .{ .id = 603, .label = "Mode" } },
        .{ .checkbox = .{ .id = 604, .label = "Receipts", .checked = true } },
        .{ .switch_control = .{ .id = 605, .label = "Public", .checked = false } },
        .{ .slider = .{ .id = 606, .label = "Brightness", .value = 0.5 } },
        .{ .row_item = .{ .id = 607, .title = "DNS", .detail = "Lookup" } },
    };
    const expected = [_]ui.HitKind{ .input, .textarea, .select, .checkbox, .switch_control, .slider, .row_item };
    var regions: [primitives.len]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    for (primitives, 0..) |component, index| {
        const y = @as(f32, @floatFromInt(index)) * 48.0;
        try collectComponentInteractions(&collector, ui.Rect.init(0, y, 240, 40), component);
    }

    try std.testing.expectEqual(primitives.len, collector.written().len);
    for (collector.written(), 0..) |region, index| {
        try std.testing.expectEqual(@as(u32, 601 + @as(u32, @intCast(index))), region.id);
        try std.testing.expectEqual(expected[index], region.kind);
    }
}

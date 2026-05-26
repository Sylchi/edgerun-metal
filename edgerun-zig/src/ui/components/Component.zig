const clock = @import("../../clock.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const common = @import("../../ui_component_common.zig");
const component_codec = @import("Codec.zig");
const component_io = @import("ComponentIO.zig");
const primitives = @import("Primitives.zig");
const text_component = @import("Text.zig");
const accordion_component = @import("Accordion.zig");
const alert_component = @import("Alert.zig");
const alert_dialog_component = @import("AlertDialog.zig");
const aspect_ratio_component = @import("AspectRatio.zig");
const calendar_component = @import("Calendar.zig");
const carousel_component = @import("Carousel.zig");
const chart_component = @import("Chart.zig");
const combobox_component = @import("Combobox.zig");
const card_component = @import("Card.zig");
const empty_component = @import("Empty.zig");
const button_component = @import("Button.zig");
const button_group_component = @import("ButtonGroup.zig");
const toggle_group_component = @import("ToggleGroup.zig");
const badge_component = @import("Badge.zig");
const avatar_component = @import("Avatar.zig");
const kbd_component = @import("Kbd.zig");
const label_component = @import("Label.zig");
const separator_component = @import("Separator.zig");
const scroll_area_component = @import("ScrollArea.zig");
const skeleton_component = @import("Skeleton.zig");
const spinner_component = @import("Spinner.zig");
const breadcrumb_component = @import("Breadcrumb.zig");
const menubar_component = @import("Menubar.zig");
const navigation_menu_component = @import("NavigationMenu.zig");
const command_component = @import("Command.zig");
const context_menu_component = @import("ContextMenu.zig");
const dialog_component = @import("Dialog.zig");
const direction_component = @import("Direction.zig");
const drawer_component = @import("Drawer.zig");
const dropdown_menu_component = @import("DropdownMenu.zig");
const field_component = @import("Field.zig");
const hover_card_component = @import("HoverCard.zig");
const input_otp_component = @import("InputOtp.zig");
const input_component = @import("Input.zig");
const input_group_component = @import("InputGroup.zig");
const textarea_component = @import("Textarea.zig");
const select_component = @import("Select.zig");
const checkbox_component = @import("Checkbox.zig");
const radio_group_component = @import("RadioGroup.zig");
const switch_component = @import("Switch.zig");
const pagination_component = @import("Pagination.zig");
const popover_component = @import("Popover.zig");
const resizable_component = @import("Resizable.zig");
const sheet_component = @import("Sheet.zig");
const sidebar_component = @import("Sidebar.zig");
const toggle_component = @import("Toggle.zig");
const progress_component = @import("Progress.zig");
const slider_component = @import("Slider.zig");
const tabs_component = @import("Tabs.zig");
const table_component = @import("Table.zig");
const tooltip_component = @import("Tooltip.zig");
const toast_component = @import("Toast.zig");
const row_item_component = @import("RowItem.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const Accessibility = common.Accessibility;
const AccessibilityTree = common.AccessibilityTree;

const Text = text_component.Text;
const Accordion = accordion_component.Accordion;
const Alert = alert_component.Alert;
const AlertDialog = alert_dialog_component.AlertDialog;
const AspectRatio = aspect_ratio_component.AspectRatio;
const Calendar = calendar_component.Calendar;
const Carousel = carousel_component.Carousel;
const Chart = chart_component.Chart;
const Combobox = combobox_component.Combobox;
const Card = card_component.Card;
const Empty = empty_component.Empty;
const Button = button_component.Button;
const IconButton = button_component.IconButton;
const ButtonGroup = button_group_component.ButtonGroup;
const ToggleGroup = toggle_group_component.ToggleGroup;
const Badge = badge_component.Badge;
const Avatar = avatar_component.Avatar;
const Kbd = kbd_component.Kbd;
const Label = label_component.Label;
const Separator = separator_component.Separator;
const ScrollArea = scroll_area_component.ScrollArea;
const Skeleton = skeleton_component.Skeleton;
const Spinner = spinner_component.Spinner;
const Breadcrumb = breadcrumb_component.Breadcrumb;
const Menubar = menubar_component.Menubar;
const NavigationMenu = navigation_menu_component.NavigationMenu;
const Command = command_component.Command;
const ContextMenu = context_menu_component.ContextMenu;
const Dialog = dialog_component.Dialog;
const Direction = direction_component.Direction;
const Drawer = drawer_component.Drawer;
const DropdownMenu = dropdown_menu_component.DropdownMenu;
const Field = field_component.Field;
const HoverCard = hover_card_component.HoverCard;
const InputOtp = input_otp_component.InputOtp;
const Input = input_component.Input;
const InputGroup = input_group_component.InputGroup;
const Textarea = textarea_component.Textarea;
const Select = select_component.Select;
const Checkbox = checkbox_component.Checkbox;
const RadioGroup = radio_group_component.RadioGroup;
const Switch = switch_component.Switch;
const Pagination = pagination_component.Pagination;
const Popover = popover_component.Popover;
const Resizable = resizable_component.Resizable;
const Sheet = sheet_component.Sheet;
const Sidebar = sidebar_component.Sidebar;
const Toggle = toggle_component.Toggle;
const Progress = progress_component.Progress;
const Slider = slider_component.Slider;
const Tabs = tabs_component.Tabs;
const Table = table_component.Table;
const Tooltip = tooltip_component.Tooltip;
const Toast = toast_component.Toast;
const RowItem = row_item_component.RowItem;

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
            inline else => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const resolved_options = options.withControlId(self.controlId());
        switch (self) {
            inline else => |component| try component.render(scene, bounds, resolved_options),
        }
        try primitives.renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        switch (self) {
            inline else => |component| {
                if (comptime @hasDecl(@TypeOf(component), "collectInteractions")) {
                    try component.collectInteractions(collector, bounds);
                }
            },
        }
    }

    pub fn measure(self: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
        return switch (self) {
            inline else => |component| component.measure(constraints, options),
        };
    }

    pub fn accessibility(self: Component) Accessibility {
        return switch (self) {
            .text => |component| .{ .role = .text, .label = component.value },
            .button => |component| .{ .role = .button, .label = component.label, .control_id = component.id },
            .icon_button => |component| .{ .role = .button, .label = component.label, .control_id = component.id },
            .input => |component| .{ .role = .input, .label = component.placeholder, .control_id = component.id },
            .field => |component| .{ .role = .input, .label = component.label, .control_id = component.id },
            .textarea => |component| .{ .role = .input, .label = component.placeholder, .control_id = component.id },
            .select => |component| .{ .role = .input, .label = component.label, .control_id = component.id },
            .checkbox => |component| .{ .role = .checkbox, .label = component.label, .control_id = component.id },
            .switch_control => |component| .{ .role = .switch_control, .label = component.label, .control_id = component.id },
            .slider => |component| .{ .role = .slider, .label = component.label, .control_id = component.id },
            .tabs => |component| .{ .role = .tab, .label = component.first, .control_id = component.id },
            .table => |component| .{ .role = .table, .label = component.name, .control_id = component.id },
            .dialog => |component| .{ .role = .dialog, .label = component.title, .control_id = component.id },
            .alert_dialog => |component| .{ .role = .dialog, .label = component.title, .control_id = component.id },
            .dropdown_menu => |component| .{ .role = .menu, .label = component.first, .control_id = component.id },
            .context_menu => |component| .{ .role = .menu, .label = component.first, .control_id = component.id },
            .menubar => |component| .{ .role = .menu, .label = component.first, .control_id = component.id },
            .navigation_menu => |component| .{ .role = .menu, .label = component.first, .control_id = component.id },
            .avatar => |component| .{ .role = .image, .label = component.label },
            .toast => |component| .{ .role = .status, .label = component.title, .control_id = component.id },
            .row_item => |component| .{ .role = .button, .label = component.title, .control_id = component.id },
            else => .{ .role = .generic },
        };
    }

    pub fn collectAccessibility(self: Component, tree: *AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
        _ = options;
        const metadata = self.accessibility();
        if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
        try tree.append(.{ .metadata = metadata, .bounds = bounds });
    }

    fn controlId(self: Component) ?u32 {
        return switch (self) {
            inline else => |component| if (comptime @hasField(@TypeOf(component), "id")) component.id else null,
        };
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
            inline else => |payload, tag| {
                if (comptime @hasField(Component, @tagName(tag))) {
                    return @unionInit(Component, @tagName(tag), try componentFromNode(@FieldType(Component, @tagName(tag)), payload));
                }
                return error.UnsupportedComponent;
            },
        };
    }
};

fn componentFromNode(comptime ComponentPayload: type, node_payload: anytype) Error!ComponentPayload {
    if (comptime @hasDecl(ComponentPayload, "fromNode")) {
        return ComponentPayload.fromNode(node_payload);
    }
    return copyMatchingFields(ComponentPayload, node_payload);
}

fn copyMatchingFields(comptime ComponentPayload: type, node_payload: anytype) ComponentPayload {
    var component: ComponentPayload = undefined;
    inline for (@typeInfo(ComponentPayload).@"struct".fields) |field| {
        @field(component, field.name) = @field(node_payload, field.name);
    }
    return component;
}

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
        const resolved_options = options.withControlId(self.controlId());
        switch (self) {
            .text => |component| try component.render(scene, bounds, resolved_options),
            .accordion => |component| try component.render(scene, bounds, resolved_options),
            .alert => |component| try component.render(scene, bounds, resolved_options),
            .alert_dialog => |component| try component.render(scene, bounds, resolved_options),
            .aspect_ratio => |component| try component.render(scene, bounds, resolved_options),
            .calendar => |component| try component.render(scene, bounds, resolved_options),
            .carousel => |component| try component.render(scene, bounds, resolved_options),
            .chart => |component| try component.render(scene, bounds, resolved_options),
            .combobox => |component| try component.render(scene, bounds, resolved_options),
            .card => |component| try component.render(scene, bounds, resolved_options),
            .empty => |component| try component.render(scene, bounds, resolved_options),
            .badge => |component| try component.render(scene, bounds, resolved_options),
            .avatar => |component| try component.render(scene, bounds, resolved_options),
            .kbd => |component| try component.render(scene, bounds, resolved_options),
            .label => |component| try component.render(scene, bounds, resolved_options),
            .separator => |component| try component.render(scene, bounds, resolved_options),
            .scroll_area => |component| try component.render(scene, bounds, resolved_options),
            .skeleton => |component| try component.render(scene, bounds, resolved_options),
            .spinner => |component| try component.render(scene, bounds, resolved_options),
            .breadcrumb => |component| try component.render(scene, bounds, resolved_options),
            .menubar => |component| try component.render(scene, bounds, resolved_options),
            .navigation_menu => |component| try component.render(scene, bounds, resolved_options),
            .command => |component| try component.render(scene, bounds, resolved_options),
            .context_menu => |component| try component.render(scene, bounds, resolved_options),
            .dialog => |component| try component.render(scene, bounds, resolved_options),
            .direction => |component| try component.render(scene, bounds, resolved_options),
            .drawer => |component| try component.render(scene, bounds, resolved_options),
            .dropdown_menu => |component| try component.render(scene, bounds, resolved_options),
            .field => |component| try component.render(scene, bounds, resolved_options),
            .hover_card => |component| try component.render(scene, bounds, resolved_options),
            .input_otp => |component| try component.render(scene, bounds, resolved_options),
            .button => |component| try component.render(scene, bounds, resolved_options),
            .icon_button => |component| try component.render(scene, bounds, resolved_options),
            .button_group => |component| try component.render(scene, bounds, resolved_options),
            .toggle_group => |component| try component.render(scene, bounds, resolved_options),
            .toggle => |component| try component.render(scene, bounds, resolved_options),
            .input => |component| try component.render(scene, bounds, resolved_options),
            .input_group => |component| try component.render(scene, bounds, resolved_options),
            .textarea => |component| try component.render(scene, bounds, resolved_options),
            .select => |component| try component.render(scene, bounds, resolved_options),
            .checkbox => |component| try component.render(scene, bounds, resolved_options),
            .radio_group => |component| try component.render(scene, bounds, resolved_options),
            .switch_control => |component| try component.render(scene, bounds, resolved_options),
            .pagination => |component| try component.render(scene, bounds, resolved_options),
            .popover => |component| try component.render(scene, bounds, resolved_options),
            .resizable => |component| try component.render(scene, bounds, resolved_options),
            .sheet => |component| try component.render(scene, bounds, resolved_options),
            .sidebar => |component| try component.render(scene, bounds, resolved_options),
            .progress => |component| try component.render(scene, bounds, resolved_options),
            .slider => |component| try component.render(scene, bounds, resolved_options),
            .tabs => |component| try component.render(scene, bounds, resolved_options),
            .table => |component| try component.render(scene, bounds, resolved_options),
            .tooltip => |component| try component.render(scene, bounds, resolved_options),
            .toast => |component| try component.render(scene, bounds, resolved_options),
            .row_item => |component| try component.render(scene, bounds, resolved_options),
        }
        try primitives.renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        switch (self) {
            .accordion => |component| try component.collectInteractions(collector, bounds),
            .alert_dialog => |component| try component.collectInteractions(collector, bounds),
            .calendar => |component| try component.collectInteractions(collector, bounds),
            .carousel => |component| try component.collectInteractions(collector, bounds),
            .chart => |component| try component.collectInteractions(collector, bounds),
            .combobox => |component| try component.collectInteractions(collector, bounds),
            .breadcrumb => |component| try component.collectInteractions(collector, bounds),
            .menubar => |component| try component.collectInteractions(collector, bounds),
            .navigation_menu => |component| try component.collectInteractions(collector, bounds),
            .command => |component| try component.collectInteractions(collector, bounds),
            .context_menu => |component| try component.collectInteractions(collector, bounds),
            .dialog => |component| try component.collectInteractions(collector, bounds),
            .direction => |component| try component.collectInteractions(collector, bounds),
            .drawer => |component| try component.collectInteractions(collector, bounds),
            .dropdown_menu => |component| try component.collectInteractions(collector, bounds),
            .field => |component| try component.collectInteractions(collector, bounds),
            .hover_card => |component| try component.collectInteractions(collector, bounds),
            .input_otp => |component| try component.collectInteractions(collector, bounds),
            .button => |component| try component.collectInteractions(collector, bounds),
            .icon_button => |component| try component.collectInteractions(collector, bounds),
            .button_group => |component| try component.collectInteractions(collector, bounds),
            .toggle_group => |component| try component.collectInteractions(collector, bounds),
            .input => |component| try component.collectInteractions(collector, bounds),
            .input_group => |component| try component.collectInteractions(collector, bounds),
            .textarea => |component| try component.collectInteractions(collector, bounds),
            .select => |component| try component.collectInteractions(collector, bounds),
            .checkbox => |component| try component.collectInteractions(collector, bounds),
            .radio_group => |component| try component.collectInteractions(collector, bounds),
            .switch_control => |component| try component.collectInteractions(collector, bounds),
            .pagination => |component| try component.collectInteractions(collector, bounds),
            .popover => |component| try component.collectInteractions(collector, bounds),
            .resizable => |component| try component.collectInteractions(collector, bounds),
            .sheet => |component| try component.collectInteractions(collector, bounds),
            .sidebar => |component| try component.collectInteractions(collector, bounds),
            .toggle => |component| try component.collectInteractions(collector, bounds),
            .slider => |component| try component.collectInteractions(collector, bounds),
            .tabs => |component| try component.collectInteractions(collector, bounds),
            .table => |component| try component.collectInteractions(collector, bounds),
            .tooltip => |component| try component.collectInteractions(collector, bounds),
            .toast => |component| try component.collectInteractions(collector, bounds),
            .row_item => |component| try component.collectInteractions(collector, bounds),
            else => {},
        }
    }

    pub fn measure(self: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
        return switch (self) {
            .text => |component| component.measure(constraints, options),
            .accordion => |component| component.measure(constraints, options),
            .alert => |component| component.measure(constraints, options),
            .alert_dialog => |component| component.measure(constraints, options),
            .aspect_ratio => |component| component.measure(constraints, options),
            .calendar => |component| component.measure(constraints, options),
            .carousel => |component| component.measure(constraints, options),
            .chart => |component| component.measure(constraints, options),
            .combobox => |component| component.measure(constraints, options),
            .card => |component| component.measure(constraints, options),
            .empty => |component| component.measure(constraints, options),
            .badge => |component| component.measure(constraints, options),
            .avatar => |component| component.measure(constraints, options),
            .kbd => |component| component.measure(constraints, options),
            .label => |component| component.measure(constraints, options),
            .separator => |component| component.measure(constraints, options),
            .scroll_area => |component| component.measure(constraints, options),
            .skeleton => |component| component.measure(constraints, options),
            .spinner => |component| component.measure(constraints, options),
            .breadcrumb => |component| component.measure(constraints, options),
            .menubar => |component| component.measure(constraints, options),
            .navigation_menu => |component| component.measure(constraints, options),
            .command => |component| component.measure(constraints, options),
            .context_menu => |component| component.measure(constraints, options),
            .dialog => |component| component.measure(constraints, options),
            .direction => |component| component.measure(constraints, options),
            .drawer => |component| component.measure(constraints, options),
            .dropdown_menu => |component| component.measure(constraints, options),
            .field => |component| component.measure(constraints, options),
            .hover_card => |component| component.measure(constraints, options),
            .input_otp => |component| component.measure(constraints, options),
            .button => |component| component.measure(constraints, options),
            .icon_button => |component| component.measure(constraints, options),
            .button_group => |component| component.measure(constraints, options),
            .toggle_group => |component| component.measure(constraints, options),
            .toggle => |component| component.measure(constraints, options),
            .input => |component| component.measure(constraints, options),
            .input_group => |component| component.measure(constraints, options),
            .textarea => |component| component.measure(constraints, options),
            .select => |component| component.measure(constraints, options),
            .checkbox => |component| component.measure(constraints, options),
            .radio_group => |component| component.measure(constraints, options),
            .switch_control => |component| component.measure(constraints, options),
            .pagination => |component| component.measure(constraints, options),
            .popover => |component| component.measure(constraints, options),
            .resizable => |component| component.measure(constraints, options),
            .sheet => |component| component.measure(constraints, options),
            .sidebar => |component| component.measure(constraints, options),
            .progress => |component| component.measure(constraints, options),
            .slider => |component| component.measure(constraints, options),
            .tabs => |component| component.measure(constraints, options),
            .table => |component| component.measure(constraints, options),
            .tooltip => |component| component.measure(constraints, options),
            .toast => |component| component.measure(constraints, options),
            .row_item => |component| component.measure(constraints, options),
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
            .text, .alert, .aspect_ratio, .card, .empty, .badge, .avatar, .kbd, .label, .separator, .scroll_area, .skeleton, .spinner, .progress => null,
            .accordion => |component| component.id,
            .alert_dialog => |component| component.id,
            .calendar => |component| component.id,
            .carousel => |component| component.id,
            .chart => |component| component.id,
            .combobox => |component| component.id,
            .breadcrumb => |component| component.id,
            .menubar => |component| component.id,
            .navigation_menu => |component| component.id,
            .command => |component| component.id,
            .context_menu => |component| component.id,
            .dialog => |component| component.id,
            .direction => |component| component.id,
            .drawer => |component| component.id,
            .dropdown_menu => |component| component.id,
            .field => |component| component.id,
            .hover_card => |component| component.id,
            .input_otp => |component| component.id,
            .button => |component| component.id,
            .icon_button => |component| component.id,
            .button_group => |component| component.id,
            .toggle_group => |component| component.id,
            .toggle => |component| component.id,
            .input => |component| component.id,
            .input_group => |component| component.id,
            .textarea => |component| component.id,
            .select => |component| component.id,
            .checkbox => |component| component.id,
            .radio_group => |component| component.id,
            .switch_control => |component| component.id,
            .pagination => |component| component.id,
            .popover => |component| component.id,
            .resizable => |component| component.id,
            .sheet => |component| component.id,
            .sidebar => |component| component.id,
            .slider => |component| component.id,
            .tabs => |component| component.id,
            .table => |component| component.id,
            .tooltip => |component| component.id,
            .toast => |component| component.id,
            .row_item => |component| component.id,
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
            .button => |button| .{ .button = .{ .id = button.id, .label = button.label, .variant = button_component.variantFromTag(button.variant) catch return error.Corrupt, .leading_icon = common.optionalIconFromTag(button.leading_icon) catch return error.Corrupt, .trailing_icon = common.optionalIconFromTag(button.trailing_icon) catch return error.Corrupt } },
            .icon_button => |button| .{ .icon_button = .{ .id = button.id, .label = button.label, .variant = button_component.variantFromTag(button.variant) catch return error.Corrupt, .icon_value = (common.optionalIconFromTag(button.icon) catch return error.Corrupt) orelse return error.Corrupt } },
            .button_group => |group| .{ .button_group = .{ .id = group.id, .first = group.first, .second = group.second, .active = group.active } },
            .toggle_group => |group| .{ .toggle_group = .{ .id = group.id, .first = group.first, .second = group.second, .active = group.active } },
            .toggle => |toggle| .{ .toggle = .{ .id = toggle.id, .label = toggle.label, .pressed = toggle.pressed } },
            .input => |input| .{ .input = .{ .id = input.id, .placeholder = input.placeholder, .leading_icon = common.optionalIconFromTag(input.leading_icon) catch return error.Corrupt } },
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

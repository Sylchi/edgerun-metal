const clock = @import("../../clock.zig");
const ui_input = @import("../../input.zig");
const interaction = @import("../interaction.zig");
const layout_types = @import("../layouts/Types.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const common = @import("../component_common.zig");
const component_codec = @import("Codec.zig");
const component_test = @import("TestSupport.zig");
const icon_pack = @import("../icon_pack.zig");
const primitives = @import("Primitives.zig");
const std = @import("std");
const ui_icon = @import("../icon.zig");
const ui_tokens = @import("../theme.zig");

const accordion_component = @import("Accordion.zig");
const alert_component = @import("Alert.zig");
const alert_dialog_component = @import("AlertDialog.zig");
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
const display_component = @import("Display.zig");
const empty_component = @import("Empty.zig");
const field_component = @import("Field.zig");
const hover_card_component = @import("HoverCard.zig");
const icon_component = @import("Icon.zig");
const input_component = @import("Input.zig");
const input_group_component = @import("InputGroup.zig");
const input_otp_component = @import("InputOtp.zig");
const menubar_component = @import("Menubar.zig");
const navigation_menu_component = @import("NavigationMenu.zig");
const pagination_component = @import("Pagination.zig");
const popover_component = @import("Popover.zig");
const radio_group_component = @import("RadioGroup.zig");
const resizable_component = @import("Resizable.zig");
const row_item_component = @import("RowItem.zig");
const scroll_area_component = @import("ScrollArea.zig");
const select_component = @import("Select.zig");
const sheet_component = @import("Sheet.zig");
const sidebar_component = @import("Sidebar.zig");
const slider_component = @import("Slider.zig");
const switch_component = @import("Switch.zig");
const table_component = @import("Table.zig");
const tabs_component = @import("Tabs.zig");
const textarea_component = @import("Textarea.zig");
const text_component = @import("Text.zig");
const toast_component = @import("Toast.zig");
const toggle_component = @import("Toggle.zig");
const toggle_group_component = @import("ToggleGroup.zig");
const tooltip_component = @import("Tooltip.zig");

pub const Error = common.Error;
pub const RenderOptions = common.RenderOptions;
pub const Accessibility = common.Accessibility;
pub const AccessibilityTree = common.AccessibilityTree;
pub const ButtonVariant = common.ButtonVariant;
pub const BadgeVariant = common.BadgeVariant;
pub const SurfaceVariant = common.SurfaceVariant;
pub const Icon = icon_component.Icon;
pub const IconSlot = icon_component.IconSlot;

pub const Component = union(enum) {
    text: text_component.Text,
    accordion: accordion_component.Accordion,
    alert: alert_component.Alert,
    alert_dialog: alert_dialog_component.AlertDialog,
    aspect_ratio: display_component.AspectRatio,
    calendar: calendar_component.Calendar,
    carousel: carousel_component.Carousel,
    chart: chart_component.Chart,
    combobox: combobox_component.Combobox,
    card: card_component.Card,
    empty: empty_component.Empty,
    badge: badge_component.Badge,
    avatar: display_component.Avatar,
    kbd: display_component.Kbd,
    label: display_component.Label,
    separator: display_component.Separator,
    scroll_area: scroll_area_component.ScrollArea,
    skeleton: display_component.Skeleton,
    spinner: display_component.Spinner,
    breadcrumb: breadcrumb_component.Breadcrumb,
    menubar: menubar_component.Menubar,
    navigation_menu: navigation_menu_component.NavigationMenu,
    command: command_component.Command,
    context_menu: context_menu_component.ContextMenu,
    dialog: dialog_component.Dialog,
    direction: direction_component.Direction,
    drawer: drawer_component.Drawer,
    dropdown_menu: dropdown_menu_component.DropdownMenu,
    field: field_component.Field,
    hover_card: hover_card_component.HoverCard,
    input_otp: input_otp_component.InputOtp,
    icon: icon_component.Icon,
    button: button_component.Button,
    icon_button: button_component.IconButton,
    button_group: button_group_component.ButtonGroup,
    toggle_group: toggle_group_component.ToggleGroup,
    toggle: toggle_component.Toggle,
    input: input_component.Input,
    input_group: input_group_component.InputGroup,
    textarea: textarea_component.Textarea,
    select: select_component.Select,
    checkbox: checkbox_component.Checkbox,
    radio_group: radio_group_component.RadioGroup,
    switch_control: switch_component.Switch,
    pagination: pagination_component.Pagination,
    popover: popover_component.Popover,
    resizable: resizable_component.Resizable,
    sheet: sheet_component.Sheet,
    sidebar: sidebar_component.Sidebar,
    progress: display_component.Progress,
    slider: slider_component.Slider,
    tabs: tabs_component.Tabs,
    table: table_component.Table,
    tooltip: tooltip_component.Tooltip,
    toast: toast_component.Toast,
    row_item: row_item_component.RowItem,

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            inline else => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const resolved_options = self.componentFlags().apply(options.withControlId(self.controlId()));
        switch (self) {
            inline else => |component| try component.render(scene, bounds, resolved_options),
        }
        try primitives.renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
        const resolved_options = self.componentFlags().apply(options.withControlId(self.controlId()));
        if (resolved_options.control.disabled) return;
        switch (self) {
            inline else => |component| {
                if (comptime @hasDecl(@TypeOf(component), "collectInteractions")) {
                    const T = @TypeOf(component);
                    const fn_info = @typeInfo(@TypeOf(T.collectInteractions)).@"fn";
                    if (fn_info.params.len >= 4) {
                        try component.collectInteractions(collector, bounds, resolved_options);
                    } else {
                        try component.collectInteractions(collector, bounds);
                    }
                }
            },
        }
    }

    pub fn renderInteractive(self: Component, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
        try self.render(scene, bounds, options);
        try self.collectInteractions(collector, bounds, options);
    }

    pub fn measure(self: Component, constraints: layout_types.Constraints, options: RenderOptions) layout_types.Measurement {
        return switch (self) {
            inline else => |component| component.measure(constraints, options),
        };
    }

    pub fn accessibility(self: Component) Accessibility {
        return switch (self) {
            inline else => |component| if (comptime @hasDecl(@TypeOf(component), "accessibility")) component.accessibility() else .{ .role = .generic },
        };
    }

    pub fn collectAccessibility(self: Component, tree: *AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
        _ = options;
        const metadata = self.accessibility();
        if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
        try tree.append(.{ .metadata = metadata, .bounds = bounds });
    }

    pub fn withFlags(self: Component, flags: common.ComponentFlags) Component {
        var next = self;
        switch (next) {
            inline else => |*component| {
                if (comptime @hasField(@TypeOf(component.*), "flags")) {
                    component.flags = component.flags.merge(flags);
                }
            },
        }
        return next;
    }

    pub fn disabled(self: Component) Component {
        return self.withFlags(.{ .disabled = true });
    }

    pub fn loading(self: Component) Component {
        return self.withFlags(.{ .loading = true });
    }

    pub fn invalid(self: Component) Component {
        return self.withFlags(.{ .invalid = true });
    }

    fn controlId(self: Component) ?u32 {
        return self.accessibility().control_id;
    }

    fn componentFlags(self: Component) common.ComponentFlags {
        return switch (self) {
            inline else => |component| if (comptime @hasField(@TypeOf(component), "flags")) component.flags else .{},
        };
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.writeObject(Component, self, ui_out, object_out, epoch);
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

pub const registrations = @typeInfo(Component).@"union".fields;

pub fn text(value: []const u8) Component {
    return .{ .text = .{ .value = value } };
}

pub fn card(title: []const u8, detail: []const u8, variant: SurfaceVariant) Component {
    return .{ .card = .{ .title = title, .detail = detail, .variant = variant } };
}

pub fn selectableCard(id: u32, title: []const u8, detail: []const u8, variant: SurfaceVariant) Component {
    return .{ .card = .{ .id = id, .title = title, .detail = detail, .variant = variant } };
}

pub fn panel(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .panel);
}

pub fn selectablePanel(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .panel);
}

pub fn elevated(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .elevated);
}

pub fn selectableElevated(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .elevated);
}

pub fn subtle(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .subtle);
}

pub fn selectableSubtle(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .subtle);
}

pub fn progress(value: f32) Component {
    return .{ .progress = .{ .value = value } };
}

pub fn badge(label: []const u8, variant: BadgeVariant) Component {
    return .{ .badge = .{ .label = label, .variant = variant } };
}

pub fn empty(title: []const u8, detail: []const u8) Component {
    return .{ .empty = .{ .title = title, .detail = detail } };
}

pub fn icon(icon_value: ui_icon.Icon) Component {
    return .{ .icon = Icon.named(icon_value) };
}

pub fn input(id: u32, placeholder: []const u8) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder } };
}

pub fn inputValue(id: u32, placeholder: []const u8, value: []const u8) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder, .value = value } };
}

pub fn inputIcon(id: u32, placeholder: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder, .icon_slot = IconSlot.named(.leading, icon_value) } };
}

pub fn rowItem(id: u32, title: []const u8, detail: []const u8) Component {
    return .{ .row_item = .{ .id = id, .title = title, .detail = detail } };
}

pub fn rowItemIcon(id: u32, title: []const u8, detail: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .row_item = .{ .id = id, .title = title, .detail = detail, .leading_icon = IconSlot.named(.leading, icon_value) } };
}

pub fn button(id: u32, label: []const u8, variant: ButtonVariant, icon_slot: IconSlot) Component {
    return .{ .button = .{ .id = id, .label = label, .variant = variant, .icon_slot = icon_slot } };
}

pub fn buttonText(id: u32, label: []const u8, variant: ButtonVariant) Component {
    return button(id, label, variant, .none);
}

pub fn buttonIcon(id: u32, label: []const u8, variant: ButtonVariant, icon_value: ui_icon.Icon) Component {
    return button(id, label, variant, IconSlot.named(.leading, icon_value));
}

pub fn iconButton(id: u32, label: []const u8, icon_value: Icon, variant: ButtonVariant) Component {
    return .{ .icon_button = .{ .id = id, .label = label, .icon = icon_value, .variant = variant } };
}

pub fn iconButtonNamed(id: u32, label: []const u8, icon_value: ui_icon.Icon, variant: ButtonVariant) Component {
    return iconButton(id, label, Icon.named(icon_value), variant);
}

pub fn textarea(id: u32, placeholder: []const u8) Component {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder } };
}

pub fn textareaValue(id: u32, placeholder: []const u8, value: []const u8) Component {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder, .value = value } };
}

pub fn slider(id: u32, label: []const u8, value: f32) Component {
    return .{ .slider = .{ .id = id, .label = label, .value = value } };
}

pub fn select(id: u32, label: []const u8) Component {
    return .{ .select = .{ .id = id, .label = label } };
}

pub fn selectIcon(id: u32, label: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .select = .{ .id = id, .label = label, .icon_slot = IconSlot.named(.trailing, icon_value) } };
}

pub fn switchControl(id: u32, label: []const u8, checked: bool) Component {
    return .{ .switch_control = .{ .id = id, .label = label, .checked = checked } };
}

pub fn checkbox(id: u32, label: []const u8, checked: bool) Component {
    return .{ .checkbox = .{ .id = id, .label = label, .checked = checked } };
}

pub fn toggle(id: u32, label: []const u8, pressed: bool) Component {
    return .{ .toggle = .{ .id = id, .label = label, .pressed = pressed } };
}

pub fn tabs(id: u32, first: []const u8, second: []const u8, active: u16) Component {
    return .{ .tabs = .{ .id = id, .first = first, .second = second, .active = active } };
}

pub fn chart(id: u32, label: []const u8) Component {
    return .{ .chart = .{ .id = id, .label = label } };
}

pub fn alert(title: []const u8, detail: []const u8) Component {
    return .{ .alert = .{ .title = title, .detail = detail } };
}

pub fn destructiveAlert(title: []const u8, detail: []const u8) Component {
    return .{ .alert = .{ .title = title, .detail = detail, .destructive = true } };
}

pub fn command(id: u32, placeholder: []const u8) Component {
    return .{ .command = .{ .id = id, .placeholder = placeholder } };
}

pub fn toast(id: u32, title: []const u8, detail: []const u8) Component {
    return .{ .toast = .{ .id = id, .title = title, .detail = detail } };
}

pub fn tooltip(id: u32, trigger: []const u8, content: []const u8) Component {
    return .{ .tooltip = .{ .id = id, .trigger = trigger, .content = content } };
}

pub fn separator() Component {
    return .{ .separator = .{} };
}

pub fn render(component: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try component.render(scene, bounds, options);
}

pub fn renderInteractive(component: Component, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
    try component.renderInteractive(scene, collector, bounds, options);
}

pub fn renderLine(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try render(separator(), scene, bounds, options);
}

pub fn renderer(scene: *ui.Scene, collector: ?*interaction.Collector, options: RenderOptions) View {
    return .{ .scene = scene, .collector = collector, .options = options };
}

pub const SectionProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
};

pub const MetricCardProps = struct {
    id: ?u32 = null,
    title: []const u8,
    detail: []const u8 = "",
    value: []const u8,
    icon: ?ui_icon.Icon = null,
    progress: ?f32 = null,
    selected: bool = false,
};

pub const Segment = struct {
    id: u32,
    weight: f32,
    height: f32 = 1.0,
    color: ui.Color,
    selected: bool = false,
};

pub const SegmentMapProps = struct {
    segments: []const Segment,
    background: ui.Color,
    border: ui.Color,
    selected_border: ui.Color,
    gap: f32 = 5.0,
    radius: f32 = 8.0,
};

pub const TimelineBlock = struct {
    id: u32,
    start: f32,
    end: f32,
    value: f32,
    color: ui.Color,
    selected: bool = false,
};

pub const TimelineLaneProps = struct {
    label: []const u8,
    lane_index: usize,
    lane_count: usize,
    blocks: []const TimelineBlock,
    border: ui.Color,
    label_color: ui.Color,
};

pub const ControlGroupProps = struct {
    id: u32,
    title: []const u8,
    value: []const u8,
    slider_id: u32,
    slider_value: f32,
    down_id: u32,
    down_label: []const u8,
    down_icon: ui_icon.Icon,
    up_id: u32,
    up_label: []const u8,
    up_icon: ui_icon.Icon,
};

pub const PathRowProps = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    trailing: []const u8,
    progress: f32,
    accent: ui.Color,
    progress_color: ui.Color,
    selected: bool = false,
    fill: ?ui.Color = null,
    selected_fill: ?ui.Color = null,
    border: ?ui.Color = null,
    text: ?ui.Color = null,
    muted: ?ui.Color = null,
};

pub const PipelineNodeProps = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    accent: ui.Color,
    selected: bool = false,
    fill: ?ui.Color = null,
    selected_fill: ?ui.Color = null,
    border: ?ui.Color = null,
    text: ?ui.Color = null,
    muted: ?ui.Color = null,
};

pub const FloatingPanelProps = struct {
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    shadow: ui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 88 },
    radius: f32 = 12.0,
    shadow_size: f32 = 8.0,
    shadow_outset: f32 = 2.0,
    inset: f32 = 16.0,
    scrim: ?ui.Color = null,
    scrim_height: f32 = 0.0,
};

pub const MessageBubbleProps = struct {
    body: []const u8,
    outbound: bool = false,
    media_label: []const u8 = "",
    media_detail: []const u8 = "",
    media_icon: ?ui_icon.Icon = null,
    inbound_fill: ?ui.Color = null,
    outbound_fill: ui.Color = .{ .r = 15, .g = 95, .b = 160 },
    outbound_border: ui.Color = .{ .r = 58, .g = 177, .b = 255, .a = 190 },
    radius: f32 = 5.0,
};

pub const StackCursor = struct {
    bounds: ui.Rect,
    gap: f32 = 0.0,
    cursor_y: f32,

    pub fn init(bounds: ui.Rect, gap: f32) StackCursor {
        return .{ .bounds = bounds, .gap = gap, .cursor_y = bounds.y };
    }

    pub fn take(self: *StackCursor, height: f32) ui.Rect {
        const resolved_h = @max(primitives.min_extent, height);
        const rect = ui.Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, resolved_h);
        self.cursor_y += resolved_h + self.gap;
        return rect;
    }

    pub fn takeIfFits(self: *StackCursor, height: f32) ?ui.Rect {
        if (self.cursor_y + height > self.bounds.y + self.bounds.h) return null;
        return self.take(height);
    }

    pub fn skip(self: *StackCursor, amount: f32) void {
        self.cursor_y += amount;
    }

    pub fn remaining(self: StackCursor) ui.Rect {
        const h = @max(primitives.min_extent, self.bounds.y + self.bounds.h - self.cursor_y);
        return ui.Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, h);
    }
};

pub const RowCursor = struct {
    bounds: ui.Rect,
    gap: f32 = 0.0,
    cursor_x: f32,

    pub fn init(bounds: ui.Rect, gap: f32) RowCursor {
        return .{ .bounds = bounds, .gap = gap, .cursor_x = bounds.x };
    }

    pub fn take(self: *RowCursor, width: f32) ui.Rect {
        const resolved_w = @max(primitives.min_extent, width);
        const rect = ui.Rect.init(self.cursor_x, self.bounds.y, resolved_w, self.bounds.h);
        self.cursor_x += resolved_w + self.gap;
        return rect;
    }

    pub fn remaining(self: RowCursor) ui.Rect {
        const w = @max(primitives.min_extent, self.bounds.x + self.bounds.w - self.cursor_x);
        return ui.Rect.init(self.cursor_x, self.bounds.y, w, self.bounds.h);
    }
};

pub const Split = struct {
    first: ui.Rect,
    second: ui.Rect,
};

pub const Grid = struct {
    bounds: ui.Rect,
    columns: usize,
    gap: f32,
    item_h: f32,

    pub fn item(self: Grid, index: usize) ui.Rect {
        const columns_value = @max(@as(usize, 1), self.columns);
        const col = index % columns_value;
        const row_value = index / columns_value;
        const col_f = @as(f32, @floatFromInt(col));
        const row_f = @as(f32, @floatFromInt(row_value));
        const column_count_f = @as(f32, @floatFromInt(columns_value));
        const item_w = @max(primitives.min_extent, (self.bounds.w - self.gap * @as(f32, @floatFromInt(columns_value - 1))) / column_count_f);
        return ui.Rect.init(
            self.bounds.x + col_f * (item_w + self.gap),
            self.bounds.y + row_f * (self.item_h + self.gap),
            item_w,
            self.item_h,
        );
    }

    pub fn height(self: Grid, item_count: usize) f32 {
        if (item_count == 0) return 0.0;
        const rows = (item_count + @max(@as(usize, 1), self.columns) - 1) / @max(@as(usize, 1), self.columns);
        return @as(f32, @floatFromInt(rows)) * self.item_h + @as(f32, @floatFromInt(rows - 1)) * self.gap;
    }
};

pub const View = struct {
    scene: *ui.Scene,
    collector: ?*interaction.Collector = null,
    options: RenderOptions = .{},

    pub fn withOptions(self: View, options: RenderOptions) View {
        var next = self;
        next.options = options;
        return next;
    }

    pub fn withStyle(self: View, style: ui.Style) View {
        return self.withOptions(self.options.withStyle(style));
    }

    pub fn withAccent(self: View, color: ui.Color) View {
        return self.withOptions(self.options.withAccent(color));
    }

    pub fn withTextColor(self: View, color: ui.Color) View {
        return self.withOptions(self.options.withTextColor(color));
    }

    pub fn withControl(self: View, control: common.ControlState) View {
        return self.withOptions(self.options.withControl(control));
    }

    pub fn withMergedControl(self: View, control: common.ControlState) View {
        return self.withOptions(self.options.withMergedControl(control));
    }

    pub fn withControlSize(self: View, size: common.ControlSize) View {
        return self.withOptions(self.options.withControlSize(size));
    }

    pub fn hasCollector(self: View) bool {
        return self.collector != null;
    }

    pub fn draw(self: View, component: Component, bounds: ui.Rect) ui.RenderError!void {
        try component.render(self.scene, bounds, self.options);
    }

    pub fn drawWith(self: View, component: Component, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try component.render(self.scene, bounds, options);
    }

    pub fn interactive(self: View, component: Component, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try component.renderInteractive(self.scene, collector, bounds, self.options);
    }

    pub fn interactiveWith(self: View, component: Component, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try component.renderInteractive(self.scene, collector, bounds, options);
    }

    pub fn drawWithControl(self: View, component: Component, bounds: ui.Rect, control: common.ControlState) ui.RenderError!void {
        try self.drawWith(component, bounds, self.options.withMergedControl(control));
    }

    pub fn interactiveWithControl(self: View, component: Component, bounds: ui.Rect, control: common.ControlState) (ui.RenderError || interaction.Error)!void {
        try self.interactiveWith(component, bounds, self.options.withMergedControl(control));
    }

    pub fn hit(self: View, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try collector.addHit(bounds, kind, id);
    }

    pub fn buttonHit(self: View, bounds: ui.Rect, id: u32) interaction.Error!void {
        try self.hit(bounds, .button, id);
    }

    pub fn line(self: View, bounds: ui.Rect) ui.RenderError!void {
        try self.draw(separator(), bounds);
    }

    pub fn text(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushText(bounds, value, color);
    }

    pub fn alignedText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
        try self.scene.pushAlignedText(bounds, value, color, alignment);
    }

    pub fn strongText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushStrongText(bounds, value, color);
    }

    pub fn boldText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushBoldText(bounds, value, color);
    }

    pub fn icon(self: View, bounds: ui.Rect, icon_value: ui_icon.Icon, color: ui.Color) ui.RenderError!void {
        try Icon.named(icon_value).renderColor(self.scene, bounds, color);
    }

    pub fn fill(self: View, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushRect(bounds, color, .fill, radius, 0.0);
    }

    pub fn stroke(self: View, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushRect(bounds, color, .border, radius, 0.0);
    }

    pub fn gradient(self: View, bounds: ui.Rect, top: ui.Color, bottom: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushGradientRect(bounds, top, bottom, radius);
    }

    pub fn topScrim(self: View, bounds: ui.Rect, color: ui.Color, height: f32, radius: f32) ui.RenderError!void {
        if (height <= 0.0 or color.a == 0) return;
        try self.gradient(ui.Rect.init(bounds.x, bounds.y, bounds.w, height), color, ui.Color.clear, radius);
    }

    pub fn column(self: View, bounds: ui.Rect, gap: f32) StackCursor {
        _ = self;
        return StackCursor.init(bounds, gap);
    }

    pub fn row(self: View, bounds: ui.Rect, gap: f32) RowCursor {
        _ = self;
        return RowCursor.init(bounds, gap);
    }

    pub fn splitLeft(self: View, bounds: ui.Rect, width: f32, gap: f32) Split {
        _ = self;
        const first_w = @min(bounds.w, @max(primitives.min_extent, width));
        const rest_x = bounds.x + first_w + gap;
        return .{
            .first = ui.Rect.init(bounds.x, bounds.y, first_w, bounds.h),
            .second = ui.Rect.init(rest_x, bounds.y, @max(primitives.min_extent, bounds.x + bounds.w - rest_x), bounds.h),
        };
    }

    pub fn splitRight(self: View, bounds: ui.Rect, width: f32, gap: f32) Split {
        _ = self;
        const second_w = @min(bounds.w, @max(primitives.min_extent, width));
        const second_x = bounds.x + @max(0.0, bounds.w - second_w);
        return .{
            .first = ui.Rect.init(bounds.x, bounds.y, @max(primitives.min_extent, second_x - gap - bounds.x), bounds.h),
            .second = ui.Rect.init(second_x, bounds.y, second_w, bounds.h),
        };
    }

    pub fn splitTop(self: View, bounds: ui.Rect, height: f32, gap: f32) Split {
        _ = self;
        const first_h = @min(bounds.h, @max(primitives.min_extent, height));
        const rest_y = bounds.y + first_h + gap;
        return .{
            .first = ui.Rect.init(bounds.x, bounds.y, bounds.w, first_h),
            .second = ui.Rect.init(bounds.x, rest_y, bounds.w, @max(primitives.min_extent, bounds.y + bounds.h - rest_y)),
        };
    }

    pub fn splitBottom(self: View, bounds: ui.Rect, height: f32, gap: f32) Split {
        _ = self;
        const second_h = @min(bounds.h, @max(primitives.min_extent, height));
        const second_y = bounds.y + @max(0.0, bounds.h - second_h);
        return .{
            .first = ui.Rect.init(bounds.x, bounds.y, bounds.w, @max(primitives.min_extent, second_y - gap - bounds.y)),
            .second = ui.Rect.init(bounds.x, second_y, bounds.w, second_h),
        };
    }

    pub fn grid(self: View, bounds: ui.Rect, columns: usize, gap: f32, item_h: f32) Grid {
        _ = self;
        return .{ .bounds = bounds, .columns = @max(@as(usize, 1), columns), .gap = gap, .item_h = item_h };
    }

    pub fn title(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.strongText(bounds, value, self.options.style.text);
    }

    pub fn body(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.text(bounds, value, self.options.style.text);
    }

    pub fn muted(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.text(bounds, value, self.options.style.muted);
    }

    pub fn wrapped(self: View, bounds: ui.Rect, value: []const u8, max_lines: usize) ui.RenderError!void {
        try text_component.Text.renderWrapped(self.scene, bounds, value, self.options.style.text, .{
            .line_height = 16.0,
            .average_char_width = 7.0,
            .max_lines = max_lines,
        });
    }

    pub fn wrappedWith(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color, line_height: f32, average_char_width: f32, max_lines: usize) ui.RenderError!void {
        try text_component.Text.renderWrapped(self.scene, bounds, value, color, .{
            .line_height = line_height,
            .average_char_width = average_char_width,
            .max_lines = max_lines,
        });
    }

    pub fn renderIconButtonNamed(self: View, bounds: ui.Rect, id: u32, label: []const u8, icon_value: ui_icon.Icon, variant: ButtonVariant) (ui.RenderError || interaction.Error)!void {
        try self.interactive(iconButtonNamed(id, label, icon_value, variant), bounds);
    }

    pub fn renderButtonIcon(self: View, bounds: ui.Rect, id: u32, label: []const u8, variant: ButtonVariant, icon_value: ui_icon.Icon) (ui.RenderError || interaction.Error)!void {
        try self.interactive(buttonIcon(id, label, variant, icon_value), bounds);
    }

    pub fn renderTextareaValue(self: View, bounds: ui.Rect, id: u32, placeholder: []const u8, value: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.interactive(textareaValue(id, placeholder, value), bounds);
    }

    pub fn selectableRow(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8, icon_value: ui_icon.Icon, active: bool) (ui.RenderError || interaction.Error)!void {
        try self.interactiveWithControl(rowItemIcon(id, title_value, detail_value, icon_value), bounds, .{ .active = active });
    }

    pub fn section(self: View, bounds: ui.Rect, props: SectionProps) ui.RenderError!void {
        const text_x = if (props.icon != null) bounds.x + 42.0 else bounds.x;
        const text_w = @max(primitives.min_extent, bounds.x + bounds.w - text_x);
        if (props.icon) |icon_value| {
            const chip = ui.Rect.init(bounds.x, bounds.y + 2.0, 28.0, 28.0);
            try self.scene.pushRect(chip, self.options.style.row, .fill, 7.0, 0.0);
            try self.scene.pushRect(chip, self.options.style.border, .border, 7.0, 0.0);
            try self.icon(chip.withHeightCentered(15.0).withWidthCentered(15.0), icon_value, self.options.style.accent);
        }
        try self.strongText(ui.Rect.init(text_x, bounds.y, text_w, 18.0), props.title, self.options.style.text);
        if (props.detail.len != 0) {
            try self.text(ui.Rect.init(text_x, bounds.y + 23.0, text_w, 15.0), props.detail, self.options.style.muted);
        }
    }

    pub fn labelValue(self: View, bounds: ui.Rect, label: []const u8, value: []const u8, label_w: f32) ui.RenderError!void {
        const clamped_label_w = @min(bounds.w, @max(primitives.min_extent, label_w));
        try self.text(ui.Rect.init(bounds.x, bounds.y, clamped_label_w, bounds.h), label, self.options.style.muted);
        if (bounds.w > clamped_label_w) {
            try self.strongText(
                ui.Rect.init(bounds.x + clamped_label_w, bounds.y, @max(primitives.min_extent, bounds.w - clamped_label_w), bounds.h),
                value,
                self.options.style.text,
            );
        }
    }

    pub fn metricCard(self: View, bounds: ui.Rect, props: MetricCardProps) (ui.RenderError || interaction.Error)!void {
        const card_component_value = if (props.id) |id|
            selectablePanel(id, "", "")
        else
            panel("", "");
        if (props.id != null) {
            try self.interactiveWithControl(card_component_value, bounds, .{ .active = props.selected });
        } else {
            try self.drawWithControl(card_component_value, bounds, .{ .active = props.selected });
        }

        const inner = bounds.insetUniform(14.0);
        const text_x = if (props.icon != null) inner.x + 40.0 else inner.x;
        const text_w = @max(primitives.min_extent, inner.x + inner.w - text_x);
        if (props.icon) |icon_value| {
            const chip = ui.Rect.init(inner.x, inner.y, 28.0, 28.0);
            try self.scene.pushRect(chip, self.options.style.row, .fill, 7.0, 0.0);
            try self.scene.pushRect(chip, self.options.style.border, .border, 7.0, 0.0);
            try self.icon(chip.withHeightCentered(15.0).withWidthCentered(15.0), icon_value, self.options.style.accent);
        }
        try self.strongText(ui.Rect.init(text_x, inner.y - 1.0, text_w, 17.0), props.title, self.options.style.text);
        if (props.detail.len != 0) {
            try self.text(ui.Rect.init(text_x, inner.y + 21.0, text_w, 14.0), props.detail, self.options.style.muted);
        }
        const value_y = if (props.detail.len != 0) inner.y + 58.0 else inner.y + 36.0;
        if (props.value.len != 0) {
            try self.text(ui.Rect.init(inner.x, value_y, inner.w, 20.0), props.value, self.options.style.text);
        }
        if (props.progress) |value| {
            try self.draw(progress(value), ui.Rect.init(inner.x, inner.y + inner.h - 24.0, inner.w, 18.0));
        }
    }

    pub fn segmentMap(self: View, bounds: ui.Rect, props: SegmentMapProps) (ui.RenderError || interaction.Error)!void {
        try self.scene.pushRect(bounds, props.background, .fill, props.radius, 0.0);
        try self.scene.pushRect(bounds, props.border, .border, props.radius, 0.0);
        const inner = bounds.insetUniform(8.0);
        var total_weight: f32 = 0.0;
        for (props.segments) |segment| {
            total_weight += @max(0.0, segment.weight);
        }
        if (props.segments.len == 0 or total_weight <= 0.0) return;

        var x = inner.x;
        for (props.segments, 0..) |segment, index| {
            const remaining = @max(primitives.min_extent, inner.x + inner.w - x);
            const normalized = @max(0.0, segment.weight) / total_weight;
            const width = if (index == props.segments.len - 1) remaining else @max(18.0, inner.w * normalized);
            const block_w = @max(primitives.min_extent, @min(width, remaining));
            const block_h = @max(18.0, inner.h * @max(0.05, @min(1.0, segment.height)));
            const block = ui.Rect.init(x, inner.y + inner.h - block_h, block_w, block_h);
            try self.interactive(selectableSubtle(segment.id, "", ""), block);
            try self.scene.pushRect(block, segment.color, .fill, props.radius - 3.0, 0.0);
            try self.scene.pushRect(block, if (segment.selected) props.selected_border else props.border, .border, props.radius - 3.0, 0.0);
            x += width + props.gap;
            if (x >= inner.x + inner.w) break;
        }
    }

    pub fn timelineLane(self: View, axis: ui.Rect, props: TimelineLaneProps) (ui.RenderError || interaction.Error)!void {
        if (props.lane_count == 0) return;
        const lane_h = @max(primitives.min_extent, (axis.h - 16.0) / @as(f32, @floatFromInt(props.lane_count)));
        const y = axis.y + 18.0 + @as(f32, @floatFromInt(props.lane_index)) * lane_h;
        try self.text(ui.Rect.init(axis.x - 78.0, y + 4.0, 68.0, 16.0), props.label, props.label_color);
        try self.scene.pushRect(ui.Rect.init(axis.x, y + lane_h - 6.0, axis.w, 1.0), props.border, .fill, 0.0, 0.0);
        for (props.blocks) |block_value| {
            if (block_value.value <= 0.001) continue;
            const start_x = axis.x + axis.w * @max(0.0, @min(1.0, block_value.start));
            const end_x = axis.x + axis.w * @max(0.0, @min(1.0, block_value.end));
            const w = @max(4.0, @max(0.0, end_x - start_x));
            const h = @max(5.0, (lane_h - 18.0) * @max(0.0, @min(1.0, block_value.value)));
            const block_bounds = ui.Rect.init(start_x, y + lane_h - 8.0 - h, w, h);
            try self.interactive(selectableSubtle(block_value.id, "", ""), block_bounds);
            try self.scene.pushRect(block_bounds, block_value.color, .fill, 4.0, 0.0);
        }
    }

    pub fn controlGroup(self: View, bounds: ui.Rect, props: ControlGroupProps) (ui.RenderError || interaction.Error)!void {
        try self.interactive(selectableSubtle(props.id, "", ""), bounds);
        const inner = bounds.insetUniform(14.0);
        try self.strongText(ui.Rect.init(inner.x, inner.y, inner.w * 0.55, 18.0), props.title, self.options.style.text);
        try self.text(ui.Rect.init(inner.x + inner.w * 0.55, inner.y + 1.0, inner.w * 0.45, 15.0), props.value, self.options.style.muted);
        try self.interactive(slider(props.slider_id, "", props.slider_value), ui.Rect.init(inner.x, inner.y + 27.0, inner.w, 26.0));
        const half_w = (inner.w - 10.0) * 0.5;
        try self.interactive(buttonIcon(props.down_id, props.down_label, .outline, props.down_icon), ui.Rect.init(inner.x, inner.y + 66.0, half_w, 32.0));
        try self.interactive(buttonIcon(props.up_id, props.up_label, .primary, props.up_icon), ui.Rect.init(inner.x + half_w + 10.0, inner.y + 66.0, half_w, 32.0));
    }

    pub fn pathRow(self: View, bounds: ui.Rect, props: PathRowProps) (ui.RenderError || interaction.Error)!void {
        const fill_color = if (props.selected) props.selected_fill orelse self.options.style.panel else props.fill orelse self.options.style.row;
        const border_color = if (props.selected) props.accent else props.border orelse self.options.style.border;
        const text_color = props.text orelse self.options.style.text;
        const muted_color = props.muted orelse self.options.style.muted;

        try self.interactive(selectableSubtle(props.id, "", ""), bounds);
        try self.scene.pushRect(bounds, fill_color, .fill, 7.0, 0.0);
        try self.scene.pushRect(bounds, border_color, .border, 7.0, 0.0);

        const marker_h = @max(primitives.min_extent, bounds.h - 18.0);
        try self.scene.pushRect(ui.Rect.init(bounds.x + 9.0, bounds.y + 9.0, 7.0, marker_h), props.accent, .fill, 4.0, 0.0);
        try self.strongText(ui.Rect.init(bounds.x + 24.0, bounds.y + 7.0, @max(primitives.min_extent, bounds.w - 92.0), 16.0), props.title, text_color);
        try self.text(ui.Rect.init(bounds.x + 24.0, bounds.y + 27.0, @max(primitives.min_extent, bounds.w - 92.0), 14.0), props.detail, muted_color);
        try self.text(ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + 8.0, 56.0, 14.0), props.trailing, muted_color);
        try self.withAccent(props.progress_color).draw(progress(props.progress), ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + bounds.h - 16.0, 50.0, 6.0));
    }

    pub fn pipelineNode(self: View, bounds: ui.Rect, props: PipelineNodeProps) (ui.RenderError || interaction.Error)!void {
        const fill_color = if (props.selected) props.selected_fill orelse self.options.style.panel else props.fill orelse self.options.style.row;
        const border_color = if (props.selected) props.accent else props.border orelse self.options.style.border;
        const text_color = props.text orelse self.options.style.text;
        const muted_color = props.muted orelse self.options.style.muted;

        try self.interactive(selectableSubtle(props.id, "", ""), bounds);
        try self.scene.pushRect(bounds, fill_color, .fill, 8.0, 0.0);
        try self.scene.pushRect(bounds, border_color, .border, 8.0, 0.0);

        const marker_h = @max(primitives.min_extent, bounds.h - 20.0);
        try self.scene.pushRect(ui.Rect.init(bounds.x + 10.0, bounds.y + 10.0, 8.0, marker_h), props.accent, .fill, 5.0, 0.0);
        try self.strongText(ui.Rect.init(bounds.x + 28.0, bounds.y + 10.0, @max(primitives.min_extent, bounds.w - 36.0), 18.0), props.title, text_color);
        try self.text(ui.Rect.init(bounds.x + 28.0, bounds.y + 32.0, @max(primitives.min_extent, bounds.w - 36.0), 16.0), props.detail, muted_color);
    }

    pub fn floatingPanel(self: View, bounds: ui.Rect, props: FloatingPanelProps) ui.RenderError!ui.Rect {
        const radius = @max(0.0, props.radius);
        if (props.shadow.a != 0 and props.shadow_size > 0.0) {
            try self.scene.pushRect(bounds.insetUniform(-props.shadow_outset), props.shadow, .shadow, radius + props.shadow_outset, props.shadow_size);
        }
        try self.scene.pushRect(bounds, props.fill orelse self.options.style.panel, .fill, radius, 0.0);
        try self.scene.pushRect(bounds, props.border orelse self.options.style.border, .border, radius, 0.0);
        if (props.scrim) |scrim_color| {
            if (props.scrim_height > 0.0) {
                try self.scene.pushGradientRect(ui.Rect.init(bounds.x, bounds.y, bounds.w, props.scrim_height), scrim_color, ui.Color.clear, radius);
            }
        }
        return bounds.insetUniform(props.inset);
    }

    pub fn messageBubble(self: View, bounds: ui.Rect, props: MessageBubbleProps) ui.RenderError!void {
        const fill_color = if (props.outbound) props.outbound_fill else props.inbound_fill orelse self.options.style.row;
        const border_color = if (props.outbound) props.outbound_border else self.options.style.border;
        try self.scene.pushRect(bounds, fill_color, .fill, props.radius, 0.0);
        try self.scene.pushRect(bounds, border_color, .border, props.radius, 0.0);
        try self.wrapped(bounds.insetUniform(11.0), props.body, 2);
        if (props.media_label.len == 0) return;

        const media = ui.Rect.init(bounds.x + 10.0, bounds.y + 42.0, @max(primitives.min_extent, bounds.w - 20.0), 66.0);
        try self.draw(subtle(props.media_label, props.media_detail), media);
        if (props.media_icon) |icon_value| {
            try self.icon(ui.Rect.init(media.x + media.w - 28.0, media.y + 10.0, 18.0, 18.0), icon_value, self.options.style.accent);
        }
    }
};

pub fn textNode(value: []const u8) ui.Node {
    return text(value).node();
}

pub fn cardNode(title: []const u8, detail: []const u8, variant: common.SurfaceVariant) ui.Node {
    return card(title, detail, variant).node();
}

pub fn progressNode(value: f32) ui.Node {
    return progress(value).node();
}

pub fn badgeNode(label: []const u8, variant: common.BadgeVariant) ui.Node {
    return badge(label, variant).node();
}

pub fn emptyNode(title: []const u8, detail: []const u8) ui.Node {
    return empty(title, detail).node();
}

pub fn rowItemNode(id: u32, title: []const u8, detail: []const u8) ui.Node {
    return rowItem(id, title, detail).node();
}

fn componentFromNode(comptime ComponentPayload: type, node_payload: anytype) Error!ComponentPayload {
    if (comptime !@hasDecl(ComponentPayload, "fromNode")) @compileError(@typeName(ComponentPayload) ++ " must own fromNode");
    return ComponentPayload.fromNode(node_payload);
}

comptime {
    @setEvalBranchQuota(10000);
    for (registrations) |entry| {
        if (entry.name.len == 0) @compileError("component union fields must have stable names");
        if (!@hasDecl(entry.type, "node")) @compileError(@typeName(entry.type) ++ " must own node");
        if (!@hasDecl(entry.type, "render")) @compileError(@typeName(entry.type) ++ " must own render");
        if (!@hasDecl(entry.type, "measure")) @compileError(@typeName(entry.type) ++ " must own measure");
        if (!@hasDecl(entry.type, "writeRecord")) @compileError(@typeName(entry.type) ++ " must own writeRecord");
        if (!@hasDecl(entry.type, "fromNode")) @compileError(@typeName(entry.type) ++ " must own fromNode");
        common.assertComponentContract(entry.type, .{
            .requires_id = @hasField(entry.type, "id"),
            .requires_flags = @hasField(entry.type, "flags"),
            .requires_accessibility = @hasDecl(entry.type, "accessibility"),
            .requires_interactions = @hasDecl(entry.type, "collectInteractions"),
        });
    }
}

test "component union is the component list source of truth" {
    const fields = @typeInfo(Component).@"union".fields;
    try std.testing.expectEqual(registrations.len, fields.len);
    inline for (registrations, 0..) |entry, index| {
        const field = fields[index];
        try std.testing.expectEqualStrings(entry.name, field.name);
        try std.testing.expect(field.type == entry.type);
        try std.testing.expect(comptime @hasDecl(entry.type, "node"));
        try std.testing.expect(comptime @hasDecl(entry.type, "render"));
        try std.testing.expect(comptime @hasDecl(entry.type, "measure"));
        try std.testing.expect(comptime @hasDecl(entry.type, "writeRecord"));
        try std.testing.expect(comptime @hasDecl(entry.type, "fromNode"));
    }
}

test "component union roundtrips concrete component objects" {
    const icon_button_component = Component{ .icon_button = .{ .id = 14, .label = "Search", .icon = Icon.named(.search) } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = icon_button_component.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Component.fromObject(canonical);

    try std.testing.expectEqual(@as(u32, 14), decoded.icon_button.id);
    try std.testing.expectEqualStrings("Search", decoded.icon_button.label);
    try std.testing.expectEqual(Icon.named(.search).value, decoded.icon_button.icon.value);
}

test "component constructors provide app-facing composition helpers" {
    try std.testing.expectEqualStrings("Runtime", card("Runtime", "ready", .panel).card.title);
    try std.testing.expectEqual(SurfaceVariant.panel, card("Runtime", "ready", .panel).card.variant);
    try std.testing.expectEqual(@as(u32, 70), selectableCard(70, "Runtime", "ready", .panel).card.id.?);
    try std.testing.expectEqual(SurfaceVariant.panel, panel("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 71), selectablePanel(71, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(SurfaceVariant.elevated, elevated("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 72), selectableElevated(72, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(SurfaceVariant.subtle, subtle("Runtime", "ready").card.variant);
    try std.testing.expectEqual(@as(u32, 73), selectableSubtle(73, "Runtime", "ready").card.id.?);
    try std.testing.expectEqual(@as(f32, 0.42), progress(0.42).progress.value);
    try std.testing.expectEqual(BadgeVariant.secondary, badge("ready", .secondary).badge.variant);
    try std.testing.expectEqual(Icon.named(.sparkles).tag(), icon(.sparkles).icon.tag());
    try std.testing.expectEqual(@as(u32, 74), input(74, "Search").input.id);
    try std.testing.expectEqualStrings("needle", inputValue(74, "Search", "needle").input.value);
    try std.testing.expectEqual(IconSlot.named(.leading, .search).tag(), inputIcon(74, "Search", .search).input.icon_slot.tag());
    try std.testing.expectEqual(@as(u32, 77), rowItem(77, "Task", "Ready").row_item.id);
    try std.testing.expectEqual(IconSlot.named(.leading, .message_2).tag(), rowItemIcon(77, "Task", "Ready", .message_2).row_item.leading_icon.tag());
    try std.testing.expectEqual(@as(u32, 78), button(78, "Run", .primary, IconSlot.named(.leading, .send)).button.id);
    try std.testing.expectEqual(IconSlot.named(.leading, .send).tag(), buttonIcon(78, "Run", .primary, .send).button.icon_slot.tag());
    try std.testing.expectEqual(Icon.named(.send).value, iconButtonNamed(79, "Send", .send, .outline).icon_button.icon.value);
    try std.testing.expectEqual(IconSlot.named(.trailing, .adjustments).tag(), selectIcon(80, "Profile", .adjustments).select.icon_slot.tag());
    try std.testing.expectEqualStrings("Describe", textarea(79, "Describe").textarea.placeholder);
    try std.testing.expectEqualStrings("Live", textareaValue(79, "Describe", "Live").textarea.value);
    try std.testing.expect(checkbox(80, "Enabled", true).checkbox.checked);
    try std.testing.expect(toggle(80, "Bold", true).toggle.pressed);
    try std.testing.expectEqual(@as(u16, 1), tabs(80, "Graph", "Timeline", 1).tabs.active.?);
    try std.testing.expectEqual(@as(u32, 81), chart(81, "Activity").chart.id);
    try std.testing.expectEqualStrings("Heads up", alert("Heads up", "Detail").alert.title);
    try std.testing.expect(destructiveAlert("Delete", "Danger").alert.destructive);
    try std.testing.expectEqual(@as(u32, 82), command(82, "Run command").command.id);
    try std.testing.expectEqualStrings("Saved", toast(83, "Saved", "Complete").toast.title);
    try std.testing.expectEqualStrings("Help", tooltip(84, "?", "Help").tooltip.content);

    try std.testing.expectEqualStrings("Runtime", cardNode("Runtime", "ready", .panel).card.title);
    try std.testing.expectEqual(@as(f32, 0.42), progressNode(0.42).progress.value);
}

test "component flag helpers attach state to components that support flags" {
    try std.testing.expect(buttonText(91, "Run", .primary).loading().button.flags.loading);
    try std.testing.expect(input(92, "Email").invalid().input.flags.invalid);
    try std.testing.expect(rowItem(93, "Task", "Ready").disabled().row_item.flags.disabled);
    try std.testing.expectEqualStrings("Passive", panel("Passive", "No flags").disabled().card.title);
}

test "component view binds scene collector and options for app rendering" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [8]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const app = renderer(&scene, &collector, .{});

    try app.draw(panel("Runtime", "ready"), ui.Rect.init(0, 0, 120, 64));
    try app.interactive(buttonIcon(81, "Run", .primary, .send), ui.Rect.init(0, 72, 120, 36));
    try app.line(ui.Rect.init(0, 116, 120, 1));
    try app.icon(ui.Rect.init(4, 122, 16, 16), .send, ui.Color.accent);
    try app.buttonHit(ui.Rect.init(0, 144, 120, 24), 82);
    try app.interactive(selectablePanel(83, "Selectable", "card owns hit"), ui.Rect.init(0, 176, 120, 48));

    try std.testing.expect(component_test.hasText(scene.written(), "Runtime"));
    try std.testing.expect(component_test.hasText(scene.written(), "Run"));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon_pack.iconId(.send)));
    try std.testing.expectEqual(@as(u32, 81), collector.written()[0].id);
    try std.testing.expectEqual(@as(u32, 82), collector.written()[1].id);
    try std.testing.expectEqual(@as(u32, 83), collector.written()[2].id);
}

test "component renderer reports missing collector for interactive calls" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const app = renderer(&scene, null, .{});

    try std.testing.expect(!app.hasCollector());
    try std.testing.expectError(error.MissingInteractionCollector, app.interactive(buttonText(90, "Run", .primary), ui.Rect.init(0, 0, 100, 36)));
    try std.testing.expectError(error.MissingInteractionCollector, app.buttonHit(ui.Rect.init(0, 40, 100, 24), 91));
}

test "component renderer provides higher level app surfaces" {
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [12]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const app = renderer(&scene, &collector, .{});

    try app.section(ui.Rect.init(0, 0, 240, 42), .{
        .title = "Controls",
        .detail = "Runtime knobs",
        .icon = .adjustments,
    });
    try app.labelValue(ui.Rect.init(0, 42, 240, 18), "path", "repo", 64.0);
    try app.metricCard(ui.Rect.init(0, 52, 240, 112), .{
        .id = 99,
        .title = "Memory",
        .detail = "Live pressure",
        .value = "42%",
        .icon = .database,
        .progress = 0.42,
    });
    const segments = [_]Segment{
        .{ .id = 100, .weight = 0.7, .height = 1.0, .color = ui.Color.accent, .selected = true },
        .{ .id = 101, .weight = 0.3, .height = 0.4, .color = ui.Color.muted },
    };
    try app.segmentMap(ui.Rect.init(0, 174, 240, 64), .{
        .segments = &segments,
        .background = ui.Color.panel,
        .border = ui.Color.border,
        .selected_border = ui.Color.text,
    });
    const blocks = [_]TimelineBlock{
        .{ .id = 102, .start = 0.1, .end = 0.6, .value = 0.8, .color = ui.Color.accent },
    };
    try app.timelineLane(ui.Rect.init(82, 248, 158, 56), .{
        .label = "RAM",
        .lane_index = 0,
        .lane_count = 1,
        .blocks = &blocks,
        .border = ui.Color.border,
        .label_color = ui.Color.muted,
    });
    try app.controlGroup(ui.Rect.init(0, 314, 240, 112), .{
        .id = 103,
        .title = "Screen",
        .value = "42%",
        .slider_id = 104,
        .slider_value = 0.42,
        .down_id = 105,
        .down_label = "Screen -",
        .down_icon = .brightness_down,
        .up_id = 106,
        .up_label = "Screen +",
        .up_icon = .brightness_up,
    });
    try app.pathRow(ui.Rect.init(0, 436, 240, 58), .{
        .id = 107,
        .title = "repo/app",
        .detail = "UI source",
        .trailing = "42 MB",
        .progress = 0.6,
        .accent = ui.Color.accent,
        .progress_color = ui.Color.accent,
    });
    try app.pipelineNode(ui.Rect.init(0, 504, 240, 64), .{
        .id = 108,
        .title = "index",
        .detail = "extract relationships",
        .accent = ui.Color.accent,
    });
    _ = try app.floatingPanel(ui.Rect.init(0, 578, 160, 80), .{
        .scrim = ui.Color.accent,
        .scrim_height = 24.0,
    });

    try std.testing.expect(component_test.hasText(scene.written(), "Controls"));
    try std.testing.expect(component_test.hasText(scene.written(), "repo"));
    try std.testing.expect(component_test.hasText(scene.written(), "Memory"));
    try std.testing.expect(component_test.hasText(scene.written(), "42%"));
    try std.testing.expect(component_test.hasText(scene.written(), "index"));
    try std.testing.expectEqual(@as(u32, 99), collector.written()[0].id);
    try std.testing.expectEqual(@as(u32, 100), collector.written()[1].id);
    try std.testing.expectEqual(@as(u32, 101), collector.written()[2].id);
    try std.testing.expectEqual(@as(u32, 102), collector.written()[3].id);
    try std.testing.expectEqual(@as(u32, 103), collector.written()[4].id);
    try std.testing.expectEqual(@as(u32, 104), collector.written()[5].id);
    try std.testing.expectEqual(@as(u32, 105), collector.written()[6].id);
    try std.testing.expectEqual(@as(u32, 106), collector.written()[7].id);
    try std.testing.expectEqual(@as(u32, 107), collector.written()[8].id);
    try std.testing.expectEqual(@as(u32, 108), collector.written()[9].id);
}

test "component renderer provides layout cursors and message bubbles" {
    var commands: [48]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const app = renderer(&scene, null, .{});

    var column_cursor = app.column(ui.Rect.init(10, 20, 120, 100), 6.0);
    try std.testing.expectEqual(ui.Rect.init(10, 20, 120, 24), column_cursor.take(24.0));
    try std.testing.expectEqual(ui.Rect.init(10, 50, 120, 30), column_cursor.take(30.0));
    try std.testing.expect(column_cursor.takeIfFits(80.0) == null);
    try std.testing.expectEqual(ui.Rect.init(10, 86, 120, 34), column_cursor.remaining());

    var row_cursor = app.row(ui.Rect.init(0, 0, 100, 20), 5.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 30, 20), row_cursor.take(30.0));
    try std.testing.expectEqual(ui.Rect.init(35, 0, 65, 20), row_cursor.remaining());

    const split = app.splitLeft(ui.Rect.init(0, 0, 100, 20), 30.0, 5.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 30, 20), split.first);
    try std.testing.expectEqual(ui.Rect.init(35, 0, 65, 20), split.second);

    const grid_layout = app.grid(ui.Rect.init(0, 0, 105, 200), 2, 5.0, 20.0);
    try std.testing.expectEqual(ui.Rect.init(0, 0, 50, 20), grid_layout.item(0));
    try std.testing.expectEqual(ui.Rect.init(55, 0, 50, 20), grid_layout.item(1));
    try std.testing.expectEqual(ui.Rect.init(0, 25, 50, 20), grid_layout.item(2));
    try std.testing.expectEqual(@as(f32, 45.0), grid_layout.height(4));

    try app.messageBubble(ui.Rect.init(0, 130, 220, 112), .{
        .body = "Image received",
        .media_label = "image",
        .media_detail = "object://image/8f21",
        .media_icon = .photo,
    });
    try std.testing.expect(component_test.hasText(scene.written(), "Image received"));
    try std.testing.expect(component_test.hasText(scene.written(), "image"));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon_pack.iconId(.photo)));
}

test "component render options helpers preserve immutable call style" {
    const options = (RenderOptions{})
        .withStyle(ui.Style{ .accent = ui.Color.accent })
        .withAccent(ui.Color.text)
        .withTextColor(ui.Color.muted)
        .withControl(.{ .active = true })
        .withMergedControl(.{ .loading = true })
        .withControlSize(.large);

    try std.testing.expectEqual(ui.Color.text, options.style.accent);
    try std.testing.expectEqual(ui.Color.muted, options.style.text);
    try std.testing.expect(options.control.active);
    try std.testing.expect(options.control.loading);
    try std.testing.expectEqual(common.ControlSize.large, options.control_size);
}

test "component union decodes only canonical component objects" {
    const component = Component{ .badge = .{ .label = "Object", .variant = .secondary } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.meta.eql(component_codec.requirements(), view.header.requirements));
    try std.testing.expectError(error.Corrupt, Component.fromObject(view.body));
}

test "component union rejects objects without component requirements" {
    const component = Component{ .button = .{ .id = 7, .label = "Wrong req" } };
    var req = component_codec.requirements();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_codec.writeRecord(Component, &writer, 0, component));
    const canonical = writer.objectNode(&object_raw, req, component_test.epoch()).?;

    try std.testing.expectError(error.Corrupt, Component.fromObject(canonical));
}

test "component union dispatches button variants and collects hit targets" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const primary = Component{ .button = .{ .id = 501, .label = "Primary" } };
    const outline = Component{ .button = .{ .id = 502, .label = "Outline", .variant = .outline, .icon_slot = IconSlot.named(.leading, .search) } };
    try primary.render(&scene, ui.Rect.init(0, 0, 120, 36), .{});
    try primary.collectInteractions(&collector, ui.Rect.init(0, 0, 120, 36), .{});
    try outline.render(&scene, ui.Rect.init(0, 44, 120, 36), .{});
    try outline.collectInteractions(&collector, ui.Rect.init(0, 44, 120, 36), .{});

    try std.testing.expectEqual(@as(u32, 501), ui_input.hitTest(collector.written(), 12, 12).?.id);
    try std.testing.expectEqual(@as(u32, 502), ui_input.hitTest(collector.written(), 12, 56).?.id);
    try std.testing.expect(component_test.hasText(scene.written(), "Primary"));
    try std.testing.expect(component_test.hasText(scene.written(), "Outline"));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon_pack.iconId(.search)));
}

test "component renderInteractive renders and collects through one canonical path" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const launch_button = Component{ .button = .{ .id = 510, .label = "Launch" } };
    try launch_button.renderInteractive(&scene, &collector, ui.Rect.init(0, 0, 120, 36), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Launch"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
    try std.testing.expectEqual(@as(u32, 510), collector.written()[0].id);
}

test "component renderInteractive honors disabled interaction state" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const disabled_button = Component{ .button = .{ .id = 511, .label = "Disabled" } };
    try disabled_button.renderInteractive(&scene, &collector, ui.Rect.init(0, 0, 120, 36), .{
        .interaction = .{ .disabled_id = 511 },
    });

    try std.testing.expect(component_test.hasText(scene.written(), "Disabled"));
    try std.testing.expect(component_test.hasFillColor(scene.written(), common.state_disabled_tint));
    try std.testing.expectEqual(@as(usize, 0), collector.written().len);
}

test "component renderer exports shared sizing tokens for measurements" {
    try std.testing.expectEqual(ui_tokens.Component.surface_radius, card_component.surface_radius);
    try std.testing.expectEqual(ui_tokens.Component.surface_padding, card_component.surface_padding);
    try std.testing.expectEqual(ui_tokens.Component.surface_detail_gap, card_component.surface_detail_gap);
    try std.testing.expectEqual(ui_tokens.Component.badge_height, badge_component.badge_height);
    try std.testing.expectEqual(ui_tokens.Component.badge_padding_x, badge_component.badge_padding_x);
}

test "component accessibility metadata comes from component identity and labels" {
    const button_meta = (Component{ .button = .{ .id = 91, .label = "Save" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.button, button_meta.role);
    try std.testing.expectEqual(@as(u32, 91), button_meta.control_id.?);
    try std.testing.expectEqualStrings("Save", button_meta.label);

    const input_meta = (Component{ .input = .{ .id = 92, .placeholder = "Email" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.input, input_meta.role);
    try std.testing.expectEqual(@as(u32, 92), input_meta.control_id.?);
    try std.testing.expectEqualStrings("Email", input_meta.label);

    const table_meta = (Component{ .table = .{ .id = 93, .name = "Ada", .role = "Engineer" } }).accessibility();
    try std.testing.expectEqual(common.AccessibilityRole.table, table_meta.role);
    try std.testing.expectEqual(@as(u32, 93), table_meta.control_id.?);
    try std.testing.expectEqualStrings("Ada", table_meta.label);
}

test "component union applies shared interactive states by component id" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const save_button = Component{ .button = .{ .id = 701, .label = "Save" } };
    try save_button.render(&scene, ui.Rect.init(10, 12, 120, 36), .{
        .interaction = .{
            .hovered_id = 701,
            .active_id = 701,
            .focused_id = 701,
            .disabled_id = 701,
            .loading_id = 701,
            .invalid_id = 701,
        },
    });

    try std.testing.expect(component_test.hasRectColor(scene.written(), common.state_hover_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), common.state_active_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), common.state_focus_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), common.state_invalid_border));
    try std.testing.expect(component_test.hasFillColor(scene.written(), common.state_disabled_tint));
    try std.testing.expect(component_test.hasFillColor(scene.written(), common.state_loading_fill));
}

test "component union does not leak interactive state to other ids" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const save_button = Component{ .button = .{ .id = 702, .label = "Save" } };
    try save_button.render(&scene, ui.Rect.init(10, 12, 120, 36), .{
        .interaction = .{ .focused_id = 701 },
    });

    try std.testing.expect(!component_test.hasRectColor(scene.written(), common.state_focus_border));
}

test "component interaction collection covers primitive controls" {
    const controls = [_]Component{
        .{ .input = .{ .id = 601, .placeholder = "Filter" } },
        .{ .textarea = .{ .id = 602, .placeholder = "Explain" } },
        .{ .select = .{ .id = 603, .label = "Mode" } },
        .{ .checkbox = .{ .id = 604, .label = "Receipts", .checked = true } },
        .{ .switch_control = .{ .id = 605, .label = "Public", .checked = false } },
        .{ .slider = .{ .id = 606, .label = "Brightness", .value = 0.5 } },
        .{ .row_item = .{ .id = 607, .title = "DNS", .detail = "Lookup" } },
    };
    const expected = [_]ui.HitKind{ .input, .textarea, .select, .checkbox, .switch_control, .slider, .row_item };
    var regions: [controls.len]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    for (controls, 0..) |component, index| {
        const y = @as(f32, @floatFromInt(index)) * 48.0;
        try component.collectInteractions(&collector, ui.Rect.init(0, y, 240, 40), .{});
    }

    try std.testing.expectEqual(controls.len, collector.written().len);
    for (collector.written(), 0..) |region, index| {
        try std.testing.expectEqual(@as(u32, 601 + @as(u32, @intCast(index))), region.id);
        try std.testing.expectEqual(expected[index], region.kind);
    }
}

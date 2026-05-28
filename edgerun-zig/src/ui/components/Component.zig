const clock = @import("../../clock.zig");
const ui_input = @import("../../input.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const common = @import("../../ui_component_common.zig");
const component_codec = @import("Codec.zig");
const component_test = @import("TestSupport.zig");
const primitives = @import("Primitives.zig");
const std = @import("std");
const ui_tokens = @import("../../ui_tokens.zig");

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
            inline else => |component| if (comptime @hasDecl(@TypeOf(component), "accessibility")) component.accessibility() else .{ .role = .generic },
        };
    }

    pub fn collectAccessibility(self: Component, tree: *AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
        _ = options;
        const metadata = self.accessibility();
        if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
        try tree.append(.{ .metadata = metadata, .bounds = bounds });
    }

    fn controlId(self: Component) ?u32 {
        return self.accessibility().control_id;
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
    const Icon = icon_component.Icon;
    const component = Component{ .icon_button = .{ .id = 14, .label = "Search", .icon = Icon.named(.search) } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Component.fromObject(canonical);

    try std.testing.expectEqual(@as(u32, 14), decoded.icon_button.id);
    try std.testing.expectEqualStrings("Search", decoded.icon_button.label);
    try std.testing.expectEqual(Icon.named(.search).value, decoded.icon_button.icon.value);
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
    const Icon = icon_component.Icon;
    const IconSlot = icon_component.IconSlot;
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const primary = Component{ .button = .{ .id = 501, .label = "Primary" } };
    const outline = Component{ .button = .{ .id = 502, .label = "Outline", .variant = .outline, .icon_slot = IconSlot.named(.leading, .search) } };
    try primary.render(&scene, ui.Rect.init(0, 0, 120, 36), .{});
    try primary.collectInteractions(&collector, ui.Rect.init(0, 0, 120, 36));
    try outline.render(&scene, ui.Rect.init(0, 44, 120, 36), .{});
    try outline.collectInteractions(&collector, ui.Rect.init(0, 44, 120, 36));

    try std.testing.expectEqual(@as(u32, 501), ui_input.hitTest(collector.written(), 12, 12).?.id);
    try std.testing.expectEqual(@as(u32, 502), ui_input.hitTest(collector.written(), 12, 56).?.id);
    try std.testing.expect(component_test.hasText(scene.written(), "Primary"));
    try std.testing.expect(component_test.hasText(scene.written(), "Outline"));
    try std.testing.expect(component_test.hasIcon(scene.written(), Icon.named(.search).tag()));
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
    const button = Component{ .button = .{ .id = 701, .label = "Save" } };
    try button.render(&scene, ui.Rect.init(10, 12, 120, 36), .{
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
    const button = Component{ .button = .{ .id = 702, .label = "Save" } };
    try button.render(&scene, ui.Rect.init(10, 12, 120, 36), .{
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
        try component.collectInteractions(&collector, ui.Rect.init(0, y, 240, 40));
    }

    try std.testing.expectEqual(controls.len, collector.written().len);
    for (collector.written(), 0..) |region, index| {
        try std.testing.expectEqual(@as(u32, 601 + @as(u32, @intCast(index))), region.id);
        try std.testing.expectEqual(expected[index], region.kind);
    }
}

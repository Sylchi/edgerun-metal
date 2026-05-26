const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const component_common = @import("ui_component_common.zig");
const component_union = @import("ui/components/Component.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");

pub const Error = error{
    Corrupt,
    NodeBudgetExceeded,
    UnsupportedObject,
};

pub const magic = "ERUI001\x00";
pub const header_size = 20;
pub const record_size = 16;

pub const RecordKind = enum(u16) {
    text = 1,
    button = 2,
    input = 3,
    row_item = 4,
    slot = 5,
    badge = 6,
    checkbox = 7,
    switch_control = 8,
    progress = 9,
    slider = 10,
    card = 11,
    avatar = 12,
    kbd = 13,
    separator = 14,
    textarea = 15,
    select = 16,
    label = 17,
    skeleton = 18,
    toggle = 19,
    alert = 20,
    radio_group = 21,
    tabs = 22,
    empty = 23,
    button_group = 24,
    input_group = 25,
    accordion = 26,
    aspect_ratio = 27,
    pagination = 28,
    breadcrumb = 29,
    menubar = 30,
    navigation_menu = 31,
    field = 32,
    input_otp = 33,
    toggle_group = 34,
    spinner = 35,
    table = 36,
    resizable = 37,
    scroll_area = 38,
    command = 39,
    carousel = 40,
    combobox = 41,
    calendar = 42,
    chart = 43,
    tooltip = 44,
    popover = 45,
    dialog = 46,
    alert_dialog = 47,
    dropdown_menu = 48,
    context_menu = 49,
    drawer = 50,
    sheet = 51,
    hover_card = 52,
    toast = 53,
    sidebar = 54,
    direction = 55,
    icon_button = 56,
    icon = 57,
};

pub fn decodeObject(canonical: []const u8, out_nodes: []ui.Node) Error!ui.Node {
    const view = object.View.decode(canonical) catch return error.Corrupt;
    return decodeView(view, out_nodes);
}

pub fn decodeView(view: object.View, out_nodes: []ui.Node) Error!ui.Node {
    if (view.header.kind != .bytes) return error.UnsupportedObject;
    return decodeBytes(view.body, out_nodes);
}

pub fn decodeBytes(raw: []const u8, out_nodes: []ui.Node) Error!ui.Node {
    if (raw.len < header_size) return error.Corrupt;
    if (!bytes.eql(raw[0..magic.len], magic)) return error.Corrupt;
    if ((bytes.load16(raw[8..10]) orelse return error.Corrupt) != 1) return error.Corrupt;

    const axis_raw = bytes.load16(raw[10..12]) orelse return error.Corrupt;
    const axis = switch (axis_raw) {
        0 => ui.Axis.column,
        1 => ui.Axis.row,
        else => return error.Corrupt,
    };
    const gap = @as(f32, @floatFromInt(bytes.load16(raw[12..14]) orelse return error.Corrupt));
    const padding = @as(f32, @floatFromInt(bytes.load16(raw[14..16]) orelse return error.Corrupt));
    const node_count = bytes.load16(raw[16..18]) orelse return error.Corrupt;
    const root_count = bytes.load16(raw[18..20]) orelse return error.Corrupt;

    if (node_count == 0 or root_count == 0 or root_count > node_count) return error.Corrupt;
    if (node_count > out_nodes.len) return error.NodeBudgetExceeded;

    const records_len = @as(usize, node_count) * record_size;
    if (records_len > raw.len - header_size) return error.Corrupt;
    const records = raw[header_size..][0..records_len];
    const string_table = raw[header_size + records_len ..];

    var index: usize = 0;
    while (index < node_count) : (index += 1) {
        const record = records[index * record_size ..][0..record_size];
        const kind = recordKind(bytes.load16(record[0..2]) orelse return error.Corrupt) orelse return error.Corrupt;
        const id = bytes.load32(record[4..8]) orelse return error.Corrupt;
        const a = bytes.load16(record[8..10]) orelse return error.Corrupt;
        const b = bytes.load16(record[10..12]) orelse return error.Corrupt;
        const c = bytes.load16(record[12..14]) orelse return error.Corrupt;
        const d = bytes.load16(record[14..16]) orelse return error.Corrupt;

        out_nodes[index] = switch (kind) {
            .text => .{ .text = .{ .value = try stringRef(string_table, a, b) } },
            .accordion => .{ .accordion = .{ .id = id / accordion_id_stride, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d), .open = (id % accordion_id_stride) != 0 } },
            .alert => .{ .alert = .{ .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d), .destructive = (id & alert_destructive_mask) != 0, .icon = try boundedU32Tag(id >> alert_icon_shift, component_common.encoded_icon_count) } },
            .alert_dialog => .{ .alert_dialog = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .aspect_ratio => .{ .aspect_ratio = .{ .ratio_w = c, .ratio_h = d } },
            .calendar => .{ .calendar = .{ .id = id, .month = try stringRef(string_table, a, b), .selected_day = c } },
            .carousel => .{ .carousel = .{ .id = id, .label = try stringRef(string_table, a, b) } },
            .chart => .{ .chart = .{ .id = id, .label = try stringRef(string_table, a, b) } },
            .combobox => .{ .combobox = .{ .id = id, .placeholder = try stringRef(string_table, a, b), .selected = try stringRef(string_table, c, d) } },
            .empty => .{ .empty = .{ .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d), .icon = try boundedU32Tag(id, component_common.encoded_icon_count) } },
            .button => .{ .button = .{ .id = id, .label = try stringRef(string_table, a, b), .variant = try boundedTag(c, button_variant_count), .leading_icon = try boundedTag(d & button_icon_mask, component_common.encoded_icon_count), .trailing_icon = try boundedTag(d >> button_icon_shift, component_common.encoded_icon_count) } },
            .icon_button => .{ .icon_button = .{ .id = id, .label = try stringRef(string_table, a, b), .variant = try boundedTag(c, button_variant_count), .icon = try boundedTag(d, component_common.encoded_icon_count) } },
            .button_group => .{ .button_group = .{ .id = id / grouped_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .active = @intCast(id % grouped_id_stride) } },
            .toggle_group => .{ .toggle_group = .{ .id = id / toggle_group_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .active = @intCast(id % toggle_group_id_stride) } },
            .input => .{ .input = .{ .id = id, .placeholder = try stringRef(string_table, a, b), .leading_icon = try boundedTag(c, component_common.encoded_icon_count) } },
            .input_group => .{ .input_group = .{ .id = id, .addon = try stringRef(string_table, a, b), .placeholder = try stringRef(string_table, c, d) } },
            .row_item => .{ .row_item = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .badge => .{ .badge = .{ .label = try stringRef(string_table, a, b), .variant = try boundedTag(c, badge_variant_count) } },
            .checkbox => .{ .checkbox = .{ .id = id, .label = try stringRef(string_table, a, b), .checked = decodeBool(c) orelse return error.Corrupt } },
            .switch_control => .{ .switch_control = .{ .id = id, .label = try stringRef(string_table, a, b), .checked = decodeBool(c) orelse return error.Corrupt } },
            .pagination => .{ .pagination = .{ .id = id / pagination_id_stride, .page = @intCast(id % pagination_id_stride) } },
            .popover => .{ .popover = .{ .id = id, .trigger = try stringRef(string_table, a, b), .content = try stringRef(string_table, c, d) } },
            .resizable => .{ .resizable = .{ .id = id, .ratio = ui.decodeUnit(c) } },
            .progress => .{ .progress = .{ .value = ui.decodeUnit(c) } },
            .slider => .{ .slider = .{ .id = id, .label = try stringRef(string_table, a, b), .value = ui.decodeUnit(c) } },
            .card => .{ .card = .{ .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d), .variant = try boundedU32Tag(id, surface_variant_count) } },
            .avatar => .{ .avatar = .{ .label = try stringRef(string_table, a, b) } },
            .kbd => .{ .kbd = .{ .label = try stringRef(string_table, a, b) } },
            .label => .{ .label = .{ .value = try stringRef(string_table, a, b) } },
            .separator => .{ .separator = {} },
            .scroll_area => .{ .scroll_area = {} },
            .skeleton => .{ .skeleton = {} },
            .spinner => .{ .spinner = {} },
            .breadcrumb => .{ .breadcrumb = .{ .id = id, .first = try stringRef(string_table, a, b), .current = try stringRef(string_table, c, d) } },
            .menubar => .{ .menubar = .{ .id = id / menubar_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .active = @intCast(id % menubar_id_stride) } },
            .navigation_menu => .{ .navigation_menu = .{ .id = id / navigation_menu_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .active = @intCast(id % navigation_menu_id_stride) } },
            .command => .{ .command = .{ .id = id, .placeholder = try stringRef(string_table, a, b), .leading_icon = try boundedTag(c, component_common.encoded_icon_count) } },
            .context_menu => .{ .context_menu = .{ .id = id, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d) } },
            .dialog => .{ .dialog = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .direction => .{ .direction = .{ .id = id / direction_id_stride, .active = @intCast(id % direction_id_stride) } },
            .icon => .{ .icon = .{ .label = try stringRef(string_table, a, b), .icon = try boundedTag(d, component_common.encoded_icon_count) } },
            .drawer => .{ .drawer = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .dropdown_menu => .{ .dropdown_menu = .{ .id = id, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d) } },
            .field => .{ .field = .{ .id = id, .label = try stringRef(string_table, a, b), .placeholder = try stringRef(string_table, c, d) } },
            .hover_card => .{ .hover_card = .{ .id = id, .trigger = try stringRef(string_table, a, b), .content = try stringRef(string_table, c, d) } },
            .input_otp => .{ .input_otp = .{ .id = id, .value = try stringRef(string_table, a, b) } },
            .toggle => .{ .toggle = .{ .id = id, .label = try stringRef(string_table, a, b), .pressed = decodeBool(c) orelse return error.Corrupt } },
            .textarea => .{ .textarea = .{ .id = id, .placeholder = try stringRef(string_table, a, b) } },
            .select => .{ .select = .{ .id = id, .label = try stringRef(string_table, a, b), .trailing_icon = try boundedTag(c, component_common.encoded_icon_count) } },
            .radio_group => .{ .radio_group = .{ .id = id / radio_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .selected = @intCast(id % radio_id_stride) } },
            .tabs => .{ .tabs = .{ .id = id / tabs_id_stride, .first = try stringRef(string_table, a, b), .second = try stringRef(string_table, c, d), .active = @intCast(id % tabs_id_stride) } },
            .table => .{ .table = .{ .id = id, .name = try stringRef(string_table, a, b), .role = try stringRef(string_table, c, d) } },
            .tooltip => .{ .tooltip = .{ .id = id, .trigger = try stringRef(string_table, a, b), .content = try stringRef(string_table, c, d) } },
            .toast => .{ .toast = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .sheet => .{ .sheet = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .sidebar => .{ .sidebar = .{ .id = id, .title = try stringRef(string_table, a, b), .item = try stringRef(string_table, c, d) } },
            .slot => blk: {
                if (a >= node_count) return error.Corrupt;
                break :blk .{ .slot = .{ .id = id, .child = &out_nodes[a] } };
            },
        };
    }

    return .{ .stack = .{ .axis = axis, .gap = gap, .padding = padding, .children = out_nodes[0..root_count] } };
}

fn stringRef(table: []const u8, offset: u16, len: u16) Error![]const u8 {
    const start: usize = offset;
    const size: usize = len;
    if (start > table.len or size > table.len - start) return error.Corrupt;
    return table[start..][0..size];
}

fn recordKind(value: u16) ?RecordKind {
    return switch (value) {
        @intFromEnum(RecordKind.text) => .text,
        @intFromEnum(RecordKind.button) => .button,
        @intFromEnum(RecordKind.input) => .input,
        @intFromEnum(RecordKind.row_item) => .row_item,
        @intFromEnum(RecordKind.slot) => .slot,
        @intFromEnum(RecordKind.badge) => .badge,
        @intFromEnum(RecordKind.checkbox) => .checkbox,
        @intFromEnum(RecordKind.switch_control) => .switch_control,
        @intFromEnum(RecordKind.progress) => .progress,
        @intFromEnum(RecordKind.slider) => .slider,
        @intFromEnum(RecordKind.card) => .card,
        @intFromEnum(RecordKind.avatar) => .avatar,
        @intFromEnum(RecordKind.kbd) => .kbd,
        @intFromEnum(RecordKind.separator) => .separator,
        @intFromEnum(RecordKind.scroll_area) => .scroll_area,
        @intFromEnum(RecordKind.spinner) => .spinner,
        @intFromEnum(RecordKind.textarea) => .textarea,
        @intFromEnum(RecordKind.select) => .select,
        @intFromEnum(RecordKind.label) => .label,
        @intFromEnum(RecordKind.skeleton) => .skeleton,
        @intFromEnum(RecordKind.toggle) => .toggle,
        @intFromEnum(RecordKind.alert) => .alert,
        @intFromEnum(RecordKind.alert_dialog) => .alert_dialog,
        @intFromEnum(RecordKind.calendar) => .calendar,
        @intFromEnum(RecordKind.carousel) => .carousel,
        @intFromEnum(RecordKind.chart) => .chart,
        @intFromEnum(RecordKind.combobox) => .combobox,
        @intFromEnum(RecordKind.tooltip) => .tooltip,
        @intFromEnum(RecordKind.popover) => .popover,
        @intFromEnum(RecordKind.radio_group) => .radio_group,
        @intFromEnum(RecordKind.tabs) => .tabs,
        @intFromEnum(RecordKind.table) => .table,
        @intFromEnum(RecordKind.empty) => .empty,
        @intFromEnum(RecordKind.button_group) => .button_group,
        @intFromEnum(RecordKind.toggle_group) => .toggle_group,
        @intFromEnum(RecordKind.input_group) => .input_group,
        @intFromEnum(RecordKind.accordion) => .accordion,
        @intFromEnum(RecordKind.aspect_ratio) => .aspect_ratio,
        @intFromEnum(RecordKind.pagination) => .pagination,
        @intFromEnum(RecordKind.resizable) => .resizable,
        @intFromEnum(RecordKind.breadcrumb) => .breadcrumb,
        @intFromEnum(RecordKind.menubar) => .menubar,
        @intFromEnum(RecordKind.navigation_menu) => .navigation_menu,
        @intFromEnum(RecordKind.command) => .command,
        @intFromEnum(RecordKind.context_menu) => .context_menu,
        @intFromEnum(RecordKind.dialog) => .dialog,
        @intFromEnum(RecordKind.direction) => .direction,
        @intFromEnum(RecordKind.icon_button) => .icon_button,
        @intFromEnum(RecordKind.icon) => .icon,
        @intFromEnum(RecordKind.drawer) => .drawer,
        @intFromEnum(RecordKind.dropdown_menu) => .dropdown_menu,
        @intFromEnum(RecordKind.sheet) => .sheet,
        @intFromEnum(RecordKind.field) => .field,
        @intFromEnum(RecordKind.hover_card) => .hover_card,
        @intFromEnum(RecordKind.input_otp) => .input_otp,
        @intFromEnum(RecordKind.toast) => .toast,
        @intFromEnum(RecordKind.sidebar) => .sidebar,
        else => null,
    };
}

fn decodeBool(value: u16) ?bool {
    return switch (value) {
        0 => false,
        1 => true,
        else => null,
    };
}

fn boundedTag(value: u16, count: u16) Error!u16 {
    if (value >= count) return error.Corrupt;
    return value;
}

fn boundedU32Tag(value: u32, count: u16) Error!u16 {
    if (value >= count) return error.Corrupt;
    return @intCast(value);
}

const radio_id_stride: u32 = 2;
const tabs_id_stride: u32 = 2;
const grouped_id_stride: u32 = 2;
const direction_id_stride: u32 = 2;
const alert_destructive_mask: u32 = 1;
const alert_icon_shift: u5 = 1;
const toggle_group_id_stride: u32 = 3;
const accordion_id_stride: u32 = 2;
const pagination_id_stride: u32 = 3;
const menubar_id_stride: u32 = 3;
const navigation_menu_id_stride: u32 = 3;
const button_variant_count: u16 = 6;
const badge_variant_count: u16 = 6;
const surface_variant_count: u16 = 3;
const button_icon_mask: u16 = 0x00ff;
const button_icon_shift: u4 = 8;

test "decode ui bytes into borrowed nodes and render paint" {
    var raw: [256]u8 = undefined;
    var cursor = Writer.init(&raw, 5, 4, .column, 10, 16).?;
    const title = cursor.string("edgerun ui");
    const search = cursor.string("search objects");
    const row_title = cursor.string("object graph");
    const row_detail = cursor.string("canonical data");
    const button = cursor.string("Render");
    try std.testing.expect(cursor.record(0, .text, 0, title.?, .{}));
    try std.testing.expect(cursor.record(1, .input, 10, search.?, .{}));
    try std.testing.expect(cursor.record(2, .row_item, 20, row_title.?, row_detail.?));
    try std.testing.expect(cursor.record(3, .slot, 7, .{ .offset = 4, .len = 0 }, .{}));
    try std.testing.expect(cursor.record(4, .badge, 30, button.?, .{}));

    var nodes: [5]ui.Node = undefined;
    const root = try decodeBytes(cursor.written(), &nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try node_renderer.renderNode(component_union.Component, &scene, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, root, .{});

    try std.testing.expect(hasText(scene.written(), "Render"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

test "decode ui bytes from canonical object body" {
    var raw_ui: [128]u8 = undefined;
    var cursor = Writer.init(&raw_ui, 1, 1, .column, 0, 0).?;
    const label = cursor.string("From object");
    try std.testing.expect(cursor.record(0, .button, 99, label.?, .{}));

    var canonical: [object.header_size + 128]u8 = undefined;
    var keeper = [_]u8{0} ** 32;
    keeper[0] = 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper } };
    const req = object.Requirements{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };
    const canonical_node = cursor.objectNode(&canonical, req, epoch).?;

    var nodes: [1]ui.Node = undefined;
    const root = try decodeObject(canonical_node, &nodes);
    try std.testing.expectEqual(@as(usize, 1), root.stack.children.len);
    try std.testing.expectEqualStrings("From object", root.stack.children[0].button.label);
}

test "decode dev component primitive records" {
    var raw: [256]u8 = undefined;
    var writer = Writer.init(&raw, 5, 5, .column, 6, 8).?;
    const badge = writer.string("Ready").?;
    const checkbox = writer.string("Enable sync").?;
    const switch_label = writer.string("Public").?;
    const slider = writer.string("Brightness").?;
    try std.testing.expect(writer.record(0, .badge, 0, badge, .{}));
    try std.testing.expect(writer.record(1, .checkbox, 11, checkbox, .{ .offset = 1, .len = 0 }));
    try std.testing.expect(writer.record(2, .switch_control, 12, switch_label, .{}));
    try std.testing.expect(writer.record(3, .progress, 0, .{}, .{ .offset = ui.encodeUnit(0.64), .len = 0 }));
    try std.testing.expect(writer.record(4, .slider, 13, slider, .{ .offset = ui.encodeUnit(0.72), .len = 0 }));

    var nodes: [5]ui.Node = undefined;
    const root = try decodeBytes(writer.written(), &nodes);
    try std.testing.expectEqualStrings("Ready", root.stack.children[0].badge.label);
    try std.testing.expect(root.stack.children[1].checkbox.checked);
    try std.testing.expect(!root.stack.children[2].switch_control.checked);
    try std.testing.expect(@abs(root.stack.children[3].progress.value - 0.64) < 0.001);
    try std.testing.expect(@abs(root.stack.children[4].slider.value - 0.72) < 0.001);
}

test "decode layout and display primitive records" {
    var raw: [320]u8 = undefined;
    var writer = Writer.init(&raw, 6, 6, .column, 6, 8).?;
    const card_title = writer.string("Project").?;
    const card_detail = writer.string("Interactive docs").?;
    const avatar = writer.string("ER").?;
    const kbd = writer.string("CmdK").?;
    const textarea = writer.string("Describe this app").?;
    const select = writer.string("Production").?;
    try std.testing.expect(writer.record(0, .card, 0, card_title, card_detail));
    try std.testing.expect(writer.record(1, .separator, 0, .{}, .{}));
    try std.testing.expect(writer.record(2, .avatar, 0, avatar, .{}));
    try std.testing.expect(writer.record(3, .kbd, 0, kbd, .{}));
    try std.testing.expect(writer.record(4, .textarea, 21, textarea, .{}));
    try std.testing.expect(writer.record(5, .select, 22, select, .{}));

    var nodes: [6]ui.Node = undefined;
    const root = try decodeBytes(writer.written(), &nodes);
    try std.testing.expectEqualStrings("Project", root.stack.children[0].card.title);
    try std.testing.expect(root.stack.children[1] == .separator);
    try std.testing.expectEqualStrings("ER", root.stack.children[2].avatar.label);
    try std.testing.expectEqualStrings("CmdK", root.stack.children[3].kbd.label);
    try std.testing.expectEqual(@as(u32, 21), root.stack.children[4].textarea.id);
    try std.testing.expectEqualStrings("Production", root.stack.children[5].select.label);
}

test "decode ui view returned by storage" {
    const store = @import("store.zig");
    const identity = @import("identity.zig");
    const preimage = @import("preimage.zig");

    var raw_ui: [128]u8 = undefined;
    var cursor = Writer.init(&raw_ui, 1, 1, .column, 0, 0).?;
    const label = cursor.string("From store");
    try std.testing.expect(cursor.record(0, .button, 42, label.?, .{}));

    var data: [512]u8 = undefined;
    var slots: [2]store.Blob = undefined;
    var s = store.Store.init(.{ .base = &data }, &slots);

    var keeper = [_]u8{0} ** 32;
    keeper[0] = 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper } };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui")).?, epoch).?;
    const req = object.Requirements{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };

    var canonical: [object.header_size + 128]u8 = undefined;
    const canonical_node = cursor.objectNode(&canonical, req, epoch).?;
    const object_id = s.putObject(app.id, canonical_node).?;
    const view = s.getObject(app.id, object_id).?;

    var nodes: [1]ui.Node = undefined;
    const root = try decodeView(view, &nodes);
    try std.testing.expectEqual(@as(u32, 42), root.stack.children[0].button.id);
    try std.testing.expectEqualStrings("From store", root.stack.children[0].button.label);
}

test "ui writer rejects invalid budgets and out of range records" {
    var too_small: [header_size]u8 = undefined;
    try std.testing.expect(Writer.init(&too_small, 1, 1, .column, 0, 0) == null);

    var raw: [header_size + record_size + 4]u8 = undefined;
    var writer = Writer.init(&raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(Writer.init(&raw, 0, 0, .column, 0, 0) == null);
    try std.testing.expect(Writer.init(&raw, 1, 2, .column, 0, 0) == null);

    const label = writer.string("test").?;
    try std.testing.expect(writer.string("x") == null);
    try std.testing.expect(!writer.record(1, .button, 1, label, .{}));
    try std.testing.expect(writer.record(0, .button, 1, label, .{}));
}

test "ui writer wraps payloads as owned canonical objects" {
    var raw_ui: [128]u8 = undefined;
    var writer = Writer.init(&raw_ui, 1, 1, .column, 0, 0).?;
    const label = writer.string("Owned").?;
    try std.testing.expect(writer.record(0, .button, 5, label, .{}));

    var keeper = [_]u8{0} ** 32;
    keeper[0] = 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper } };
    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
    const owner = object.Owner{
        .kind = .app,
        .node_id = [_]u8{1} ++ [_]u8{0} ** 31,
    };
    const envelope = object.Envelope{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .aes_gcm_256,
        .flags = 0,
        .key_id = [_]u8{2} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{3} ++ [_]u8{0} ** 31,
    };

    var canonical: [object.header_size + object.owner_size + object.envelope_size + 128]u8 = undefined;
    const canonical_node = writer.objectNodeOwned(&canonical, req, epoch, &.{owner}, &.{envelope}).?;
    const view = try object.View.decode(canonical_node);
    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expectEqual(@as(u16, 1), view.header.owner_count);
    try std.testing.expectEqual(@as(u16, 1), view.header.envelope_count);

    var nodes: [1]ui.Node = undefined;
    const root = try decodeView(view, &nodes);
    try std.testing.expectEqual(@as(u32, 5), root.stack.children[0].button.id);
    try std.testing.expectEqualStrings("Owned", root.stack.children[0].button.label);
}

pub const StringRef = struct {
    offset: u16 = 0,
    len: u16 = 0,
};

pub const Writer = struct {
    raw: []u8,
    node_count: u16,
    cursor: usize,

    pub fn init(raw: []u8, node_count: u16, root_count: u16, axis: ui.Axis, gap: u16, padding: u16) ?Writer {
        if (node_count == 0 or root_count == 0 or root_count > node_count) return null;
        const records_len = @as(usize, node_count) * record_size;
        if (raw.len < header_size + records_len) return null;

        @memset(raw, 0);
        @memcpy(raw[0..magic.len], magic);
        _ = bytes.store16(raw[8..10], 1);
        _ = bytes.store16(raw[10..12], switch (axis) {
            .column => 0,
            .row => 1,
        });
        _ = bytes.store16(raw[12..14], gap);
        _ = bytes.store16(raw[14..16], padding);
        _ = bytes.store16(raw[16..18], node_count);
        _ = bytes.store16(raw[18..20], root_count);
        return .{
            .raw = raw,
            .node_count = node_count,
            .cursor = header_size + @as(usize, node_count) * record_size,
        };
    }

    pub fn string(self: *Writer, value: []const u8) ?StringRef {
        const table_start = header_size + @as(usize, self.node_count) * record_size;
        const offset = self.cursor - table_start;
        if (offset > std.math.maxInt(u16) or value.len > std.math.maxInt(u16)) return null;
        if (value.len > self.raw.len - self.cursor) return null;
        @memcpy(self.raw[self.cursor..][0..value.len], value);
        self.cursor += value.len;
        return .{ .offset = @intCast(offset), .len = @intCast(value.len) };
    }

    pub fn record(self: Writer, index: usize, kind: RecordKind, id: u32, first: StringRef, second: StringRef) bool {
        if (index >= self.node_count) return false;
        const offset = header_size + index * record_size;
        const record_bytes = self.raw[offset..][0..record_size];
        _ = bytes.store16(record_bytes[0..2], @intFromEnum(kind));
        _ = bytes.store32(record_bytes[4..8], id);
        _ = bytes.store16(record_bytes[8..10], first.offset);
        _ = bytes.store16(record_bytes[10..12], first.len);
        _ = bytes.store16(record_bytes[12..14], second.offset);
        _ = bytes.store16(record_bytes[14..16], second.len);
        return true;
    }

    pub fn written(self: Writer) []const u8 {
        return self.raw[0..self.cursor];
    }

    pub fn objectNode(self: Writer, out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return self.objectNodeOwned(out, req, epoch, &.{}, &.{});
    }

    pub fn objectNodeOwned(self: Writer, out: []u8, req: object.Requirements, epoch: clock.Stamp, owners: []const object.Owner, envelopes: []const object.Envelope) ?[]u8 {
        const object_writer = object.NodeWriter{ .out = out };
        return object_writer.bytesNodeOwned(req, epoch, owners, envelopes, self.written()) catch return null;
    }
};

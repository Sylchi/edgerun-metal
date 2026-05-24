const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
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
            .button => .{ .button = .{ .id = id, .label = try stringRef(string_table, a, b) } },
            .input => .{ .input = .{ .id = id, .placeholder = try stringRef(string_table, a, b) } },
            .row_item => .{ .row_item = .{ .id = id, .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .badge => .{ .badge = .{ .label = try stringRef(string_table, a, b) } },
            .checkbox => .{ .checkbox = .{ .id = id, .label = try stringRef(string_table, a, b), .checked = decodeBool(c) orelse return error.Corrupt } },
            .switch_control => .{ .switch_control = .{ .id = id, .label = try stringRef(string_table, a, b), .checked = decodeBool(c) orelse return error.Corrupt } },
            .progress => .{ .progress = .{ .value = ui.decodeUnit(c) } },
            .slider => .{ .slider = .{ .id = id, .label = try stringRef(string_table, a, b), .value = ui.decodeUnit(c) } },
            .card => .{ .card = .{ .title = try stringRef(string_table, a, b), .detail = try stringRef(string_table, c, d) } },
            .avatar => .{ .avatar = .{ .label = try stringRef(string_table, a, b) } },
            .kbd => .{ .kbd = .{ .label = try stringRef(string_table, a, b) } },
            .separator => .{ .separator = {} },
            .textarea => .{ .textarea = .{ .id = id, .placeholder = try stringRef(string_table, a, b) } },
            .select => .{ .select = .{ .id = id, .label = try stringRef(string_table, a, b) } },
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
        @intFromEnum(RecordKind.textarea) => .textarea,
        @intFromEnum(RecordKind.select) => .select,
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
    try std.testing.expect(cursor.record(4, .button, 30, button.?, .{}));

    var nodes: [5]ui.Node = undefined;
    const root = try decodeBytes(cursor.written(), &nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

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

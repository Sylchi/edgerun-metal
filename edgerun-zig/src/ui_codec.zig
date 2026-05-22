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
        else => null,
    };
}

test "decode ui bytes into borrowed nodes and render hits" {
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

    const button_hit = ui.hitTest(scene.written(), 20, 160).?;
    try std.testing.expectEqual(@as(u32, 7), button_hit.slot);
    try std.testing.expectEqual(@as(u32, 30), button_hit.id);
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

test "decode ui view returned by storage" {
    const store = @import("store.zig");
    const identity = @import("identity.zig");

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
    const app = identity.Identity.init(.app, identity.Source.init(.hash, "ui").?, epoch).?;
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
        return object_writer.bytesNodeOwned(req, epoch, owners, envelopes, self.written());
    }
};

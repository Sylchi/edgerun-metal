const common = @import("../component_common.zig");
const clock = @import("../../clock.zig");
const codec = @import("../codec.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../core.zig");

const Error = common.Error;
pub const Writer = codec.Writer;

pub fn requirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .app_private,
        .portability = .app_portable,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .app_namespace,
        .access = .hot_memory_allowed,
    };
}

pub fn validateView(view: object.View) Error!void {
    if (view.header.kind != .bytes) return error.Corrupt;
    if (!std.meta.eql(view.header.requirements, requirements())) return error.Corrupt;
}

pub fn validateTreeView(view: object.View) Error!void {
    if (view.header.kind != .tree) return error.Corrupt;
    if (!std.meta.eql(view.header.requirements, requirements())) return error.Corrupt;
}

pub fn singleNode(view: object.View) Error!ui.Node {
    try validateView(view);
    var nodes: [1]ui.Node = undefined;
    const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
    return switch (root) {
        .stack => |stack| {
            if (stack.children.len != 1) return error.Corrupt;
            return stack.children[0];
        },
        else => error.UnsupportedComponent,
    };
}

pub fn nodeView(view: object.View, comptime tag: std.meta.Tag(ui.Node)) Error!@FieldType(ui.Node, @tagName(tag)) {
    const node = try singleNode(view);
    return switch (node) {
        tag => |payload| payload,
        else => error.UnsupportedComponent,
    };
}

pub fn emptyObject(kind: codec.RecordKind, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, 0, .{}, .{}, ui_out, object_out, epoch);
}

pub fn refObject(kind: codec.RecordKind, id: u32, value: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, id, .{}, value, ui_out, object_out, epoch);
}

pub fn oneStringObject(kind: codec.RecordKind, id: u32, value: []const u8, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!oneStringRecord(&writer, 0, kind, id, value)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn stringAndRefObject(kind: codec.RecordKind, id: u32, value: []const u8, b: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!stringAndRefRecord(&writer, 0, kind, id, value, b)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn twoStringObject(kind: codec.RecordKind, id: u32, first: []const u8, second: []const u8, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!twoStringRecord(&writer, 0, kind, id, first, second)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn emptyRecord(writer: *Writer, index: usize, kind: codec.RecordKind) bool {
    return writer.record(index, kind, 0, .{}, .{});
}

pub fn refRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: codec.StringRef) bool {
    return writer.record(index, kind, id, .{}, value);
}

pub fn oneStringRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: []const u8) bool {
    const a = writer.string(value) orelse return false;
    return writer.record(index, kind, id, a, .{});
}

pub fn stringAndRefRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, value: []const u8, b: codec.StringRef) bool {
    const a = writer.string(value) orelse return false;
    return writer.record(index, kind, id, a, b);
}

pub fn twoStringRecord(writer: *Writer, index: usize, kind: codec.RecordKind, id: u32, first: []const u8, second: []const u8) bool {
    const a = writer.string(first) orelse return false;
    const b = writer.string(second) orelse return false;
    return writer.record(index, kind, id, a, b);
}

pub fn boolRef(value: bool) codec.StringRef {
    return .{ .offset = if (value) 1 else 0, .len = 0 };
}

pub fn unitRef(value: f32) codec.StringRef {
    return .{ .offset = ui.encodeUnit(value), .len = 0 };
}

fn recordObject(kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    return recordObjectWithWriter(&writer, kind, id, a, b, object_out, epoch);
}

fn recordObjectWithWriter(writer: *Writer, kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    if (!writer.record(0, kind, id, a, b)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn singleWriter(ui_out: []u8) ?Writer {
    return codec.Writer.init(ui_out, 1, 1, .column, 0, 0);
}

pub fn writeObject(comptime Component: type, component: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeRecord(Component, &writer, 0, component)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn writeRecord(comptime Component: type, writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        inline else => |payload| payload.writeRecord(writer, index),
    };
}

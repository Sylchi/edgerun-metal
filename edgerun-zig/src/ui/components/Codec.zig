const common = @import("../../ui_component_common.zig");
const clock = @import("../../clock.zig");
const codec = @import("../../ui_codec.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../../ui.zig");

const Error = common.Error;
pub const Writer = codec.Writer;
pub const MarkdownIdText = struct {
    id: u32,
    text: []const u8,
};
pub const MarkdownCheckedText = struct {
    id: u32,
    checked: bool,
    text: []const u8,
};
pub const MarkdownIdTwoText = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
};

pub fn singleNode(view: object.View) Error!ui.Node {
    var nodes: [1]ui.Node = undefined;
    const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
    if (root.stack.children.len != 1) return error.Corrupt;
    return root.stack.children[0];
}

pub fn emptyObject(kind: codec.RecordKind, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, 0, .{}, .{}, ui_out, object_out, req, epoch);
}

pub fn refObject(kind: codec.RecordKind, id: u32, value: codec.StringRef, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    return recordObject(kind, id, .{}, value, ui_out, object_out, req, epoch);
}

pub fn oneStringObject(kind: codec.RecordKind, id: u32, value: []const u8, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!oneStringRecord(&writer, 0, kind, id, value)) return null;
    return writer.objectNode(object_out, req, epoch);
}

pub fn stringAndRefObject(kind: codec.RecordKind, id: u32, value: []const u8, b: codec.StringRef, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!stringAndRefRecord(&writer, 0, kind, id, value, b)) return null;
    return writer.objectNode(object_out, req, epoch);
}

pub fn twoStringObject(kind: codec.RecordKind, id: u32, first: []const u8, second: []const u8, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    if (!twoStringRecord(&writer, 0, kind, id, first, second)) return null;
    return writer.objectNode(object_out, req, epoch);
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

pub fn readIdTextDirectiveMarkdown(
    markdown: []const u8,
    directive: []const u8,
    id_prefix: []const u8,
    text_prefix: []const u8,
    text: *common.MarkdownTextArena,
) common.MarkdownError!MarkdownIdText {
    const body = try common.readMarkdownDirectiveBody(markdown, directive, id_prefix);
    const id_end = std.mem.indexOf(u8, body, text_prefix) orelse return error.InvalidMarkdown;
    const id = try common.parseMarkdownU32(body[0..id_end]);
    const value = try text.unescapeInline(body[id_end + text_prefix.len ..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .text = value };
}

pub fn readCheckedTextDirectiveMarkdown(
    markdown: []const u8,
    directive: []const u8,
    id_prefix: []const u8,
    text: *common.MarkdownTextArena,
) common.MarkdownError!MarkdownCheckedText {
    const body = try common.readMarkdownDirectiveBody(markdown, directive, id_prefix);
    const id_end = std.mem.indexOf(u8, body, "\nchecked: ") orelse return error.InvalidMarkdown;
    const id = try common.parseMarkdownU32(body[0..id_end]);
    const checked_start = id_end + "\nchecked: ".len;
    const checked_end_relative = std.mem.indexOf(u8, body[checked_start..], "\nlabel: ") orelse return error.InvalidMarkdown;
    const label_start = checked_start + checked_end_relative + "\nlabel: ".len;
    const checked = try common.parseMarkdownBool(body[checked_start .. checked_start + checked_end_relative]);
    const value = try text.unescapeInline(body[label_start..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .checked = checked, .text = value };
}

pub fn readIdTwoTextDirectiveMarkdown(
    markdown: []const u8,
    directive: []const u8,
    id_prefix: []const u8,
    first_prefix: []const u8,
    second_prefix: []const u8,
    text: *common.MarkdownTextArena,
) common.MarkdownError!MarkdownIdTwoText {
    const body = try common.readMarkdownDirectiveBody(markdown, directive, id_prefix);
    const id_end = std.mem.indexOf(u8, body, first_prefix) orelse return error.InvalidMarkdown;
    const id = try common.parseMarkdownU32(body[0..id_end]);
    const first_start = id_end + first_prefix.len;
    const first_end_relative = std.mem.indexOf(u8, body[first_start..], second_prefix) orelse return error.InvalidMarkdown;
    const second_start = first_start + first_end_relative + second_prefix.len;
    const first = try text.unescapeInline(body[first_start .. first_start + first_end_relative]);
    const second = try text.unescapeInline(body[second_start..]);
    if (first.len == 0 or second.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .first = first, .second = second };
}

fn recordObject(kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = singleWriter(ui_out) orelse return null;
    return recordObjectWithWriter(&writer, kind, id, a, b, object_out, req, epoch);
}

fn recordObjectWithWriter(writer: *Writer, kind: codec.RecordKind, id: u32, a: codec.StringRef, b: codec.StringRef, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    if (!writer.record(0, kind, id, a, b)) return null;
    return writer.objectNode(object_out, req, epoch);
}

fn singleWriter(ui_out: []u8) ?Writer {
    return codec.Writer.init(ui_out, 1, 1, .column, 0, 0);
}

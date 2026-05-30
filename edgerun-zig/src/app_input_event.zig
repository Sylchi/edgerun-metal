const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const object = @import("object.zig");

pub const Kind = enum(u32) {
    resize = 1,
    wheel = 2,
    pointer_move = 3,
    pointer_leave = 4,
    pointer_down = 5,
    pointer_up = 6,
    popstate = 7,
    hashchange = 8,
    key_down = 9,
    context_menu = 10,
    key_up = 11,
    input = 12,
    change = 13,
    click = 14,
    dbl_click = 15,
    visibility_change = 16,
    focus = 17,
    blur = 18,
    before_input = 19,
    composition_start = 20,
    composition_update = 21,
    composition_end = 22,
    touch_start = 23,
    touch_move = 24,
    touch_end = 25,
    touch_cancel = 26,
    drag_start = 27,
    drag_end = 28,
    drop = 29,
};

pub const Record = struct {
    kind: Kind,
    x: f32,
    y: f32,
    delta_y: f32,
    ctrl: u32,
    meta: u32,
    alt: u32,
    shift: u32,
    repeat: u32,
    key: []const u8,
    code: []const u8,
    input_type: []const u8,
    data: []const u8,
};

pub const header_bytes: usize = 36;
pub const kind_offset: usize = 0;
pub const x_offset: usize = 4;
pub const y_offset: usize = 8;
pub const delta_y_offset: usize = 12;
pub const flags_offset: usize = 16;
pub const key_len_offset: usize = 20;
pub const code_len_offset: usize = 24;
pub const input_type_len_offset: usize = 28;
pub const data_len_offset: usize = 32;

pub const flag_ctrl: u32 = 1 << 0;
pub const flag_meta: u32 = 1 << 1;
pub const flag_alt: u32 = 1 << 2;
pub const flag_shift: u32 = 1 << 3;
pub const flag_repeat: u32 = 1 << 4;

pub fn kindFromInt(value: u32) ?Kind {
    return switch (value) {
        @intFromEnum(Kind.resize) => .resize,
        @intFromEnum(Kind.wheel) => .wheel,
        @intFromEnum(Kind.pointer_move) => .pointer_move,
        @intFromEnum(Kind.pointer_leave) => .pointer_leave,
        @intFromEnum(Kind.pointer_down) => .pointer_down,
        @intFromEnum(Kind.pointer_up) => .pointer_up,
        @intFromEnum(Kind.popstate) => .popstate,
        @intFromEnum(Kind.hashchange) => .hashchange,
        @intFromEnum(Kind.key_down) => .key_down,
        @intFromEnum(Kind.context_menu) => .context_menu,
        @intFromEnum(Kind.key_up) => .key_up,
        @intFromEnum(Kind.input) => .input,
        @intFromEnum(Kind.change) => .change,
        @intFromEnum(Kind.click) => .click,
        @intFromEnum(Kind.dbl_click) => .dbl_click,
        @intFromEnum(Kind.visibility_change) => .visibility_change,
        @intFromEnum(Kind.focus) => .focus,
        @intFromEnum(Kind.blur) => .blur,
        @intFromEnum(Kind.before_input) => .before_input,
        @intFromEnum(Kind.composition_start) => .composition_start,
        @intFromEnum(Kind.composition_update) => .composition_update,
        @intFromEnum(Kind.composition_end) => .composition_end,
        @intFromEnum(Kind.touch_start) => .touch_start,
        @intFromEnum(Kind.touch_move) => .touch_move,
        @intFromEnum(Kind.touch_end) => .touch_end,
        @intFromEnum(Kind.touch_cancel) => .touch_cancel,
        @intFromEnum(Kind.drag_start) => .drag_start,
        @intFromEnum(Kind.drag_end) => .drag_end,
        @intFromEnum(Kind.drop) => .drop,
        else => null,
    };
}

pub fn parseBytes(envelope: []const u8) !Record {
    if (envelope.len < header_bytes) return error.BadInput;
    const kind = kindFromInt(loadU32(envelope, kind_offset) orelse return error.BadInput) orelse return error.UnknownInputEvent;
    const x = loadF32(envelope, x_offset) orelse return error.BadInput;
    const y = loadF32(envelope, y_offset) orelse return error.BadInput;
    const delta_y = loadF32(envelope, delta_y_offset) orelse return error.BadInput;
    const flags = loadU32(envelope, flags_offset) orelse return error.BadInput;
    const key_len: usize = @intCast(loadU32(envelope, key_len_offset) orelse return error.BadInput);
    const code_len: usize = @intCast(loadU32(envelope, code_len_offset) orelse return error.BadInput);
    const input_type_len: usize = @intCast(loadU32(envelope, input_type_len_offset) orelse return error.BadInput);
    const data_len: usize = @intCast(loadU32(envelope, data_len_offset) orelse return error.BadInput);
    var offset: usize = header_bytes;
    const key = nextBytes(envelope, &offset, key_len) orelse return error.BadInput;
    const code = nextBytes(envelope, &offset, code_len) orelse return error.BadInput;
    const input_type = nextBytes(envelope, &offset, input_type_len) orelse return error.BadInput;
    const data = nextBytes(envelope, &offset, data_len) orelse return error.BadInput;
    if (offset != envelope.len) return error.BadInput;
    return .{
        .kind = kind,
        .x = x,
        .y = y,
        .delta_y = delta_y,
        .ctrl = boolFlag(flags, flag_ctrl),
        .meta = boolFlag(flags, flag_meta),
        .alt = boolFlag(flags, flag_alt),
        .shift = boolFlag(flags, flag_shift),
        .repeat = boolFlag(flags, flag_repeat),
        .key = key,
        .code = code,
        .input_type = input_type,
        .data = data,
    };
}

pub fn writeBytes(out: []u8, kind: Kind, x: f32, y: f32, delta_y: f32, flags: u32, key: []const u8, code: []const u8, input_type: []const u8, data: []const u8) !usize {
    const len = header_bytes + key.len + code.len + input_type.len + data.len;
    if (len > out.len) return error.InputEventTooLarge;
    _ = bytes.store32(out[kind_offset..][0..4], @intFromEnum(kind));
    storeF32(out, x_offset, x);
    storeF32(out, y_offset, y);
    storeF32(out, delta_y_offset, delta_y);
    _ = bytes.store32(out[flags_offset..][0..4], flags);
    _ = bytes.store32(out[key_len_offset..][0..4], @intCast(key.len));
    _ = bytes.store32(out[code_len_offset..][0..4], @intCast(code.len));
    _ = bytes.store32(out[input_type_len_offset..][0..4], @intCast(input_type.len));
    _ = bytes.store32(out[data_len_offset..][0..4], @intCast(data.len));
    var offset: usize = header_bytes;
    @memcpy(out[offset..][0..key.len], key);
    offset += key.len;
    @memcpy(out[offset..][0..code.len], code);
    offset += code.len;
    @memcpy(out[offset..][0..input_type.len], input_type);
    offset += input_type.len;
    @memcpy(out[offset..][0..data.len], data);
    offset += data.len;
    return offset;
}

fn loadU32(envelope: []const u8, offset: usize) ?u32 {
    if (offset > envelope.len or 4 > envelope.len - offset) return null;
    return bytes.load32(envelope[offset..][0..4]);
}

fn loadF32(envelope: []const u8, offset: usize) ?f32 {
    return @as(f32, @bitCast(loadU32(envelope, offset) orelse return null));
}

fn nextBytes(envelope: []const u8, offset: *usize, len: usize) ?[]const u8 {
    if (offset.* > envelope.len or len > envelope.len - offset.*) return null;
    const out = envelope[offset.*..][0..len];
    offset.* += len;
    return out;
}

fn boolFlag(flags: u32, flag: u32) u32 {
    return if ((flags & flag) != 0) 1 else 0;
}

fn storeF32(out: []u8, offset: usize, value: f32) void {
    _ = bytes.store32(out[offset..][0..4], @as(u32, @bitCast(value)));
}

pub fn requirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .machine_bound,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .private,
        .access = .hot_memory_allowed,
    };
}

pub fn encodeObject(kind: Kind, x: f32, y: f32, delta_y: f32, flags: u32, key: []const u8, code: []const u8, input_type: []const u8, data: []const u8, epoch: clock.Stamp, out: []u8) ![]u8 {
    var body_buf: [2048]u8 = undefined;
    const body_len = try writeBytes(&body_buf, kind, x, y, delta_y, flags, key, code, input_type, data);
    return try (object.NodeWriter{ .out = out }).bytesNode(requirements(), epoch, body_buf[0..body_len]);
}

pub fn decodeObject(canonical: []const u8) !Record {
    const view = try object.View.decode(canonical);
    if (view.header.kind != .bytes) return error.BadInput;
    return try parseBytes(view.body);
}

test "input event decode object rejects non-bytes kind" {
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{0x69} ** 32 }, .tick = 1, .slot = 1, .epoch = 1, .era = 1 };
    var obj_buf: [512]u8 = undefined;
    const tree = try (object.NodeWriter{ .out = &obj_buf }).treeNode(requirements(), epoch, &.{});
    try std.testing.expectError(error.BadInput, decodeObject(tree));
}

test "input event object round trips" {
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{0x69} ** 32 }, .tick = 1, .slot = 1, .epoch = 1, .era = 1 };
    var object_buf: [2048]u8 = undefined;
    const canonical = try encodeObject(.pointer_move, 10.0, 20.0, 0.0, flag_ctrl | flag_shift, "", "", "", "", epoch, &object_buf);
    const record = try decodeObject(canonical);
    try std.testing.expectEqual(Kind.pointer_move, record.kind);
    try std.testing.expectEqual(@as(f32, 10.0), record.x);
    try std.testing.expectEqual(@as(f32, 20.0), record.y);
    try std.testing.expectEqual(@as(u32, 1), record.ctrl);
    try std.testing.expectEqual(@as(u32, 1), record.shift);
}

test "input event byte record round trips browser bridge fields" {
    var out: [128]u8 = undefined;
    const len = try writeBytes(&out, .before_input, 12.5, 24.25, -3.0, flag_ctrl | flag_shift, "A", "KeyA", "insertText", "x");
    const record = try parseBytes(out[0..len]);

    try std.testing.expectEqual(Kind.before_input, record.kind);
    try std.testing.expectEqual(@as(f32, 12.5), record.x);
    try std.testing.expectEqual(@as(f32, 24.25), record.y);
    try std.testing.expectEqual(@as(f32, -3.0), record.delta_y);
    try std.testing.expectEqual(@as(u32, 1), record.ctrl);
    try std.testing.expectEqual(@as(u32, 0), record.meta);
    try std.testing.expectEqual(@as(u32, 0), record.alt);
    try std.testing.expectEqual(@as(u32, 1), record.shift);
    try std.testing.expectEqualStrings("A", record.key);
    try std.testing.expectEqualStrings("KeyA", record.code);
    try std.testing.expectEqualStrings("insertText", record.input_type);
    try std.testing.expectEqualStrings("x", record.data);
}

test "input event byte record rejects trailing and unknown event bytes" {
    var out: [64]u8 = undefined;
    const len = try writeBytes(&out, .pointer_move, 1.0, 2.0, 0.0, 0, "", "", "", "");

    try std.testing.expectError(error.BadInput, parseBytes(out[0 .. len + 1]));
    _ = bytes.store32(out[kind_offset..][0..4], 9000);
    try std.testing.expectError(error.UnknownInputEvent, parseBytes(out[0..len]));
}

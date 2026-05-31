const std = @import("std");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const object = @import("../object.zig");

pub const body_magic = "ERFNTV3\n".*;
pub const header_size: usize = 48;
pub const glyph_record_size: usize = 20;
pub const kern_record_size: usize = 12;
pub const command_record_size: usize = 20;

pub const Error = error{ Corrupt, UnsupportedObject };

const op_move_to: u32 = 1;
const op_line_to: u32 = 2;
const op_quad_to: u32 = 3;
const op_close: u32 = 4;

pub const Point = struct { x: f32, y: f32 };
pub const Quadratic = struct { control: Point, end: Point };
pub const Command = union(enum) { move_to: Point, line_to: Point, quad_to: Quadratic, close };

pub const Metrics = struct {
    units_per_em: u16,
    ascender: f32,
    descender: f32,
    line_gap: f32,
    y_min: f32,
    y_max: f32,
};

pub const GlyphInfo = struct { glyph_id: u16, advance: f32, commands: []const Command };

pub const GlyphRecord = struct {
    codepoint: u21,
    glyph_id: u16,
    command_offset: u32,
    command_count: u32,
    advance: f32,
};

pub const KernRecord = struct { left_codepoint: u21, right_codepoint: u21, advance_adjust: f32 };

pub const Body = struct {
    metrics: Metrics,
    glyphs: []const GlyphRecord,
    kerns: []const KernRecord = &.{},
    commands: []const Command,

    pub fn glyphForCodepoint(self: Body, codepoint: u21) ?GlyphInfo {
        for (self.glyphs) |glyph| {
            if (glyph.codepoint == codepoint) {
                const start: usize = @intCast(glyph.command_offset);
                const end = start + @as(usize, @intCast(glyph.command_count));
                if (end > self.commands.len) return null;
                return .{ .glyph_id = glyph.glyph_id, .advance = glyph.advance, .commands = self.commands[start..end] };
            }
        }
        return null;
    }

    pub fn kern(self: Body, left: u21, right: u21) f32 {
        for (self.kerns) |record| if (record.left_codepoint == left and record.right_codepoint == right) return record.advance_adjust;
        return 0;
    }
};

pub fn serializedLen(glyph_count: usize, kern_count: usize, command_count: usize) ?usize {
    const glyph_bytes = std.math.mul(usize, glyph_count, glyph_record_size) catch return null;
    const kern_bytes = std.math.mul(usize, kern_count, kern_record_size) catch return null;
    const command_bytes = std.math.mul(usize, command_count, command_record_size) catch return null;
    return std.math.add(usize, header_size, glyph_bytes + kern_bytes + command_bytes) catch null;
}

pub fn encodeBody(out: []u8, body_val: Body) ?[]const u8 {
    if (body_val.glyphs.len > ~@as(u32, 0)) return null;
    if (body_val.kerns.len > ~@as(u32, 0)) return null;
    if (body_val.commands.len > ~@as(u32, 0)) return null;
    const total = serializedLen(body_val.glyphs.len, body_val.kerns.len, body_val.commands.len) orelse return null;
    if (out.len < total) return null;

    @memcpy(out[0..body_magic.len], &body_magic);
    if (!bytes.store16(out[8..10], body_val.metrics.units_per_em)) return null;
    if (!bytes.store16(out[10..12], 0)) return null;
    if (!bytes.store32(out[12..16], @intCast(body_val.glyphs.len))) return null;
    if (!bytes.store32(out[16..20], @intCast(body_val.commands.len))) return null;
    if (!bytes.store32(out[20..24], @intCast(body_val.kerns.len))) return null;
    storeF32(out[24..28], body_val.metrics.ascender);
    storeF32(out[28..32], body_val.metrics.descender);
    storeF32(out[32..36], body_val.metrics.line_gap);
    storeF32(out[36..40], body_val.metrics.y_min);
    storeF32(out[40..44], body_val.metrics.y_max);
    _ = bytes.store32(out[44..48], 0);

    var offset: usize = header_size;
    for (body_val.glyphs) |glyph| {
        if (!encodeGlyphRecord(out[offset .. offset + glyph_record_size], glyph)) return null;
        offset += glyph_record_size;
    }
    for (body_val.kerns) |kern_record| {
        if (!encodeKernRecord(out[offset .. offset + kern_record_size], kern_record)) return null;
        offset += kern_record_size;
    }
    for (body_val.commands) |command| {
        encodeCommandRecord(out[offset .. offset + command_record_size], command);
        offset += command_record_size;
    }
    return out[0..total];
}

pub fn decodeObject(canonical: []const u8, glyphs_out: []GlyphRecord, kerns_out: []KernRecord, commands_out: []Command) Error!Body {
    const view = object.View.decode(canonical) catch return error.Corrupt;
    return decodeView(view, glyphs_out, kerns_out, commands_out);
}

pub fn decodeView(view: object.View, glyphs_out: []GlyphRecord, kerns_out: []KernRecord, commands_out: []Command) Error!Body {
    if (view.header.kind != .bytes) return error.UnsupportedObject;
    return decodeBody(view.body, glyphs_out, kerns_out, commands_out) orelse return error.Corrupt;
}

pub fn objectNode(body_out: []u8, object_out: []u8, body_val: Body, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    return objectNodeOwned(body_out, object_out, body_val, req, epoch, &.{}, &.{});
}

pub fn objectNodeOwned(body_out: []u8, object_out: []u8, body_val: Body, req: object.Requirements, epoch: clock.Stamp, owners: []const object.Owner, envelopes: []const object.Envelope) ?[]u8 {
    const encoded = encodeBody(body_out, body_val) orelse return null;
    return (object.NodeWriter{ .out = object_out }).bytesNodeOwned(req, epoch, owners, envelopes, encoded) catch return null;
}

pub fn decodeBody(bytes_in: []const u8, glyphs_out: []GlyphRecord, kerns_out: []KernRecord, commands_out: []Command) ?Body {
    if (bytes_in.len < header_size) return null;
    if (!bytes.eql(bytes_in[0..body_magic.len], &body_magic)) return null;
    const glyph_count: usize = @intCast(bytes.load32(bytes_in[12..16]) orelse return null);
    const command_count: usize = @intCast(bytes.load32(bytes_in[16..20]) orelse return null);
    const kern_count: usize = @intCast(bytes.load32(bytes_in[20..24]) orelse return null);
    if (glyph_count > glyphs_out.len or kern_count > kerns_out.len or command_count > commands_out.len) return null;
    const total = serializedLen(glyph_count, kern_count, command_count) orelse return null;
    if (bytes_in.len != total) return null;

    const metrics = Metrics{
        .units_per_em = bytes.load16(bytes_in[8..10]) orelse return null,
        .ascender = loadF32(bytes_in[24..28]) orelse return null,
        .descender = loadF32(bytes_in[28..32]) orelse return null,
        .line_gap = loadF32(bytes_in[32..36]) orelse return null,
        .y_min = loadF32(bytes_in[36..40]) orelse return null,
        .y_max = loadF32(bytes_in[40..44]) orelse return null,
    };
    if (metrics.units_per_em == 0) return null;
    if ((bytes.load16(bytes_in[10..12]) orelse return null) != 0) return null;
    if ((bytes.load32(bytes_in[44..48]) orelse return null) != 0) return null;

    var offset: usize = header_size;
    var index: usize = 0;
    while (index < glyph_count) : (index += 1) {
        const glyph = decodeGlyphRecord(bytes_in[offset .. offset + glyph_record_size]) orelse return null;
        const end = @as(usize, @intCast(glyph.command_offset)) + @as(usize, @intCast(glyph.command_count));
        if (end > command_count) return null;
        glyphs_out[index] = glyph;
        offset += glyph_record_size;
    }
    index = 0;
    while (index < kern_count) : (index += 1) {
        kerns_out[index] = decodeKernRecord(bytes_in[offset .. offset + kern_record_size]) orelse return null;
        offset += kern_record_size;
    }
    index = 0;
    while (index < command_count) : (index += 1) {
        commands_out[index] = decodeCommandRecord(bytes_in[offset .. offset + command_record_size]) orelse return null;
        offset += command_record_size;
    }

    return .{ .metrics = metrics, .glyphs = glyphs_out[0..glyph_count], .kerns = kerns_out[0..kern_count], .commands = commands_out[0..command_count] };
}

fn storeF32(out: []u8, value: f32) void {
    _ = bytes.store32(out, @as(u32, @bitCast(value)));
}
fn loadF32(in: []const u8) ?f32 {
    return @as(f32, @bitCast(bytes.load32(in) orelse return null));
}

fn encodeGlyphRecord(out: []u8, glyph: GlyphRecord) bool {
    if (out.len < glyph_record_size) return false;
    if (!bytes.store32(out[0..4], glyph.codepoint)) return false;
    if (!bytes.store16(out[4..6], glyph.glyph_id)) return false;
    if (!bytes.store16(out[6..8], 0)) return false;
    if (!bytes.store32(out[8..12], glyph.command_offset)) return false;
    if (!bytes.store32(out[12..16], glyph.command_count)) return false;
    storeF32(out[16..20], glyph.advance);
    return true;
}

fn decodeGlyphRecord(in: []const u8) ?GlyphRecord {
    if (in.len < glyph_record_size) return null;
    const codepoint = bytes.load32(in[0..4]) orelse return null;
    if (codepoint > std.math.maxInt(u21)) return null;
    if ((bytes.load16(in[6..8]) orelse return null) != 0) return null;
    return .{ .codepoint = @intCast(codepoint), .glyph_id = bytes.load16(in[4..6]) orelse return null, .command_offset = bytes.load32(in[8..12]) orelse return null, .command_count = bytes.load32(in[12..16]) orelse return null, .advance = loadF32(in[16..20]) orelse return null };
}

fn encodeKernRecord(out: []u8, kern_record: KernRecord) bool {
    if (out.len < kern_record_size) return false;
    if (!bytes.store32(out[0..4], kern_record.left_codepoint)) return false;
    if (!bytes.store32(out[4..8], kern_record.right_codepoint)) return false;
    storeF32(out[8..12], kern_record.advance_adjust);
    return true;
}

fn decodeKernRecord(in: []const u8) ?KernRecord {
    if (in.len < kern_record_size) return null;
    const left = bytes.load32(in[0..4]) orelse return null;
    const right = bytes.load32(in[4..8]) orelse return null;
    if (left > std.math.maxInt(u21) or right > std.math.maxInt(u21)) return null;
    return .{ .left_codepoint = @intCast(left), .right_codepoint = @intCast(right), .advance_adjust = loadF32(in[8..12]) orelse return null };
}

fn encodeCommandRecord(out: []u8, command: Command) void {
    bytes.zero(out[0..command_record_size]);
    switch (command) {
        .move_to => |p| {
            _ = bytes.store32(out[0..4], op_move_to);
            storeF32(out[4..8], p.x);
            storeF32(out[8..12], p.y);
        },
        .line_to => |p| {
            _ = bytes.store32(out[0..4], op_line_to);
            storeF32(out[4..8], p.x);
            storeF32(out[8..12], p.y);
        },
        .quad_to => |q| {
            _ = bytes.store32(out[0..4], op_quad_to);
            storeF32(out[4..8], q.end.x);
            storeF32(out[8..12], q.end.y);
            storeF32(out[12..16], q.control.x);
            storeF32(out[16..20], q.control.y);
        },
        .close => _ = bytes.store32(out[0..4], op_close),
    }
}

fn decodeCommandRecord(in: []const u8) ?Command {
    if (in.len < command_record_size) return null;
    return switch (bytes.load32(in[0..4]) orelse return null) {
        op_move_to => .{ .move_to = .{ .x = loadF32(in[4..8]) orelse return null, .y = loadF32(in[8..12]) orelse return null } },
        op_line_to => .{ .line_to = .{ .x = loadF32(in[4..8]) orelse return null, .y = loadF32(in[8..12]) orelse return null } },
        op_quad_to => .{ .quad_to = .{ .control = .{ .x = loadF32(in[12..16]) orelse return null, .y = loadF32(in[16..20]) orelse return null }, .end = .{ .x = loadF32(in[4..8]) orelse return null, .y = loadF32(in[8..12]) orelse return null } } },
        op_close => if (bytes.zeroed(in[4..20])) .close else null,
        else => null,
    };
}

test "font vector body round trips widened counts" {
    const commands = [_]Command{ .{ .move_to = .{ .x = 0, .y = 0 } }, .close };
    const glyphs = [_]GlyphRecord{.{ .codepoint = 'A', .glyph_id = 4, .command_offset = 0, .command_count = commands.len, .advance = 10 }};
    const body_val = Body{ .metrics = .{ .units_per_em = 1000, .ascender = 800, .descender = -200, .line_gap = 0, .y_min = -200, .y_max = 1000 }, .glyphs = &glyphs, .commands = &commands };
    var encoded: [header_size + glyph_record_size + command_record_size * commands.len]u8 = undefined;
    const out = encodeBody(&encoded, body_val).?;
    var decoded_glyphs: [1]GlyphRecord = undefined;
    var decoded_kerns: [0]KernRecord = .{};
    var decoded_commands: [commands.len]Command = undefined;
    const decoded = decodeBody(out, &decoded_glyphs, &decoded_kerns, &decoded_commands).?;
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(decoded.glyphs.len)));
    try std.testing.expectEqual(@as(u32, commands.len), decoded.glyphs[0].command_count);
}

pub const atlas_width: usize = 1024;
pub const atlas_height: usize = 1024;
pub const atlas_bytes: usize = atlas_width * atlas_height;
pub const replacement_codepoint: u21 = std.unicode.replacement_character;

pub const Weight = enum(u8) {
    regular,
    semibold,
    bold,
};

/// Canonical EdgeRun vector font objects.
/// Body starts at byte 148 (object.header_size) for bytes-kind objects with no owners/envelopes/children.
const regular_obj = @embedFile("../assets/font_regular.obj");
const semibold_obj = @embedFile("../assets/font_semibold.obj");
const bold_obj = @embedFile("../assets/font_bold.obj");

const object_body_offset = 148;

fn readCount(comptime obj: []const u8, comptime offset: usize) usize {
    const raw = obj[object_body_offset..];
    return @intCast((bytes.load32(raw[offset..][0..4]) orelse @compileError("bad font body")));
}

pub const regular_counts = .{
    .glyphs = readCount(regular_obj, 12),
    .commands = readCount(regular_obj, 16),
    .kerns = readCount(regular_obj, 20),
};
pub const semibold_counts = .{
    .glyphs = readCount(semibold_obj, 12),
    .commands = readCount(semibold_obj, 16),
    .kerns = readCount(semibold_obj, 20),
};
pub const bold_counts = .{
    .glyphs = readCount(bold_obj, 12),
    .commands = readCount(bold_obj, 16),
    .kerns = readCount(bold_obj, 20),
};

pub const codepoint_count: usize = regular_counts.glyphs;

const max_glyphs = blk: {
    break :blk @max(@max(regular_counts.glyphs, semibold_counts.glyphs), bold_counts.glyphs);
};
const max_kerns = blk: {
    break :blk @max(@max(regular_counts.kerns, semibold_counts.kerns), bold_counts.kerns);
};
const builtin_max_commands = blk: {
    break :blk @max(@max(regular_counts.commands, semibold_counts.commands), bold_counts.commands);
};

const Storage = struct {
    metrics: Metrics,
    glyphs: [max_glyphs]GlyphRecord,
    kerns: [max_kerns]KernRecord,
    commands: [builtin_max_commands]Command,
    glyph_count: usize,
    kern_count: usize,
    command_count: usize,
    decoded: bool,
};

var regular_storage: Storage = .{
    .glyphs = undefined,
    .kerns = undefined,
    .commands = undefined,
    .glyph_count = 0,
    .kern_count = 0,
    .command_count = 0,
    .decoded = false,
    .metrics = undefined,
};
var semibold_storage: Storage = .{
    .glyphs = undefined,
    .kerns = undefined,
    .commands = undefined,
    .glyph_count = 0,
    .kern_count = 0,
    .command_count = 0,
    .decoded = false,
    .metrics = undefined,
};
var bold_storage: Storage = .{
    .glyphs = undefined,
    .kerns = undefined,
    .commands = undefined,
    .glyph_count = 0,
    .kern_count = 0,
    .command_count = 0,
    .decoded = false,
    .metrics = undefined,
};

fn ensureWeight(weight: Weight) void {
    const storage = switch (weight) {
        .regular => &regular_storage,
        .semibold => &semibold_storage,
        .bold => &bold_storage,
    };
    if (!storage.decoded) {
        const obj = switch (weight) {
            .regular => regular_obj,
            .semibold => semibold_obj,
            .bold => bold_obj,
        };
        const raw = obj[object_body_offset..];
        const decoded = decodeBody(raw, &storage.glyphs, &storage.kerns, &storage.commands) orelse @panic("built-in font body decode failed");
        storage.metrics = decoded.metrics;
        storage.glyph_count = decoded.glyphs.len;
        storage.kern_count = decoded.kerns.len;
        storage.command_count = decoded.commands.len;
        storage.decoded = true;
    }
}

pub fn body(weight: Weight) Body {
    ensureWeight(weight);
    const storage = switch (weight) {
        .regular => &regular_storage,
        .semibold => &semibold_storage,
        .bold => &bold_storage,
    };
    return .{
        .metrics = storage.metrics,
        .glyphs = storage.glyphs[0..storage.glyph_count],
        .kerns = storage.kerns[0..storage.kern_count],
        .commands = storage.commands[0..storage.command_count],
    };
}

pub fn weightValue(weight: Weight) f32 {
    return switch (weight) {
        .regular => 400.0,
        .semibold => 600.0,
        .bold => 700.0,
    };
}

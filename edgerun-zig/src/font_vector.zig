const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const object = @import("object.zig");
const varfont = @import("varfont.zig");

pub const default_weight: f32 = 400.0;

pub const max_commands = varfont.max_contour_points;
pub const body_magic = "ERFNTV3\n".*;
pub const header_size: usize = 48;
pub const glyph_record_size: usize = 20;
pub const kern_record_size: usize = 12;
pub const command_record_size: usize = 20;

pub const Error = error{ Corrupt, UnsupportedObject };

pub const CompileError = varfont.Error || error{
    DuplicateCodepoint,
    GlyphCommandBudgetExceeded,
    GlyphRecordBudgetExceeded,
    KernRecordBudgetExceeded,
};

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

pub const FixedFace = struct {
    face: varfont.Face,
    axis_values: [varfont.max_axes]f32,

    pub fn geistDefault() varfont.Error!FixedFace {
        const face = try varfont.Face.geist();
        return .{ .face = face, .axis_values = face.fixedAxisValues("wght", default_weight) };
    }

    pub fn metrics(self: FixedFace) Metrics {
        const value = self.face.metrics(@floatFromInt(self.face.units_per_em));
        return .{ .units_per_em = value.units_per_em, .ascender = value.ascender, .descender = value.descender, .line_gap = value.line_gap, .y_min = value.y_min, .y_max = value.y_max };
    }

    pub fn glyphId(self: FixedFace, codepoint: u21) u16 { return self.face.glyphId(codepoint); }
    pub fn advance(self: FixedFace, glyph_id: u16, px_size: f32) f32 { return self.face.advance(glyph_id, px_size); }
    pub fn kern(self: FixedFace, left: u16, right: u16, px_size: f32) f32 { return self.face.kern(left, right, px_size); }

    pub fn glyphPath(self: FixedFace, glyph_id: u16, out: []Command) varfont.Error![]const Command {
        var points: [varfont.max_points]varfont.Point = undefined;
        var contour_ends: [varfont.max_contours]u16 = undefined;
        const outline = try self.face.outline(glyph_id, self.axis_values, &points, &contour_ends);
        return emitGlyphPath(points[0..outline.points], contour_ends[0..outline.contours], out);
    }
};

pub const Counts = struct { glyphs: usize, kerns: usize, commands: usize };

pub fn countCodepoints(face: FixedFace, codepoints: []const u21) CompileError!Counts {
    const metrics = face.metrics();
    const design_size: f32 = @floatFromInt(metrics.units_per_em);
    var tmp: [max_commands]Command = undefined;
    var commands: usize = 0;
    var kerns: usize = 0;

    for (codepoints, 0..) |codepoint, i| {
        if (containsCodepoint(codepoints[0..i], codepoint)) return error.DuplicateCodepoint;
        const path = try face.glyphPath(face.glyphId(codepoint), &tmp);
        commands += path.len;
    }

    for (codepoints) |left_cp| {
        const left_id = face.glyphId(left_cp);
        for (codepoints) |right_cp| {
            const right_id = face.glyphId(right_cp);
            if (face.kern(left_id, right_id, design_size) != 0) kerns += 1;
        }
    }

    return .{ .glyphs = codepoints.len, .kerns = kerns, .commands = commands };
}

pub fn compileCodepoints(face: FixedFace, codepoints: []const u21, glyphs_out: []GlyphRecord, kerns_out: []KernRecord, commands_out: []Command) CompileError!Body {
    if (codepoints.len > glyphs_out.len) return error.GlyphRecordBudgetExceeded;
    const metrics = face.metrics();
    const design_size: f32 = @floatFromInt(metrics.units_per_em);
    var command_count: usize = 0;

    for (codepoints, 0..) |codepoint, glyph_index| {
        if (containsCodepoint(codepoints[0..glyph_index], codepoint)) return error.DuplicateCodepoint;
        const glyph_id = face.glyphId(codepoint);
        const path = try face.glyphPath(glyph_id, commands_out[command_count..]);
        const start = command_count;
        command_count += path.len;
        glyphs_out[glyph_index] = .{ .codepoint = codepoint, .glyph_id = glyph_id, .command_offset = @intCast(start), .command_count = @intCast(path.len), .advance = face.advance(glyph_id, design_size) };
    }

    var kern_count: usize = 0;
    for (glyphs_out[0..codepoints.len]) |left| {
        for (glyphs_out[0..codepoints.len]) |right| {
            const adjust = face.kern(left.glyph_id, right.glyph_id, design_size);
            if (adjust == 0) continue;
            if (kern_count >= kerns_out.len) return error.KernRecordBudgetExceeded;
            kerns_out[kern_count] = .{ .left_codepoint = left.codepoint, .right_codepoint = right.codepoint, .advance_adjust = adjust };
            kern_count += 1;
        }
    }

    return .{ .metrics = metrics, .glyphs = glyphs_out[0..codepoints.len], .kerns = kerns_out[0..kern_count], .commands = commands_out[0..command_count] };
}

pub fn emitGlyphPath(points: []const varfont.Point, contour_ends: []const u16, out: []Command) varfont.Error![]const Command {
    var count: usize = 0;
    var start: usize = 0;
    for (contour_ends) |end_u16| {
        const end = @as(usize, end_u16);
        if (end >= points.len or end < start) return error.InvalidFont;
        try emitContour(points[start .. end + 1], out, &count);
        start = end + 1;
    }
    return out[0..count];
}

pub fn serializedLen(glyph_count: usize, kern_count: usize, command_count: usize) ?usize {
    const glyph_bytes = std.math.mul(usize, glyph_count, glyph_record_size) catch return null;
    const kern_bytes = std.math.mul(usize, kern_count, kern_record_size) catch return null;
    const command_bytes = std.math.mul(usize, command_count, command_record_size) catch return null;
    return std.math.add(usize, header_size, glyph_bytes + kern_bytes + command_bytes) catch null;
}

pub fn encodeBody(out: []u8, body: Body) ?[]const u8 {
    if (body.glyphs.len > std.math.maxInt(u32)) return null;
    if (body.kerns.len > std.math.maxInt(u32)) return null;
    if (body.commands.len > std.math.maxInt(u32)) return null;
    const total = serializedLen(body.glyphs.len, body.kerns.len, body.commands.len) orelse return null;
    if (out.len < total) return null;

    @memcpy(out[0..body_magic.len], &body_magic);
    if (!bytes.store16(out[8..10], body.metrics.units_per_em)) return null;
    if (!bytes.store16(out[10..12], 0)) return null;
    if (!bytes.store32(out[12..16], @intCast(body.glyphs.len))) return null;
    if (!bytes.store32(out[16..20], @intCast(body.commands.len))) return null;
    if (!bytes.store32(out[20..24], @intCast(body.kerns.len))) return null;
    storeF32(out[24..28], body.metrics.ascender);
    storeF32(out[28..32], body.metrics.descender);
    storeF32(out[32..36], body.metrics.line_gap);
    storeF32(out[36..40], body.metrics.y_min);
    storeF32(out[40..44], body.metrics.y_max);
    _ = bytes.store32(out[44..48], 0);

    var offset: usize = header_size;
    for (body.glyphs) |glyph| { if (!encodeGlyphRecord(out[offset .. offset + glyph_record_size], glyph)) return null; offset += glyph_record_size; }
    for (body.kerns) |kern_record| { if (!encodeKernRecord(out[offset .. offset + kern_record_size], kern_record)) return null; offset += kern_record_size; }
    for (body.commands) |command| { encodeCommandRecord(out[offset .. offset + command_record_size], command); offset += command_record_size; }
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

pub fn objectNode(body_out: []u8, object_out: []u8, body: Body, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    return objectNodeOwned(body_out, object_out, body, req, epoch, &.{}, &.{});
}

pub fn objectNodeOwned(body_out: []u8, object_out: []u8, body: Body, req: object.Requirements, epoch: clock.Stamp, owners: []const object.Owner, envelopes: []const object.Envelope) ?[]u8 {
    const encoded = encodeBody(body_out, body) orelse return null;
    return (object.NodeWriter{ .out = object_out }).bytesNodeOwned(req, epoch, owners, envelopes, encoded) catch return null;
}

pub fn decodeBody(bytes_in: []const u8, glyphs_out: []GlyphRecord, kerns_out: []KernRecord, commands_out: []Command) ?Body {
    if (bytes_in.len < header_size) return null;
    if (!bytes.eql(bytes_in[0..body_magic.len], &body_magic)) return null;
    const glyph_count = bytes.load32(bytes_in[12..16]) orelse return null;
    const command_count = bytes.load32(bytes_in[16..20]) orelse return null;
    const kern_count = bytes.load32(bytes_in[20..24]) orelse return null;
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
        const end = @as(usize, glyph.command_offset) + @as(usize, glyph.command_count);
        if (end > command_count) return null;
        glyphs_out[index] = glyph;
        offset += glyph_record_size;
    }
    index = 0;
    while (index < kern_count) : (index += 1) { kerns_out[index] = decodeKernRecord(bytes_in[offset .. offset + kern_record_size]) orelse return null; offset += kern_record_size; }
    index = 0;
    while (index < command_count) : (index += 1) { commands_out[index] = decodeCommandRecord(bytes_in[offset .. offset + command_record_size]) orelse return null; offset += command_record_size; }

    return .{ .metrics = metrics, .glyphs = glyphs_out[0..glyph_count], .kerns = kerns_out[0..kern_count], .commands = commands_out[0..command_count] };
}

fn storeF32(out: []u8, value: f32) void { _ = bytes.store32(out, @as(u32, @bitCast(value))); }
fn loadF32(in: []const u8) ?f32 { return @as(f32, @bitCast(bytes.load32(in) orelse return null)); }

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
        .move_to => |p| { _ = bytes.store32(out[0..4], op_move_to); storeF32(out[4..8], p.x); storeF32(out[8..12], p.y); },
        .line_to => |p| { _ = bytes.store32(out[0..4], op_line_to); storeF32(out[4..8], p.x); storeF32(out[8..12], p.y); },
        .quad_to => |q| { _ = bytes.store32(out[0..4], op_quad_to); storeF32(out[4..8], q.end.x); storeF32(out[8..12], q.end.y); storeF32(out[12..16], q.control.x); storeF32(out[16..20], q.control.y); },
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

fn containsCodepoint(haystack: []const u21, needle: u21) bool {
    for (haystack) |value| if (value == needle) return true;
    return false;
}

fn emitContour(raw: []const varfont.Point, out: []Command, count: *usize) varfont.Error!void {
    if (raw.len == 0) return error.InvalidFont;
    const start = contourStart(raw);
    try appendCommand(out, count, .{ .move_to = point(start) });
    var i: usize = if (raw[0].on_curve) 1 else 0;
    while (i < raw.len) {
        const p = raw[i];
        if (p.on_curve) { try appendCommand(out, count, .{ .line_to = point(p) }); i += 1; continue; }
        const next = raw[(i + 1) % raw.len];
        const end = if (next.on_curve) next else midpoint(p, next);
        try appendCommand(out, count, .{ .quad_to = .{ .control = point(p), .end = point(end) } });
        i += if (next.on_curve) 2 else 1;
    }
    try appendCommand(out, count, .close);
}

fn contourStart(raw: []const varfont.Point) varfont.Point {
    if (raw[0].on_curve) return raw[0];
    if (raw[raw.len - 1].on_curve) return raw[raw.len - 1];
    return midpoint(raw[raw.len - 1], raw[0]);
}

fn appendCommand(out: []Command, count: *usize, command: Command) varfont.Error!void {
    if (count.* >= out.len) return error.GlyphPointBudgetExceeded;
    out[count.*] = command;
    count.* += 1;
}

fn point(value: varfont.Point) Point { return .{ .x = value.x, .y = value.y }; }
fn midpoint(a: varfont.Point, b: varfont.Point) varfont.Point { return .{ .x = (a.x + b.x) * 0.5, .y = (a.y + b.y) * 0.5, .on_curve = true }; }

test "font vector body round trips widened counts" {
    const commands = [_]Command{ .{ .move_to = .{ .x = 0, .y = 0 } }, .close };
    const glyphs = [_]GlyphRecord{.{ .codepoint = 'A', .glyph_id = 4, .command_offset = 0, .command_count = commands.len, .advance = 10 }};
    const body = Body{ .metrics = .{ .units_per_em = 1000, .ascender = 800, .descender = -200, .line_gap = 0, .y_min = -200, .y_max = 1000 }, .glyphs = &glyphs, .commands = &commands };
    var encoded: [header_size + glyph_record_size + command_record_size * commands.len]u8 = undefined;
    const out = encodeBody(&encoded, body).?;
    var decoded_glyphs: [1]GlyphRecord = undefined;
    var decoded_kerns: [0]KernRecord = .{};
    var decoded_commands: [commands.len]Command = undefined;
    const decoded = decodeBody(out, &decoded_glyphs, &decoded_kerns, &decoded_commands).?;
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(decoded.glyphs.len)));
    try std.testing.expectEqual(@as(u32, commands.len), decoded.glyphs[0].command_count);
}

const std = @import("std");
const font_vector = @import("font_vector.zig");

pub const replacement_codepoint: u21 = std.unicode.replacement_character;

const source_face = font_vector.FixedFace.geistDefault() catch @compileError("failed to load source font for built-in vector font");

pub const codepoint_count: usize = countCoveredCodepoints(source_face);
pub const codepoints: [codepoint_count]u21 = buildCodepoints(source_face);
pub const counts: font_vector.Counts = countExactVectorStorage(source_face, &codepoints);

pub const Compiled = CompiledFont(counts.glyphs, counts.kerns, counts.commands);
pub const compiled: Compiled = compileBuiltIn(source_face, &codepoints, counts);

pub fn CompiledFont(comptime glyph_count: usize, comptime kern_count: usize, comptime command_count: usize) type {
    return struct {
        metrics: font_vector.Metrics,
        glyphs: [glyph_count]font_vector.GlyphRecord,
        kerns: [kern_count]font_vector.KernRecord,
        commands: [command_count]font_vector.Command,

        pub fn body(self: *const @This()) font_vector.Body {
            return .{ .metrics = self.metrics, .glyphs = &self.glyphs, .kerns = &self.kerns, .commands = &self.commands };
        }
    };
}

fn countExactVectorStorage(comptime face: font_vector.FixedFace, comptime cps: []const u21) font_vector.Counts {
    @setEvalBranchQuota(400_000_000);
    return font_vector.countCodepoints(face, cps) catch @compileError("failed to count built-in vector font");
}

fn compileBuiltIn(comptime face: font_vector.FixedFace, comptime cps: []const u21, comptime expected: font_vector.Counts) CompiledFont(expected.glyphs, expected.kerns, expected.commands) {
    @setEvalBranchQuota(400_000_000);
    var glyphs: [expected.glyphs]font_vector.GlyphRecord = undefined;
    var kerns: [expected.kerns]font_vector.KernRecord = undefined;
    var commands: [expected.commands]font_vector.Command = undefined;
    const body = font_vector.compileCodepoints(face, cps, &glyphs, &kerns, &commands) catch @compileError("failed to compile built-in vector font");
    if (body.glyphs.len != expected.glyphs) @compileError("built-in vector font glyph count drifted");
    if (body.kerns.len != expected.kerns) @compileError("built-in vector font kern count drifted");
    if (body.commands.len != expected.commands) @compileError("built-in vector font command count drifted");
    return .{ .metrics = body.metrics, .glyphs = glyphs, .kerns = kerns, .commands = commands };
}

fn countCoveredCodepoints(comptime face: font_vector.FixedFace) usize {
    @setEvalBranchQuota(20_000_000);
    return switch (face.face.cmap_format) {
        4 => countFormat4(face),
        12 => countFormat12(face),
        else => @compileError("unsupported cmap format for built-in vector font"),
    };
}

fn buildCodepoints(comptime face: font_vector.FixedFace) [codepoint_count]u21 {
    @setEvalBranchQuota(20_000_000);
    var out: [codepoint_count]u21 = undefined;
    var count: usize = 0;
    switch (face.face.cmap_format) {
        4 => fillFormat4(face, &out, &count),
        12 => fillFormat12(face, &out, &count),
        else => @compileError("unsupported cmap format for built-in vector font"),
    }
    if (count != codepoint_count) @compileError("source font coverage changed during vector compilation");
    return out;
}

fn countFormat4(comptime face: font_vector.FixedFace) usize {
    var count: usize = 0;
    var dummy: [0]u21 = .{};
    var ignored: usize = 0;
    walkFormat4(face, &dummy, &ignored, &count, false);
    return count;
}

fn fillFormat4(comptime face: font_vector.FixedFace, out: *[codepoint_count]u21, count: *usize) void {
    var counted: usize = 0;
    walkFormat4(face, out, count, &counted, true);
}

fn walkFormat4(comptime face: font_vector.FixedFace, out: anytype, out_count: *usize, counted: *usize, comptime write: bool) void {
    const sub = face.face.cmap_offset;
    const seg_count = readU16(face.face.data, sub + 6) / 2;
    const end_codes = sub + 14;
    const start_codes = end_codes + @as(usize, seg_count) * 2 + 2;
    var i: usize = 0;
    while (i < seg_count) : (i += 1) {
        const start = readU16(face.face.data, start_codes + i * 2);
        const end = readU16(face.face.data, end_codes + i * 2);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            if (write) put(out, out_count, cp);
            counted.* += 1;
        }
    }
    ensureReplacement(face, out, out_count, counted, write);
}

fn countFormat12(comptime face: font_vector.FixedFace) usize {
    var count: usize = 0;
    var dummy: [0]u21 = .{};
    var ignored: usize = 0;
    walkFormat12(face, &dummy, &ignored, &count, false);
    return count;
}

fn fillFormat12(comptime face: font_vector.FixedFace, out: *[codepoint_count]u21, count: *usize) void {
    var counted: usize = 0;
    walkFormat12(face, out, count, &counted, true);
}

fn walkFormat12(comptime face: font_vector.FixedFace, out: anytype, out_count: *usize, counted: *usize, comptime write: bool) void {
    const group_count = readU32(face.face.data, face.face.cmap_offset + 12);
    var group_index: usize = 0;
    while (group_index < group_count) : (group_index += 1) {
        const group = face.face.cmap_offset + 16 + group_index * 12;
        const start = readU32(face.face.data, group);
        const end = readU32(face.face.data, group + 4);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            if (write) put(out, out_count, cp);
            counted.* += 1;
        }
    }
    ensureReplacement(face, out, out_count, counted, write);
}

fn ensureReplacement(comptime face: font_vector.FixedFace, out: anytype, out_count: *usize, counted: *usize, comptime write: bool) void {
    if (face.glyphId(replacement_codepoint) == 0) @compileError("source font has no U+FFFD replacement glyph");
    if (!coverageContains(face, replacement_codepoint)) {
        if (write) put(out, out_count, replacement_codepoint);
        counted.* += 1;
    }
}

fn coverageContains(comptime face: font_vector.FixedFace, cp: u21) bool {
    return switch (face.face.cmap_format) {
        4 => containsFormat4(face, cp),
        12 => containsFormat12(face, cp),
        else => false,
    };
}

fn containsFormat4(comptime face: font_vector.FixedFace, cp: u21) bool {
    if (cp > 0xffff) return false;
    const sub = face.face.cmap_offset;
    const seg_count = readU16(face.face.data, sub + 6) / 2;
    const end_codes = sub + 14;
    const start_codes = end_codes + @as(usize, seg_count) * 2 + 2;
    var i: usize = 0;
    while (i < seg_count) : (i += 1) {
        const start = readU16(face.face.data, start_codes + i * 2);
        const end = readU16(face.face.data, end_codes + i * 2);
        if (cp >= start and cp <= end) return true;
    }
    return false;
}

fn containsFormat12(comptime face: font_vector.FixedFace, cp: u21) bool {
    const group_count = readU32(face.face.data, face.face.cmap_offset + 12);
    var group_index: usize = 0;
    while (group_index < group_count) : (group_index += 1) {
        const group = face.face.cmap_offset + 16 + group_index * 12;
        const start = readU32(face.face.data, group);
        const end = readU32(face.face.data, group + 4);
        if (cp >= start and cp <= end) return true;
    }
    return false;
}

fn put(out: anytype, count: *usize, cp: u21) void {
    out[count.*] = cp;
    count.* += 1;
}

fn readU16(data: []const u8, offset: usize) u16 {
    return (@as(u16, data[offset]) << 8) | data[offset + 1];
}

fn readU32(data: []const u8, offset: usize) u32 {
    return (@as(u32, data[offset]) << 24) |
        (@as(u32, data[offset + 1]) << 16) |
        (@as(u32, data[offset + 2]) << 8) |
        data[offset + 3];
}

fn isSurrogate(cp: u21) bool {
    return cp >= 0xd800 and cp <= 0xdfff;
}

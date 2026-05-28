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
    var count: usize = 0;
    var cp_raw: usize = 0;
    while (cp_raw <= std.math.maxInt(u21)) : (cp_raw += 1) {
        const cp: u21 = @intCast(cp_raw);
        if (isSurrogate(cp)) continue;
        if (face.glyphId(cp) == 0) continue;
        count += 1;
    }
    if (face.glyphId(replacement_codepoint) == 0) @compileError("source font has no U+FFFD replacement glyph");
    return count;
}

fn buildCodepoints(comptime face: font_vector.FixedFace) [codepoint_count]u21 {
    @setEvalBranchQuota(20_000_000);
    var out: [codepoint_count]u21 = undefined;
    var count: usize = 0;
    var cp_raw: usize = 0;
    while (cp_raw <= std.math.maxInt(u21)) : (cp_raw += 1) {
        const cp: u21 = @intCast(cp_raw);
        if (isSurrogate(cp)) continue;
        if (face.glyphId(cp) == 0) continue;
        out[count] = cp;
        count += 1;
    }
    if (count != codepoint_count) @compileError("source font coverage changed during vector compilation");
    return out;
}

fn isSurrogate(cp: u21) bool {
    return cp >= 0xd800 and cp <= 0xdfff;
}

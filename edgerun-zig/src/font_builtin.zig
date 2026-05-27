const std = @import("std");
const font_vector = @import("font_vector.zig");

pub const replacement_codepoint: u21 = std.unicode.replacement_character;

pub const max_codepoints: usize = 4096;
pub const max_kerns: usize = 65536;
pub const max_commands: usize = font_vector.max_serialized_commands;

pub const Storage = struct {
    glyphs: [max_codepoints]font_vector.GlyphRecord = undefined,
    kerns: [max_kerns]font_vector.KernRecord = undefined,
    commands: [max_commands]font_vector.Command = undefined,

    pub fn compile(self: *Storage) font_vector.CompileError!font_vector.Body {
        const fixed = try font_vector.FixedFace.geistDefault();
        var raw: [max_codepoints]u21 = undefined;
        const discovered = discoverCodepoints(fixed, &raw);
        return try font_vector.compileCodepoints(fixed, discovered, &self.glyphs, &self.kerns, &self.commands);
    }
};

pub const Compiled = struct {
    metrics: font_vector.Metrics,
    glyph_len: usize,
    kern_len: usize,
    command_len: usize,
    glyphs: [max_codepoints]font_vector.GlyphRecord,
    kerns: [max_kerns]font_vector.KernRecord,
    commands: [max_commands]font_vector.Command,

    pub fn body(self: *const Compiled) font_vector.Body {
        return .{
            .metrics = self.metrics,
            .glyphs = self.glyphs[0..self.glyph_len],
            .kerns = self.kerns[0..self.kern_len],
            .commands = self.commands[0..self.command_len],
        };
    }
};

pub const compiled = blk: {
    @setEvalBranchQuota(200_000_000);
    var storage: Storage = .{};
    const body = storage.compile() catch @compileError("failed to compile full built-in vector font from source font");
    var out = Compiled{
        .metrics = body.metrics,
        .glyph_len = body.glyphs.len,
        .kern_len = body.kerns.len,
        .command_len = body.commands.len,
        .glyphs = undefined,
        .kerns = undefined,
        .commands = undefined,
    };
    @memcpy(out.glyphs[0..body.glyphs.len], body.glyphs);
    @memcpy(out.kerns[0..body.kerns.len], body.kerns);
    @memcpy(out.commands[0..body.commands.len], body.commands);
    break :blk out;
};

pub fn discoverCodepoints(face: font_vector.FixedFace, out: *[max_codepoints]u21) []const u21 {
    var count: usize = 0;
    var cp_raw: usize = 0;
    while (cp_raw <= std.math.maxInt(u21)) : (cp_raw += 1) {
        const cp: u21 = @intCast(cp_raw);
        if (isSurrogate(cp)) continue;
        if (face.glyphId(cp) == 0) continue;
        put(out, &count, cp);
    }

    if (!contains(out[0..count], replacement_codepoint)) {
        if (face.glyphId(replacement_codepoint) == 0) @compileError("source font has no U+FFFD replacement glyph");
        put(out, &count, replacement_codepoint);
    }

    return out[0..count];
}

fn isSurrogate(cp: u21) bool {
    return cp >= 0xd800 and cp <= 0xdfff;
}

fn contains(values: []const u21, needle: u21) bool {
    for (values) |value| if (value == needle) return true;
    return false;
}

fn put(out: *[max_codepoints]u21, count: *usize, value: u21) void {
    if (count.* >= out.len) @compileError("source font coverage exceeds built-in vector font codepoint capacity");
    out[count.*] = value;
    count.* += 1;
}

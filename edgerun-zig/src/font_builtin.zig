const std = @import("std");
const font_vector = @import("font_vector.zig");
const renderer_ir = @import("render/ir.zig");

pub const replacement_codepoint: u21 = std.unicode.replacement_character;
pub const ascii_count: usize = renderer_ir.font_last_char - renderer_ir.font_first_char + 1;
const latin1_count: usize = 0x00ff - 0x00a0 + 1;
const punctuation = [_]u21{ 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2018, 0x2019, 0x201a, 0x201c, 0x201d, 0x201e, 0x2022, 0x2026, 0x2039, 0x203a };
const symbols = [_]u21{ 0x20ac, 0x20a3, 0x20a4, 0x20a6, 0x20a8, 0x20a9, 0x2190, 0x2191, 0x2192, 0x2193, 0x2713, 0x2717 };

pub const glyph_count: usize = ascii_count + latin1_count + punctuation.len + symbols.len + 1;
pub const kern_capacity: usize = glyph_count * glyph_count;
pub const command_capacity: usize = glyph_count * font_vector.max_commands;

pub const Storage = struct {
    glyphs: [glyph_count]font_vector.GlyphRecord = undefined,
    kerns: [kern_capacity]font_vector.KernRecord = undefined,
    commands: [command_capacity]font_vector.Command = undefined,

    pub fn compile(self: *Storage) font_vector.CompileError!font_vector.Body {
        const fixed = try font_vector.FixedFace.geistDefault();
        var raw: [glyph_count]u21 = undefined;
        return try font_vector.compileCodepoints(fixed, codepoints(&raw), &self.glyphs, &self.kerns, &self.commands);
    }
};

pub const Compiled = struct {
    metrics: font_vector.Metrics,
    glyph_len: usize,
    kern_len: usize,
    command_len: usize,
    glyphs: [glyph_count]font_vector.GlyphRecord,
    kerns: [kern_capacity]font_vector.KernRecord,
    commands: [command_capacity]font_vector.Command,

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
    @setEvalBranchQuota(20_000_000);
    var storage: Storage = .{};
    const body = storage.compile() catch @compileError("failed to compile built-in vector font");
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

pub fn codepoints(out: *[glyph_count]u21) []const u21 {
    var i: usize = 0;
    var c: u21 = renderer_ir.font_first_char;
    while (c <= renderer_ir.font_last_char) : (c += 1) put(out, &i, c);
    c = 0x00a0;
    while (c <= 0x00ff) : (c += 1) put(out, &i, c);
    for (punctuation) |v| put(out, &i, v);
    for (symbols) |v| put(out, &i, v);
    put(out, &i, replacement_codepoint);
    if (i != glyph_count) @compileError("built-in font codepoint count mismatch");
    return out[0..i];
}

fn put(out: *[glyph_count]u21, i: *usize, value: u21) void {
    if (i.* >= out.len) @compileError("built-in font codepoint overflow");
    out[i.*] = value;
    i.* += 1;
}

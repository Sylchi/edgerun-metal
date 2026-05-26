const std = @import("std");
const varfont = @import("varfont.zig");

pub const default_text_px: f32 = 16.0;
pub const button_label_px: f32 = 17.0;
pub const badge_label_px: f32 = 13.0;

pub fn width(value: []const u8, px_size: f32) f32 {
    if (value.len == 0) return 0.0;
    const face = varfont.Face.geist() catch unreachable;
    var out: f32 = 0.0;
    var previous: u16 = 0;
    for (value) |byte| {
        const glyph_id = face.glyphId(byte);
        if (previous != 0) out += face.kern(previous, glyph_id, px_size);
        out += face.advance(glyph_id, px_size);
        previous = glyph_id;
    }
    return out;
}

pub fn averageWidth(value: []const u8, px_size: f32) f32 {
    if (value.len == 0) return width("n", px_size);
    return @max(1.0, width(value, px_size) / @as(f32, @floatFromInt(value.len)));
}

pub fn fitPrefix(value: []const u8, px_size: f32, max_width: f32) []const u8 {
    if (value.len == 0 or max_width <= 0.0) return value[0..0];
    const face = varfont.Face.geist() catch unreachable;
    var out: f32 = 0.0;
    var previous: u16 = 0;
    for (value, 0..) |byte, index| {
        const glyph_id = face.glyphId(byte);
        const kern = if (previous != 0) face.kern(previous, glyph_id, px_size) else 0.0;
        const next = out + kern + face.advance(glyph_id, px_size);
        if (next > max_width) return value[0..index];
        out = next;
        previous = glyph_id;
    }
    return value;
}

test "ui text metrics use geist glyph advances and kerning" {
    const wide = width("WWW", default_text_px);
    const narrow = width("iii", default_text_px);
    try std.testing.expect(wide > narrow);

    const kerned = width("AV", default_text_px);
    const separate = width("A", default_text_px) + width("V", default_text_px);
    try std.testing.expect(kerned <= separate);
    try std.testing.expect(averageWidth("EdgeRun", default_text_px) > 1.0);
}

test "ui text metrics fits deterministic prefixes to a width" {
    const value = "Continue safely";
    const full_width = width(value, button_label_px);
    try std.testing.expectEqualStrings(value, fitPrefix(value, button_label_px, full_width));

    const prefix = fitPrefix(value, button_label_px, width("Continue", button_label_px));
    try std.testing.expect(prefix.len < value.len);
    try std.testing.expect(std.mem.startsWith(u8, value, prefix));
}

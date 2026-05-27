const std = @import("std");
const varfont = @import("varfont.zig");

pub const default_text_px: f32 = 16.0;
pub const button_label_px: f32 = 17.0;
pub const badge_label_px: f32 = 13.0;

pub fn width(value: []const u8, px_size: f32) f32 {
    if (value.len == 0) return 0.0;
    const face = varfont.Face.geist() catch unreachable;
    var out: f32 = 0.0;
    var previous: ?u16 = null;
    var index: usize = 0;
    while (nextCodepoint(value, &index)) |codepoint| {
        const glyph_id = face.glyphId(codepoint);
        if (previous) |left| out += face.kern(left, glyph_id, px_size);
        out += face.advance(glyph_id, px_size);
        previous = glyph_id;
    }
    return out;
}

pub fn averageWidth(value: []const u8, px_size: f32) f32 {
    if (value.len == 0) return width("n", px_size);
    const codepoint_count = utf8CodepointCount(value);
    return @max(1.0, width(value, px_size) / @as(f32, @floatFromInt(codepoint_count)));
}

pub fn fitPrefix(value: []const u8, px_size: f32, max_width: f32) []const u8 {
    if (value.len == 0 or max_width <= 0.0) return value[0..0];
    const face = varfont.Face.geist() catch unreachable;
    var out: f32 = 0.0;
    var previous: ?u16 = null;
    var index: usize = 0;
    while (index < value.len) {
        const start = index;
        const codepoint = nextCodepoint(value, &index) orelse break;
        const glyph_id = face.glyphId(codepoint);
        const kern = if (previous) |left| face.kern(left, glyph_id, px_size) else 0.0;
        const next = out + kern + face.advance(glyph_id, px_size);
        if (next > max_width) return value[0..start];
        out = next;
        previous = glyph_id;
    }
    return value;
}

fn nextCodepoint(value: []const u8, index: *usize) ?u21 {
    if (index.* >= value.len) return null;
    const start = index.*;

    const codepoint_len = std.unicode.utf8ByteSequenceLength(value[start]) catch {
        index.* = start + 1;
        return std.unicode.replacement_character;
    };

    const end = start + codepoint_len;
    if (end > value.len) {
        index.* = value.len;
        return std.unicode.replacement_character;
    }

    const codepoint = std.unicode.utf8Decode(value[start..end]) catch {
        index.* = start + 1;
        return std.unicode.replacement_character;
    };
    index.* = end;
    return codepoint;
}

fn utf8CodepointCount(value: []const u8) usize {
    var index: usize = 0;
    var count: usize = 0;
    while (nextCodepoint(value, &index)) |_| count += 1;
    return count;
}

test "ui text metrics average width treats utf8 as codepoints" {
    const value = "éé";
    const total = width(value, default_text_px);
    const average = averageWidth(value, default_text_px);
    try std.testing.expectApproxEqAbs(total / 2.0, average, 0.0001);
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

test "ui text metrics fit prefix respects utf8 codepoint boundaries" {
    const value = "éx";
    const max_width = width("é", default_text_px);
    const prefix = fitPrefix(value, default_text_px, max_width);
    try std.testing.expectEqual(@as(usize, 2), prefix.len);
    try std.testing.expectEqualStrings("é", prefix);
}

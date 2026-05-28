const std = @import("std");
const font_builtin = @import("font_builtin.zig");
const font_vector = @import("font_vector.zig");
const ui = @import("ui.zig");

pub const default_text_px: f32 = 16.0;
pub const button_label_px: f32 = 17.0;
pub const badge_label_px: f32 = 13.0;

fn resolveCodepoint(body: font_vector.Body, codepoint: u21) u21 {
    if (body.glyphForCodepoint(codepoint) != null) return codepoint;
    return font_builtin.replacement_codepoint;
}

fn glyphAdvance(body: font_vector.Body, codepoint: u21, px_size: f32) f32 {
    const glyph = body.glyphForCodepoint(codepoint) orelse return 0.0;
    const scale = px_size / @as(f32, @floatFromInt(body.metrics.units_per_em));
    return glyph.advance * scale;
}

fn glyphKern(body: font_vector.Body, left: u21, right: u21, px_size: f32) f32 {
    const kern = body.kern(left, right);
    if (kern == 0.0) return 0.0;
    const scale = px_size / @as(f32, @floatFromInt(body.metrics.units_per_em));
    return kern * scale;
}

pub fn width(value: []const u8, px_size: f32) f32 {
    if (value.len == 0) return 0.0;
    const body = font_builtin.body(.regular);
    var out: f32 = 0.0;
    var previous: ?u21 = null;
    var index: usize = 0;
    while (ui.nextCodepoint(value, &index)) |raw_codepoint| {
        const codepoint = resolveCodepoint(body, raw_codepoint);
        if (previous) |left| out += glyphKern(body, left, codepoint, px_size);
        out += glyphAdvance(body, codepoint, px_size);
        previous = codepoint;
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
    const body = font_builtin.body(.regular);
    var out: f32 = 0.0;
    var previous: ?u21 = null;
    var index: usize = 0;
    while (index < value.len) {
        const start = index;
        const raw_codepoint = ui.nextCodepoint(value, &index) orelse break;
        const codepoint = resolveCodepoint(body, raw_codepoint);
        const next = out + glyphAdvance(body, codepoint, px_size) + if (previous) |left| glyphKern(body, left, codepoint, px_size) else 0.0;
        if (next > max_width) return value[0..start];
        out = next;
        previous = codepoint;
    }
    return value;
}

fn utf8CodepointCount(value: []const u8) usize {
    var index: usize = 0;
    var count: usize = 0;
    while (ui.nextCodepoint(value, &index)) |_| count += 1;
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

test "ui text metrics fit deterministic prefixes to a width" {
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

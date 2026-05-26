const std = @import("std");
const ui = @import("ui.zig");
const tokens = @import("ui_tokens.zig");

pub const content_wide: f32 = tokens.content_wide;
pub const content_pad: f32 = tokens.content_pad;
pub const header_h: f32 = tokens.header_h;
pub const surface_radius: f32 = tokens.Radius.surface;
pub const control_radius: f32 = tokens.Radius.control;
pub const control_h: f32 = tokens.Control.h;
pub const compact_control_h: f32 = tokens.Control.compact_h;
pub const min_touch_target: f32 = tokens.Control.min_touch_target;

pub const Icon = tokens.Icon;
pub const Type = tokens.Type;
pub const palette = tokens.Palette;

pub fn style() ui.Style {
    return tokens.appStyle();
}

pub fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

test "app design re-exports the shared ui token layer" {
    try std.testing.expectEqual(tokens.Radius.surface, surface_radius);
    try std.testing.expectEqual(tokens.Control.compact_h, compact_control_h);
    try std.testing.expect(std.meta.eql(style().bg, tokens.Palette.bg));
    try std.testing.expect(std.meta.eql(palette.primary, tokens.Palette.primary));
}

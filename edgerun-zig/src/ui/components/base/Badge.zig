const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");

const RenderOptions = common.RenderOptions;

pub fn render(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const color = colorFor(options);
    var fill = color;
    fill.a = fill_alpha;
    const resolved_height = @min(height, bounds.h);
    const badge_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - resolved_height) * 0.5, bounds.w, resolved_height);
    try scene.pushRect(badge_bounds, fill, .fill, resolved_height * 0.5, 0.0);
    try scene.pushAlignedText(labelBounds(badge_bounds), label, color, .center);
}

pub fn measure(label: []const u8, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = @max(min_width, @as(f32, @floatFromInt(label.len)) * label_average_w + padding_x * 2.0);
    return layout.Measurement.flexible(
        .{ .w = min_width, .h = height },
        .{ .w = preferred_width, .h = height },
        .{ .w = max_width, .h = height },
    ).applyExact(constraints);
}

fn colorFor(options: RenderOptions) ui.Color {
    return switch (options.badge_variant) {
        .accent => options.style.accent,
        .neutral => options.style.muted,
        .danger => ui.Color{ .r = 239, .g = 68, .b = 68 },
    };
}

fn labelBounds(bounds: ui.Rect) ui.Rect {
    const resolved_padding = @min(padding_x, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + resolved_padding, bounds.y + (bounds.h - text_height) * 0.5, @max(1.0, bounds.w - resolved_padding * 2.0), text_height);
}

pub const height: f32 = 24.0;
pub const text_height: f32 = 13.0;
pub const padding_x: f32 = 12.0;

const fill_alpha: u8 = 48;
const label_average_w: f32 = 8.0;
const min_width: f32 = 28.0;
const max_width: f32 = 4096.0;

test "base badge measurement includes horizontal padding" {
    const measured = measure("Native", .{});

    try std.testing.expect(measured.preferred.w > @as(f32, 24.0));
    try std.testing.expectEqual(height, measured.preferred.h);
}

const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const ui = @import("../../../ui.zig");

const RenderOptions = common.RenderOptions;

pub const Params = struct {
    value: f32,
    height: f32 = default_height,
    radius: f32 = default_radius,
    min_fill_width: f32 = default_min_fill_width,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params, options: RenderOptions) ui.RenderError!void {
    const bar_bounds = ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(params.height, bounds.h));
    if (bar_bounds.w <= 0.0 or bar_bounds.h <= 0.0) return;
    try scene.pushRect(bar_bounds, options.style.row, .fill, params.radius, 0.0);
    const value = ui.clampUnit(params.value);
    if (value <= 0.0) return;
    const fill_w = @min(bar_bounds.w, @max(params.min_fill_width, bar_bounds.w * value));
    try scene.pushRect(ui.Rect.init(bar_bounds.x, bar_bounds.y, fill_w, bar_bounds.h), options.style.accent, .fill, params.radius, 0.0);
}

pub const default_height: f32 = 10.0;
pub const default_radius: f32 = 5.0;
pub const default_min_fill_width: f32 = 2.0;

test "base progress bar renders track and fill" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 100, 10), .{ .value = 0.25 }, .{});

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 2), written.len);
    try std.testing.expectEqual(@as(f32, 25.0), written[1].rect.bounds.w);
}

test "base progress bar omits fill for empty value" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 100, 10), .{ .value = 0.0 }, .{});

    try std.testing.expectEqual(@as(usize, 1), scene.written().len);
}

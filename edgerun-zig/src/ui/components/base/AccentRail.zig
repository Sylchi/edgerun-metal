const std = @import("std");
const ui = @import("../../../ui.zig");

pub const Params = struct {
    width: f32 = default_width,
    radius: f32,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, params: Params) ui.RenderError!void {
    const rail_width = @min(params.width, bounds.w);
    if (rail_width <= 0.0 or bounds.h <= 0.0) return;
    try scene.pushRect(ui.Rect.init(bounds.x, bounds.y, rail_width, bounds.h), color, .fill, params.radius, 0.0);
}

pub const default_width: f32 = 4.0;

test "base accent rail draws a left edge strip" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(10, 20, 100, 40), ui.Color.accent, .{ .radius = 10.0 });

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 1), written.len);
    try std.testing.expectEqual(@as(f32, 10.0), written[0].rect.bounds.x);
    try std.testing.expectEqual(default_width, written[0].rect.bounds.w);
}

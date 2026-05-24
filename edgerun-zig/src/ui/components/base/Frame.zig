const std = @import("std");
const ui = @import("../../../ui.zig");

pub const Params = struct {
    fill: ui.Color,
    border: ui.Color,
    radius: f32,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params) ui.RenderError!void {
    if (bounds.w <= 0.0 or bounds.h <= 0.0) return;
    try scene.pushRect(bounds, params.fill, .fill, params.radius, 0.0);
    try scene.pushRect(bounds, params.border, .border, params.radius, 0.0);
}

test "base frame renders fill and border" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 100, 40), .{
        .fill = ui.Color.row,
        .border = ui.Color.border,
        .radius = 6.0,
    });

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 2), written.len);
    try std.testing.expectEqual(ui.RectMode.fill, written[0].rect.mode);
    try std.testing.expectEqual(ui.RectMode.border, written[1].rect.mode);
}

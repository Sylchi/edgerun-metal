const std = @import("std");
const ui = @import("../../../ui.zig");

pub fn renderFilled(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color) ui.RenderError!void {
    if (bounds.w <= 0.0 or bounds.h <= 0.0) return;
    try scene.pushRect(bounds, color, .fill, radiusFor(bounds), 0.0);
}

pub fn renderRing(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color) ui.RenderError!void {
    if (bounds.w <= 0.0 or bounds.h <= 0.0) return;
    try scene.pushRect(bounds, color, .border, radiusFor(bounds), 0.0);
}

pub fn renderRadio(scene: *ui.Scene, bounds: ui.Rect, border_color: ui.Color, fill_color: ui.Color, selected: bool, selected_inset: f32) ui.RenderError!void {
    try renderRing(scene, bounds, border_color);
    if (!selected) return;
    const inner = bounds.insetUniform(@min(selected_inset, @min(bounds.w, bounds.h) * 0.5));
    try renderFilled(scene, inner, fill_color);
}

fn radiusFor(bounds: ui.Rect) f32 {
    return @min(bounds.w, bounds.h) * 0.5;
}

test "base marker renders filled circle" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderFilled(&scene, ui.Rect.init(0, 0, 12, 12), ui.Color.accent);

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 1), written.len);
    try std.testing.expectEqual(@as(f32, 6.0), written[0].rect.radius);
}

test "base marker renders selected radio" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderRadio(&scene, ui.Rect.init(0, 0, 16, 16), ui.Color.border, ui.Color.accent, true, 4.0);

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 2), written.len);
    try std.testing.expectEqual(@as(f32, 8.0), written[0].rect.radius);
    try std.testing.expectEqual(@as(f32, 4.0), written[1].rect.radius);
}

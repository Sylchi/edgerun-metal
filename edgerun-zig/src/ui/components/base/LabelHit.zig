const std = @import("std");
const ui = @import("../../../ui.zig");

pub const Params = struct {
    id: u32,
    label: []const u8,
    color: ui.Color,
    alignment: ui.TextAlign = .center,
    hit_kind: ui.HitKind = .button,
};

pub const Insets = struct {
    x: f32,
    y: f32,
};

pub const WidthMetrics = struct {
    average_char_width: f32,
    min_width: f32,
    padding_x: f32,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params, insets: Insets) ui.RenderError!void {
    try scene.pushAlignedText(bounds.insetLtrb(insets.x, insets.y, insets.x, insets.y), params.label, params.color, params.alignment);
    try scene.pushHit(.{ .slot = 0, .kind = params.hit_kind, .id = params.id, .bounds = bounds });
}

pub fn width(label: []const u8, metrics: WidthMetrics) f32 {
    const label_width = @as(f32, @floatFromInt(label.len)) * metrics.average_char_width;
    return @max(metrics.min_width, label_width + metrics.padding_x * 2.0);
}

test "base label hit renders text and button hit" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 120, 32), .{
        .id = 90,
        .label = "Academy",
        .color = ui.Color.text,
        .alignment = .start,
    }, .{ .x = 8.0, .y = 6.0 });

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 2), written.len);
    try std.testing.expect(written[0] == .text);
    try std.testing.expect(written[1] == .hit);
    try std.testing.expectEqual(@as(u32, 90), written[1].hit.id);
}

test "base label hit width includes padding and minimum" {
    const metrics = WidthMetrics{ .average_char_width = 8.0, .min_width = 44.0, .padding_x = 6.0 };

    try std.testing.expectEqual(@as(f32, 44.0), width("A", metrics));
    try std.testing.expectEqual(@as(f32, 60.0), width("Lesson", metrics));
}

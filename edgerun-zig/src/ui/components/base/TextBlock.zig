const std = @import("std");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");

pub const Metrics = struct {
    line_height: f32,
    average_char_width: f32,
    max_lines: usize,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, metrics: Metrics) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, color, .{
        .line_height = metrics.line_height,
        .average_char_width = metrics.average_char_width,
        .max_lines = metrics.max_lines,
    });
}

pub fn measure(value: []const u8, constraints: layout.Constraints, metrics: Metrics) layout.Measurement {
    return layout.measureText(value, constraints, .{
        .line_height = metrics.line_height,
        .average_char_width = metrics.average_char_width,
        .max_lines = metrics.max_lines,
    });
}

test "base text block renders wrapped text" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 120, 40), "A small block of text", ui.Color.text, .{
        .line_height = 18.0,
        .average_char_width = 9.0,
        .max_lines = 2,
    });

    try std.testing.expect(scene.written().len > 0);
}

test "base text block measurement wraps under exact width" {
    const metrics = Metrics{ .line_height = 18.0, .average_char_width = 9.0, .max_lines = 4 };
    const wide = measure("A small block of text", .{ .width = .{ .exact = 240 }, .text_wrap = .wrap }, metrics);
    const narrow = measure("A small block of text", .{ .width = .{ .exact = 80 }, .text_wrap = .wrap }, metrics);

    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
}

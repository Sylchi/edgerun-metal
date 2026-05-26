const std = @import("std");
const layouts = @import("layouts.zig");
const ui = @import("ui.zig");

pub fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0.0);
}

pub fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .border, radius, 0.0);
}

pub fn text(scene: *ui.Scene, x: f32, y: f32, width: f32, height: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try alignedText(scene, ui.Rect.init(x, y, @max(1.0, width), @max(1.0, height)), value, color, .start);
}

pub fn alignedText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    try scene.pushAlignedText(bounds, value, color, alignment);
}

pub fn wrappedText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, metrics: layouts.types.TextMetrics) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, color, .{
        .line_height = metrics.line_height,
        .average_char_width = metrics.average_char_width,
        .max_lines = metrics.max_lines,
    });
}

pub fn wrappedTextWith(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, line_height: f32, average_char_width: f32, max_lines: usize) ui.RenderError!void {
    try wrappedText(scene, bounds, value, color, .{
        .line_height = line_height,
        .average_char_width = average_char_width,
        .max_lines = max_lines,
    });
}

pub fn wrappedTextHeight(value: []const u8, width: f32, metrics: layouts.types.TextMetrics) f32 {
    const measurement = layouts.types.measureText(value, .{
        .width = .{ .exact = @max(1.0, width) },
        .height = .unconstrained,
        .text_wrap = .wrap,
    }, metrics);
    return @max(metrics.line_height, measurement.preferred.h);
}

pub fn wrappedTextHeightWith(value: []const u8, width: f32, line_height: f32, max_lines: usize, average_char_width: f32) f32 {
    return wrappedTextHeight(value, width, .{
        .line_height = line_height,
        .average_char_width = average_char_width,
        .max_lines = max_lines,
    });
}

pub fn wrappedLineCount(value: []const u8, width: f32, average_char_width: f32, max_lines: usize) usize {
    if (value.len == 0 or max_lines == 0) return 0;
    const height = wrappedTextHeightWith(value, width, 1.0, max_lines, average_char_width);
    return @max(@as(usize, 1), @as(usize, @intFromFloat(height)));
}

pub fn centered(bounds: ui.Rect, max_width: f32, horizontal_pad: f32) ui.Rect {
    const width = @min(max_width, @max(1.0, bounds.w - horizontal_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

pub fn columnBounds(bounds: ui.Rect, columns: usize, gap: f32, column: usize, y: f32, height: f32) ui.Rect {
    const safe_columns = @max(@as(usize, 1), columns);
    const clamped_column = @min(column, safe_columns - 1);
    const column_count: f32 = @floatFromInt(safe_columns);
    const gap_count: f32 = @floatFromInt(safe_columns - 1);
    const column_width = @max(1.0, (bounds.w - gap * gap_count) / column_count);
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(clamped_column)) * (column_width + gap), y, column_width, height);
}

pub fn gridColumns(width: f32, min_column_width: f32, gap: f32, max_columns: usize) usize {
    var columns: usize = 1;
    while (columns < max_columns) {
        const next = columns + 1;
        const required = min_column_width * @as(f32, @floatFromInt(next)) + gap * @as(f32, @floatFromInt(next - 1));
        if (required > width) break;
        columns = next;
    }
    return columns;
}

test "app layout wrapped text measurement delegates to canonical layout metrics" {
    const metrics = layouts.types.TextMetrics{ .line_height = 18.0, .average_char_width = 9.0, .max_lines = 3 };
    try std.testing.expect(wrappedTextHeight("one two three four five", 60.0, metrics) > metrics.line_height);
}

test "app layout column bounds stay inside parent" {
    const parent = ui.Rect.init(10, 20, 300, 40);
    const third = columnBounds(parent, 3, 12, 2, 30, 24);
    try std.testing.expect(third.x + third.w <= parent.x + parent.w + 0.01);
}

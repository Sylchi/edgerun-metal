const std = @import("std");
const ui = @import("../core.zig");
const layout = @import("Types.zig");

pub const Options = struct {
    columns: usize = 1,
    gap: f32 = 0,
    padding: layout.Insets = .{},
};

pub fn measure(children: []const layout.Measurement, constraints: layout.Constraints, options: Options) layout.Measurement {
    const columns = requireColumns(options.columns);
    const inner_constraints = constraints.inner(options.padding);
    const available_width = inner_constraints.width.limit(maxPreferredWidth(children, columns, options.gap));
    const cell_width = gridCellWidth(available_width, columns, options.gap);
    const grid_width = cell_width * @as(f32, @floatFromInt(columns)) + options.gap * @as(f32, @floatFromInt(columns - 1));
    const rows = rowCount(children.len, columns);
    var preferred_height: f32 = 0;

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        if (row != 0) preferred_height += options.gap;
        preferred_height += rowHeight(children, row, columns);
    }

    return layout.Measurement.flexible(
        .{ .w = grid_width, .h = preferred_height },
        .{ .w = grid_width, .h = preferred_height },
        .{ .w = grid_width, .h = preferred_height },
    ).withInsets(options.padding).applyExact(constraints);
}

pub fn place(bounds: ui.Rect, children: []const layout.Measurement, options: Options, out: []ui.Rect) []ui.Rect {
    const columns = requireColumns(options.columns);
    const count = @min(children.len, out.len);
    const inner = bounds.insetLtrb(options.padding.left, options.padding.top, options.padding.right, options.padding.bottom);
    const cell_width = gridCellWidth(inner.w, columns, options.gap);
    var y = inner.y;
    var index: usize = 0;
    while (index < count) {
        const row = index / columns;
        const row_h = rowHeight(children[0..count], row, columns);
        var column: usize = 0;
        while (column < columns and index < count) : (column += 1) {
            const x = inner.x + @as(f32, @floatFromInt(column)) * (cell_width + options.gap);
            out[index] = ui.Rect.init(x, y, cell_width, row_h);
            index += 1;
        }
        y += row_h + options.gap;
    }
    return out[0..count];
}

fn requireColumns(columns: usize) usize {
    std.debug.assert(columns > 0);
    return columns;
}

fn rowCount(child_count: usize, columns: usize) usize {
    if (child_count == 0) return 0;
    return (child_count + columns - 1) / columns;
}

fn gridCellWidth(width: f32, columns: usize, gap: f32) f32 {
    const column_count = @as(f32, @floatFromInt(columns));
    const total_gap = @as(f32, @floatFromInt(columns - 1)) * gap;
    return @max(0, (width - total_gap) / column_count);
}

fn rowHeight(children: []const layout.Measurement, row: usize, columns: usize) f32 {
    const start = row * columns;
    const end = @min(children.len, start + columns);
    var height: f32 = 0;
    for (children[start..end]) |child| height = @max(height, child.preferred.h);
    return height;
}

fn maxPreferredWidth(children: []const layout.Measurement, columns: usize, gap: f32) f32 {
    var width: f32 = 0;
    for (children) |child| width = @max(width, child.preferred.w);
    return width * @as(f32, @floatFromInt(columns)) + gap * @as(f32, @floatFromInt(columns - 1));
}

test "grid measures rows from tallest child per row" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 80, .h = 20 }),
        layout.Measurement.fixed(.{ .w = 120, .h = 40 }),
        layout.Measurement.fixed(.{ .w = 90, .h = 30 }),
    };
    const measured = measure(&children, .{ .width = .{ .exact = 260 } }, .{ .columns = 2, .gap = 10 });

    try std.testing.expectEqual(@as(f32, 260), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 80), measured.preferred.h);
}

test "grid places cells using resolved column width" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 80, .h = 20 }),
        layout.Measurement.fixed(.{ .w = 120, .h = 40 }),
    };
    var out: [2]ui.Rect = undefined;
    const rects = place(ui.Rect.init(0, 0, 260, 80), &children, .{ .columns = 2, .gap = 10 }, &out);

    try std.testing.expectEqual(@as(f32, 125), rects[0].w);
    try std.testing.expectEqual(@as(f32, 135), rects[1].x);
    try std.testing.expectEqual(@as(f32, 40), rects[0].h);
}

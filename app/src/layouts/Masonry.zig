const std = @import("std");
const ui = @import("../ui.zig");
const layout = @import("Types.zig");

const max_columns = 12;

pub const Options = struct {
    columns: usize = 1,
    gap: f32 = 0,
    padding: layout.Insets = .{},
};

pub fn measure(children: []const layout.Measurement, constraints: layout.Constraints, options: Options) layout.Measurement {
    const columns = requireColumns(options.columns);
    const inner_constraints = constraints.inner(options.padding);
    const available_width = inner_constraints.width.limit(maxPreferredWidth(children, columns, options.gap));
    var heights = emptyColumnHeights();

    for (children) |child| {
        const column = shortestColumn(heights[0..columns]);
        if (heights[column] != 0) heights[column] += options.gap;
        heights[column] += child.preferred.h;
    }

    const preferred_height = tallestColumn(heights[0..columns]);
    return layout.Measurement.flexible(
        .{ .w = available_width, .h = preferred_height },
        .{ .w = available_width, .h = preferred_height },
        .{ .w = available_width, .h = preferred_height },
    ).withInsets(options.padding).applyExact(constraints);
}

pub fn place(bounds: ui.Rect, children: []const layout.Measurement, options: Options, out: []ui.Rect) []ui.Rect {
    const columns = requireColumns(options.columns);
    const count = @min(children.len, out.len);
    const inner = bounds.insetLtrb(options.padding.left, options.padding.top, options.padding.right, options.padding.bottom);
    const cell_width = masonryCellWidth(inner.w, columns, options.gap);
    var heights = emptyColumnHeights();

    for (children[0..count], 0..) |child, index| {
        const column = shortestColumn(heights[0..columns]);
        const x = inner.x + @as(f32, @floatFromInt(column)) * (cell_width + options.gap);
        const y = inner.y + heights[column] + if (heights[column] == 0) 0 else options.gap;
        out[index] = ui.Rect.init(x, y, cell_width, child.preferred.h);
        heights[column] = y - inner.y + child.preferred.h;
    }
    return out[0..count];
}

fn requireColumns(columns: usize) usize {
    std.debug.assert(columns > 0 and columns <= max_columns);
    return columns;
}

fn emptyColumnHeights() [max_columns]f32 {
    return [_]f32{0} ** max_columns;
}

fn shortestColumn(heights: []const f32) usize {
    var best: usize = 0;
    var best_height = heights[0];
    for (heights[1..], 1..) |height, index| {
        if (height < best_height) {
            best = index;
            best_height = height;
        }
    }
    return best;
}

fn tallestColumn(heights: []const f32) f32 {
    var height: f32 = 0;
    for (heights) |value| height = @max(height, value);
    return height;
}

fn masonryCellWidth(width: f32, columns: usize, gap: f32) f32 {
    const column_count = @as(f32, @floatFromInt(columns));
    const total_gap = @as(f32, @floatFromInt(columns - 1)) * gap;
    return @max(0, (width - total_gap) / column_count);
}

fn maxPreferredWidth(children: []const layout.Measurement, columns: usize, gap: f32) f32 {
    var width: f32 = 0;
    for (children) |child| width = @max(width, child.preferred.w);
    return width * @as(f32, @floatFromInt(columns)) + gap * @as(f32, @floatFromInt(columns - 1));
}

test "masonry measures by shortest-column placement" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 80, .h = 100 }),
        layout.Measurement.fixed(.{ .w = 80, .h = 40 }),
        layout.Measurement.fixed(.{ .w = 80, .h = 40 }),
    };
    const measured = measure(&children, .{ .width = .{ .exact = 200 } }, .{ .columns = 2, .gap = 10 });

    try std.testing.expectEqual(@as(f32, 200), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 100), measured.preferred.h);
}

test "masonry places each item in the current shortest column" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 80, .h = 100 }),
        layout.Measurement.fixed(.{ .w = 80, .h = 40 }),
        layout.Measurement.fixed(.{ .w = 80, .h = 40 }),
    };
    var out: [3]ui.Rect = undefined;
    const rects = place(ui.Rect.init(0, 0, 200, 160), &children, .{ .columns = 2, .gap = 10 }, &out);

    try std.testing.expectEqual(@as(f32, 105), rects[1].x);
    try std.testing.expectEqual(@as(f32, 50), rects[2].y);
    try std.testing.expectEqual(@as(f32, 95), rects[2].w);
}

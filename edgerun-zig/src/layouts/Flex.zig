const std = @import("std");
const ui = @import("../ui.zig");
const layout = @import("Types.zig");

pub const Align = enum {
    start,
    stretch,
};

pub const Options = struct {
    axis: layout.Axis = .vertical,
    gap: f32 = 0,
    padding: layout.Insets = .{},
    cross_align: Align = .stretch,
};

pub fn measure(children: []const layout.Measurement, constraints: layout.Constraints, options: Options) layout.Measurement {
    var min_main: f32 = 0;
    var min_cross: f32 = 0;
    var preferred_main: f32 = 0;
    var preferred_cross: f32 = 0;
    var max_main: f32 = 0;
    var max_cross: f32 = 0;

    for (children, 0..) |child, index| {
        const gap = if (index == 0) 0 else options.gap;
        const child_min = layout.toLogical(options.axis, child.min);
        const child_preferred = layout.toLogical(options.axis, child.preferred);
        const child_max = layout.toLogical(options.axis, child.max);
        min_main += child_min.w + gap;
        preferred_main += child_preferred.w + gap;
        max_main += child_max.w + gap;
        min_cross = @max(min_cross, child_min.h);
        preferred_cross = @max(preferred_cross, child_preferred.h);
        max_cross = @max(max_cross, child_max.h);
    }

    const min_size = layout.fromLogical(options.axis, .{ .w = min_main, .h = min_cross });
    const preferred_size = layout.fromLogical(options.axis, .{ .w = preferred_main, .h = preferred_cross });
    const max_size = layout.fromLogical(options.axis, .{ .w = max_main, .h = max_cross });
    return layout.Measurement.flexible(min_size, preferred_size, max_size)
        .withInsets(options.padding)
        .applyExact(constraints);
}

pub fn place(bounds: ui.Rect, children: []const layout.Measurement, options: Options, out: []ui.Rect) []ui.Rect {
    const count = @min(children.len, out.len);
    const inner = bounds.insetLtrb(options.padding.left, options.padding.top, options.padding.right, options.padding.bottom);
    var cursor: f32 = 0;
    for (children[0..count], 0..) |child, index| {
        const child_size = layout.toLogical(options.axis, child.preferred);
        const main_size = child_size.w;
        const cross_size = switch (options.cross_align) {
            .start => @min(child_size.h, if (options.axis == .horizontal) inner.h else inner.w),
            .stretch => if (options.axis == .horizontal) inner.h else inner.w,
        };
        const rect = switch (options.axis) {
            .horizontal => ui.Rect.init(inner.x + cursor, inner.y, main_size, cross_size),
            .vertical => ui.Rect.init(inner.x, inner.y + cursor, cross_size, main_size),
        };
        out[index] = rect;
        cursor += main_size + options.gap;
    }
    return out[0..count];
}

test "flex measures vertical stack with parent-owned gap and padding" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 100, .h = 20 }),
        layout.Measurement.fixed(.{ .w = 140, .h = 30 }),
    };
    const measured = measure(&children, .{}, .{
        .axis = .vertical,
        .gap = 8,
        .padding = layout.Insets.uniform(10),
    });

    try std.testing.expectEqual(@as(f32, 160), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 78), measured.preferred.h);
}

test "flex places horizontal children in order" {
    const children = [_]layout.Measurement{
        layout.Measurement.fixed(.{ .w = 50, .h = 20 }),
        layout.Measurement.fixed(.{ .w = 70, .h = 24 }),
    };
    var out: [2]ui.Rect = undefined;
    const rects = place(ui.Rect.init(0, 0, 200, 50), &children, .{ .axis = .horizontal, .gap = 6 }, &out);

    try std.testing.expectEqual(@as(usize, 2), rects.len);
    try std.testing.expectEqual(@as(f32, 0), rects[0].x);
    try std.testing.expectEqual(@as(f32, 56), rects[1].x);
    try std.testing.expectEqual(@as(f32, 50), rects[0].h);
}

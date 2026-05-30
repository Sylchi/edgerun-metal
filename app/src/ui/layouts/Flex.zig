const std = @import("std");
const ui = @import("../core.zig");
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

const min_extent: f32 = 1.0;

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
    var main_sizes: [64]f32 = undefined;
    const count = @min(children.len, @min(out.len, main_sizes.len));
    const resolved_main_sizes = resolveMainSizes(bounds, children[0..count], options, &main_sizes);
    var cursor = Cursor.init(bounds, options);
    cursor.resolved_main_sizes = resolved_main_sizes;
    for (children[0..count], 0..) |child, index| {
        out[index] = cursor.next(child);
    }
    return out[0..count];
}

pub const Cursor = struct {
    inner: ui.Rect,
    options: Options,
    resolved_main_sizes: []const f32 = &.{},
    offset: f32 = 0,
    index: usize = 0,

    pub fn init(bounds: ui.Rect, options: Options) Cursor {
        return .{
            .inner = bounds.insetLtrb(options.padding.left, options.padding.top, options.padding.right, options.padding.bottom),
            .options = options,
        };
    }

    pub fn next(self: *Cursor, child: layout.Measurement) ui.Rect {
        const main_offset = self.nextMainOffset();
        const out = self.rectAt(main_offset, child);
        self.claimMainOffset(main_offset, child);
        return out;
    }

    pub fn nextWithinBounds(self: *Cursor, child: layout.Measurement) ?ui.Rect {
        const main_offset = self.nextMainOffset();
        const child_size = self.childLogicalSize(child);
        if (main_offset + child_size.w > self.innerMainSize()) return null;
        const out = self.rectAt(main_offset, child);
        self.claimMainOffset(main_offset, child);
        return out;
    }

    fn claimMainOffset(self: *Cursor, main_offset: f32, child: layout.Measurement) void {
        const child_size = self.childLogicalSize(child);
        self.offset = main_offset + child_size.w;
        self.index += 1;
    }

    fn nextMainOffset(self: Cursor) f32 {
        return self.offset + if (self.index == 0) 0 else self.options.gap;
    }

    fn rectAt(self: Cursor, main_offset: f32, child: layout.Measurement) ui.Rect {
        const child_size = self.childLogicalSize(child);
        const main_size = child_size.w;
        const cross_size = switch (self.options.cross_align) {
            .start => @min(child_size.h, self.innerCrossSize()),
            .stretch => self.innerCrossSize(),
        };
        return switch (self.options.axis) {
            .horizontal => ui.Rect.init(self.inner.x + main_offset, self.inner.y, main_size, cross_size),
            .vertical => ui.Rect.init(self.inner.x, self.inner.y + main_offset, cross_size, main_size),
        };
    }

    fn childLogicalSize(self: Cursor, child: layout.Measurement) ui.Size {
        var child_size = layout.toLogical(self.options.axis, child.preferred);
        if (self.index < self.resolved_main_sizes.len) {
            child_size.w = self.resolved_main_sizes[self.index];
        }
        return child_size;
    }

    fn innerMainSize(self: Cursor) f32 {
        return switch (self.options.axis) {
            .horizontal => self.inner.w,
            .vertical => self.inner.h,
        };
    }

    fn innerCrossSize(self: Cursor) f32 {
        return switch (self.options.axis) {
            .horizontal => self.inner.h,
            .vertical => self.inner.w,
        };
    }
};

pub fn resolveMainSizes(bounds: ui.Rect, children: []const layout.Measurement, options: Options, out: []f32) []f32 {
    const count = @min(children.len, out.len);
    if (count == 0) return out[0..0];

    const inner = bounds.insetLtrb(options.padding.left, options.padding.top, options.padding.right, options.padding.bottom);
    const available = switch (options.axis) {
        .horizontal => inner.w,
        .vertical => inner.h,
    };
    const total_gap = options.gap * @as(f32, @floatFromInt(count - 1));
    const available_children_main = @max(0.0, available - total_gap);
    var preferred_total: f32 = 0.0;
    var min_total: f32 = 0.0;
    for (children[0..count], 0..) |child, index| {
        const preferred = layout.toLogical(options.axis, child.preferred).w;
        const min_size = layout.toLogical(options.axis, child.min).w;
        out[index] = preferred;
        preferred_total += preferred;
        min_total += min_size;
    }

    if (preferred_total <= available_children_main) return out[0..count];

    if (min_total >= available_children_main) {
        const scale = if (min_total > 0.0) available_children_main / min_total else 0.0;
        for (children[0..count], 0..) |child, index| {
            const child_min = layout.toLogical(options.axis, child.min).w;
            out[index] = @max(min_extent, child_min * scale);
        }
        return out[0..count];
    }

    const overflow = preferred_total - available_children_main;
    const shrink_capacity = preferred_total - min_total;
    for (children[0..count], 0..) |child, index| {
        const child_preferred = layout.toLogical(options.axis, child.preferred).w;
        const child_min = layout.toLogical(options.axis, child.min).w;
        const child_shrink = child_preferred - child_min;
        const shrink = if (shrink_capacity > 0.0) overflow * (child_shrink / shrink_capacity) else 0.0;
        out[index] = @max(min_extent, child_preferred - shrink);
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

test "flex cursor places dynamic rows without scratch arrays" {
    var cursor = Cursor.init(ui.Rect.init(0, 0, 200, 84), .{ .axis = .vertical, .gap = 6, .padding = layout.Insets.uniform(8) });
    const first = cursor.nextWithinBounds(layout.Measurement.fixed(.{ .w = 120, .h = 30 })).?;
    const second = cursor.nextWithinBounds(layout.Measurement.fixed(.{ .w = 120, .h = 30 })).?;

    try std.testing.expect(cursor.nextWithinBounds(layout.Measurement.fixed(.{ .w = 120, .h = 30 })) == null);
    try std.testing.expectEqual(@as(f32, 8), first.x);
    try std.testing.expectEqual(@as(f32, 8), first.y);
    try std.testing.expectEqual(@as(f32, 44), second.y);
    try std.testing.expectEqual(@as(f32, 184), first.w);
}

test "flex shrinks overflowing horizontal children inside parent width" {
    const children = [_]layout.Measurement{
        layout.Measurement.flexible(.{ .w = 40, .h = 20 }, .{ .w = 120, .h = 20 }, .{ .w = 220, .h = 20 }),
        layout.Measurement.flexible(.{ .w = 40, .h = 20 }, .{ .w = 120, .h = 20 }, .{ .w = 220, .h = 20 }),
    };
    var out: [2]ui.Rect = undefined;
    const rects = place(ui.Rect.init(0, 0, 180, 40), &children, .{ .axis = .horizontal, .gap = 12 }, &out);

    try std.testing.expectEqual(@as(usize, 2), rects.len);
    try std.testing.expectEqual(@as(f32, 84), rects[0].w);
    try std.testing.expectEqual(@as(f32, 96), rects[1].x);
    try std.testing.expect(rects[1].x + rects[1].w <= 180.01);
}

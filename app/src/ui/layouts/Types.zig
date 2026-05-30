const std = @import("std");
const math = @import("../../math.zig");
const ui = @import("../core.zig");

pub const Axis = enum {
    horizontal,
    vertical,
};

pub const AxisConstraint = union(enum) {
    unconstrained,
    at_most: f32,
    exact: f32,

    pub fn limit(self: AxisConstraint, fallback: f32) f32 {
        return switch (self) {
            .unconstrained => fallback,
            .at_most => |value| sanitizeSize(value),
            .exact => |value| sanitizeSize(value),
        };
    }

    pub fn exactValue(self: AxisConstraint) ?f32 {
        return switch (self) {
            .exact => |value| sanitizeSize(value),
            else => null,
        };
    }
};

pub const TextWrapPolicy = enum {
    auto,
    wrap,
    nowrap,
    truncate,
};

pub const Insets = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn uniform(value: f32) Insets {
        const safe = sanitizeSize(value);
        return .{ .top = safe, .right = safe, .bottom = safe, .left = safe };
    }

    pub fn horizontal(self: Insets) f32 {
        return self.left + self.right;
    }

    pub fn vertical(self: Insets) f32 {
        return self.top + self.bottom;
    }
};

pub const Constraints = struct {
    width: AxisConstraint = .unconstrained,
    height: AxisConstraint = .unconstrained,
    text_wrap: TextWrapPolicy = .auto,

    pub fn inner(self: Constraints, insets: Insets) Constraints {
        return .{
            .width = shrinkConstraint(self.width, insets.horizontal()),
            .height = shrinkConstraint(self.height, insets.vertical()),
            .text_wrap = self.text_wrap,
        };
    }
};

pub const Measurement = struct {
    min: ui.Size,
    preferred: ui.Size,
    max: ui.Size,

    pub fn fixed(size: ui.Size) Measurement {
        const safe = sanitizeSize2(size);
        return .{ .min = safe, .preferred = safe, .max = safe };
    }

    pub fn flexible(min_size: ui.Size, preferred_size: ui.Size, max_size: ui.Size) Measurement {
        const min_safe = sanitizeSize2(min_size);
        const preferred_safe = maxSize(min_safe, sanitizeSize2(preferred_size));
        const max_safe = maxSize(preferred_safe, sanitizeSize2(max_size));
        return .{ .min = min_safe, .preferred = preferred_safe, .max = max_safe };
    }

    pub fn withInsets(self: Measurement, insets: Insets) Measurement {
        return .{
            .min = addInsets(self.min, insets),
            .preferred = addInsets(self.preferred, insets),
            .max = addInsets(self.max, insets),
        };
    }

    pub fn applyExact(self: Measurement, constraints: Constraints) Measurement {
        const preferred = applyExactSize(self.preferred, constraints);
        const min_size = minSize(self.min, preferred);
        const max_size = maxSize(self.max, preferred);
        return .{ .min = min_size, .preferred = preferred, .max = max_size };
    }
};

pub const TextMetrics = struct {
    line_height: f32,
    average_char_width: f32,
    max_lines: usize,
};

pub fn measureText(value: []const u8, constraints: Constraints, metrics: TextMetrics) Measurement {
    if (value.len == 0 or metrics.max_lines == 0) return Measurement.fixed(.{ .w = 0, .h = 0 });
    const line_height = sanitizePositive(metrics.line_height, default_line_height);
    const average_char_width = sanitizePositive(metrics.average_char_width, default_average_char_width);
    const char_count = @as(f32, @floatFromInt(utf8CodepointCount(value)));
    const natural_width = char_count * average_char_width;
    const min_width = @max(average_char_width, @as(f32, @floatFromInt(longestUtf8Run(value))) * average_char_width);
    const wrap_width = constraints.width.limit(natural_width);
    const should_wrap = switch (constraints.text_wrap) {
        .wrap => true,
        .auto => constraints.width != .unconstrained,
        .nowrap, .truncate => false,
    };

    const measured_width = if (should_wrap) @min(natural_width, @max(average_char_width, wrap_width)) else natural_width;
    const line_count = if (should_wrap)
        wrappedLineCount(value, measured_width, average_char_width, metrics.max_lines)
    else
        @as(usize, 1);
    const preferred_height = @as(f32, @floatFromInt(@max(@as(usize, 1), line_count))) * line_height;
    const preferred = applyExactSize(.{ .w = measured_width, .h = preferred_height }, constraints);
    const max_width = switch (constraints.width) {
        .unconstrained => natural_width,
        .at_most => |value_max| sanitizeSize(value_max),
        .exact => |value_exact| sanitizeSize(value_exact),
    };
    return Measurement.flexible(
        .{ .w = @min(min_width, preferred.w), .h = @min(line_height, preferred.h) },
        preferred,
        .{ .w = @max(preferred.w, max_width), .h = @max(preferred.h, preferred_height) },
    );
}

pub fn toLogical(axis: Axis, size: ui.Size) ui.Size {
    return switch (axis) {
        .horizontal => size,
        .vertical => .{ .w = size.h, .h = size.w },
    };
}

pub fn fromLogical(axis: Axis, size: ui.Size) ui.Size {
    return switch (axis) {
        .horizontal => size,
        .vertical => .{ .w = size.h, .h = size.w },
    };
}

fn shrinkConstraint(constraint: AxisConstraint, amount: f32) AxisConstraint {
    const safe_amount = sanitizeSize(amount);
    return switch (constraint) {
        .unconstrained => .unconstrained,
        .at_most => |value| .{ .at_most = @max(0, sanitizeSize(value) - safe_amount) },
        .exact => |value| .{ .exact = @max(0, sanitizeSize(value) - safe_amount) },
    };
}

fn applyExactSize(size: ui.Size, constraints: Constraints) ui.Size {
    return .{
        .w = constraints.width.exactValue() orelse size.w,
        .h = constraints.height.exactValue() orelse size.h,
    };
}

fn addInsets(size: ui.Size, insets: Insets) ui.Size {
    return .{
        .w = sanitizeSize(size.w + insets.horizontal()),
        .h = sanitizeSize(size.h + insets.vertical()),
    };
}

fn minSize(left: ui.Size, right: ui.Size) ui.Size {
    return .{ .w = @min(left.w, right.w), .h = @min(left.h, right.h) };
}

fn maxSize(left: ui.Size, right: ui.Size) ui.Size {
    return .{ .w = @max(left.w, right.w), .h = @max(left.h, right.h) };
}

fn sanitizeSize2(size: ui.Size) ui.Size {
    return .{ .w = sanitizeSize(size.w), .h = sanitizeSize(size.h) };
}

fn sanitizeSize(value: f32) f32 {
    if (!math.isFiniteF(value) or value <= 0) return 0;
    return value;
}

fn sanitizePositive(value: f32, fallback: f32) f32 {
    if (!math.isFiniteF(value) or value <= 0) return fallback;
    return value;
}

fn wrappedLineCount(value: []const u8, width: f32, average_char_width: f32, max_lines: usize) usize {
    if (value.len == 0 or max_lines == 0) return 0;
    const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, width / average_char_width))));
    var byte_cursor: usize = 0;
    var line_count: usize = 0;
    while (line_count < max_lines) : (line_count += 1) {
        byte_cursor = ui.skipAsciiSpace(value, byte_cursor);
        if (byte_cursor >= value.len) return line_count;
        byte_cursor = ui.wrappedLine(value, byte_cursor, char_capacity).next;
    }
    return line_count;
}

fn utf8CodepointCount(value: []const u8) usize {
    var index: usize = 0;
    var count: usize = 0;
    while (ui.nextCodepoint(value, &index)) |_| count += 1;
    return count;
}

fn longestUtf8Run(value: []const u8) usize {
    var longest: usize = 0;
    var current: usize = 0;
    var index: usize = 0;
    while (ui.nextCodepoint(value, &index)) |codepoint| {
        if (isAsciiSpace(codepoint)) {
            longest = @max(longest, current);
            current = 0;
        } else {
            current += 1;
        }
    }
    return @max(longest, current);
}

fn isAsciiSpace(value: u21) bool {
    return switch (value) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}

const default_line_height: f32 = 16.0;
const default_average_char_width: f32 = 8.0;

test "layout constraints shrink by padding without margins" {
    const outer = Constraints{
        .width = .{ .exact = 320 },
        .height = .{ .at_most = 200 },
        .text_wrap = .wrap,
    };
    const inner_constraints = outer.inner(.{ .left = 12, .right = 8, .top = 4, .bottom = 6 });

    try std.testing.expectEqual(@as(f32, 300), inner_constraints.width.exact);
    try std.testing.expectEqual(@as(f32, 190), inner_constraints.height.at_most);
    try std.testing.expectEqual(TextWrapPolicy.wrap, inner_constraints.text_wrap);
}

test "text measurement wraps when width is constrained" {
    const value = "Browser asks resolver answers cache remembers";
    const loose = measureText(value, .{ .width = .unconstrained, .text_wrap = .nowrap }, .{
        .line_height = 18,
        .average_char_width = 9,
        .max_lines = 4,
    });
    const narrow = measureText(value, .{ .width = .{ .exact = 120 }, .text_wrap = .wrap }, .{
        .line_height = 18,
        .average_char_width = 9,
        .max_lines = 4,
    });

    try std.testing.expect(narrow.preferred.h > loose.preferred.h);
    try std.testing.expectEqual(@as(f32, 120), narrow.preferred.w);
}

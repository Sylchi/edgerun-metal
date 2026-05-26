const std = @import("std");
const ui = @import("../ui.zig");

pub const exact_tolerance: u8 = 0;
pub const hardware_tolerance: u8 = 2;
pub const missing_mismatch: usize = std.math.maxInt(usize);

pub const PixelDiff = struct {
    width: usize,
    height: usize,
    pixel_count: usize,
    mismatch_count: usize,
    max_channel_delta: u8,
    first_mismatch_index: usize = missing_mismatch,
    first_expected: ui.Color = .clear,
    first_actual: ui.Color = .clear,
    worst_mismatch_index: usize = missing_mismatch,
    worst_expected: ui.Color = .clear,
    worst_actual: ui.Color = .clear,
    actual_minus_expected: [signed_delta_bucket_count]usize = [_]usize{0} ** signed_delta_bucket_count,

    pub fn valid(self: PixelDiff) bool {
        return self.pixel_count != 0 and self.mismatch_count == 0 and self.max_channel_delta == 0;
    }

    pub fn firstMismatchX(self: PixelDiff) usize {
        return if (self.first_mismatch_index == missing_mismatch or self.width == 0) 0 else self.first_mismatch_index % self.width;
    }

    pub fn firstMismatchY(self: PixelDiff) usize {
        return if (self.first_mismatch_index == missing_mismatch or self.width == 0) 0 else self.first_mismatch_index / self.width;
    }

    pub fn worstMismatchX(self: PixelDiff) usize {
        return if (self.worst_mismatch_index == missing_mismatch or self.width == 0) 0 else self.worst_mismatch_index % self.width;
    }

    pub fn worstMismatchY(self: PixelDiff) usize {
        return if (self.worst_mismatch_index == missing_mismatch or self.width == 0) 0 else self.worst_mismatch_index / self.width;
    }

    fn recordSignedDelta(self: *PixelDiff, expected: ui.Color, actual: ui.Color) void {
        self.recordChannelDelta(expected.r, actual.r);
        self.recordChannelDelta(expected.g, actual.g);
        self.recordChannelDelta(expected.b, actual.b);
        self.recordChannelDelta(expected.a, actual.a);
    }

    fn recordChannelDelta(self: *PixelDiff, expected: u8, actual: u8) void {
        const delta = @as(i16, @intCast(actual)) - @as(i16, @intCast(expected));
        if (signedDeltaBucket(delta)) |bucket| self.actual_minus_expected[bucket] += 1;
    }
};

const signed_delta_min: i16 = -8;
const signed_delta_max: i16 = 8;
const signed_delta_bucket_count: usize = @intCast(signed_delta_max - signed_delta_min + 1);

pub fn compareExact(width: usize, height: usize, expected: []const ui.Color, actual: []const ui.Color) !PixelDiff {
    return compare(width, height, expected, actual, exact_tolerance);
}

pub fn compareHardware(width: usize, height: usize, expected: []const ui.Color, actual: []const ui.Color) !PixelDiff {
    return compare(width, height, expected, actual, hardware_tolerance);
}

pub fn compare(width: usize, height: usize, expected: []const ui.Color, actual: []const ui.Color, tolerance: u8) !PixelDiff {
    if (width == 0 or height == 0) return error.InvalidPixelFrame;
    const pixel_count = width * height;
    if (expected.len < pixel_count or actual.len < pixel_count) return error.InvalidPixelFrame;
    var diff = PixelDiff{
        .width = width,
        .height = height,
        .pixel_count = pixel_count,
        .mismatch_count = 0,
        .max_channel_delta = 0,
    };
    for (expected[0..pixel_count], actual[0..pixel_count], 0..) |want, got, index| {
        const delta = maxPixelDelta(want, got);
        if (delta > diff.max_channel_delta) {
            diff.max_channel_delta = delta;
            diff.worst_mismatch_index = index;
            diff.worst_expected = want;
            diff.worst_actual = got;
        }
        if (delta > tolerance) {
            diff.mismatch_count += 1;
            diff.recordSignedDelta(want, got);
            if (diff.first_mismatch_index == missing_mismatch) {
                diff.first_mismatch_index = index;
                diff.first_expected = want;
                diff.first_actual = got;
            }
        }
    }
    return diff;
}

fn signedDeltaBucket(delta: i16) ?usize {
    if (delta < signed_delta_min or delta > signed_delta_max) return null;
    return @intCast(delta - signed_delta_min);
}

fn maxPixelDelta(a: ui.Color, b: ui.Color) u8 {
    return @max(
        @max(channelDelta(a.r, b.r), channelDelta(a.g, b.g)),
        @max(channelDelta(a.b, b.b), channelDelta(a.a, b.a)),
    );
}

fn channelDelta(a: u8, b: u8) u8 {
    return if (a >= b) a - b else b - a;
}

test "pixel parity reports exact first mismatch coordinates" {
    const expected = [_]ui.Color{
        .accent,
        .text,
        .clear,
        .bg,
    };
    const actual_equal = expected;
    const equal = try compareExact(2, 2, &expected, &actual_equal);
    try std.testing.expect(equal.valid());

    const actual_mismatch = [_]ui.Color{
        .accent,
        .text,
        .clear,
        .panel,
    };
    const diff = try compareExact(2, 2, &expected, &actual_mismatch);
    try std.testing.expect(!diff.valid());
    try std.testing.expectEqual(@as(usize, 1), diff.mismatch_count);
    try std.testing.expectEqual(@as(usize, 3), diff.first_mismatch_index);
    try std.testing.expectEqual(@as(usize, 1), diff.firstMismatchX());
    try std.testing.expectEqual(@as(usize, 1), diff.firstMismatchY());
    try std.testing.expectEqual(ui.Color.bg, diff.first_expected);
    try std.testing.expectEqual(ui.Color.panel, diff.first_actual);
    try std.testing.expectEqual(@as(usize, 3), diff.worst_mismatch_index);
    try std.testing.expectEqual(@as(usize, 1), diff.worstMismatchX());
    try std.testing.expectEqual(@as(usize, 1), diff.worstMismatchY());
    try std.testing.expectEqual(ui.Color.bg, diff.worst_expected);
    try std.testing.expectEqual(ui.Color.panel, diff.worst_actual);
    try std.testing.expect(diff.max_channel_delta != 0);
}

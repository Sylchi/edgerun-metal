const std = @import("std");

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    pub fn inset(self: Rect, dx: f32, dy: f32) Rect {
        return .{
            .x = self.x + dx,
            .y = self.y + dy,
            .w = max(self.w - dx * 2.0, 0.0),
            .h = max(self.h - dy * 2.0, 0.0),
        };
    }

    pub fn insetUniform(self: Rect, amount: f32) Rect {
        return self.inset(amount, amount);
    }

    pub fn insetLtrb(self: Rect, left: f32, top: f32, edge_right: f32, edge_bottom: f32) Rect {
        return .{
            .x = self.x + left,
            .y = self.y + top,
            .w = max(self.w - left - edge_right, 0.0),
            .h = max(self.h - top - edge_bottom, 0.0),
        };
    }

    pub fn withHeightCentered(self: Rect, height: f32) Rect {
        const clamped = clamp(height, 0.0, self.h);
        return .{
            .x = self.x,
            .y = self.y + (self.h - clamped) * 0.5,
            .w = self.w,
            .h = clamped,
        };
    }

    pub fn withWidthCentered(self: Rect, width: f32) Rect {
        const clamped = clamp(width, 0.0, self.w);
        return .{
            .x = self.x + (self.w - clamped) * 0.5,
            .y = self.y,
            .w = clamped,
            .h = self.h,
        };
    }

    pub fn right(self: Rect, width: f32) Rect {
        return .{
            .x = self.x + self.w - width,
            .y = self.y,
            .w = width,
            .h = self.h,
        };
    }

    pub fn bottom(self: Rect, height: f32) Rect {
        return .{
            .x = self.x,
            .y = self.y + self.h - height,
            .w = self.w,
            .h = height,
        };
    }

    pub fn containsInclusive(self: Rect, x: f32, y: f32) bool {
        return x >= self.x and y >= self.y and x <= self.x + self.w and y <= self.y + self.h;
    }

    pub fn containsExclusive(self: Rect, x: f32, y: f32) bool {
        return x >= self.x and y >= self.y and x < self.x + self.w and y < self.y + self.h;
    }

    pub fn intersect(self: Rect, other: Rect) ?Rect {
        const x0 = max(self.x, other.x);
        const y0 = max(self.y, other.y);
        const x1 = min(self.x + self.w, other.x + other.w);
        const y1 = min(self.y + self.h, other.y + other.h);
        const width = x1 - x0;
        const height = y1 - y0;
        if (width <= 0.0 or height <= 0.0) return null;
        return .{ .x = x0, .y = y0, .w = width, .h = height };
    }

    pub fn valid(self: Rect) bool {
        return finite(self.x) and finite(self.y) and finite(self.w) and finite(self.h) and self.w > 0.0 and self.h > 0.0;
    }

    pub fn usable(self: Rect) bool {
        return finite(self.x) and finite(self.y) and finite(self.w) and finite(self.h) and self.w >= 0.0 and self.h >= 0.0;
    }
};

pub fn asciiLen(text: ?[]const u8) usize {
    return if (text) |value| value.len else 0;
}

pub fn clamp(value: f32, min_value: f32, max_value: f32) f32 {
    return min(max(value, min_value), max_value);
}

pub fn min(a: f32, b: f32) f32 {
    return if (a < b) a else b;
}

pub fn max(a: f32, b: f32) f32 {
    return if (a > b) a else b;
}

pub fn finite(value: f32) bool {
    const bits: u32 = @bitCast(value);
    return (bits & 0x7f80_0000) != 0x7f80_0000;
}

test "rect helpers match the C primitive bounds semantics" {
    const bounds = Rect.init(10.0, 20.0, 100.0, 60.0);

    const inset = bounds.inset(8.0, 4.0);
    try std.testing.expectEqual(@as(f32, 18.0), inset.x);
    try std.testing.expectEqual(@as(f32, 24.0), inset.y);
    try std.testing.expectEqual(@as(f32, 84.0), inset.w);
    try std.testing.expectEqual(@as(f32, 52.0), inset.h);

    const ltrb = bounds.insetLtrb(2.0, 3.0, 5.0, 7.0);
    try std.testing.expectEqual(@as(f32, 12.0), ltrb.x);
    try std.testing.expectEqual(@as(f32, 23.0), ltrb.y);
    try std.testing.expectEqual(@as(f32, 93.0), ltrb.w);
    try std.testing.expectEqual(@as(f32, 50.0), ltrb.h);

    const centered_h = bounds.withHeightCentered(20.0);
    try std.testing.expectEqual(@as(f32, 40.0), centered_h.y);
    try std.testing.expectEqual(@as(f32, 20.0), centered_h.h);

    const centered_w = bounds.withWidthCentered(40.0);
    try std.testing.expectEqual(@as(f32, 40.0), centered_w.x);
    try std.testing.expectEqual(@as(f32, 40.0), centered_w.w);

    const right = bounds.right(24.0);
    try std.testing.expectEqual(@as(f32, 86.0), right.x);
    try std.testing.expectEqual(@as(f32, 24.0), right.w);

    const bottom = bounds.bottom(16.0);
    try std.testing.expectEqual(@as(f32, 64.0), bottom.y);
    try std.testing.expectEqual(@as(f32, 16.0), bottom.h);
}

test "rect validation hit and intersection semantics match C primitives" {
    const bounds = Rect.init(10.0, 20.0, 100.0, 60.0);

    try std.testing.expect(bounds.containsInclusive(10.0, 20.0));
    try std.testing.expect(bounds.containsInclusive(110.0, 80.0));
    try std.testing.expect(!bounds.containsInclusive(111.0, 80.0));

    const intersection = bounds.intersect(Rect.init(50.0, 40.0, 80.0, 80.0)).?;
    try std.testing.expectEqual(@as(f32, 50.0), intersection.x);
    try std.testing.expectEqual(@as(f32, 40.0), intersection.y);
    try std.testing.expectEqual(@as(f32, 60.0), intersection.w);
    try std.testing.expectEqual(@as(f32, 40.0), intersection.h);
    try std.testing.expect(bounds.intersect(Rect.init(200.0, 200.0, 10.0, 10.0)) == null);
    try std.testing.expect(bounds.intersect(Rect.init(110.0, 20.0, 10.0, 10.0)) == null);

    try std.testing.expect(bounds.valid());
    try std.testing.expect(!Rect.init(0.0, 0.0, 0.0, 1.0).valid());
    try std.testing.expect(!finite(std.math.nan(f32)));
}

test "primitive scalar and ascii helpers match C semantics" {
    try std.testing.expectEqual(@as(f32, 2.0), clamp(4.0, 0.0, 2.0));
    try std.testing.expectEqual(@as(f32, 0.0), clamp(-1.0, 0.0, 2.0));
    try std.testing.expectEqual(@as(f32, 1.5), clamp(1.5, 0.0, 2.0));
    try std.testing.expectEqual(@as(f32, 1.0), min(1.0, 2.0));
    try std.testing.expectEqual(@as(f32, 2.0), max(1.0, 2.0));
    try std.testing.expectEqual(@as(usize, 0), asciiLen(null));
    try std.testing.expectEqual(@as(usize, 0), asciiLen(""));
    try std.testing.expectEqual(@as(usize, 6), asciiLen("Ledger"));
}

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
    if (inset.x != 18.0) return error.TestExpectedEqual;
    if (inset.y != 24.0) return error.TestExpectedEqual;
    if (inset.w != 84.0) return error.TestExpectedEqual;
    if (inset.h != 52.0) return error.TestExpectedEqual;

    const ltrb = bounds.insetLtrb(2.0, 3.0, 5.0, 7.0);
    if (ltrb.x != 12.0) return error.TestExpectedEqual;
    if (ltrb.y != 23.0) return error.TestExpectedEqual;
    if (ltrb.w != 93.0) return error.TestExpectedEqual;
    if (ltrb.h != 50.0) return error.TestExpectedEqual;

    const centered_h = bounds.withHeightCentered(20.0);
    if (centered_h.y != 40.0) return error.TestExpectedEqual;
    if (centered_h.h != 20.0) return error.TestExpectedEqual;

    const centered_w = bounds.withWidthCentered(40.0);
    if (centered_w.x != 40.0) return error.TestExpectedEqual;
    if (centered_w.w != 40.0) return error.TestExpectedEqual;

    const right = bounds.right(24.0);
    if (right.x != 86.0) return error.TestExpectedEqual;
    if (right.w != 24.0) return error.TestExpectedEqual;

    const bottom = bounds.bottom(16.0);
    if (bottom.y != 64.0) return error.TestExpectedEqual;
    if (bottom.h != 16.0) return error.TestExpectedEqual;
}

test "rect validation hit and intersection semantics match C primitives" {
    const bounds = Rect.init(10.0, 20.0, 100.0, 60.0);

    if (!bounds.containsInclusive(10.0, 20.0)) return error.TestExpectedTrue;
    if (!bounds.containsInclusive(110.0, 80.0)) return error.TestExpectedTrue;
    if (bounds.containsInclusive(111.0, 80.0)) return error.TestExpectedFalse;

    const intersection = bounds.intersect(Rect.init(50.0, 40.0, 80.0, 80.0)).?;
    if (intersection.x != 50.0) return error.TestExpectedEqual;
    if (intersection.y != 40.0) return error.TestExpectedEqual;
    if (intersection.w != 60.0) return error.TestExpectedEqual;
    if (intersection.h != 40.0) return error.TestExpectedEqual;
    if (bounds.intersect(Rect.init(200.0, 200.0, 10.0, 10.0)) != null) return error.TestExpectedNull;
    if (bounds.intersect(Rect.init(110.0, 20.0, 10.0, 10.0)) != null) return error.TestExpectedNull;

    if (!bounds.valid()) return error.TestExpectedTrue;
    if (Rect.init(0.0, 0.0, 0.0, 1.0).valid()) return error.TestExpectedFalse;
    if (finite(@as(f32, @bitCast(@as(u32, 0x7fc0_0000))))) return error.TestExpectedFalse;
}

test "primitive scalar and ascii helpers match C semantics" {
    if (clamp(4.0, 0.0, 2.0) != 2.0) return error.TestExpectedEqual;
    if (clamp(-1.0, 0.0, 2.0) != 0.0) return error.TestExpectedEqual;
    if (clamp(1.5, 0.0, 2.0) != 1.5) return error.TestExpectedEqual;
    if (min(1.0, 2.0) != 1.0) return error.TestExpectedEqual;
    if (max(1.0, 2.0) != 2.0) return error.TestExpectedEqual;
    if (asciiLen(null) != 0) return error.TestExpectedEqual;
    if (asciiLen("") != 0) return error.TestExpectedEqual;
    if (asciiLen("Ledger") != 6) return error.TestExpectedEqual;
}

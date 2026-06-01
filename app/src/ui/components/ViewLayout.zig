const ui = @import("../core.zig");
const primitives = @import("Primitives.zig");

pub const StackCursor = struct {
    bounds: ui.Rect,
    gap: f32 = 0.0,
    cursor_y: f32,

    pub fn init(bounds: ui.Rect, gap: f32) StackCursor {
        return .{ .bounds = bounds, .gap = gap, .cursor_y = bounds.y };
    }

    pub fn take(self: *StackCursor, height: f32) ui.Rect {
        const resolved_h = @max(primitives.min_extent, height);
        const rect = ui.Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, resolved_h);
        self.cursor_y += resolved_h + self.gap;
        return rect;
    }

    pub fn takeIfFits(self: *StackCursor, height: f32) ?ui.Rect {
        if (self.cursor_y + height > self.bounds.y + self.bounds.h) return null;
        return self.take(height);
    }

    pub fn skip(self: *StackCursor, amount: f32) void {
        self.cursor_y += amount;
    }

    pub fn remaining(self: StackCursor) ui.Rect {
        const h = @max(primitives.min_extent, self.bounds.y + self.bounds.h - self.cursor_y);
        return ui.Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, h);
    }
};

pub const RowCursor = struct {
    bounds: ui.Rect,
    gap: f32 = 0.0,
    cursor_x: f32,

    pub fn init(bounds: ui.Rect, gap: f32) RowCursor {
        return .{ .bounds = bounds, .gap = gap, .cursor_x = bounds.x };
    }

    pub fn take(self: *RowCursor, width: f32) ui.Rect {
        const resolved_w = @max(primitives.min_extent, width);
        const rect = ui.Rect.init(self.cursor_x, self.bounds.y, resolved_w, self.bounds.h);
        self.cursor_x += resolved_w + self.gap;
        return rect;
    }

    pub fn remaining(self: RowCursor) ui.Rect {
        const w = @max(primitives.min_extent, self.bounds.x + self.bounds.w - self.cursor_x);
        return ui.Rect.init(self.cursor_x, self.bounds.y, w, self.bounds.h);
    }
};

pub const Split = struct {
    first: ui.Rect,
    second: ui.Rect,
};

pub const Grid = struct {
    bounds: ui.Rect,
    columns: usize,
    gap: f32,
    item_h: f32,

    pub fn item(self: Grid, index: usize) ui.Rect {
        const columns_value = @max(@as(usize, 1), self.columns);
        const col = index % columns_value;
        const row_value = index / columns_value;
        const col_f = @as(f32, @floatFromInt(col));
        const row_f = @as(f32, @floatFromInt(row_value));
        const column_count_f = @as(f32, @floatFromInt(columns_value));
        const item_w = @max(primitives.min_extent, (self.bounds.w - self.gap * @as(f32, @floatFromInt(columns_value - 1))) / column_count_f);
        return ui.Rect.init(
            self.bounds.x + col_f * (item_w + self.gap),
            self.bounds.y + row_f * (self.item_h + self.gap),
            item_w,
            self.item_h,
        );
    }

    pub fn height(self: Grid, item_count: usize) f32 {
        if (item_count == 0) return 0.0;
        const rows = (item_count + @max(@as(usize, 1), self.columns) - 1) / @max(@as(usize, 1), self.columns);
        return @as(f32, @floatFromInt(rows)) * self.item_h + @as(f32, @floatFromInt(rows - 1)) * self.gap;
    }
};

pub fn splitLeft(bounds: ui.Rect, width: f32, gap: f32) Split {
    const first_w = @min(bounds.w, @max(primitives.min_extent, width));
    const rest_x = bounds.x + first_w + gap;
    return .{
        .first = ui.Rect.init(bounds.x, bounds.y, first_w, bounds.h),
        .second = ui.Rect.init(rest_x, bounds.y, @max(primitives.min_extent, bounds.x + bounds.w - rest_x), bounds.h),
    };
}

pub fn splitRight(bounds: ui.Rect, width: f32, gap: f32) Split {
    const second_w = @min(bounds.w, @max(primitives.min_extent, width));
    const second_x = bounds.x + @max(0.0, bounds.w - second_w);
    return .{
        .first = ui.Rect.init(bounds.x, bounds.y, @max(primitives.min_extent, second_x - gap - bounds.x), bounds.h),
        .second = ui.Rect.init(second_x, bounds.y, second_w, bounds.h),
    };
}

pub fn splitTop(bounds: ui.Rect, height: f32, gap: f32) Split {
    const first_h = @min(bounds.h, @max(primitives.min_extent, height));
    const rest_y = bounds.y + first_h + gap;
    return .{
        .first = ui.Rect.init(bounds.x, bounds.y, bounds.w, first_h),
        .second = ui.Rect.init(bounds.x, rest_y, bounds.w, @max(primitives.min_extent, bounds.y + bounds.h - rest_y)),
    };
}

pub fn splitBottom(bounds: ui.Rect, height: f32, gap: f32) Split {
    const second_h = @min(bounds.h, @max(primitives.min_extent, height));
    const second_y = bounds.y + @max(0.0, bounds.h - second_h);
    return .{
        .first = ui.Rect.init(bounds.x, bounds.y, bounds.w, @max(primitives.min_extent, second_y - gap - bounds.y)),
        .second = ui.Rect.init(bounds.x, second_y, bounds.w, second_h),
    };
}

const std = @import("std");
const ui = @import("core.zig");

pub const Error = error{
    InteractionBudgetExceeded,
    InvalidInteractionBounds,
    MissingInteractionCollector,
};

pub const Region = struct {
    slot: u32 = 0,
    kind: ui.HitKind,
    id: u32,
    bounds: ui.Rect,
};

pub const Collector = struct {
    regions: []Region,
    len: usize = 0,

    pub fn init(regions: []Region) Collector {
        return .{ .regions = regions };
    }

    pub fn clear(self: *Collector) void {
        self.len = 0;
    }

    pub fn add(self: *Collector, region: Region) Error!void {
        if (!region.bounds.valid()) return error.InvalidInteractionBounds;
        if (self.len == self.regions.len) return error.InteractionBudgetExceeded;
        self.regions[self.len] = region;
        self.len += 1;
    }

    pub fn addHit(self: *Collector, bounds: ui.Rect, kind: ui.HitKind, id: u32) Error!void {
        try self.add(.{ .kind = kind, .id = id, .bounds = bounds });
    }

    pub fn written(self: Collector) []const Region {
        return self.regions[0..self.len];
    }
};

pub fn hitTest(regions: []const Region, x: f32, y: f32) ?Region {
    var index = regions.len;
    while (index > 0) {
        index -= 1;
        const region = regions[index];
        if (region.bounds.containsExclusive(x, y)) return region;
    }
    return null;
}

test "interaction collector records regions outside render commands" {
    var regions: [2]Region = undefined;
    var collector = Collector.init(&regions);

    try collector.add(.{ .kind = .button, .id = 1, .bounds = ui.Rect.init(0, 0, 10, 10) });
    try collector.add(.{ .kind = .button, .id = 2, .bounds = ui.Rect.init(0, 0, 10, 10) });

    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 2), hitTest(collector.written(), 4, 4).?.id);
}

test "interaction collector rejects invalid regions before consuming budget" {
    var regions: [1]Region = undefined;
    var collector = Collector.init(&regions);

    try std.testing.expectError(error.InvalidInteractionBounds, collector.addHit(ui.Rect.init(0, 0, 0, 10), .button, 1));
    try std.testing.expectEqual(@as(usize, 0), collector.written().len);

    try collector.addHit(ui.Rect.init(0, 0, 10, 10), .button, 2);
    try std.testing.expectError(error.InteractionBudgetExceeded, collector.addHit(ui.Rect.init(10, 0, 10, 10), .button, 3));
}

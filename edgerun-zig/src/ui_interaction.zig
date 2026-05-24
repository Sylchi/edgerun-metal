const std = @import("std");
const ui = @import("ui.zig");

pub const Error = error{
    InteractionBudgetExceeded,
    InvalidInteractionBounds,
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
        if (self.len == self.regions.len) return error.InteractionBudgetExceeded;
        self.regions[self.len] = region;
        self.len += 1;
    }

    pub fn written(self: Collector) []const Region {
        return self.regions[0..self.len];
    }

    pub fn emitSceneHits(self: Collector, scene: *ui.Scene) ui.RenderError!void {
        for (self.written()) |region| {
            try scene.pushHit(.{
                .slot = region.slot,
                .kind = region.kind,
                .id = region.id,
                .bounds = region.bounds,
            });
        }
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

test "interaction collector can emit legacy scene hits" {
    var regions: [1]Region = undefined;
    var collector = Collector.init(&regions);
    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try collector.add(.{ .slot = 9, .kind = .row_item, .id = 7, .bounds = ui.Rect.init(0, 0, 12, 12) });
    try collector.emitSceneHits(&scene);

    try std.testing.expectEqual(@as(usize, 1), scene.written().len);
    try std.testing.expectEqual(@as(u32, 9), scene.written()[0].hit.slot);
    try std.testing.expectEqual(@as(u32, 7), scene.written()[0].hit.id);
}

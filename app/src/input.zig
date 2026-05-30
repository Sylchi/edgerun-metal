const std = @import("std");
const ui = @import("ui/core.zig");
const interaction = @import("ui/interaction.zig");

pub fn hitTest(regions: []const interaction.Region, x: f32, y: f32) ?interaction.Region {
    return interaction.hitTest(regions, x, y);
}

pub fn dragSourceAt(commands: []const ui.Command, x: f32, y: f32) ?ui.DragSource {
    var index = commands.len;
    while (index > 0) {
        index -= 1;
        switch (commands[index]) {
            .drag_source => |source| if (source.bounds.containsInclusive(x, y)) return source,
            else => {},
        }
    }
    return null;
}

pub fn dropTargetAt(commands: []const ui.Command, x: f32, y: f32, scope_id: u32) ?ui.DropTarget {
    var index = commands.len;
    while (index > 0) {
        index -= 1;
        switch (commands[index]) {
            .drop_target => |target| if (target.scope_id == scope_id and target.bounds.containsInclusive(x, y)) return target,
            else => {},
        }
    }
    return null;
}

test "input queries interaction regions and drag state without owning ui state" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 10, 10), .button, 1);
    try collector.addHit(ui.Rect.init(0, 0, 10, 10), .button, 2);
    try scene.pushDragSource(.{ .scope_id = 7, .item_id = 3, .index = 1, .bounds = ui.Rect.init(0, 0, 10, 10) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 4, .bounds = ui.Rect.init(0, 0, 10, 10) });

    try std.testing.expectEqual(@as(u32, 2), hitTest(collector.written(), 4, 4).?.id);
    try std.testing.expectEqual(@as(u32, 3), dragSourceAt(scene.written(), 4, 4).?.item_id);
    try std.testing.expectEqual(@as(usize, 4), dropTargetAt(scene.written(), 4, 4, 7).?.index);
    try std.testing.expect(dropTargetAt(scene.written(), 4, 4, 8) == null);
}

const std = @import("std");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");

pub fn hitTest(commands: []const ui.Command, x: f32, y: f32) ?ui.Hit {
    var index = commands.len;
    while (index > 0) {
        index -= 1;
        switch (commands[index]) {
            .hit => |hit| if (hit.bounds.containsExclusive(x, y)) return hit,
            else => {},
        }
    }
    return null;
}

pub fn regionHitTest(regions: []const interaction.Region, x: f32, y: f32) ?interaction.Region {
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

test "input queries structural hits without owning ui state" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 1, .bounds = ui.Rect.init(0, 0, 10, 10) });
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 2, .bounds = ui.Rect.init(0, 0, 10, 10) });
    try scene.pushDragSource(.{ .scope_id = 7, .item_id = 3, .index = 1, .bounds = ui.Rect.init(0, 0, 10, 10) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 4, .bounds = ui.Rect.init(0, 0, 10, 10) });

    try std.testing.expectEqual(@as(u32, 2), hitTest(scene.written(), 4, 4).?.id);
    try std.testing.expectEqual(@as(u32, 3), dragSourceAt(scene.written(), 4, 4).?.item_id);
    try std.testing.expectEqual(@as(usize, 4), dropTargetAt(scene.written(), 4, 4, 7).?.index);
    try std.testing.expect(dropTargetAt(scene.written(), 4, 4, 8) == null);
}

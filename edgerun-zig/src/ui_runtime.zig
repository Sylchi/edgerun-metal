const std = @import("std");
const input = @import("input.zig");
const ui = @import("ui.zig");

const drag_start_threshold_px: f32 = 5.0;

pub const ActionKind = enum(u8) {
    none,
    hovered,
    activated,
    drag_started,
    drag_moved,
    dropped,
    reordered,
};

pub const Action = struct {
    kind: ActionKind = .none,
    hit: ?ui.Hit = null,
    source: ?ui.DragSource = null,
    target: ?ui.DropTarget = null,

    pub fn none() Action {
        return .{};
    }
};

const DragState = struct {
    source: ui.DragSource,
    start_x: f32,
    start_y: f32,
    current_x: f32,
    current_y: f32,
    started: bool = false,
    target: ?ui.DropTarget = null,
};

pub const State = struct {
    hovered: ?ui.Hit = null,
    active: ?ui.Hit = null,
    drag: ?DragState = null,

    pub fn pointerDown(self: *State, commands: []const ui.Command, x: f32, y: f32) Action {
        const hit = input.hitTest(commands, x, y);
        self.hovered = hit;
        self.active = hit;
        self.drag = if (input.dragSourceAt(commands, x, y)) |source| .{
            .source = source,
            .start_x = x,
            .start_y = y,
            .current_x = x,
            .current_y = y,
        } else null;
        return if (hit) |value| .{ .kind = .hovered, .hit = value } else Action.none();
    }

    pub fn pointerMove(self: *State, commands: []const ui.Command, x: f32, y: f32) Action {
        self.hovered = input.hitTest(commands, x, y);
        if (self.drag) |*drag| {
            drag.current_x = x;
            drag.current_y = y;
            const next_target = input.dropTargetAt(commands, x, y, drag.source.scope_id);
            drag.target = next_target;
            if (!drag.started and dragDistanceExceeded(drag.*, x, y)) {
                drag.started = true;
                return .{ .kind = .drag_started, .source = drag.source, .target = next_target };
            }
            if (drag.started) {
                return .{ .kind = .drag_moved, .source = drag.source, .target = next_target };
            }
        }
        return if (self.hovered) |value| .{ .kind = .hovered, .hit = value } else Action.none();
    }

    pub fn pointerUp(self: *State, commands: []const ui.Command, x: f32, y: f32) Action {
        self.hovered = input.hitTest(commands, x, y);
        const finished_drag = self.drag;
        self.drag = null;
        defer self.active = null;

        if (finished_drag) |drag| {
            if (drag.started) {
                if (drag.target) |target| {
                    if (target.index != drag.source.index) {
                        return .{ .kind = .reordered, .source = drag.source, .target = target };
                    }
                    return .{ .kind = .dropped, .source = drag.source, .target = target };
                }
                return .{ .kind = .dropped, .source = drag.source };
            }
        }

        if (self.active) |active_hit| {
            if (self.hovered) |hovered_hit| {
                if (sameHit(active_hit, hovered_hit)) {
                    return .{ .kind = .activated, .hit = hovered_hit };
                }
            }
        }
        return Action.none();
    }
};

fn sameHit(left: ui.Hit, right: ui.Hit) bool {
    return left.kind == right.kind and left.id == right.id and left.slot == right.slot;
}

fn dragDistanceExceeded(drag: DragState, x: f32, y: f32) bool {
    const dx = x - drag.start_x;
    const dy = y - drag.start_y;
    return dx * dx + dy * dy >= drag_start_threshold_px * drag_start_threshold_px;
}

test "runtime emits activation for stable pointer press" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 9, .bounds = ui.Rect.init(0, 0, 40, 30) });

    var state = State{};
    try std.testing.expectEqual(ActionKind.hovered, state.pointerDown(scene.written(), 8, 8).kind);
    const action = state.pointerUp(scene.written(), 8, 8);
    try std.testing.expectEqual(ActionKind.activated, action.kind);
    try std.testing.expectEqual(@as(u32, 9), action.hit.?.id);
}

test "runtime emits reorder only after drag threshold and changed target" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushDragSource(.{ .scope_id = 7, .item_id = 10, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 30) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 30) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 2, .bounds = ui.Rect.init(0, 80, 40, 30) });

    var state = State{};
    try std.testing.expectEqual(ActionKind.none, state.pointerDown(scene.written(), 8, 8).kind);
    try std.testing.expectEqual(ActionKind.none, state.pointerMove(scene.written(), 10, 10).kind);
    try std.testing.expectEqual(ActionKind.drag_started, state.pointerMove(scene.written(), 8, 88).kind);
    const action = state.pointerUp(scene.written(), 8, 88);
    try std.testing.expectEqual(ActionKind.reordered, action.kind);
    try std.testing.expectEqual(@as(usize, 0), action.source.?.index);
    try std.testing.expectEqual(@as(usize, 2), action.target.?.index);
}

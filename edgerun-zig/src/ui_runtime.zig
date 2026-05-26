const std = @import("std");
const input = @import("input.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");

const drag_start_threshold_px: f32 = 5.0;

pub const ActionKind = enum(u8) {
    none,
    hovered,
    focused,
    activated,
    drag_started,
    drag_moved,
    dropped,
    reordered,
};

pub const Key = enum(u8) {
    tab,
    shift_tab,
    enter,
    space,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    escape,
};

pub const Action = struct {
    kind: ActionKind = .none,
    hit: ?interaction.Region = null,
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
    hovered: ?interaction.Region = null,
    active: ?interaction.Region = null,
    focused: ?interaction.Region = null,
    drag: ?DragState = null,

    pub fn refreshHover(self: *State, regions: []const interaction.Region, x: f32, y: f32) void {
        self.hovered = if (x < 0.0 or y < 0.0) null else input.hitTest(regions, x, y);
    }

    pub fn clearHover(self: *State) void {
        self.hovered = null;
    }

    pub fn hoverKind(self: State) ?ui.HitKind {
        return if (self.hovered) |hit| hit.kind else null;
    }

    pub fn hoverHitId(self: State) u32 {
        return if (self.hovered) |hit| hit.id else 0;
    }

    pub fn focusKind(self: State) ?ui.HitKind {
        return if (self.focused) |hit| hit.kind else null;
    }

    pub fn focusHitId(self: State) u32 {
        return if (self.focused) |hit| hit.id else 0;
    }

    pub fn refreshFocus(self: *State, regions: []const interaction.Region) void {
        if (self.focused) |current| {
            self.focused = matchingRegion(regions, current);
        }
    }

    pub fn pointerDown(self: *State, commands: []const ui.Command, regions: []const interaction.Region, x: f32, y: f32) Action {
        const hit = input.hitTest(regions, x, y);
        self.hovered = hit;
        self.active = hit;
        self.focused = hit orelse self.focused;
        self.drag = if (input.dragSourceAt(commands, x, y)) |source| .{
            .source = source,
            .start_x = x,
            .start_y = y,
            .current_x = x,
            .current_y = y,
        } else null;
        return if (hit) |value| .{ .kind = .hovered, .hit = value } else Action.none();
    }

    pub fn keyDown(self: *State, regions: []const interaction.Region, key: Key) Action {
        return switch (key) {
            .tab, .arrow_down, .arrow_right => self.focusNext(regions),
            .shift_tab, .arrow_up, .arrow_left => self.focusPrevious(regions),
            .enter, .space => self.activateFocused(),
            .escape => self.clearFocus(),
        };
    }

    pub fn focusNext(self: *State, regions: []const interaction.Region) Action {
        return self.focusByStep(regions, .forward);
    }

    pub fn focusPrevious(self: *State, regions: []const interaction.Region) Action {
        return self.focusByStep(regions, .backward);
    }

    pub fn clearFocus(self: *State) Action {
        self.focused = null;
        self.active = null;
        return Action.none();
    }

    fn activateFocused(self: *State) Action {
        if (self.focused) |hit| {
            self.active = hit;
            return .{ .kind = .activated, .hit = hit };
        }
        return Action.none();
    }

    fn focusByStep(self: *State, regions: []const interaction.Region, direction: FocusDirection) Action {
        if (regions.len == 0) {
            self.focused = null;
            return Action.none();
        }
        const next_index = nextFocusIndex(regions, self.focused, direction);
        self.focused = regions[next_index];
        self.hovered = self.focused;
        return .{ .kind = .focused, .hit = self.focused };
    }

    pub fn pointerMove(self: *State, commands: []const ui.Command, regions: []const interaction.Region, x: f32, y: f32) Action {
        self.hovered = input.hitTest(regions, x, y);
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

    pub fn pointerUp(self: *State, commands: []const ui.Command, regions: []const interaction.Region, x: f32, y: f32) Action {
        _ = commands;
        self.hovered = input.hitTest(regions, x, y);
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

const FocusDirection = enum {
    forward,
    backward,
};

fn sameHit(left: interaction.Region, right: interaction.Region) bool {
    return left.kind == right.kind and left.id == right.id and left.slot == right.slot;
}

fn nextFocusIndex(regions: []const interaction.Region, current: ?interaction.Region, direction: FocusDirection) usize {
    if (regions.len == 0) return 0;
    const current_index = if (current) |value| indexOfRegion(regions, value) else null;
    return switch (direction) {
        .forward => if (current_index) |index| (index + 1) % regions.len else 0,
        .backward => if (current_index) |index| if (index == 0) regions.len - 1 else index - 1 else regions.len - 1,
    };
}

fn indexOfRegion(regions: []const interaction.Region, value: interaction.Region) ?usize {
    for (regions, 0..) |region, index| {
        if (sameHit(region, value)) return index;
    }
    return null;
}

fn matchingRegion(regions: []const interaction.Region, value: interaction.Region) ?interaction.Region {
    for (regions) |region| {
        if (sameHit(region, value)) return region;
    }
    return null;
}

fn dragDistanceExceeded(drag: DragState, x: f32, y: f32) bool {
    const dx = x - drag.start_x;
    const dy = y - drag.start_y;
    return dx * dx + dy * dy >= drag_start_threshold_px * drag_start_threshold_px;
}

test "runtime emits activation for stable pointer press" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 40, 30), .button, 9);

    var state = State{};
    try std.testing.expectEqual(ActionKind.hovered, state.pointerDown(scene.written(), collector.written(), 8, 8).kind);
    const action = state.pointerUp(scene.written(), collector.written(), 8, 8);
    try std.testing.expectEqual(ActionKind.activated, action.kind);
    try std.testing.expectEqual(@as(u32, 9), action.hit.?.id);
}

test "runtime refreshes hover from current interaction regions" {
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(10, 20, 40, 30), .button, 42);

    var state = State{};
    state.refreshHover(collector.written(), 20, 30);
    try std.testing.expectEqual(@as(u32, 42), state.hovered.?.id);
    try std.testing.expectEqual(@as(u32, 42), state.hoverHitId());
    try std.testing.expectEqual(ui.HitKind.button, state.hoverKind().?);

    state.clearHover();
    try std.testing.expect(state.hovered == null);
    try std.testing.expectEqual(@as(u32, 0), state.hoverHitId());
    try std.testing.expect(state.hoverKind() == null);

    state.refreshHover(collector.written(), -1, -1);
    try std.testing.expectEqual(@as(u32, 0), state.hoverHitId());
}

test "runtime keyboard navigation moves focus through regions" {
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 40, 30), .button, 1);
    try collector.addHit(ui.Rect.init(0, 40, 40, 30), .input, 2);
    try collector.addHit(ui.Rect.init(0, 80, 40, 30), .select, 3);

    var state = State{};
    var action = state.keyDown(collector.written(), .tab);
    try std.testing.expectEqual(ActionKind.focused, action.kind);
    try std.testing.expectEqual(@as(u32, 1), action.hit.?.id);
    try std.testing.expectEqual(@as(u32, 1), state.focusHitId());
    try std.testing.expectEqual(ui.HitKind.button, state.focusKind().?);

    action = state.keyDown(collector.written(), .arrow_down);
    try std.testing.expectEqual(@as(u32, 2), action.hit.?.id);

    action = state.keyDown(collector.written(), .shift_tab);
    try std.testing.expectEqual(@as(u32, 1), action.hit.?.id);

    action = state.keyDown(collector.written(), .arrow_left);
    try std.testing.expectEqual(@as(u32, 3), action.hit.?.id);
}

test "runtime keyboard activation uses focused region" {
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 40, 30), .button, 11);
    try collector.addHit(ui.Rect.init(0, 40, 40, 30), .button, 12);

    var state = State{};
    _ = state.keyDown(collector.written(), .tab);
    _ = state.keyDown(collector.written(), .tab);
    const action = state.keyDown(collector.written(), .enter);

    try std.testing.expectEqual(ActionKind.activated, action.kind);
    try std.testing.expectEqual(@as(u32, 12), action.hit.?.id);
    try std.testing.expectEqual(@as(u32, 12), state.active.?.id);
    try std.testing.expectEqual(ActionKind.none, state.keyDown(collector.written(), .escape).kind);
    try std.testing.expectEqual(@as(u32, 0), state.focusHitId());
}

test "runtime focus refresh tracks matching region bounds and clears stale focus" {
    var state = State{ .focused = .{ .kind = .button, .id = 8, .bounds = ui.Rect.init(0, 0, 10, 10) } };
    const next_regions = [_]interaction.Region{
        .{ .kind = .button, .id = 8, .bounds = ui.Rect.init(20, 30, 40, 50) },
    };

    state.refreshFocus(&next_regions);
    try std.testing.expectEqual(@as(u32, 8), state.focusHitId());
    try std.testing.expectEqual(@as(f32, 20.0), state.focused.?.bounds.x);
    try std.testing.expectEqual(@as(f32, 30.0), state.focused.?.bounds.y);

    state.refreshFocus(&.{});
    try std.testing.expectEqual(@as(u32, 0), state.focusHitId());
}

test "runtime emits reorder only after drag threshold and changed target" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushDragSource(.{ .scope_id = 7, .item_id = 10, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 30) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 30) });
    try scene.pushDropTarget(.{ .scope_id = 7, .index = 2, .bounds = ui.Rect.init(0, 80, 40, 30) });

    var state = State{};
    try std.testing.expectEqual(ActionKind.none, state.pointerDown(scene.written(), &.{}, 8, 8).kind);
    try std.testing.expectEqual(ActionKind.none, state.pointerMove(scene.written(), &.{}, 10, 10).kind);
    try std.testing.expectEqual(ActionKind.drag_started, state.pointerMove(scene.written(), &.{}, 8, 88).kind);
    const action = state.pointerUp(scene.written(), &.{}, 8, 88);
    try std.testing.expectEqual(ActionKind.reordered, action.kind);
    try std.testing.expectEqual(@as(usize, 0), action.source.?.index);
    try std.testing.expectEqual(@as(usize, 2), action.target.?.index);
}

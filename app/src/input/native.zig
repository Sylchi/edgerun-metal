const std = @import("std");
const math = @import("../math.zig");
const app_agent = @import("../shell/agent.zig");
const app_cursor = @import("../ui/cursor.zig");
const app_frame = @import("../shell/frame.zig");
const app_input_event = @import("../app_input_event.zig");
const app_location = @import("../location.zig");
const interaction = @import("../ui/interaction.zig");
const ui = @import("../ui/core.zig");
const ui_runtime = @import("../ui/runtime.zig");

pub const State = struct {
    location: app_location.Location = .{},
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    runtime: ui_runtime.State = .{},
    agent: app_agent.State = .{},
    last_action_kind: ui_runtime.ActionKind = .none,
    public_identity_ready: bool = true,
    public_identity: []const u8 = "native",
    reveal_identity: []const u8 = "native",

    pub fn frameState(self: State) app_frame.State {
        return .{
            .location = self.location,
            .scroll_y = self.scroll_y,
            .hover_x = self.hover_x,
            .hover_y = self.hover_y,
            .agent = self.agent,
            .public_identity_ready = self.public_identity_ready,
            .public_identity = self.public_identity,
        };
    }

    pub fn contentHeight(self: State, width: f32) f32 {
        return app_frame.contentHeight(width, self.frameState());
    }

    pub fn cursorKind(self: State) app_cursor.Kind {
        return app_cursor.fromState(self.last_action_kind, self.runtime.hoverKind());
    }
};

pub fn refreshHover(state: *State, regions: []const interaction.Region) void {
    _ = state;
    _ = regions;
}

pub fn clearHover(state: *State) void {
    state.hover_x = -1.0;
    state.hover_y = -1.0;
    state.runtime.clearHover();
    state.last_action_kind = .none;
}

pub fn applyLocation(state: *State, location: app_location.Location) void {
    state.location = location;
    state.scroll_y = 0.0;
}

pub fn activateHovered(state: *State) void {
    const hover_hit_id = state.runtime.hoverHitId();
    if (app_location.fromHit(hover_hit_id, state.location)) |location| {
        applyLocation(state, location);
        return;
    }
    if (hover_hit_id == app_agent.open_host_binary_button_id) {
        state.agent.host_launch_requested = true;
        state.agent.connected = false;
        state.agent.status.set(app_agent.host_launch_requested_notice);
        return;
    }
    if (app_location.actionFromHit(hover_hit_id)) |action| switch (action) {
        .reveal_identity => {
            state.public_identity_ready = true;
            state.public_identity = state.reveal_identity;
        },
        else => {},
    };
}

pub fn processPointerEvent(state: *State, commands: []const ui.Command, regions: []const interaction.Region, routed_hit: ?interaction.Region, event: app_input_event.Kind) void {
    _ = regions;
    const hit = routed_hit orelse state.runtime.hovered;
    state.last_action_kind = switch (event) {
        .pointer_move => state.runtime.pointerMoveRouted(commands, hit, state.hover_x, state.hover_y).kind,
        .pointer_leave => blk: {
            state.runtime.clearHover();
            break :blk ui_runtime.ActionKind.none;
        },
        .pointer_down => state.runtime.pointerDownRouted(commands, hit, state.hover_x, state.hover_y).kind,
        .pointer_up => blk: {
            const action = state.runtime.pointerUpRouted(commands, hit, state.hover_x, state.hover_y);
            if (action.kind != .reordered) activateHovered(state);
            break :blk action.kind;
        },
        else => state.last_action_kind,
    };
}

pub fn scrollBy(state: *State, width: f32, viewport_height: f32, delta_y: f32) void {
    if (!math.isFiniteF(delta_y)) return;
    const viewport_h = @max(1.0, viewport_height);
    const limit = @max(0.0, state.contentHeight(width) - viewport_h);
    state.scroll_y = math.clampF(state.scroll_y + delta_y, 0.0, limit);
}

test "native input activates routes and resets scroll through shared state" {
    var state = State{ .scroll_y = 120.0 };
    state.runtime.hovered = .{ .kind = .button, .id = app_location.app_preview_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) };

    activateHovered(&state);

    try std.testing.expect(app_location.isAppPreview(state.location));
    try std.testing.expectEqual(@as(f32, 0.0), state.scroll_y);
}

test "native input reveals host identity from shared action policy" {
    var state = State{ .public_identity_ready = false, .public_identity = "pending", .reveal_identity = "native-test" };
    state.runtime.hovered = .{ .kind = .button, .id = app_location.reveal_identity_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) };

    activateHovered(&state);

    try std.testing.expect(state.public_identity_ready);
    try std.testing.expectEqualStrings("native-test", state.public_identity);
}

test "native input requests host launch from open-host action" {
    var state = State{};
    state.runtime.hovered = .{ .kind = .button, .id = app_agent.open_host_binary_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) };

    activateHovered(&state);

    try std.testing.expect(state.agent.host_launch_requested);
    try std.testing.expect(!state.agent.connected);
    try std.testing.expect(state.agent.status.len > 0);
}

test "native input pointer path uses shared runtime activation" {
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, app_location.app_preview_button_id);
    var state = State{ .hover_x = 8.0, .hover_y = 8.0 };

    processPointerEvent(&state, scene.written(), collector.written(), collector.written()[0], .pointer_down);
    processPointerEvent(&state, scene.written(), collector.written(), collector.written()[0], .pointer_up);

    try std.testing.expectEqual(ui_runtime.ActionKind.activated, state.last_action_kind);
    try std.testing.expect(app_location.isAppPreview(state.location));
}

test "native input routes all canonical fixtures through shared top-level binding path" {
    for (app_location.location_fixtures) |fixture| {
        var state = State{ .location = fixture.location };
        var matching_binding: ?app_location.TopLevelBinding = null;

        for (app_location.topLevelBindings()) |binding| {
            if (std.meta.eql(binding.location, fixture.location)) {
                matching_binding = binding;
                break;
            }
        }
        const binding = matching_binding orelse continue;
        state.runtime.hovered = .{ .kind = .button, .id = binding.id, .bounds = ui.Rect.init(0, 0, 1, 1) };

        activateHovered(&state);

        try expectLocation(state.location, fixture.location);
    }
}

test "native input location fixtures keep deterministic path/hash mapping" {
    for (app_location.location_fixtures) |fixture| {
        try expectLocationProjections(fixture.location, fixture.path, fixture.hash);
    }
}

fn expectLocation(actual: app_location.Location, expected: app_location.Location) !void {
    try std.testing.expectEqual(expected, actual);
}

fn expectLocationProjections(location: app_location.Location, expected_path: []const u8, expected_hash: []const u8) !void {
    var path_buf: [app_location.path_projection_capacity]u8 = undefined;
    var hash_buf: [app_location.hash_projection_capacity]u8 = undefined;

    const path_len = try app_location.writePathProjection(&path_buf, location);
    const hash_len = try app_location.writeHashProjection(&hash_buf, location);

    try std.testing.expectEqualStrings(expected_path, path_buf[0..path_len]);
    try std.testing.expectEqualStrings(expected_hash, hash_buf[0..hash_len]);
}

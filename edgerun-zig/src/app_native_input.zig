const std = @import("std");
const app_cursor = @import("app_cursor.zig");
const app_frame = @import("app_frame.zig");
const app_input_event = @import("app_input_event.zig");
const app_navigation = @import("app_navigation.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const ui_runtime = @import("ui_runtime.zig");

pub const State = struct {
    route: app_navigation.Route = .{},
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    runtime: ui_runtime.State = .{},
    last_action_kind: ui_runtime.ActionKind = .none,
    public_identity_ready: bool = true,
    public_identity: []const u8 = "native",
    reveal_identity: []const u8 = "native",

    pub fn frameState(self: State) app_frame.State {
        return .{
            .route = self.route,
            .scroll_y = self.scroll_y,
            .hover_x = self.hover_x,
            .hover_y = self.hover_y,
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
    state.runtime.refreshHover(regions, state.hover_x, state.hover_y);
}

pub fn clearHover(state: *State) void {
    state.hover_x = -1.0;
    state.hover_y = -1.0;
    state.runtime.clearHover();
    state.last_action_kind = .none;
}

pub fn applyRoute(state: *State, route: app_navigation.Route) void {
    state.route = route;
    state.scroll_y = 0.0;
}

pub fn activateHovered(state: *State) void {
    const hover_hit_id = state.runtime.hoverHitId();
    if (app_navigation.fromHit(hover_hit_id, state.route)) |route| {
        applyRoute(state, route);
        return;
    }
    if (app_navigation.actionFromHit(hover_hit_id)) |action| switch (action) {
        .reveal_identity => {
            state.public_identity_ready = true;
            state.public_identity = state.reveal_identity;
        },
        .compile_source,
        .download_source_release,
        .launch_source_release,
        .reset_source,
        .open_context_source,
        => {},
    };
}

pub fn processPointerEvent(state: *State, commands: []const ui.Command, regions: []const interaction.Region, event: app_input_event.Kind) void {
    state.last_action_kind = switch (event) {
        .pointer_move => state.runtime.pointerMove(commands, regions, state.hover_x, state.hover_y).kind,
        .pointer_leave => blk: {
            state.runtime.clearHover();
            break :blk ui_runtime.ActionKind.none;
        },
        .pointer_down => state.runtime.pointerDown(commands, regions, state.hover_x, state.hover_y).kind,
        .pointer_up => blk: {
            const action = state.runtime.pointerUp(commands, regions, state.hover_x, state.hover_y);
            if (action.kind != .reordered) activateHovered(state);
            break :blk action.kind;
        },
        else => state.last_action_kind,
    };
}

pub fn scrollBy(state: *State, width: f32, viewport_height: f32, delta_y: f32) void {
    if (!std.math.isFinite(delta_y)) return;
    const viewport_h = @max(1.0, viewport_height);
    const limit = @max(0.0, state.contentHeight(width) - viewport_h);
    state.scroll_y = std.math.clamp(state.scroll_y + delta_y, 0.0, limit);
}

test "native input activates routes and resets scroll through shared state" {
    var state = State{ .scroll_y = 120.0 };
    state.runtime.hovered = .{ .kind = .button, .id = @import("app_chrome.zig").docs_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) };

    activateHovered(&state);

    try std.testing.expectEqual(app_navigation.View.docs, state.route.view);
    try std.testing.expectEqual(@as(f32, 0.0), state.scroll_y);
}

test "native input reveals host identity from shared action policy" {
    var state = State{ .public_identity_ready = false, .public_identity = "pending", .reveal_identity = "native-test" };
    state.runtime.hovered = .{ .kind = .button, .id = @import("app_landing.zig").reveal_identity_button_id, .bounds = ui.Rect.init(0, 0, 1, 1) };

    activateHovered(&state);

    try std.testing.expect(state.public_identity_ready);
    try std.testing.expectEqualStrings("native-test", state.public_identity);
}

test "native input pointer path uses shared runtime activation" {
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, @import("app_chrome.zig").blog_button_id);
    var state = State{ .hover_x = 8.0, .hover_y = 8.0 };

    processPointerEvent(&state, scene.written(), collector.written(), .pointer_down);
    processPointerEvent(&state, scene.written(), collector.written(), .pointer_up);

    try std.testing.expectEqual(ui_runtime.ActionKind.activated, state.last_action_kind);
    try std.testing.expectEqual(app_navigation.View.blog, state.route.view);
}

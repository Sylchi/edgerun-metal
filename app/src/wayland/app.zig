const std = @import("std");
const protocol = @import("protocol.zig");
const client = @import("client.zig");

const interaction = @import("../ui/interaction.zig");
const app_chrome = @import("../ui/chrome.zig");
const app_agent = @import("../shell/agent.zig");
const app_cursor = @import("../ui/cursor.zig");
const app_frame = @import("../shell/frame.zig");
const app_images = @import("../app_images.zig");
const app_location = @import("../location.zig");
const app_native_input = @import("../input/native.zig");
const app_dashboard = @import("../app_dashboard.zig");
const app_hardware_dashboard = @import("../app_hardware_dashboard.zig");
const icon_component = @import("../ui/components/Icon.zig");
const ui = @import("../ui/core.zig");
const text_component = @import("../ui/components/Text.zig");
const bytes_mod = @import("../bytes.zig");

const surface = @import("surface.zig");
const icon_pack = @import("../ui/icon_pack.zig");

const posix = std.posix;

pub const AppState = app_native_input.State;

pub const default_refresh_hz = surface.default_refresh_hz;
pub const max_commands: usize = 4096;
pub const max_clips: usize = 64;
pub const max_interaction_regions: usize = 1024;

pub const IrStorage = surface.IrStorage;
pub const GpuRecorder = surface.GpuRecorder;
pub const WaylandCommitSink = surface.WaylandCommitSink;
pub const WaylandDmabufCommitSink = surface.WaylandDmabufCommitSink;

pub const packXrgb8888 = surface.packXrgb8888;
pub const packXrgb8888Rect = surface.packXrgb8888Rect;
pub const packXrgb8888Strided = surface.packXrgb8888Strided;
pub const cursorPixelRect = surface.cursorPixelRect;
pub const unionPixelRect = surface.unionPixelRect;
pub const fixedToFloat = surface.fixedToFloat;
pub const appBackground = surface.defaultBackground;

pub fn renderNativeAppScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, state: AppState, dashboard_state: *app_dashboard.State, dashboard_mode: bool, hardware_state: ?*app_hardware_dashboard.State, hardware_mode: bool) !void {
    try renderClientDecoration(scene, collector, @floatFromInt(width));
    const content_y = protocol.client_decor_h;
    const content_h = @max(1.0, @as(f32, @floatFromInt(height)) - content_y);
    const bounds = ui.Rect.init(0, content_y, @floatFromInt(width), content_h);
    if (dashboard_mode) {
        try dashboard_state.refresh();
        try dashboard_state.render(scene, bounds, .{});
        return;
    }
    if (hardware_mode) {
        if (hardware_state) |hs| {
            try hs.render(scene, collector, bounds, hardwareRenderOptions(state));
        }
        return;
    }
    try app_frame.render(scene, collector, bounds, .{
        .location = state.location,
        .scroll_y = state.scroll_y,
        .hover_x = state.hover_x,
        .hover_y = state.hover_y,
        .agent = state.agent,
        .public_identity = state.public_identity,
        .public_identity_ready = state.public_identity_ready,
    });
}

fn renderClientDecoration(scene: *ui.Scene, collector: *interaction.Collector, width: f32) !void {
    const bounds = ui.Rect.init(0.0, 0.0, width, protocol.client_decor_h);
    try scene.pushRect(bounds, protocol.client_decor_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(0.0, protocol.client_decor_h - 1.0, width, 1.0), protocol.client_decor_border, .fill, 0.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(14.0, 8.0, @max(1.0, width - 168.0), 15.0), "EdgeRun Native", protocol.client_decor_text, .start);

    const close = clientDecorButton(width, 0);
    const minimize = clientDecorButton(width, 1);
    try scene.pushRect(minimize, protocol.client_decor_border, .border, 12.0, 0.0);
    try scene.pushRect(centeredRect(minimize, protocol.client_decor_minimize_w, protocol.client_decor_minimize_h), protocol.client_decor_dim, .fill, 1.0, 0.0);
    try collector.addHit(minimize, .button, protocol.client_decor_minimize_id);

    try scene.pushRect(close, protocol.client_decor_border, .border, 12.0, 0.0);
    try icon_component.Icon.named(.x).renderColor(scene, centeredRect(close, protocol.client_decor_icon_size, protocol.client_decor_icon_size), protocol.client_decor_dim);
    try collector.addHit(close, .button, protocol.client_decor_close_id);

    const drag_w = @max(1.0, minimize.x - protocol.client_decor_button_gap - 140.0);
    try collector.addHit(ui.Rect.init(0.0, 0.0, drag_w, protocol.client_decor_h), .button, protocol.client_decor_drag_id);
}

fn clientDecorButton(width: f32, index: usize) ui.Rect {
    const offset = @as(f32, @floatFromInt(index + 1)) * (protocol.client_decor_button_size + protocol.client_decor_button_gap);
    return ui.Rect.init(width - offset, 5.0, protocol.client_decor_button_size, protocol.client_decor_button_size);
}

fn centeredRect(bounds: ui.Rect, w: f32, h: f32) ui.Rect {
    return ui.Rect.init(bounds.x + (bounds.w - w) * 0.5, bounds.y + (bounds.h - h) * 0.5, w, h);
}

pub fn activateClientDecorationForState(state: *AppState, client_ptr: ?*client.WaylandClient) !void {
    const hover_hit_id = state.runtime.hoverHitId();
    switch (hover_hit_id) {
        protocol.client_decor_close_id => {
            app_native_input.clearHover(state);
            if (client_ptr) |c| c.state.closed = true;
            return;
        },
        protocol.client_decor_minimize_id => {
            if (client_ptr) |c| try c.sendMinimize();
            return;
        },
        else => {},
    }
}

pub fn scrollStateBy(state: *AppState, width: u32, height: u32, delta_y: f32) void {
    const viewport_h = @max(1.0, @as(f32, @floatFromInt(height)) - protocol.client_decor_h);
    app_native_input.scrollBy(state, @floatFromInt(width), viewport_h, delta_y);
}

pub const NativeApp = struct {
    surface: *surface.Surface,
    allocator: std.mem.Allocator,
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_interaction_regions]interaction.Region = undefined,
    region_len: usize = 0,
    state: AppState = .{ .public_identity = "native-wayland", .reveal_identity = "native-wayland" },
    dashboard_app: app_dashboard.State = .{},
    hardware_app: app_hardware_dashboard.State = .{},
    dashboard: bool = false,
    hardware: bool = false,

    pub fn create(client_ptr: *client.WaylandClient, allocator: std.mem.Allocator, options: @import("options.zig").Options) !*NativeApp {
        const surf = try surface.Surface.create(allocator, client_ptr, options);
        errdefer surf.destroy();
        const self = try allocator.create(NativeApp);
        errdefer allocator.destroy(self);
        self.surface = surf;
        self.allocator = allocator;
        self.region_len = 0;
        self.state = .{
            .location = try app_location.fromPathProjection(options.path),
            .public_identity = "native-wayland",
            .reveal_identity = "native-wayland",
        };
        self.dashboard_app = .{};
        self.hardware_app = .{};
        self.dashboard = options.dashboard;
        self.hardware = options.hardware;
        if (self.hardware) self.hardware_app.refresh();
        return self;
    }

    pub fn deinit(self: *NativeApp) void {
        self.surface.destroy();
    }

    pub fn destroy(self: *NativeApp) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn render(self: *NativeApp, client_ptr: *client.WaylandClient) !void {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try renderNativeAppScene(&scene, &collector, self.surface.width, self.surface.height, self.state, &self.dashboard_app, self.dashboard, &self.hardware_app, self.hardware);
        self.region_len = collector.written().len;
        const cursor_kind = self.state.cursorKind();
        if (self.surface.present != .cpu) try app_cursor.render(&scene, self.state.hover_x, self.state.hover_y, cursor_kind);
        const cursor_for_surface: ?app_cursor.Kind = if (self.surface.present == .cpu) cursor_kind else null;
        try self.surface.renderScene(client_ptr, scene.written(), appBackground(), self.state.hover_x, self.state.hover_y, cursor_for_surface);
    }

    pub fn renderSafe(self: *NativeApp, client_ptr: *client.WaylandClient) void {
        self.render(client_ptr) catch |err| {
            std.debug.print("render error: {s}\n", .{@errorName(err)});
            self.refreshAgentHostConnectivity();
        };
    }

    pub fn tickIdleFrame(self: *NativeApp, client_ptr: *client.WaylandClient) void {
        if (!self.hardware) return;
        if (self.hardware_app.tick()) self.renderSafe(client_ptr);
    }

    pub fn refreshAgentHostConnectivity(self: *NativeApp) void {
        const options = @import("options.zig");
        if (self.state.agent.host_launch_requested) return;
        if (options.isHostApiReachable(self.state.agent.host_url)) {
            self.state.agent.connected = true;
            self.state.agent.status.set("Host API connected");
        } else {
            self.state.agent.connected = false;
            self.state.agent.status.set(app_agent.host_not_connected_notice);
        }
    }

    pub fn renderCursorOnly(self: *NativeApp, client_ptr: *client.WaylandClient, old_x: f32, old_y: f32, old_kind: app_cursor.Kind) !void {
        try self.surface.renderCursorOnly(client_ptr, old_x, old_y, old_kind, self.state.hover_x, self.state.hover_y, self.state.cursorKind());
    }

    pub fn renderCursorOverlay(self: *NativeApp, kind: app_cursor.Kind) !?protocol.PixelRect {
        return self.surface.renderCursorOverlay(self.state.hover_x, self.state.hover_y, kind);
    }

    pub fn handleWaylandInput(self: *NativeApp, client_ptr: *client.WaylandClient, kind: protocol.ObjectKind, message: protocol.Message) !bool {
        if (kind != .pointer) return false;
        switch (message.opcode) {
            protocol.wl_pointer_enter_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                try client_ptr.sendHidePointerCursor(serial);
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[12..16], .little));
                app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_move);
                return true;
            },
            protocol.wl_pointer_leave_event => {
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_kind = self.state.cursorKind();
                app_native_input.clearHover(&self.state);
                if (self.surface.present == .cpu and self.surface.base_pixels_ready) {
                    try self.surface.renderCursorOnly(client_ptr, old_x, old_y, old_kind, self.state.hover_x, self.state.hover_y, self.state.cursorKind());
                    return false;
                }
                return true;
            },
            protocol.wl_pointer_motion_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_hit = self.state.runtime.hoverHitId();
                const old_kind = self.state.cursorKind();
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[4..8], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_move);
                if (self.surface.present == .cpu and self.surface.base_pixels_ready) {
                    try self.surface.renderCursorOnly(client_ptr, old_x, old_y, old_kind, self.state.hover_x, self.state.hover_y, self.state.cursorKind());
                    return false;
                }
                if (self.state.runtime.hoverHitId() != old_hit) return true;
                return @abs(self.state.hover_x - old_x) >= 8.0 or @abs(self.state.hover_y - old_y) >= 8.0;
            },
            protocol.wl_pointer_button_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                const button = std.mem.readInt(u32, message.payload[8..12], .little);
                const state = std.mem.readInt(u32, message.payload[12..16], .little);
                if (button == protocol.wl_pointer_button_left) {
                    if (state == protocol.wl_pointer_button_released) {
                        app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_up);
                        if (self.hardware and self.state.last_action_kind == .activated) {
                            self.hardware_app.activate(self.state.runtime.hovered, self.state.runtime.persisted_value);
                        }
                        try self.activateClientDecoration(client_ptr);
                    } else {
                        app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_down);
                        if (self.state.runtime.hoverHitId() == protocol.client_decor_drag_id) try client_ptr.sendMove(serial);
                    }
                } else if (button == protocol.wl_pointer_button_right and state == protocol.wl_pointer_button_released) {
                    app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_move);
                    if (self.hardware) self.hardware_app.openContext(self.state.runtime.hovered, self.state.hover_x, self.state.hover_y);
                }
                return true;
            },
            protocol.wl_pointer_axis_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const axis = std.mem.readInt(u32, message.payload[4..8], .little);
                const value = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                if (axis == protocol.wl_pointer_axis_vertical_scroll) scrollStateBy(&self.state, self.surface.width, self.surface.height, value);
                return true;
            },
            else => return false,
        }
    }

    pub fn regionSlice(self: *const NativeApp) []const interaction.Region {
        return self.regions[0..self.region_len];
    }

    pub fn routedPointerHit(self: *const NativeApp) ?interaction.Region {
        if (self.state.hover_x < 0.0 or self.state.hover_y < 0.0) return null;
        return interaction.hitTest(self.regionSlice(), self.state.hover_x, self.state.hover_y);
    }

    fn activateClientDecoration(self: *NativeApp, client_ptr: *client.WaylandClient) !void {
        try activateClientDecorationForState(&self.state, client_ptr);
    }
};

pub fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and bytes_mod.eql(command.text.value, value)) return true;
    }
    return false;
}

fn hardwareRenderOptions(state: AppState) @import("../ui/component_common.zig").RenderOptions {
    return .{
        .interaction = .{
            .hovered_id = if (state.runtime.hovered) |hit| hit.id else null,
            .active_id = if (state.runtime.active) |hit| hit.id else null,
            .focused_id = if (state.runtime.focused) |hit| hit.id else null,
        },
    };
}

pub fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasIcon(commands: []const ui.Command, value: icon_component.Icon) bool {
    return hasIconId(commands, icon_pack.iconId(value.value));
}

pub fn hasIconId(commands: []const ui.Command, icon_id: u32) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

pub fn hitRect(regions: []const interaction.Region, id: u32) !ui.Rect {
    for (regions) |region| {
        if (region.id == id) return region.bounds;
    }
    return error.MissingHit;
}

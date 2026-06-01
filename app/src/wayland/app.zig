const std = @import("std");
const protocol = @import("protocol.zig");
const client = @import("client.zig");

const interaction = @import("../ui/interaction.zig");
const app_chrome = @import("../ui/chrome.zig");
const app_agent = @import("../shell/agent.zig");
const app_cursor = @import("../ui/cursor.zig");
const app_images = @import("../app_images.zig");
const app_location = @import("../location.zig");
const app_native_input = @import("../input/native.zig");
const app_dashboard = @import("../app_dashboard.zig");
const app_hardware_dashboard = @import("../app_hardware_dashboard.zig");
const app_encrypted_chat = @import("../app_encrypted_chat.zig");
const app_pipeline_dashboard = @import("../app_pipeline_dashboard.zig");
const component = @import("../ui/components/Component.zig");
const ui = @import("../ui/core.zig");
const bytes_mod = @import("../bytes.zig");

const surface = @import("surface.zig");
const icon_pack = @import("../ui/icon_pack.zig");

const linux = std.os.linux;
const posix = std.posix;

pub const AppState = app_native_input.State;

pub const default_refresh_hz = surface.default_refresh_hz;
pub const max_commands: usize = 4096;
pub const max_clips: usize = 64;
pub const max_interaction_regions: usize = 1024;
const lens_base_id: u32 = 305_000;

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

pub const WorkspaceLens = enum(u32) {
    agent = lens_base_id,
    pipeline = lens_base_id + 1,
    hardware = lens_base_id + 2,
    chat = lens_base_id + 3,
    network = lens_base_id + 4,
};

pub fn renderNativeAppScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, state: AppState, dashboard_state: *app_dashboard.State, dashboard_mode: bool, hardware_state: ?*app_hardware_dashboard.State, hardware_mode: bool, chat_state: ?*app_encrypted_chat.State, chat_mode: bool, pipeline_state: ?*app_pipeline_dashboard.State, pipeline_mode: bool) !void {
    try renderNativeWorkspaceScene(scene, collector, width, height, state, dashboard_state, hardware_state, chat_state, pipeline_state, lensFromLegacyModes(dashboard_mode, hardware_mode, chat_mode, pipeline_mode));
}

fn renderNativeWorkspaceScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, state: AppState, dashboard_state: *app_dashboard.State, hardware_state: ?*app_hardware_dashboard.State, chat_state: ?*app_encrypted_chat.State, pipeline_state: ?*app_pipeline_dashboard.State, active_lens: WorkspaceLens) !void {
    try renderClientDecoration(scene, collector, @floatFromInt(width));
    const content_y = protocol.client_decor_h;
    const content_h = @max(1.0, @as(f32, @floatFromInt(height)) - content_y);
    const bounds = ui.Rect.init(0, content_y, @floatFromInt(width), content_h);
    try renderWorkspaceSystem(scene, collector, bounds, state, dashboard_state, hardware_state, chat_state, pipeline_state, active_lens);
    try renderResizeAffordance(scene, @floatFromInt(width), @floatFromInt(height));
    try addResizeHits(scene, collector, @floatFromInt(width), @floatFromInt(height));
}

fn renderWorkspaceSystem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: AppState, dashboard_state: *app_dashboard.State, hardware_state: ?*app_hardware_dashboard.State, chat_state: ?*app_encrypted_chat.State, pipeline_state: ?*app_pipeline_dashboard.State, active_lens: WorkspaceLens) !void {
    const app = component.renderer(scene, collector, hardwareRenderOptions(state));
    const design = @import("../ui/theme.zig");
    const shell = try app.workspaceSurface(bounds, .{
        .shell = .{ .sidebar_w = 292.0 },
        .background = design.Palette.bg,
        .top = .{
            .title = "EdgeRun workspace",
            .detail = lensDetail(active_lens),
            .trailing_top = "active lens",
            .trailing_bottom = lensTitle(active_lens),
            .fill = design.workspace_sidebar_bg,
            .detail_color = design.Palette.muted,
        },
        .status = .{
            .text = locationStatus(state.location),
            .fill = design.workspace_status_bg,
        },
    });
    try renderWorkspaceLensRail(app, shell.rail, active_lens);
    try renderWorkspaceLensSidebar(app, shell.sidebar, state, active_lens);
    try renderWorkspaceLensMain(app, shell.main, state, dashboard_state, hardware_state, chat_state, pipeline_state, active_lens);
}

fn renderWorkspaceLensRail(app: component.View, bounds: ui.Rect, active_lens: WorkspaceLens) !void {
    const design = @import("../ui/theme.zig");
    const specs = [_]component.IconButtonSpec{
        .{ .id = @intFromEnum(WorkspaceLens.agent), .label = "Agent", .icon = .ai_agent, .variant = if (active_lens == .agent) .primary else .ghost },
        .{ .id = @intFromEnum(WorkspaceLens.pipeline), .label = "Pipeline", .icon = .git_branch, .variant = if (active_lens == .pipeline) .primary else .ghost },
        .{ .id = @intFromEnum(WorkspaceLens.hardware), .label = "Hardware", .icon = .cpu, .variant = if (active_lens == .hardware) .primary else .ghost },
        .{ .id = @intFromEnum(WorkspaceLens.chat), .label = "Chat", .icon = .message_2, .variant = if (active_lens == .chat) .primary else .ghost },
        .{ .id = @intFromEnum(WorkspaceLens.network), .label = "Network", .icon = .network, .variant = if (active_lens == .network) .primary else .ghost },
    };
    try app.workspaceRail(bounds, .{
        .actions = &specs,
        .fill = design.workspace_rail_bg,
        .pad_top = design.workspace_rail_pad,
        .button_h = design.workspace_icon_button,
        .gap = 8.0,
    });
}

fn renderWorkspaceLensSidebar(app: component.View, bounds: ui.Rect, state: AppState, active_lens: WorkspaceLens) !void {
    const design = @import("../ui/theme.zig");
    const nav_h: f32 = 116.0;
    const body = try app.workspaceSidebarChrome(bounds, .{
        .fill = design.workspace_sidebar_bg,
        .border = design.Palette.border,
        .body_y = nav_h,
        .title = "",
        .detail = "",
    });
    var nav_rows = app.column(ui.Rect.init(bounds.x + 12.0, bounds.y + 12.0, bounds.w - 24.0, nav_h - 18.0), 6.0);
    for (app_location.topLevelBindings()) |binding| {
        const row = nav_rows.take(44.0);
        try app_chrome.renderNavItemView(app, .{
            .kind = .workspace_sidebar,
            .binding = binding,
            .bounds = row,
            .active = std.meta.eql(state.location, binding.location),
        });
    }
    const items = [_]component.PanelListItem{
        lensItem(.agent, active_lens),
        lensItem(.pipeline, active_lens),
        lensItem(.hardware, active_lens),
        lensItem(.chat, active_lens),
        lensItem(.network, active_lens),
    };
    try app.panelList(ui.Rect.init(bounds.x + 12.0, body.y, bounds.w - 24.0, @max(1.0, bounds.y + bounds.h - body.y - 12.0)), .{
        .title = "EDGERUN",
        .detail = "workspace objects",
        .icon = .layout_dashboard,
        .items = &items,
        .row_h = 52.0,
        .gap = 6.0,
        .inset = 12.0,
    });
}

fn renderWorkspaceLensMain(app: component.View, bounds: ui.Rect, state: AppState, dashboard_state: *app_dashboard.State, hardware_state: ?*app_hardware_dashboard.State, chat_state: ?*app_encrypted_chat.State, pipeline_state: ?*app_pipeline_dashboard.State, active_lens: WorkspaceLens) !void {
    if (try app.pushClip(bounds)) {
        defer app.popClip();
        const content = bounds.insetUniform(12.0);
        switch (active_lens) {
            .agent => try app_agent.renderView(app, content, state.agent),
            .pipeline => if (pipeline_state) |ps| try ps.renderView(app.withOptions(hardwareRenderOptions(state)), content),
            .hardware => if (hardware_state) |hs| try hs.renderView(app.withOptions(hardwareRenderOptions(state)), content),
            .chat => if (chat_state) |cs| try cs.renderView(app.withOptions(hardwareRenderOptions(state)), content),
            .network => {
                try dashboard_state.refresh();
                try dashboard_state.renderView(app.withStyle(@import("../ui/theme.zig").appStyle()), content);
            },
        }
    }
}

fn lensItem(lens: WorkspaceLens, active_lens: WorkspaceLens) component.PanelListItem {
    return .{
        .id = @intFromEnum(lens),
        .title = lensTitle(lens),
        .detail = lensDetail(lens),
        .icon = lensIcon(lens),
        .active = lens == active_lens,
    };
}

fn lensFromLegacyModes(dashboard_mode: bool, hardware_mode: bool, chat_mode: bool, pipeline_mode: bool) WorkspaceLens {
    if (pipeline_mode) return .pipeline;
    if (hardware_mode) return .hardware;
    if (chat_mode) return .chat;
    if (dashboard_mode) return .network;
    return .agent;
}

fn initialLens(options: @import("options.zig").Options) WorkspaceLens {
    return lensFromLegacyModes(options.dashboard, options.hardware, options.chat, options.pipeline);
}

fn lensFromHit(hit_id: u32) ?WorkspaceLens {
    return switch (hit_id) {
        @intFromEnum(WorkspaceLens.agent) => .agent,
        @intFromEnum(WorkspaceLens.pipeline) => .pipeline,
        @intFromEnum(WorkspaceLens.hardware) => .hardware,
        @intFromEnum(WorkspaceLens.chat) => .chat,
        @intFromEnum(WorkspaceLens.network) => .network,
        else => null,
    };
}

fn lensTitle(lens: WorkspaceLens) []const u8 {
    return switch (lens) {
        .agent => "Agent",
        .pipeline => "Pipeline",
        .hardware => "Hardware",
        .chat => "Chat",
        .network => "Network",
    };
}

fn lensDetail(lens: WorkspaceLens) []const u8 {
    return switch (lens) {
        .agent => "intent, tools, and visible work log",
        .pipeline => "paths, transforms, budgets, commit",
        .hardware => "resource signals and local controls",
        .chat => "messages as runtime events",
        .network => "host connectivity and transport state",
    };
}

fn locationStatus(location: app_location.Location) []const u8 {
    if (app_location.isSourceWorkspace(location)) return "workspace";
    if (app_location.isAppPreview(location)) return "preview";
    return "object";
}

fn lensIcon(lens: WorkspaceLens) @import("../ui/icon.zig").Icon {
    return switch (lens) {
        .agent => .ai_agent,
        .pipeline => .git_branch,
        .hardware => .cpu,
        .chat => .message_2,
        .network => .network,
    };
}

fn renderClientDecoration(scene: *ui.Scene, collector: *interaction.Collector, width: f32) !void {
    const app = component.renderer(scene, collector, .{});
    const bounds = ui.Rect.init(0.0, 0.0, width, protocol.client_decor_h);
    try app.fill(bounds, protocol.client_decor_bg, 0.0);
    try app.fill(ui.Rect.init(0.0, protocol.client_decor_h - 1.0, width, 1.0), protocol.client_decor_border, 0.0);
    try app.text(ui.Rect.init(14.0, 8.0, @max(1.0, width - 168.0), 15.0), "EdgeRun Native", protocol.client_decor_text);

    const close = clientDecorButton(width, 0);
    const minimize = clientDecorButton(width, 1);
    try app.stroke(minimize, protocol.client_decor_border, 12.0);
    try app.fill(centeredRect(minimize, protocol.client_decor_minimize_w, protocol.client_decor_minimize_h), protocol.client_decor_dim, 1.0);
    try app.buttonHit(minimize, protocol.client_decor_minimize_id);

    try app.stroke(close, protocol.client_decor_border, 12.0);
    try app.icon(centeredRect(close, protocol.client_decor_icon_size, protocol.client_decor_icon_size), .x, protocol.client_decor_dim);
    try app.buttonHit(close, protocol.client_decor_close_id);

    const drag_w = @max(1.0, minimize.x - protocol.client_decor_button_gap - 140.0);
    try app.buttonHit(ui.Rect.init(0.0, 0.0, drag_w, protocol.client_decor_h), protocol.client_decor_drag_id);
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

fn addResizeHits(scene: *ui.Scene, collector: *interaction.Collector, width: f32, height: f32) !void {
    const app = component.renderer(scene, collector, .{});
    const m = protocol.client_decor_resize_margin;
    try app.buttonHit(ui.Rect.init(0.0, 0.0, m, height), protocol.client_decor_resize_left_id);
    try app.buttonHit(ui.Rect.init(@max(0.0, width - m), 0.0, m, height), protocol.client_decor_resize_right_id);
    try app.buttonHit(ui.Rect.init(0.0, 0.0, width, m), protocol.client_decor_resize_top_id);
    try app.buttonHit(ui.Rect.init(0.0, @max(0.0, height - m), width, m), protocol.client_decor_resize_bottom_id);
    try app.buttonHit(ui.Rect.init(0.0, 0.0, m * 2.0, m * 2.0), protocol.client_decor_resize_top_left_id);
    try app.buttonHit(ui.Rect.init(@max(0.0, width - m * 2.0), 0.0, m * 2.0, m * 2.0), protocol.client_decor_resize_top_right_id);
    try app.buttonHit(ui.Rect.init(0.0, @max(0.0, height - m * 2.0), m * 2.0, m * 2.0), protocol.client_decor_resize_bottom_left_id);
    try app.buttonHit(ui.Rect.init(@max(0.0, width - m * 2.0), @max(0.0, height - m * 2.0), m * 2.0, m * 2.0), protocol.client_decor_resize_bottom_right_id);
}

fn renderResizeAffordance(scene: *ui.Scene, width: f32, height: f32) ui.RenderError!void {
    const app = component.renderer(scene, null, .{});
    const edge = ui.Color{ .r = 110, .g = 121, .b = 136, .a = 70 };
    const corner = ui.Color{ .r = 166, .g = 181, .b = 198, .a = 130 };
    try app.fill(ui.Rect.init(0.0, 0.0, width, 1.0), edge, 0.0);
    try app.fill(ui.Rect.init(0.0, @max(0.0, height - 1.0), width, 1.0), edge, 0.0);
    try app.fill(ui.Rect.init(0.0, 0.0, 1.0, height), edge, 0.0);
    try app.fill(ui.Rect.init(@max(0.0, width - 1.0), 0.0, 1.0, height), edge, 0.0);
    const s: f32 = 18.0;
    const t: f32 = 2.0;
    try app.fill(ui.Rect.init(width - s, height - t - 5.0, s - 5.0, t), corner, 0.0);
    try app.fill(ui.Rect.init(width - t - 5.0, height - s, t, s - 5.0), corner, 0.0);
}

fn resizeEdgeForHit(hit_id: u32) ?u32 {
    return switch (hit_id) {
        protocol.client_decor_resize_left_id => protocol.xdg_toplevel_resize_edge_left,
        protocol.client_decor_resize_right_id => protocol.xdg_toplevel_resize_edge_right,
        protocol.client_decor_resize_top_id => protocol.xdg_toplevel_resize_edge_top,
        protocol.client_decor_resize_bottom_id => protocol.xdg_toplevel_resize_edge_bottom,
        protocol.client_decor_resize_top_left_id => protocol.xdg_toplevel_resize_edge_top_left,
        protocol.client_decor_resize_top_right_id => protocol.xdg_toplevel_resize_edge_top_right,
        protocol.client_decor_resize_bottom_left_id => protocol.xdg_toplevel_resize_edge_bottom_left,
        protocol.client_decor_resize_bottom_right_id => protocol.xdg_toplevel_resize_edge_bottom_right,
        else => null,
    };
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
    chat_app: app_encrypted_chat.State = undefined,
    pipeline_app: app_pipeline_dashboard.State = .{},
    dashboard: bool = false,
    hardware: bool = false,
    chat: bool = false,
    pipeline: bool = false,
    active_lens: WorkspaceLens = .agent,
    ui_stream: @import("options.zig").UiStreamMode = .off,
    ui_stream_fd: posix.fd_t = 0,
    ui_stream_buffer: [client.max_socket_read_bytes]u8 = undefined,
    ui_stream_len: usize = 0,

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
        self.chat_app = try app_encrypted_chat.State.initDemo();
        self.pipeline_app = .{};
        self.dashboard = options.dashboard;
        self.hardware = options.hardware;
        self.chat = options.chat;
        self.pipeline = options.pipeline;
        self.active_lens = initialLens(options);
        self.ui_stream = options.ui_stream;
        self.ui_stream_len = 0;
        if (self.hardware) self.hardware_app.refresh();
        if (client_ptr.state.configured_width != 0 and client_ptr.state.configured_height != 0) {
            try self.surface.resize(client_ptr, client_ptr.state.configured_width, client_ptr.state.configured_height);
        }
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
        try renderNativeWorkspaceScene(&scene, &collector, self.surface.width, self.surface.height, self.state, &self.dashboard_app, &self.hardware_app, &self.chat_app, &self.pipeline_app, self.active_lens);
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
        var needs_render = self.receiveUiStream();
        if (self.hardware_app.tick()) needs_render = true;
        if (needs_render) self.renderSafe(client_ptr);
    }

    fn receiveUiStream(self: *NativeApp) bool {
        if (self.ui_stream != .receive and self.ui_stream != .both) return false;
        var fds = [_]posix.pollfd{.{ .fd = self.ui_stream_fd, .events = linux.POLL.IN, .revents = 0 }};
        const ready = posix.poll(&fds, 0) catch return false;
        if (ready == 0 or (fds[0].revents & linux.POLL.IN) == 0) return false;
        if (self.ui_stream_len == self.ui_stream_buffer.len) self.ui_stream_len = 0;
        const n = posix.read(self.ui_stream_fd, self.ui_stream_buffer[self.ui_stream_len..]) catch return false;
        if (n == 0) return false;
        self.ui_stream_len += n;
        var offset: usize = 0;
        var applied = false;
        while (offset < self.ui_stream_len) {
            const frame_len = app_agent.messageLen(self.ui_stream_buffer[offset..self.ui_stream_len]) orelse break;
            self.state.agent.applyMessage(self.ui_stream_buffer[offset..][0..frame_len]) catch |err| {
                self.state.agent.connected = false;
                self.state.agent.thinking = false;
                self.state.agent.status.set(@errorName(err));
            };
            offset += frame_len;
            applied = true;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.ui_stream_buffer[0 .. self.ui_stream_len - offset], self.ui_stream_buffer[offset..self.ui_stream_len]);
            self.ui_stream_len -= offset;
        }
        return applied;
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
        if (kind == .xdg_toplevel and message.opcode == protocol.xdg_toplevel_configure_event) {
            if (client_ptr.state.configured_width != 0 and client_ptr.state.configured_height != 0) {
                try self.surface.resize(client_ptr, client_ptr.state.configured_width, client_ptr.state.configured_height);
                app_native_input.clearHover(&self.state);
                return true;
            }
            return false;
        }
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
                        if (self.state.last_action_kind == .activated) {
                            self.activateWorkspaceLens();
                            self.hardware_app.activate(self.state.runtime.hovered, self.state.runtime.persisted_value);
                            self.chat_app.activate(self.state.runtime.hovered);
                            self.pipeline_app.activate(self.state.runtime.hovered, self.state.runtime.persisted_value);
                        }
                        try self.activateClientDecoration(client_ptr);
                    } else {
                        app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_down);
                        if (resizeEdgeForHit(self.state.runtime.hoverHitId())) |edge| try client_ptr.sendResize(serial, edge);
                        if (self.state.runtime.hoverHitId() == protocol.client_decor_drag_id) try client_ptr.sendMove(serial);
                    }
                } else if (button == protocol.wl_pointer_button_right and state == protocol.wl_pointer_button_released) {
                    app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), self.routedPointerHit(), .pointer_move);
                    if (self.active_lens == .hardware) self.hardware_app.openContext(self.state.runtime.hovered, self.state.hover_x, self.state.hover_y);
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

    fn activateWorkspaceLens(self: *NativeApp) void {
        const hit_id = self.state.runtime.hoverHitId();
        if (lensFromHit(hit_id)) |lens| self.active_lens = lens;
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
        .rect, .overlay_rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasIcon(commands: []const ui.Command, value: component.Icon) bool {
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

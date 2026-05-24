const std = @import("std");
const input = @import("input.zig");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_gles = @import("renderer_gles.zig");
const renderer_ir = @import("renderer_ir.zig");
const site_apps = @import("site_apps.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");
const site_cursor = @import("site_cursor.zig");
const site_images = @import("site_images.zig");
const site_landing = @import("site_landing.zig");
const site_navigation = @import("site_navigation.zig");
const ui = @import("ui.zig");
const ui_runtime = @import("ui_runtime.zig");

const linux = std.os.linux;
const posix = std.posix;

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-cursor.h");
    @cInclude("wayland-egl.h");
    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("EGL/egl.h");
});

const default_width: i32 = 960;
const default_height: i32 = 540;
const default_seconds: u32 = 5;
const default_surface_scale: i32 = 2;
const frame_ms: i32 = 16;
const wayland_fixed_scale: f32 = 256.0;
const pointer_button_left: u32 = 0x110;
const wl_seat_protocol_version: u32 = 1;
const cursor_size: c_int = 24;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
);

const Options = struct {
    width: i32 = default_width,
    height: i32 = default_height,
    scale: i32 = default_surface_scale,
    seconds: u32 = default_seconds,
};

const PointerEvent = enum {
    none,
    enter,
    leave,
    move,
    down,
    up,
};

const WaylandState = struct {
    display: *c.wl_display,
    registry: *c.wl_registry,
    compositor: ?*c.wl_compositor = null,
    shm: ?*c.wl_shm = null,
    wm_base: ?*c.xdg_wm_base = null,
    seat: ?*c.wl_seat = null,
    pointer: ?*c.wl_pointer = null,
    surface: ?*c.wl_surface = null,
    cursor: ?CursorState = null,
    xdg_surface: ?*c.xdg_surface = null,
    toplevel: ?*c.xdg_toplevel = null,
    configured: bool = false,
    closed: bool = false,
    resized: bool = false,
    input_dirty: bool = false,
    cursor_dirty: bool = false,
    pointer_serial: u32 = 0,
    pointer_event: PointerEvent = .none,
    app: *AppState,
    width: i32,
    height: i32,
    scale: i32,

    fn framebufferWidth(self: WaylandState) i32 {
        return self.width * self.scale;
    }

    fn framebufferHeight(self: WaylandState) i32 {
        return self.height * self.scale;
    }
};

const CursorState = struct {
    theme: *c.wl_cursor_theme,
    surface: *c.wl_surface,
    kind: ?site_cursor.Kind = null,

    fn set(self: *CursorState, pointer: *c.wl_pointer, serial: u32, kind: site_cursor.Kind) !void {
        const cursor = c.wl_cursor_theme_get_cursor(self.theme, site_cursor.waylandName(kind).ptr) orelse return error.MissingWaylandCursor;
        if (cursor.*.image_count == 0) return error.MissingWaylandCursorImage;
        const image = cursor.*.images[0];
        const buffer = c.wl_cursor_image_get_buffer(image) orelse return error.MissingWaylandCursorBuffer;
        c.wl_pointer_set_cursor(pointer, serial, self.surface, @intCast(image.*.hotspot_x), @intCast(image.*.hotspot_y));
        c.wl_surface_attach(self.surface, buffer, 0, 0);
        c.wl_surface_damage_buffer(self.surface, 0, 0, @intCast(image.*.width), @intCast(image.*.height));
        c.wl_surface_commit(self.surface);
        self.kind = kind;
    }
};

const EglState = struct {
    display: c.EGLDisplay,
    context: c.EGLContext,
    surface: c.EGLSurface,
    window: *c.wl_egl_window,

    fn surfaceSize(self: EglState) !SurfaceSize {
        var width: c.EGLint = 0;
        var height: c.EGLint = 0;
        if (c.eglQuerySurface(self.display, self.surface, c.EGL_WIDTH, &width) != c.EGL_TRUE) return error.EglSurfaceQueryFailed;
        if (c.eglQuerySurface(self.display, self.surface, c.EGL_HEIGHT, &height) != c.EGL_TRUE) return error.EglSurfaceQueryFailed;
        if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
        return .{ .width = width, .height = height };
    }
};

const SurfaceSize = struct {
    width: i32,
    height: i32,
};

const SceneState = struct {
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    ir_storage: IrStorage = .{},
    command_len: usize = 0,

    fn rebuild(self: *SceneState, width: i32, height: i32, app: AppState, font_atlas: *renderer_font_atlas.Atlas) !renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        const bounds = ui.Rect.init(
            0,
            0,
            @floatFromInt(width),
            @floatFromInt(height),
        );
        switch (app.route.view) {
            .landing => try site_landing.render(&scene, bounds, app.landingState()),
            .blog => try site_blog.render(&scene, bounds, app.blogState()),
            .apps => try site_apps.render(&scene, bounds, app.appsState()),
        }
        self.command_len = scene.written().len;
        const buffers = self.ir_storage.buffers();
        try renderer_ir.packScene(buffers, renderer_gles.sources(font_atlas), scene.written());
        return buffers;
    }

    fn commandSlice(self: *const SceneState) []const ui.Command {
        return self.commands[0..self.command_len];
    }
};

const AppState = struct {
    route: site_navigation.Route = .{},
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    runtime: ui_runtime.State = .{},
    last_action_kind: ui_runtime.ActionKind = .none,
    hover_hit_kind: ?ui.HitKind = null,
    hover_hit_id: u32 = 0,
    public_identity_ready: bool = true,
    public_identity: []const u8 = "native-egl-gpu",

    fn landingState(self: AppState) site_landing.State {
        return .{
            .scroll_y = self.scroll_y,
            .hover_x = self.hover_x,
            .hover_y = self.hover_y,
            .public_identity_ready = self.public_identity_ready,
            .public_identity = self.public_identity,
        };
    }

    fn blogState(self: AppState) site_blog.State {
        return .{
            .scroll_y = self.scroll_y,
            .hover_x = self.hover_x,
            .hover_y = self.hover_y,
            .selected_post_id = self.route.selected_blog_post_id,
            .arc_filter_index = self.route.blog_arc_filter_index,
        };
    }

    fn appsState(self: AppState) site_apps.State {
        return .{
            .scroll_y = self.scroll_y,
            .hover_x = self.hover_x,
            .hover_y = self.hover_y,
        };
    }

    fn contentHeight(self: AppState, width: f32) f32 {
        return switch (self.route.view) {
            .landing => site_landing.contentHeight(width),
            .blog => if (self.route.selected_blog_post_id == 0)
                site_blog.indexContentHeightFiltered(width, self.route.blog_arc_filter_index)
            else
                site_blog.postContentHeight(width, self.route.selected_blog_post_id),
            .apps => site_apps.contentHeight(width),
        };
    }

    fn applyRoute(self: *AppState, route: site_navigation.Route) void {
        self.route = route;
        self.scroll_y = 0.0;
    }

    fn cursorKind(self: AppState) site_cursor.Kind {
        return site_cursor.fromState(self.last_action_kind, self.hover_hit_kind);
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);

    var app = AppState{};
    var wl: WaylandState = undefined;
    try initWayland(&wl, options.width, options.height, options.scale, &app);
    defer deinitWayland(&wl);
    var egl = try initEgl(&wl);
    defer deinitEgl(&egl);
    var font_atlas = renderer_font_atlas.Atlas.init();
    const cloud_meme = try site_images.cloudMeme();
    var gl = try renderer_gles.init(&font_atlas, .{
        .width = cloud_meme.width,
        .height = cloud_meme.height,
        .pixels = cloud_meme.pixels,
    });
    defer renderer_gles.deinit(&gl);

    var scene_state = SceneState{};
    var buffers = try scene_state.rebuild(wl.width, wl.height, app, &font_atlas);
    renderer_gles.refreshFontTexture(gl, &font_atlas);
    updateHoverHit(&app, scene_state.commandSlice());

    var frames_remaining: u32 = options.seconds * 60;
    var frame_verified = false;
    while (!wl.closed and frames_remaining != 0) : (frames_remaining -= 1) {
        try pumpWaylandEvents(&wl);

        if (wl.resized) {
            c.wl_egl_window_resize(egl.window, wl.framebufferWidth(), wl.framebufferHeight(), 0, 0);
            buffers = try scene_state.rebuild(wl.width, wl.height, app, &font_atlas);
            renderer_gles.refreshFontTexture(gl, &font_atlas);
            updateHoverHit(&app, scene_state.commandSlice());
            wl.resized = false;
        } else if (wl.input_dirty) {
            processPointerEvent(&wl, scene_state.commandSlice());
            buffers = try scene_state.rebuild(wl.width, wl.height, app, &font_atlas);
            renderer_gles.refreshFontTexture(gl, &font_atlas);
            updateHoverHit(&app, scene_state.commandSlice());
            wl.cursor_dirty = true;
            wl.input_dirty = false;
        }
        if (wl.cursor_dirty) {
            try updateWaylandCursor(&wl);
            wl.cursor_dirty = false;
        }
        const framebuffer = try egl.surfaceSize();
        try renderer_gles.renderFrameToViewport(gl, wl.width, wl.height, framebuffer.width, framebuffer.height, buffers);
        if (!frame_verified) {
            _ = try renderer_gles.verifyFrameNonBlank(framebuffer.width, framebuffer.height);
            frame_verified = true;
        }
        if (c.eglSwapBuffers(egl.display, egl.surface) != c.EGL_TRUE) return error.EglSwapFailed;
        sleepFrame();
    }
}

fn pumpWaylandEvents(wl: *WaylandState) !void {
    while (c.wl_display_prepare_read(wl.display) != 0) {
        if (c.wl_display_dispatch_pending(wl.display) < 0) return error.WaylandDispatchFailed;
    }
    if (c.wl_display_flush(wl.display) < 0) {
        c.wl_display_cancel_read(wl.display);
        return error.WaylandFlushFailed;
    }

    var fds = [_]posix.pollfd{.{
        .fd = c.wl_display_get_fd(wl.display),
        .events = linux.POLL.IN,
        .revents = 0,
    }};
    const ready = try posix.poll(&fds, 0);
    if ((fds[0].revents & (linux.POLL.ERR | linux.POLL.HUP | linux.POLL.NVAL)) != 0) {
        c.wl_display_cancel_read(wl.display);
        return error.WaylandPollFailed;
    }
    if (ready != 0 and (fds[0].revents & linux.POLL.IN) != 0) {
        if (c.wl_display_read_events(wl.display) < 0) return error.WaylandReadFailed;
    } else {
        c.wl_display_cancel_read(wl.display);
    }
    if (c.wl_display_dispatch_pending(wl.display) < 0) return error.WaylandDispatchFailed;
}

fn sleepFrame() void {
    const req = linux.timespec{ .sec = 0, .nsec = frame_ms * std.time.ns_per_ms };
    _ = linux.nanosleep(&req, null);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.width = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.height = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--scale")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.scale = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width <= 0 or options.height <= 0 or options.scale <= 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

fn initWayland(state: *WaylandState, width: i32, height: i32, scale: i32, app: *AppState) !void {
    const display = c.wl_display_connect(null) orelse return error.WaylandConnectFailed;
    errdefer c.wl_display_disconnect(display);
    const registry = c.wl_display_get_registry(display) orelse return error.WaylandRegistryFailed;
    state.* = .{ .display = display, .registry = registry, .app = app, .width = width, .height = height, .scale = scale };
    if (c.wl_registry_add_listener(registry, &registry_listener, state) != 0) return error.WaylandRegistryFailed;
    if (c.wl_display_roundtrip(display) < 0) return error.WaylandRoundtripFailed;
    const compositor = state.compositor orelse return error.MissingWaylandCompositor;
    const shm = state.shm orelse return error.MissingWaylandShm;
    const wm_base = state.wm_base orelse return error.MissingXdgWmBase;
    if (c.xdg_wm_base_add_listener(wm_base, &wm_base_listener, state) != 0) return error.XdgListenerFailed;
    if (state.seat) |seat| {
        if (c.wl_seat_add_listener(seat, &seat_listener, state) != 0) return error.WaylandSeatListenerFailed;
    }
    state.surface = c.wl_compositor_create_surface(compositor) orelse return error.WaylandSurfaceFailed;
    state.cursor = try initCursor(compositor, shm);
    c.wl_surface_set_buffer_scale(state.surface, scale);
    state.xdg_surface = c.xdg_wm_base_get_xdg_surface(wm_base, state.surface) orelse return error.XdgSurfaceFailed;
    if (c.xdg_surface_add_listener(state.xdg_surface, &xdg_surface_listener, state) != 0) return error.XdgListenerFailed;
    state.toplevel = c.xdg_surface_get_toplevel(state.xdg_surface) orelse return error.XdgToplevelFailed;
    if (c.xdg_toplevel_add_listener(state.toplevel, &xdg_toplevel_listener, state) != 0) return error.XdgListenerFailed;
    c.xdg_toplevel_set_title(state.toplevel, "EdgeRun EGL GPU");
    c.wl_surface_commit(state.surface);
    while (!state.configured) {
        if (c.wl_display_dispatch(display) < 0) return error.WaylandDispatchFailed;
    }
}

fn deinitWayland(state: *WaylandState) void {
    if (state.cursor) |value| {
        c.wl_surface_destroy(value.surface);
        c.wl_cursor_theme_destroy(value.theme);
    }
    if (state.pointer) |value| c.wl_pointer_destroy(value);
    if (state.seat) |value| c.wl_seat_destroy(value);
    if (state.toplevel) |value| c.xdg_toplevel_destroy(value);
    if (state.xdg_surface) |value| c.xdg_surface_destroy(value);
    if (state.surface) |value| c.wl_surface_destroy(value);
    if (state.wm_base) |value| c.xdg_wm_base_destroy(value);
    if (state.shm) |value| c.wl_shm_destroy(value);
    if (state.compositor) |value| c.wl_compositor_destroy(value);
    c.wl_registry_destroy(state.registry);
    c.wl_display_disconnect(state.display);
}

fn initCursor(compositor: *c.wl_compositor, shm: *c.wl_shm) !CursorState {
    const theme = c.wl_cursor_theme_load(null, cursor_size, shm) orelse return error.WaylandCursorThemeFailed;
    errdefer c.wl_cursor_theme_destroy(theme);
    const surface = c.wl_compositor_create_surface(compositor) orelse return error.WaylandCursorSurfaceFailed;
    errdefer c.wl_surface_destroy(surface);
    const cursor = CursorState{ .theme = theme, .surface = surface };
    _ = c.wl_cursor_theme_get_cursor(cursor.theme, site_cursor.waylandName(.default).ptr) orelse return error.MissingWaylandCursor;
    _ = c.wl_cursor_theme_get_cursor(cursor.theme, site_cursor.waylandName(.pointer).ptr) orelse return error.MissingWaylandCursor;
    _ = c.wl_cursor_theme_get_cursor(cursor.theme, site_cursor.waylandName(.text).ptr) orelse return error.MissingWaylandCursor;
    _ = c.wl_cursor_theme_get_cursor(cursor.theme, site_cursor.waylandName(.grabbing).ptr) orelse return error.MissingWaylandCursor;
    return cursor;
}

fn initEgl(wl: *WaylandState) !EglState {
    const egl_display = c.eglGetDisplay(@ptrCast(wl.display));
    if (egl_display == c.EGL_NO_DISPLAY) return error.EglDisplayFailed;
    var major: c.EGLint = 0;
    var minor: c.EGLint = 0;
    if (c.eglInitialize(egl_display, &major, &minor) != c.EGL_TRUE) return error.EglInitializeFailed;
    if (c.eglBindAPI(c.EGL_OPENGL_ES_API) != c.EGL_TRUE) return error.EglApiFailed;
    const attrs = [_]c.EGLint{
        c.EGL_SURFACE_TYPE,    c.EGL_WINDOW_BIT,
        c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES2_BIT,
        c.EGL_RED_SIZE,        8,
        c.EGL_GREEN_SIZE,      8,
        c.EGL_BLUE_SIZE,       8,
        c.EGL_ALPHA_SIZE,      8,
        c.EGL_NONE,
    };
    var config: c.EGLConfig = null;
    var count: c.EGLint = 0;
    if (c.eglChooseConfig(egl_display, &attrs, &config, 1, &count) != c.EGL_TRUE or count == 0) return error.EglConfigFailed;
    const context_attrs = [_]c.EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };
    const context = c.eglCreateContext(egl_display, config, c.EGL_NO_CONTEXT, &context_attrs);
    if (context == c.EGL_NO_CONTEXT) return error.EglContextFailed;
    errdefer _ = c.eglDestroyContext(egl_display, context);
    const surface = wl.surface orelse return error.WaylandSurfaceFailed;
    const window = c.wl_egl_window_create(surface, wl.framebufferWidth(), wl.framebufferHeight()) orelse return error.EglWindowFailed;
    errdefer c.wl_egl_window_destroy(window);
    const egl_surface = c.eglCreateWindowSurface(egl_display, config, @ptrCast(window), null);
    if (egl_surface == c.EGL_NO_SURFACE) return error.EglSurfaceFailed;
    if (c.eglMakeCurrent(egl_display, egl_surface, egl_surface, context) != c.EGL_TRUE) return error.EglMakeCurrentFailed;
    if (c.eglSwapInterval(egl_display, 1) != c.EGL_TRUE) return error.EglSwapIntervalFailed;
    return .{ .display = egl_display, .context = context, .surface = egl_surface, .window = window };
}

fn deinitEgl(egl: *EglState) void {
    _ = c.eglMakeCurrent(egl.display, c.EGL_NO_SURFACE, c.EGL_NO_SURFACE, c.EGL_NO_CONTEXT);
    _ = c.eglDestroySurface(egl.display, egl.surface);
    _ = c.eglDestroyContext(egl.display, egl.context);
    c.wl_egl_window_destroy(egl.window);
    _ = c.eglTerminate(egl.display);
}

fn updateHoverHit(app: *AppState, commands: []const ui.Command) void {
    if (app.hover_x < 0.0 or app.hover_y < 0.0) {
        app.hover_hit_kind = null;
        app.hover_hit_id = 0;
        return;
    }
    if (input.hitTest(commands, app.hover_x, app.hover_y)) |hit| {
        app.hover_hit_kind = hit.kind;
        app.hover_hit_id = hit.id;
        return;
    }
    app.hover_hit_kind = null;
    app.hover_hit_id = 0;
}

fn updateWaylandCursor(wl: *WaylandState) !void {
    if (wl.pointer_serial == 0) return;
    const pointer = wl.pointer orelse return;
    const cursor = if (wl.cursor) |*value| value else return;
    const kind = wl.app.cursorKind();
    if (cursor.kind != null and cursor.kind.? == kind) return;
    try cursor.set(pointer, wl.pointer_serial, kind);
}

fn processPointerEvent(wl: *WaylandState, commands: []const ui.Command) void {
    const app = wl.app;
    app.last_action_kind = switch (wl.pointer_event) {
        .none => app.last_action_kind,
        .enter, .move => app.runtime.pointerMove(commands, app.hover_x, app.hover_y).kind,
        .leave => blk: {
            app.hover_hit_kind = null;
            app.hover_hit_id = 0;
            break :blk ui_runtime.ActionKind.none;
        },
        .down => app.runtime.pointerDown(commands, app.hover_x, app.hover_y).kind,
        .up => blk: {
            const action = app.runtime.pointerUp(commands, app.hover_x, app.hover_y);
            if (action.kind != .reordered) activateHit(app);
            break :blk action.kind;
        },
    };
    wl.pointer_event = .none;
}

fn activateHit(app: *AppState) void {
    if (site_navigation.fromHit(app.hover_hit_id, app.route)) |route| {
        app.applyRoute(route);
        return;
    }
    switch (app.hover_hit_id) {
        site_landing.reveal_identity_button_id => {
            app.public_identity_ready = true;
            app.public_identity = "native-egl-gpu";
        },
        else => {},
    }
}

fn scrollBy(app: *AppState, width: i32, height: i32, delta_y: f32) void {
    if (!std.math.isFinite(delta_y)) return;
    const limit = @max(0.0, app.contentHeight(@floatFromInt(width)) - @as(f32, @floatFromInt(height)));
    app.scroll_y = std.math.clamp(app.scroll_y + delta_y, 0.0, limit);
}

fn fixedToFloat(value: c.wl_fixed_t) f32 {
    return @as(f32, @floatFromInt(value)) / wayland_fixed_scale;
}

const registry_listener = c.wl_registry_listener{ .global = registryGlobal, .global_remove = registryRemove };
fn registryGlobal(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    const reg = registry.?;
    const iface = std.mem.span(interface);
    if (std.mem.eql(u8, iface, "wl_compositor")) {
        state.compositor = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_compositor_interface, @min(version, 4)));
    } else if (std.mem.eql(u8, iface, "wl_shm")) {
        state.shm = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_shm_interface, @min(version, 1)));
    } else if (std.mem.eql(u8, iface, "xdg_wm_base")) {
        state.wm_base = @ptrCast(c.wl_registry_bind(reg, name, &c.xdg_wm_base_interface, @min(version, 1)));
    } else if (std.mem.eql(u8, iface, "wl_seat")) {
        state.seat = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_seat_interface, @min(version, wl_seat_protocol_version)));
    }
}
fn registryRemove(_: ?*anyopaque, _: ?*c.wl_registry, _: u32) callconv(.c) void {}

const seat_listener = c.wl_seat_listener{ .capabilities = seatCapabilities, .name = seatName };
fn seatCapabilities(data: ?*anyopaque, seat: ?*c.wl_seat, capabilities: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if ((capabilities & c.WL_SEAT_CAPABILITY_POINTER) != 0 and state.pointer == null) {
        state.pointer = c.wl_seat_get_pointer(seat);
        if (state.pointer) |pointer| {
            _ = c.wl_pointer_add_listener(pointer, &pointer_listener, state);
        }
    } else if ((capabilities & c.WL_SEAT_CAPABILITY_POINTER) == 0 and state.pointer != null) {
        c.wl_pointer_destroy(state.pointer.?);
        state.pointer = null;
    }
}
fn seatName(_: ?*anyopaque, _: ?*c.wl_seat, _: [*c]const u8) callconv(.c) void {}

const pointer_listener = c.wl_pointer_listener{
    .enter = pointerEnter,
    .leave = pointerLeave,
    .motion = pointerMotion,
    .button = pointerButton,
    .axis = pointerAxis,
};
fn pointerEnter(data: ?*anyopaque, _: ?*c.wl_pointer, serial: u32, _: ?*c.wl_surface, sx: c.wl_fixed_t, sy: c.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.pointer_serial = serial;
    state.app.hover_x = fixedToFloat(sx);
    state.app.hover_y = fixedToFloat(sy);
    state.pointer_event = .enter;
    state.input_dirty = true;
    state.cursor_dirty = true;
}
fn pointerLeave(data: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: ?*c.wl_surface) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.app.hover_x = -1.0;
    state.app.hover_y = -1.0;
    state.app.hover_hit_kind = null;
    state.app.hover_hit_id = 0;
    state.pointer_event = .leave;
    state.input_dirty = true;
    state.cursor_dirty = true;
}
fn pointerMotion(data: ?*anyopaque, _: ?*c.wl_pointer, _: u32, sx: c.wl_fixed_t, sy: c.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.app.hover_x = fixedToFloat(sx);
    state.app.hover_y = fixedToFloat(sy);
    state.pointer_event = .move;
    state.input_dirty = true;
    state.cursor_dirty = true;
}
fn pointerButton(data: ?*anyopaque, _: ?*c.wl_pointer, serial: u32, _: u32, button: u32, button_state: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.pointer_serial = serial;
    if (button == pointer_button_left and button_state == c.WL_POINTER_BUTTON_STATE_PRESSED) {
        state.pointer_event = .down;
    } else if (button == pointer_button_left and button_state == c.WL_POINTER_BUTTON_STATE_RELEASED) {
        state.pointer_event = .up;
    }
    state.input_dirty = true;
    state.cursor_dirty = true;
}
fn pointerAxis(data: ?*anyopaque, _: ?*c.wl_pointer, _: u32, axis: u32, value: c.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if (axis == c.WL_POINTER_AXIS_VERTICAL_SCROLL) scrollBy(state.app, state.width, state.height, fixedToFloat(value));
    state.input_dirty = true;
}

const wm_base_listener = c.xdg_wm_base_listener{ .ping = wmBasePing };
fn wmBasePing(_: ?*anyopaque, wm_base: ?*c.xdg_wm_base, serial: u32) callconv(.c) void {
    c.xdg_wm_base_pong(wm_base, serial);
}

const xdg_surface_listener = c.xdg_surface_listener{ .configure = xdgSurfaceConfigure };
fn xdgSurfaceConfigure(data: ?*anyopaque, surface: ?*c.xdg_surface, serial: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    c.xdg_surface_ack_configure(surface, serial);
    state.configured = true;
}

const xdg_toplevel_listener = c.xdg_toplevel_listener{ .configure = xdgToplevelConfigure, .close = xdgToplevelClose };
fn xdgToplevelConfigure(data: ?*anyopaque, _: ?*c.xdg_toplevel, width: i32, height: i32, _: ?*c.wl_array) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if (width > 0 and height > 0) {
        if (state.width != width or state.height != height) {
            state.width = width;
            state.height = height;
            state.resized = true;
        }
    }
}
fn xdgToplevelClose(data: ?*anyopaque, _: ?*c.xdg_toplevel) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.closed = true;
}

test "egl host input helpers update hover activation and scroll state" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = site_landing.reveal_identity_button_id, .bounds = ui.Rect.init(8, 8, 80, 32) });

    var app = AppState{ .public_identity_ready = false, .public_identity = "pending" };
    updateHoverHit(&app, scene.written());
    try std.testing.expectEqual(@as(u32, 0), app.hover_hit_id);

    app.hover_x = 16.0;
    app.hover_y = 16.0;
    updateHoverHit(&app, scene.written());
    try std.testing.expectEqual(site_landing.reveal_identity_button_id, app.hover_hit_id);

    activateHit(&app);
    try std.testing.expect(app.public_identity_ready);
    try std.testing.expectEqualStrings("native-egl-gpu", app.public_identity);

    scrollBy(&app, default_width, 200, 120.0);
    try std.testing.expect(app.scroll_y > 0.0);
    const before = app.scroll_y;
    scrollBy(&app, default_width, 200, std.math.nan(f32));
    try std.testing.expectEqual(before, app.scroll_y);
}

test "egl host activation uses shared site navigation routes" {
    var app = AppState{};

    app.hover_hit_id = site_chrome.blog_button_id;
    activateHit(&app);
    try std.testing.expectEqual(site_navigation.View.blog, app.route.view);
    try std.testing.expectEqual(@as(f32, 0.0), app.scroll_y);

    const post_id = site_blog.postIdAt(0);
    app.scroll_y = 120.0;
    app.hover_hit_id = post_id;
    activateHit(&app);
    try std.testing.expectEqual(site_navigation.View.blog, app.route.view);
    try std.testing.expectEqual(post_id, app.route.selected_blog_post_id);
    try std.testing.expectEqual(@as(f32, 0.0), app.scroll_y);

    app.hover_hit_id = site_chrome.apps_button_id;
    activateHit(&app);
    try std.testing.expectEqual(site_navigation.View.apps, app.route.view);

    app.hover_hit_id = site_chrome.logo_button_id;
    activateHit(&app);
    try std.testing.expectEqual(site_navigation.View.landing, app.route.view);
}

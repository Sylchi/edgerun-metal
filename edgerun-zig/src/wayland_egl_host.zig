const std = @import("std");
const bytes = @import("bytes.zig");
const interaction = @import("ui_interaction.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_gles = @import("render/backends/gles.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_parity = @import("render/parity.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const app_cursor = @import("app_cursor.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const app_input_event = @import("app_input_event.zig");
const app_navigation = @import("app_navigation.zig");
const app_native_input = @import("app_native_input.zig");
const ui = @import("ui.zig");
const wl = @import("linux_wayland.zig");
const gpu = @import("linux_gpu.zig");

const linux = std.os.linux;
const posix = std.posix;

const default_width: i32 = 960;
const default_height: i32 = 540;
const default_seconds: u32 = 5;
const default_surface_scale: i32 = 2;
const frame_ms: i32 = 16;
const wayland_fixed_scale: f32 = 256.0;
const pointer_button_left: u32 = 0x110;
const wl_seat_protocol_version: u32 = 1;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_interaction_regions: usize = 1024;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

const Options = struct {
    width: i32 = default_width,
    height: i32 = default_height,
    scale: i32 = default_surface_scale,
    seconds: u32 = default_seconds,
    verify_parity: bool = false,
};

const WaylandState = struct {
    wayland: wl.Wayland,
    display: *wl.WlDisplay,
    registry: *wl.WlRegistry,
    compositor: ?*wl.WlCompositor = null,
    wm_base: ?*wl.XdgWmBase = null,
    seat: ?*wl.WlSeat = null,
    pointer: ?*wl.WlPointer = null,
    surface: ?*wl.WlSurface = null,
    xdg_surface: ?*wl.XdgSurface = null,
    toplevel: ?*wl.XdgToplevel = null,
    configured: bool = false,
    closed: bool = false,
    resized: bool = false,
    input_dirty: bool = false,
    pointer_serial: u32 = 0,
    pointer_event: ?app_input_event.Kind = null,
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

const EglState = struct {
    egl: gpu.Egl,
    display: gpu.EGLDisplay,
    context: gpu.EGLContext,
    surface: gpu.EGLSurface,
    window: *wl.WlEglWindow,

    fn surfaceSize(self: *EglState) !SurfaceSize {
        var width: gpu.EGLint = 0;
        var height: gpu.EGLint = 0;
        if (self.egl.eglQuerySurface(self.display, self.surface, @intCast(gpu.egl_width), &width) != gpu.egl_true) return error.EglSurfaceQueryFailed;
        if (self.egl.eglQuerySurface(self.display, self.surface, @intCast(gpu.egl_height), &height) != gpu.egl_true) return error.EglSurfaceQueryFailed;
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
    regions: [max_interaction_regions]interaction.Region = undefined,
    ir_storage: IrStorage = .{},
    command_len: usize = 0,
    region_len: usize = 0,

    fn rebuild(self: *SceneState, width: i32, height: i32, app: *AppState, font_atlas: *renderer_font_atlas.Atlas) !renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try app_frame.render(&scene, &collector, ui.Rect.init(0, 0, @floatFromInt(width), @floatFromInt(height)), app.frameState());
        updateHoverHit(app, collector.written());
        try app_cursor.render(&scene, app.input.hover_x, app.input.hover_y, app.cursorKind());
        self.command_len = scene.written().len;
        self.region_len = collector.written().len;
        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, font_atlas, .object, scene.written());
        return buffers;
    }

    fn commandSlice(self: *const SceneState) []const ui.Command {
        return self.commands[0..self.command_len];
    }

    fn regionSlice(self: *const SceneState) []const interaction.Region {
        return self.regions[0..self.region_len];
    }
};

const AppState = struct {
    input: app_native_input.State = .{ .public_identity = "native-egl-gpu", .reveal_identity = "native-egl-gpu" },

    fn frameState(self: AppState) app_frame.State {
        return self.input.frameState();
    }

    fn contentHeight(self: AppState, width: f32) f32 {
        return self.input.contentHeight(width);
    }

    fn cursorKind(self: AppState) app_cursor.Kind {
        return self.input.cursorKind();
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);

    var app = AppState{};
    var wl_state: WaylandState = undefined;
    try initWayland(&wl_state, options.width, options.height, options.scale, &app);
    defer deinitWayland(&wl_state);
    var egl = try initEgl(&wl_state);
    defer deinitEgl(&egl);
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    const cloud_meme = try app_images.cloudMeme();
    var gl = try renderer_gles.Adapter.init(&font_atlas, .{
        .width = cloud_meme.width,
        .height = cloud_meme.height,
        .pixels = cloud_meme.pixels,
    });
    defer gl.deinit();

    var scene_state = SceneState{};
    var buffers = try scene_state.rebuild(wl_state.width, wl_state.height, &app, &font_atlas);
    gl.refreshFontTexture(&font_atlas);

    var frames_remaining: u32 = options.seconds * 60;
    var frame_verified = false;
    while (!wl_state.closed and frames_remaining != 0) : (frames_remaining -= 1) {
        try pumpWaylandEvents(&wl_state);

        if (wl_state.resized) {
            wl_state.wayland.wl_egl_window_resize(egl.window, wl_state.framebufferWidth(), wl_state.framebufferHeight(), 0, 0);
            buffers = try scene_state.rebuild(wl_state.width, wl_state.height, &app, &font_atlas);
            gl.refreshFontTexture(&font_atlas);
            wl_state.resized = false;
        } else if (wl_state.input_dirty) {
            processPointerEvent(&wl_state, scene_state.commandSlice(), scene_state.regionSlice());
            buffers = try scene_state.rebuild(wl_state.width, wl_state.height, &app, &font_atlas);
            gl.refreshFontTexture(&font_atlas);
            wl_state.input_dirty = false;
        }
        const framebuffer = try egl.surfaceSize();
        const receipt = try gl.renderFrameToViewport(wl_state.width, wl_state.height, framebuffer.width, framebuffer.height, buffers);
        if (!receipt.valid()) return error.InvalidGlesReceipt;
        if (options.verify_parity) {
            try verifyGpuCpuParity(gl, wl_state.width, wl_state.height, framebuffer.width, framebuffer.height, buffers, &font_atlas, cloud_meme, allocator);
        }
        if (!frame_verified) {
            _ = try gl.verifyFrameNonBlank(framebuffer.width, framebuffer.height);
            frame_verified = true;
        }
        if (egl.egl.eglSwapBuffers(egl.display, egl.surface) != gpu.egl_true) return error.EglSwapFailed;
        sleepFrame();
    }
}

fn pumpWaylandEvents(wl_state: *WaylandState) !void {
    while (wl_state.wayland.wl_display_prepare_read(wl_state.display) != 0) {
        if (wl_state.wayland.wl_display_dispatch_pending(wl_state.display) < 0) return error.WaylandDispatchFailed;
    }
    if (wl_state.wayland.wl_display_flush(wl_state.display) < 0) {
        wl_state.wayland.wl_display_cancel_read(wl_state.display);
        return error.WaylandFlushFailed;
    }

    var fds = [_]posix.pollfd{.{
        .fd = wl_state.wayland.wl_display_get_fd(wl_state.display),
        .events = linux.POLL.IN,
        .revents = 0,
    }};
    const ready = try posix.poll(&fds, 0);
    if ((fds[0].revents & (linux.POLL.ERR | linux.POLL.HUP | linux.POLL.NVAL)) != 0) {
        wl_state.wayland.wl_display_cancel_read(wl_state.display);
        return error.WaylandPollFailed;
    }
    if (ready != 0 and (fds[0].revents & linux.POLL.IN) != 0) {
        if (wl_state.wayland.wl_display_read_events(wl_state.display) < 0) return error.WaylandReadFailed;
    } else {
        wl_state.wayland.wl_display_cancel_read(wl_state.display);
    }
    if (wl_state.wayland.wl_display_dispatch_pending(wl_state.display) < 0) return error.WaylandDispatchFailed;
}

fn sleepFrame() void {
    const req = linux.timespec{ .sec = 0, .nsec = frame_ms * std.time.ns_per_ms };
    _ = linux.nanosleep(&req, null);
}

fn appBackground() ui.Color {
    return .{ .r = 11, .g = 11, .b = 11 };
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (bytes.eql(args[index], "--width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.width = try std.fmt.parseInt(i32, args[index], 10);
        } else if (bytes.eql(args[index], "--height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.height = try std.fmt.parseInt(i32, args[index], 10);
        } else if (bytes.eql(args[index], "--scale")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.scale = try std.fmt.parseInt(i32, args[index], 10);
        } else if (bytes.eql(args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes.eql(args[index], "--verify-parity")) {
            options.verify_parity = true;
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width <= 0 or options.height <= 0 or options.scale <= 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

fn verifyGpuCpuParity(
    gl: renderer_gles.Adapter,
    logical_width: i32,
    logical_height: i32,
    framebuffer_width: i32,
    framebuffer_height: i32,
    buffers: renderer_ir.Buffers,
    font_atlas: *renderer_font_atlas.Atlas,
    image_texture: renderer_software.RgbaTexture,
    allocator: std.mem.Allocator,
) !void {
    if (logical_width <= 0 or logical_height <= 0) return error.InvalidFramebufferSize;
    if (logical_width != framebuffer_width or logical_height != framebuffer_height) return error.UnsupportedParityScale;
    const width: usize = @intCast(logical_width);
    const height: usize = @intCast(logical_height);
    const pixel_count = width * height;
    const expected = try allocator.alloc(ui.Color, pixel_count);
    defer allocator.free(expected);
    const actual = try allocator.alloc(ui.Color, pixel_count);
    defer allocator.free(actual);

    const software_surface = try renderer_software.Framebuffer.init(width, height, expected);
    software_surface.clear(appBackground());
    const software_receipt = try software_surface.renderIr(buffers, renderer_pipeline.softwareResources(font_atlas, image_texture));
    if (!software_receipt.valid()) return error.InvalidSoftwareReceipt;
    const gpu_receipt = try gl.renderFrameToRgbaPixels(logical_width, logical_height, buffers, actual);
    if (!gpu_receipt.valid()) return error.InvalidGlesReceipt;
    const diff = try renderer_parity.compareExact(width, height, expected, actual);
    if (!diff.valid()) {
        const hardware_diff = try renderer_parity.compareHardware(width, height, expected, actual);
        std.debug.print(
            "render parity mismatch: pixels={} mismatches={} max_delta={} hardware_tolerance_mismatches={} first=({}, {}) expected=rgba({},{},{},{}) actual=rgba({},{},{},{}) worst=({}, {}) expected=rgba({},{},{},{}) actual=rgba({},{},{},{})\n",
            .{
                diff.pixel_count,
                diff.mismatch_count,
                diff.max_channel_delta,
                hardware_diff.mismatch_count,
                diff.firstMismatchX(),
                diff.firstMismatchY(),
                diff.first_expected.r,
                diff.first_expected.g,
                diff.first_expected.b,
                diff.first_expected.a,
                diff.first_actual.r,
                diff.first_actual.g,
                diff.first_actual.b,
                diff.first_actual.a,
                diff.worstMismatchX(),
                diff.worstMismatchY(),
                diff.worst_expected.r,
                diff.worst_expected.g,
                diff.worst_expected.b,
                diff.worst_expected.a,
                diff.worst_actual.r,
                diff.worst_actual.g,
                diff.worst_actual.b,
                diff.worst_actual.a,
            },
        );
        printParityPrimitiveAt(buffers, @floatFromInt(diff.firstMismatchX()), @floatFromInt(diff.firstMismatchY()));
        printParityPrimitiveAt(buffers, @floatFromInt(diff.worstMismatchX()), @floatFromInt(diff.worstMismatchY()));
        printParityDeltaBuckets(diff);
        return error.RenderParityMismatch;
    }
}

fn printParityDeltaBuckets(diff: renderer_parity.PixelDiff) void {
    std.debug.print("signed actual-expected channel deltas:", .{});
    for (diff.actual_minus_expected, 0..) |count, index| {
        if (count == 0) continue;
        const delta = @as(i32, @intCast(index)) - 8;
        std.debug.print(" {d}:{}", .{ delta, count });
    }
    std.debug.print("\n", .{});
}

fn printParityPrimitiveAt(buffers: renderer_ir.Buffers, x: f32, y: f32) void {
    printParityRectsAt("base", buffers.liveRects(), x, y);
    printParityTexturedAt("base text", buffers.liveTextVertices(), x, y);
    printParityTexturedAt("base image", buffers.liveImageVertices(), x, y);
    printParityIconsAt("base icon", buffers.liveIconVertices(), x, y);
    printParityRectsAt("overlay", buffers.liveOverlayRects(), x, y);
    printParityTexturedAt("overlay text", buffers.liveOverlayTextVertices(), x, y);
    printParityIconsAt("overlay icon", buffers.liveOverlayIconVertices(), x, y);
}

fn printParityRectsAt(label: []const u8, values: []const f32, x: f32, y: f32) void {
    var iter = renderer_ir.RectIterator.init(values) catch return;
    while (iter.next() catch return) |rect| {
        const influence = switch (rect.mode) {
            .shadow => rect.bounds.insetUniform(-rect.shadow),
            .fill, .border, .linear_gradient, .pie_slice => rect.bounds,
        };
        if (influence.containsInclusive(x, y)) {
            std.debug.print(
                "  {s} rect mode={any} bounds=({d:.2},{d:.2},{d:.2},{d:.2}) radius={d:.2} shadow={d:.2} color=rgba({},{},{},{})\n",
                .{
                    label,
                    rect.mode,
                    rect.bounds.x,
                    rect.bounds.y,
                    rect.bounds.w,
                    rect.bounds.h,
                    rect.radius,
                    rect.shadow,
                    rect.color.r,
                    rect.color.g,
                    rect.color.b,
                    rect.color.a,
                },
            );
        }
    }
}

fn printParityTexturedAt(label: []const u8, values: []const f32, x: f32, y: f32) void {
    var iter = renderer_ir.TexturedQuadIterator.init(values) catch return;
    while (iter.next() catch return) |quad| {
        if (quad.bounds.containsInclusive(x, y)) {
            std.debug.print(
                "  {s} bounds=({d:.2},{d:.2},{d:.2},{d:.2}) uv=({d:.4},{d:.4},{d:.4},{d:.4}) color=rgba({},{},{},{})\n",
                .{
                    label,
                    quad.bounds.x,
                    quad.bounds.y,
                    quad.bounds.w,
                    quad.bounds.h,
                    quad.u0,
                    quad.v0,
                    quad.u1,
                    quad.v1,
                    quad.color.r,
                    quad.color.g,
                    quad.color.b,
                    quad.color.a,
                },
            );
        }
    }
}

fn printParityIconsAt(label: []const u8, values: []const f32, x: f32, y: f32) void {
    var iter = renderer_ir.IconIterator.init(values) catch return;
    while (iter.next() catch return) |icon| {
        if (icon.bounds.containsInclusive(x, y)) {
            std.debug.print(
                "  {s} id={} bounds=({d:.2},{d:.2},{d:.2},{d:.2}) color=rgba({},{},{},{})\n",
                .{
                    label,
                    icon.icon_id,
                    icon.bounds.x,
                    icon.bounds.y,
                    icon.bounds.w,
                    icon.bounds.h,
                    icon.color.r,
                    icon.color.g,
                    icon.color.b,
                    icon.color.a,
                },
            );
        }
    }
}

fn initWayland(state: *WaylandState, width: i32, height: i32, scale: i32, app: *AppState) !void {
    var wayland = try wl.Wayland.open();
    errdefer wayland.deinit();
    const display = wayland.wl_display_connect(null) orelse return error.WaylandConnectFailed;
    errdefer wayland.wl_display_disconnect(display);
    const registry = wayland.wl_display_get_registry(display) orelse return error.WaylandRegistryFailed;
    state.* = .{ .wayland = wayland, .display = display, .registry = registry, .app = app, .width = width, .height = height, .scale = scale };
    if (state.wayland.wl_registry_add_listener(registry, &registry_listener, state) != 0) return error.WaylandRegistryFailed;
    if (state.wayland.wl_display_roundtrip(display) < 0) return error.WaylandRoundtripFailed;
    const compositor = state.compositor orelse return error.MissingWaylandCompositor;
    const wm_base = state.wm_base orelse return error.MissingXdgWmBase;
    if (wl.xdg_wm_base_add_listener(wm_base, &wm_base_listener, state) != 0) return error.XdgListenerFailed;
    if (state.seat) |seat| {
        if (state.wayland.wl_seat_add_listener(seat, &seat_listener, state) != 0) return error.WaylandSeatListenerFailed;
    }
    state.surface = state.wayland.wl_compositor_create_surface(compositor) orelse return error.WaylandSurfaceFailed;
    state.wayland.wl_surface_set_buffer_scale(state.surface, scale);
    state.xdg_surface = wl.xdg_wm_base_get_xdg_surface(wm_base, state.surface) orelse return error.XdgSurfaceFailed;
    if (wl.xdg_surface_add_listener(state.xdg_surface, &xdg_surface_listener, state) != 0) return error.XdgListenerFailed;
    state.toplevel = wl.xdg_surface_get_toplevel(state.xdg_surface) orelse return error.XdgToplevelFailed;
    if (wl.xdg_toplevel_add_listener(state.toplevel, &xdg_toplevel_listener, state) != 0) return error.XdgListenerFailed;
    wl.xdg_toplevel_set_title(state.toplevel, "EdgeRun EGL GPU");
    state.wayland.wl_surface_commit(state.surface);
    while (!state.configured) {
        if (state.wayland.wl_display_dispatch(display) < 0) return error.WaylandDispatchFailed;
    }
}

fn deinitWayland(state: *WaylandState) void {
    if (state.pointer) |value| state.wayland.wl_pointer_destroy(value);
    if (state.seat) |value| state.wayland.wl_seat_destroy(value);
    if (state.toplevel) |value| wl.xdg_toplevel_destroy(value);
    if (state.xdg_surface) |value| wl.xdg_surface_destroy(value);
    if (state.surface) |value| state.wayland.wl_surface_destroy(value);
    if (state.wm_base) |value| wl.xdg_wm_base_destroy(value);
    if (state.compositor) |value| state.wayland.wl_compositor_destroy(value);
    state.wayland.wl_registry_destroy(state.registry);
    state.wayland.wl_display_disconnect(state.display);
    state.wayland.deinit();
}

fn initEgl(wl_state: *WaylandState) !EglState {
    var egl_wrapper = try gpu.Egl.open();
    errdefer egl_wrapper.lib.close();
    const egl_display = egl_wrapper.eglGetDisplay(@ptrCast(wl_state.display));
    if (egl_display == null) return error.EglDisplayFailed;
    var major: gpu.EGLint = 0;
    var minor: gpu.EGLint = 0;
    if (egl_wrapper.eglInitialize(egl_display, &major, &minor) != gpu.egl_true) return error.EglInitializeFailed;
    if (egl_wrapper.eglBindAPI(gpu.egl_opengl_es_api) != gpu.egl_true) return error.EglApiFailed;
    const attrs = [_]gpu.EGLint{
        gpu.egl_surface_type,    gpu.egl_window_bit,
        gpu.egl_renderable_type, gpu.egl_opengl_es2_bit,
        gpu.egl_red_size,        8,
        gpu.egl_green_size,      8,
        gpu.egl_blue_size,       8,
        gpu.egl_alpha_size,      8,
        gpu.egl_none,
    };
    var config: gpu.EGLConfig = undefined;
    var count: gpu.EGLint = 0;
    if (egl_wrapper.eglChooseConfig(egl_display, &attrs, &config, 1, &count) != gpu.egl_true or count == 0) return error.EglConfigFailed;
    const context_attrs = [_]gpu.EGLint{ gpu.egl_context_client_version, 2, gpu.egl_none };
    const context = egl_wrapper.eglCreateContext(egl_display, config, gpu.egl_no_context, &context_attrs);
    if (context == null) return error.EglContextFailed;
    errdefer _ = egl_wrapper.eglDestroyContext(egl_display, context);
    const surface = wl_state.surface orelse return error.WaylandSurfaceFailed;
    const window = wl_state.wayland.wl_egl_window_create(surface, wl_state.framebufferWidth(), wl_state.framebufferHeight()) orelse return error.EglWindowFailed;
    errdefer wl_state.wayland.wl_egl_window_destroy(window);
    const egl_surface = egl_wrapper.eglCreateWindowSurface(egl_display, config, @ptrCast(window), null);
    if (egl_surface == null) return error.EglSurfaceFailed;
    if (egl_wrapper.eglMakeCurrent(egl_display, egl_surface, egl_surface, context) != gpu.egl_true) return error.EglMakeCurrentFailed;
    if (egl_wrapper.eglSwapInterval(egl_display, 1) != gpu.egl_true) return error.EglSwapIntervalFailed;
    return .{ .egl = egl_wrapper, .display = egl_display, .context = context, .surface = egl_surface, .window = window };
}

fn deinitEgl(egl_state: *EglState) void {
    _ = egl_state.egl.eglMakeCurrent(egl_state.display, gpu.egl_no_surface, gpu.egl_no_surface, gpu.egl_no_context);
    _ = egl_state.egl.eglDestroySurface(egl_state.display, egl_state.surface);
    _ = egl_state.egl.eglDestroyContext(egl_state.display, egl_state.context);
    egl_state.egl.lib.close();
}

fn updateHoverHit(app: *AppState, regions: []const interaction.Region) void {
    app_native_input.refreshHover(&app.input, regions);
}

fn processPointerEvent(wl_state: *WaylandState, commands: []const ui.Command, regions: []const interaction.Region) void {
    if (wl_state.pointer_event) |event| app_native_input.processPointerEvent(&wl_state.app.input, commands, regions, event);
    wl_state.pointer_event = null;
}

fn scrollBy(app: *AppState, width: i32, height: i32, delta_y: f32) void {
    app_native_input.scrollBy(&app.input, @floatFromInt(width), @floatFromInt(height), delta_y);
}

fn fixedToFloat(value: wl.wl_fixed_t) f32 {
    return @as(f32, @floatFromInt(value)) / wayland_fixed_scale;
}

const registry_listener = wl.WlRegistryListener{ .global = registryGlobal, .global_remove = registryRemove };
fn registryGlobal(data: ?*anyopaque, registry: ?*wl.WlRegistry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    const reg = registry.?;
    const iface = std.mem.span(interface);
    if (bytes.eql(iface, "wl_compositor")) {
        state.compositor = @ptrCast(state.wayland.wl_registry_bind(reg, name, state.wayland.wl_compositor_interface, @min(version, 4)));
    } else if (bytes.eql(iface, "xdg_wm_base")) {
        state.wm_base = @ptrCast(state.wayland.wl_registry_bind(reg, name, &wl.xdg_wm_base_interface, @min(version, 1)));
    } else if (bytes.eql(iface, "wl_seat")) {
        state.seat = @ptrCast(state.wayland.wl_registry_bind(reg, name, state.wayland.wl_seat_interface, @min(version, wl_seat_protocol_version)));
    }
}
fn registryRemove(_: ?*anyopaque, _: ?*wl.WlRegistry, _: u32) callconv(.c) void {}

const seat_listener = wl.WlSeatListener{ .capabilities = seatCapabilities, .name = seatName };
fn seatCapabilities(data: ?*anyopaque, seat: ?*wl.WlSeat, capabilities: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if ((capabilities & wl.wl_seat_capability_pointer) != 0 and state.pointer == null) {
        state.pointer = state.wayland.wl_seat_get_pointer(seat.?);
        if (state.pointer) |pointer| {
            _ = state.wayland.wl_pointer_add_listener(pointer, &pointer_listener, state);
        }
    } else if ((capabilities & wl.wl_seat_capability_pointer) == 0 and state.pointer != null) {
        state.wayland.wl_pointer_destroy(state.pointer.?);
        state.pointer = null;
    }
}
fn seatName(_: ?*anyopaque, _: ?*wl.WlSeat, _: [*c]const u8) callconv(.c) void {}

const pointer_listener = wl.WlPointerListener{
    .enter = pointerEnter,
    .leave = pointerLeave,
    .motion = pointerMotion,
    .button = pointerButton,
    .axis = pointerAxis,
};
fn pointerEnter(data: ?*anyopaque, pointer: ?*wl.WlPointer, serial: u32, _: ?*wl.WlSurface, sx: wl.wl_fixed_t, sy: wl.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.pointer_serial = serial;
    hideHostCursor(state, pointer, serial);
    state.app.input.hover_x = fixedToFloat(sx);
    state.app.input.hover_y = fixedToFloat(sy);
    state.pointer_event = .pointer_move;
    state.input_dirty = true;
}
fn pointerLeave(data: ?*anyopaque, _: ?*wl.WlPointer, _: u32, _: ?*wl.WlSurface) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    app_native_input.clearHover(&state.app.input);
    state.pointer_event = .pointer_leave;
    state.input_dirty = true;
}
fn pointerMotion(data: ?*anyopaque, _: ?*wl.WlPointer, _: u32, sx: wl.wl_fixed_t, sy: wl.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.app.input.hover_x = fixedToFloat(sx);
    state.app.input.hover_y = fixedToFloat(sy);
    state.pointer_event = .pointer_move;
    state.input_dirty = true;
}
fn pointerButton(data: ?*anyopaque, pointer: ?*wl.WlPointer, serial: u32, _: u32, button: u32, button_state: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.pointer_serial = serial;
    hideHostCursor(state, pointer, serial);
    if (button == pointer_button_left and button_state == wl.wl_pointer_button_state_pressed) {
        state.pointer_event = .pointer_down;
    } else if (button == pointer_button_left and button_state == wl.wl_pointer_button_state_released) {
        state.pointer_event = .pointer_up;
    }
    state.input_dirty = true;
}

fn hideHostCursor(wl_state: *WaylandState, pointer: ?*wl.WlPointer, serial: u32) void {
    if (pointer) |value| wl_state.wayland.wl_pointer_set_cursor(value, serial, null, 0, 0);
}
fn pointerAxis(data: ?*anyopaque, _: ?*wl.WlPointer, _: u32, axis: u32, value: wl.wl_fixed_t) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if (axis == wl.wl_pointer_axis_vertical_scroll) scrollBy(state.app, state.width, state.height, fixedToFloat(value));
    state.input_dirty = true;
}

const wm_base_listener = wl.XdgWmBaseListener{ .ping = wmBasePing };
fn wmBasePing(_: ?*anyopaque, wm_base: ?*wl.XdgWmBase, serial: u32) callconv(.c) void {
    wl.xdg_wm_base_pong(wm_base, serial);
}

const xdg_surface_listener = wl.XdgSurfaceListener{ .configure = xdgSurfaceConfigure };
fn xdgSurfaceConfigure(data: ?*anyopaque, surface: ?*wl.XdgSurface, serial: u32) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    wl.xdg_surface_ack_configure(surface, serial);
    state.configured = true;
}

const xdg_toplevel_listener = wl.XdgToplevelListener{ .configure = xdgToplevelConfigure, .close = xdgToplevelClose };
fn xdgToplevelConfigure(data: ?*anyopaque, _: ?*wl.XdgToplevel, width: i32, height: i32, _: ?*wl.WlArray) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    if (width > 0 and height > 0) {
        if (state.width != width or state.height != height) {
            state.width = width;
            state.height = height;
            state.resized = true;
        }
    }
}
fn xdgToplevelClose(data: ?*anyopaque, _: ?*wl.XdgToplevel) callconv(.c) void {
    const state: *WaylandState = @ptrCast(@alignCast(data.?));
    state.closed = true;
}

test "egl host input helpers update hover activation and scroll state" {
    var app = AppState{ .input = .{ .public_identity_ready = false, .public_identity = "pending", .reveal_identity = "native-egl-gpu" } };
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.add(.{ .kind = .button, .id = app_navigation.reveal_identity_button_id, .bounds = ui.Rect.init(8, 8, 80, 32) });
    updateHoverHit(&app, collector.written());
    try std.testing.expectEqual(@as(u32, 0), app.input.runtime.hoverHitId());

    app.input.hover_x = 16.0;
    app.input.hover_y = 16.0;
    updateHoverHit(&app, collector.written());
    try std.testing.expectEqual(app_navigation.reveal_identity_button_id, app.input.runtime.hoverHitId());

    app_native_input.activateHovered(&app.input);
    try std.testing.expect(app.input.public_identity_ready);
    try std.testing.expectEqualStrings("native-egl-gpu", app.input.public_identity);

    scrollBy(&app, default_width, 200, 120.0);
    try std.testing.expect(app.input.scroll_y > 0.0);
    const before = app.input.scroll_y;
    scrollBy(&app, default_width, 200, @as(f32, @bitCast(@as(u32, 0x7fc00000))));
    try std.testing.expectEqual(before, app.input.scroll_y);
}

test "egl host parses explicit parity verification mode" {
    const args = [_][:0]const u8{
        "wayland-egl-window",
        "--width",
        "320",
        "--height",
        "240",
        "--scale",
        "1",
        "--seconds",
        "1",
        "--verify-parity",
    };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(@as(i32, 320), options.width);
    try std.testing.expectEqual(@as(i32, 240), options.height);
    try std.testing.expectEqual(@as(i32, 1), options.scale);
    try std.testing.expectEqual(@as(u32, 1), options.seconds);
    try std.testing.expect(options.verify_parity);
}

test "egl host activation uses shared app navigation routes" {
    var app = AppState{};

    app.input.runtime.hovered = .{ .kind = .button, .id = app_navigation.topLevelButtonId(.blog), .bounds = ui.Rect.init(0, 0, 1, 1) };
    app_native_input.activateHovered(&app.input);
    try std.testing.expectEqual(app_navigation.View.blog, app.input.route.view);
    try std.testing.expectEqual(@as(f32, 0.0), app.input.scroll_y);

    const post_id = app_blog.postIdAt(0);
    app.input.scroll_y = 120.0;
    app.input.runtime.hovered = .{ .kind = .button, .id = post_id, .bounds = ui.Rect.init(0, 0, 1, 1) };
    app_native_input.activateHovered(&app.input);
    try std.testing.expectEqual(app_navigation.View.blog, app.input.route.view);
    try std.testing.expectEqual(post_id, app.input.route.selected_blog_post_id);
    try std.testing.expectEqual(@as(f32, 0.0), app.input.scroll_y);

    app.input.runtime.hovered = .{ .kind = .button, .id = app_navigation.topLevelButtonId(.docs), .bounds = ui.Rect.init(0, 0, 1, 1) };
    app_native_input.activateHovered(&app.input);
    try std.testing.expectEqual(app_navigation.View.docs, app.input.route.view);

    app.input.runtime.hovered = .{ .kind = .button, .id = app_navigation.topLevelButtonId(.docs), .bounds = ui.Rect.init(0, 0, 1, 1) };
    app_native_input.activateHovered(&app.input);
    try std.testing.expectEqual(app_navigation.View.docs, app.input.route.view);

    app.input.runtime.hovered = .{ .kind = .button, .id = app_navigation.topLevelButtonId(.logo), .bounds = ui.Rect.init(0, 0, 1, 1) };
    app_native_input.activateHovered(&app.input);
    try std.testing.expectEqual(app_navigation.View.source, app.input.route.view);
}

const std = @import("std");
const app_dashboard = @import("app_dashboard.zig");
const app_hardware_dashboard = @import("app_hardware_dashboard.zig");
const app_import = @import("wayland/app.zig");
const app_input_event = @import("app_input_event.zig");
const app_native_input = @import("input/native.zig");
const egl_mod = @import("linux_gpu.zig");
const interaction = @import("ui/interaction.zig");
const linux_gles = @import("linux_gles.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_gles = @import("render/backends/gles.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const ui = @import("ui/core.zig");
const wl = @import("linux_wayland.zig");
const linux = std.os.linux;

const default_width: i32 = 3840;
const default_height: i32 = 2160;
const default_logical_width: i32 = 1920;
const default_logical_height: i32 = 1080;
const default_seconds: u32 = 30;
const frames_per_second: u32 = 60;
const remote_mouse_paths = [_][]const u8{
    "/dev/input/event3",
    "/dev/input/event4",
    "/dev/input/event5",
    "/dev/input/event9",
};
const remote_mouse_event_bytes: usize = 16;
const ev_key: u16 = 1;
const ev_rel: u16 = 2;
const ev_abs: u16 = 3;
const rel_x: u16 = 0;
const rel_y: u16 = 1;
const abs_x: u16 = 0;
const abs_y: u16 = 1;
const btn_left: u16 = 0x110;
const btn_touch: u16 = 0x14a;
const remote_mouse_gain: f32 = 1.8;
const max_direct_mouse_devices: usize = remote_mouse_paths.len;
const info_bytes: usize = 96;

const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_regions: usize = 1024;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_image_vertices: usize = 24576;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;

const WlMessage = extern struct {
    name: [*c]const u8,
    signature: [*c]const u8,
    types: ?*const anyopaque,
};

const webos_shell_version: i32 = 2;
const webos_shell_methods = [_]WlMessage{
    .{ .name = "get_system_pip", .signature = "no", .types = null },
    .{ .name = "get_shell_surface", .signature = "no", .types = null },
};
const webos_shell_surface_methods = [_]WlMessage{
    .{ .name = "set_location_hint", .signature = "u", .types = null },
    .{ .name = "set_state", .signature = "u", .types = null },
    .{ .name = "set_property", .signature = "ss", .types = null },
    .{ .name = "set_key_mask", .signature = "u", .types = null },
    .{ .name = "set_addon", .signature = "2s", .types = null },
    .{ .name = "reset_addon", .signature = "2", .types = null },
};
const webos_shell_surface_events = [_]WlMessage{
    .{ .name = "state_changed", .signature = "u", .types = null },
    .{ .name = "position_changed", .signature = "ii", .types = null },
    .{ .name = "close", .signature = "", .types = null },
    .{ .name = "exposed", .signature = "a", .types = null },
    .{ .name = "state_about_to_change", .signature = "u", .types = null },
    .{ .name = "addon_status_changed", .signature = "2u", .types = null },
};
const webos_shell_interface = wl.WlInterface{
    .name = "wl_webos_shell",
    .version = webos_shell_version,
    .method_count = webos_shell_methods.len,
    .methods = &webos_shell_methods,
    .event_count = 0,
    .events = null,
};
const webos_shell_surface_interface = wl.WlInterface{
    .name = "wl_webos_shell_surface",
    .version = webos_shell_version,
    .method_count = webos_shell_surface_methods.len,
    .methods = &webos_shell_surface_methods,
    .event_count = webos_shell_surface_events.len,
    .events = &webos_shell_surface_events,
};

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

const Options = struct {
    width: i32 = default_width,
    height: i32 = default_height,
    logical_width: i32 = default_logical_width,
    logical_height: i32 = default_logical_height,
    seconds: u32 = default_seconds,
};

const MiniWayland = struct {
    lib: std.DynLib,
    lib_egl: std.DynLib,
    display: *wl.WlDisplay,
    registry: *wl.WlRegistry,
    compositor: *wl.WlCompositor,
    surface: *wl.WlSurface,
    webos_surface: ?*WlWebosShellSurface,
    shell_surface: ?*WlShellSurface,
    window: *wl.WlEglWindow,
    wl_display_disconnect: wl.PFNWLDISPLAYDISCONNECT,
    wl_display_roundtrip: wl.PFNWLDISPLAYROUNDTRIP,
    wl_display_dispatch_pending: wl.PFNWLDISPLAYDISPATCHPENDING,
    wl_display_flush: wl.PFNWLDISPLAYFLUSH,
    wl_proxy_destroy: *const fn (proxy: *anyopaque) callconv(.c) void,
    wl_egl_window_destroy: wl.PFNWLEGLWINDOWDESTROY,

    const Loader = struct {
        lib: std.DynLib,
        lib_egl: std.DynLib,
        wl_display_connect: wl.PFNWLDISPLAYCONNECT,
        wl_display_disconnect: wl.PFNWLDISPLAYDISCONNECT,
        wl_display_roundtrip: wl.PFNWLDISPLAYROUNDTRIP,
        wl_display_dispatch_pending: wl.PFNWLDISPLAYDISPATCHPENDING,
        wl_display_flush: wl.PFNWLDISPLAYFLUSH,
        wl_proxy_add_listener: *const fn (proxy: *anyopaque, implementation: *const ?*const anyopaque, data: ?*anyopaque) callconv(.c) i32,
        wl_proxy_marshal_constructor: *const fn (proxy: *anyopaque, opcode: u32, interface: *const wl.WlInterface, data: ?*const anyopaque) callconv(.c) ?*anyopaque,
        wl_proxy_marshal_constructor_surface: *const fn (proxy: *anyopaque, opcode: u32, interface: *const wl.WlInterface, data: ?*const anyopaque, surface: *wl.WlSurface) callconv(.c) ?*anyopaque,
        wl_proxy_marshal_constructor_versioned: *const fn (proxy: *anyopaque, opcode: u32, interface: *const wl.WlInterface, version: u32, name: u32, interface_name: [*c]const u8, interface_version: u32, data: ?*const anyopaque) callconv(.c) ?*anyopaque,
        wl_proxy_marshal_flags: *const fn (proxy: *anyopaque, opcode: u32, interface: ?*const wl.WlInterface, version: u32, flags: u32) callconv(.c) ?*anyopaque,
        wl_proxy_marshal_flags_u32: *const fn (proxy: *anyopaque, opcode: u32, interface: ?*const wl.WlInterface, version: u32, flags: u32, value: u32) callconv(.c) ?*anyopaque,
        wl_proxy_marshal_flags_string_pair: *const fn (proxy: *anyopaque, opcode: u32, interface: ?*const wl.WlInterface, version: u32, flags: u32, name: [*:0]const u8, value: [*:0]const u8) callconv(.c) ?*anyopaque,
        wl_proxy_get_version: *const fn (proxy: *anyopaque) callconv(.c) u32,
        wl_proxy_destroy: *const fn (proxy: *anyopaque) callconv(.c) void,
        wl_egl_window_create: wl.PFNWLEGLWINDOWCREATE,
        wl_egl_window_destroy: wl.PFNWLEGLWINDOWDESTROY,
        wl_compositor_interface: *const wl.WlInterface,
        wl_registry_interface: *const wl.WlInterface,
        wl_surface_interface: *const wl.WlInterface,
        wl_shell_interface: *const wl.WlInterface,
        wl_shell_surface_interface: *const wl.WlInterface,
    };

    const Registry = struct {
        loader: *Loader,
        compositor: ?*wl.WlCompositor = null,
        compositor_version: u32 = 0,
        webos_shell: ?*WlWebosShell = null,
        webos_shell_version_seen: u32 = 0,
        shell: ?*WlShell = null,
        shell_version: u32 = 0,
    };

    const WlWebosShell = opaque {};
    const WlWebosShellSurface = opaque {};
    const WlShell = opaque {};
    const WlShellSurface = opaque {};
    const wl_webos_shell_get_shell_surface_opcode: u32 = 1;
    const wl_webos_shell_surface_set_state_opcode: u32 = 1;
    const wl_webos_shell_surface_set_property_opcode: u32 = 2;
    const wl_webos_shell_surface_state_fullscreen: u32 = 3;
    const wl_shell_get_shell_surface_opcode: u32 = 0;
    const wl_shell_surface_set_toplevel_opcode: u32 = 3;

    fn open(width: i32, height: i32) !MiniWayland {
        var loader = try openLoader();
        errdefer {
            loader.lib_egl.close();
            loader.lib.close();
        }
        const display = loader.wl_display_connect(null) orelse return error.WaylandConnectFailed;
        errdefer loader.wl_display_disconnect(display);
        const registry_raw = loader.wl_proxy_marshal_constructor(@ptrCast(display), 1, loader.wl_registry_interface, null) orelse return error.WaylandRegistryFailed;
        const registry: *wl.WlRegistry = @ptrCast(@alignCast(registry_raw));
        errdefer loader.wl_proxy_destroy(@ptrCast(registry));

        var state = Registry{ .loader = &loader };
        const listener = wl.WlRegistryListener{ .global = onGlobal, .global_remove = onGlobalRemove };
        if (loader.wl_proxy_add_listener(@ptrCast(registry), @ptrCast(&listener), &state) < 0) return error.WaylandListenerFailed;
        if (loader.wl_display_roundtrip(display) < 0) return error.WaylandRoundtripFailed;
        const compositor = state.compositor orelse return error.MissingCompositor;
        const surface_raw = loader.wl_proxy_marshal_constructor(@ptrCast(compositor), 0, loader.wl_surface_interface, null) orelse return error.SurfaceCreateFailed;
        const surface: *wl.WlSurface = @ptrCast(@alignCast(surface_raw));
        errdefer loader.wl_proxy_destroy(@ptrCast(surface));
        const webos_surface = try createWebosSurface(&loader, state.webos_shell, surface);
        errdefer if (webos_surface) |owned| loader.wl_proxy_destroy(@ptrCast(owned));
        const shell_surface = if (webos_surface == null) try createShellSurface(&loader, state.shell, surface) else null;
        errdefer if (shell_surface) |owned| loader.wl_proxy_destroy(@ptrCast(owned));
        const window = loader.wl_egl_window_create(surface, width, height) orelse return error.EglWindowFailed;
        errdefer loader.wl_egl_window_destroy(window);
        return .{
            .lib = loader.lib,
            .lib_egl = loader.lib_egl,
            .display = display,
            .registry = registry,
            .compositor = compositor,
            .surface = surface,
            .webos_surface = webos_surface,
            .shell_surface = shell_surface,
            .window = window,
            .wl_display_disconnect = loader.wl_display_disconnect,
            .wl_display_roundtrip = loader.wl_display_roundtrip,
            .wl_display_dispatch_pending = loader.wl_display_dispatch_pending,
            .wl_display_flush = loader.wl_display_flush,
            .wl_proxy_destroy = loader.wl_proxy_destroy,
            .wl_egl_window_destroy = loader.wl_egl_window_destroy,
        };
    }

    fn deinit(self: *MiniWayland) void {
        self.wl_egl_window_destroy(self.window);
        if (self.shell_surface) |shell_surface| self.wl_proxy_destroy(@ptrCast(shell_surface));
        if (self.webos_surface) |webos_surface| self.wl_proxy_destroy(@ptrCast(webos_surface));
        self.wl_proxy_destroy(@ptrCast(self.surface));
        self.wl_proxy_destroy(@ptrCast(self.registry));
        self.wl_display_disconnect(self.display);
        self.lib_egl.close();
        self.lib.close();
    }

    fn openLoader() !Loader {
        var lib = try std.DynLib.openZ("libwayland-client.so.0");
        errdefer lib.close();
        var lib_egl = try std.DynLib.openZ("libwayland-egl.so.1");
        errdefer lib_egl.close();
        return .{
            .lib = lib,
            .lib_egl = lib_egl,
            .wl_display_connect = lib.lookup(wl.PFNWLDISPLAYCONNECT, "wl_display_connect") orelse return error.MissingWaylandSymbol,
            .wl_display_disconnect = lib.lookup(wl.PFNWLDISPLAYDISCONNECT, "wl_display_disconnect") orelse return error.MissingWaylandSymbol,
            .wl_display_roundtrip = lib.lookup(wl.PFNWLDISPLAYROUNDTRIP, "wl_display_roundtrip") orelse return error.MissingWaylandSymbol,
            .wl_display_dispatch_pending = lib.lookup(wl.PFNWLDISPLAYDISPATCHPENDING, "wl_display_dispatch_pending") orelse return error.MissingWaylandSymbol,
            .wl_display_flush = lib.lookup(wl.PFNWLDISPLAYFLUSH, "wl_display_flush") orelse return error.MissingWaylandSymbol,
            .wl_proxy_add_listener = lib.lookup(*const fn (*anyopaque, *const ?*const anyopaque, ?*anyopaque) callconv(.c) i32, "wl_proxy_add_listener") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_constructor = lib.lookup(*const fn (*anyopaque, u32, *const wl.WlInterface, ?*const anyopaque) callconv(.c) ?*anyopaque, "wl_proxy_marshal_constructor") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_constructor_surface = lib.lookup(*const fn (*anyopaque, u32, *const wl.WlInterface, ?*const anyopaque, *wl.WlSurface) callconv(.c) ?*anyopaque, "wl_proxy_marshal_constructor") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_constructor_versioned = lib.lookup(*const fn (*anyopaque, u32, *const wl.WlInterface, u32, u32, [*c]const u8, u32, ?*const anyopaque) callconv(.c) ?*anyopaque, "wl_proxy_marshal_constructor_versioned") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_flags = lib.lookup(*const fn (*anyopaque, u32, ?*const wl.WlInterface, u32, u32) callconv(.c) ?*anyopaque, "wl_proxy_marshal_flags") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_flags_u32 = lib.lookup(*const fn (*anyopaque, u32, ?*const wl.WlInterface, u32, u32, u32) callconv(.c) ?*anyopaque, "wl_proxy_marshal_flags") orelse return error.MissingWaylandSymbol,
            .wl_proxy_marshal_flags_string_pair = lib.lookup(*const fn (*anyopaque, u32, ?*const wl.WlInterface, u32, u32, [*:0]const u8, [*:0]const u8) callconv(.c) ?*anyopaque, "wl_proxy_marshal_flags") orelse return error.MissingWaylandSymbol,
            .wl_proxy_get_version = lib.lookup(*const fn (*anyopaque) callconv(.c) u32, "wl_proxy_get_version") orelse return error.MissingWaylandSymbol,
            .wl_proxy_destroy = lib.lookup(*const fn (*anyopaque) callconv(.c) void, "wl_proxy_destroy") orelse return error.MissingWaylandSymbol,
            .wl_egl_window_create = lib_egl.lookup(wl.PFNWLEGLWINDOWCREATE, "wl_egl_window_create") orelse return error.MissingWaylandSymbol,
            .wl_egl_window_destroy = lib_egl.lookup(wl.PFNWLEGLWINDOWDESTROY, "wl_egl_window_destroy") orelse return error.MissingWaylandSymbol,
            .wl_compositor_interface = lib.lookup(*const wl.WlInterface, "wl_compositor_interface") orelse return error.MissingWaylandSymbol,
            .wl_registry_interface = lib.lookup(*const wl.WlInterface, "wl_registry_interface") orelse return error.MissingWaylandSymbol,
            .wl_surface_interface = lib.lookup(*const wl.WlInterface, "wl_surface_interface") orelse return error.MissingWaylandSymbol,
            .wl_shell_interface = lib.lookup(*const wl.WlInterface, "wl_shell_interface") orelse return error.MissingWaylandSymbol,
            .wl_shell_surface_interface = lib.lookup(*const wl.WlInterface, "wl_shell_surface_interface") orelse return error.MissingWaylandSymbol,
        };
    }

    fn onGlobal(data: ?*anyopaque, registry: ?*wl.WlRegistry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
        const state: *Registry = @ptrCast(@alignCast(data.?));
        const interface_name = std.mem.sliceTo(interface, 0);
        if (std.mem.eql(u8, interface_name, "wl_compositor")) {
            state.compositor_version = @min(version, 3);
            const bound = state.loader.wl_proxy_marshal_constructor_versioned(
                @ptrCast(registry.?),
                0,
                state.loader.wl_compositor_interface,
                state.compositor_version,
                name,
                state.loader.wl_compositor_interface.name,
                state.compositor_version,
                null,
            ) orelse return;
            state.compositor = @ptrCast(@alignCast(bound));
            return;
        }
        if (std.mem.eql(u8, interface_name, "wl_webos_shell")) {
            state.webos_shell_version_seen = @min(version, webos_shell_version);
            const bound = state.loader.wl_proxy_marshal_constructor_versioned(
                @ptrCast(registry.?),
                0,
                &webos_shell_interface,
                state.webos_shell_version_seen,
                name,
                webos_shell_interface.name,
                state.webos_shell_version_seen,
                null,
            ) orelse return;
            state.webos_shell = @ptrCast(@alignCast(bound));
            return;
        }
        if (!std.mem.eql(u8, interface_name, "wl_shell")) return;
        state.shell_version = @min(version, 1);
        const bound = state.loader.wl_proxy_marshal_constructor_versioned(
            @ptrCast(registry.?),
            0,
            state.loader.wl_shell_interface,
            state.shell_version,
            name,
            state.loader.wl_shell_interface.name,
            state.shell_version,
            null,
        ) orelse return;
        state.shell = @ptrCast(@alignCast(bound));
    }

    fn onGlobalRemove(data: ?*anyopaque, registry: ?*wl.WlRegistry, name: u32) callconv(.c) void {
        _ = data;
        _ = registry;
        _ = name;
    }

    fn createWebosSurface(loader: *Loader, shell: ?*WlWebosShell, surface: *wl.WlSurface) !?*WlWebosShellSurface {
        const shell_proxy = shell orelse return null;
        const shell_surface_raw = loader.wl_proxy_marshal_constructor_surface(
            @ptrCast(shell_proxy),
            wl_webos_shell_get_shell_surface_opcode,
            &webos_shell_surface_interface,
            null,
            surface,
        ) orelse return error.WebosSurfaceCreateFailed;
        const shell_surface: *WlWebosShellSurface = @ptrCast(@alignCast(shell_surface_raw));
        const version = loader.wl_proxy_get_version(@ptrCast(shell_surface));
        _ = loader.wl_proxy_marshal_flags_string_pair(
            @ptrCast(shell_surface),
            wl_webos_shell_surface_set_property_opcode,
            null,
            version,
            0,
            "appId",
            "com.edgerun.hardware",
        );
        _ = loader.wl_proxy_marshal_flags_string_pair(
            @ptrCast(shell_surface),
            wl_webos_shell_surface_set_property_opcode,
            null,
            version,
            0,
            "displayAffinity",
            "0",
        );
        _ = loader.wl_proxy_marshal_flags_u32(
            @ptrCast(shell_surface),
            wl_webos_shell_surface_set_state_opcode,
            null,
            version,
            0,
            wl_webos_shell_surface_state_fullscreen,
        );
        return shell_surface;
    }

    fn createShellSurface(loader: *Loader, shell: ?*WlShell, surface: *wl.WlSurface) !?*WlShellSurface {
        const shell_proxy = shell orelse return null;
        const shell_surface_raw = loader.wl_proxy_marshal_constructor_surface(
            @ptrCast(shell_proxy),
            wl_shell_get_shell_surface_opcode,
            loader.wl_shell_surface_interface,
            null,
            surface,
        ) orelse return error.ShellSurfaceCreateFailed;
        const shell_surface: *WlShellSurface = @ptrCast(@alignCast(shell_surface_raw));
        const version = loader.wl_proxy_get_version(@ptrCast(shell_surface));
        _ = loader.wl_proxy_marshal_flags(
            @ptrCast(shell_surface),
            wl_shell_surface_set_toplevel_opcode,
            null,
            version,
            0,
        );
        return shell_surface;
    }
};

const EglState = struct {
    egl: egl_mod.Egl,
    display: egl_mod.EGLDisplay,
    context: egl_mod.EGLContext,
    surface: egl_mod.EGLSurface,

    fn init(native_display: *wl.WlDisplay, window: *wl.WlEglWindow) !EglState {
        var egl = try egl_mod.Egl.open();
        errdefer egl.lib.close();
        const display = egl.eglGetDisplay(@ptrCast(native_display));
        if (display == null) return error.EglDisplayFailed;
        var major: egl_mod.EGLint = 0;
        var minor: egl_mod.EGLint = 0;
        if (egl.eglInitialize(display, &major, &minor) != egl_mod.egl_true) return error.EglInitializeFailed;
        if (egl.eglBindAPI(egl_mod.egl_opengl_es_api) != egl_mod.egl_true) return error.EglApiFailed;
        const attrs = [_]egl_mod.EGLint{
            egl_mod.egl_surface_type, egl_mod.egl_window_bit,
            egl_mod.egl_renderable_type, egl_mod.egl_opengl_es2_bit,
            egl_mod.egl_red_size, 8,
            egl_mod.egl_green_size, 8,
            egl_mod.egl_blue_size, 8,
            egl_mod.egl_alpha_size, 8,
            egl_mod.egl_none,
        };
        var config: egl_mod.EGLConfig = undefined;
        var count: egl_mod.EGLint = 0;
        if (egl.eglChooseConfig(display, &attrs, &config, 1, &count) != egl_mod.egl_true or count == 0) return error.EglConfigFailed;
        const context_attrs = [_]egl_mod.EGLint{ egl_mod.egl_context_client_version, 2, egl_mod.egl_none };
        const context = egl.eglCreateContext(display, config, egl_mod.egl_no_context, &context_attrs);
        if (context == null) return error.EglContextFailed;
        errdefer _ = egl.eglDestroyContext(display, context);
        const surface = egl.eglCreateWindowSurface(display, config, @ptrCast(window), null);
        if (surface == null) return error.EglSurfaceFailed;
        errdefer _ = egl.eglDestroySurface(display, surface);
        if (egl.eglMakeCurrent(display, surface, surface, context) != egl_mod.egl_true) return error.EglMakeCurrentFailed;
        _ = egl.eglSwapInterval(display, 1);
        return .{ .egl = egl, .display = display, .context = context, .surface = surface };
    }

    fn deinit(self: *EglState) void {
        _ = self.egl.eglDestroySurface(self.display, self.surface);
        _ = self.egl.eglDestroyContext(self.display, self.context);
        _ = self.egl.eglTerminate(self.display);
        self.egl.lib.close();
    }
};

const SceneState = struct {
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_regions]interaction.Region = undefined,
    command_len: usize = 0,
    region_len: usize = 0,
    ir_storage: IrStorage = .{},
    dashboard: app_dashboard.State = .{},
    hardware: app_hardware_dashboard.State = .{},
    app_state: app_native_input.State = .{},
    tv_info: TvInfo = .{},

    fn render(self: *SceneState, width: i32, height: i32, frame: u32, font_atlas: *renderer_font_atlas.Atlas) !renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try renderTvHardwareScene(&scene, &collector, @intCast(width), @intCast(height), &self.tv_info);
        try renderHeartbeat(&scene, width, height, frame);
        try renderCursor(&scene, self.app_state.hover_x, self.app_state.hover_y);
        const written_commands = scene.written();
        self.command_len = written_commands.len;
        self.region_len = collector.written().len;
        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, font_atlas, written_commands);
        return buffers;
    }

    fn commandSlice(self: *const SceneState) []const ui.Command {
        return self.commands[0..self.command_len];
    }

    fn regionSlice(self: *const SceneState) []const interaction.Region {
        return self.regions[0..self.region_len];
    }
};

const DirectMouse = struct {
    fds: [max_direct_mouse_devices]i32 = [_]i32{-1} ** max_direct_mouse_devices,
    left_down: bool = false,
    event_log_count: u32 = 0,

    fn open() DirectMouse {
        var out = DirectMouse{};
        for (remote_mouse_paths, 0..) |remote_path, index| {
            var path: [64]u8 = [_]u8{0} ** 64;
            if (remote_path.len >= path.len) continue;
            @memcpy(path[0..remote_path.len], remote_path);
            const rc = linux.openat(linux.AT.FDCWD, @ptrCast(&path), linux.O{ .NONBLOCK = true, .CLOEXEC = true }, 0);
            if (@as(isize, @bitCast(rc)) < 0) continue;
            out.fds[index] = @intCast(rc);
            std.debug.print("webos direct input opened {s}\n", .{remote_path});
        }
        return out;
    }

    fn deinit(self: *DirectMouse) void {
        for (&self.fds) |*fd| {
            if (fd.* >= 0) _ = linux.close(fd.*);
            fd.* = -1;
        }
    }

    fn poll(self: *DirectMouse, scene_state: *SceneState, logical_width: i32, logical_height: i32) void {
        for (&self.fds) |*fd| self.pollFd(fd, scene_state, logical_width, logical_height);
    }

    fn pollFd(self: *DirectMouse, fd: *i32, scene_state: *SceneState, logical_width: i32, logical_height: i32) void {
        if (fd.* < 0) return;
        var events: u32 = 0;
        while (events < 128) : (events += 1) {
            var bytes: [remote_mouse_event_bytes]u8 = undefined;
            const n = linux.read(fd.*, &bytes, bytes.len);
            if (linux.errno(n) != .SUCCESS) {
                if (linux.errno(n) == .AGAIN) return;
                _ = linux.close(fd.*);
                fd.* = -1;
                return;
            }
            if (n != remote_mouse_event_bytes) return;
            self.applyEvent(scene_state, logical_width, logical_height, bytes);
        }
    }

    fn applyEvent(self: *DirectMouse, scene_state: *SceneState, logical_width: i32, logical_height: i32, bytes: [remote_mouse_event_bytes]u8) void {
        const kind = std.mem.readInt(u16, bytes[8..10], .little);
        const code = std.mem.readInt(u16, bytes[10..12], .little);
        const value = std.mem.readInt(i32, bytes[12..16], .little);
        if (self.event_log_count < 24) {
            std.debug.print("webos direct input event kind={d} code={d} value={d}\n", .{ kind, code, value });
            self.event_log_count += 1;
        }
        if (kind == ev_rel or kind == ev_abs) {
            if (scene_state.app_state.hover_x < 0.0 or scene_state.app_state.hover_y < 0.0) {
                scene_state.app_state.hover_x = @as(f32, @floatFromInt(@max(logical_width, 1))) * 0.5;
                scene_state.app_state.hover_y = @as(f32, @floatFromInt(@max(logical_height, 1))) * 0.5;
            }
            if (code == rel_x or code == abs_x) {
                const next = if (kind == ev_abs) absoluteInput(value, logical_width) else scene_state.app_state.hover_x + @as(f32, @floatFromInt(value)) * remote_mouse_gain;
                scene_state.app_state.hover_x = clampInput(next, logical_width);
                updateHover(scene_state, .pointer_move);
            } else if (code == rel_y or code == abs_y) {
                const next = if (kind == ev_abs) absoluteInput(value, logical_height) else scene_state.app_state.hover_y + @as(f32, @floatFromInt(value)) * remote_mouse_gain;
                scene_state.app_state.hover_y = clampInput(next, logical_height);
                updateHover(scene_state, .pointer_move);
            }
        } else if (kind == ev_key and (code == btn_left or code == btn_touch)) {
            if (value != 0 and !self.left_down) {
                self.left_down = true;
                updateHover(scene_state, .pointer_down);
            } else if (value == 0 and self.left_down) {
                self.left_down = false;
                updateHover(scene_state, .pointer_up);
            }
        }
    }
};

const TvInfo = struct {
    platform: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    processor: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    memory: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    kernel: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    graphics: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    input: [info_bytes]u8 = [_]u8{0} ** info_bytes,
    refreshed: bool = false,

    fn refresh(self: *TvInfo) void {
        writeInfo(&self.platform, "LG webOS TV");
        readProcessor(&self.processor) catch writeInfo(&self.processor, "ARM platform");
        readMemory(&self.memory) catch writeInfo(&self.memory, "Memory unavailable");
        readKernel(&self.kernel) catch writeInfo(&self.kernel, "Linux kernel");
        writeInfo(&self.graphics, "Mali-G52 via libmali EGL/GLES");
        writeInfo(&self.input, "Magic Remote input: LGE M-RCU + ClickableMouse");
        self.refreshed = true;
    }

    fn slice(field: *const [info_bytes]u8) []const u8 {
        var len: usize = 0;
        while (len < field.len and field[len] != 0) : (len += 1) {}
        return field[0..len];
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);
    var wayland = try MiniWayland.open(options.width, options.height);
    defer wayland.deinit();
    var egl = try EglState.init(wayland.display, wayland.window);
    defer egl.deinit();

    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var gles = try linux_gles.Gles2.open();
    defer gles.lib.close();
    var gl = try renderer_gles.initState(&font_atlas, null, &gles);
    defer renderer_gles.deinit(&gl);
    var scene_state = SceneState{};
    scene_state.app_state = .{ .public_identity = "webos-mali", .reveal_identity = "webos-mali" };
    scene_state.hardware.refresh();
    scene_state.tv_info.refresh();
    var direct_mouse = DirectMouse.open();
    defer direct_mouse.deinit();

    const frames = options.seconds * frames_per_second;
    var frame: u32 = 0;
    while (frame < frames) : (frame += 1) {
        direct_mouse.poll(&scene_state, options.logical_width, options.logical_height);
        _ = scene_state.hardware.tick();
        if (frame % frames_per_second == 0) scene_state.tv_info.refresh();
        const buffers = try scene_state.render(options.logical_width, options.logical_height, frame, &font_atlas);
        renderer_gles.refreshFontTexture(gl, &font_atlas);
        try renderer_gles.renderFrameToViewport(gl, options.logical_width, options.logical_height, options.width, options.height, buffers);
        if (frame == 0 or frame % frames_per_second == 0) {
            const proof = try renderer_gles.verifyFrameNonBlank(&gles, options.width, options.height);
            if (!proof.valid()) return error.BlankGpuFrame;
            std.debug.print("webos mali frame {d} {d}x{d} hash {x}\n", .{ frame, proof.width, proof.height, proof.sample_hash });
        }
        gles.glFinish();
        if (egl.egl.eglSwapBuffers(egl.display, egl.surface) != egl_mod.egl_true) return error.EglSwapFailed;
        _ = wayland.wl_display_dispatch_pending(wayland.display);
        _ = wayland.wl_display_flush(wayland.display);
        sleepFrame();
    }
}

fn updateHover(scene_state: *SceneState, event: app_input_event.Kind) void {
    const hit = interaction.hitTest(scene_state.regionSlice(), scene_state.app_state.hover_x, scene_state.app_state.hover_y);
    app_native_input.processPointerEvent(&scene_state.app_state, scene_state.commandSlice(), scene_state.regionSlice(), hit, event);
}

fn clampInput(value: f32, limit: i32) f32 {
    const max_value = @as(f32, @floatFromInt(@max(limit, 1))) - 1.0;
    return @min(@max(value, 0.0), max_value);
}

fn absoluteInput(value: i32, limit: i32) f32 {
    const unit = @as(f32, @floatFromInt(@max(value, 0))) / 65535.0;
    return unit * (@as(f32, @floatFromInt(@max(limit, 1))) - 1.0);
}

fn renderCursor(scene: *ui.Scene, x: f32, y: f32) !void {
    if (x < 0.0 or y < 0.0) return;
    try scene.pushOverlayRect(ui.Rect.init(x - 10.0, y - 10.0, 20.0, 20.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 235 }, .fill, 10.0, 0.0);
    try scene.pushOverlayRect(ui.Rect.init(x - 5.0, y - 5.0, 10.0, 10.0), ui.Color{ .r = 20, .g = 184, .b = 166, .a = 255 }, .fill, 5.0, 0.0);
}

fn renderTvHardwareScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, info: *TvInfo) !void {
    if (!info.refreshed) info.refresh();
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try scene.pushGradientRect(ui.Rect.init(0.0, 0.0, w, h), ui.Color{ .r = 8, .g = 10, .b = 14 }, ui.Color{ .r = 16, .g = 18, .b = 24 }, 0.0);
    const margin: f32 = 54.0;
    try scene.pushBoldText(ui.Rect.init(margin, 48.0, w - margin * 2.0, 56.0), "LG webOS TV Hardware", ui.Color{ .r = 250, .g = 250, .b = 250 });
    try scene.pushText(ui.Rect.init(margin, 112.0, w - margin * 2.0, 28.0), "Direct EGL/GLES on Mali, rendered from EdgeRun IR", ui.Color{ .r = 168, .g = 178, .b = 190 });

    const top_y: f32 = 174.0;
    const gap: f32 = 24.0;
    const card_w = (w - margin * 2.0 - gap * 2.0) / 3.0;
    const card_h: f32 = 180.0;
    try renderTvCard(scene, collector, ui.Rect.init(margin, top_y, card_w, card_h), 1, "Platform", TvInfo.slice(&info.platform), ui.Color{ .r = 23, .g = 166, .b = 135 });
    try renderTvCard(scene, collector, ui.Rect.init(margin + card_w + gap, top_y, card_w, card_h), 2, "CPU", TvInfo.slice(&info.processor), ui.Color{ .r = 82, .g = 154, .b = 255 });
    try renderTvCard(scene, collector, ui.Rect.init(margin + (card_w + gap) * 2.0, top_y, card_w, card_h), 3, "Graphics", TvInfo.slice(&info.graphics), ui.Color{ .r = 245, .g = 183, .b = 78 });

    const lower_y = top_y + card_h + gap;
    const lower_card_h: f32 = 168.0;
    const lower_card_w = (w - margin * 2.0 - gap * 2.0) / 3.0;
    try renderTvCard(scene, collector, ui.Rect.init(margin, lower_y, lower_card_w, lower_card_h), 4, "Memory", TvInfo.slice(&info.memory), ui.Color{ .r = 132, .g = 204, .b = 22 });
    try renderTvCard(scene, collector, ui.Rect.init(margin + lower_card_w + gap, lower_y, lower_card_w, lower_card_h), 5, "Kernel", TvInfo.slice(&info.kernel), ui.Color{ .r = 168, .g = 85, .b = 247 });
    try renderTvCard(scene, collector, ui.Rect.init(margin + (lower_card_w + gap) * 2.0, lower_y, lower_card_w, lower_card_h), 6, "Remote", TvInfo.slice(&info.input), ui.Color{ .r = 20, .g = 184, .b = 166 });
}

fn renderTvCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, title: []const u8, detail: []const u8, accent: ui.Color) !void {
    try collector.addHit(bounds, .button, id);
    try scene.pushRect(bounds, ui.Color{ .r = 28, .g = 31, .b = 38, .a = 232 }, .fill, 18.0, 0.0);
    try scene.pushRect(bounds, ui.Color{ .r = 255, .g = 255, .b = 255, .a = 32 }, .border, 18.0, 0.0);
    try scene.pushRect(ui.Rect.init(bounds.x + 22.0, bounds.y + 24.0, 58.0, 6.0), accent, .fill, 3.0, 0.0);
    try scene.pushStrongText(ui.Rect.init(bounds.x + 22.0, bounds.y + 52.0, bounds.w - 44.0, 30.0), title, ui.Color{ .r = 245, .g = 247, .b = 250 });
    try scene.pushText(ui.Rect.init(bounds.x + 22.0, bounds.y + 98.0, bounds.w - 44.0, 58.0), detail, ui.Color{ .r = 178, .g = 188, .b = 202 });
}

fn writeInfo(out: *[info_bytes]u8, value: []const u8) void {
    @memset(out, 0);
    const len = @min(value.len, out.len - 1);
    @memcpy(out[0..len], value[0..len]);
}

fn readProcessor(out: *[info_bytes]u8) !void {
    var buf: [2048]u8 = undefined;
    const n = try readFile("/proc/cpuinfo", &buf);
    const text = buf[0..n];
    var cores: u32 = 0;
    var part: []const u8 = "ARM";
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "processor")) cores += 1;
        if (std.mem.startsWith(u8, line, "CPU part")) part = std.mem.trim(u8, line[(std.mem.indexOfScalar(u8, line, ':') orelse 0) + 1 ..], " \t\r");
    }
    writeFixed(out, "{d} cores, CPU part {s}", .{ cores, part });
}

fn readMemory(out: *[info_bytes]u8) !void {
    var buf: [2048]u8 = undefined;
    const n = try readFile("/proc/meminfo", &buf);
    const text = buf[0..n];
    const total = parseMeminfoKb(text, "MemTotal:") orelse return error.ReadFailed;
    const avail = parseMeminfoKb(text, "MemAvailable:") orelse return error.ReadFailed;
    writeFixed(out, "{d} MB RAM, {d} MB available", .{ total / 1024, avail / 1024 });
}

fn readKernel(out: *[info_bytes]u8) !void {
    var buf: [256]u8 = undefined;
    const n = try readFile("/proc/sys/kernel/osrelease", &buf);
    const text = std.mem.trim(u8, buf[0..n], " \n\r\t");
    writeFixed(out, "Linux {s} aarch64", .{text});
}

fn parseMeminfoKb(text: []const u8, key: []const u8) ?u32 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, key)) continue;
        var parts = std.mem.tokenizeAny(u8, line[key.len..], " \t");
        return std.fmt.parseUnsigned(u32, parts.next() orelse return null, 10) catch null;
    }
    return null;
}

fn readFile(path: []const u8, out: []u8) !usize {
    var path_buf: [256]u8 = [_]u8{0} ** 256;
    if (path.len >= path_buf.len) return error.ReadFailed;
    @memcpy(path_buf[0..path.len], path);
    const rc = linux.openat(linux.AT.FDCWD, @ptrCast(&path_buf), linux.O{}, 0);
    if (@as(isize, @bitCast(rc)) < 0) return error.ReadFailed;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    const n = linux.read(fd, out.ptr, out.len);
    if (linux.errno(n) != .SUCCESS) return error.ReadFailed;
    return @intCast(n);
}

fn writeFixed(out: *[info_bytes]u8, comptime fmt: []const u8, args: anytype) void {
    @memset(out, 0);
    const text = std.fmt.bufPrint(out, fmt, args) catch return;
    if (text.len < out.len) out[text.len] = 0;
}

fn renderHeartbeat(scene: *ui.Scene, width: i32, height: i32, frame: u32) !void {
    const w = @as(f32, @floatFromInt(@max(width, 1)));
    const h = @as(f32, @floatFromInt(@max(height, 1)));
    const cycle_frames = frames_per_second * 2;
    const unit = @as(f32, @floatFromInt(frame % cycle_frames)) / @as(f32, @floatFromInt(cycle_frames));
    const track_w = 128.0;
    const x = w - 176.0 + (track_w - 22.0) * unit;
    const y = h - 42.0;
    const color = heartbeatColor(frame);
    try scene.pushOverlayRect(ui.Rect.init(w - 188.0, h - 54.0, 152.0, 30.0), ui.Color{ .r = 10, .g = 14, .b = 20, .a = 180 }, .fill, 8.0, 0.0);
    try scene.pushOverlayRect(ui.Rect.init(w - 176.0, h - 40.0, track_w, 4.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 70 }, .fill, 2.0, 0.0);
    try scene.pushOverlayRect(ui.Rect.init(x, y, 22.0, 18.0), color, .fill, 6.0, 0.0);
}

fn heartbeatColor(frame: u32) ui.Color {
    return switch ((frame / frames_per_second) & 3) {
        0 => ui.Color{ .r = 29, .g = 185, .b = 84, .a = 168 },
        1 => ui.Color{ .r = 18, .g = 145, .b = 244, .a = 168 },
        2 => ui.Color{ .r = 244, .g = 180, .b = 0, .a = 168 },
        else => ui.Color{ .r = 232, .g = 64, .b = 86, .a = 168 },
    };
}

fn sleepFrame() void {
    var request = linux.timespec{
        .sec = 0,
        .nsec = @intCast(std.time.ns_per_s / frames_per_second),
    };
    var remaining: linux.timespec = undefined;
    while (linux.nanosleep(&request, &remaining) != 0) {
        request = remaining;
    }
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
        } else if (std.mem.eql(u8, args[index], "--logical-width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.logical_width = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--logical-height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.logical_height = try std.fmt.parseInt(i32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width <= 0 or options.height <= 0 or options.logical_width <= 0 or options.logical_height <= 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

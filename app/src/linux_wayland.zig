const std = @import("er_std");

// ─── Opaque types ──────────────────────────────────────────

pub const WlDisplay = opaque {};
pub const WlRegistry = opaque {};
pub const WlCompositor = opaque {};
pub const WlSurface = opaque {};
pub const WlSeat = opaque {};
pub const WlPointer = opaque {};
pub const WlArray = opaque {};
pub const WlEglWindow = opaque {};

// ─── XDG shell opaque types ────────────────────────────────

pub const XdgWmBase = opaque {};
pub const XdgSurface = opaque {};
pub const XdgToplevel = opaque {};

// ─── Interface descriptor ──────────────────────────────────

pub const WlInterface = extern struct {
    name: [*c]const u8,
    version: i32,
    method_count: i32,
    methods: ?*const anyopaque,
    event_count: i32,
    events: ?*const anyopaque,
};

pub const wl_fixed_t = i32;

// ─── Listener structs (all fn ptrs optional for C ABI) ────

pub const WlRegistryListener = extern struct {
    global: ?*const fn (data: ?*anyopaque, registry: ?*WlRegistry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void,
    global_remove: ?*const fn (data: ?*anyopaque, registry: ?*WlRegistry, name: u32) callconv(.c) void,
};

pub const WlSeatListener = extern struct {
    capabilities: ?*const fn (data: ?*anyopaque, seat: ?*WlSeat, capabilities: u32) callconv(.c) void,
    name: ?*const fn (data: ?*anyopaque, seat: ?*WlSeat, name: [*c]const u8) callconv(.c) void,
};

pub const WlPointerListener = extern struct {
    enter: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, serial: u32, surface: ?*WlSurface, surface_x: wl_fixed_t, surface_y: wl_fixed_t) callconv(.c) void,
    leave: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, serial: u32, surface: ?*WlSurface) callconv(.c) void,
    motion: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, time: u32, surface_x: wl_fixed_t, surface_y: wl_fixed_t) callconv(.c) void,
    button: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, serial: u32, time: u32, button: u32, state: u32) callconv(.c) void,
    axis: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, time: u32, axis: u32, value: wl_fixed_t) callconv(.c) void,
    frame: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer) callconv(.c) void,
    axis_source: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, axis_source: u32) callconv(.c) void,
    axis_stop: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, time: u32, axis: u32) callconv(.c) void,
    axis_discrete: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, axis: u32, discrete: i32) callconv(.c) void,
    axis_value120: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, axis: u32, value120: i32) callconv(.c) void,
    axis_relative_direction: ?*const fn (data: ?*anyopaque, pointer: ?*WlPointer, axis: u32, direction: u32) callconv(.c) void,
};

pub const XdgWmBaseListener = extern struct {
    ping: ?*const fn (data: ?*anyopaque, wm_base: ?*XdgWmBase, serial: u32) callconv(.c) void,
};

pub const XdgSurfaceListener = extern struct {
    configure: ?*const fn (data: ?*anyopaque, surface: ?*XdgSurface, serial: u32) callconv(.c) void,
};

pub const XdgToplevelListener = extern struct {
    configure: ?*const fn (data: ?*anyopaque, toplevel: ?*XdgToplevel, width: i32, height: i32, states: ?*WlArray) callconv(.c) void,
    close: ?*const fn (data: ?*anyopaque, toplevel: ?*XdgToplevel) callconv(.c) void,
};

// ─── Constants ─────────────────────────────────────────────

pub const wl_seat_capability_pointer: u32 = 1;
pub const wl_pointer_button_state_pressed: u32 = 1;
pub const wl_pointer_button_state_released: u32 = 0;
pub const wl_pointer_axis_vertical_scroll: u32 = 0;

// ─── XDG shell functions (linked from wayland-scanner generated C) ────

pub extern fn xdg_wm_base_destroy(wm_base: *XdgWmBase) void;
pub extern fn xdg_wm_base_add_listener(wm_base: *XdgWmBase, listener: *const XdgWmBaseListener, data: ?*anyopaque) i32;
pub extern fn xdg_wm_base_get_xdg_surface(wm_base: *XdgWmBase, surface: *WlSurface) ?*XdgSurface;
pub extern fn xdg_wm_base_pong(wm_base: *XdgWmBase, serial: u32) void;
pub extern fn xdg_surface_destroy(surface: *XdgSurface) void;
pub extern fn xdg_surface_add_listener(surface: *XdgSurface, listener: *const XdgSurfaceListener, data: ?*anyopaque) i32;
pub extern fn xdg_surface_ack_configure(surface: *XdgSurface, serial: u32) void;
pub extern fn xdg_surface_get_toplevel(surface: *XdgSurface) ?*XdgToplevel;
pub extern fn xdg_toplevel_destroy(toplevel: *XdgToplevel) void;
pub extern fn xdg_toplevel_add_listener(toplevel: *XdgToplevel, listener: *const XdgToplevelListener, data: ?*anyopaque) i32;
pub extern fn xdg_toplevel_set_title(toplevel: *XdgToplevel, title: [*:0]const u8) void;

pub extern const xdg_wm_base_interface: WlInterface;

// ─── Wayland function pointer types ────────────────────────

pub const PFNWLDISPLAYCONNECT = *const fn (name: ?[*:0]const u8) callconv(.c) ?*WlDisplay;
pub const PFNWLDISPLAYDISCONNECT = *const fn (display: *WlDisplay) callconv(.c) void;
pub const PFNWLDISPLAYGETREGISTRY = *const fn (display: *WlDisplay) callconv(.c) ?*WlRegistry;
pub const PFNWLDISPLAYROUNDTRIP = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYDISPATCH = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYDISPATCHPENDING = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYPREPAREREAD = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYFLUSH = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYCANCELREAD = *const fn (display: *WlDisplay) callconv(.c) void;
pub const PFNWLDISPLAYGETFD = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLDISPLAYREADEVENTS = *const fn (display: *WlDisplay) callconv(.c) i32;
pub const PFNWLREGISTRYADDLISTENER = *const fn (registry: *WlRegistry, listener: *const WlRegistryListener, data: ?*anyopaque) callconv(.c) i32;
pub const PFNWLREGISTRYBIND = *const fn (registry: *WlRegistry, name: u32, interface: *const WlInterface, version: u32) callconv(.c) *anyopaque;
pub const PFNWLREGISTRYDESTROY = *const fn (registry: *WlRegistry) callconv(.c) void;
pub const PFNWLCOMPOSITORCREATESURFACE = *const fn (compositor: *WlCompositor) callconv(.c) ?*WlSurface;
pub const PFNWLCOMPOSITORDESTROY = *const fn (compositor: *WlCompositor) callconv(.c) void;
pub const PFNWLSURFACEDESTROY = *const fn (surface: *WlSurface) callconv(.c) void;
pub const PFNWLSURFACECOMMIT = *const fn (surface: *WlSurface) callconv(.c) void;
pub const PFNWLSURFACESETBUFFERSCALE = *const fn (surface: *WlSurface, scale: i32) callconv(.c) void;
pub const PFNWLSEATADDLISTENER = *const fn (seat: *WlSeat, listener: *const WlSeatListener, data: ?*anyopaque) callconv(.c) i32;
pub const PFNWLSEATDESTROY = *const fn (seat: *WlSeat) callconv(.c) void;
pub const PFNWLSEATGETPOINTER = *const fn (seat: *WlSeat) callconv(.c) ?*WlPointer;
pub const PFNWLPOINTERADDLISTENER = *const fn (pointer: *WlPointer, listener: *const WlPointerListener, data: ?*anyopaque) callconv(.c) i32;
pub const PFNWLPOINTERDESTROY = *const fn (pointer: *WlPointer) callconv(.c) void;
pub const PFNWLPOINTERSETCURSOR = *const fn (pointer: *WlPointer, serial: u32, surface: ?*WlSurface, hotspot_x: i32, hotspot_y: i32) callconv(.c) void;

pub const PFNWLEGLWINDOWCREATE = *const fn (surface: *WlSurface, width: i32, height: i32) callconv(.c) ?*WlEglWindow;
pub const PFNWLEGLWINDOWDESTROY = *const fn (window: *WlEglWindow) callconv(.c) void;
pub const PFNWLEGLWINDOWRESIZE = *const fn (window: *WlEglWindow, width: i32, height: i32, dx: i32, dy: i32) callconv(.c) void;

// ─── Wayland + Wayland EGL wrapper ─────────────────────────

pub const Wayland = struct {
    lib: std.DynLib,
    lib_egl: std.DynLib,

    wl_display_connect: PFNWLDISPLAYCONNECT,
    wl_display_disconnect: PFNWLDISPLAYDISCONNECT,
    wl_display_get_registry: PFNWLDISPLAYGETREGISTRY,
    wl_display_roundtrip: PFNWLDISPLAYROUNDTRIP,
    wl_display_dispatch: PFNWLDISPLAYDISPATCH,
    wl_display_dispatch_pending: PFNWLDISPLAYDISPATCHPENDING,
    wl_display_prepare_read: PFNWLDISPLAYPREPAREREAD,
    wl_display_flush: PFNWLDISPLAYFLUSH,
    wl_display_cancel_read: PFNWLDISPLAYCANCELREAD,
    wl_display_get_fd: PFNWLDISPLAYGETFD,
    wl_display_read_events: PFNWLDISPLAYREADEVENTS,
    wl_registry_add_listener: PFNWLREGISTRYADDLISTENER,
    wl_registry_bind: PFNWLREGISTRYBIND,
    wl_registry_destroy: PFNWLREGISTRYDESTROY,
    wl_compositor_create_surface: PFNWLCOMPOSITORCREATESURFACE,
    wl_compositor_destroy: PFNWLCOMPOSITORDESTROY,
    wl_surface_destroy: PFNWLSURFACEDESTROY,
    wl_surface_commit: PFNWLSURFACECOMMIT,
    wl_surface_set_buffer_scale: PFNWLSURFACESETBUFFERSCALE,
    wl_seat_add_listener: PFNWLSEATADDLISTENER,
    wl_seat_destroy: PFNWLSEATDESTROY,
    wl_seat_get_pointer: PFNWLSEATGETPOINTER,
    wl_pointer_add_listener: PFNWLPOINTERADDLISTENER,
    wl_pointer_destroy: PFNWLPOINTERDESTROY,
    wl_pointer_set_cursor: PFNWLPOINTERSETCURSOR,
    wl_egl_window_create: PFNWLEGLWINDOWCREATE,
    wl_egl_window_destroy: PFNWLEGLWINDOWDESTROY,
    wl_egl_window_resize: PFNWLEGLWINDOWRESIZE,

    wl_compositor_interface: *const WlInterface,
    wl_seat_interface: *const WlInterface,

    pub fn open() !Wayland {
        var lib = try std.DynLib.openZ("libwayland-client.so.0");
        errdefer lib.close();
        var lib_egl = try std.DynLib.openZ("libwayland-egl.so.1");
        errdefer lib_egl.close();

        return Wayland{
            .lib = lib,
            .lib_egl = lib_egl,
            .wl_display_connect = lib.lookup(PFNWLDISPLAYCONNECT, "wl_display_connect") orelse return error.Unexpected,
            .wl_display_disconnect = lib.lookup(PFNWLDISPLAYDISCONNECT, "wl_display_disconnect") orelse return error.Unexpected,
            .wl_display_get_registry = lib.lookup(PFNWLDISPLAYGETREGISTRY, "wl_display_get_registry") orelse return error.Unexpected,
            .wl_display_roundtrip = lib.lookup(PFNWLDISPLAYROUNDTRIP, "wl_display_roundtrip") orelse return error.Unexpected,
            .wl_display_dispatch = lib.lookup(PFNWLDISPLAYDISPATCH, "wl_display_dispatch") orelse return error.Unexpected,
            .wl_display_dispatch_pending = lib.lookup(PFNWLDISPLAYDISPATCHPENDING, "wl_display_dispatch_pending") orelse return error.Unexpected,
            .wl_display_prepare_read = lib.lookup(PFNWLDISPLAYPREPAREREAD, "wl_display_prepare_read") orelse return error.Unexpected,
            .wl_display_flush = lib.lookup(PFNWLDISPLAYFLUSH, "wl_display_flush") orelse return error.Unexpected,
            .wl_display_cancel_read = lib.lookup(PFNWLDISPLAYCANCELREAD, "wl_display_cancel_read") orelse return error.Unexpected,
            .wl_display_get_fd = lib.lookup(PFNWLDISPLAYGETFD, "wl_display_get_fd") orelse return error.Unexpected,
            .wl_display_read_events = lib.lookup(PFNWLDISPLAYREADEVENTS, "wl_display_read_events") orelse return error.Unexpected,
            .wl_registry_add_listener = lib.lookup(PFNWLREGISTRYADDLISTENER, "wl_registry_add_listener") orelse return error.Unexpected,
            .wl_registry_bind = lib.lookup(PFNWLREGISTRYBIND, "wl_registry_bind") orelse return error.Unexpected,
            .wl_registry_destroy = lib.lookup(PFNWLREGISTRYDESTROY, "wl_registry_destroy") orelse return error.Unexpected,
            .wl_compositor_create_surface = lib.lookup(PFNWLCOMPOSITORCREATESURFACE, "wl_compositor_create_surface") orelse return error.Unexpected,
            .wl_compositor_destroy = lib.lookup(PFNWLCOMPOSITORDESTROY, "wl_compositor_destroy") orelse return error.Unexpected,
            .wl_surface_destroy = lib.lookup(PFNWLSURFACEDESTROY, "wl_surface_destroy") orelse return error.Unexpected,
            .wl_surface_commit = lib.lookup(PFNWLSURFACECOMMIT, "wl_surface_commit") orelse return error.Unexpected,
            .wl_surface_set_buffer_scale = lib.lookup(PFNWLSURFACESETBUFFERSCALE, "wl_surface_set_buffer_scale") orelse return error.Unexpected,
            .wl_seat_add_listener = lib.lookup(PFNWLSEATADDLISTENER, "wl_seat_add_listener") orelse return error.Unexpected,
            .wl_seat_destroy = lib.lookup(PFNWLSEATDESTROY, "wl_seat_destroy") orelse return error.Unexpected,
            .wl_seat_get_pointer = lib.lookup(PFNWLSEATGETPOINTER, "wl_seat_get_pointer") orelse return error.Unexpected,
            .wl_pointer_add_listener = lib.lookup(PFNWLPOINTERADDLISTENER, "wl_pointer_add_listener") orelse return error.Unexpected,
            .wl_pointer_destroy = lib.lookup(PFNWLPOINTERDESTROY, "wl_pointer_destroy") orelse return error.Unexpected,
            .wl_pointer_set_cursor = lib.lookup(PFNWLPOINTERSETCURSOR, "wl_pointer_set_cursor") orelse return error.Unexpected,
            .wl_egl_window_create = lib_egl.lookup(PFNWLEGLWINDOWCREATE, "wl_egl_window_create") orelse return error.Unexpected,
            .wl_egl_window_destroy = lib_egl.lookup(PFNWLEGLWINDOWDESTROY, "wl_egl_window_destroy") orelse return error.Unexpected,
            .wl_egl_window_resize = lib_egl.lookup(PFNWLEGLWINDOWRESIZE, "wl_egl_window_resize") orelse return error.Unexpected,
            .wl_compositor_interface = lib.lookup(*const WlInterface, "wl_compositor_interface") orelse return error.Unexpected,
            .wl_seat_interface = lib.lookup(*const WlInterface, "wl_seat_interface") orelse return error.Unexpected,
        };
    }

    pub fn deinit(self: *Wayland) void {
        self.lib_egl.close();
        self.lib.close();
    }
};

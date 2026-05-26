const std = @import("std");
const icon = @import("icon.zig");
const icon_svg = @import("icon_svg.zig");
const input = @import("input.zig");
const interaction = @import("ui_interaction.zig");
const linux_drm = @import("linux_drm.zig");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_gpu = @import("render/gpu.zig");
const renderer_gpu_buffer = @import("render/gpu_buffer.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_native_present = @import("render/native_present.zig");
const renderer_software = @import("render/software.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const app_cursor = @import("app_cursor.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const app_landing = @import("app_landing.zig");
const app_navigation = @import("app_navigation.zig");
const ui = @import("ui.zig");
const ui_runtime = @import("ui_runtime.zig");

const linux = std.os.linux;
const posix = std.posix;

const default_width: u32 = 960;
const default_height: u32 = 540;
const default_seconds: u32 = 5;
const default_refresh_hz: u32 = 60;
const tile_width: u32 = 64;
const tile_height: u32 = 64;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_interaction_regions: usize = 1024;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_tiles: usize = 512;
const max_gpu_primitives: usize = 32768;
const max_registry_globals: usize = 128;
const socket_read_bytes: usize = 8192;
const message_bytes: usize = 512;
const pointer_motion_render_step: f32 = 8.0;
const cursor_scene_budget: usize = 32;
const cursor_overlay_icon_vertices: usize = renderer_ir.icon_instance_float_stride * 2;

const display_id: u32 = 1;
const registry_id: u32 = 2;
const sync_callback_id: u32 = 3;
const compositor_id: u32 = 4;
const shm_id: u32 = 5;
const wm_base_id: u32 = 6;
const seat_id: u32 = 7;
const pointer_id: u32 = 8;
const surface_id: u32 = 9;
const xdg_surface_id: u32 = 10;
const xdg_toplevel_id: u32 = 11;
const shm_pool_id: u32 = 12;
const wl_buffer_id: u32 = 13;
const linux_dmabuf_id: u32 = 14;
const dmabuf_params_id: u32 = 15;
const dmabuf_wl_buffer_id: u32 = 16;
const xdg_decoration_manager_id: u32 = 17;
const xdg_toplevel_decoration_id: u32 = 18;

const wl_display_sync: u16 = 0;
const wl_display_get_registry: u16 = 1;
const wl_registry_bind: u16 = 0;
const wl_compositor_create_surface: u16 = 0;
const wl_seat_get_pointer: u16 = 0;
const wl_pointer_set_cursor: u16 = 0;
const wl_shm_create_pool: u16 = 0;
const wl_shm_pool_create_buffer: u16 = 0;
const wl_shm_pool_destroy: u16 = 1;
const wl_surface_attach: u16 = 1;
const wl_surface_damage_buffer: u16 = 9;
const wl_surface_commit: u16 = 6;
const xdg_wm_base_get_xdg_surface: u16 = 2;
const xdg_wm_base_pong: u16 = 3;
const xdg_surface_get_toplevel: u16 = 1;
const xdg_surface_ack_configure: u16 = 4;
const xdg_toplevel_set_title: u16 = 2;
const xdg_toplevel_set_app_id: u16 = 3;
const xdg_toplevel_move: u16 = 5;
const xdg_toplevel_set_minimized: u16 = 13;
const xdg_decoration_manager_get_toplevel_decoration: u16 = 1;
const xdg_toplevel_decoration_set_mode: u16 = 1;
const zwp_linux_dmabuf_create_params: u16 = 1;
const zwp_linux_buffer_params_add: u16 = 1;
const zwp_linux_buffer_params_create_immed: u16 = 3;

const wl_display_error_event: u16 = 0;
const wl_registry_global_event: u16 = 0;
const wl_callback_done_event: u16 = 0;
const wl_pointer_enter_event: u16 = 0;
const wl_pointer_leave_event: u16 = 1;
const wl_pointer_motion_event: u16 = 2;
const wl_pointer_button_event: u16 = 3;
const wl_pointer_axis_event: u16 = 4;
const wl_seat_capabilities_event: u16 = 0;
const xdg_wm_base_ping_event: u16 = 0;
const xdg_surface_configure_event: u16 = 0;
const xdg_toplevel_close_event: u16 = 1;

const wl_shm_format_xrgb8888: u32 = 1;
const drm_format_xrgb8888: u32 = 0x34325258;
const drm_format_argb8888: u32 = 0x34325241;
const dmabuf_flags_none: u32 = 0;
const wl_pointer_button_left: u32 = 0x110;
const wl_pointer_button_released: u32 = 0;
const wl_pointer_axis_vertical_scroll: u32 = 0;
const wl_seat_capability_pointer: u32 = 1;
const xdg_toplevel_decoration_mode_server_side: u32 = 2;
const fixed_scale: f32 = 256.0;
const client_decor_h: f32 = 34.0;
const client_decor_button_size: f32 = 24.0;
const client_decor_button_gap: f32 = 8.0;
const client_decor_icon_size: f32 = 14.0;
const client_decor_minimize_w: f32 = 10.0;
const client_decor_minimize_h: f32 = 2.0;
const client_decor_close_id: u32 = 40_000;
const client_decor_minimize_id: u32 = 40_001;
const client_decor_drag_id: u32 = 40_002;
const client_decor_bg = ui.Color{ .r = 24, .g = 24, .b = 27 };
const client_decor_border = ui.Color{ .r = 52, .g = 52, .b = 58 };
const client_decor_text = ui.Color{ .r = 232, .g = 232, .b = 235 };
const client_decor_dim = ui.Color{ .r = 156, .g = 156, .b = 164 };

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
    width: u32 = default_width,
    height: u32 = default_height,
    seconds: u32 = default_seconds,
    present: PresentMode = .cpu,
    drm_device: []const u8 = linux_drm.default_device_path,
    dmabuf_fd: ?posix.fd_t = null,
    path: []const u8 = "/",
};

const PresentMode = enum {
    cpu,
    gpu_record,
    gpu_dmabuf,
};

const ObjectKind = enum {
    unknown,
    display,
    registry,
    callback,
    compositor,
    shm,
    wm_base,
    surface,
    xdg_surface,
    xdg_toplevel,
    seat,
    pointer,
    linux_dmabuf,
    dmabuf_params,
    dmabuf_buffer,
    decoration_manager,
    toplevel_decoration,
};

const RegistryGlobal = struct {
    name: u32,
    interface: RegistryInterface,
    version: u32,
};

const RegistryInterface = enum {
    other,
    compositor,
    shm,
    wm_base,
    seat,
    linux_dmabuf,
    xdg_decoration_manager,
};

const RegistryState = struct {
    globals: [max_registry_globals]RegistryGlobal = undefined,
    len: usize = 0,

    fn add(self: *RegistryState, global: RegistryGlobal) !void {
        if (self.len >= self.globals.len) return error.RegistryGlobalBudgetExceeded;
        self.globals[self.len] = global;
        self.len += 1;
    }

    fn find(self: RegistryState, interface: RegistryInterface) ?RegistryGlobal {
        for (self.globals[0..self.len]) |global| {
            if (global.interface == interface) return global;
        }
        return null;
    }
};

const WaylandState = struct {
    registry: RegistryState = .{},
    registry_done: bool = false,
    configured: bool = false,
    closed: bool = false,
    seat_has_pointer: bool = false,
    dmabuf_bound: bool = false,
};

const DmabufImport = struct {
    fd: posix.fd_t,
    width: u32,
    height: u32,
    stride: u32,
    format: u32 = drm_format_xrgb8888,
    offset: u32 = 0,
    plane_index: u32 = 0,
    modifier: u64 = 0,

    fn valid(self: DmabufImport) bool {
        return self.fd >= 0 and
            self.width != 0 and
            self.height != 0 and
            self.stride >= self.width * @sizeOf(u32) and
            isSupportedDmabufFormat(self.format);
    }

    fn fromNativeSurface(surface: renderer_native_present.NativeSurface) !DmabufImport {
        return switch (surface) {
            .drm => error.UnsupportedDmabufSurface,
            .wayland => |value| fromWaylandSurface(value),
        };
    }

    fn fromWaylandSurface(surface: renderer_native_present.WaylandSurface) !DmabufImport {
        const gpu_buffer = surface.gpu_buffer orelse return error.InvalidDmabufImport;
        if (gpu_buffer.kind != .dma_buf or gpu_buffer.plane_count != 1) return error.InvalidDmabufImport;
        if (gpu_buffer.handle > @as(u64, @intCast(std.math.maxInt(posix.fd_t)))) return error.InvalidDmabufImport;
        const import = DmabufImport{
            .fd = @intCast(gpu_buffer.handle),
            .width = surface.width,
            .height = surface.height,
            .stride = surface.stride * @sizeOf(u32),
            .format = dmabufFormat(surface.format),
            .offset = gpu_buffer.offset,
            .modifier = gpu_buffer.modifier,
        };
        if (!import.valid()) return error.InvalidDmabufImport;
        return import;
    }
};

const AppState = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    runtime: ui_runtime.State = .{},
    public_identity_ready: bool = true,
    public_identity: []const u8 = "native-wayland",
    route: app_navigation.Route = .{},
};

const Message = struct {
    object_id: u32,
    opcode: u16,
    payload: []const u8,
};

const MessageWriter = struct {
    buffer: []u8,
    len: usize = 0,

    fn init(buffer: []u8, object_id: u32, opcode: u16) !MessageWriter {
        if (buffer.len < 8) return error.MessageBufferTooSmall;
        var self = MessageWriter{ .buffer = buffer, .len = 8 };
        std.mem.writeInt(u32, self.buffer[0..4], object_id, .little);
        std.mem.writeInt(u16, self.buffer[4..6], opcode, .little);
        return self;
    }

    fn putU32(self: *MessageWriter, value: u32) !void {
        try self.reserve(4);
        std.mem.writeInt(u32, self.buffer[self.len..][0..4], value, .little);
        self.len += 4;
    }

    fn putI32(self: *MessageWriter, value: i32) !void {
        try self.putU32(@bitCast(value));
    }

    fn putString(self: *MessageWriter, value: []const u8) !void {
        const wire_len: u32 = @intCast(value.len + 1);
        try self.putU32(wire_len);
        try self.reserve(paddedLen(wire_len));
        @memcpy(self.buffer[self.len..][0..value.len], value);
        self.buffer[self.len + value.len] = 0;
        @memset(self.buffer[self.len + value.len + 1 .. self.len + paddedLen(wire_len)], 0);
        self.len += paddedLen(wire_len);
    }

    fn finish(self: *MessageWriter) []const u8 {
        std.mem.writeInt(u16, self.buffer[6..8], @intCast(self.len), .little);
        return self.buffer[0..self.len];
    }

    fn reserve(self: MessageWriter, count: usize) !void {
        if (self.len + count > self.buffer.len) return error.MessageBufferTooSmall;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);
    const socket_path = try waylandSocketPath(init, allocator);
    defer allocator.free(socket_path);

    var client = try WaylandClient.connect(init.io, socket_path);
    defer client.close(init.io);
    try client.bootstrap();
    try client.createWindow(options.width, options.height);
    const app = try NativeApp.create(&client, allocator, options);
    defer app.destroy();
    try app.render(&client);
    try client.eventLoop(options.seconds, app);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.width = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (std.mem.eql(u8, arg, "--height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.height = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (std.mem.eql(u8, arg, "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (std.mem.eql(u8, arg, "--present")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.present = try parsePresentMode(args[index]);
        } else if (std.mem.eql(u8, arg, "--drm-device")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.drm_device = args[index];
        } else if (std.mem.eql(u8, arg, "--dmabuf-fd")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.dmabuf_fd = try std.fmt.parseInt(posix.fd_t, args[index], 10);
        } else if (std.mem.eql(u8, arg, "--path")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.path = args[index];
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width == 0 or options.height == 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

fn parsePresentMode(value: []const u8) !PresentMode {
    if (std.mem.eql(u8, value, "cpu")) return .cpu;
    if (std.mem.eql(u8, value, "gpu-record")) return .gpu_record;
    if (std.mem.eql(u8, value, "gpu-dmabuf")) return .gpu_dmabuf;
    return error.InvalidArguments;
}

fn waylandSocketPath(init: std.process.Init, allocator: std.mem.Allocator) ![]u8 {
    const runtime_dir = init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.MissingWaylandRuntime;
    const display = init.environ_map.get("WAYLAND_DISPLAY") orelse "wayland-0";
    if (std.mem.indexOfScalar(u8, display, '/')) |_| return allocator.dupe(u8, display);
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, display });
}

const WaylandClient = struct {
    fd: posix.fd_t,
    state: WaylandState = .{},
    read_buffer: [socket_read_bytes]u8 = undefined,
    read_len: usize = 0,
    object_kinds: [32]ObjectKind = [_]ObjectKind{.unknown} ** 32,

    fn connect(io: std.Io, path: []const u8) !WaylandClient {
        const address = try std.Io.net.UnixAddress.init(path);
        const stream = try std.Io.net.UnixAddress.connect(&address, io);
        var client = WaylandClient{ .fd = stream.socket.handle };
        client.object_kinds[display_id] = .display;
        client.object_kinds[registry_id] = .registry;
        client.object_kinds[sync_callback_id] = .callback;
        client.object_kinds[compositor_id] = .compositor;
        client.object_kinds[shm_id] = .shm;
        client.object_kinds[wm_base_id] = .wm_base;
        client.object_kinds[surface_id] = .surface;
        client.object_kinds[xdg_surface_id] = .xdg_surface;
        client.object_kinds[xdg_toplevel_id] = .xdg_toplevel;
        client.object_kinds[seat_id] = .seat;
        client.object_kinds[pointer_id] = .pointer;
        client.object_kinds[linux_dmabuf_id] = .linux_dmabuf;
        client.object_kinds[dmabuf_params_id] = .dmabuf_params;
        client.object_kinds[dmabuf_wl_buffer_id] = .dmabuf_buffer;
        client.object_kinds[xdg_decoration_manager_id] = .decoration_manager;
        client.object_kinds[xdg_toplevel_decoration_id] = .toplevel_decoration;
        return client;
    }

    fn close(self: *WaylandClient, io: std.Io) void {
        _ = io;
        closeFd(self.fd);
    }

    fn bootstrap(self: *WaylandClient) !void {
        try self.send(makeGetRegistry);
        try self.send(makeSync);
        while (!self.state.registry_done) try self.readEventsBlocking();
        const compositor = self.state.registry.find(.compositor) orelse return error.MissingWaylandCompositor;
        const shm = self.state.registry.find(.shm) orelse return error.MissingWaylandShm;
        const wm_base = self.state.registry.find(.wm_base) orelse return error.MissingXdgWmBase;
        const seat = self.state.registry.find(.seat);
        try self.sendBind(compositor.name, "wl_compositor", @min(compositor.version, 4), compositor_id);
        try self.sendBind(shm.name, "wl_shm", @min(shm.version, 1), shm_id);
        try self.sendBind(wm_base.name, "xdg_wm_base", @min(wm_base.version, 1), wm_base_id);
        if (seat) |value| {
            try self.sendBind(value.name, "wl_seat", value.version, seat_id);
        }
        try self.send(makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
        if (self.state.seat_has_pointer) {
            try self.send(makeGetPointer);
            try self.send(makeSync);
            self.state.registry_done = false;
            while (!self.state.registry_done) try self.readEventsBlocking();
        }
    }

    fn createWindow(self: *WaylandClient, width: u32, height: u32) !void {
        _ = width;
        _ = height;
        try self.send(makeCreateSurface);
        try self.send(makeGetXdgSurface);
        try self.send(makeGetToplevel);
        try self.sendTitle("EdgeRun Native Wayland");
        try self.sendAppId("dev.edgerun.Native");
        try self.send(makeSurfaceCommit);
        while (!self.state.configured) try self.readEventsBlocking();
    }

    fn eventLoop(self: *WaylandClient, seconds: u32, app: *NativeApp) !void {
        var remaining_ms: i32 = @intCast(seconds * std.time.ms_per_s);
        while (!self.state.closed and remaining_ms > 0) {
            const step_ms: i32 = @min(remaining_ms, 100);
            var fds = [_]posix.pollfd{.{ .fd = self.fd, .events = linux.POLL.IN, .revents = 0 }};
            const ready = try posix.poll(&fds, step_ms);
            if (ready != 0 and (fds[0].revents & linux.POLL.IN) != 0) try self.readEvents(app);
            remaining_ms -= step_ms;
        }
    }

    fn createShmBuffer(self: *WaylandClient, bytes: usize, width: u32, height: u32, stride: u32) !ShmBuffer {
        const fd = try posix.memfd_create("edgerun-wayland-frame", linux.MFD.CLOEXEC);
        errdefer closeFd(fd);
        try truncateFd(fd, bytes);
        const mapped = try posix.mmap(null, bytes, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);
        errdefer posix.munmap(mapped);
        try self.sendCreatePool(fd, @intCast(bytes));
        try self.sendCreateBuffer(width, height, stride);
        try self.send(makeDestroyPool);
        return .{ .fd = fd, .memory = mapped, .width = width, .height = height, .stride = stride };
    }

    fn createDmabufBuffer(self: *WaylandClient, import: DmabufImport) !void {
        if (!import.valid()) return error.InvalidDmabufImport;
        try self.bindDmabuf();
        try self.send(makeDmabufCreateParams);
        try self.sendDmabufAddPlane(import);
        try self.sendDmabufCreateImmediate(import.width, import.height, import.format);
    }

    fn bindDmabuf(self: *WaylandClient) !void {
        if (self.state.dmabuf_bound) return;
        const global = self.state.registry.find(.linux_dmabuf) orelse return error.MissingWaylandDmabuf;
        try self.sendBind(global.name, "zwp_linux_dmabuf_v1", @min(global.version, 4), linux_dmabuf_id);
        try self.send(makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
        self.state.dmabuf_bound = true;
    }

    fn attachCommit(self: *WaylandClient, width: u32, height: u32) !void {
        try self.sendAttach(wl_buffer_id);
        try self.sendDamage(width, height);
        try self.send(makeSurfaceCommit);
    }

    fn attachCommitRect(self: *WaylandClient, rect: PixelRect) !void {
        try self.sendAttach(wl_buffer_id);
        try self.sendDamageRect(rect);
        try self.send(makeSurfaceCommit);
    }

    fn attachDmabufCommit(self: *WaylandClient, width: u32, height: u32) !void {
        try self.sendAttach(dmabuf_wl_buffer_id);
        try self.sendDamage(width, height);
        try self.send(makeSurfaceCommit);
    }

    fn send(self: WaylandClient, comptime maker: fn ([]u8) anyerror![]const u8) !void {
        var buffer: [message_bytes]u8 = undefined;
        try writeAll(self.fd, try maker(&buffer));
    }

    fn sendBind(self: WaylandClient, name: u32, interface: []const u8, version: u32, new_id: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeBind(&buffer, name, interface, version, new_id);
        try writeAll(self.fd, bytes);
    }

    fn sendTitle(self: WaylandClient, title: []const u8) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeSetTitle(&buffer, title);
        try writeAll(self.fd, bytes);
    }

    fn sendAppId(self: WaylandClient, app_id: []const u8) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeSetAppId(&buffer, app_id);
        try writeAll(self.fd, bytes);
    }

    fn sendMove(self: WaylandClient, serial: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeMove(&buffer, serial);
        try writeAll(self.fd, bytes);
    }

    fn sendMinimize(self: WaylandClient) !void {
        var buffer: [message_bytes]u8 = undefined;
        try writeAll(self.fd, try makeSetMinimized(&buffer));
    }

    fn sendHidePointerCursor(self: WaylandClient, serial: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        try writeAll(self.fd, try makeHidePointerCursor(&buffer, serial));
    }

    fn sendDamage(self: WaylandClient, width: u32, height: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeDamageBuffer(&buffer, width, height);
        try writeAll(self.fd, bytes);
    }

    fn sendDamageRect(self: WaylandClient, rect: PixelRect) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeDamageBufferRect(&buffer, rect);
        try writeAll(self.fd, bytes);
    }

    fn sendAttach(self: WaylandClient, buffer_id: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        try writeAll(self.fd, try makeAttach(&buffer, buffer_id));
    }

    fn sendCreatePool(self: WaylandClient, fd: posix.fd_t, bytes: i32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const msg = try makeCreatePool(&buffer, bytes);
        try sendFd(self.fd, msg, fd);
    }

    fn sendCreateBuffer(self: WaylandClient, width: u32, height: u32, stride: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeCreateBuffer(&buffer, width, height, stride);
        try writeAll(self.fd, bytes);
    }

    fn sendDmabufAddPlane(self: WaylandClient, import: DmabufImport) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeDmabufAddPlane(&buffer, import.plane_index, import.offset, import.stride, import.modifier);
        try sendFd(self.fd, bytes, import.fd);
    }

    fn sendDmabufCreateImmediate(self: WaylandClient, width: u32, height: u32, format: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeDmabufCreateImmediate(&buffer, width, height, format);
        try writeAll(self.fd, bytes);
    }

    fn readEventsBlocking(self: *WaylandClient) !void {
        const n = try posix.read(self.fd, self.read_buffer[self.read_len..]);
        if (n == 0) return error.WaylandConnectionClosed;
        self.read_len += n;
        var offset: usize = 0;
        while (nextMessage(self.read_buffer[offset..self.read_len])) |message| {
            try self.replyToMessage(self.object_kinds[message.object_id], message);
            try handleMessage(&self.state, self.object_kinds[message.object_id], message);
            offset += message.payload.len + 8;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.read_buffer[0 .. self.read_len - offset], self.read_buffer[offset..self.read_len]);
            self.read_len -= offset;
        }
    }

    fn readEvents(self: *WaylandClient, app: *NativeApp) !void {
        const n = try posix.read(self.fd, self.read_buffer[self.read_len..]);
        if (n == 0) return error.WaylandConnectionClosed;
        self.read_len += n;
        var offset: usize = 0;
        var needs_render = false;
        while (nextMessage(self.read_buffer[offset..self.read_len])) |message| {
            const kind = self.object_kinds[message.object_id];
            try self.replyToMessage(kind, message);
            try handleMessage(&self.state, kind, message);
            needs_render = (try app.handleWaylandInput(self, kind, message)) or needs_render;
            offset += message.payload.len + 8;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.read_buffer[0 .. self.read_len - offset], self.read_buffer[offset..self.read_len]);
            self.read_len -= offset;
        }
        if (needs_render) try app.render(self);
    }

    fn replyToMessage(self: WaylandClient, kind: ObjectKind, message: Message) !void {
        if (message.payload.len < 4) return;
        const serial = std.mem.readInt(u32, message.payload[0..4], .little);
        switch (kind) {
            .wm_base => if (message.opcode == xdg_wm_base_ping_event) {
                var buffer: [message_bytes]u8 = undefined;
                try writeAll(self.fd, try makePong(&buffer, serial));
            },
            .xdg_surface => if (message.opcode == xdg_surface_configure_event) {
                var buffer: [message_bytes]u8 = undefined;
                try writeAll(self.fd, try makeAckConfigure(&buffer, serial));
            },
            else => {},
        }
    }
};

const ShmBuffer = struct {
    fd: posix.fd_t,
    memory: []align(std.heap.page_size_min) u8,
    width: u32,
    height: u32,
    stride: u32,

    fn deinit(self: ShmBuffer) void {
        posix.munmap(self.memory);
        closeFd(self.fd);
    }
};

const PixelRect = struct {
    x: usize,
    y: usize,
    w: usize,
    h: usize,

    fn valid(self: PixelRect) bool {
        return self.w != 0 and self.h != 0;
    }
};

const NativeApp = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    present: PresentMode,
    dmabuf_fd: ?posix.fd_t,
    shm: ShmBuffer,
    pixels: []ui.Color,
    base_pixels: []ui.Color,
    base_pixels_ready: bool = false,
    cursor_damage: ?PixelRect = null,
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_interaction_regions]interaction.Region = undefined,
    region_len: usize = 0,
    ir_storage: IrStorage = .{},
    font_atlas: renderer_font_atlas.Atlas,
    gpu_primitives: []renderer_gpu.Primitive,
    gpu_tile_marks: [max_tiles]u8 = undefined,
    gpu_dirty_ids: [max_tiles]u32 = undefined,
    tile_marks: [max_tiles]u8 = undefined,
    dirty_ids: [max_tiles]u32 = undefined,
    state: AppState = .{},
    gpu_recorder: GpuRecorder = .{},
    gpu_buffer_device: renderer_gpu_buffer.CpuFilledDevice = .{},
    drm_buffer: ?linux_drm.DumbBuffer = null,

    fn create(client: *WaylandClient, allocator: std.mem.Allocator, options: Options) !*NativeApp {
        const width = options.width;
        const height = options.height;
        const stride = width * @sizeOf(u32);
        const shm = try client.createShmBuffer(@as(usize, stride) * height, width, height, stride);
        errdefer shm.deinit();
        const pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        const base_pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
        errdefer allocator.free(base_pixels);
        const gpu_primitives = try allocator.alloc(renderer_gpu.Primitive, max_gpu_primitives);
        errdefer allocator.free(gpu_primitives);
        var drm_buffer: ?linux_drm.DumbBuffer = if (options.present == .gpu_dmabuf and options.dmabuf_fd == null)
            try linux_drm.DumbBuffer.createExported(options.drm_device, width, height, .xrgb8888)
        else
            null;
        errdefer if (drm_buffer) |*buffer| buffer.deinit();

        const self = try allocator.create(NativeApp);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.width = width;
        self.height = height;
        self.present = options.present;
        self.dmabuf_fd = options.dmabuf_fd;
        self.shm = shm;
        self.pixels = pixels;
        self.base_pixels = base_pixels;
        self.base_pixels_ready = false;
        self.cursor_damage = null;
        self.gpu_primitives = gpu_primitives;
        self.region_len = 0;
        self.ir_storage = .{};
        self.font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body());
        self.state = .{ .route = app_navigation.fromPath(options.path) };
        self.gpu_recorder = .{};
        self.gpu_buffer_device = .{};
        self.drm_buffer = drm_buffer;
        return self;
    }

    fn deinit(self: *NativeApp) void {
        if (self.drm_buffer) |*buffer| buffer.deinit();
        self.allocator.free(self.gpu_primitives);
        self.allocator.free(self.base_pixels);
        self.allocator.free(self.pixels);
        self.shm.deinit();
    }

    fn destroy(self: *NativeApp) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    fn render(self: *NativeApp, client: *WaylandClient) !void {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try renderNativeAppScene(&scene, &collector, self.width, self.height, self.state);
        self.region_len = collector.written().len;
        self.updateHoverHit(self.regionSlice());
        const cursor_kind = app_cursor.fromState(.none, self.state.runtime.hoverKind());
        if (self.present != .cpu) try app_cursor.render(&scene, self.state.hover_x, self.state.hover_y, cursor_kind);

        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, .object, scene.written());

        var sink_state = WaylandCommitSink{};
        const resources = renderer_pipeline.softwareResources(&self.font_atlas, try app_images.cloudMeme());
        switch (self.present) {
            .cpu => {
                const receipt = try renderer_native_present.renderCpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    resources,
                    .{ .width = self.width, .height = self.height, .pixels = self.pixels },
                    appBackground(),
                    default_refresh_hz,
                    tile_width,
                    tile_height,
                    &self.tile_marks,
                    &self.dirty_ids,
                    sink_state.sink(),
                );
                if (!receipt.valid() or !sink_state.submitted) return error.WaylandCommitRejected;
                @memcpy(self.base_pixels, self.pixels);
                self.base_pixels_ready = true;
                self.cursor_damage = try self.renderCursorOverlay(cursor_kind);
            },
            .gpu_record => {
                const receipt = try renderer_native_present.renderGpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    resources.presentationResources(),
                    self.gpu_recorder.device(),
                    .{
                        .primitives = self.gpu_primitives,
                        .gpu_tile_marks = &self.gpu_tile_marks,
                        .gpu_dirty_ids = &self.gpu_dirty_ids,
                        .native_tile_marks = &self.tile_marks,
                        .native_dirty_ids = &self.dirty_ids,
                    },
                    default_refresh_hz,
                    tile_width,
                    tile_height,
                    sink_state.sink(),
                );
                if (!receipt.valid() or !sink_state.submitted) return error.WaylandCommitRejected;
                try self.renderSoftwarePixels(buffers, resources);
            },
            .gpu_dmabuf => {
                const dmabuf_surface = try self.dmabufSurface();
                const import = try DmabufImport.fromNativeSurface(dmabuf_surface);
                try client.createDmabufBuffer(import);
                try self.renderSoftwarePixels(buffers, resources);
                if (self.drm_buffer) |*buffer| {
                    const memory = try buffer.map();
                    packXrgb8888Strided(memory, buffer.pitch_bytes, self.width, self.height, self.pixels);
                }
                var dmabuf_sink_state = WaylandDmabufCommitSink{};
                const receipt = try renderer_native_present.renderGpuBackedAndSubmit(
                    dmabuf_surface,
                    buffers,
                    resources.presentationResources(),
                    self.gpu_buffer_device.device(),
                    .{
                        .primitives = self.gpu_primitives,
                        .gpu_tile_marks = &self.gpu_tile_marks,
                        .gpu_dirty_ids = &self.gpu_dirty_ids,
                        .native_tile_marks = &self.tile_marks,
                        .native_dirty_ids = &self.dirty_ids,
                    },
                    default_refresh_hz,
                    tile_width,
                    tile_height,
                    dmabuf_sink_state.sink(),
                );
                if (!receipt.gpuBackedValid() or !dmabuf_sink_state.submitted) return error.WaylandCommitRejected;
                if (receipt.gpu.rasterization != .cpu_filled_gpu_buffer) return error.InvalidGpuReceipt;
                try client.attachDmabufCommit(self.width, self.height);
                return;
            },
        }
        packXrgb8888(self.shm.memory, self.pixels);
        try client.attachCommit(self.width, self.height);
    }

    fn renderCursorOnly(self: *NativeApp, client: *WaylandClient, old_x: f32, old_y: f32, old_kind: app_cursor.Kind) !void {
        if (self.present != .cpu or !self.base_pixels_ready) return error.CursorOverlayUnavailable;
        const old_damage = cursorPixelRect(self.width, self.height, old_x, old_y, old_kind);
        const next_kind = app_cursor.fromState(.none, self.state.runtime.hoverKind());
        const next_damage = cursorPixelRect(self.width, self.height, self.state.hover_x, self.state.hover_y, next_kind);
        const damage = unionPixelRect(old_damage, next_damage) orelse return;
        self.restoreBasePixels(damage);
        self.cursor_damage = try self.renderCursorOverlay(next_kind);
        const final_damage = unionPixelRect(damage, self.cursor_damage) orelse damage;
        packXrgb8888Rect(self.shm.memory, self.shm.stride, self.width, self.height, self.pixels, final_damage);
        try client.attachCommitRect(final_damage);
    }

    fn renderCursorOverlay(self: *NativeApp, kind: app_cursor.Kind) !?PixelRect {
        const damage = cursorPixelRect(self.width, self.height, self.state.hover_x, self.state.hover_y, kind) orelse return null;
        var cursor_commands: [cursor_scene_budget]ui.Command = undefined;
        var scene = ui.Scene.init(&cursor_commands);
        try app_cursor.render(&scene, self.state.hover_x, self.state.hover_y, kind);
        var cursor_ir = renderer_ir.FixedBuffers(cursor_scene_budget, 0, cursor_overlay_icon_vertices, 0, 0, 0, 0){};
        const buffers = cursor_ir.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, .object, scene.written());
        const surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&self.font_atlas, null));
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
        return damage;
    }

    fn restoreBasePixels(self: *NativeApp, rect: PixelRect) void {
        var row: usize = 0;
        const width_usize: usize = self.width;
        while (row < rect.h) : (row += 1) {
            const start = (rect.y + row) * width_usize + rect.x;
            const end = start + rect.w;
            @memcpy(self.pixels[start..end], self.base_pixels[start..end]);
        }
    }

    fn waylandSurface(self: *const NativeApp) renderer_native_present.NativeSurface {
        return .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = self.width,
            .scale = 1,
        } };
    }

    fn dmabufSurface(self: *const NativeApp) !renderer_native_present.NativeSurface {
        const fd = if (self.dmabuf_fd) |fd| fd else if (self.drm_buffer) |buffer| buffer.dma_buf_fd else return error.MissingDmabufFd;
        const stride = if (self.drm_buffer) |buffer| try buffer.stridePixels() else self.width;
        if (fd < 0) return error.InvalidDmabufImport;
        return .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = dmabuf_wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = stride,
            .scale = 1,
            .format = .xrgb8888,
            .gpu_buffer = .{
                .kind = .dma_buf,
                .handle = @intCast(fd),
            },
        } };
    }

    fn renderSoftwarePixels(self: *NativeApp, buffers: renderer_ir.Buffers, resources: renderer_software.Resources) !void {
        const software_surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        software_surface.clear(appBackground());
        const receipt = try software_surface.renderIr(buffers, resources);
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
    }

    fn handleWaylandInput(self: *NativeApp, client: *WaylandClient, kind: ObjectKind, message: Message) !bool {
        if (kind != .pointer) return false;
        switch (message.opcode) {
            wl_pointer_enter_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                try client.sendHidePointerCursor(serial);
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[12..16], .little));
                self.updateHoverHit(self.regionSlice());
                return true;
            },
            wl_pointer_leave_event => {
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_kind = app_cursor.fromState(.none, self.state.runtime.hoverKind());
                self.state.hover_x = -1.0;
                self.state.hover_y = -1.0;
                self.state.runtime.clearHover();
                if (self.present == .cpu and self.base_pixels_ready) {
                    try self.renderCursorOnly(client, old_x, old_y, old_kind);
                    return false;
                }
                return true;
            },
            wl_pointer_motion_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_hit = self.state.runtime.hoverHitId();
                const old_kind = app_cursor.fromState(.none, self.state.runtime.hoverKind());
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[4..8], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                self.updateHoverHit(self.regionSlice());
                if (self.state.runtime.hoverHitId() != old_hit) return true;
                if (self.present == .cpu and self.base_pixels_ready) {
                    try self.renderCursorOnly(client, old_x, old_y, old_kind);
                    return false;
                }
                return @abs(self.state.hover_x - old_x) >= pointer_motion_render_step or
                    @abs(self.state.hover_y - old_y) >= pointer_motion_render_step;
            },
            wl_pointer_button_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                const button = std.mem.readInt(u32, message.payload[8..12], .little);
                const state = std.mem.readInt(u32, message.payload[12..16], .little);
                if (button == wl_pointer_button_left) {
                    if (state == wl_pointer_button_released) try self.activateHit(client);
                    if (state != wl_pointer_button_released and self.state.runtime.hoverHitId() == client_decor_drag_id) try client.sendMove(serial);
                }
                return true;
            },
            wl_pointer_axis_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const axis = std.mem.readInt(u32, message.payload[4..8], .little);
                const value = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                if (axis == wl_pointer_axis_vertical_scroll) self.scrollBy(value);
                return true;
            },
            else => return false,
        }
    }

    fn updateHoverHit(self: *NativeApp, regions: []const interaction.Region) void {
        self.state.runtime.refreshHover(regions, self.state.hover_x, self.state.hover_y);
    }

    fn regionSlice(self: *const NativeApp) []const interaction.Region {
        return self.regions[0..self.region_len];
    }

    fn activateHit(self: *NativeApp, client: *WaylandClient) !void {
        try activateHitForState(&self.state, client);
    }

    fn scrollBy(self: *NativeApp, delta_y: f32) void {
        scrollStateBy(&self.state, self.width, self.height, delta_y);
    }
};

fn updateHoverHitForState(state: *AppState, regions: []const interaction.Region) void {
    state.runtime.refreshHover(regions, state.hover_x, state.hover_y);
}

fn activateHitForState(state: *AppState, client: ?*WaylandClient) !void {
    const hover_hit_id = state.runtime.hoverHitId();
    switch (hover_hit_id) {
        client_decor_close_id => {
            state.runtime.clearHover();
            if (client) |value| value.state.closed = true;
            return;
        },
        client_decor_minimize_id => {
            if (client) |value| try value.sendMinimize();
            return;
        },
        else => {},
    }
    if (app_navigation.fromHit(hover_hit_id, state.route)) |route| {
        state.route = route;
        state.scroll_y = 0.0;
        return;
    }
    if (app_navigation.actionFromHit(hover_hit_id)) |action| switch (action) {
        .reveal_identity => {
            state.public_identity_ready = true;
            state.public_identity = "native-wayland";
        },
        .compile_source,
        .download_source_release,
        .launch_source_release,
        .reset_source,
        .open_context_source,
        => {},
    };
}

fn scrollStateBy(state: *AppState, width: u32, height: u32, delta_y: f32) void {
    if (!std.math.isFinite(delta_y)) return;
    const viewport_h = @max(1.0, @as(f32, @floatFromInt(height)) - client_decor_h);
    const limit = @max(0.0, contentHeightForRoute(@floatFromInt(width), state.route) - viewport_h);
    state.scroll_y = std.math.clamp(state.scroll_y + delta_y, 0.0, limit);
}

const WaylandCommitSink = struct {
    submitted: bool = false,

    fn sink(self: *WaylandCommitSink) renderer_native_present.Sink {
        return .{ .context = self, .submit_wayland = submit };
    }

    fn submit(context: *anyopaque, commit: renderer_native_present.WaylandCommit) bool {
        const self: *WaylandCommitSink = @ptrCast(@alignCast(context));
        self.submitted = commit.surface_id == surface_id and commit.buffer_id == wl_buffer_id and commit.dirty_tiles.len != 0;
        return self.submitted;
    }
};

const WaylandDmabufCommitSink = struct {
    submitted: bool = false,

    fn sink(self: *WaylandDmabufCommitSink) renderer_native_present.Sink {
        return .{ .context = self, .submit_wayland = submit };
    }

    fn submit(context: *anyopaque, commit: renderer_native_present.WaylandCommit) bool {
        const self: *WaylandDmabufCommitSink = @ptrCast(@alignCast(context));
        self.submitted = commit.surface_id == surface_id and commit.buffer_id == dmabuf_wl_buffer_id and commit.dirty_tiles.len != 0;
        return self.submitted;
    }
};

const GpuRecorder = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,

    fn device(self: *GpuRecorder) renderer_gpu.Device {
        return .{
            .context = self,
            .begin_frame = beginFrame,
            .upload_primitives = uploadPrimitives,
            .render_tiles = renderTiles,
            .present = present,
        };
    }

    fn beginFrame(context: *anyopaque, frame: renderer_gpu.Frame) bool {
        const self: *GpuRecorder = @ptrCast(@alignCast(context));
        if (frame.sequence == 0 or frame.primitives.len == 0) return false;
        self.began += 1;
        return true;
    }

    fn uploadPrimitives(context: *anyopaque, primitives: []const renderer_gpu.Primitive) bool {
        const self: *GpuRecorder = @ptrCast(@alignCast(context));
        if (primitives.len == 0) return false;
        self.uploaded += primitives.len;
        return true;
    }

    fn renderTiles(context: *anyopaque, dirty_tiles: []const u32) bool {
        const self: *GpuRecorder = @ptrCast(@alignCast(context));
        if (dirty_tiles.len == 0) return false;
        self.rendered += dirty_tiles.len;
        return true;
    }

    fn present(context: *anyopaque, sequence: u64) bool {
        const self: *GpuRecorder = @ptrCast(@alignCast(context));
        if (sequence == 0) return false;
        self.presented += 1;
        self.last_sequence = sequence;
        return true;
    }
};

fn renderNativeAppScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, state: AppState) !void {
    try renderClientDecoration(scene, collector, @floatFromInt(width));
    const content_y = client_decor_h;
    const content_h = @max(1.0, @as(f32, @floatFromInt(height)) - content_y);
    const bounds = ui.Rect.init(0, content_y, @floatFromInt(width), content_h);
    try app_frame.render(scene, collector, bounds, .{
        .route = state.route,
        .scroll_y = state.scroll_y,
        .hover_x = state.hover_x,
        .hover_y = state.hover_y,
        .public_identity = state.public_identity,
        .public_identity_ready = state.public_identity_ready,
    });
}

fn renderClientDecoration(scene: *ui.Scene, collector: *interaction.Collector, width: f32) !void {
    const bounds = ui.Rect.init(0.0, 0.0, width, client_decor_h);
    try scene.pushRect(bounds, client_decor_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(0.0, client_decor_h - 1.0, width, 1.0), client_decor_border, .fill, 0.0, 0.0);
    try scene.pushAlignedText(ui.Rect.init(14.0, 8.0, @max(1.0, width - 168.0), 15.0), "EdgeRun Native", client_decor_text, .start);

    const close = clientDecorButton(width, 0);
    const minimize = clientDecorButton(width, 1);
    try scene.pushRect(minimize, client_decor_border, .border, 12.0, 0.0);
    try scene.pushRect(centeredRect(minimize, client_decor_minimize_w, client_decor_minimize_h), client_decor_dim, .fill, 1.0, 0.0);
    try collector.addHit(minimize, .button, client_decor_minimize_id);

    try scene.pushRect(close, client_decor_border, .border, 12.0, 0.0);
    try scene.pushIconQuad(.{
        .bounds = centeredRect(close, client_decor_icon_size, client_decor_icon_size),
        .icon_id = icon.id(.x),
        .color = client_decor_dim,
    });
    try collector.addHit(close, .button, client_decor_close_id);

    const drag_w = @max(1.0, minimize.x - client_decor_button_gap - 140.0);
    try collector.addHit(ui.Rect.init(0.0, 0.0, drag_w, client_decor_h), .button, client_decor_drag_id);
}

fn clientDecorButton(width: f32, index: usize) ui.Rect {
    const offset = @as(f32, @floatFromInt(index + 1)) * (client_decor_button_size + client_decor_button_gap);
    return ui.Rect.init(width - offset, 5.0, client_decor_button_size, client_decor_button_size);
}

fn centeredRect(bounds: ui.Rect, w: f32, h: f32) ui.Rect {
    return ui.Rect.init(
        bounds.x + (bounds.w - w) * 0.5,
        bounds.y + (bounds.h - h) * 0.5,
        w,
        h,
    );
}

fn contentHeightForRoute(width: f32, route: app_navigation.Route) f32 {
    return app_frame.contentHeight(width, .{ .route = route });
}

fn appBackground() ui.Color {
    return .{ .r = 11, .g = 11, .b = 11 };
}

fn packXrgb8888(out: []u8, pixels: []const ui.Color) void {
    packXrgb8888Strided(out, @intCast(pixels.len * @sizeOf(u32)), @intCast(pixels.len), 1, pixels);
}

fn packXrgb8888Rect(out: []u8, stride_bytes: u32, width: u32, height: u32, pixels: []const ui.Color, rect: PixelRect) void {
    if (!rect.valid()) return;
    const width_usize: usize = width;
    const height_usize: usize = height;
    if (rect.x >= width_usize or rect.y >= height_usize) return;
    const x_end = @min(width_usize, rect.x + rect.w);
    const y_end = @min(height_usize, rect.y + rect.h);
    var y = rect.y;
    while (y < y_end) : (y += 1) {
        const pixel_row = y * width_usize;
        const byte_row = y * stride_bytes;
        var x = rect.x;
        while (x < x_end) : (x += 1) {
            const pixel = pixels[pixel_row + x];
            const base = byte_row + x * @sizeOf(u32);
            out[base + 0] = pixel.b;
            out[base + 1] = pixel.g;
            out[base + 2] = pixel.r;
            out[base + 3] = 255;
        }
    }
}

fn packXrgb8888Strided(out: []u8, stride_bytes: u32, width: u32, height: u32, pixels: []const ui.Color) void {
    const row_bytes = @as(usize, width) * @sizeOf(u32);
    for (0..height) |y| {
        const out_row = @as(usize, y) * stride_bytes;
        const pixel_row = @as(usize, y) * width;
        for (pixels[pixel_row .. pixel_row + width], 0..) |pixel, x| {
            const base = out_row + x * @sizeOf(u32);
            out[base + 0] = pixel.b;
            out[base + 1] = pixel.g;
            out[base + 2] = pixel.r;
            out[base + 3] = 255;
        }
        if (stride_bytes > row_bytes) @memset(out[out_row + row_bytes .. out_row + stride_bytes], 0);
    }
}

fn cursorPixelRect(width: u32, height: u32, x: f32, y: f32, kind: app_cursor.Kind) ?PixelRect {
    const bounds = app_cursor.damageBounds(x, y, kind) orelse return null;
    return clampPixelRect(width, height, bounds);
}

fn clampPixelRect(width: u32, height: u32, bounds: ui.Rect) ?PixelRect {
    const max_w: i32 = @intCast(width);
    const max_h: i32 = @intCast(height);
    const x0 = std.math.clamp(@as(i32, @intFromFloat(@floor(bounds.x))), 0, max_w);
    const y0 = std.math.clamp(@as(i32, @intFromFloat(@floor(bounds.y))), 0, max_h);
    const x1 = std.math.clamp(@as(i32, @intFromFloat(@ceil(bounds.x + bounds.w))), 0, max_w);
    const y1 = std.math.clamp(@as(i32, @intFromFloat(@ceil(bounds.y + bounds.h))), 0, max_h);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{
        .x = @intCast(x0),
        .y = @intCast(y0),
        .w = @intCast(x1 - x0),
        .h = @intCast(y1 - y0),
    };
}

fn unionPixelRect(a: ?PixelRect, b: ?PixelRect) ?PixelRect {
    if (a == null) return b;
    if (b == null) return a;
    const left = @min(a.?.x, b.?.x);
    const top = @min(a.?.y, b.?.y);
    const right = @max(a.?.x + a.?.w, b.?.x + b.?.w);
    const bottom = @max(a.?.y + a.?.h, b.?.y + b.?.h);
    return .{ .x = left, .y = top, .w = right - left, .h = bottom - top };
}

fn fixedToFloat(value: i32) f32 {
    return @as(f32, @floatFromInt(value)) / fixed_scale;
}

fn makeGetRegistry(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, display_id, wl_display_get_registry);
    try msg.putU32(registry_id);
    return msg.finish();
}

fn makeSync(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, display_id, wl_display_sync);
    try msg.putU32(sync_callback_id);
    return msg.finish();
}

fn makeBind(buffer: []u8, name: u32, interface: []const u8, version: u32, new_id: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, registry_id, wl_registry_bind);
    try msg.putU32(name);
    try msg.putString(interface);
    try msg.putU32(version);
    try msg.putU32(new_id);
    return msg.finish();
}

fn makeCreateSurface(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, compositor_id, wl_compositor_create_surface);
    try msg.putU32(surface_id);
    return msg.finish();
}

fn makeGetPointer(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, seat_id, wl_seat_get_pointer);
    try msg.putU32(pointer_id);
    return msg.finish();
}

fn makeHidePointerCursor(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, pointer_id, wl_pointer_set_cursor);
    try msg.putU32(serial);
    try msg.putU32(0);
    try msg.putI32(0);
    try msg.putI32(0);
    return msg.finish();
}

fn makeCreatePool(buffer: []u8, bytes: i32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, shm_id, wl_shm_create_pool);
    try msg.putU32(shm_pool_id);
    try msg.putI32(bytes);
    return msg.finish();
}

fn makeCreateBuffer(buffer: []u8, width: u32, height: u32, stride: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, shm_pool_id, wl_shm_pool_create_buffer);
    try msg.putU32(wl_buffer_id);
    try msg.putI32(0);
    try msg.putI32(@intCast(width));
    try msg.putI32(@intCast(height));
    try msg.putI32(@intCast(stride));
    try msg.putU32(wl_shm_format_xrgb8888);
    return msg.finish();
}

fn makeDestroyPool(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, shm_pool_id, wl_shm_pool_destroy);
    return msg.finish();
}

fn makeDmabufCreateParams(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, linux_dmabuf_id, zwp_linux_dmabuf_create_params);
    try msg.putU32(dmabuf_params_id);
    return msg.finish();
}

fn makeDmabufAddPlane(buffer: []u8, plane_index: u32, offset: u32, stride: u32, modifier: u64) ![]const u8 {
    var msg = try MessageWriter.init(buffer, dmabuf_params_id, zwp_linux_buffer_params_add);
    try msg.putU32(plane_index);
    try msg.putU32(offset);
    try msg.putU32(stride);
    try msg.putU32(@intCast(modifier >> 32));
    try msg.putU32(@truncate(modifier));
    return msg.finish();
}

fn makeDmabufCreateImmediate(buffer: []u8, width: u32, height: u32, format: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, dmabuf_params_id, zwp_linux_buffer_params_create_immed);
    try msg.putU32(dmabuf_wl_buffer_id);
    try msg.putI32(@intCast(width));
    try msg.putI32(@intCast(height));
    try msg.putU32(format);
    try msg.putU32(dmabuf_flags_none);
    return msg.finish();
}

fn makeGetXdgSurface(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, wm_base_id, xdg_wm_base_get_xdg_surface);
    try msg.putU32(xdg_surface_id);
    try msg.putU32(surface_id);
    return msg.finish();
}

fn makeGetToplevel(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_surface_id, xdg_surface_get_toplevel);
    try msg.putU32(xdg_toplevel_id);
    return msg.finish();
}

fn makeSetTitle(buffer: []u8, title: []const u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_toplevel_id, xdg_toplevel_set_title);
    try msg.putString(title);
    return msg.finish();
}

fn makeSetAppId(buffer: []u8, app_id: []const u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_toplevel_id, xdg_toplevel_set_app_id);
    try msg.putString(app_id);
    return msg.finish();
}

fn makeMove(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_toplevel_id, xdg_toplevel_move);
    try msg.putU32(seat_id);
    try msg.putU32(serial);
    return msg.finish();
}

fn makeSetMinimized(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_toplevel_id, xdg_toplevel_set_minimized);
    return msg.finish();
}

fn makeGetToplevelDecoration(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_decoration_manager_id, xdg_decoration_manager_get_toplevel_decoration);
    try msg.putU32(xdg_toplevel_decoration_id);
    try msg.putU32(xdg_toplevel_id);
    return msg.finish();
}

fn makeSetServerSideDecoration(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_toplevel_decoration_id, xdg_toplevel_decoration_set_mode);
    try msg.putU32(xdg_toplevel_decoration_mode_server_side);
    return msg.finish();
}

fn makeSurfaceCommit(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, surface_id, wl_surface_commit);
    return msg.finish();
}

fn makeAttach(buffer: []u8, buffer_id: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, surface_id, wl_surface_attach);
    try msg.putU32(buffer_id);
    try msg.putI32(0);
    try msg.putI32(0);
    return msg.finish();
}

fn makeDamageBuffer(buffer: []u8, width: u32, height: u32) ![]const u8 {
    return makeDamageBufferRect(buffer, .{ .x = 0, .y = 0, .w = width, .h = height });
}

fn makeDamageBufferRect(buffer: []u8, rect: PixelRect) ![]const u8 {
    var msg = try MessageWriter.init(buffer, surface_id, wl_surface_damage_buffer);
    try msg.putI32(@intCast(rect.x));
    try msg.putI32(@intCast(rect.y));
    try msg.putI32(@intCast(rect.w));
    try msg.putI32(@intCast(rect.h));
    return msg.finish();
}

fn makePong(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, wm_base_id, xdg_wm_base_pong);
    try msg.putU32(serial);
    return msg.finish();
}

fn makeAckConfigure(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try MessageWriter.init(buffer, xdg_surface_id, xdg_surface_ack_configure);
    try msg.putU32(serial);
    return msg.finish();
}

fn nextMessage(buffer: []const u8) ?Message {
    if (buffer.len < 8) return null;
    const object_id = std.mem.readInt(u32, buffer[0..4], .little);
    const opcode = std.mem.readInt(u16, buffer[4..6], .little);
    const size = std.mem.readInt(u16, buffer[6..8], .little);
    if (size < 8 or size > buffer.len) return null;
    return .{ .object_id = object_id, .opcode = opcode, .payload = buffer[8..size] };
}

fn handleMessage(state: *WaylandState, kind: ObjectKind, message: Message) !void {
    switch (kind) {
        .display => if (message.opcode == wl_display_error_event) return error.WaylandProtocolError,
        .registry => if (message.opcode == wl_registry_global_event) {
            const global = try parseRegistryGlobal(message.payload);
            try state.registry.add(global);
        },
        .callback => {
            if (message.opcode == wl_callback_done_event) state.registry_done = true;
        },
        .wm_base => if (message.opcode == xdg_wm_base_ping_event) {},
        .xdg_surface => {
            if (message.opcode == xdg_surface_configure_event) state.configured = true;
        },
        .xdg_toplevel => {
            if (message.opcode == xdg_toplevel_close_event) state.closed = true;
        },
        .seat => {
            if (message.opcode == wl_seat_capabilities_event) {
                if (message.payload.len < 4) return error.InvalidWaylandMessage;
                const capabilities = std.mem.readInt(u32, message.payload[0..4], .little);
                state.seat_has_pointer = (capabilities & wl_seat_capability_pointer) != 0;
            }
        },
        else => {},
    }
}

fn parseRegistryGlobal(payload: []const u8) !RegistryGlobal {
    if (payload.len < 12) return error.InvalidWaylandMessage;
    const name = std.mem.readInt(u32, payload[0..4], .little);
    const string_len = std.mem.readInt(u32, payload[4..8], .little);
    if (string_len == 0) return error.InvalidWaylandMessage;
    const padded = paddedLen(string_len);
    if (payload.len < 8 + padded + 4) return error.InvalidWaylandMessage;
    const interface_name = payload[8 .. 8 + string_len - 1];
    const version = std.mem.readInt(u32, payload[8 + padded ..][0..4], .little);
    return .{ .name = name, .interface = registryInterface(interface_name), .version = version };
}

fn registryInterface(value: []const u8) RegistryInterface {
    if (std.mem.eql(u8, value, "wl_compositor")) return .compositor;
    if (std.mem.eql(u8, value, "wl_shm")) return .shm;
    if (std.mem.eql(u8, value, "xdg_wm_base")) return .wm_base;
    if (std.mem.eql(u8, value, "wl_seat")) return .seat;
    if (std.mem.eql(u8, value, "zwp_linux_dmabuf_v1")) return .linux_dmabuf;
    if (std.mem.eql(u8, value, "zxdg_decoration_manager_v1")) return .xdg_decoration_manager;
    return .other;
}

fn isSupportedDmabufFormat(format: u32) bool {
    return switch (format) {
        drm_format_xrgb8888,
        drm_format_argb8888,
        => true,
        else => false,
    };
}

fn dmabufFormat(format: renderer_native_present.PixelFormat) u32 {
    return switch (format) {
        .xrgb8888 => drm_format_xrgb8888,
        .argb8888 => drm_format_argb8888,
    };
}

fn paddedLen(len: u32) usize {
    return (@as(usize, len) + 3) & ~@as(usize, 3);
}

fn writeAll(fd: posix.fd_t, bytes: []const u8) !void {
    var written: usize = 0;
    while (written < bytes.len) {
        const rc = linux.write(fd, bytes[written..].ptr, bytes.len - written);
        switch (posix.errno(rc)) {
            .SUCCESS => written += @intCast(rc),
            .INTR => {},
            .AGAIN => return error.WouldBlock,
            .PIPE => return error.WaylandConnectionClosed,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn sendFd(socket_fd: posix.fd_t, bytes: []const u8, fd: posix.fd_t) !void {
    var iov = [_]posix.iovec_const{.{ .base = bytes.ptr, .len = bytes.len }};
    var control: [cmsgSpace(@sizeOf(posix.fd_t))]u8 align(@alignOf(linux.cmsghdr)) = undefined;
    @memset(&control, 0);
    const header: *linux.cmsghdr = @ptrCast(@alignCast(&control));
    header.* = .{
        .len = cmsgLen(@sizeOf(posix.fd_t)),
        .level = linux.SOL.SOCKET,
        .type = linux.SCM.RIGHTS,
    };
    const data = control[cmsgAlign(@sizeOf(linux.cmsghdr))..][0..@sizeOf(posix.fd_t)];
    std.mem.writeInt(posix.fd_t, data, fd, .native);
    const msg = linux.msghdr_const{
        .name = null,
        .namelen = 0,
        .iov = &iov,
        .iovlen = iov.len,
        .control = &control,
        .controllen = control.len,
        .flags = 0,
    };
    const rc = linux.sendmsg(socket_fd, &msg, 0);
    switch (posix.errno(rc)) {
        .SUCCESS => if (rc != bytes.len) return error.ShortWaylandWrite,
        .INTR => return error.ShortWaylandWrite,
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn truncateFd(fd: posix.fd_t, size: usize) !void {
    const rc = linux.ftruncate(fd, @intCast(size));
    switch (posix.errno(rc)) {
        .SUCCESS => {},
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn closeFd(fd: posix.fd_t) void {
    switch (posix.errno(linux.close(fd))) {
        .SUCCESS => {},
        .INTR => {},
        else => {},
    }
}

fn cmsgAlign(len: usize) usize {
    const mask: usize = @sizeOf(usize) - 1;
    return (len + mask) & ~mask;
}

fn cmsgLen(len: usize) usize {
    return cmsgAlign(@sizeOf(linux.cmsghdr)) + len;
}

fn cmsgSpace(len: usize) usize {
    return cmsgAlign(@sizeOf(linux.cmsghdr)) + cmsgAlign(len);
}

test "wayland bind message encodes registry name interface version and new id" {
    var buffer: [128]u8 = undefined;
    const bytes = try makeBind(&buffer, 17, "wl_compositor", 4, compositor_id);
    try std.testing.expectEqual(@as(u32, registry_id), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_registry_bind), std.mem.readInt(u16, bytes[4..6], .little));
    try std.testing.expectEqual(@as(u16, 40), std.mem.readInt(u16, bytes[6..8], .little));
    try std.testing.expectEqual(@as(u32, 17), std.mem.readInt(u32, bytes[8..12], .little));
    try std.testing.expectEqual(@as(u32, 14), std.mem.readInt(u32, bytes[12..16], .little));
    try std.testing.expectEqualStrings("wl_compositor", bytes[16..29]);
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, bytes[32..36], .little));
    try std.testing.expectEqual(@as(u32, compositor_id), std.mem.readInt(u32, bytes[36..40], .little));
}

test "wayland host parses explicit presentation mode" {
    try std.testing.expectEqual(PresentMode.cpu, try parsePresentMode("cpu"));
    try std.testing.expectEqual(PresentMode.gpu_record, try parsePresentMode("gpu-record"));
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, try parsePresentMode("gpu-dmabuf"));
    try std.testing.expectError(error.InvalidArguments, parsePresentMode("gpu"));

    const args = [_][:0]const u8{ "wayland-window", "--width", "800", "--height", "600", "--seconds", "1", "--present", "gpu-record", "--path", "/academy" };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(@as(u32, 800), options.width);
    try std.testing.expectEqual(@as(u32, 600), options.height);
    try std.testing.expectEqual(@as(u32, 1), options.seconds);
    try std.testing.expectEqual(PresentMode.gpu_record, options.present);
    try std.testing.expectEqualStrings("/academy", options.path);

    const dmabuf_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf", "--dmabuf-fd", "17" };
    const dmabuf_options = try parseOptions(&dmabuf_args);
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, dmabuf_options.present);
    try std.testing.expectEqual(@as(posix.fd_t, 17), dmabuf_options.dmabuf_fd.?);

    const allocated_dmabuf_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf", "--drm-device", "/dev/dri/card1" };
    const allocated_dmabuf_options = try parseOptions(&allocated_dmabuf_args);
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, allocated_dmabuf_options.present);
    try std.testing.expectEqualStrings("/dev/dri/card1", allocated_dmabuf_options.drm_device);
    try std.testing.expect(allocated_dmabuf_options.dmabuf_fd == null);
}

test "wayland registry global parser keeps interface slice and version" {
    var payload: [32]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 11, .little);
    std.mem.writeInt(u32, payload[4..8], 7, .little);
    @memcpy(payload[8..14], "wl_shm");
    payload[14] = 0;
    payload[15] = 0;
    std.mem.writeInt(u32, payload[16..20], 1, .little);
    const global = try parseRegistryGlobal(payload[0..20]);
    try std.testing.expectEqual(@as(u32, 11), global.name);
    try std.testing.expectEqual(RegistryInterface.shm, global.interface);
    try std.testing.expectEqual(@as(u32, 1), global.version);
}

test "wayland registry parser discovers linux dmabuf global" {
    var payload: [48]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 23, .little);
    std.mem.writeInt(u32, payload[4..8], 20, .little);
    @memcpy(payload[8..27], "zwp_linux_dmabuf_v1");
    payload[27] = 0;
    std.mem.writeInt(u32, payload[28..32], 4, .little);
    const global = try parseRegistryGlobal(payload[0..32]);
    try std.testing.expectEqual(@as(u32, 23), global.name);
    try std.testing.expectEqual(RegistryInterface.linux_dmabuf, global.interface);
    try std.testing.expectEqual(@as(u32, 4), global.version);
}

test "wayland registry parser discovers xdg decoration manager global" {
    var payload: [48]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 31, .little);
    std.mem.writeInt(u32, payload[4..8], 27, .little);
    @memcpy(payload[8..34], "zxdg_decoration_manager_v1");
    payload[34] = 0;
    payload[35] = 0;
    std.mem.writeInt(u32, payload[36..40], 1, .little);
    const global = try parseRegistryGlobal(payload[0..40]);
    try std.testing.expectEqual(@as(u32, 31), global.name);
    try std.testing.expectEqual(RegistryInterface.xdg_decoration_manager, global.interface);
    try std.testing.expectEqual(@as(u32, 1), global.version);
}

test "wayland xdg decoration message encoders stay explicit but unused by client chrome" {
    var get_buffer: [64]u8 = undefined;
    const get = try makeGetToplevelDecoration(&get_buffer);
    try std.testing.expectEqual(@as(u32, xdg_decoration_manager_id), std.mem.readInt(u32, get[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_decoration_manager_get_toplevel_decoration), std.mem.readInt(u16, get[4..6], .little));
    try std.testing.expectEqual(@as(u16, 16), std.mem.readInt(u16, get[6..8], .little));
    try std.testing.expectEqual(@as(u32, xdg_toplevel_decoration_id), std.mem.readInt(u32, get[8..12], .little));
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, get[12..16], .little));

    var mode_buffer: [64]u8 = undefined;
    const mode = try makeSetServerSideDecoration(&mode_buffer);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_decoration_id), std.mem.readInt(u32, mode[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_decoration_set_mode), std.mem.readInt(u16, mode[4..6], .little));
    try std.testing.expectEqual(@as(u16, 12), std.mem.readInt(u16, mode[6..8], .little));
    try std.testing.expectEqual(xdg_toplevel_decoration_mode_server_side, std.mem.readInt(u32, mode[8..12], .little));
}

test "wayland xdg toplevel client chrome messages encode move and minimize" {
    var move_buffer: [64]u8 = undefined;
    const move = try makeMove(&move_buffer, 77);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, move[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_move), std.mem.readInt(u16, move[4..6], .little));
    try std.testing.expectEqual(@as(u16, 16), std.mem.readInt(u16, move[6..8], .little));
    try std.testing.expectEqual(@as(u32, seat_id), std.mem.readInt(u32, move[8..12], .little));
    try std.testing.expectEqual(@as(u32, 77), std.mem.readInt(u32, move[12..16], .little));

    var minimize_buffer: [64]u8 = undefined;
    const minimize = try makeSetMinimized(&minimize_buffer);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, minimize[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_set_minimized), std.mem.readInt(u16, minimize[4..6], .little));
    try std.testing.expectEqual(@as(u16, 8), std.mem.readInt(u16, minimize[6..8], .little));
}

test "wayland pointer cursor message hides native compositor cursor" {
    var buffer: [64]u8 = undefined;
    const serial: u32 = 91;
    const message = try makeHidePointerCursor(&buffer, serial);

    try std.testing.expectEqual(@as(u32, pointer_id), std.mem.readInt(u32, message[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_pointer_set_cursor), std.mem.readInt(u16, message[4..6], .little));
    try std.testing.expectEqual(@as(u16, 24), std.mem.readInt(u16, message[6..8], .little));
    try std.testing.expectEqual(serial, std.mem.readInt(u32, message[8..12], .little));
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, message[12..16], .little));
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, message[16..20], .little));
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, message[20..24], .little));
}

test "wayland dmabuf messages encode params add and immediate buffer creation" {
    var create_params_buffer: [64]u8 = undefined;
    const create_params = try makeDmabufCreateParams(&create_params_buffer);
    try std.testing.expectEqual(@as(u32, linux_dmabuf_id), std.mem.readInt(u32, create_params[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_dmabuf_create_params), std.mem.readInt(u16, create_params[4..6], .little));
    try std.testing.expectEqual(@as(u16, 12), std.mem.readInt(u16, create_params[6..8], .little));
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, create_params[8..12], .little));

    var add_buffer: [64]u8 = undefined;
    const modifier: u64 = 0x1122334455667788;
    const add = try makeDmabufAddPlane(&add_buffer, 2, 128, 4096, modifier);
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, add[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_buffer_params_add), std.mem.readInt(u16, add[4..6], .little));
    try std.testing.expectEqual(@as(u16, 28), std.mem.readInt(u16, add[6..8], .little));
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, add[8..12], .little));
    try std.testing.expectEqual(@as(u32, 128), std.mem.readInt(u32, add[12..16], .little));
    try std.testing.expectEqual(@as(u32, 4096), std.mem.readInt(u32, add[16..20], .little));
    try std.testing.expectEqual(@as(u32, 0x11223344), std.mem.readInt(u32, add[20..24], .little));
    try std.testing.expectEqual(@as(u32, 0x55667788), std.mem.readInt(u32, add[24..28], .little));

    var create_immed_buffer: [64]u8 = undefined;
    const create_immed = try makeDmabufCreateImmediate(&create_immed_buffer, 1280, 800, drm_format_xrgb8888);
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, create_immed[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_buffer_params_create_immed), std.mem.readInt(u16, create_immed[4..6], .little));
    try std.testing.expectEqual(@as(u16, 28), std.mem.readInt(u16, create_immed[6..8], .little));
    try std.testing.expectEqual(@as(u32, dmabuf_wl_buffer_id), std.mem.readInt(u32, create_immed[8..12], .little));
    try std.testing.expectEqual(@as(u32, 1280), std.mem.readInt(u32, create_immed[12..16], .little));
    try std.testing.expectEqual(@as(u32, 800), std.mem.readInt(u32, create_immed[16..20], .little));
    try std.testing.expectEqual(drm_format_xrgb8888, std.mem.readInt(u32, create_immed[20..24], .little));
    try std.testing.expectEqual(dmabuf_flags_none, std.mem.readInt(u32, create_immed[24..28], .little));
}

test "wayland dmabuf import validates fd dimensions stride and format" {
    try std.testing.expect((DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
    }).valid());
    try std.testing.expect((DmabufImport{
        .fd = 4,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
        .format = drm_format_argb8888,
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = -1,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 63 * @sizeOf(u32),
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
        .format = 0,
    }).valid());
}

test "wayland dmabuf import derives from gpu backed native wayland surface" {
    const import = try DmabufImport.fromNativeSurface(.{ .wayland = .{
        .surface_id = surface_id,
        .buffer_id = dmabuf_wl_buffer_id,
        .width = 320,
        .height = 240,
        .stride = 320,
        .format = .argb8888,
        .gpu_buffer = .{
            .kind = .dma_buf,
            .handle = 7,
            .offset = 128,
            .modifier = 0x0102030405060708,
        },
    } });
    try std.testing.expectEqual(@as(posix.fd_t, 7), import.fd);
    try std.testing.expectEqual(@as(u32, 320), import.width);
    try std.testing.expectEqual(@as(u32, 240), import.height);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);
    try std.testing.expectEqual(drm_format_argb8888, import.format);
    try std.testing.expectEqual(@as(u32, 128), import.offset);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), import.modifier);

    try std.testing.expectError(error.InvalidDmabufImport, DmabufImport.fromNativeSurface(.{ .wayland = .{
        .surface_id = surface_id,
        .buffer_id = dmabuf_wl_buffer_id,
        .width = 320,
        .height = 240,
        .stride = 320,
        .gpu_buffer = .{ .kind = .scanout, .handle = 9 },
    } }));
    try std.testing.expectError(error.UnsupportedDmabufSurface, DmabufImport.fromNativeSurface(.{ .drm = .{
        .framebuffer_id = 1,
        .connector_id = 2,
        .crtc_id = 3,
        .width = 320,
        .height = 240,
        .stride = 320,
        .gpu_buffer = .{ .kind = .dma_buf, .handle = 11 },
    } }));
}

test "wayland native app builds dmabuf surface only in explicit fd mode" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 320,
        .height = 240,
        .present = .gpu_dmabuf,
        .dmabuf_fd = 19,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body()),
        .gpu_primitives = &.{},
    };
    const surface = try app.dmabufSurface();
    const import = try DmabufImport.fromNativeSurface(surface);
    try std.testing.expectEqual(@as(posix.fd_t, 19), import.fd);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);

    app.dmabuf_fd = null;
    try std.testing.expectError(error.MissingDmabufFd, app.dmabufSurface());
}

test "wayland native app builds dmabuf surface from owned drm buffer" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 320,
        .height = 240,
        .present = .gpu_dmabuf,
        .dmabuf_fd = null,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body()),
        .gpu_primitives = &.{},
        .drm_buffer = .{
            .drm_fd = 18,
            .dma_buf_fd = 19,
            .handle = 20,
            .width = 320,
            .height = 240,
            .pitch_bytes = 320 * @sizeOf(u32),
            .size = 320 * 240 * @sizeOf(u32),
        },
    };
    const surface = try app.dmabufSurface();
    const import = try DmabufImport.fromNativeSurface(surface);
    try std.testing.expectEqual(@as(posix.fd_t, 19), import.fd);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);
}

test "wayland attach message can target shm or dmabuf buffers" {
    var shm_buffer: [32]u8 = undefined;
    const shm = try makeAttach(&shm_buffer, wl_buffer_id);
    try std.testing.expectEqual(@as(u32, surface_id), std.mem.readInt(u32, shm[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_surface_attach), std.mem.readInt(u16, shm[4..6], .little));
    try std.testing.expectEqual(@as(u16, 20), std.mem.readInt(u16, shm[6..8], .little));
    try std.testing.expectEqual(@as(u32, wl_buffer_id), std.mem.readInt(u32, shm[8..12], .little));

    var dmabuf_buffer: [32]u8 = undefined;
    const dmabuf = try makeAttach(&dmabuf_buffer, dmabuf_wl_buffer_id);
    try std.testing.expectEqual(@as(u32, dmabuf_wl_buffer_id), std.mem.readInt(u32, dmabuf[8..12], .little));
}

test "wayland damage message can target only cursor rectangle" {
    var buffer: [32]u8 = undefined;
    const damage = try makeDamageBufferRect(&buffer, .{ .x = 3, .y = 5, .w = 7, .h = 11 });
    try std.testing.expectEqual(@as(u32, surface_id), std.mem.readInt(u32, damage[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_surface_damage_buffer), std.mem.readInt(u16, damage[4..6], .little));
    try std.testing.expectEqual(@as(u16, 24), std.mem.readInt(u16, damage[6..8], .little));
    try std.testing.expectEqual(@as(i32, 3), std.mem.readInt(i32, damage[8..12], .little));
    try std.testing.expectEqual(@as(i32, 5), std.mem.readInt(i32, damage[12..16], .little));
    try std.testing.expectEqual(@as(i32, 7), std.mem.readInt(i32, damage[16..20], .little));
    try std.testing.expectEqual(@as(i32, 11), std.mem.readInt(i32, damage[20..24], .little));
}

test "wayland xdg configure event marks window configured" {
    var payload: [4]u8 = undefined;
    std.mem.writeInt(u32, &payload, 99, .little);
    var state = WaylandState{};
    try handleMessage(&state, .xdg_surface, .{
        .object_id = xdg_surface_id,
        .opcode = xdg_surface_configure_event,
        .payload = &payload,
    });
    try std.testing.expect(state.configured);
}

test "wayland xrgb pack swaps renderer color channels for shm" {
    var out: [8]u8 = undefined;
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = 4 },
        .{ .r = 5, .g = 6, .b = 7, .a = 8 },
    };
    packXrgb8888(&out, &pixels);
    try std.testing.expectEqualSlices(u8, &.{ 3, 2, 1, 255, 7, 6, 5, 255 }, &out);
}

test "wayland xrgb rect pack updates only cursor damage bytes" {
    var out = [_]u8{0xaa} ** (4 * 4 * @sizeOf(u32));
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3 },    .{ .r = 4, .g = 5, .b = 6 },    .{ .r = 7, .g = 8, .b = 9 },    .{ .r = 10, .g = 11, .b = 12 },
        .{ .r = 13, .g = 14, .b = 15 }, .{ .r = 16, .g = 17, .b = 18 }, .{ .r = 19, .g = 20, .b = 21 }, .{ .r = 22, .g = 23, .b = 24 },
        .{ .r = 25, .g = 26, .b = 27 }, .{ .r = 28, .g = 29, .b = 30 }, .{ .r = 31, .g = 32, .b = 33 }, .{ .r = 34, .g = 35, .b = 36 },
        .{ .r = 37, .g = 38, .b = 39 }, .{ .r = 40, .g = 41, .b = 42 }, .{ .r = 43, .g = 44, .b = 45 }, .{ .r = 46, .g = 47, .b = 48 },
    };

    packXrgb8888Rect(&out, 4 * @sizeOf(u32), 4, 4, &pixels, .{ .x = 1, .y = 1, .w = 2, .h = 2 });

    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa }, out[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 18, 17, 16, 255 }, out[20..24]);
    try std.testing.expectEqualSlices(u8, &.{ 21, 20, 19, 255 }, out[24..28]);
    try std.testing.expectEqualSlices(u8, &.{ 30, 29, 28, 255 }, out[36..40]);
    try std.testing.expectEqualSlices(u8, &.{ 33, 32, 31, 255 }, out[40..44]);
    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa }, out[60..64]);
}

test "wayland host renders the source app through canonical ir" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderNativeAppScene(&scene, &collector, 1280, 800, .{});
    try std.testing.expect(hasText(scene.written(), "EdgeRun Workspace"));
    try std.testing.expect(hasText(scene.written(), "EXPLORER"));

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body());
    try renderer_pipeline.packScene(buffers, &font_atlas, .object, scene.written());
    try std.testing.expect(ir_storage.rect_len > 0);
    try std.testing.expect(ir_storage.text_vertex_len > 0);
    try std.testing.expect(ir_storage.icon_vertex_len > 0);
}

test "wayland host renders academy post route through canonical ir" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    const post_id = app_blog.postIdAt(app_blog.posts.len - 1);
    var path: [app_navigation.route_path_capacity]u8 = undefined;
    const route_path = try std.fmt.bufPrint(&path, "/academy/{d}", .{post_id});
    try renderNativeAppScene(&scene, &collector, 1280, 1800, .{ .route = app_navigation.fromPath(route_path) });
    try std.testing.expect(hasText(scene.written(), "AUTHORITY FLOW"));
    try std.testing.expect(hasText(scene.written(), "Relay"));
    try std.testing.expect(hasText(scene.written(), "TPM"));
}

test "wayland host renders current docs routes through the shared app frame" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderNativeAppScene(&scene, &collector, 1280, 1800, .{ .route = app_navigation.fromPath("/docs/fonts") });

    try std.testing.expect(hasText(scene.written(), "EdgeRun Native"));
    try std.testing.expect(hasText(scene.written(), "Fonts"));
    try std.testing.expect(hasText(scene.written(), "asset: varfont.geist_bytes"));
    try std.testing.expect(hasText(scene.written(), "atlas: 2048x2048 alpha8, 1280 glyphs"));
}

test "wayland host renders client side decoration above app content" {
    var state = AppState{};
    state.route = app_navigation.fromPath("/academy");
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderNativeAppScene(&scene, &collector, 1280, 800, state);

    try std.testing.expect(hasText(scene.written(), "EDGERUN"));
    try std.testing.expect(hasText(scene.written(), "Academy"));
    try std.testing.expect(hasIcon(scene.written(), .x));
    try std.testing.expectEqual(@as(f32, 0.0), (try hitRect(collector.written(), client_decor_drag_id)).y);
    try std.testing.expect((try hitRect(collector.written(), client_decor_close_id)).x > 1200.0);

    const academy = try hitRect(collector.written(), app_chrome.blog_button_id);
    try std.testing.expect(academy.y >= client_decor_h);
}

test "wayland cursor overlay renders through software presentation receipt" {
    const source = @embedFile("wayland_window_host.zig");
    const direct_raster = "try surface." ++ "rasterizeIr(";
    try std.testing.expect(std.mem.indexOf(u8, source, direct_raster) == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "const receipt = try surface.renderIr(") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "if (!receipt.valid()) return error.InvalidSoftwareReceipt;") != null);
}

test "wayland gpu recorder accepts canonical ir frame callbacks" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 32, .h = 32 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var recorder = GpuRecorder{};
    var sink_state = WaylandCommitSink{};
    const receipt = try renderer_native_present.renderGpuAndSubmit(
        .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = wl_buffer_id,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        .{},
        recorder.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        default_refresh_hz,
        16,
        16,
        sink_state.sink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_gpu.Rasterization.recorded_commands, receipt.gpu.rasterization);
    try std.testing.expect(sink_state.submitted);
    try std.testing.expectEqual(@as(usize, 1), recorder.began);
    try std.testing.expectEqual(receipt.gpu.primitive_count, recorder.uploaded);
    try std.testing.expectEqual(receipt.gpu.dirty_tile_count, recorder.rendered);
    try std.testing.expectEqual(receipt.gpu.sequence, recorder.last_sequence);
}

test "wayland host pointer input updates hover activation and scroll state" {
    var state = AppState{};
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try renderNativeAppScene(&scene, &collector, 1280, 800, state);
    updateHoverHitForState(&state, collector.written());
    try std.testing.expect(state.runtime.hovered == null);

    const docs = try hitRect(collector.written(), app_landing.docs_button_id);
    state.hover_x = docs.x + docs.w * 0.5;
    state.hover_y = docs.y + docs.h * 0.5;
    updateHoverHitForState(&state, collector.written());
    try std.testing.expect(state.runtime.hovered != null);
    try std.testing.expectEqual(app_cursor.Kind.pointer, app_cursor.fromState(.none, state.runtime.hovered.?.kind));

    const old_hit = state.runtime.hovered.?.id;
    try activateHitForState(&state, null);
    try std.testing.expectEqual(old_hit, state.runtime.hovered.?.id);

    scrollStateBy(&state, 1280, 800, 320.0);
    try std.testing.expectEqual(@as(f32, 320.0), state.scroll_y);
    scrollStateBy(&state, 1280, 800, 200000.0);
    try std.testing.expect(state.scroll_y <= contentHeightForRoute(1280.0, state.route));
}

test "wayland host appends scene cursor from native hover state" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 1280,
        .height = 800,
        .present = .cpu,
        .dmabuf_fd = null,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body()),
        .gpu_primitives = &.{},
    };
    var scene = ui.Scene.initWithClips(&app.commands, &app.clips);
    var collector = interaction.Collector.init(&app.regions);
    try renderNativeAppScene(&scene, &collector, app.width, app.height, app.state);
    app.region_len = collector.written().len;
    const docs = try hitRect(app.regionSlice(), app_landing.docs_button_id);
    app.state.hover_x = docs.x + docs.w * 0.5;
    app.state.hover_y = docs.y + docs.h * 0.5;
    app.updateHoverHit(app.regionSlice());
    try app_cursor.render(&scene, app.state.hover_x, app.state.hover_y, app_cursor.fromState(.none, app.state.runtime.hoverKind()));

    try std.testing.expectEqual(app_cursor.Kind.pointer, app_cursor.fromState(.none, app.state.runtime.hoverKind()));
    try std.testing.expect(hasIconId(scene.written(), icon_svg.cursor_hand_finger_icon_id));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}

fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, value: icon.Icon) bool {
    const icon_id = icon.id(value);
    return hasIconId(commands, icon_id);
}

fn hasIconId(commands: []const ui.Command, icon_id: u32) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

fn hitRect(regions: []const interaction.Region, id: u32) !ui.Rect {
    for (regions) |region| {
        if (region.id == id) return region.bounds;
    }
    return error.MissingHit;
}

const std = @import("std");
const icon = @import("icon.zig");
const input = @import("input.zig");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_gpu = @import("renderer_gpu.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_native_present = @import("renderer_native_present.zig");
const renderer_software = @import("renderer_software.zig");
const site_chrome = @import("site_chrome.zig");
const site_landing = @import("site_landing.zig");
const tabler_atlas = @import("tabler_atlas.zig");
const ui = @import("ui.zig");

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

const wl_display_sync: u16 = 0;
const wl_display_get_registry: u16 = 1;
const wl_registry_bind: u16 = 0;
const wl_compositor_create_surface: u16 = 0;
const wl_seat_get_pointer: u16 = 0;
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
const fixed_scale: f32 = 256.0;

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
    dmabuf_fd: ?posix.fd_t = null,
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
        };
        if (!import.valid()) return error.InvalidDmabufImport;
        return import;
    }
};

const AppState = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    hover_hit_id: u32 = 0,
    public_identity_ready: bool = true,
    public_identity: []const u8 = "native-wayland",
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
    var app = try NativeApp.init(&client, allocator, options);
    defer app.deinit();
    try app.render(&client);
    try client.eventLoop(options.seconds, &app);
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
        } else if (std.mem.eql(u8, arg, "--dmabuf-fd")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.dmabuf_fd = try std.fmt.parseInt(posix.fd_t, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width == 0 or options.height == 0 or options.seconds == 0) return error.InvalidArguments;
    if (options.present == .gpu_dmabuf and options.dmabuf_fd == null) return error.MissingDmabufFd;
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

    fn sendDamage(self: WaylandClient, width: u32, height: u32) !void {
        var buffer: [message_bytes]u8 = undefined;
        const bytes = try makeDamageBuffer(&buffer, width, height);
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
        while (nextMessage(self.read_buffer[offset..self.read_len])) |message| {
            const kind = self.object_kinds[message.object_id];
            try self.replyToMessage(kind, message);
            try handleMessage(&self.state, kind, message);
            if (try app.handleWaylandInput(self, kind, message)) try app.render(self);
            offset += message.payload.len + 8;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.read_buffer[0 .. self.read_len - offset], self.read_buffer[offset..self.read_len]);
            self.read_len -= offset;
        }
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

const NativeApp = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    present: PresentMode,
    dmabuf_fd: ?posix.fd_t,
    shm: ShmBuffer,
    pixels: []ui.Color,
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    ir_storage: IrStorage = .{},
    font_atlas: renderer_font_atlas.Atlas = renderer_font_atlas.Atlas.init(),
    gpu_primitives: []renderer_gpu.Primitive,
    gpu_tile_marks: [max_tiles]u8 = undefined,
    gpu_dirty_ids: [max_tiles]u32 = undefined,
    tile_marks: [max_tiles]u8 = undefined,
    dirty_ids: [max_tiles]u32 = undefined,
    state: AppState = .{},
    gpu_recorder: GpuRecorder = .{},

    fn init(client: *WaylandClient, allocator: std.mem.Allocator, options: Options) !NativeApp {
        const width = options.width;
        const height = options.height;
        const stride = width * @sizeOf(u32);
        const shm = try client.createShmBuffer(@as(usize, stride) * height, width, height, stride);
        errdefer shm.deinit();
        const pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        const gpu_primitives = try allocator.alloc(renderer_gpu.Primitive, max_gpu_primitives);
        errdefer allocator.free(gpu_primitives);
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .present = options.present,
            .dmabuf_fd = options.dmabuf_fd,
            .shm = shm,
            .pixels = pixels,
            .gpu_primitives = gpu_primitives,
        };
    }

    fn deinit(self: *NativeApp) void {
        self.allocator.free(self.gpu_primitives);
        self.allocator.free(self.pixels);
        self.shm.deinit();
    }

    fn render(self: *NativeApp, client: *WaylandClient) !void {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        try renderBrowserLandingScene(&scene, self.width, self.height, self.state);
        self.updateHoverHit(scene.written());

        const buffers = self.ir_storage.buffers();
        try renderer_ir.packScene(buffers, sources(&self.font_atlas), scene.written());

        var sink_state = WaylandCommitSink{};
        const atlases = renderer_software.IrAtlases{
            .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .alpha = self.font_atlas.alphaSlice() },
            .icon = .{ .width = tabler_atlas.width, .height = tabler_atlas.height, .alpha = tabler_atlas.alpha },
        };
        switch (self.present) {
            .cpu => {
                const receipt = try renderer_native_present.renderCpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    atlases,
                    .{ .width = self.width, .height = self.height, .pixels = self.pixels },
                    siteBackground(),
                    default_refresh_hz,
                    tile_width,
                    tile_height,
                    &self.tile_marks,
                    &self.dirty_ids,
                    sink_state.sink(),
                );
                if (!receipt.valid() or !sink_state.submitted) return error.WaylandCommitRejected;
            },
            .gpu_record => {
                const receipt = try renderer_native_present.renderGpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    atlases.resources(),
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
                try self.renderSoftwarePixels(buffers, atlases);
            },
            .gpu_dmabuf => {
                const dmabuf_surface = try self.dmabufSurface();
                const import = try DmabufImport.fromNativeSurface(dmabuf_surface);
                try client.createDmabufBuffer(import);
                var dmabuf_sink_state = WaylandDmabufCommitSink{};
                const receipt = try renderer_native_present.renderGpuBackedAndSubmit(
                    dmabuf_surface,
                    buffers,
                    atlases.resources(),
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
                    dmabuf_sink_state.sink(),
                );
                if (!receipt.valid() or !dmabuf_sink_state.submitted) return error.WaylandCommitRejected;
                try client.attachDmabufCommit(self.width, self.height);
                return;
            },
        }
        packXrgb8888(self.shm.memory, self.pixels);
        try client.attachCommit(self.width, self.height);
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
        const fd = self.dmabuf_fd orelse return error.MissingDmabufFd;
        if (fd < 0) return error.InvalidDmabufImport;
        return .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = dmabuf_wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = self.width,
            .scale = 1,
            .format = .xrgb8888,
            .gpu_buffer = .{
                .kind = .dma_buf,
                .handle = @intCast(fd),
            },
        } };
    }

    fn renderSoftwarePixels(self: *NativeApp, buffers: renderer_ir.Buffers, atlases: renderer_software.IrAtlases) !void {
        const software_surface = try renderer_software.Surface.init(self.width, self.height, self.pixels);
        software_surface.clear(siteBackground());
        _ = try software_surface.renderIrFrameWithAtlases(buffers, atlases);
    }

    fn handleWaylandInput(self: *NativeApp, client: *WaylandClient, kind: ObjectKind, message: Message) !bool {
        _ = client;
        if (kind != .pointer) return false;
        switch (message.opcode) {
            wl_pointer_enter_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[12..16], .little));
                return true;
            },
            wl_pointer_leave_event => {
                self.state.hover_x = -1.0;
                self.state.hover_y = -1.0;
                self.state.hover_hit_id = 0;
                return true;
            },
            wl_pointer_motion_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[4..8], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                return true;
            },
            wl_pointer_button_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const button = std.mem.readInt(u32, message.payload[8..12], .little);
                const state = std.mem.readInt(u32, message.payload[12..16], .little);
                if (button == wl_pointer_button_left and state == wl_pointer_button_released) self.activateHit();
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

    fn updateHoverHit(self: *NativeApp, commands: []const ui.Command) void {
        updateHoverHitForState(&self.state, commands);
    }

    fn activateHit(self: *NativeApp) void {
        activateHitForState(&self.state);
    }

    fn scrollBy(self: *NativeApp, delta_y: f32) void {
        scrollStateBy(&self.state, self.width, self.height, delta_y);
    }
};

fn updateHoverHitForState(state: *AppState, commands: []const ui.Command) void {
    if (state.hover_x < 0.0 or state.hover_y < 0.0) {
        state.hover_hit_id = 0;
        return;
    }
    state.hover_hit_id = if (input.hitTest(commands, state.hover_x, state.hover_y)) |hit| hit.id else 0;
}

fn activateHitForState(state: *AppState) void {
    switch (state.hover_hit_id) {
        site_chrome.logo_button_id,
        site_chrome.docs_button_id,
        => state.scroll_y = 0.0,
        site_landing.reveal_identity_button_id => {
            state.public_identity_ready = true;
            state.public_identity = "native-wayland";
        },
        else => {},
    }
}

fn scrollStateBy(state: *AppState, width: u32, height: u32, delta_y: f32) void {
    if (!std.math.isFinite(delta_y)) return;
    const limit = @max(0.0, site_landing.contentHeight(@floatFromInt(width)) - @as(f32, @floatFromInt(height)));
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

fn renderBrowserLandingScene(scene: *ui.Scene, width: u32, height: u32, state: AppState) !void {
    try site_landing.render(scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(width),
        .h = @floatFromInt(height),
    }, .{
        .scroll_y = state.scroll_y,
        .hover_x = state.hover_x,
        .hover_y = state.hover_y,
        .frame_ms = 0.0,
        .public_identity = state.public_identity,
        .public_identity_ready = state.public_identity_ready,
    });
}

fn sources(font_atlas: *renderer_font_atlas.Atlas) renderer_ir.Sources {
    return .{
        .font = font_atlas.source(),
        .icon = .{ .context = font_atlas, .rect = iconAtlasRect },
    };
}

fn iconAtlasRect(_: *anyopaque, atlas_id: u32) ?renderer_ir.AtlasRect {
    const value = icon.fromAtlasId(atlas_id) orelse return null;
    const found = tabler_atlas.rect(value);
    return .{
        .u0 = (@as(f32, @floatFromInt(found.x)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
        .u1 = (@as(f32, @floatFromInt(found.x + found.w)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v1 = (@as(f32, @floatFromInt(found.y + found.h)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
    };
}

fn siteBackground() ui.Color {
    return .{ .r = 11, .g = 11, .b = 11 };
}

fn packXrgb8888(out: []u8, pixels: []const ui.Color) void {
    for (pixels, 0..) |pixel, index| {
        const base = index * @sizeOf(u32);
        out[base + 0] = pixel.b;
        out[base + 1] = pixel.g;
        out[base + 2] = pixel.r;
        out[base + 3] = 255;
    }
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
    var msg = try MessageWriter.init(buffer, surface_id, wl_surface_damage_buffer);
    try msg.putI32(0);
    try msg.putI32(0);
    try msg.putI32(@intCast(width));
    try msg.putI32(@intCast(height));
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

    const args = [_][:0]const u8{ "wayland-window", "--width", "800", "--height", "600", "--seconds", "1", "--present", "gpu-record" };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(@as(u32, 800), options.width);
    try std.testing.expectEqual(@as(u32, 600), options.height);
    try std.testing.expectEqual(@as(u32, 1), options.seconds);
    try std.testing.expectEqual(PresentMode.gpu_record, options.present);

    const dmabuf_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf", "--dmabuf-fd", "17" };
    const dmabuf_options = try parseOptions(&dmabuf_args);
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, dmabuf_options.present);
    try std.testing.expectEqual(@as(posix.fd_t, 17), dmabuf_options.dmabuf_fd.?);

    const missing_fd_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf" };
    try std.testing.expectError(error.MissingDmabufFd, parseOptions(&missing_fd_args));
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
        },
    } });
    try std.testing.expectEqual(@as(posix.fd_t, 7), import.fd);
    try std.testing.expectEqual(@as(u32, 320), import.width);
    try std.testing.expectEqual(@as(u32, 240), import.height);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);
    try std.testing.expectEqual(drm_format_argb8888, import.format);
    try std.testing.expectEqual(@as(u32, 128), import.offset);

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
        .gpu_primitives = &.{},
    };
    const surface = try app.dmabufSurface();
    const import = try DmabufImport.fromNativeSurface(surface);
    try std.testing.expectEqual(@as(posix.fd_t, 19), import.fd);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);

    app.dmabuf_fd = null;
    try std.testing.expectError(error.MissingDmabufFd, app.dmabufSurface());
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

test "wayland host renders the browser landing app through canonical ir" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderBrowserLandingScene(&scene, 1280, 800, .{});
    try std.testing.expect(hasText(scene.written(), "Your Node is"));
    try std.testing.expect(hasText(scene.written(), "Already Running"));

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas = renderer_font_atlas.Atlas.init();
    try renderer_ir.packScene(buffers, sources(&font_atlas), scene.written());
    try std.testing.expect(ir_storage.rect_len > 0);
    try std.testing.expect(ir_storage.text_vertex_len > 0);
    try std.testing.expect(ir_storage.icon_vertex_len > 0);
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
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderBrowserLandingScene(&scene, 1280, 800, state);
    updateHoverHitForState(&state, scene.written());
    try std.testing.expectEqual(@as(u32, 0), state.hover_hit_id);

    const docs = try hitRect(scene.written(), site_landing.docs_button_id);
    state.hover_x = docs.x + docs.w * 0.5;
    state.hover_y = docs.y + docs.h * 0.5;
    updateHoverHitForState(&state, scene.written());
    try std.testing.expect(state.hover_hit_id != 0);

    const old_hit = state.hover_hit_id;
    activateHitForState(&state);
    try std.testing.expectEqual(old_hit, state.hover_hit_id);

    scrollStateBy(&state, 1280, 800, 320.0);
    try std.testing.expectEqual(@as(f32, 320.0), state.scroll_y);
    scrollStateBy(&state, 1280, 800, 200000.0);
    try std.testing.expect(state.scroll_y <= site_landing.contentHeight(1280.0));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}

fn hitRect(commands: []const ui.Command, id: u32) !ui.Rect {
    for (commands) |command| {
        if (command == .hit and command.hit.id == id) return command.hit.bounds;
    }
    return error.MissingHit;
}

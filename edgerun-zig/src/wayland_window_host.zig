const std = @import("std");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_native_present = @import("renderer_native_present.zig");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

const linux = std.os.linux;
const posix = std.posix;

const default_width: u32 = 960;
const default_height: u32 = 540;
const default_seconds: u32 = 5;
const default_refresh_hz: u32 = 60;
const tile_width: u32 = 64;
const tile_height: u32 = 64;
const max_commands: usize = 64;
const max_rects: usize = 256;
const max_text_vertices: usize = 8192;
const empty_texture_vertices: usize = 0;
const max_tiles: usize = 512;
const max_registry_globals: usize = 128;
const socket_read_bytes: usize = 8192;
const message_bytes: usize = 512;
const empty_alpha = [_]u8{255};

const display_id: u32 = 1;
const registry_id: u32 = 2;
const sync_callback_id: u32 = 3;
const compositor_id: u32 = 4;
const shm_id: u32 = 5;
const wm_base_id: u32 = 6;
const surface_id: u32 = 7;
const xdg_surface_id: u32 = 8;
const xdg_toplevel_id: u32 = 9;
const shm_pool_id: u32 = 10;
const wl_buffer_id: u32 = 11;

const wl_display_sync: u16 = 0;
const wl_display_get_registry: u16 = 1;
const wl_registry_bind: u16 = 0;
const wl_compositor_create_surface: u16 = 0;
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

const wl_display_error_event: u16 = 0;
const wl_registry_global_event: u16 = 0;
const wl_callback_done_event: u16 = 0;
const xdg_wm_base_ping_event: u16 = 0;
const xdg_surface_configure_event: u16 = 0;
const xdg_toplevel_close_event: u16 = 1;

const wl_shm_format_xrgb8888: u32 = 1;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
);

const Options = struct {
    width: u32 = default_width,
    height: u32 = default_height,
    seconds: u32 = default_seconds,
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
};

const RegistryGlobal = struct {
    name: u32,
    interface: []const u8,
    version: u32,
};

const RegistryState = struct {
    globals: [max_registry_globals]RegistryGlobal = undefined,
    len: usize = 0,

    fn add(self: *RegistryState, global: RegistryGlobal) !void {
        if (self.len >= self.globals.len) return error.RegistryGlobalBudgetExceeded;
        self.globals[self.len] = global;
        self.len += 1;
    }

    fn find(self: RegistryState, interface: []const u8) ?RegistryGlobal {
        for (self.globals[0..self.len]) |global| {
            if (std.mem.eql(u8, global.interface, interface)) return global;
        }
        return null;
    }
};

const WaylandState = struct {
    registry: RegistryState = .{},
    registry_done: bool = false,
    configured: bool = false,
    closed: bool = false,
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
    try renderAndCommit(&client, allocator, options.width, options.height);
    try client.eventLoop(options.seconds);
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
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width == 0 or options.height == 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
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
        const compositor = self.state.registry.find("wl_compositor") orelse return error.MissingWaylandCompositor;
        const shm = self.state.registry.find("wl_shm") orelse return error.MissingWaylandShm;
        const wm_base = self.state.registry.find("xdg_wm_base") orelse return error.MissingXdgWmBase;
        try self.sendBind(compositor.name, "wl_compositor", @min(compositor.version, 4), compositor_id);
        try self.sendBind(shm.name, "wl_shm", @min(shm.version, 1), shm_id);
        try self.sendBind(wm_base.name, "xdg_wm_base", @min(wm_base.version, 1), wm_base_id);
        try self.send(makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
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

    fn eventLoop(self: *WaylandClient, seconds: u32) !void {
        var remaining_ms: i32 = @intCast(seconds * std.time.ms_per_s);
        while (!self.state.closed and remaining_ms > 0) {
            const step_ms: i32 = @min(remaining_ms, 100);
            var fds = [_]posix.pollfd{.{ .fd = self.fd, .events = linux.POLL.IN, .revents = 0 }};
            const ready = try posix.poll(&fds, step_ms);
            if (ready != 0 and (fds[0].revents & linux.POLL.IN) != 0) try self.readEventsBlocking();
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

    fn attachCommit(self: *WaylandClient, width: u32, height: u32) !void {
        try self.sendAttach();
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

    fn sendAttach(self: WaylandClient) !void {
        var buffer: [message_bytes]u8 = undefined;
        try writeAll(self.fd, try makeAttach(&buffer));
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

fn renderAndCommit(client: *WaylandClient, allocator: std.mem.Allocator, width: u32, height: u32) !void {
    const stride = width * @sizeOf(u32);
    var shm = try client.createShmBuffer(@as(usize, stride) * height, width, height, stride);
    defer shm.deinit();

    const pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
    defer allocator.free(pixels);

    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var nodes: [5]ui.Node = undefined;
    try ui.render(&scene, sampleRoot(&nodes), .{ .x = 0, .y = 0, .w = @floatFromInt(width), .h = @floatFromInt(height) }, .{});

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas = renderer_font_atlas.Atlas.init();
    try renderer_ir.packScene(buffers, .{
        .font = font_atlas.source(),
        .icon = renderer_font_atlas.nullIconSource(&font_atlas),
    }, scene.written());

    var tile_marks: [max_tiles]u8 = undefined;
    var dirty_ids: [max_tiles]u32 = undefined;
    var sink_state = WaylandCommitSink{};
    const atlases = renderer_software.IrAtlases{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .alpha = font_atlas.alphaSlice() },
        .icon = .{ .width = 1, .height = 1, .alpha = &empty_alpha },
    };
    const receipt = try renderer_native_present.renderCpuAndSubmit(
        .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = wl_buffer_id,
            .width = width,
            .height = height,
            .stride = width,
            .scale = 1,
        } },
        buffers,
        atlases,
        .{ .width = width, .height = height, .pixels = pixels },
        .bg,
        default_refresh_hz,
        tile_width,
        tile_height,
        &tile_marks,
        &dirty_ids,
        sink_state.sink(),
    );
    if (!receipt.valid() or !sink_state.submitted) return error.WaylandCommitRejected;
    packXrgb8888(shm.memory, pixels);
    try client.attachCommit(width, height);
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

fn sampleRoot(children: []ui.Node) ui.Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "EdgeRun native Wayland", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "canonical IR -> CPU pixels -> Wayland shm" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "same UI frame", .detail = "browser, cpu, gpu, drm, wayland" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Native" } };
    return .{ .stack = .{ .axis = .column, .gap = 18, .padding = 48, .children = children[0..4] } };
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

fn makeAttach(buffer: []u8) ![]const u8 {
    var msg = try MessageWriter.init(buffer, surface_id, wl_surface_attach);
    try msg.putU32(wl_buffer_id);
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
    const interface = payload[8 .. 8 + string_len - 1];
    const version = std.mem.readInt(u32, payload[8 + padded ..][0..4], .little);
    return .{ .name = name, .interface = interface, .version = version };
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
    try std.testing.expectEqualStrings("wl_shm", global.interface);
    try std.testing.expectEqual(@as(u32, 1), global.version);
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

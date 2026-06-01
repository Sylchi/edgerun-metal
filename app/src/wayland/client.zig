const std = @import("er_std");
const protocol = @import("protocol.zig");
const messages = @import("messages.zig");

const linux = std.os.linux;
const posix = std.posix;

pub const max_socket_read_bytes: usize = 8192;
pub const max_message_bytes: usize = 512;

pub const WaylandClient = struct {
    fd: posix.fd_t,
    state: protocol.WaylandState = .{},
    read_buffer: [max_socket_read_bytes]u8 = undefined,
    read_len: usize = 0,
    object_kinds: [128]protocol.ObjectKind = [_]protocol.ObjectKind{.unknown} ** 128,
    next_object_id: u32 = protocol.dynamic_object_id_start,

    pub fn connect(io: std.Io, path: []const u8) !WaylandClient {
        const address = try std.Io.net.UnixAddress.init(path);
        const stream = try std.Io.net.UnixAddress.connect(&address, io);
        var client = WaylandClient{ .fd = stream.socket.handle };
        client.object_kinds[protocol.display_id] = .display;
        client.object_kinds[protocol.registry_id] = .registry;
        client.object_kinds[protocol.sync_callback_id] = .callback;
        client.object_kinds[protocol.compositor_id] = .compositor;
        client.object_kinds[protocol.shm_id] = .shm;
        client.object_kinds[protocol.wm_base_id] = .wm_base;
        client.object_kinds[protocol.surface_id] = .surface;
        client.object_kinds[protocol.xdg_surface_id] = .xdg_surface;
        client.object_kinds[protocol.xdg_toplevel_id] = .xdg_toplevel;
        client.object_kinds[protocol.seat_id] = .seat;
        client.object_kinds[protocol.pointer_id] = .pointer;
        client.object_kinds[protocol.linux_dmabuf_id] = .linux_dmabuf;
        client.object_kinds[protocol.dmabuf_params_id] = .dmabuf_params;
        client.object_kinds[protocol.dmabuf_wl_buffer_id] = .dmabuf_buffer;
        client.object_kinds[protocol.xdg_decoration_manager_id] = .decoration_manager;
        client.object_kinds[protocol.xdg_toplevel_decoration_id] = .toplevel_decoration;
        return client;
    }

    pub fn close(self: *WaylandClient, io: std.Io) void {
        _ = io;
        protocol.closeFd(self.fd);
    }

    pub fn bootstrap(self: *WaylandClient) !void {
        try self.send(messages.makeGetRegistry);
        try self.send(messages.makeSync);
        while (!self.state.registry_done) try self.readEventsBlocking();
        const compositor = self.state.registry.find(.compositor) orelse return error.MissingWaylandCompositor;
        const shm = self.state.registry.find(.shm) orelse return error.MissingWaylandShm;
        const wm_base = self.state.registry.find(.wm_base);
        const seat = self.state.registry.find(.seat);
        try self.sendBind(compositor.name, "wl_compositor", @min(compositor.version, 4), protocol.compositor_id);
        try self.waitRegistrySync();
        try self.sendBind(shm.name, "wl_shm", @min(shm.version, 1), protocol.shm_id);
        try self.waitRegistrySync();
        if (wm_base) |value| {
            try self.sendBind(value.name, "xdg_wm_base", @min(value.version, 1), protocol.wm_base_id);
            try self.waitRegistrySync();
            self.state.xdg_available = true;
        }
        if (self.state.xdg_available) {
            if (seat) |value| {
                try self.sendBind(value.name, "wl_seat", @min(value.version, 1), protocol.seat_id);
                try self.waitRegistrySync();
            }
        }
        try self.send(messages.makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
        if (self.state.seat_has_pointer) {
            try self.send(messages.makeGetPointer);
            try self.send(messages.makeSync);
            self.state.registry_done = false;
            while (!self.state.registry_done) try self.readEventsBlocking();
        }
    }

    pub fn createWindow(self: *WaylandClient, width: u32, height: u32) !void {
        _ = width;
        _ = height;
        try self.send(messages.makeCreateSurface);
        if (!self.state.xdg_available) {
            self.state.configured = true;
            return;
        }
        try self.send(messages.makeGetXdgSurface);
        try self.send(messages.makeGetToplevel);
        try self.sendTitle("EdgeRun Native Wayland");
        try self.sendAppId("dev.edgerun.Native");
        try self.send(messages.makeSurfaceCommit);
        while (!self.state.configured) try self.readEventsBlocking();
    }

    pub fn eventLoop(self: *WaylandClient, seconds: u32, app: anytype) !void {
        const deadline_ms = eventLoopDeadlineMs(try monotonicMs(), seconds);
        while (!self.state.closed) {
            const remaining_ms = eventLoopRemainingMs(try monotonicMs(), deadline_ms);
            if (remaining_ms == 0) break;
            const step_ms: i32 = @min(remaining_ms, frame_poll_ms);
            var fds = [_]posix.pollfd{.{ .fd = self.fd, .events = linux.POLL.IN, .revents = 0 }};
            const ready = try posix.poll(&fds, step_ms);
            if (ready != 0 and (fds[0].revents & linux.POLL.IN) != 0) {
                try self.readEvents(app);
            } else {
                app.tickIdleFrame(self);
            }
        }
    }

    pub fn createShmBuffer(self: *WaylandClient, bytes: usize, width: u32, height: u32, stride: u32) !protocol.ShmBuffer {
        const fd = try posix.memfd_create("edgerun-wayland-frame", linux.MFD.CLOEXEC);
        errdefer protocol.closeFd(fd);
        try messages.truncateFd(fd, bytes);
        const mapped = try posix.mmap(null, bytes, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);
        errdefer posix.munmap(mapped);
        const pool_id = try self.allocObject(.unknown);
        const buffer_id = try self.allocObject(.unknown);
        try self.sendCreatePool(fd, pool_id, @intCast(bytes));
        try self.sendCreateBuffer(pool_id, buffer_id, width, height, stride);
        try self.sendDestroyPool(pool_id);
        return .{ .fd = fd, .pool_id = pool_id, .buffer_id = buffer_id, .memory = mapped, .width = width, .height = height, .stride = stride };
    }

    pub fn createDmabufBuffer(self: *WaylandClient, import: protocol.DmabufImport) !void {
        if (!import.valid()) return error.InvalidDmabufImport;
        try self.bindDmabuf();
        try self.send(messages.makeDmabufCreateParams);
        try self.sendDmabufAddPlane(import);
        try self.sendDmabufCreateImmediate(import.width, import.height, import.format);
    }

    fn bindDmabuf(self: *WaylandClient) !void {
        if (self.state.dmabuf_bound) return;
        const global = self.state.registry.find(.linux_dmabuf) orelse return error.MissingWaylandDmabuf;
        try self.sendBind(global.name, "zwp_linux_dmabuf_v1", @min(global.version, 4), protocol.linux_dmabuf_id);
        try self.send(messages.makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
        self.state.dmabuf_bound = true;
    }

    pub fn attachCommit(self: *WaylandClient, buffer_id: u32, width: u32, height: u32) !void {
        try self.sendAttach(buffer_id);
        try self.sendDamage(width, height);
        try self.send(messages.makeSurfaceCommit);
    }

    pub fn attachCommitRect(self: *WaylandClient, buffer_id: u32, rect: protocol.PixelRect) !void {
        try self.sendAttach(buffer_id);
        try self.sendDamageRect(rect);
        try self.send(messages.makeSurfaceCommit);
    }

    pub fn attachDmabufCommit(self: *WaylandClient, width: u32, height: u32) !void {
        try self.sendAttach(protocol.dmabuf_wl_buffer_id);
        try self.sendDamage(width, height);
        try self.send(messages.makeSurfaceCommit);
    }

    fn send(self: WaylandClient, comptime maker: fn ([]u8) anyerror![]const u8) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try maker(&buffer));
    }

    fn sendBind(self: WaylandClient, name: u32, interface: []const u8, version: u32, new_id: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        const bytes = try messages.makeBind(&buffer, name, interface, version, new_id);
        try messages.writeAll(self.fd, bytes);
    }

    fn waitRegistrySync(self: *WaylandClient) !void {
        try self.send(messages.makeSync);
        self.state.registry_done = false;
        while (!self.state.registry_done) try self.readEventsBlocking();
    }

    fn sendTitle(self: WaylandClient, title: []const u8) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        const bytes = try messages.makeSetTitle(&buffer, title);
        try messages.writeAll(self.fd, bytes);
    }

    fn sendAppId(self: WaylandClient, app_id: []const u8) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        const bytes = try messages.makeSetAppId(&buffer, app_id);
        try messages.writeAll(self.fd, bytes);
    }

    pub fn sendMove(self: WaylandClient, serial: u32) !void {
        if (!self.state.xdg_available) return;
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeMove(&buffer, serial));
    }

    pub fn sendResize(self: WaylandClient, serial: u32, edges: u32) !void {
        if (!self.state.xdg_available) return;
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeResize(&buffer, serial, edges));
    }

    pub fn sendMinimize(self: WaylandClient) !void {
        if (!self.state.xdg_available) return;
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeSetMinimized(&buffer));
    }

    pub fn sendHidePointerCursor(self: WaylandClient, serial: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeHidePointerCursor(&buffer, serial));
    }

    fn sendDamage(self: WaylandClient, width: u32, height: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeDamageBuffer(&buffer, width, height));
    }

    fn sendDamageRect(self: WaylandClient, rect: protocol.PixelRect) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeDamageBufferRect(&buffer, rect));
    }

    fn sendAttach(self: WaylandClient, buffer_id: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeAttach(&buffer, buffer_id));
    }

    fn sendCreatePool(self: WaylandClient, fd: posix.fd_t, pool_id: u32, bytes: i32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        const msg = try messages.makeCreatePoolWithId(&buffer, pool_id, bytes);
        try messages.sendFd(self.fd, msg, fd);
    }

    fn sendCreateBuffer(self: WaylandClient, pool_id: u32, buffer_id: u32, width: u32, height: u32, stride: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeCreateBufferWithId(&buffer, pool_id, buffer_id, width, height, stride));
    }

    pub fn sendDestroyBuffer(self: WaylandClient, buffer_id: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeDestroyBuffer(&buffer, buffer_id));
    }

    fn sendDestroyPool(self: WaylandClient, pool_id: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeDestroyPoolWithId(&buffer, pool_id));
    }

    fn allocObject(self: *WaylandClient, kind: protocol.ObjectKind) !u32 {
        const id = self.next_object_id;
        if (id >= self.object_kinds.len) return error.WaylandObjectBudgetExceeded;
        self.next_object_id += 1;
        self.object_kinds[id] = kind;
        return id;
    }

    fn sendDmabufAddPlane(self: WaylandClient, import: protocol.DmabufImport) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        const bytes = try messages.makeDmabufAddPlane(&buffer, import.plane_index, import.offset, import.stride, import.modifier);
        try messages.sendFd(self.fd, bytes, import.fd);
    }

    fn sendDmabufCreateImmediate(self: WaylandClient, width: u32, height: u32, format: u32) !void {
        var buffer: [max_message_bytes]u8 = undefined;
        try messages.writeAll(self.fd, try messages.makeDmabufCreateImmediate(&buffer, width, height, format));
    }

    fn readEventsBlocking(self: *WaylandClient) !void {
        const n = try posix.read(self.fd, self.read_buffer[self.read_len..]);
        if (n == 0) return error.WaylandConnectionClosed;
        self.read_len += n;
        var offset: usize = 0;
        while (messages.nextMessage(self.read_buffer[offset..self.read_len])) |msg| {
            try self.replyToMessage(self.object_kinds[msg.object_id], msg);
            try messages.handleMessage(&self.state, self.object_kinds[msg.object_id], msg);
            offset += msg.payload.len + 8;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.read_buffer[0 .. self.read_len - offset], self.read_buffer[offset..self.read_len]);
            self.read_len -= offset;
        }
    }

    pub fn readEvents(self: *WaylandClient, app: anytype) !void {
        const n = try posix.read(self.fd, self.read_buffer[self.read_len..]);
        if (n == 0) return error.WaylandConnectionClosed;
        self.read_len += n;
        var offset: usize = 0;
        var needs_render = false;
        while (messages.nextMessage(self.read_buffer[offset..self.read_len])) |msg| {
            const kind = self.object_kinds[msg.object_id];
            try self.replyToMessage(kind, msg);
            try messages.handleMessage(&self.state, kind, msg);
            needs_render = (try app.handleWaylandInput(self, kind, msg)) or needs_render;
            offset += msg.payload.len + 8;
        }
        if (offset != 0) {
            std.mem.copyForwards(u8, self.read_buffer[0 .. self.read_len - offset], self.read_buffer[offset..self.read_len]);
            self.read_len -= offset;
        }
        if (needs_render) app.renderSafe(self);
    }

    fn replyToMessage(self: WaylandClient, kind: protocol.ObjectKind, message: protocol.Message) !void {
        if (message.payload.len < 4) return;
        const serial = std.mem.readInt(u32, message.payload[0..4], .little);
        switch (kind) {
            .wm_base => if (message.opcode == protocol.xdg_wm_base_ping_event) {
                var buffer: [max_message_bytes]u8 = undefined;
                try messages.writeAll(self.fd, try messages.makePong(&buffer, serial));
            },
            .xdg_surface => if (message.opcode == protocol.xdg_surface_configure_event) {
                var buffer: [max_message_bytes]u8 = undefined;
                try messages.writeAll(self.fd, try messages.makeAckConfigure(&buffer, serial));
            },
            else => {},
        }
    }
};

const frame_poll_ms: i32 = 16;

fn monotonicMs() !i64 {
    var ts: linux.timespec = undefined;
    if (linux.clock_gettime(.MONOTONIC, &ts) != 0) return error.ClockUnavailable;
    return @as(i64, @intCast(ts.sec)) * std.time.ms_per_s + @divTrunc(@as(i64, @intCast(ts.nsec)), std.time.ns_per_ms);
}

fn eventLoopDeadlineMs(now_ms: i64, seconds: u32) i64 {
    return now_ms + @as(i64, @intCast(seconds)) * std.time.ms_per_s;
}

fn eventLoopRemainingMs(now_ms: i64, deadline_ms: i64) i32 {
    if (now_ms >= deadline_ms) return 0;
    const remaining = deadline_ms - now_ms;
    return @intCast(@min(remaining, std.math.maxInt(i32)));
}

test "wayland event loop remaining time uses elapsed wall clock" {
    const deadline = eventLoopDeadlineMs(1_000, 5);

    try std.testing.expectEqual(@as(i32, 5_000), eventLoopRemainingMs(1_000, deadline));
    try std.testing.expectEqual(@as(i32, 3_750), eventLoopRemainingMs(2_250, deadline));
    try std.testing.expectEqual(@as(i32, 0), eventLoopRemainingMs(6_000, deadline));
}

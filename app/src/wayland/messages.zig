const std = @import("std");
const protocol = @import("protocol.zig");
const bytes_mod = @import("../bytes.zig");

const linux = std.os.linux;
const posix = std.posix;

pub fn makeGetRegistry(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.display_id, protocol.wl_display_get_registry);
    try msg.putU32(protocol.registry_id);
    return msg.finish();
}

pub fn makeSync(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.display_id, protocol.wl_display_sync);
    try msg.putU32(protocol.sync_callback_id);
    return msg.finish();
}

pub fn makeBind(buffer: []u8, name: u32, interface: []const u8, version: u32, new_id: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.registry_id, protocol.wl_registry_bind);
    try msg.putU32(name);
    try msg.putString(interface);
    try msg.putU32(version);
    try msg.putU32(new_id);
    return msg.finish();
}

pub fn makeCreateSurface(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.compositor_id, protocol.wl_compositor_create_surface);
    try msg.putU32(protocol.surface_id);
    return msg.finish();
}

pub fn makeGetPointer(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.seat_id, protocol.wl_seat_get_pointer);
    try msg.putU32(protocol.pointer_id);
    return msg.finish();
}

pub fn makeHidePointerCursor(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.pointer_id, protocol.wl_pointer_set_cursor);
    try msg.putU32(serial);
    try msg.putU32(0);
    try msg.putI32(0);
    try msg.putI32(0);
    return msg.finish();
}

pub fn makeCreatePool(buffer: []u8, bytes: i32) ![]const u8 {
    return makeCreatePoolWithId(buffer, protocol.shm_pool_id, bytes);
}

pub fn makeCreatePoolWithId(buffer: []u8, pool_id: u32, bytes: i32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.shm_id, protocol.wl_shm_create_pool);
    try msg.putU32(pool_id);
    try msg.putI32(bytes);
    return msg.finish();
}

pub fn makeCreateBuffer(buffer: []u8, width: u32, height: u32, stride: u32) ![]const u8 {
    return makeCreateBufferWithId(buffer, protocol.shm_pool_id, protocol.wl_buffer_id, width, height, stride);
}

pub fn makeCreateBufferWithId(buffer: []u8, pool_id: u32, buffer_id: u32, width: u32, height: u32, stride: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, pool_id, protocol.wl_shm_pool_create_buffer);
    try msg.putU32(buffer_id);
    try msg.putI32(0);
    try msg.putI32(@intCast(width));
    try msg.putI32(@intCast(height));
    try msg.putI32(@intCast(stride));
    try msg.putU32(protocol.wl_shm_format_xrgb8888);
    return msg.finish();
}

pub fn makeDestroyBuffer(buffer: []u8, buffer_id: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, buffer_id, protocol.wl_buffer_destroy);
    return msg.finish();
}

pub fn makeDestroyPool(buffer: []u8) ![]const u8 {
    return makeDestroyPoolWithId(buffer, protocol.shm_pool_id);
}

pub fn makeDestroyPoolWithId(buffer: []u8, pool_id: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, pool_id, protocol.wl_shm_pool_destroy);
    return msg.finish();
}

pub fn makeDmabufCreateParams(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.linux_dmabuf_id, protocol.zwp_linux_dmabuf_create_params);
    try msg.putU32(protocol.dmabuf_params_id);
    return msg.finish();
}

pub fn makeDmabufAddPlane(buffer: []u8, plane_index: u32, offset: u32, stride: u32, modifier: u64) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.dmabuf_params_id, protocol.zwp_linux_buffer_params_add);
    try msg.putU32(plane_index);
    try msg.putU32(offset);
    try msg.putU32(stride);
    try msg.putU32(@intCast(modifier >> 32));
    try msg.putU32(@truncate(modifier));
    return msg.finish();
}

pub fn makeDmabufCreateImmediate(buffer: []u8, width: u32, height: u32, format: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.dmabuf_params_id, protocol.zwp_linux_buffer_params_create_immed);
    try msg.putU32(protocol.dmabuf_wl_buffer_id);
    try msg.putI32(@intCast(width));
    try msg.putI32(@intCast(height));
    try msg.putU32(format);
    try msg.putU32(protocol.dmabuf_flags_none);
    return msg.finish();
}

pub fn makeGetXdgSurface(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.wm_base_id, protocol.xdg_wm_base_get_xdg_surface);
    try msg.putU32(protocol.xdg_surface_id);
    try msg.putU32(protocol.surface_id);
    return msg.finish();
}

pub fn makeGetToplevel(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_surface_id, protocol.xdg_surface_get_toplevel);
    try msg.putU32(protocol.xdg_toplevel_id);
    return msg.finish();
}

pub fn makeSetTitle(buffer: []u8, title: []const u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_id, protocol.xdg_toplevel_set_title);
    try msg.putString(title);
    return msg.finish();
}

pub fn makeSetAppId(buffer: []u8, app_id: []const u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_id, protocol.xdg_toplevel_set_app_id);
    try msg.putString(app_id);
    return msg.finish();
}

pub fn makeMove(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_id, protocol.xdg_toplevel_move);
    try msg.putU32(protocol.seat_id);
    try msg.putU32(serial);
    return msg.finish();
}

pub fn makeResize(buffer: []u8, serial: u32, edges: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_id, protocol.xdg_toplevel_resize);
    try msg.putU32(protocol.seat_id);
    try msg.putU32(serial);
    try msg.putU32(edges);
    return msg.finish();
}

pub fn makeSetMinimized(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_id, protocol.xdg_toplevel_set_minimized);
    return msg.finish();
}

pub fn makeGetToplevelDecoration(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_decoration_manager_id, protocol.xdg_decoration_manager_get_toplevel_decoration);
    try msg.putU32(protocol.xdg_toplevel_decoration_id);
    try msg.putU32(protocol.xdg_toplevel_id);
    return msg.finish();
}

pub fn makeSetServerSideDecoration(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_toplevel_decoration_id, protocol.xdg_toplevel_decoration_set_mode);
    try msg.putU32(protocol.xdg_toplevel_decoration_mode_server_side);
    return msg.finish();
}

pub fn makeSurfaceCommit(buffer: []u8) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.surface_id, protocol.wl_surface_commit);
    return msg.finish();
}

pub fn makeAttach(buffer: []u8, buffer_id: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.surface_id, protocol.wl_surface_attach);
    try msg.putU32(buffer_id);
    try msg.putI32(0);
    try msg.putI32(0);
    return msg.finish();
}

pub fn makeDamageBuffer(buffer: []u8, width: u32, height: u32) ![]const u8 {
    return makeDamageBufferRect(buffer, .{ .x = 0, .y = 0, .w = width, .h = height });
}

pub fn makeDamageBufferRect(buffer: []u8, rect: protocol.PixelRect) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.surface_id, protocol.wl_surface_damage_buffer);
    try msg.putI32(@intCast(rect.x));
    try msg.putI32(@intCast(rect.y));
    try msg.putI32(@intCast(rect.w));
    try msg.putI32(@intCast(rect.h));
    return msg.finish();
}

pub fn makePong(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.wm_base_id, protocol.xdg_wm_base_pong);
    try msg.putU32(serial);
    return msg.finish();
}

pub fn makeAckConfigure(buffer: []u8, serial: u32) ![]const u8 {
    var msg = try protocol.MessageWriter.init(buffer, protocol.xdg_surface_id, protocol.xdg_surface_ack_configure);
    try msg.putU32(serial);
    return msg.finish();
}

pub fn nextMessage(buffer: []const u8) ?protocol.Message {
    if (buffer.len < 8) return null;
    const object_id = std.mem.readInt(u32, buffer[0..4], .little);
    const opcode = std.mem.readInt(u16, buffer[4..6], .little);
    const size = std.mem.readInt(u16, buffer[6..8], .little);
    if (size < 8 or size > buffer.len) return null;
    return .{ .object_id = object_id, .opcode = opcode, .payload = buffer[8..size] };
}

pub fn handleMessage(state: *protocol.WaylandState, kind: protocol.ObjectKind, message: protocol.Message) !void {
    switch (kind) {
        .display => if (message.opcode == protocol.wl_display_error_event) {
            printDisplayError(message.payload);
            return error.WaylandProtocolError;
        },
        .registry => if (message.opcode == protocol.wl_registry_global_event) {
            const global = try parseRegistryGlobal(message.payload);
            try state.registry.add(global);
        },
        .callback => {
            if (message.opcode == protocol.wl_callback_done_event) state.registry_done = true;
        },
        .wm_base => if (message.opcode == protocol.xdg_wm_base_ping_event) {},
        .xdg_surface => {
            if (message.opcode == protocol.xdg_surface_configure_event) state.configured = true;
        },
        .xdg_toplevel => {
            if (message.opcode == protocol.xdg_toplevel_configure_event) {
                if (message.payload.len < 8) return error.InvalidWaylandMessage;
                const width = std.mem.readInt(i32, message.payload[0..4], .little);
                const height = std.mem.readInt(i32, message.payload[4..8], .little);
                if (width > 0) state.configured_width = @intCast(width);
                if (height > 0) state.configured_height = @intCast(height);
            }
            if (message.opcode == protocol.xdg_toplevel_close_event) state.closed = true;
        },
        .seat => {
            if (message.opcode == protocol.wl_seat_capabilities_event) {
                if (message.payload.len < 4) return error.InvalidWaylandMessage;
                const capabilities = std.mem.readInt(u32, message.payload[0..4], .little);
                state.seat_has_pointer = (capabilities & protocol.wl_seat_capability_pointer) != 0;
            }
        },
        else => {},
    }
}

fn printDisplayError(payload: []const u8) void {
    if (payload.len < 12) {
        std.debug.print("wayland error: truncated display error\n", .{});
        return;
    }
    const object_id = std.mem.readInt(u32, payload[0..4], .little);
    const code = std.mem.readInt(u32, payload[4..8], .little);
    const wire_len = std.mem.readInt(u32, payload[8..12], .little);
    if (wire_len == 0 or 12 + wire_len > payload.len) {
        std.debug.print("wayland error: object {d} code {d}\n", .{ object_id, code });
        return;
    }
    const raw = payload[12 .. 12 + wire_len - 1];
    std.debug.print("wayland error: object {d} code {d}: {s}\n", .{ object_id, code, raw });
}

pub fn parseRegistryGlobal(payload: []const u8) !protocol.RegistryGlobal {
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

pub fn registryInterface(value: []const u8) protocol.RegistryInterface {
    if (bytes_mod.eql(value, "wl_compositor")) return .compositor;
    if (bytes_mod.eql(value, "wl_shm")) return .shm;
    if (bytes_mod.eql(value, "xdg_wm_base")) return .wm_base;
    if (bytes_mod.eql(value, "wl_seat")) return .seat;
    if (bytes_mod.eql(value, "zwp_linux_dmabuf_v1")) return .linux_dmabuf;
    if (bytes_mod.eql(value, "zxdg_decoration_manager_v1")) return .xdg_decoration_manager;
    return .other;
}

pub fn writeAll(fd: posix.fd_t, bytes: []const u8) !void {
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

pub fn sendFd(socket_fd: posix.fd_t, bytes: []const u8, fd: posix.fd_t) !void {
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

pub fn truncateFd(fd: posix.fd_t, size: usize) !void {
    const rc = linux.ftruncate(fd, @intCast(size));
    switch (posix.errno(rc)) {
        .SUCCESS => {},
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn paddedLen(len: u32) usize {
    return (@as(usize, len) + 3) & ~@as(usize, 3);
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

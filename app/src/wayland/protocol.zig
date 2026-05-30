const std = @import("std");
const renderer_native_present = @import("../render/native_present.zig");
const renderer_gpu_buffer = @import("../render/gpu_buffer.zig");
const linux_drm = @import("../linux_drm.zig");

pub const display_id: u32 = 1;
pub const registry_id: u32 = 2;
pub const sync_callback_id: u32 = 3;
pub const compositor_id: u32 = 4;
pub const shm_id: u32 = 5;
pub const wm_base_id: u32 = 6;
pub const seat_id: u32 = 7;
pub const pointer_id: u32 = 8;
pub const surface_id: u32 = 9;
pub const xdg_surface_id: u32 = 10;
pub const xdg_toplevel_id: u32 = 11;
pub const shm_pool_id: u32 = 12;
pub const wl_buffer_id: u32 = 13;
pub const linux_dmabuf_id: u32 = 14;
pub const dmabuf_params_id: u32 = 15;
pub const dmabuf_wl_buffer_id: u32 = 16;
pub const xdg_decoration_manager_id: u32 = 17;
pub const xdg_toplevel_decoration_id: u32 = 18;

pub const wl_display_sync: u16 = 0;
pub const wl_display_get_registry: u16 = 1;
pub const wl_registry_bind: u16 = 0;
pub const wl_compositor_create_surface: u16 = 0;
pub const wl_seat_get_pointer: u16 = 0;
pub const wl_pointer_set_cursor: u16 = 0;
pub const wl_shm_create_pool: u16 = 0;
pub const wl_shm_pool_create_buffer: u16 = 0;
pub const wl_shm_pool_destroy: u16 = 1;
pub const wl_surface_attach: u16 = 1;
pub const wl_surface_damage_buffer: u16 = 9;
pub const wl_surface_commit: u16 = 6;
pub const xdg_wm_base_get_xdg_surface: u16 = 2;
pub const xdg_wm_base_pong: u16 = 3;
pub const xdg_surface_get_toplevel: u16 = 1;
pub const xdg_surface_ack_configure: u16 = 4;
pub const xdg_toplevel_set_title: u16 = 2;
pub const xdg_toplevel_set_app_id: u16 = 3;
pub const xdg_toplevel_move: u16 = 5;
pub const xdg_toplevel_set_minimized: u16 = 13;
pub const xdg_decoration_manager_get_toplevel_decoration: u16 = 1;
pub const xdg_toplevel_decoration_set_mode: u16 = 1;
pub const zwp_linux_dmabuf_create_params: u16 = 1;
pub const zwp_linux_buffer_params_add: u16 = 1;
pub const zwp_linux_buffer_params_create_immed: u16 = 3;

pub const wl_display_error_event: u16 = 0;
pub const wl_registry_global_event: u16 = 0;
pub const wl_callback_done_event: u16 = 0;
pub const wl_pointer_enter_event: u16 = 0;
pub const wl_pointer_leave_event: u16 = 1;
pub const wl_pointer_motion_event: u16 = 2;
pub const wl_pointer_button_event: u16 = 3;
pub const wl_pointer_axis_event: u16 = 4;
pub const wl_seat_capabilities_event: u16 = 0;
pub const xdg_wm_base_ping_event: u16 = 0;
pub const xdg_surface_configure_event: u16 = 0;
pub const xdg_toplevel_close_event: u16 = 1;

pub const wl_shm_format_xrgb8888: u32 = 1;
pub const drm_format_xrgb8888: u32 = 0x34325258;
pub const drm_format_argb8888: u32 = 0x34325241;
pub const dmabuf_flags_none: u32 = 0;
pub const wl_pointer_button_left: u32 = 0x110;
pub const wl_pointer_button_released: u32 = 0;
pub const wl_pointer_axis_vertical_scroll: u32 = 0;
pub const wl_seat_capability_pointer: u32 = 1;
pub const xdg_toplevel_decoration_mode_server_side: u32 = 2;

pub const fixed_scale: f32 = 256.0;

pub const client_decor_h: f32 = 34.0;
pub const client_decor_button_size: f32 = 24.0;
pub const client_decor_button_gap: f32 = 8.0;
pub const client_decor_icon_size: f32 = 14.0;
pub const client_decor_minimize_w: f32 = 10.0;
pub const client_decor_minimize_h: f32 = 2.0;
pub const client_decor_close_id: u32 = 40_000;
pub const client_decor_minimize_id: u32 = 40_001;
pub const client_decor_drag_id: u32 = 40_002;

pub const client_decor_bg = ui.Color{ .r = 24, .g = 24, .b = 27 };
pub const client_decor_border = ui.Color{ .r = 52, .g = 52, .b = 58 };
pub const client_decor_text = ui.Color{ .r = 232, .g = 232, .b = 235 };
pub const client_decor_dim = ui.Color{ .r = 156, .g = 156, .b = 164 };

const ui = @import("../ui.zig");
const posix = std.posix;

pub const ObjectKind = enum {
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

pub const RegistryInterface = enum {
    other,
    compositor,
    shm,
    wm_base,
    seat,
    linux_dmabuf,
    xdg_decoration_manager,
};

pub const RegistryGlobal = struct {
    name: u32,
    interface: RegistryInterface,
    version: u32,
};

pub const max_registry_globals: usize = 128;

pub const RegistryState = struct {
    globals: [max_registry_globals]RegistryGlobal = undefined,
    len: usize = 0,

    pub fn add(self: *RegistryState, global: RegistryGlobal) !void {
        if (self.len >= self.globals.len) return error.RegistryGlobalBudgetExceeded;
        self.globals[self.len] = global;
        self.len += 1;
    }

    pub fn find(self: RegistryState, interface: RegistryInterface) ?RegistryGlobal {
        for (self.globals[0..self.len]) |global| {
            if (global.interface == interface) return global;
        }
        return null;
    }
};

pub const WaylandState = struct {
    registry: RegistryState = .{},
    registry_done: bool = false,
    configured: bool = false,
    closed: bool = false,
    seat_has_pointer: bool = false,
    dmabuf_bound: bool = false,
};

pub const Message = struct {
    object_id: u32,
    opcode: u16,
    payload: []const u8,
};

pub const MessageWriter = struct {
    buffer: []u8,
    len: usize = 0,

    pub fn init(buffer: []u8, object_id: u32, opcode: u16) !MessageWriter {
        if (buffer.len < 8) return error.MessageBufferTooSmall;
        var self = MessageWriter{ .buffer = buffer, .len = 8 };
        std.mem.writeInt(u32, self.buffer[0..4], object_id, .little);
        std.mem.writeInt(u16, self.buffer[4..6], opcode, .little);
        return self;
    }

    pub fn putU32(self: *MessageWriter, value: u32) !void {
        try self.reserve(4);
        std.mem.writeInt(u32, self.buffer[self.len..][0..4], value, .little);
        self.len += 4;
    }

    pub fn putI32(self: *MessageWriter, value: i32) !void {
        try self.putU32(@bitCast(value));
    }

    pub fn putString(self: *MessageWriter, value: []const u8) !void {
        const wire_len: u32 = @intCast(value.len + 1);
        try self.putU32(wire_len);
        try self.reserve(paddedLen(wire_len));
        @memcpy(self.buffer[self.len..][0..value.len], value);
        self.buffer[self.len + value.len] = 0;
        @memset(self.buffer[self.len + value.len + 1 .. self.len + paddedLen(wire_len)], 0);
        self.len += paddedLen(wire_len);
    }

    pub fn finish(self: *MessageWriter) []const u8 {
        std.mem.writeInt(u16, self.buffer[6..8], @intCast(self.len), .little);
        return self.buffer[0..self.len];
    }

    fn reserve(self: MessageWriter, count: usize) !void {
        if (self.len + count > self.buffer.len) return error.MessageBufferTooSmall;
    }
};

fn paddedLen(len: u32) usize {
    return (@as(usize, len) + 3) & ~@as(usize, 3);
}

pub const PixelRect = struct {
    x: usize,
    y: usize,
    w: usize,
    h: usize,

    pub fn valid(self: PixelRect) bool {
        return self.w != 0 and self.h != 0;
    }
};

pub const DmabufImport = struct {
    fd: posix.fd_t,
    width: u32,
    height: u32,
    stride: u32,
    format: u32 = drm_format_xrgb8888,
    offset: u32 = 0,
    plane_index: u32 = 0,
    modifier: u64 = 0,

    pub fn valid(self: DmabufImport) bool {
        return self.fd >= 0 and
            self.width != 0 and
            self.height != 0 and
            self.stride >= self.width * @sizeOf(u32) and
            isSupportedDmabufFormat(self.format);
    }

    pub fn fromNativeSurface(surface: renderer_native_present.NativeSurface) !DmabufImport {
        return switch (surface) {
            .drm => error.UnsupportedDmabufSurface,
            .wayland => |value| fromWaylandSurface(value),
        };
    }

    fn fromWaylandSurface(surface: renderer_native_present.WaylandSurface) !DmabufImport {
        const gpu_buffer = surface.gpu_buffer orelse return error.InvalidDmabufImport;
        if (gpu_buffer.kind != .dma_buf or gpu_buffer.plane_count != 1) return error.InvalidDmabufImport;
        if (gpu_buffer.handle > @as(u64, 2147483647)) return error.InvalidDmabufImport;
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

pub fn isSupportedDmabufFormat(format: u32) bool {
    return switch (format) {
        drm_format_xrgb8888,
        drm_format_argb8888,
        => true,
        else => false,
    };
}

pub fn dmabufFormat(format: renderer_native_present.PixelFormat) u32 {
    return switch (format) {
        .xrgb8888 => drm_format_xrgb8888,
        .argb8888 => drm_format_argb8888,
    };
}

pub const ShmBuffer = struct {
    fd: posix.fd_t,
    memory: []align(std.heap.page_size_min) u8,
    width: u32,
    height: u32,
    stride: u32,

    pub fn deinit(self: ShmBuffer) void {
        posix.munmap(self.memory);
        closeFd(self.fd);
    }
};

pub fn closeFd(fd: posix.fd_t) void {
    const linux = std.os.linux;
    switch (posix.errno(linux.close(fd))) {
        .SUCCESS => {},
        .INTR => {},
        else => {},
    }
}

const std = @import("std");
const renderer_native_present = @import("renderer_native_present.zig");

const linux = std.os.linux;
const posix = std.posix;

pub const default_device_path = "/dev/dri/card0";

const drm_ioctl_mode_create_dumb: u32 = 0xc02064b2;
const drm_ioctl_mode_map_dumb: u32 = 0xc01064b3;
const drm_ioctl_mode_destroy_dumb: u32 = 0xc00464b4;
const drm_ioctl_prime_handle_to_fd: u32 = 0xc00c642d;

const drm_prime_flag_rdwr: u32 = 0x00000002;
const drm_prime_flag_cloexec: u32 = 0x00080000;
const xrgb8888_bits_per_pixel: u32 = 32;
const argb8888_bits_per_pixel: u32 = 32;
const bytes_per_pixel: u32 = 4;

pub const Error = error{
    InvalidBufferSize,
    InvalidPitch,
    DrmOpenFailed,
    DrmCreateDumbFailed,
    DrmMapDumbFailed,
    DrmPrimeExportFailed,
    DrmDestroyDumbFailed,
};

const DrmModeCreateDumb = extern struct {
    height: u32,
    width: u32,
    bpp: u32,
    flags: u32,
    handle: u32,
    pitch: u32,
    size: u64,
};

const DrmModeMapDumb = extern struct {
    handle: u32,
    pad: u32,
    offset: u64,
};

const DrmModeDestroyDumb = extern struct {
    handle: u32,
};

const DrmPrimeHandleToFd = extern struct {
    handle: u32,
    flags: u32,
    fd: i32,
};

pub const DumbBuffer = struct {
    drm_fd: posix.fd_t,
    dma_buf_fd: posix.fd_t,
    handle: u32,
    width: u32,
    height: u32,
    pitch_bytes: u32,
    size: u64,
    mapped: ?[]align(std.heap.page_size_min) u8 = null,

    pub fn createExported(path: []const u8, width: u32, height: u32, format: renderer_native_present.PixelFormat) Error!DumbBuffer {
        const request = createRequest(width, height, format) orelse return error.InvalidBufferSize;
        const drm_fd = posix.openat(posix.AT.FDCWD, path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch return error.DrmOpenFailed;
        errdefer closeFd(drm_fd);
        return createExportedFromFd(drm_fd, request);
    }

    pub fn deinit(self: *DumbBuffer) void {
        if (self.mapped) |memory| {
            posix.munmap(memory);
            self.mapped = null;
        }
        if (self.dma_buf_fd >= 0) {
            closeFd(self.dma_buf_fd);
            self.dma_buf_fd = -1;
        }
        if (self.handle != 0 and self.drm_fd >= 0) {
            var destroy = DrmModeDestroyDumb{ .handle = self.handle };
            _ = ioctl(self.drm_fd, drm_ioctl_mode_destroy_dumb, @intFromPtr(&destroy));
            self.handle = 0;
        }
        if (self.drm_fd >= 0) {
            closeFd(self.drm_fd);
            self.drm_fd = -1;
        }
    }

    pub fn map(self: *DumbBuffer) Error![]u8 {
        if (self.mapped) |memory| return memory;
        if (self.size > std.math.maxInt(usize)) return error.InvalidBufferSize;
        var request = DrmModeMapDumb{ .handle = self.handle, .pad = 0, .offset = 0 };
        try ioctlOk(self.drm_fd, drm_ioctl_mode_map_dumb, @intFromPtr(&request), error.DrmMapDumbFailed);
        const memory = posix.mmap(
            null,
            @intCast(self.size),
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = .SHARED },
            self.drm_fd,
            request.offset,
        ) catch return error.DrmMapDumbFailed;
        self.mapped = memory;
        return memory;
    }

    pub fn stridePixels(self: DumbBuffer) Error!u32 {
        if (self.pitch_bytes % bytes_per_pixel != 0) return error.InvalidPitch;
        return self.pitch_bytes / bytes_per_pixel;
    }
};

const CreateRequest = struct {
    width: u32,
    height: u32,
    bpp: u32,
};

fn createExportedFromFd(drm_fd: posix.fd_t, request: CreateRequest) Error!DumbBuffer {
    var create = DrmModeCreateDumb{
        .height = request.height,
        .width = request.width,
        .bpp = request.bpp,
        .flags = 0,
        .handle = 0,
        .pitch = 0,
        .size = 0,
    };
    try ioctlOk(drm_fd, drm_ioctl_mode_create_dumb, @intFromPtr(&create), error.DrmCreateDumbFailed);
    if (create.handle == 0 or create.pitch < request.width * bytes_per_pixel or create.size == 0) return error.InvalidBufferSize;

    var prime = DrmPrimeHandleToFd{
        .handle = create.handle,
        .flags = drm_prime_flag_rdwr | drm_prime_flag_cloexec,
        .fd = -1,
    };
    errdefer destroyDumb(drm_fd, create.handle);
    try ioctlOk(drm_fd, drm_ioctl_prime_handle_to_fd, @intFromPtr(&prime), error.DrmPrimeExportFailed);
    return .{
        .drm_fd = drm_fd,
        .dma_buf_fd = prime.fd,
        .handle = create.handle,
        .width = create.width,
        .height = create.height,
        .pitch_bytes = create.pitch,
        .size = create.size,
    };
}

fn createRequest(width: u32, height: u32, format: renderer_native_present.PixelFormat) ?CreateRequest {
    if (width == 0 or height == 0) return null;
    if (width > std.math.maxInt(u32) / bytes_per_pixel) return null;
    return .{
        .width = width,
        .height = height,
        .bpp = switch (format) {
            .xrgb8888 => xrgb8888_bits_per_pixel,
            .argb8888 => argb8888_bits_per_pixel,
        },
    };
}

fn destroyDumb(fd: posix.fd_t, handle: u32) void {
    var destroy = DrmModeDestroyDumb{ .handle = handle };
    _ = ioctl(fd, drm_ioctl_mode_destroy_dumb, @intFromPtr(&destroy));
}

fn ioctlOk(fd: posix.fd_t, request: u32, arg: usize, err: Error) Error!void {
    const rc = ioctl(fd, request, arg);
    if (linux.errno(rc) != .SUCCESS) return err;
}

fn ioctl(fd: posix.fd_t, request: u32, arg: usize) usize {
    return linux.ioctl(fd, request, arg);
}

fn closeFd(fd: posix.fd_t) void {
    _ = linux.close(fd);
}

test "drm dumb and prime ioctl abi constants match linux uapi" {
    try std.testing.expectEqual(@as(u32, 0xc02064b2), drm_ioctl_mode_create_dumb);
    try std.testing.expectEqual(@as(u32, 0xc01064b3), drm_ioctl_mode_map_dumb);
    try std.testing.expectEqual(@as(u32, 0xc00464b4), drm_ioctl_mode_destroy_dumb);
    try std.testing.expectEqual(@as(u32, 0xc00c642d), drm_ioctl_prime_handle_to_fd);
}

test "drm dumb and prime structs keep kernel layout sizes" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(DrmModeCreateDumb));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(DrmModeMapDumb));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(DrmModeDestroyDumb));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(DrmPrimeHandleToFd));
}

test "drm dumb create request validates dimensions and format" {
    try std.testing.expect(createRequest(640, 480, .xrgb8888) != null);
    try std.testing.expect(createRequest(640, 480, .argb8888) != null);
    try std.testing.expectEqual(@as(u32, xrgb8888_bits_per_pixel), createRequest(1, 1, .xrgb8888).?.bpp);
    try std.testing.expect(createRequest(0, 480, .xrgb8888) == null);
    try std.testing.expect(createRequest(640, 0, .xrgb8888) == null);
    try std.testing.expect(createRequest(std.math.maxInt(u32), 1, .xrgb8888) == null);
}

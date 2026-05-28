const std = @import("std");
const renderer_native_present = @import("render/native_present.zig");

const linux = std.os.linux;
const posix = std.posix;

pub const default_device_path = "/dev/dri/card0";

// ─── Ioctl constants (from kernel uapi drm.h + drm_mode.h) ────

pub const drm_ioctl_version: u32 = 0xc0406400;
pub const drm_ioctl_set_client_cap: u32 = 0x4010640d;
pub const drm_ioctl_set_master: u32 = 0x0000641e;
pub const drm_ioctl_drop_master: u32 = 0x0000641f;
pub const drm_ioctl_prime_fd_to_handle: u32 = 0xc00c642e;
pub const drm_ioctl_prime_handle_to_fd: u32 = 0xc00c642d;
pub const drm_ioctl_mode_getresources: u32 = 0xc04064a0;
pub const drm_ioctl_mode_getcrtc: u32 = 0xc06864a1;
pub const drm_ioctl_mode_setcrtc: u32 = 0xc06864a2;
pub const drm_ioctl_mode_page_flip: u32 = 0xc01864b0;
pub const drm_ioctl_mode_map_dumb: u32 = 0xc01064b3;
pub const drm_ioctl_mode_rmfb: u32 = 0xc00464af;
pub const drm_ioctl_mode_create_dumb: u32 = 0xc02064b2;
pub const drm_ioctl_mode_getconnector: u32 = 0xc05064a7;
pub const drm_ioctl_mode_addfb2: u32 = 0xc06864b8;
pub const drm_ioctl_mode_destroy_dumb: u32 = 0xc00464b4;
pub const drm_ioctl_mode_atomic: u32 = 0xc03864bc;
pub const drm_ioctl_mode_getplane: u32 = 0xc02064b6;
pub const drm_ioctl_mode_getencoder: u32 = 0xc02064a6;
pub const drm_ioctl_syncobj_create: u32 = 0xc00c644b;
pub const drm_ioctl_syncobj_destroy: u32 = 0xc004644c;
pub const drm_ioctl_syncobj_handle_to_fd: u32 = 0xc010644d;
pub const drm_ioctl_syncobj_fd_to_handle: u32 = 0xc00c644e;
pub const drm_ioctl_syncobj_timeline_wait: u32 = 0x40286457;
pub const drm_ioctl_syncobj_timeline_signal: u32 = 0x40286458;
pub const drm_ioctl_syncobj_timeline_query: u32 = 0xc018645c;
pub const drm_ioctl_syncobj_import_sync_file: u32 = 0xc008645d;
pub const drm_ioctl_syncobj_export_sync_file: u32 = 0xc008645e;
pub const drm_ioctl_syncobj_wait: u32 = 0xc018644f;
pub const drm_ioctl_syncobj_reset: u32 = 0xc0086450;
pub const drm_ioctl_syncobj_signal: u32 = 0xc0086451;

// ─── Flag constants ─────────────────────────────────────────

pub const drm_prime_flag_rdwr: u32 = 0x00000002;
pub const drm_prime_flag_cloexec: u32 = 0x00080000;
const xrgb8888_bits_per_pixel: u32 = 32;
const argb8888_bits_per_pixel: u32 = 32;
const bytes_per_pixel: u32 = 4;

pub const drm_mode_page_flip_event: u32 = 0x01;
pub const drm_mode_page_flip_async: u32 = 0x02;

pub const connector_connected: i32 = 1;
pub const connector_disconnected: i32 = 2;
pub const connector_unknown: i32 = 3;

pub const atomic_test_only: u32 = 0x01;
pub const atomic_nonblock: u32 = 0x02;
pub const atomic_allow_modeset: u32 = 0x04;

pub const client_cap_universal_planes: u64 = 2;
pub const client_cap_atomic: u64 = 3;

pub const drm_syncobj_create_signaled: u32 = 1 << 0;
pub const drm_syncobj_wait_any: u32 = 1 << 0;
pub const drm_syncobj_wait_for_submit: u32 = 1 << 1;
pub const drm_syncobj_wait_available: u32 = 1 << 2;

// ─── Error set ──────────────────────────────────────────────

pub const Error = error{
    InvalidBufferSize,
    InvalidPitch,
    DrmOpenFailed,
    DrmCreateDumbFailed,
    DrmMapDumbFailed,
    DrmPrimeExportFailed,
    DrmDestroyDumbFailed,
    DrmVersionFailed,
    DrmMasterFailed,
    DrmCapFailed,
    DrmResourceFailed,
    DrmConnectorFailed,
    DrmCrtcFailed,
    DrmSetCrtcFailed,
    DrmAddFbFailed,
    DrmRmFbFailed,
    DrmPageFlipFailed,
    DrmSyncobjCreateFailed,
    DrmSyncobjDestroyFailed,
    DrmSyncobjImportFailed,
    DrmSyncobjExportFailed,
    DrmSyncobjWaitFailed,
    DrmSyncobjSignalFailed,
    DrmAtomicFailed,
    DrmGetPlaneFailed,
    FdSizeFailed,
};

// ─── Kernel struct definitions (matching uapi drm.h/drm_mode.h) ──

pub const DrmVersion = extern struct {
    version_major: i32,
    version_minor: i32,
    version_patchlevel: i32,
    name_len: i32,
    name: ?[*]u8,
    date_len: i32,
    date: ?[*]u8,
    desc_len: i32,
    desc: ?[*]u8,
    _pad: [8]u8,
};

pub const DrmSetClientCap = extern struct {
    capability: u64,
    value: u64,
};

pub const DrmModeCardRes = extern struct {
    fb_id_ptr: ?[*]u32,
    crtc_id_ptr: ?[*]u32,
    connector_id_ptr: ?[*]u32,
    encoder_id_ptr: ?[*]u32,
    count_fbs: i32,
    count_crtcs: i32,
    count_connectors: i32,
    count_encoders: i32,
    min_width: u32,
    max_width: u32,
    min_height: u32,
    max_height: u32,
};

pub const DrmModeModeInfo = extern struct {
    clock: u32,
    hdisplay: u16,
    hsync_start: u16,
    hsync_end: u16,
    htotal: u16,
    hskew: u16,
    vdisplay: u16,
    vsync_start: u16,
    vsync_end: u16,
    vtotal: u16,
    vscan: u16,
    vrefresh: u32,
    flags: u32,
    type_: u32,
    name: [32]u8,
};

pub const DrmModeGetConnector = extern struct {
    encoders_ptr: ?[*]u32,
    modes_ptr: ?[*]DrmModeModeInfo,
    props_ptr: ?[*]u32,
    prop_values_ptr: ?[*]u64,
    count_modes: i32,
    count_props: i32,
    count_encoders: i32,
    encoder_id: u32,
    connector_id: u32,
    connector_type: u32,
    connector_type_id: i32,
    connection: i32,
    mm_width: u32,
    mm_height: u32,
    subpixel: i32,
    pad: u32,
};

pub const DrmModeCrtc = extern struct {
    set_connectors_ptr: ?[*]u32,
    count_connectors: u32,
    crtc_id: u32,
    fb_id: u32,
    x: u32,
    y: u32,
    gamma_size: u32,
    mode_valid: u32,
    mode: DrmModeModeInfo,
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

pub const DrmModeMapDumb = extern struct {
    handle: u32,
    pad: u32,
    offset: u64,
};

pub const DrmModeDestroyDumb = extern struct {
    handle: u32,
};

pub const DrmModeFbCmd2 = extern struct {
    fb_id: u32,
    width: u32,
    height: u32,
    pixel_format: u32,
    flags: u32,
    handles: [4]u32,
    pitches: [4]u32,
    offsets: [4]u32,
    modifier: [4]u64,
    _pad: [4]u8,
};

pub const DrmModePageFlip = extern struct {
    crtc_id: u32,
    fb_id: u32,
    flags: u32,
    reserved: u32,
    user_data: u64,
};

pub const DrmPrimeHandleToFd = extern struct {
    handle: u32,
    flags: u32,
    fd: i32,
};

pub const DrmPrimeFdToHandle = extern struct {
    fd: i32,
    handle: u32,
    pad: u32,
};

pub const DrmModeAtomic = extern struct {
    flags: u32,
    count_objs: u32,
    objs_ptr: ?[*]u32,
    count_props_ptr: ?[*]u32,
    props_ptr: ?[*]u32,
    prop_values_ptr: ?[*]u64,
    reserved: u64,
    user_data: u64,
};

pub const DrmModeEncoder = extern struct {
    encoder_id: u32,
    encoder_type: u32,
    crtc_id: u32,
    possible_crtcs: u32,
    possible_clones: u32,
};

pub const DrmModeGetPlaneRes = extern struct {
    plane_id_ptr: ?[*]u32,
    count_planes: u32,
    pad: u32,
};

// ─── Syncobj structs ────────────────────────────────────────

pub const DrmSyncobjCreate = extern struct {
    flags: u32,
    handle: u32,
};

pub const DrmSyncobjDestroy = extern struct {
    handle: u32,
    pad: u32,
};

pub const DrmSyncobjFdToHandle = extern struct {
    fd: i32,
    handle: u32,
};

pub const DrmSyncobjImportSyncFile = extern struct {
    handle: u32,
    fd: i32,
};

pub const DrmSyncobjExportSyncFile = extern struct {
    handle: u32,
    fd: i32,
};

pub const DrmSyncobjTimelineWait = extern struct {
    handles_ptr: [*]u32,
    timelines_ptr: [*]u64,
    timeout_nsec: u64,
    flags: u32,
    count_handles: u32,
    pad: [8]u8,
};

pub const DrmSyncobjTimelineSignal = extern struct {
    handles_ptr: [*]u32,
    timelines_ptr: [*]u64,
    count_handles: u32,
    flags: u32,
};

// ─── Higher-level result types ──────────────────────────────

pub const DrmResources = struct {
    crtcs: []u32,
    connectors: []u32,
    encoders: []u32,
    fbs: []u32,
    count_connectors: i32,
    count_crtcs: i32,
    count_encoders: i32,
    count_fbs: i32,
    min_width: u32,
    max_width: u32,
    min_height: u32,
    max_height: u32,
};

pub const DrmConnector = struct {
    connector_id: u32,
    encoder_id: u32,
    connector_type: u32,
    connector_type_id: i32,
    connection: i32,
    subpixel: i32,
    mm_width: u32,
    mm_height: u32,
    encoder_ids: []u32,
    modes: []DrmModeModeInfo,
    prop_ids: []u32,
    prop_values: []u64,
};

pub const DrmCrtcInfo = struct {
    crtc_id: u32,
    fb_id: u32,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    mode_valid: u32,
    mode: DrmModeModeInfo,
    gamma_size: u32,
};

pub const OutputInfo = struct {
    connector_id: u32,
    crtc_id: u32,
    fb_id: u32,
    mode: DrmModeModeInfo,
    width: u32,
    height: u32,
    refresh_mhz: u32,
};

const CreateRequest = struct {
    width: u32,
    height: u32,
    bpp: u32,
};

// ─── Public API ─────────────────────────────────────────────

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
            _ = drmIoctl(self.drm_fd, drm_ioctl_mode_destroy_dumb, @intFromPtr(&destroy));
            self.handle = 0;
        }
        if (self.drm_fd >= 0) {
            closeFd(self.drm_fd);
            self.drm_fd = -1;
        }
    }

    pub fn map(self: *DumbBuffer) Error![]u8 {
        if (self.mapped) |memory| return memory;
        if (self.size > ~@as(usize, 0)) return error.InvalidBufferSize;
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

/// Open a DRM device by path and return its fd.
pub fn openDevice(path: []const u8) Error!posix.fd_t {
    const fd = posix.openat(posix.AT.FDCWD, path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch return error.DrmOpenFailed;
    return fd;
}

/// Query DRM driver version.
pub fn getVersion(fd: posix.fd_t) Error!DrmVersion {
    var ver = DrmVersion{
        .version_major = 0,
        .version_minor = 0,
        .version_patchlevel = 0,
        .name_len = 0,
        .name = null,
        .date_len = 0,
        .date = null,
        .desc_len = 0,
        .desc = null,
        ._pad = [_]u8{0} ** 8,
    };
    try ioctlOk(fd, drm_ioctl_version, @intFromPtr(&ver), error.DrmVersionFailed);
    return ver;
}

/// Set DRM master.
pub fn setMaster(fd: posix.fd_t) Error!void {
    try ioctlOk(fd, drm_ioctl_set_master, 0, error.DrmMasterFailed);
}

/// Drop DRM master.
pub fn dropMaster(fd: posix.fd_t) Error!void {
    try ioctlOk(fd, drm_ioctl_drop_master, 0, error.DrmMasterFailed);
}

/// Set a client capability.
pub fn setClientCap(fd: posix.fd_t, cap: u64, value: u64) Error!void {
    var cc = DrmSetClientCap{ .capability = cap, .value = value };
    try ioctlOk(fd, drm_ioctl_set_client_cap, @intFromPtr(&cc), error.DrmCapFailed);
}

/// Get DRM resources (CRTC, connector, encoder, FB IDs).
pub fn getResources(fd: posix.fd_t) Error!DrmResources {
    var res = DrmModeCardRes{
        .fb_id_ptr = null,
        .crtc_id_ptr = null,
        .connector_id_ptr = null,
        .encoder_id_ptr = null,
        .count_fbs = 0,
        .count_crtcs = 0,
        .count_connectors = 0,
        .count_encoders = 0,
        .min_width = 0,
        .max_width = 0,
        .min_height = 0,
        .max_height = 0,
    };
    try ioctlOk(fd, drm_ioctl_mode_getresources, @intFromPtr(&res), error.DrmResourceFailed);
    const crtc_count = @as(usize, @intCast(@max(res.count_crtcs, 0)));
    const connector_count = @as(usize, @intCast(@max(res.count_connectors, 0)));
    const encoder_count = @as(usize, @intCast(@max(res.count_encoders, 0)));
    const fb_count = @as(usize, @intCast(@max(res.count_fbs, 0)));
    const allocator = std.heap.page_allocator;
    const crtcs = allocator.alloc(u32, crtc_count) catch return error.DrmResourceFailed;
    const connectors = allocator.alloc(u32, connector_count) catch {
        allocator.free(crtcs);
        return error.DrmResourceFailed;
    };
    const encoders = allocator.alloc(u32, encoder_count) catch {
        allocator.free(crtcs);
        allocator.free(connectors);
        return error.DrmResourceFailed;
    };
    const fbs = allocator.alloc(u32, fb_count) catch {
        allocator.free(crtcs);
        allocator.free(connectors);
        allocator.free(encoders);
        return error.DrmResourceFailed;
    };
    res.crtc_id_ptr = crtcs.ptr;
    res.connector_id_ptr = connectors.ptr;
    res.encoder_id_ptr = encoders.ptr;
    res.fb_id_ptr = fbs.ptr;
    try ioctlOk(fd, drm_ioctl_mode_getresources, @intFromPtr(&res), error.DrmResourceFailed);
    return .{
        .crtcs = crtcs,
        .connectors = connectors,
        .encoders = encoders,
        .fbs = fbs,
        .count_connectors = res.count_connectors,
        .count_crtcs = res.count_crtcs,
        .count_encoders = res.count_encoders,
        .count_fbs = res.count_fbs,
        .min_width = res.min_width,
        .max_width = res.max_width,
        .min_height = res.min_height,
        .max_height = res.max_height,
    };
}

/// Query connector info including modes.
pub fn getConnector(fd: posix.fd_t, connector_id: u32) Error!DrmConnector {
    var conn = DrmModeGetConnector{
        .connector_id = connector_id,
        .encoders_ptr = null,
        .modes_ptr = null,
        .props_ptr = null,
        .prop_values_ptr = null,
        .count_modes = 0,
        .count_props = 0,
        .count_encoders = 0,
        .encoder_id = 0,
        .connector_type = 0,
        .connector_type_id = 0,
        .connection = 0,
        .mm_width = 0,
        .mm_height = 0,
        .subpixel = 0,
        .pad = 0,
    };
    try ioctlOk(fd, drm_ioctl_mode_getconnector, @intFromPtr(&conn), error.DrmConnectorFailed);
    const num_modes = @as(usize, @intCast(@max(conn.count_modes, 0)));
    const num_encoders = @as(usize, @intCast(@max(conn.count_encoders, 0)));
    const num_props = @as(usize, @intCast(@max(conn.count_props, 0)));
    const allocator = std.heap.page_allocator;
    const modes = allocator.alloc(DrmModeModeInfo, num_modes) catch return error.DrmConnectorFailed;
    const encoder_ids = allocator.alloc(u32, num_encoders) catch {
        allocator.free(modes);
        return error.DrmConnectorFailed;
    };
    const prop_ids = allocator.alloc(u32, num_props) catch {
        allocator.free(modes);
        allocator.free(encoder_ids);
        return error.DrmConnectorFailed;
    };
    const prop_values = allocator.alloc(u64, num_props) catch {
        allocator.free(modes);
        allocator.free(encoder_ids);
        allocator.free(prop_ids);
        return error.DrmConnectorFailed;
    };
    conn.modes_ptr = modes.ptr;
    conn.encoders_ptr = encoder_ids.ptr;
    conn.props_ptr = prop_ids.ptr;
    conn.prop_values_ptr = prop_values.ptr;
    try ioctlOk(fd, drm_ioctl_mode_getconnector, @intFromPtr(&conn), error.DrmConnectorFailed);
    return .{
        .connector_id = conn.connector_id,
        .encoder_id = conn.encoder_id,
        .connector_type = conn.connector_type,
        .connector_type_id = conn.connector_type_id,
        .connection = conn.connection,
        .subpixel = conn.subpixel,
        .mm_width = conn.mm_width,
        .mm_height = conn.mm_height,
        .encoder_ids = encoder_ids,
        .modes = modes,
        .prop_ids = prop_ids,
        .prop_values = prop_values,
    };
}

/// Get CRTC info.
pub fn getCrtc(fd: posix.fd_t, crtc_id: u32) Error!DrmCrtcInfo {
    var crtc = DrmModeCrtc{
        .set_connectors_ptr = null,
        .count_connectors = 0,
        .crtc_id = crtc_id,
        .fb_id = 0,
        .x = 0,
        .y = 0,
        .gamma_size = 0,
        .mode_valid = 0,
        .mode = undefined,
    };
    try ioctlOk(fd, drm_ioctl_mode_getcrtc, @intFromPtr(&crtc), error.DrmCrtcFailed);
    return .{
        .crtc_id = crtc.crtc_id,
        .fb_id = crtc.fb_id,
        .x = crtc.x,
        .y = crtc.y,
        .width = crtc.mode.hdisplay,
        .height = crtc.mode.vdisplay,
        .mode_valid = crtc.mode_valid,
        .mode = crtc.mode,
        .gamma_size = crtc.gamma_size,
    };
}

/// Get encoder info.
pub fn getEncoder(fd: posix.fd_t, encoder_id: u32) Error!DrmModeEncoder {
    var enc = DrmModeEncoder{
        .encoder_id = encoder_id,
        .encoder_type = 0,
        .crtc_id = 0,
        .possible_crtcs = 0,
        .possible_clones = 0,
    };
    try ioctlOk(fd, drm_ioctl_mode_getencoder, @intFromPtr(&enc), error.DrmVersionFailed);
    return enc;
}

/// Get plane resources (returns list of plane IDs).
pub fn getPlaneResources(fd: posix.fd_t) Error![]u32 {
    var res = DrmModeGetPlaneRes{
        .plane_id_ptr = null,
        .count_planes = 0,
        .pad = 0,
    };
    try ioctlOk(fd, drm_ioctl_mode_getplane, @intFromPtr(&res), error.DrmGetPlaneFailed);
    const count = @as(usize, @intCast(@max(res.count_planes, 0)));
    const allocator = std.heap.page_allocator;
    const planes = allocator.alloc(u32, count) catch return error.DrmGetPlaneFailed;
    res.plane_id_ptr = planes.ptr;
    try ioctlOk(fd, drm_ioctl_mode_getplane, @intFromPtr(&res), error.DrmGetPlaneFailed);
    return planes;
}

/// Add a framebuffer (FB2) from a dumb buffer handle.
pub fn addFb2(fd: posix.fd_t, handle: u32, width: u32, height: u32, pitch: u32, pixel_format: u32) Error!u32 {
    var fb = DrmModeFbCmd2{
        .fb_id = 0,
        .width = width,
        .height = height,
        .pixel_format = pixel_format,
        .flags = 0,
        .handles = [4]u32{ handle, 0, 0, 0 },
        .pitches = [4]u32{ pitch, 0, 0, 0 },
        .offsets = [4]u32{ 0, 0, 0, 0 },
        .modifier = [4]u64{ 0, 0, 0, 0 },
        ._pad = [4]u8{ 0, 0, 0, 0 },
    };
    try ioctlOk(fd, drm_ioctl_mode_addfb2, @intFromPtr(&fb), error.DrmAddFbFailed);
    return fb.fb_id;
}

/// Remove a framebuffer.
pub fn rmfb(fd: posix.fd_t, fb_id: u32) Error!void {
    var id = fb_id;
    try ioctlOk(fd, drm_ioctl_mode_rmfb, @intFromPtr(&id), error.DrmRmFbFailed);
}

/// Set CRTC mode (legacy mode setting).
pub fn setCrtc(fd: posix.fd_t, crtc_id: u32, fb_id: u32, connector_id: u32, mode: *const DrmModeModeInfo) Error!void {
    var set = DrmModeCrtc{
        .set_connectors_ptr = @ptrCast(@constCast(&connector_id)),
        .count_connectors = 1,
        .crtc_id = crtc_id,
        .fb_id = fb_id,
        .x = 0,
        .y = 0,
        .gamma_size = 0,
        .mode_valid = 1,
        .mode = mode.*,
    };
    try ioctlOk(fd, drm_ioctl_mode_setcrtc, @intFromPtr(&set), error.DrmSetCrtcFailed);
}

/// Queue a page flip.
pub fn pageFlip(fd: posix.fd_t, crtc_id: u32, fb_id: u32, flags: u32, user_data: u64) Error!void {
    var flip = DrmModePageFlip{
        .crtc_id = crtc_id,
        .fb_id = fb_id,
        .flags = flags,
        .reserved = 0,
        .user_data = user_data,
    };
    try ioctlOk(fd, drm_ioctl_mode_page_flip, @intFromPtr(&flip), error.DrmPageFlipFailed);
}

/// Read pending DRM events from the fd.
pub fn readEvents(fd: posix.fd_t) Error!std.ArrayListUnmanaged(struct { type_: u32, user_data: u64 }) {
    var events = std.ArrayListUnmanaged(struct { type_: u32, user_data: u64 }){};
    var buf: [8]u8 = undefined;
    while (true) {
        const n = linux.read(fd, &buf, buf.len);
        if (linux.errno(n) != .SUCCESS and n != 0) {
            if (linux.getErrno(n) == .AGAIN) break;
            return error.DrmResourceFailed;
        }
        if (n == 0) break;
        const type_ = std.mem.readInt(u32, buf[0..4], .little);
        const length = std.mem.readInt(u32, buf[4..8], .little);
        if (length < 8) break;
        var rest: [1024]u8 = undefined;
        const to_read = @min(length - 8, rest.len);
        const rn = linux.read(fd, rest[0..to_read], to_read);
        if (linux.errno(rn) != .SUCCESS) break;
        if (type_ == 0x01) {
            const user_data = std.mem.readInt(u64, rest[0..8], .little);
            events.append(std.heap.page_allocator, .{ .type_ = type_, .user_data = user_data }) catch break;
        }
    }
    return events;
}

// ─── Syncobj API ────────────────────────────────────────────

pub fn syncobjCreate(fd: posix.fd_t, flags: u32) Error!u32 {
    var create = DrmSyncobjCreate{ .flags = flags, .handle = 0 };
    try ioctlOk(fd, drm_ioctl_syncobj_create, @intFromPtr(&create), error.DrmSyncobjCreateFailed);
    return create.handle;
}

pub fn syncobjDestroy(fd: posix.fd_t, handle: u32) Error!void {
    var destroy = DrmSyncobjDestroy{ .handle = handle, .pad = 0 };
    try ioctlOk(fd, drm_ioctl_syncobj_destroy, @intFromPtr(&destroy), error.DrmSyncobjDestroyFailed);
}

pub fn syncobjImportSyncFile(fd: posix.fd_t, syncobj_handle: u32, sync_file_fd: i32) Error!void {
    var import = DrmSyncobjImportSyncFile{ .handle = syncobj_handle, .fd = sync_file_fd };
    try ioctlOk(fd, drm_ioctl_syncobj_import_sync_file, @intFromPtr(&import), error.DrmSyncobjImportFailed);
}

pub fn syncobjExportSyncFile(fd: posix.fd_t, syncobj_handle: u32) Error!i32 {
    var exp = DrmSyncobjExportSyncFile{ .handle = syncobj_handle, .fd = -1 };
    try ioctlOk(fd, drm_ioctl_syncobj_export_sync_file, @intFromPtr(&exp), error.DrmSyncobjExportFailed);
    return exp.fd;
}

pub fn syncobjTimelineWait(fd: posix.fd_t, syncobj_handle: u32, point: u64, timeout_nsec: u64, flags: u32) Error!void {
    var wait = DrmSyncobjTimelineWait{
        .handles_ptr = @ptrCast(@constCast(&syncobj_handle)),
        .timelines_ptr = @ptrCast(@constCast(&point)),
        .timeout_nsec = timeout_nsec,
        .flags = flags,
        .count_handles = 1,
        .pad = [_]u8{0} ** 8,
    };
    try ioctlOk(fd, drm_ioctl_syncobj_timeline_wait, @intFromPtr(&wait), error.DrmSyncobjWaitFailed);
}

pub fn syncobjTimelineSignal(fd: posix.fd_t, syncobj_handle: u32, point: u64) Error!void {
    var signal = DrmSyncobjTimelineSignal{
        .handles_ptr = @ptrCast(@constCast(&syncobj_handle)),
        .timelines_ptr = @ptrCast(@constCast(&point)),
        .count_handles = 1,
        .flags = 0,
    };
    try ioctlOk(fd, drm_ioctl_syncobj_timeline_signal, @intFromPtr(&signal), error.DrmSyncobjSignalFailed);
}

pub fn syncobjFdToHandle(fd: posix.fd_t, syncobj_fd: i32) Error!u32 {
    var import = DrmSyncobjFdToHandle{ .fd = syncobj_fd, .handle = 0 };
    try ioctlOk(fd, drm_ioctl_syncobj_fd_to_handle, @intFromPtr(&import), error.DrmSyncobjImportFailed);
    return import.handle;
}

// ─── Utilities ──────────────────────────────────────────────

/// Find available DRM card devices.
pub fn findCardDevices(allocator: std.mem.Allocator) ![][:0]u8 {
    var dir = std.fs.openDirAbsolute("/dev/dri", .{ .iterate = true }) catch return &[][:0]u8{};
    defer dir.close();
    var devices = std.ArrayList([:0]u8).init(allocator);
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file and entry.kind != .character_device) continue;
        if (std.mem.startsWith(u8, entry.name, "card") and std.mem.indexOfScalar(u8, entry.name, '-') == null) {
            const full = std.fmt.allocPrintZ(allocator, "/dev/dri/{s}", .{entry.name}) catch continue;
            devices.append(full) catch continue;
        }
    }
    return devices.toOwnedSlice();
}

/// Find render nodes.
pub fn findRenderDevices(allocator: std.mem.Allocator) ![][:0]u8 {
    var dir = std.fs.openDirAbsolute("/dev/dri", .{ .iterate = true }) catch return &[][:0]u8{};
    defer dir.close();
    var devices = std.ArrayList([:0]u8).init(allocator);
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file and entry.kind != .character_device) continue;
        if (std.mem.startsWith(u8, entry.name, "renderD")) {
            const full = std.fmt.allocPrintZ(allocator, "/dev/dri/{s}", .{entry.name}) catch continue;
            devices.append(full) catch continue;
        }
    }
    return devices.toOwnedSlice();
}

/// Get file descriptor size via fstat.
pub fn fdSize(fd: posix.fd_t) Error!u64 {
    var st: posix.Stat = undefined;
    const rc = linux.fstat(fd, @ptrCast(&st));
    if (linux.errno(rc) != .SUCCESS) return error.FdSizeFailed;
    return st.size;
}

// ─── Internal helpers ───────────────────────────────────────

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
    if (width > ~@as(u32, 0) / bytes_per_pixel) return null;
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
    _ = drmIoctl(fd, drm_ioctl_mode_destroy_dumb, @intFromPtr(&destroy));
}

fn ioctlOk(fd: posix.fd_t, request: u32, arg: usize, err: Error) Error!void {
    const rc = drmIoctl(fd, request, arg);
    if (linux.errno(rc) != .SUCCESS) return err;
}

fn drmIoctl(fd: posix.fd_t, request: u32, arg: usize) usize {
    return linux.ioctl(fd, request, arg);
}

fn closeFd(fd: posix.fd_t) void {
    _ = linux.close(fd);
}

// ─── Tests ──────────────────────────────────────────────────

test "drm struct sizes match kernel ABI" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(DrmModeDestroyDumb));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(DrmPrimeHandleToFd));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(DrmModeMapDumb));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(DrmModeCreateDumb));
    try std.testing.expectEqual(@as(usize, 104), @sizeOf(DrmModeFbCmd2));
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(DrmModePageFlip));
    try std.testing.expectEqual(@as(usize, 68), @sizeOf(DrmModeModeInfo));
    try std.testing.expectEqual(@as(usize, 80), @sizeOf(DrmModeGetConnector));
    try std.testing.expectEqual(@as(usize, 104), @sizeOf(DrmModeCrtc));
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(DrmModeCardRes));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(DrmSetClientCap));
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(DrmModeAtomic));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(DrmModeGetPlaneRes));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(DrmModeEncoder));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(DrmSyncobjCreate));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(DrmSyncobjDestroy));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(DrmSyncobjFdToHandle));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(DrmSyncobjImportSyncFile));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(DrmSyncobjExportSyncFile));
}

test "drm ioctl constants" {
    try std.testing.expectEqual(@as(u32, 0xc02064b2), drm_ioctl_mode_create_dumb);
    try std.testing.expectEqual(@as(u32, 0xc01064b3), drm_ioctl_mode_map_dumb);
    try std.testing.expectEqual(@as(u32, 0xc00464b4), drm_ioctl_mode_destroy_dumb);
    try std.testing.expectEqual(@as(u32, 0xc00c642d), drm_ioctl_prime_handle_to_fd);
    try std.testing.expectEqual(@as(u32, 0xc0406400), drm_ioctl_version);
    try std.testing.expectEqual(@as(u32, 0x0000641e), drm_ioctl_set_master);
    try std.testing.expectEqual(@as(u32, 0xc06864b8), drm_ioctl_mode_addfb2);
    try std.testing.expectEqual(@as(u32, 0xc06864a2), drm_ioctl_mode_setcrtc);
    try std.testing.expectEqual(@as(u32, 0xc00c644b), drm_ioctl_syncobj_create);
}

test "drm dumb create request validates dimensions" {
    try std.testing.expect(createRequest(640, 480, .xrgb8888) != null);
    try std.testing.expect(createRequest(640, 480, .argb8888) != null);
    try std.testing.expectEqual(@as(u32, xrgb8888_bits_per_pixel), createRequest(1, 1, .xrgb8888).?.bpp);
    try std.testing.expect(createRequest(0, 480, .xrgb8888) == null);
}

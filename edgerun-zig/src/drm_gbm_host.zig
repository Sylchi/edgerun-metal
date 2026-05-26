const std = @import("std");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_gles = @import("render/gles.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const app_frame = @import("app_frame.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");

const linux = std.os.linux;
const posix = std.posix;

const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("gbm.h");
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
    @cInclude("drm_fourcc.h");
    @cInclude("EGL/egl.h");
});

const default_device_path = "/dev/dri/card1";
const default_seconds: u32 = 5;
const crtc_depth: u8 = 24;
const crtc_bpp: u8 = 32;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_interaction_regions: usize = 1024;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 262144;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 65536;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

const Options = struct {
    device: []const u8 = default_device_path,
    seconds: u32 = default_seconds,
    connector_id: ?u32 = null,
    mode_index: u32 = 0,
};

const DrmTarget = struct {
    connector_id: u32,
    crtc_id: u32,
    mode: c.drmModeModeInfo,
};

const GbmState = struct {
    device: *c.gbm_device,
    surface: *c.gbm_surface,
};

const EglState = struct {
    display: c.EGLDisplay,
    context: c.EGLContext,
    surface: c.EGLSurface,
};

const SceneState = struct {
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_interaction_regions]interaction.Region = undefined,
    ir_storage: IrStorage = .{},

    fn rebuild(self: *SceneState, width: i32, height: i32, font_atlas: *renderer_font_atlas.Atlas) !renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try app_frame.render(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(width),
            .h = @floatFromInt(height),
        }, .{
            .route = .{ .view = .landing },
            .public_identity = "drm-gbm-gpu",
            .public_identity_ready = true,
        });
        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, font_atlas, .atlas, scene.written());
        return buffers;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const options = try parseOptions(args);

    const fd = try openDrm(options.device);
    defer closeFd(fd);
    try requireDrmMaster(fd);
    defer dropDrmMaster(fd);

    const target = try chooseTarget(fd, options);
    const width: i32 = @intCast(target.mode.hdisplay);
    const height: i32 = @intCast(target.mode.vdisplay);

    var gbm = try initGbm(fd, @intCast(width), @intCast(height));
    defer deinitGbm(&gbm);
    var egl = try initEgl(&gbm);
    defer deinitEgl(&egl);
    var font_atlas = renderer_font_atlas.Atlas.init();
    var gl = try renderer_gles.Adapter.init(&font_atlas, null);
    defer gl.deinit();

    var scene_state = SceneState{};
    const buffers = try scene_state.rebuild(width, height, &font_atlas);
    gl.refreshFontTexture(&font_atlas);
    const receipt = try gl.renderFrame(width, height, buffers);
    if (!receipt.valid()) return error.InvalidGlesReceipt;
    _ = try gl.verifyFrameNonBlank(width, height);
    if (c.eglSwapBuffers(egl.display, egl.surface) != c.EGL_TRUE) return error.EglSwapFailed;

    var scanout = try lockScanout(fd, &gbm, @intCast(width), @intCast(height));
    defer scanout.deinit(fd, &gbm);
    const saved = c.drmModeGetCrtc(fd, target.crtc_id);
    defer if (saved) |crtc| c.drmModeFreeCrtc(crtc);
    try setCrtc(fd, target, scanout.fb_id);
    sleepSeconds(options.seconds);
    if (saved) |crtc| restoreCrtc(fd, target, crtc);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--device")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.device = args[index];
        } else if (std.mem.eql(u8, args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--connector")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.connector_id = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (std.mem.eql(u8, args[index], "--mode-index")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.mode_index = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.device.len == 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

fn openDrm(path: []const u8) !posix.fd_t {
    return posix.openat(posix.AT.FDCWD, path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch return error.DrmOpenFailed;
}

fn closeFd(fd: posix.fd_t) void {
    _ = linux.close(fd);
}

fn requireDrmMaster(fd: posix.fd_t) !void {
    if (c.drmSetMaster(fd) != 0) return error.DrmMasterUnavailable;
}

fn dropDrmMaster(fd: posix.fd_t) void {
    _ = c.drmDropMaster(fd);
}

fn chooseTarget(fd: posix.fd_t, options: Options) !DrmTarget {
    const resources = c.drmModeGetResources(fd) orelse return error.DrmResourcesFailed;
    defer c.drmModeFreeResources(resources);
    var connector_index: c_int = 0;
    while (connector_index < resources.*.count_connectors) : (connector_index += 1) {
        const connector_id = resources.*.connectors[@intCast(connector_index)];
        if (options.connector_id) |requested| {
            if (connector_id != requested) continue;
        }
        const connector = c.drmModeGetConnector(fd, connector_id) orelse continue;
        defer c.drmModeFreeConnector(connector);
        if (connector.*.connection != c.DRM_MODE_CONNECTED or connector.*.count_modes == 0) continue;
        if (options.mode_index >= connector.*.count_modes) return error.InvalidDrmModeIndex;
        const crtc_id = findCrtcForConnector(fd, resources, connector) orelse continue;
        return .{
            .connector_id = connector.*.connector_id,
            .crtc_id = crtc_id,
            .mode = connector.*.modes[@intCast(options.mode_index)],
        };
    }
    if (options.connector_id != null) return error.RequestedDrmConnectorUnavailable;
    return error.NoConnectedDrmConnector;
}

fn findCrtcForConnector(fd: posix.fd_t, resources: c.drmModeResPtr, connector: c.drmModeConnectorPtr) ?u32 {
    if (connector.*.encoder_id != 0) {
        if (c.drmModeGetEncoder(fd, connector.*.encoder_id)) |encoder| {
            defer c.drmModeFreeEncoder(encoder);
            if (encoder.*.crtc_id != 0) return encoder.*.crtc_id;
        }
    }
    var encoder_index: c_int = 0;
    while (encoder_index < connector.*.count_encoders) : (encoder_index += 1) {
        const encoder = c.drmModeGetEncoder(fd, connector.*.encoders[@intCast(encoder_index)]) orelse continue;
        defer c.drmModeFreeEncoder(encoder);
        var crtc_index: c_int = 0;
        while (crtc_index < resources.*.count_crtcs) : (crtc_index += 1) {
            const crtc_mask = @as(u32, 1) << @intCast(crtc_index);
            if ((encoder.*.possible_crtcs & crtc_mask) != 0) return resources.*.crtcs[@intCast(crtc_index)];
        }
    }
    return null;
}

fn initGbm(fd: posix.fd_t, width: u32, height: u32) !GbmState {
    const device = c.gbm_create_device(fd) orelse return error.GbmDeviceFailed;
    errdefer c.gbm_device_destroy(device);
    const surface = c.gbm_surface_create(
        device,
        width,
        height,
        c.DRM_FORMAT_XRGB8888,
        c.GBM_BO_USE_SCANOUT | c.GBM_BO_USE_RENDERING,
    ) orelse return error.GbmSurfaceFailed;
    return .{ .device = device, .surface = surface };
}

fn deinitGbm(gbm: *GbmState) void {
    c.gbm_surface_destroy(gbm.surface);
    c.gbm_device_destroy(gbm.device);
}

fn initEgl(gbm: *GbmState) !EglState {
    const egl_display = c.eglGetDisplay(@ptrCast(gbm.device));
    if (egl_display == c.EGL_NO_DISPLAY) return error.EglDisplayFailed;
    var major: c.EGLint = 0;
    var minor: c.EGLint = 0;
    if (c.eglInitialize(egl_display, &major, &minor) != c.EGL_TRUE) return error.EglInitializeFailed;
    if (c.eglBindAPI(c.EGL_OPENGL_ES_API) != c.EGL_TRUE) return error.EglApiFailed;
    const attrs = [_]c.EGLint{
        c.EGL_SURFACE_TYPE,    c.EGL_WINDOW_BIT,
        c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES2_BIT,
        c.EGL_RED_SIZE,        8,
        c.EGL_GREEN_SIZE,      8,
        c.EGL_BLUE_SIZE,       8,
        c.EGL_NONE,
    };
    var config: c.EGLConfig = null;
    var count: c.EGLint = 0;
    if (c.eglChooseConfig(egl_display, &attrs, &config, 1, &count) != c.EGL_TRUE or count == 0) return error.EglConfigFailed;
    const context_attrs = [_]c.EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };
    const context = c.eglCreateContext(egl_display, config, c.EGL_NO_CONTEXT, &context_attrs);
    if (context == c.EGL_NO_CONTEXT) return error.EglContextFailed;
    errdefer _ = c.eglDestroyContext(egl_display, context);
    const surface = c.eglCreateWindowSurface(egl_display, config, @ptrCast(gbm.surface), null);
    if (surface == c.EGL_NO_SURFACE) return error.EglSurfaceFailed;
    if (c.eglMakeCurrent(egl_display, surface, surface, context) != c.EGL_TRUE) return error.EglMakeCurrentFailed;
    return .{ .display = egl_display, .context = context, .surface = surface };
}

fn deinitEgl(egl: *EglState) void {
    _ = c.eglMakeCurrent(egl.display, c.EGL_NO_SURFACE, c.EGL_NO_SURFACE, c.EGL_NO_CONTEXT);
    _ = c.eglDestroySurface(egl.display, egl.surface);
    _ = c.eglDestroyContext(egl.display, egl.context);
    _ = c.eglTerminate(egl.display);
}

const Scanout = struct {
    bo: *c.gbm_bo,
    fb_id: u32,

    fn deinit(self: *Scanout, fd: posix.fd_t, gbm: *GbmState) void {
        if (self.fb_id != 0) {
            _ = c.drmModeRmFB(fd, self.fb_id);
            self.fb_id = 0;
        }
        c.gbm_surface_release_buffer(gbm.surface, self.bo);
    }
};

fn lockScanout(fd: posix.fd_t, gbm: *GbmState, width: u32, height: u32) !Scanout {
    const bo = c.gbm_surface_lock_front_buffer(gbm.surface) orelse return error.GbmLockFailed;
    errdefer c.gbm_surface_release_buffer(gbm.surface, bo);
    const handle = c.gbm_bo_get_handle(bo).u32;
    const stride = c.gbm_bo_get_stride(bo);
    var fb_id: u32 = 0;
    if (c.drmModeAddFB(fd, width, height, crtc_depth, crtc_bpp, stride, handle, &fb_id) != 0) return error.DrmFramebufferFailed;
    return .{ .bo = bo, .fb_id = fb_id };
}

fn setCrtc(fd: posix.fd_t, target: DrmTarget, fb_id: u32) !void {
    var connector_id = target.connector_id;
    var mode = target.mode;
    if (c.drmModeSetCrtc(fd, target.crtc_id, fb_id, 0, 0, &connector_id, 1, &mode) != 0) return error.DrmSetCrtcFailed;
}

fn restoreCrtc(fd: posix.fd_t, target: DrmTarget, crtc: c.drmModeCrtcPtr) void {
    var connector_id = target.connector_id;
    if (crtc.*.mode_valid != 0) {
        var mode = crtc.*.mode;
        _ = c.drmModeSetCrtc(fd, crtc.*.crtc_id, crtc.*.buffer_id, crtc.*.x, crtc.*.y, &connector_id, 1, &mode);
    } else {
        _ = c.drmModeSetCrtc(fd, crtc.*.crtc_id, 0, crtc.*.x, crtc.*.y, &connector_id, 1, null);
    }
}

fn sleepSeconds(seconds: u32) void {
    const req = linux.timespec{ .sec = seconds, .nsec = 0 };
    _ = linux.nanosleep(&req, null);
}

test "drm gbm host parses explicit device and duration" {
    const args = [_][:0]const u8{
        "drm-gbm-window",
        "--device",
        "/dev/dri/card7",
        "--seconds",
        "2",
        "--connector",
        "378",
        "--mode-index",
        "3",
    };
    const options = try parseOptions(&args);
    try std.testing.expectEqualStrings("/dev/dri/card7", options.device);
    try std.testing.expectEqual(@as(u32, 2), options.seconds);
    try std.testing.expectEqual(@as(u32, 378), options.connector_id.?);
    try std.testing.expectEqual(@as(u32, 3), options.mode_index);
}

test "drm gbm host rejects incomplete arguments" {
    const missing_device = [_][:0]const u8{ "drm-gbm-window", "--device" };
    try std.testing.expectError(error.InvalidArguments, parseOptions(&missing_device));
    const zero_seconds = [_][:0]const u8{ "drm-gbm-window", "--seconds", "0" };
    try std.testing.expectError(error.InvalidArguments, parseOptions(&zero_seconds));
}

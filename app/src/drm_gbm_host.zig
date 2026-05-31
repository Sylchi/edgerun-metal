const std = @import("std");
const bytes = @import("bytes.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_gles = @import("render/backends/gles.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const app_frame = @import("shell/frame.zig");
const app_location = @import("location.zig");
const ui = @import("ui/core.zig");
const interaction = @import("ui/interaction.zig");
const drm = @import("linux_drm.zig");
const gpu = @import("linux_gpu.zig");

const linux = std.os.linux;
const posix = std.posix;

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
const max_icon_line_vertices: usize = 65536;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;

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
    mode: drm.DrmModeModeInfo,
};

const GbmState = struct {
    gbm: *gpu.Gbm,
    device: *gpu.GbmDevice,
    surface: *gpu.GbmSurface,
};

const EglState = struct {
    egl: *gpu.Egl,
    display: gpu.EGLDisplay,
    context: gpu.EGLContext,
    surface: gpu.EGLSurface,
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
            .location = app_location.locationForButton(.app_preview),
            .public_identity = "drm-gbm-gpu",
            .public_identity_ready = true,
        });
        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, font_atlas, scene.written());
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
    try drm.setMaster(fd);
    defer drm.dropMaster(fd) catch {};

    const target = try chooseTarget(fd, options);
    const width: i32 = @intCast(target.mode.hdisplay);
    const height: i32 = @intCast(target.mode.vdisplay);

    var gbm = try initGbm(fd, @intCast(width), @intCast(height));
    defer deinitGbm(&gbm);
    var egl = try initEgl(&gbm);
    defer deinitEgl(&egl);
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var gl = try renderer_gles.Adapter.init(&font_atlas, null);
    defer gl.deinit();

    var scene_state = SceneState{};
    const buffers = try scene_state.rebuild(width, height, &font_atlas);
    gl.refreshFontTexture(&font_atlas);
    const receipt = try gl.renderFrame(width, height, buffers);
    if (!receipt.valid()) return error.InvalidGlesReceipt;
    _ = try gl.verifyFrameNonBlank(width, height);
    if (egl.egl.eglSwapBuffers(egl.display, egl.surface) != gpu.egl_true) return error.EglSwapFailed;

    var scanout = try lockScanout(fd, &gbm, @intCast(width), @intCast(height));
    defer scanout.deinit(fd, &gbm);
    const saved = drm.getCrtc(fd, target.crtc_id) catch |err| return err;
    try drm.setCrtc(fd, target.crtc_id, scanout.fb_id, target.connector_id, &target.mode);
    sleepSeconds(options.seconds);
    restoreCrtc(fd, saved);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (bytes.eql(args[index], "--device")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.device = args[index];
        } else if (bytes.eql(args[index], "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes.eql(args[index], "--connector")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.connector_id = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes.eql(args[index], "--mode-index")) {
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

fn chooseTarget(fd: posix.fd_t, options: Options) !DrmTarget {
    const resources = try drm.getResources(fd);
    defer std.heap.page_allocator.free(resources.crtcs);
    defer std.heap.page_allocator.free(resources.connectors);
    defer std.heap.page_allocator.free(resources.encoders);
    defer std.heap.page_allocator.free(resources.fbs);
    var connector_index: usize = 0;
    while (connector_index < @as(usize, @intCast(@max(resources.count_connectors, 0)))) : (connector_index += 1) {
        const connector_id = resources.connectors[connector_index];
        if (options.connector_id) |requested| {
            if (connector_id != requested) continue;
        }
        const connector = try drm.getConnector(fd, connector_id);
        defer std.heap.page_allocator.free(connector.encoder_ids);
        defer std.heap.page_allocator.free(connector.modes);
        defer std.heap.page_allocator.free(connector.prop_ids);
        defer std.heap.page_allocator.free(connector.prop_values);
        if (connector.connection != drm.connector_connected or connector.modes.len == 0) continue;
        if (options.mode_index >= connector.modes.len) return error.InvalidDrmModeIndex;
        const crtc_id = findCrtcForConnector(fd, resources, connector) orelse continue;
        return .{
            .connector_id = connector.connector_id,
            .crtc_id = crtc_id,
            .mode = connector.modes[options.mode_index],
        };
    }
    if (options.connector_id != null) return error.RequestedDrmConnectorUnavailable;
    return error.NoConnectedDrmConnector;
}

fn findCrtcForConnector(fd: posix.fd_t, resources: drm.DrmResources, connector: drm.DrmConnector) ?u32 {
    if (connector.encoder_id != 0) {
        if (drm.getEncoder(fd, connector.encoder_id)) |enc| {
            if (enc.crtc_id != 0) return enc.crtc_id;
        } else |_| {}
    }
    for (connector.encoder_ids) |enc_id| {
        const enc = drm.getEncoder(fd, enc_id) catch continue;
        var crtc_index: usize = 0;
        while (crtc_index < @as(usize, @intCast(@max(resources.count_crtcs, 0)))) : (crtc_index += 1) {
            const crtc_mask = @as(u32, 1) << @intCast(crtc_index);
            if ((enc.possible_crtcs & crtc_mask) != 0) return resources.crtcs[crtc_index];
        }
    }
    return null;
}

fn initGbm(fd: posix.fd_t, width: u32, height: u32) !GbmState {
    var gbm_wrapper = try gpu.Gbm.open();
    const device = gbm_wrapper.gbmCreateDevice(fd) orelse return error.GbmDeviceFailed;
    errdefer gbm_wrapper.gbmDeviceDestroy(device);
    const surface = gbm_wrapper.gbmCreateSurface(device, width, height, gpu.drm_format_xrgb8888, gpu.gbm_bo_use_scanout | gpu.gbm_bo_use_rendering) orelse return error.GbmSurfaceFailed;
    return .{ .gbm = &gbm_wrapper, .device = device, .surface = surface };
}

fn deinitGbm(gbm: *GbmState) void {
    gbm.gbm.gbmSurfaceDestroy(gbm.surface);
    gbm.gbm.gbmDeviceDestroy(gbm.device);
    gbm.gbm.lib.close();
}

fn initEgl(gbm: *GbmState) !EglState {
    var egl_wrapper = try gpu.Egl.open();
    const egl_display = egl_wrapper.eglGetDisplay(@ptrCast(gbm.device));
    if (egl_display == null) return error.EglDisplayFailed;
    var major: gpu.EGLint = 0;
    var minor: gpu.EGLint = 0;
    if (egl_wrapper.eglInitialize(egl_display, &major, &minor) != gpu.egl_true) return error.EglInitializeFailed;
    if (egl_wrapper.eglBindAPI(gpu.egl_opengl_es_api) != gpu.egl_true) return error.EglApiFailed;
    const attrs = [_]gpu.EGLint{
        gpu.egl_surface_type,    gpu.egl_window_bit,
        gpu.egl_renderable_type, gpu.egl_opengl_es2_bit,
        gpu.egl_red_size,        8,
        gpu.egl_green_size,      8,
        gpu.egl_blue_size,       8,
        gpu.egl_none,
    };
    var config: gpu.EGLConfig = undefined;
    var count: gpu.EGLint = 0;
    if (egl_wrapper.eglChooseConfig(egl_display, &attrs, &config, 1, &count) != gpu.egl_true or count == 0) return error.EglConfigFailed;
    const context_attrs = [_]gpu.EGLint{ gpu.egl_context_client_version, 2, gpu.egl_none };
    const context = egl_wrapper.eglCreateContext(egl_display, config, gpu.egl_no_context, &context_attrs);
    if (context == null) return error.EglContextFailed;
    errdefer _ = egl_wrapper.eglDestroyContext(egl_display, context);
    const surface = egl_wrapper.eglCreateWindowSurface(egl_display, config, @ptrCast(gbm.surface), null);
    if (surface == null) return error.EglSurfaceFailed;
    if (egl_wrapper.eglMakeCurrent(egl_display, surface, surface, context) != gpu.egl_true) return error.EglMakeCurrentFailed;
    return .{ .egl = &egl_wrapper, .display = egl_display, .context = context, .surface = surface };
}

fn deinitEgl(egl: *EglState) void {
    _ = egl.egl.eglMakeCurrent(egl.display, gpu.egl_no_surface, gpu.egl_no_surface, gpu.egl_no_context);
    _ = egl.egl.eglDestroySurface(egl.display, egl.surface);
    _ = egl.egl.eglDestroyContext(egl.display, egl.context);
    _ = egl.egl.eglTerminate(egl.display);
    egl.egl.lib.close();
}

const Scanout = struct {
    bo: *gpu.GbmBo,
    fb_id: u32,

    fn deinit(self: *Scanout, fd: posix.fd_t, gbm: *GbmState) void {
        if (self.fb_id != 0) {
            drm.rmfb(fd, self.fb_id) catch {};
            self.fb_id = 0;
        }
        gbm.gbm.gbmSurfaceReleaseBuffer(gbm.surface, self.bo);
    }
};

fn lockScanout(fd: posix.fd_t, gbm: *GbmState, width: u32, height: u32) !Scanout {
    const bo = gbm.gbm.gbmSurfaceLockFrontBuffer(gbm.surface) orelse return error.GbmLockFailed;
    errdefer gbm.gbm.gbmSurfaceReleaseBuffer(gbm.surface, bo);
    const handle = gbm.gbm.gbmBoGetHandle(bo);
    const stride = gbm.gbm.gbmBoGetStride(bo);
    const fb_id = try drm.addFb2(fd, handle, width, height, stride, gpu.drm_format_xrgb8888);
    return .{ .bo = bo, .fb_id = fb_id };
}

fn restoreCrtc(fd: posix.fd_t, crtc: drm.DrmCrtcInfo) void {
    if (crtc.mode_valid != 0) {
        drm.setCrtc(fd, crtc.crtc_id, crtc.fb_id, 0, &crtc.mode) catch {};
    } else {
        // Restore with no FB (disable the CRTC)
        _ = linux.ioctl(fd, drm.drm_ioctl_mode_setcrtc, 0);
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

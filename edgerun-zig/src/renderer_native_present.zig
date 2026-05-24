const std = @import("std");
const renderer_gpu = @import("renderer_gpu.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_present = @import("renderer_present.zig");
const renderer_software = @import("renderer_software.zig");
const renderer_surface = @import("renderer_surface.zig");
const ui = @import("ui.zig");

pub const Error = renderer_software.Error || renderer_gpu.Error || error{
    UnsupportedTarget,
    InvalidFramebuffer,
    InvalidNativeSurface,
    InvalidTilePlan,
    DirtyTileBudgetExceeded,
    InvalidSink,
    SinkRejected,
    InvalidGpuBuffer,
};

pub const PixelFormat = enum(u32) {
    xrgb8888 = 0x34325258,
    argb8888 = 0x34325241,
};

pub const GpuBuffer = struct {
    kind: renderer_gpu.BufferKind,
    handle: u64,
    offset: u32 = 0,
    plane_count: u8 = 1,

    pub fn valid(self: GpuBuffer) bool {
        return self.handle != 0 and
            self.plane_count != 0 and
            (self.kind == .scanout or self.kind == .dma_buf);
    }
};

pub const DrmSurface = struct {
    framebuffer_id: u32,
    connector_id: u32,
    crtc_id: u32,
    width: u32,
    height: u32,
    stride: u32,
    format: PixelFormat = .xrgb8888,
    gpu_buffer: ?GpuBuffer = null,

    pub fn valid(self: DrmSurface) bool {
        return self.framebuffer_id != 0 and
            self.connector_id != 0 and
            self.crtc_id != 0 and
            self.width != 0 and
            self.height != 0 and
            self.stride >= self.width;
    }
};

pub const WaylandSurface = struct {
    surface_id: u32,
    buffer_id: u32,
    width: u32,
    height: u32,
    stride: u32,
    scale: u32 = 1,
    format: PixelFormat = .argb8888,
    gpu_buffer: ?GpuBuffer = null,

    pub fn valid(self: WaylandSurface) bool {
        return self.surface_id != 0 and
            self.buffer_id != 0 and
            self.width != 0 and
            self.height != 0 and
            self.stride >= self.width and
            self.scale != 0;
    }
};

pub const NativeSurface = union(enum) {
    drm: DrmSurface,
    wayland: WaylandSurface,

    pub fn validate(self: NativeSurface) Error!void {
        switch (self) {
            .drm => |surface| if (!surface.valid()) return error.InvalidNativeSurface,
            .wayland => |surface| if (!surface.valid()) return error.InvalidNativeSurface,
        }
    }

    pub fn target(self: NativeSurface) renderer_present.Target {
        return switch (self) {
            .drm => |surface| .{
                .kind = .drm,
                .width = surface.width,
                .height = surface.height,
            },
            .wayland => |surface| .{
                .kind = .wayland,
                .width = surface.width,
                .height = surface.height,
                .scale = surface.scale,
            },
        };
    }

    pub fn mode(self: NativeSurface, refresh_hz: u32) renderer_surface.Mode {
        return switch (self) {
            .drm => |surface| .{
                .width = surface.width,
                .height = surface.height,
                .stride = surface.stride,
                .refresh_hz = refresh_hz,
                .pixel_format = surfaceFormat(surface.format),
            },
            .wayland => |surface| .{
                .width = surface.width,
                .height = surface.height,
                .stride = surface.stride,
                .refresh_hz = refresh_hz,
                .pixel_format = surfaceFormat(surface.format),
            },
        };
    }

    pub fn gpuSurface(self: NativeSurface) Error!renderer_gpu.Surface {
        return switch (self) {
            .drm => |surface| .{
                .id = surface.framebuffer_id,
                .width = surface.width,
                .height = surface.height,
                .is_opaque = surface.format == .xrgb8888,
                .buffer = try gpuSurfaceBuffer(surface.width, surface.height, surface.stride, surface.format, surface.gpu_buffer),
            },
            .wayland => |surface| .{
                .id = surface.buffer_id,
                .width = surface.width,
                .height = surface.height,
                .buffer_scale = @intCast(surface.scale),
                .is_opaque = surface.format == .xrgb8888,
                .buffer = try gpuSurfaceBuffer(surface.width, surface.height, surface.stride, surface.format, surface.gpu_buffer),
            },
        };
    }
};

pub const Request = struct {
    target: renderer_present.TargetKind,
    transport: renderer_present.Transport,
    primitive_count: usize,
    dirty_tiles: []const u32,
    scanout_bytes: u64,
    full_frame_bytes: u64,
    commit: Commit,
};

pub const Commit = union(enum) {
    drm: DrmCommit,
    wayland: WaylandCommit,
};

pub const DrmCommit = struct {
    framebuffer_id: u32,
    connector_id: u32,
    crtc_id: u32,
    dirty_tiles: []const u32,
};

pub const WaylandCommit = struct {
    surface_id: u32,
    buffer_id: u32,
    scale: u32,
    dirty_tiles: []const u32,
};

pub const Receipt = struct {
    target: renderer_present.TargetKind,
    transport: renderer_present.Transport,
    primitive_count: usize,
    dirty_tile_count: usize,

    pub fn valid(self: Receipt) bool {
        return self.primitive_count != 0 and self.dirty_tile_count != 0;
    }
};

pub const GpuNativeReceipt = struct {
    gpu: renderer_gpu.Receipt,
    native: Receipt,

    pub fn valid(self: GpuNativeReceipt) bool {
        return self.gpu.valid() and
            self.native.valid() and
            self.gpu.presentation_transport == .gpu_command_stream and
            (self.native.transport == .drm_framebuffer or self.native.transport == .wayland_surface);
    }
};

pub const Sink = struct {
    context: *anyopaque,
    submit_drm: ?*const fn (context: *anyopaque, commit: DrmCommit) bool = null,
    submit_wayland: ?*const fn (context: *anyopaque, commit: WaylandCommit) bool = null,

    pub fn valid(self: Sink) bool {
        return @intFromPtr(self.context) != 0 and (self.submit_drm != null or self.submit_wayland != null);
    }
};

pub const GpuWorkspace = struct {
    primitives: []renderer_gpu.Primitive,
    gpu_tile_marks: []u8,
    gpu_dirty_ids: []u32,
    native_tile_marks: []u8,
    native_dirty_ids: []u32,
};

pub const CpuFramebuffer = struct {
    width: u32,
    height: u32,
    pixels: []ui.Color,

    pub fn valid(self: CpuFramebuffer) bool {
        return self.width != 0 and
            self.height != 0 and
            self.pixels.len >= @as(usize, self.width) * @as(usize, self.height);
    }
};

pub fn planPresent(
    surface: NativeSurface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    refresh_hz: u32,
    tile_width: u32,
    tile_height: u32,
    tile_marks: []u8,
    dirty_ids: []u32,
) Error!Request {
    try surface.validate();
    const presentation = try renderer_present.present(.{
        .target = surface.target(),
        .buffers = buffers,
        .resources = resources,
    });
    const tile_plan = renderer_surface.tilePlanFromMode(surface.mode(refresh_hz), tile_width, tile_height, @intCast(dirty_ids.len)) orelse return error.InvalidTilePlan;
    var dirty = renderer_surface.DirtyTileList{ .tile_ids = dirty_ids };
    if (!renderer_surface.dirtyTilesReset(tile_plan, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;
    if (!renderer_surface.dirtyTilesMarkIrBuffers(tile_plan, buffers, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;

    return .{
        .target = presentation.target,
        .transport = presentation.transport,
        .primitive_count = presentation.primitive_count,
        .dirty_tiles = dirty.written(),
        .scanout_bytes = tile_plan.scanout_bytes,
        .full_frame_bytes = tile_plan.full_frame_bytes,
        .commit = commitForSurface(surface, dirty.written()),
    };
}

pub fn submit(request: Request, sink: Sink) Error!Receipt {
    if (!sink.valid()) return error.InvalidSink;
    switch (request.commit) {
        .drm => |commit| {
            const submit_drm = sink.submit_drm orelse return error.UnsupportedTarget;
            if (!submit_drm(sink.context, commit)) return error.SinkRejected;
        },
        .wayland => |commit| {
            const submit_wayland = sink.submit_wayland orelse return error.UnsupportedTarget;
            if (!submit_wayland(sink.context, commit)) return error.SinkRejected;
        },
    }
    return .{
        .target = request.target,
        .transport = request.transport,
        .primitive_count = request.primitive_count,
        .dirty_tile_count = request.dirty_tiles.len,
    };
}

pub fn planAndSubmit(
    surface: NativeSurface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    refresh_hz: u32,
    tile_width: u32,
    tile_height: u32,
    tile_marks: []u8,
    dirty_ids: []u32,
    sink: Sink,
) Error!Receipt {
    const request = try planPresent(surface, buffers, resources, refresh_hz, tile_width, tile_height, tile_marks, dirty_ids);
    return submit(request, sink);
}

pub fn renderCpuAndSubmit(
    surface: NativeSurface,
    buffers: renderer_ir.Buffers,
    atlases: renderer_software.IrAtlases,
    framebuffer: CpuFramebuffer,
    background: ui.Color,
    refresh_hz: u32,
    tile_width: u32,
    tile_height: u32,
    tile_marks: []u8,
    dirty_ids: []u32,
    sink: Sink,
) Error!Receipt {
    try surface.validate();
    if (!framebuffer.valid()) return error.InvalidFramebuffer;
    const target = surface.target();
    if (framebuffer.width != target.width or framebuffer.height != target.height) return error.InvalidFramebuffer;

    const software_surface = try renderer_software.Surface.init(framebuffer.width, framebuffer.height, framebuffer.pixels);
    software_surface.clear(background);
    _ = try software_surface.renderIrFrameWithAtlases(buffers, atlases);
    return planAndSubmit(surface, buffers, atlases.resources(), refresh_hz, tile_width, tile_height, tile_marks, dirty_ids, sink);
}

pub fn renderGpuAndSubmit(
    surface: NativeSurface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    device: renderer_gpu.Device,
    workspace: GpuWorkspace,
    refresh_hz: u32,
    tile_width: u32,
    tile_height: u32,
    sink: Sink,
) Error!GpuNativeReceipt {
    try surface.validate();
    var renderer = try renderer_gpu.Renderer.init(
        device,
        surface.mode(refresh_hz),
        tile_width,
        tile_height,
        workspace.primitives,
        workspace.gpu_tile_marks,
        workspace.gpu_dirty_ids,
    );
    const gpu_receipt = try renderer.renderIrWithResources(&.{}, buffers, resources);
    const native_receipt = try planAndSubmit(
        surface,
        buffers,
        resources,
        refresh_hz,
        tile_width,
        tile_height,
        workspace.native_tile_marks,
        workspace.native_dirty_ids,
        sink,
    );
    return .{
        .gpu = gpu_receipt,
        .native = native_receipt,
    };
}

pub fn renderGpuBackedAndSubmit(
    surface: NativeSurface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    device: renderer_gpu.Device,
    workspace: GpuWorkspace,
    refresh_hz: u32,
    tile_width: u32,
    tile_height: u32,
    sink: Sink,
) Error!GpuNativeReceipt {
    const gpu_surface = try surface.gpuSurface();
    try surface.validate();
    var renderer = try renderer_gpu.Renderer.init(
        device,
        surface.mode(refresh_hz),
        tile_width,
        tile_height,
        workspace.primitives,
        workspace.gpu_tile_marks,
        workspace.gpu_dirty_ids,
    );
    const gpu_surfaces = [_]renderer_gpu.Surface{gpu_surface};
    const gpu_receipt = try renderer.renderIrWithResources(&gpu_surfaces, buffers, resources);
    const native_receipt = try planAndSubmit(
        surface,
        buffers,
        resources,
        refresh_hz,
        tile_width,
        tile_height,
        workspace.native_tile_marks,
        workspace.native_dirty_ids,
        sink,
    );
    return .{
        .gpu = gpu_receipt,
        .native = native_receipt,
    };
}

fn commitForSurface(surface: NativeSurface, dirty_tiles: []const u32) Commit {
    return switch (surface) {
        .drm => |value| .{ .drm = .{
            .framebuffer_id = value.framebuffer_id,
            .connector_id = value.connector_id,
            .crtc_id = value.crtc_id,
            .dirty_tiles = dirty_tiles,
        } },
        .wayland => |value| .{ .wayland = .{
            .surface_id = value.surface_id,
            .buffer_id = value.buffer_id,
            .scale = value.scale,
            .dirty_tiles = dirty_tiles,
        } },
    };
}

fn gpuSurfaceBuffer(width: u32, height: u32, stride: u32, format: PixelFormat, maybe_buffer: ?GpuBuffer) Error!renderer_gpu.SurfaceBuffer {
    const buffer = maybe_buffer orelse return error.InvalidGpuBuffer;
    if (!buffer.valid()) return error.InvalidGpuBuffer;
    const surface_buffer = renderer_gpu.SurfaceBuffer{
        .kind = buffer.kind,
        .width = width,
        .height = height,
        .stride = stride * renderer_surface.bytes_per_pixel,
        .format = gpuSurfaceFormat(format),
        .handle = buffer.handle,
        .offset = buffer.offset,
        .plane_count = buffer.plane_count,
    };
    if (!surface_buffer.valid()) return error.InvalidGpuBuffer;
    return surface_buffer;
}

fn gpuSurfaceFormat(format: PixelFormat) renderer_gpu.SurfaceFormat {
    return switch (format) {
        .xrgb8888 => .xrgb8888,
        .argb8888 => .argb8888,
    };
}

const TestSink = struct {
    drm_count: usize = 0,
    wayland_count: usize = 0,
    last_framebuffer_id: u32 = 0,
    last_surface_id: u32 = 0,
    reject: bool = false,

    fn drmSink(self: *TestSink) Sink {
        return .{
            .context = self,
            .submit_drm = submitDrm,
        };
    }

    fn waylandSink(self: *TestSink) Sink {
        return .{
            .context = self,
            .submit_wayland = submitWayland,
        };
    }

    fn submitDrm(context: *anyopaque, commit: DrmCommit) bool {
        const self: *TestSink = @ptrCast(@alignCast(context));
        if (self.reject) return false;
        self.drm_count += 1;
        self.last_framebuffer_id = commit.framebuffer_id;
        return commit.dirty_tiles.len != 0;
    }

    fn submitWayland(context: *anyopaque, commit: WaylandCommit) bool {
        const self: *TestSink = @ptrCast(@alignCast(context));
        if (self.reject) return false;
        self.wayland_count += 1;
        self.last_surface_id = commit.surface_id;
        return commit.dirty_tiles.len != 0;
    }
};

const TestGpuDevice = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,
    reject_present: bool = false,

    fn device(self: *TestGpuDevice) renderer_gpu.Device {
        return .{
            .context = self,
            .begin_frame = beginFrame,
            .upload_primitives = uploadPrimitives,
            .render_tiles = renderTiles,
            .present = present,
        };
    }

    fn beginFrame(context: *anyopaque, frame: renderer_gpu.Frame) bool {
        const self: *TestGpuDevice = @ptrCast(@alignCast(context));
        if (frame.sequence == 0 or frame.primitives.len == 0) return false;
        self.began += 1;
        return true;
    }

    fn uploadPrimitives(context: *anyopaque, primitives: []const renderer_gpu.Primitive) bool {
        const self: *TestGpuDevice = @ptrCast(@alignCast(context));
        if (primitives.len == 0) return false;
        self.uploaded += primitives.len;
        return true;
    }

    fn renderTiles(context: *anyopaque, dirty_tiles: []const u32) bool {
        const self: *TestGpuDevice = @ptrCast(@alignCast(context));
        if (dirty_tiles.len == 0) return false;
        self.rendered += dirty_tiles.len;
        return true;
    }

    fn present(context: *anyopaque, sequence: u64) bool {
        const self: *TestGpuDevice = @ptrCast(@alignCast(context));
        if (self.reject_present or sequence == 0) return false;
        self.presented += 1;
        self.last_sequence = sequence;
        return true;
    }
};

fn surfaceFormat(format: PixelFormat) renderer_surface.PixelFormat {
    return switch (format) {
        .xrgb8888 => .rgbx,
        .argb8888 => .rgbx,
    };
}

test "native drm presentation plans canonical ir frame" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 4, .y = 4, .w = 32, .h = 24 }, .text, .clear, 0, 0, 0);

    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    const request = try planPresent(
        .{ .drm = .{
            .framebuffer_id = 7,
            .connector_id = 9,
            .crtc_id = 11,
            .width = 128,
            .height = 96,
            .stride = 128,
        } },
        buffers,
        .{},
        60,
        32,
        32,
        &tile_marks,
        &dirty_ids,
    );

    try std.testing.expectEqual(renderer_present.TargetKind.drm, request.target);
    try std.testing.expectEqual(renderer_present.Transport.drm_framebuffer, request.transport);
    try std.testing.expectEqual(@as(usize, 1), request.primitive_count);
    try std.testing.expect(request.dirty_tiles.len != 0);
    try std.testing.expectEqual(@as(u64, 128 * 96 * renderer_surface.bytes_per_pixel), request.scanout_bytes);
    switch (request.commit) {
        .drm => |commit| {
            try std.testing.expectEqual(@as(u32, 7), commit.framebuffer_id);
            try std.testing.expectEqual(@as(u32, 9), commit.connector_id);
            try std.testing.expectEqual(@as(u32, 11), commit.crtc_id);
            try std.testing.expectEqualSlices(u32, request.dirty_tiles, commit.dirty_tiles);
        },
        .wayland => return error.TestUnexpectedResult,
    }
}

test "native wayland presentation plans canonical ir frame" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 10, .y = 12, .w = 8, .h = 8 }, .accent, .clear, 0, 0, 0);

    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    const request = try planPresent(
        .{ .wayland = .{
            .surface_id = 3,
            .buffer_id = 5,
            .width = 64,
            .height = 64,
            .stride = 64,
            .scale = 2,
        } },
        buffers,
        .{},
        60,
        16,
        16,
        &tile_marks,
        &dirty_ids,
    );

    try std.testing.expectEqual(renderer_present.TargetKind.wayland, request.target);
    try std.testing.expectEqual(renderer_present.Transport.wayland_surface, request.transport);
    try std.testing.expectEqual(@as(usize, 1), request.primitive_count);
    try std.testing.expect(request.dirty_tiles.len != 0);
    switch (request.commit) {
        .drm => return error.TestUnexpectedResult,
        .wayland => |commit| {
            try std.testing.expectEqual(@as(u32, 3), commit.surface_id);
            try std.testing.expectEqual(@as(u32, 5), commit.buffer_id);
            try std.testing.expectEqual(@as(u32, 2), commit.scale);
            try std.testing.expectEqualSlices(u32, request.dirty_tiles, commit.dirty_tiles);
        },
    }
}

test "native presentation rejects invalid surfaces and missing resources" {
    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride;

    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    try std.testing.expectError(error.InvalidNativeSurface, planPresent(
        .{ .drm = .{
            .framebuffer_id = 0,
            .connector_id = 1,
            .crtc_id = 1,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        storage.buffers(),
        .{ .font_atlas = true },
        60,
        16,
        16,
        &tile_marks,
        &dirty_ids,
    ));

    try std.testing.expectError(error.MissingFontAtlas, planPresent(
        .{ .wayland = .{
            .surface_id = 1,
            .buffer_id = 1,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        storage.buffers(),
        .{},
        60,
        16,
        16,
        &tile_marks,
        &dirty_ids,
    ));
}

test "native presentation submits only matching drm sink" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 4, .y = 4, .w = 32, .h = 24 }, .text, .clear, 0, 0, 0);

    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    var sink_state = TestSink{};
    const receipt = try planAndSubmit(
        .{ .drm = .{
            .framebuffer_id = 17,
            .connector_id = 19,
            .crtc_id = 23,
            .width = 128,
            .height = 96,
            .stride = 128,
        } },
        buffers,
        .{},
        60,
        32,
        32,
        &tile_marks,
        &dirty_ids,
        sink_state.drmSink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_present.TargetKind.drm, receipt.target);
    try std.testing.expectEqual(@as(usize, 1), sink_state.drm_count);
    try std.testing.expectEqual(@as(usize, 0), sink_state.wayland_count);
    try std.testing.expectEqual(@as(u32, 17), sink_state.last_framebuffer_id);
}

test "native presentation rejects mismatched and failing sinks" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 16, .h = 16 }, .accent, .clear, 0, 0, 0);

    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    const surface = NativeSurface{ .wayland = .{
        .surface_id = 29,
        .buffer_id = 31,
        .width = 64,
        .height = 64,
        .stride = 64,
    } };
    var mismatched_sink = TestSink{};
    try std.testing.expectError(error.UnsupportedTarget, planAndSubmit(surface, buffers, .{}, 60, 16, 16, &tile_marks, &dirty_ids, mismatched_sink.drmSink()));

    var rejecting_sink = TestSink{ .reject = true };
    try std.testing.expectError(error.SinkRejected, planAndSubmit(surface, buffers, .{}, 60, 16, 16, &tile_marks, &dirty_ids, rejecting_sink.waylandSink()));
}

test "native cpu render submits drm commit from canonical ir" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 32, .h = 32 }, .accent, .clear, 0, 0, 0);

    var pixels: [64 * 64]ui.Color = undefined;
    const alpha = [_]u8{255};
    const atlases = renderer_software.IrAtlases{
        .font = .{ .width = 1, .height = 1, .alpha = &alpha },
        .icon = .{ .width = 1, .height = 1, .alpha = &alpha },
    };
    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    var sink_state = TestSink{};
    const receipt = try renderCpuAndSubmit(
        .{ .drm = .{
            .framebuffer_id = 41,
            .connector_id = 43,
            .crtc_id = 47,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        atlases,
        .{ .width = 64, .height = 64, .pixels = &pixels },
        .clear,
        60,
        16,
        16,
        &tile_marks,
        &dirty_ids,
        sink_state.drmSink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(@as(usize, 1), sink_state.drm_count);
    try std.testing.expectEqual(@as(u32, 41), sink_state.last_framebuffer_id);
    try std.testing.expectEqual(ui.Color.accent, pixels[0]);
}

test "native cpu render rejects framebuffer size mismatch" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 16, .h = 16 }, .accent, .clear, 0, 0, 0);

    var pixels: [32 * 32]ui.Color = undefined;
    const alpha = [_]u8{255};
    const atlases = renderer_software.IrAtlases{
        .font = .{ .width = 1, .height = 1, .alpha = &alpha },
        .icon = .{ .width = 1, .height = 1, .alpha = &alpha },
    };
    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    var sink_state = TestSink{};

    try std.testing.expectError(error.InvalidFramebuffer, renderCpuAndSubmit(
        .{ .wayland = .{
            .surface_id = 53,
            .buffer_id = 59,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        atlases,
        .{ .width = 32, .height = 32, .pixels = &pixels },
        .clear,
        60,
        16,
        16,
        &tile_marks,
        &dirty_ids,
        sink_state.waylandSink(),
    ));
}

test "native gpu render submits wayland commit from canonical ir" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 32, .h = 32 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var gpu_device = TestGpuDevice{};
    var sink_state = TestSink{};
    const receipt = try renderGpuAndSubmit(
        .{ .wayland = .{
            .surface_id = 61,
            .buffer_id = 67,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        .{},
        gpu_device.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        60,
        16,
        16,
        sink_state.waylandSink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_present.Transport.gpu_command_stream, receipt.gpu.presentation_transport);
    try std.testing.expectEqual(renderer_present.Transport.wayland_surface, receipt.native.transport);
    try std.testing.expectEqual(@as(usize, 1), gpu_device.began);
    try std.testing.expectEqual(receipt.gpu.primitive_count, gpu_device.uploaded);
    try std.testing.expectEqual(receipt.gpu.dirty_tile_count, gpu_device.rendered);
    try std.testing.expectEqual(@as(usize, 1), gpu_device.presented);
    try std.testing.expectEqual(receipt.gpu.sequence, gpu_device.last_sequence);
    try std.testing.expectEqual(@as(usize, 1), sink_state.wayland_count);
    try std.testing.expectEqual(@as(u32, 61), sink_state.last_surface_id);
}

test "native gpu backed render binds scanout surface before native commit" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 4, .y = 4, .w = 24, .h = 24 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var gpu_device = TestGpuDevice{};
    var sink_state = TestSink{};
    const receipt = try renderGpuBackedAndSubmit(
        .{ .drm = .{
            .framebuffer_id = 97,
            .connector_id = 101,
            .crtc_id = 103,
            .width = 64,
            .height = 64,
            .stride = 64,
            .gpu_buffer = .{ .kind = .scanout, .handle = 0xabc },
        } },
        buffers,
        .{},
        gpu_device.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        60,
        16,
        16,
        sink_state.drmSink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_present.Transport.gpu_command_stream, receipt.gpu.presentation_transport);
    try std.testing.expectEqual(renderer_present.Transport.drm_framebuffer, receipt.native.transport);
    try std.testing.expectEqual(@as(usize, 1), gpu_device.began);
    try std.testing.expectEqual(@as(usize, 2), receipt.gpu.primitive_count);
    try std.testing.expectEqual(receipt.gpu.primitive_count, gpu_device.uploaded);
    try std.testing.expectEqual(@as(usize, 1), sink_state.drm_count);
    try std.testing.expectEqual(@as(u32, 97), sink_state.last_framebuffer_id);
}

test "native gpu backed render rejects shared memory as gpu output" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 16, .h = 16 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var gpu_device = TestGpuDevice{};
    var sink_state = TestSink{};

    try std.testing.expectError(error.InvalidGpuBuffer, renderGpuBackedAndSubmit(
        .{ .wayland = .{
            .surface_id = 107,
            .buffer_id = 109,
            .width = 64,
            .height = 64,
            .stride = 64,
            .gpu_buffer = .{ .kind = .shared_memory, .handle = 0xdef },
        } },
        buffers,
        .{},
        gpu_device.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        60,
        16,
        16,
        sink_state.waylandSink(),
    ));
    try std.testing.expectEqual(@as(usize, 0), gpu_device.began);
    try std.testing.expectEqual(@as(usize, 0), sink_state.wayland_count);
}

test "native gpu render rejects missing resources before native submit" {
    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride;

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var gpu_device = TestGpuDevice{};
    var sink_state = TestSink{};

    try std.testing.expectError(error.MissingFontAtlas, renderGpuAndSubmit(
        .{ .drm = .{
            .framebuffer_id = 71,
            .connector_id = 73,
            .crtc_id = 79,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        storage.buffers(),
        .{},
        gpu_device.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        60,
        16,
        16,
        sink_state.drmSink(),
    ));
    try std.testing.expectEqual(@as(usize, 0), gpu_device.began);
    try std.testing.expectEqual(@as(usize, 0), sink_state.drm_count);
}

test "native gpu render fails when gpu device rejects frame" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 16, .h = 16 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var gpu_device = TestGpuDevice{ .reject_present = true };
    var sink_state = TestSink{};

    try std.testing.expectError(error.DeviceFailure, renderGpuAndSubmit(
        .{ .wayland = .{
            .surface_id = 83,
            .buffer_id = 89,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        .{},
        gpu_device.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        60,
        16,
        16,
        sink_state.waylandSink(),
    ));
    try std.testing.expectEqual(@as(usize, 1), gpu_device.began);
    try std.testing.expectEqual(@as(usize, 0), sink_state.wayland_count);
}

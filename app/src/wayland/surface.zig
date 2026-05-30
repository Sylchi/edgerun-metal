const std = @import("std");
const protocol = @import("protocol.zig");
const client = @import("client.zig");

const renderer_font_atlas = @import("../render/font_atlas_weighted.zig");
const renderer_gpu = @import("../render/backends/gpu.zig");
const renderer_ir = @import("../render/ir.zig");
const renderer_pipeline = @import("../render/pipeline.zig");
const renderer_native_present = @import("../render/native_present.zig");
const renderer_software = @import("../render/backends/software.zig");
const renderer_gpu_buffer = @import("../render/gpu_buffer.zig");
const app_cursor = @import("../ui/cursor.zig");
const icon_line_buffer = @import("../render/icon_line_buffer.zig");
const ui = @import("../ui/core.zig");
const linux_drm = @import("../linux_drm.zig");

const posix = std.posix;
const linux = std.os.linux;

pub const default_refresh_hz: u32 = 60;
const tile_width: u32 = 64;
const tile_height: u32 = 64;
const max_tiles: usize = 512;
const max_gpu_primitives: usize = 32768;
const cursor_scene_budget: usize = 32;
const cursor_overlay_icon_instances: usize = 2;

const max_image_vertices: usize = 24576;
const max_rects: usize = 8192;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = icon_line_buffer.max_instance_vertex_count * cursor_overlay_icon_instances;

pub const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

pub const GpuRecorder = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,

    pub fn device(self: *GpuRecorder) renderer_gpu.Device {
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

pub const WaylandCommitSink = struct {
    submitted: bool = false,

    pub fn sink(self: *WaylandCommitSink) renderer_native_present.Sink {
        return .{ .context = self, .submit_wayland = submit };
    }

    fn submit(context: *anyopaque, commit: renderer_native_present.WaylandCommit) bool {
        const self: *WaylandCommitSink = @ptrCast(@alignCast(context));
        self.submitted = commit.surface_id == protocol.surface_id and commit.buffer_id == protocol.wl_buffer_id and commit.dirty_tiles.len != 0;
        return self.submitted;
    }
};

pub const WaylandDmabufCommitSink = struct {
    submitted: bool = false,

    fn sink(self: *WaylandDmabufCommitSink) renderer_native_present.Sink {
        return .{ .context = self, .submit_wayland = submit };
    }

    fn submit(context: *anyopaque, commit: renderer_native_present.WaylandCommit) bool {
        const self: *WaylandDmabufCommitSink = @ptrCast(@alignCast(context));
        self.submitted = commit.surface_id == protocol.surface_id and commit.buffer_id == protocol.dmabuf_wl_buffer_id and commit.dirty_tiles.len != 0;
        return self.submitted;
    }
};

pub fn packXrgb8888(out: []u8, pixels: []const ui.Color) void {
    packXrgb8888Strided(out, @intCast(pixels.len * @sizeOf(u32)), @intCast(pixels.len), 1, pixels);
}

pub fn packXrgb8888Rect(out: []u8, stride_bytes: u32, width: u32, height: u32, pixels: []const ui.Color, rect: protocol.PixelRect) void {
    if (!rect.valid()) return;
    const width_usize: usize = width;
    const height_usize: usize = height;
    if (rect.x >= width_usize or rect.y >= height_usize) return;
    const x_end = @min(width_usize, rect.x + rect.w);
    const y_end = @min(height_usize, rect.y + rect.h);
    var y = rect.y;
    while (y < y_end) : (y += 1) {
        const pixel_row = y * width_usize;
        const byte_row = y * stride_bytes;
        var x = rect.x;
        while (x < x_end) : (x += 1) {
            const pixel = pixels[pixel_row + x];
            const base = byte_row + x * @sizeOf(u32);
            out[base + 0] = pixel.b;
            out[base + 1] = pixel.g;
            out[base + 2] = pixel.r;
            out[base + 3] = 255;
        }
    }
}

pub fn packXrgb8888Strided(out: []u8, stride_bytes: u32, width: u32, height: u32, pixels: []const ui.Color) void {
    const row_bytes = @as(usize, width) * @sizeOf(u32);
    for (0..height) |y| {
        const out_row = @as(usize, y) * stride_bytes;
        const pixel_row = @as(usize, y) * width;
        for (pixels[pixel_row .. pixel_row + width], 0..) |pixel, x| {
            const base = out_row + x * @sizeOf(u32);
            out[base + 0] = pixel.b;
            out[base + 1] = pixel.g;
            out[base + 2] = pixel.r;
            out[base + 3] = 255;
        }
        if (stride_bytes > row_bytes) @memset(out[out_row + row_bytes .. out_row + stride_bytes], 0);
    }
}

pub fn cursorPixelRect(width: u32, height: u32, x: f32, y: f32, kind: app_cursor.Kind) ?protocol.PixelRect {
    const bounds = app_cursor.damageBounds(x, y, kind) orelse return null;
    return clampPixelRect(width, height, bounds);
}

fn clampPixelRect(width: u32, height: u32, bounds: ui.Rect) ?protocol.PixelRect {
    const max_w: i32 = @intCast(width);
    const max_h: i32 = @intCast(height);
    const x0 = std.math.clamp(@as(i32, @intFromFloat(@floor(bounds.x))), 0, max_w);
    const y0 = std.math.clamp(@as(i32, @intFromFloat(@floor(bounds.y))), 0, max_h);
    const x1 = std.math.clamp(@as(i32, @intFromFloat(@ceil(bounds.x + bounds.w))), 0, max_w);
    const y1 = std.math.clamp(@as(i32, @intFromFloat(@ceil(bounds.y + bounds.h))), 0, max_h);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{ .x = @intCast(x0), .y = @intCast(y0), .w = @intCast(x1 - x0), .h = @intCast(y1 - y0) };
}

pub fn unionPixelRect(a: ?protocol.PixelRect, b: ?protocol.PixelRect) ?protocol.PixelRect {
    if (a == null) return b;
    if (b == null) return a;
    const left = @min(a.?.x, b.?.x);
    const top = @min(a.?.y, b.?.y);
    const right = @max(a.?.x + a.?.w, b.?.x + b.?.w);
    const bottom = @max(a.?.y + a.?.h, b.?.y + b.?.h);
    return .{ .x = left, .y = top, .w = right - left, .h = bottom - top };
}

pub fn fixedToFloat(value: i32) f32 {
    return @as(f32, @floatFromInt(value)) / protocol.fixed_scale;
}

pub fn defaultBackground() ui.Color {
    return .{ .r = 11, .g = 11, .b = 11 };
}

pub const Surface = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    present: @import("options.zig").PresentMode,
    dmabuf_fd: ?posix.fd_t,
    shm: protocol.ShmBuffer,
    pixels: []ui.Color,
    base_pixels: []ui.Color,
    base_pixels_ready: bool = false,
    cursor_damage: ?protocol.PixelRect = null,
    font_atlas: renderer_font_atlas.Atlas,
    gpu_primitives: []renderer_gpu.Primitive,
    gpu_tile_marks: [max_tiles]u8 = undefined,
    gpu_dirty_ids: [max_tiles]u32 = undefined,
    tile_marks: [max_tiles]u8 = undefined,
    dirty_ids: [max_tiles]u32 = undefined,
    ir_storage: IrStorage = .{},
    gpu_recorder: GpuRecorder = .{},
    gpu_buffer_device: renderer_gpu_buffer.CpuFilledDevice = .{},
    drm_buffer: ?linux_drm.DumbBuffer = null,
    first_frame: bool = true,

    pub fn create(allocator: std.mem.Allocator, client_ptr: *client.WaylandClient, options: @import("options.zig").Options) !*Surface {
        const width = options.width;
        const height = options.height;
        const stride = width * @sizeOf(u32);
        const shm = try client_ptr.createShmBuffer(@as(usize, stride) * height, width, height, stride);
        errdefer shm.deinit();
        const pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        const base_pixels = try allocator.alloc(ui.Color, @as(usize, width) * height);
        errdefer allocator.free(base_pixels);
        const gpu_primitives = try allocator.alloc(renderer_gpu.Primitive, max_gpu_primitives);
        errdefer allocator.free(gpu_primitives);
        var drm_buffer: ?linux_drm.DumbBuffer = if (options.present == .gpu_dmabuf and options.dmabuf_fd == null)
            try linux_drm.DumbBuffer.createExported(options.drm_device, width, height, .xrgb8888)
        else
            null;
        errdefer if (drm_buffer) |*buffer| buffer.deinit();

        const self = try allocator.create(Surface);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.width = width;
        self.height = height;
        self.present = options.present;
        self.dmabuf_fd = options.dmabuf_fd;
        self.shm = shm;
        self.pixels = pixels;
        self.base_pixels = base_pixels;
        self.base_pixels_ready = false;
        self.cursor_damage = null;
        self.gpu_primitives = gpu_primitives;
        self.ir_storage = .{};
        self.font_atlas.initUtf8();
        self.gpu_recorder = .{};
        self.gpu_buffer_device = .{};
        self.drm_buffer = drm_buffer;
        self.first_frame = true;
        return self;
    }

    pub fn deinit(self: *Surface) void {
        if (self.drm_buffer) |*buffer| buffer.deinit();
        self.allocator.free(self.gpu_primitives);
        self.allocator.free(self.base_pixels);
        self.allocator.free(self.pixels);
        self.shm.deinit();
    }

    pub fn destroy(self: *Surface) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn waylandSurface(self: *const Surface) renderer_native_present.NativeSurface {
        return .{ .wayland = .{
            .surface_id = protocol.surface_id,
            .buffer_id = protocol.wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = self.width,
            .scale = 1,
        } };
    }

    pub fn dmabufSurface(self: *const Surface) !renderer_native_present.NativeSurface {
        const fd = if (self.dmabuf_fd) |fd| fd else if (self.drm_buffer) |buffer| buffer.dma_buf_fd else return error.MissingDmabufFd;
        const stride = if (self.drm_buffer) |buffer| try buffer.stridePixels() else self.width;
        if (fd < 0) return error.InvalidDmabufImport;
        return .{ .wayland = .{
            .surface_id = protocol.surface_id,
            .buffer_id = protocol.dmabuf_wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = stride,
            .scale = 1,
            .format = .xrgb8888,
            .gpu_buffer = .{
                .kind = .dma_buf,
                .handle = @intCast(fd),
            },
        } };
    }

    pub fn renderScene(
        self: *Surface,
        client_ptr: *client.WaylandClient,
        commands: []const ui.Command,
        background: ui.Color,
        cursor_x: f32,
        cursor_y: f32,
        cursor_kind: ?app_cursor.Kind,
    ) !void {
        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, commands);

        const has_images = for (commands) |c| {
            if (c == .image_quad) break true;
        } else false;
        const image_texture: ?renderer_software.RgbaTexture = if (has_images) try @import("../app_images.zig").cloudMeme() else null;
        var sink_state = WaylandCommitSink{};
        const resources = renderer_pipeline.softwareResources(&self.font_atlas, image_texture);
        switch (self.present) {
            .cpu => {
                const receipt = try renderer_native_present.renderCpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    resources,
                    .{ .width = self.width, .height = self.height, .pixels = self.pixels },
                    background,
                    default_refresh_hz,
                    tile_width,
                    tile_height,
                    &self.tile_marks,
                    &self.dirty_ids,
                    sink_state.sink(),
                );
                if (!receipt.valid() or !sink_state.submitted) return error.WaylandCommitRejected;
                @memcpy(self.base_pixels, self.pixels);
                self.base_pixels_ready = true;
                self.dumpPpm();
                if (cursor_kind) |kind| {
                    self.cursor_damage = try self.renderCursorOverlay(cursor_x, cursor_y, kind);
                }
            },
            .gpu_record => {
                const receipt = try renderer_native_present.renderGpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    resources.presentationResources(),
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
                try self.renderSoftwarePixels(buffers, resources);
            },
            .gpu_dmabuf => {
                const dmabuf_surface = try self.dmabufSurface();
                const import = try protocol.DmabufImport.fromNativeSurface(dmabuf_surface);
                try client_ptr.createDmabufBuffer(import);
                try self.renderSoftwarePixels(buffers, resources);
                if (self.drm_buffer) |*buffer| {
                    const memory = try buffer.map();
                    packXrgb8888Strided(memory, buffer.pitch_bytes, self.width, self.height, self.pixels);
                }
                var dmabuf_sink_state = WaylandDmabufCommitSink{};
                const receipt = try renderer_native_present.renderGpuBackedAndSubmit(
                    dmabuf_surface,
                    buffers,
                    resources.presentationResources(),
                    self.gpu_buffer_device.device(),
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
                if (!receipt.gpuBackedValid() or !dmabuf_sink_state.submitted) return error.WaylandCommitRejected;
                if (receipt.gpu.rasterization != .cpu_filled_gpu_buffer) return error.InvalidGpuReceipt;
                try client_ptr.attachDmabufCommit(self.width, self.height);
                return;
            },
        }
        packXrgb8888(self.shm.memory, self.pixels);
        try client_ptr.attachCommit(self.width, self.height);
    }

    pub fn renderCursorOnly(
        self: *Surface,
        client_ptr: *client.WaylandClient,
        old_x: f32,
        old_y: f32,
        old_kind: app_cursor.Kind,
        new_x: f32,
        new_y: f32,
        new_kind: app_cursor.Kind,
    ) !void {
        if (self.present != .cpu or !self.base_pixels_ready) return error.CursorOverlayUnavailable;
        const old_damage = cursorPixelRect(self.width, self.height, old_x, old_y, old_kind);
        const next_damage = cursorPixelRect(self.width, self.height, new_x, new_y, new_kind);
        const damage = unionPixelRect(old_damage, next_damage) orelse return;
        self.restoreBasePixels(damage);
        self.cursor_damage = try self.renderCursorOverlay(new_x, new_y, new_kind);
        const final_damage = unionPixelRect(damage, self.cursor_damage) orelse damage;
        packXrgb8888Rect(self.shm.memory, self.shm.stride, self.width, self.height, self.pixels, final_damage);
        try client_ptr.attachCommitRect(final_damage);
    }

    pub fn renderCursorOverlay(self: *Surface, hover_x: f32, hover_y: f32, kind: app_cursor.Kind) !?protocol.PixelRect {
        const damage = cursorPixelRect(self.width, self.height, hover_x, hover_y, kind) orelse return null;
        var cursor_commands: [cursor_scene_budget]ui.Command = undefined;
        var scene = ui.Scene.init(&cursor_commands);
        try app_cursor.render(&scene, hover_x, hover_y, kind);
        var cursor_ir = renderer_ir.FixedBuffers(cursor_scene_budget, cursor_overlay_icon_instances, 0, 0, 0, max_overlay_icon_line_vertices, 0){};
        const buffers = cursor_ir.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, scene.written());
        const surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&self.font_atlas, null));
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
        return damage;
    }

    fn restoreBasePixels(self: *Surface, rect: protocol.PixelRect) void {
        var row: usize = 0;
        const width_usize: usize = self.width;
        while (row < rect.h) : (row += 1) {
            const start = (rect.y + row) * width_usize + rect.x;
            const end = start + rect.w;
            @memcpy(self.pixels[start..end], self.base_pixels[start..end]);
        }
    }

    fn renderSoftwarePixels(self: *Surface, buffers: renderer_ir.Buffers, resources: renderer_software.Resources) !void {
        const software_surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        software_surface.clear(defaultBackground());
        const receipt = try software_surface.renderIr(buffers, resources);
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
    }

    fn dumpPpm(self: *Surface) void {
        if (!self.first_frame) return;
        self.first_frame = false;
        const ppm_path = "/tmp/edgerun-hardware-dash.ppm";
        const fd = @as(i32, @intCast(linux.openat(linux.AT.FDCWD, ppm_path, linux.O{ .ACCMODE = .WRONLY, .CREAT = true }, 0o644)));
        if (fd < 0) return;
        defer _ = linux.close(fd);
        var header: [128]u8 = undefined;
        const hdr = std.fmt.bufPrint(&header, "P6\n{d} {d}\n255\n", .{ self.width, self.height }) catch return;
        _ = linux.write(fd, hdr.ptr, hdr.len);
        var row: usize = 0;
        const w = self.width;
        const h = self.height;
        while (row < h) : (row += 1) {
            var col: usize = 0;
            while (col < w) : (col += 1) {
                const px = self.pixels[row * w + col];
                _ = linux.write(fd, &[3]u8{ px.r, px.g, px.b }, 3);
            }
        }
    }
};

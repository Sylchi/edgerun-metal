const std = @import("std");
const protocol = @import("protocol.zig");
const client = @import("client.zig");


const interaction = @import("../ui_interaction.zig");
const renderer_font_atlas = @import("../render/font_atlas_weighted.zig");
const renderer_gpu = @import("../render/backends/gpu.zig");
const renderer_ir = @import("../render/ir.zig");
const renderer_pipeline = @import("../render/pipeline.zig");
const renderer_native_present = @import("../render/native_present.zig");
const renderer_software = @import("../render/backends/software.zig");
const renderer_gpu_buffer = @import("../render/gpu_buffer.zig");
const app_chrome = @import("../app_chrome.zig");
const app_agent = @import("../app_agent.zig");
const app_cursor = @import("../app_cursor.zig");
const app_frame = @import("../app_frame.zig");
const app_images = @import("../app_images.zig");
const app_navigation = @import("../app_navigation.zig");
const app_native_input = @import("../app_native_input.zig");
const app_dashboard = @import("../app_dashboard.zig");
const app_hardware_dashboard = @import("../app_hardware_dashboard.zig");
const icon_component = @import("../ui/components/Icon.zig");
const ui = @import("../ui.zig");
const text_component = @import("../ui/components/Text.zig");
const renderer_icon_mask = @import("../render/icon_mask.zig");
const icon_vector = @import("../icon_vector.zig");
const icon_line_buffer = @import("../render/icon_line_buffer.zig");
const linux_drm = @import("../linux_drm.zig");
const bytes_mod = @import("../bytes.zig");

const posix = std.posix;
const linux = std.os.linux;

pub const default_refresh_hz: u32 = 60;
const tile_width: u32 = 64;
const tile_height: u32 = 64;
pub const max_commands: usize = 4096;
pub const max_clips: usize = 64;
pub const max_interaction_regions: usize = 1024;
const max_tiles: usize = 512;
const max_gpu_primitives: usize = 32768;
const cursor_scene_budget: usize = 32;
const cursor_overlay_icon_instances: usize = 2;
const cursor_overlay_icon_line_vertices: usize = icon_line_buffer.max_instance_vertex_count * cursor_overlay_icon_instances;

pub const AppState = app_native_input.State;

pub fn appBackground() ui.Color {
    return .{ .r = 11, .g = 11, .b = 11 };
}

pub fn renderNativeAppScene(scene: *ui.Scene, collector: *interaction.Collector, width: u32, height: u32, state: AppState, dashboard_state: *app_dashboard.State, dashboard_mode: bool, hardware_state: ?*app_hardware_dashboard.State, hardware_mode: bool) !void {
    try renderClientDecoration(scene, collector, @floatFromInt(width));
    const content_y = protocol.client_decor_h;
    const content_h = @max(1.0, @as(f32, @floatFromInt(height)) - content_y);
    const bounds = ui.Rect.init(0, content_y, @floatFromInt(width), content_h);
    if (dashboard_mode) {
        try dashboard_state.refresh();
        try dashboard_state.render(scene, bounds, .{});
        return;
    }
    if (hardware_mode) {
        if (hardware_state) |hs| {
            hs.refresh();
            try hs.render(scene, bounds, .{});
        }
        return;
    }
    try app_frame.render(scene, collector, bounds, .{
        .route = state.route,
        .scroll_y = state.scroll_y,
        .hover_x = state.hover_x,
        .hover_y = state.hover_y,
        .agent = state.agent,
        .public_identity = state.public_identity,
        .public_identity_ready = state.public_identity_ready,
    });
}

fn renderClientDecoration(scene: *ui.Scene, collector: *interaction.Collector, width: f32) !void {
    const bounds = ui.Rect.init(0.0, 0.0, width, protocol.client_decor_h);
    try scene.pushRect(bounds, protocol.client_decor_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(0.0, protocol.client_decor_h - 1.0, width, 1.0), protocol.client_decor_border, .fill, 0.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(14.0, 8.0, @max(1.0, width - 168.0), 15.0), "EdgeRun Native", protocol.client_decor_text, .start);

    const close = clientDecorButton(width, 0);
    const minimize = clientDecorButton(width, 1);
    try scene.pushRect(minimize, protocol.client_decor_border, .border, 12.0, 0.0);
    try scene.pushRect(centeredRect(minimize, protocol.client_decor_minimize_w, protocol.client_decor_minimize_h), protocol.client_decor_dim, .fill, 1.0, 0.0);
    try collector.addHit(minimize, .button, protocol.client_decor_minimize_id);

    try scene.pushRect(close, protocol.client_decor_border, .border, 12.0, 0.0);
    try icon_component.Icon.named(.x).renderColor(scene, centeredRect(close, protocol.client_decor_icon_size, protocol.client_decor_icon_size), protocol.client_decor_dim);
    try collector.addHit(close, .button, protocol.client_decor_close_id);

    const drag_w = @max(1.0, minimize.x - protocol.client_decor_button_gap - 140.0);
    try collector.addHit(ui.Rect.init(0.0, 0.0, drag_w, protocol.client_decor_h), .button, protocol.client_decor_drag_id);
}

fn clientDecorButton(width: f32, index: usize) ui.Rect {
    const offset = @as(f32, @floatFromInt(index + 1)) * (protocol.client_decor_button_size + protocol.client_decor_button_gap);
    return ui.Rect.init(width - offset, 5.0, protocol.client_decor_button_size, protocol.client_decor_button_size);
}

fn centeredRect(bounds: ui.Rect, w: f32, h: f32) ui.Rect {
    return ui.Rect.init(bounds.x + (bounds.w - w) * 0.5, bounds.y + (bounds.h - h) * 0.5, w, h);
}

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

pub fn updateHoverHitForState(state: *AppState, regions: []const interaction.Region) void {
    app_native_input.refreshHover(state, regions);
}

pub fn activateClientDecorationForState(state: *AppState, client_ptr: ?*client.WaylandClient) !void {
    const hover_hit_id = state.runtime.hoverHitId();
    switch (hover_hit_id) {
        protocol.client_decor_close_id => {
            app_native_input.clearHover(state);
            if (client_ptr) |c| c.state.closed = true;
            return;
        },
        protocol.client_decor_minimize_id => {
            if (client_ptr) |c| try c.sendMinimize();
            return;
        },
        else => {},
    }
}

pub fn scrollStateBy(state: *AppState, width: u32, height: u32, delta_y: f32) void {
    const viewport_h = @max(1.0, @as(f32, @floatFromInt(height)) - protocol.client_decor_h);
    app_native_input.scrollBy(state, @floatFromInt(width), viewport_h, delta_y);
}

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

const max_image_vertices: usize = 24576;
const max_rects: usize = 8192;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;

pub const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

pub const NativeApp = struct {
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
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_interaction_regions]interaction.Region = undefined,
    region_len: usize = 0,
    ir_storage: IrStorage = .{},
    font_atlas: renderer_font_atlas.Atlas,
    gpu_primitives: []renderer_gpu.Primitive,
    gpu_tile_marks: [max_tiles]u8 = undefined,
    gpu_dirty_ids: [max_tiles]u32 = undefined,
    tile_marks: [max_tiles]u8 = undefined,
    dirty_ids: [max_tiles]u32 = undefined,
    state: AppState = .{ .public_identity = "native-wayland", .reveal_identity = "native-wayland" },
    dashboard_app: app_dashboard.State = .{},
    hardware_app: app_hardware_dashboard.State = .{},
    gpu_recorder: GpuRecorder = .{},
    gpu_buffer_device: renderer_gpu_buffer.CpuFilledDevice = .{},
    drm_buffer: ?linux_drm.DumbBuffer = null,
    dashboard: bool = false,
    hardware: bool = false,
    first_frame: bool = true,

    pub fn create(client_ptr: *client.WaylandClient, allocator: std.mem.Allocator, options: @import("options.zig").Options) !*NativeApp {
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

        const self = try allocator.create(NativeApp);
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
        self.region_len = 0;
        self.ir_storage = .{};
        self.font_atlas.initUtf8();
        self.state = .{
            .route = app_navigation.fromPath(options.path),
            .public_identity = "native-wayland",
            .reveal_identity = "native-wayland",
        };
        self.gpu_recorder = .{};
        self.gpu_buffer_device = .{};
        self.drm_buffer = drm_buffer;
        self.dashboard = options.dashboard;
        self.hardware = options.hardware;
        self.first_frame = true;
        return self;
    }

    pub fn deinit(self: *NativeApp) void {
        if (self.drm_buffer) |*buffer| buffer.deinit();
        self.allocator.free(self.gpu_primitives);
        self.allocator.free(self.base_pixels);
        self.allocator.free(self.pixels);
        self.shm.deinit();
    }

    pub fn destroy(self: *NativeApp) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn render(self: *NativeApp, client_ptr: *client.WaylandClient) !void {
        std.debug.print("RENDER hardware={} dashboard={}\n", .{ self.hardware, self.dashboard });
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        try renderNativeAppScene(&scene, &collector, self.width, self.height, self.state, &self.dashboard_app, self.dashboard, &self.hardware_app, self.hardware);
        self.region_len = collector.written().len;
        self.updateHoverHit(self.regionSlice());
        const cursor_kind = self.state.cursorKind();
        if (self.present != .cpu) try app_cursor.render(&scene, self.state.hover_x, self.state.hover_y, cursor_kind);

        const buffers = self.ir_storage.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, scene.written());
        try renderer_pipeline.packTextQuads(buffers, &self.font_atlas, scene.written());

        const has_images = for (scene.written()) |c| {
            if (c == .image_quad) break true;
        } else false;
        const image_texture: ?renderer_software.RgbaTexture = if (has_images) try app_images.cloudMeme() else null;
        var sink_state = WaylandCommitSink{};
        const resources = renderer_pipeline.softwareResources(&self.font_atlas, image_texture);
        switch (self.present) {
            .cpu => {
                const receipt = try renderer_native_present.renderCpuAndSubmit(
                    self.waylandSurface(),
                    buffers,
                    resources,
                    .{ .width = self.width, .height = self.height, .pixels = self.pixels },
                    appBackground(),
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
                self.cursor_damage = try self.renderCursorOverlay(cursor_kind);
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

    pub fn renderSafe(self: *NativeApp, client_ptr: *client.WaylandClient) void {
        self.render(client_ptr) catch |err| {
            std.debug.print("render error: {s}\n", .{@errorName(err)});
            self.refreshAgentHostConnectivity();
        };
    }

    fn dumpPpm(self: *NativeApp) void {
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

    pub fn refreshAgentHostConnectivity(self: *NativeApp) void {
        const options = @import("options.zig");
        if (self.state.agent.host_launch_requested) return;
        if (options.isHostApiReachable(self.state.agent.host_url)) {
            self.state.agent.connected = true;
            self.state.agent.status.set("Host API connected");
        } else {
            self.state.agent.connected = false;
            self.state.agent.status.set(app_agent.host_not_connected_notice);
        }
    }

    pub fn renderCursorOnly(self: *NativeApp, client_ptr: *client.WaylandClient, old_x: f32, old_y: f32, old_kind: app_cursor.Kind) !void {
        if (self.present != .cpu or !self.base_pixels_ready) return error.CursorOverlayUnavailable;
        const old_damage = cursorPixelRect(self.width, self.height, old_x, old_y, old_kind);
        const next_kind = self.state.cursorKind();
        const next_damage = cursorPixelRect(self.width, self.height, self.state.hover_x, self.state.hover_y, next_kind);
        const damage = unionPixelRect(old_damage, next_damage) orelse return;
        self.restoreBasePixels(damage);
        self.cursor_damage = try self.renderCursorOverlay(next_kind);
        const final_damage = unionPixelRect(damage, self.cursor_damage) orelse damage;
        packXrgb8888Rect(self.shm.memory, self.shm.stride, self.width, self.height, self.pixels, final_damage);
        try client_ptr.attachCommitRect(final_damage);
    }

    pub fn renderCursorOverlay(self: *NativeApp, kind: app_cursor.Kind) !?protocol.PixelRect {
        const damage = cursorPixelRect(self.width, self.height, self.state.hover_x, self.state.hover_y, kind) orelse return null;
        var cursor_commands: [cursor_scene_budget]ui.Command = undefined;
        var scene = ui.Scene.init(&cursor_commands);
        try app_cursor.render(&scene, self.state.hover_x, self.state.hover_y, kind);
        var cursor_ir = renderer_ir.FixedBuffers(cursor_scene_budget, cursor_overlay_icon_instances, 0, 0, 0, cursor_overlay_icon_line_vertices, 0){};
        const buffers = cursor_ir.buffers();
        try renderer_pipeline.packScene(buffers, &self.font_atlas, scene.written());
        try renderer_pipeline.packTextQuads(buffers, &self.font_atlas, scene.written());
        const surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&self.font_atlas, null));
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
        return damage;
    }

    fn restoreBasePixels(self: *NativeApp, rect: protocol.PixelRect) void {
        var row: usize = 0;
        const width_usize: usize = self.width;
        while (row < rect.h) : (row += 1) {
            const start = (rect.y + row) * width_usize + rect.x;
            const end = start + rect.w;
            @memcpy(self.pixels[start..end], self.base_pixels[start..end]);
        }
    }

    fn waylandSurface(self: *const NativeApp) renderer_native_present.NativeSurface {
        return .{ .wayland = .{
            .surface_id = protocol.surface_id,
            .buffer_id = protocol.wl_buffer_id,
            .width = self.width,
            .height = self.height,
            .stride = self.width,
            .scale = 1,
        } };
    }

    pub fn dmabufSurface(self: *const NativeApp) !renderer_native_present.NativeSurface {
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

    fn renderSoftwarePixels(self: *NativeApp, buffers: renderer_ir.Buffers, resources: renderer_software.Resources) !void {
        const software_surface = try renderer_software.Framebuffer.init(self.width, self.height, self.pixels);
        software_surface.clear(appBackground());
        const receipt = try software_surface.renderIr(buffers, resources);
        if (!receipt.valid()) return error.InvalidSoftwareReceipt;
    }

    pub fn handleWaylandInput(self: *NativeApp, client_ptr: *client.WaylandClient, kind: protocol.ObjectKind, message: protocol.Message) !bool {
        if (kind != .pointer) return false;
        switch (message.opcode) {
            protocol.wl_pointer_enter_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                try client_ptr.sendHidePointerCursor(serial);
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[12..16], .little));
                app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), .pointer_move);
                return true;
            },
            protocol.wl_pointer_leave_event => {
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_kind = self.state.cursorKind();
                app_native_input.clearHover(&self.state);
                if (self.present == .cpu and self.base_pixels_ready) {
                    try self.renderCursorOnly(client_ptr, old_x, old_y, old_kind);
                    return false;
                }
                return true;
            },
            protocol.wl_pointer_motion_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const old_x = self.state.hover_x;
                const old_y = self.state.hover_y;
                const old_hit = self.state.runtime.hoverHitId();
                const old_kind = self.state.cursorKind();
                self.state.hover_x = fixedToFloat(std.mem.readInt(i32, message.payload[4..8], .little));
                self.state.hover_y = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), .pointer_move);
                if (self.state.runtime.hoverHitId() != old_hit) return true;
                if (self.present == .cpu and self.base_pixels_ready) {
                    try self.renderCursorOnly(client_ptr, old_x, old_y, old_kind);
                    return false;
                }
                return @abs(self.state.hover_x - old_x) >= 8.0 or @abs(self.state.hover_y - old_y) >= 8.0;
            },
            protocol.wl_pointer_button_event => {
                if (message.payload.len < 16) return error.InvalidWaylandMessage;
                const serial = std.mem.readInt(u32, message.payload[0..4], .little);
                const button = std.mem.readInt(u32, message.payload[8..12], .little);
                const state = std.mem.readInt(u32, message.payload[12..16], .little);
                if (button == protocol.wl_pointer_button_left) {
                    if (state == protocol.wl_pointer_button_released) {
                        app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), .pointer_up);
                        try self.activateClientDecoration(client_ptr);
                    } else {
                        app_native_input.processPointerEvent(&self.state, &.{}, self.regionSlice(), .pointer_down);
                        if (self.state.runtime.hoverHitId() == protocol.client_decor_drag_id) try client_ptr.sendMove(serial);
                    }
                }
                return true;
            },
            protocol.wl_pointer_axis_event => {
                if (message.payload.len < 12) return error.InvalidWaylandMessage;
                const axis = std.mem.readInt(u32, message.payload[4..8], .little);
                const value = fixedToFloat(std.mem.readInt(i32, message.payload[8..12], .little));
                if (axis == protocol.wl_pointer_axis_vertical_scroll) scrollStateBy(&self.state, self.width, self.height, value);
                return true;
            },
            else => return false,
        }
    }

    pub fn updateHoverHit(self: *NativeApp, regions: []const interaction.Region) void {
        app_native_input.refreshHover(&self.state, regions);
    }

    pub fn regionSlice(self: *const NativeApp) []const interaction.Region {
        return self.regions[0..self.region_len];
    }

    fn activateClientDecoration(self: *NativeApp, client_ptr: *client.WaylandClient) !void {
        try activateClientDecorationForState(&self.state, client_ptr);
    }
};

pub fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and bytes_mod.eql(command.text.value, value)) return true;
    }
    return false;
}

pub fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasIcon(commands: []const ui.Command, value: icon_component.Icon) bool {
    return hasIconId(commands, value.tag());
}

pub fn hasIconId(commands: []const ui.Command, icon_id: u32) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

pub fn hitRect(regions: []const interaction.Region, id: u32) !ui.Rect {
    for (regions) |region| {
        if (region.id == id) return region.bounds;
    }
    return error.MissingHit;
}

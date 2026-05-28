const std = @import("std");
const renderer_ir = @import("../ir.zig");
const renderer_present = @import("../present.zig");
const renderer_surface = @import("../surface.zig");
const component_union = @import("../../ui/components/Component.zig");
const node_renderer = @import("../../ui/components/NodeRenderer.zig");
const ui = @import("../../ui.zig");

pub const Error = renderer_present.Error || error{
    InvalidMode,
    InvalidDevice,
    PrimitiveBudgetExceeded,
    DirtyTileBudgetExceeded,
    SurfaceBudgetExceeded,
    InvalidSurface,
    InvalidIrBuffer,
    DeviceFailure,
};

pub const Backend = enum(u8) {
    gpu,
};

pub const Rasterization = enum(u8) {
    recorded_commands,
    cpu_filled_gpu_buffer,
    hardware_gpu,
};

const scene_rect_budget: usize = 4096;
const scene_text_vertex_budget: usize = 24576;
const scene_icon_budget: usize = 4096;
const scene_image_vertex_budget: usize = 384;
const scene_overlay_rect_budget: usize = 512;
const scene_overlay_text_vertex_budget: usize = 8192;
const scene_overlay_icon_budget: usize = 256;

pub const SurfaceFormat = enum(u32) {
    xrgb8888 = 0x34325258,
    argb8888 = 0x34325241,
};

pub const BufferKind = enum(u8) {
    shared_memory,
    scanout,
    dma_buf,
};

pub const SurfaceBuffer = struct {
    kind: BufferKind,
    width: u32,
    height: u32,
    stride: u32,
    format: SurfaceFormat,
    handle: u64,
    offset: u32 = 0,
    modifier: u64 = 0,
    plane_count: u8 = 1,

    pub fn valid(self: SurfaceBuffer) bool {
        return self.width != 0 and
            self.height != 0 and
            self.stride >= self.width * renderer_surface.bytes_per_pixel and
            self.handle != 0 and
            self.plane_count != 0;
    }
};

pub const Surface = struct {
    id: u32,
    x: i32 = 0,
    y: i32 = 0,
    width: u32,
    height: u32,
    opacity: u8 = 255,
    buffer_scale: u8 = 1,
    is_opaque: bool = false,
    buffer: SurfaceBuffer,

    pub fn valid(self: Surface) bool {
        return self.id != 0 and
            self.width != 0 and
            self.height != 0 and
            self.opacity != 0 and
            self.buffer_scale != 0 and
            self.buffer.valid();
    }
};

pub const PrimitiveKind = enum(u8) {
    surface,
    rect,
    border,
    text,
    icon_quad,
    text_quad,
    image_quad,
};

pub const Primitive = struct {
    kind: PrimitiveKind,
    bounds: ui.Rect,
    color: ui.Color,
    color2: ui.Color = .clear,
    rect_mode: ui.RectMode = .fill,
    radius: f32 = 0.0,
    shadow: f32 = 0.0,
    surface_id: u32 = 0,
    buffer_handle: u64 = 0,
    buffer_modifier: u64 = 0,
    atlas_id: u32 = 0,
    icon_id: u32 = 0,
    u0: f32 = 0.0,
    v0: f32 = 0.0,
    u1: f32 = 1.0,
    v1: f32 = 1.0,
    is_opaque: bool = false,
};

pub const CommandBuffer = struct {
    primitives: []Primitive,
    len: usize = 0,

    pub fn init(primitives: []Primitive) CommandBuffer {
        return .{ .primitives = primitives };
    }

    pub fn clear(self: *CommandBuffer) void {
        self.len = 0;
    }

    pub fn append(self: *CommandBuffer, primitive: Primitive) Error!void {
        if (self.len >= self.primitives.len) return error.PrimitiveBudgetExceeded;
        self.primitives[self.len] = primitive;
        self.len += 1;
    }

    pub fn written(self: CommandBuffer) []const Primitive {
        return self.primitives[0..self.len];
    }
};

pub const Frame = struct {
    backend: Backend = .gpu,
    sequence: u64,
    mode: renderer_surface.Mode,
    tile_plan: renderer_surface.TilePlan,
    dirty_tiles: []const u32,
    primitives: []const Primitive,
};

pub const Receipt = struct {
    sequence: u64,
    primitive_count: usize,
    dirty_tile_count: usize,
    presentation_primitive_count: usize = 0,
    presentation_transport: renderer_present.Transport = .command_stream,
    rasterization: Rasterization = .recorded_commands,

    pub fn valid(self: Receipt) bool {
        return self.sequence != 0 and self.primitive_count != 0;
    }

    pub fn hardwareGpuValid(self: Receipt) bool {
        return self.valid() and self.rasterization == .hardware_gpu;
    }
};

pub const Device = struct {
    context: *anyopaque,
    rasterization: Rasterization = .recorded_commands,
    begin_frame: *const fn (context: *anyopaque, frame: Frame) bool,
    upload_primitives: *const fn (context: *anyopaque, primitives: []const Primitive) bool,
    render_tiles: *const fn (context: *anyopaque, dirty_tiles: []const u32) bool,
    present: *const fn (context: *anyopaque, sequence: u64) bool,

    pub fn valid(self: Device) bool {
        return @intFromPtr(self.context) != 0;
    }
};

pub const Renderer = struct {
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    device: Device,
    commands: CommandBuffer,
    tile_marks: []u8,
    dirty_ids: []u32,
    sequence: u64 = 0,

    pub fn init(
        device: Device,
        mode: renderer_surface.Mode,
        tile_width: u32,
        tile_height: u32,
        primitives: []Primitive,
        tile_marks: []u8,
        dirty_ids: []u32,
    ) Error!Renderer {
        if (!device.valid()) return error.InvalidDevice;
        _ = renderer_surface.tilePlanFromMode(mode, tile_width, tile_height, @intCast(dirty_ids.len)) orelse return error.InvalidMode;
        return .{
            .mode = mode,
            .tile_width = tile_width,
            .tile_height = tile_height,
            .device = device,
            .commands = CommandBuffer.init(primitives),
            .tile_marks = tile_marks,
            .dirty_ids = dirty_ids,
        };
    }

    pub fn render(self: *Renderer, surfaces: []const Surface, scene: ui.Scene) Error!Receipt {
        self.sequence += 1;
        const frame = try encodeFrame(
            self.sequence,
            self.mode,
            self.tile_width,
            self.tile_height,
            surfaces,
            scene,
            self.tile_marks,
            self.dirty_ids,
            &self.commands,
        );

        if (!self.device.begin_frame(self.device.context, frame)) return error.DeviceFailure;
        if (!self.device.upload_primitives(self.device.context, frame.primitives)) return error.DeviceFailure;
        if (!self.device.render_tiles(self.device.context, frame.dirty_tiles)) return error.DeviceFailure;
        if (!self.device.present(self.device.context, frame.sequence)) return error.DeviceFailure;

        return .{
            .sequence = frame.sequence,
            .primitive_count = frame.primitives.len,
            .dirty_tile_count = frame.dirty_tiles.len,
            .rasterization = self.device.rasterization,
        };
    }

    pub fn renderIr(self: *Renderer, surfaces: []const Surface, buffers: renderer_ir.Buffers) Error!Receipt {
        return self.renderIrWithResources(surfaces, buffers, .{});
    }

    pub fn renderIrWithResources(self: *Renderer, surfaces: []const Surface, buffers: renderer_ir.Buffers, resources: renderer_present.Resources) Error!Receipt {
        self.sequence += 1;
        const presentation = try renderer_present.present(.{
            .target = .{
                .destination = .command_frame,
                .width = self.mode.width,
                .height = self.mode.height,
            },
            .buffers = buffers,
            .resources = resources,
        });
        const frame = try encodeIrFrame(
            self.sequence,
            self.mode,
            self.tile_width,
            self.tile_height,
            surfaces,
            buffers,
            self.tile_marks,
            self.dirty_ids,
            &self.commands,
        );

        if (!self.device.begin_frame(self.device.context, frame)) return error.DeviceFailure;
        if (!self.device.upload_primitives(self.device.context, frame.primitives)) return error.DeviceFailure;
        if (!self.device.render_tiles(self.device.context, frame.dirty_tiles)) return error.DeviceFailure;
        if (!self.device.present(self.device.context, frame.sequence)) return error.DeviceFailure;

        return .{
            .sequence = frame.sequence,
            .primitive_count = frame.primitives.len,
            .dirty_tile_count = frame.dirty_tiles.len,
            .presentation_primitive_count = presentation.primitive_count,
            .presentation_transport = presentation.transport,
            .rasterization = self.device.rasterization,
        };
    }
};

pub fn available(mode: renderer_surface.Mode) bool {
    return mode.valid();
}

pub fn encodeFrame(
    sequence: u64,
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    surfaces: []const Surface,
    scene: ui.Scene,
    tile_marks: []u8,
    dirty_ids: []u32,
    out: *CommandBuffer,
) Error!Frame {
    var storage = renderer_ir.FixedBuffers(
        scene_rect_budget,
        scene_text_vertex_budget,
        scene_icon_budget,
        scene_image_vertex_budget,
        scene_overlay_rect_budget,
        scene_overlay_text_vertex_budget,
        scene_overlay_icon_budget,
        0,
        0,
    ){};
    const buffers = storage.buffers();
    var context: u8 = 0;
    const sources = renderer_ir.Sources{ .font = renderer_ir.commandAdapterFont(&context) };
    renderer_ir.packScene(buffers, sources, scene.written()) catch return error.InvalidIrBuffer;
    return encodeIrFrame(sequence, mode, tile_width, tile_height, surfaces, buffers, tile_marks, dirty_ids, out);
}

pub fn encodeIrFrame(
    sequence: u64,
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    surfaces: []const Surface,
    buffers: renderer_ir.Buffers,
    tile_marks: []u8,
    dirty_ids: []u32,
    out: *CommandBuffer,
) Error!Frame {
    if (sequence == 0) return error.InvalidMode;
    const plan = renderer_surface.tilePlanFromMode(mode, tile_width, tile_height, @intCast(dirty_ids.len)) orelse return error.InvalidMode;
    var dirty = renderer_surface.DirtyTileList{ .tile_ids = dirty_ids };
    if (!renderer_surface.dirtyTilesReset(plan, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;
    renderer_ir.validateBuffers(buffers) catch return error.InvalidIrBuffer;
    out.clear();

    for (surfaces) |surface| {
        try encodeSurface(surface, out);
        try markDirtyRect(plan, @floatFromInt(surface.x), @floatFromInt(surface.y), @floatFromInt(surface.width), @floatFromInt(surface.height), tile_marks, &dirty);
    }

    try encodeIrBuffers(buffers, out);
    if (!renderer_surface.dirtyTilesMarkIrBuffers(plan, buffers, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;

    return .{
        .sequence = sequence,
        .mode = mode,
        .tile_plan = plan,
        .dirty_tiles = dirty.written(),
        .primitives = out.written(),
    };
}

fn encodeSurface(surface: Surface, out: *CommandBuffer) Error!void {
    if (!surface.valid()) return error.InvalidSurface;
    try out.append(.{
        .kind = .surface,
        .bounds = .{
            .x = @floatFromInt(surface.x),
            .y = @floatFromInt(surface.y),
            .w = @floatFromInt(surface.width),
            .h = @floatFromInt(surface.height),
        },
        .color = .{ .r = 255, .g = 255, .b = 255, .a = surface.opacity },
        .surface_id = surface.id,
        .buffer_handle = surface.buffer.handle,
        .buffer_modifier = surface.buffer.modifier,
        .is_opaque = surface.is_opaque,
    });
}

fn encodeIrBuffers(
    buffers: renderer_ir.Buffers,
    out: *CommandBuffer,
) Error!void {
    for (renderer_ir.drawBatches(buffers)) |batch| switch (batch) {
        .rects, .overlay_rects => |rects| try encodeIrRects(rects, out),
        .image => |vertices| try encodeIrTextured(.image_quad, vertices, out),
        .text, .overlay_text => |vertices| try encodeIrTextured(.text_quad, vertices, out),
        .svg, .overlay_icon => |instances| try encodeIrIcons(instances, out),
        .icon_lines, .overlay_icon_lines => {},
    };
}

fn encodeIrRects(
    values: []const f32,
    out: *CommandBuffer,
) Error!void {
    var iter = renderer_ir.RectIterator.init(values) catch return error.InvalidIrBuffer;
    while (iter.next() catch return error.InvalidIrBuffer) |rect| {
        const kind: PrimitiveKind = switch (rect.mode) {
            .border => .border,
            .fill, .shadow, .linear_gradient, .pie_slice => .rect,
        };
        try out.append(.{
            .kind = kind,
            .bounds = rect.bounds,
            .color = rect.color,
            .color2 = rect.color2,
            .rect_mode = rect.mode,
            .radius = rect.radius,
            .shadow = rect.shadow,
        });
    }
}

fn encodeIrTextured(
    kind: PrimitiveKind,
    values: []const f32,
    out: *CommandBuffer,
) Error!void {
    var iter = renderer_ir.TexturedQuadIterator.init(values) catch return error.InvalidIrBuffer;
    while (iter.next() catch return error.InvalidIrBuffer) |quad| {
        const primitive = irTexturedPrimitive(kind, quad);
        try out.append(primitive);
    }
}

fn encodeIrIcons(
    values: []const f32,
    out: *CommandBuffer,
) Error!void {
    var iter = renderer_ir.IconIterator.init(values) catch return error.InvalidIrBuffer;
    while (iter.next() catch return error.InvalidIrBuffer) |instance| {
        try out.append(.{
            .kind = .icon_quad,
            .bounds = instance.bounds,
            .color = instance.color,
            .icon_id = instance.icon_id,
        });
    }
}

fn irTexturedPrimitive(kind: PrimitiveKind, quad: renderer_ir.TexturedQuad) Primitive {
    return .{
        .kind = kind,
        .bounds = quad.bounds,
        .color = quad.color,
        .u0 = quad.u0,
        .v0 = quad.v0,
        .u1 = quad.u1,
        .v1 = quad.v1,
    };
}

fn markDirtyRect(
    plan: renderer_surface.TilePlan,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    tile_marks: []u8,
    dirty: *renderer_surface.DirtyTileList,
) Error!void {
    if (!renderer_surface.dirtyTilesMarkRect(plan, x, y, w, h, tile_marks, dirty)) return error.DirtyTileBudgetExceeded;
}

fn encodeCommand(command: ui.Command, out: *CommandBuffer) Error!void {
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var context: u8 = 0;
    const sources = renderer_ir.Sources{ .font = renderer_ir.commandAdapterFont(&context) };
    const commands = [_]ui.Command{command};
    renderer_ir.packScene(buffers, sources, &commands) catch return error.InvalidIrBuffer;
    try encodeIrBuffers(buffers, out);
}

fn quadPrimitive(kind: PrimitiveKind, quad: ui.Quad) Primitive {
    return .{
        .kind = kind,
        .bounds = quad.bounds,
        .color = quad.color,
        .atlas_id = quad.atlas_id,
        .u0 = quad.u0,
        .v0 = quad.v0,
        .u1 = quad.u1,
        .v1 = quad.v1,
    };
}

fn iconPrimitive(quad: ui.IconQuad) Primitive {
    return .{
        .kind = .icon_quad,
        .bounds = quad.bounds,
        .color = quad.color,
        .icon_id = quad.icon_id,
    };
}

const TestDevice = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,
    rasterization: Rasterization = .recorded_commands,

    fn device(self: *TestDevice) Device {
        return .{
            .context = self,
            .rasterization = self.rasterization,
            .begin_frame = beginFrame,
            .upload_primitives = uploadPrimitives,
            .render_tiles = renderTiles,
            .present = present,
        };
    }

    fn beginFrame(context: *anyopaque, frame: Frame) bool {
        const self: *TestDevice = @ptrCast(@alignCast(context));
        if (frame.sequence == 0 or frame.primitives.len == 0) return false;
        self.began += 1;
        return true;
    }

    fn uploadPrimitives(context: *anyopaque, primitives: []const Primitive) bool {
        const self: *TestDevice = @ptrCast(@alignCast(context));
        if (primitives.len == 0) return false;
        self.uploaded += primitives.len;
        return true;
    }

    fn renderTiles(context: *anyopaque, dirty_tiles: []const u32) bool {
        const self: *TestDevice = @ptrCast(@alignCast(context));
        if (dirty_tiles.len == 0) return false;
        self.rendered += dirty_tiles.len;
        return true;
    }

    fn present(context: *anyopaque, sequence: u64) bool {
        const self: *TestDevice = @ptrCast(@alignCast(context));
        if (sequence == 0) return false;
        self.presented += 1;
        self.last_sequence = sequence;
        return true;
    }
};

fn testSurface() Surface {
    return .{
        .id = 11,
        .x = 8,
        .y = 12,
        .width = 128,
        .height = 64,
        .is_opaque = true,
        .buffer = .{
            .kind = .dma_buf,
            .width = 128,
            .height = 64,
            .stride = 512,
            .format = .xrgb8888,
            .handle = 0xabc,
            .modifier = 0x0102030405060708,
        },
    };
}

fn testScene(out: []ui.Command) !ui.Scene {
    var nodes: [2]ui.Node = undefined;
    nodes[0] = .{ .text = .{ .value = "GPU", .color = .accent } };
    nodes[1] = .{ .button = .{ .id = 3, .label = "Go" } };
    const root = ui.Node{ .stack = .{ .axis = .column, .children = &nodes } };
    var scene = ui.Scene.init(out);
    try node_renderer.renderNode(component_union.Component, &scene, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, root, .{});
    return scene;
}

test "gpu compositor encodes surfaces scene primitives and dirty tiles" {
    var commands: [16]ui.Command = undefined;
    const scene = try testScene(&commands);
    var primitives: [16]Primitive = undefined;
    var command_buffer = CommandBuffer.init(&primitives);
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    const surfaces = [_]Surface{testSurface()};

    const frame = try encodeFrame(
        1,
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        &surfaces,
        scene,
        &tile_marks,
        &dirty_ids,
        &command_buffer,
    );

    try std.testing.expect(available(frame.mode));
    try std.testing.expectEqual(PrimitiveKind.surface, frame.primitives[0].kind);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), frame.primitives[0].buffer_modifier);
    try std.testing.expect(frame.primitives.len > surfaces.len);
    try std.testing.expectEqual(ui.RectMode.fill, frame.primitives[1].rect_mode);
    try std.testing.expect(frame.dirty_tiles.len > 0);
    try std.testing.expectEqual(Backend.gpu, frame.backend);
}

test "gpu renderer submits encoded frame to required device callbacks" {
    var commands: [16]ui.Command = undefined;
    const scene = try testScene(&commands);
    var primitives: [16]Primitive = undefined;
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    var test_device = TestDevice{};
    var renderer = try Renderer.init(
        test_device.device(),
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        &primitives,
        &tile_marks,
        &dirty_ids,
    );

    const surfaces = [_]Surface{testSurface()};
    const receipt = try renderer.render(&surfaces, scene);
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(@as(usize, 1), test_device.began);
    try std.testing.expect(test_device.uploaded == receipt.primitive_count);
    try std.testing.expect(test_device.rendered == receipt.dirty_tile_count);
    try std.testing.expectEqual(@as(usize, 1), test_device.presented);
    try std.testing.expectEqual(receipt.sequence, test_device.last_sequence);
    try std.testing.expectEqual(Rasterization.recorded_commands, receipt.rasterization);
    try std.testing.expect(!receipt.hardwareGpuValid());
}

test "gpu renderer encodes canonical ir frames" {
    var commands: [16]ui.Command = undefined;
    const scene = try testScene(&commands);
    var storage = renderer_ir.FixedBuffers(8, renderer_ir.textured_quad_vertex_count * 8, renderer_ir.textured_quad_vertex_count * 8, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var source_context: u8 = 0;
    const sources = renderer_ir.Sources{
        .font = .{ .context = &source_context, .metrics = testFontMetrics, .width = testTextWidth, .glyph = testGlyph },
    };
    try renderer_ir.packScene(buffers, sources, scene.written());

    var primitives: [16]Primitive = undefined;
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    var test_device = TestDevice{};
    var renderer = try Renderer.init(
        test_device.device(),
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        &primitives,
        &tile_marks,
        &dirty_ids,
    );

    const surfaces = [_]Surface{testSurface()};
    const receipt = try renderer.renderIrWithResources(&surfaces, buffers, .{ .font_atlas = true });
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(ui.RectMode.fill, primitives[1].rect_mode);
    try std.testing.expect(primitives[1].radius > 0.0);
    try std.testing.expectEqual(renderer_present.Transport.command_stream, receipt.presentation_transport);
    try std.testing.expectEqual(@as(usize, 2), receipt.presentation_primitive_count);
    try std.testing.expectEqual(@as(usize, 1), test_device.began);
    try std.testing.expect(test_device.uploaded == receipt.primitive_count);
    try std.testing.expect(test_device.rendered == receipt.dirty_tile_count);
    try std.testing.expectEqual(receipt.sequence, test_device.last_sequence);
}

test "gpu renderer keeps semantic icon ids separate from texture atlas ids" {
    const expected_icon_id: u32 = 7;
    var storage = renderer_ir.FixedBuffers(0, 0, 1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushSvgQuad(buffers, .base, ui.SvgQuad.fromIconQuad(.{
        .bounds = .{ .x = 8, .y = 8, .w = 16, .h = 16 },
        .icon_id = expected_icon_id,
        .color = .accent,
    }));

    var primitives: [4]Primitive = undefined;
    var tile_marks: [16]u8 = undefined;
    var dirty_ids: [16]u32 = undefined;
    var test_device = TestDevice{};
    var renderer = try Renderer.init(
        test_device.device(),
        .{ .width = 64, .height = 64, .stride = 64, .refresh_hz = 60 },
        16,
        16,
        &primitives,
        &tile_marks,
        &dirty_ids,
    );

    const receipt = try renderer.renderIrWithResources(&.{}, buffers, .{});
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(@as(usize, 1), receipt.primitive_count);
    try std.testing.expectEqual(PrimitiveKind.icon_quad, primitives[0].kind);
    try std.testing.expectEqual(expected_icon_id, primitives[0].icon_id);
    try std.testing.expectEqual(@as(u32, 0), primitives[0].atlas_id);
}

test "gpu renderer receipts carry hardware rasterization capability" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 32, .h = 32 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]Primitive = undefined;
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    var test_device = TestDevice{ .rasterization = .hardware_gpu };
    var renderer = try Renderer.init(
        test_device.device(),
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        &primitives,
        &tile_marks,
        &dirty_ids,
    );

    const receipt = try renderer.renderIr(&.{}, buffers);
    try std.testing.expect(receipt.hardwareGpuValid());
    try std.testing.expectEqual(Rasterization.hardware_gpu, receipt.rasterization);
}

test "gpu renderer rejects textured canonical ir without declared resources" {
    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride;
    const buffers = storage.buffers();

    var primitives: [16]Primitive = undefined;
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    var test_device = TestDevice{};
    var renderer = try Renderer.init(
        test_device.device(),
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        &primitives,
        &tile_marks,
        &dirty_ids,
    );

    const surfaces = [_]Surface{testSurface()};
    try std.testing.expectError(error.MissingFontAtlas, renderer.renderIr(&surfaces, buffers));
    try std.testing.expectEqual(@as(usize, 0), test_device.began);
}

fn testFontMetrics(_: *anyopaque, _: u8) renderer_ir.TextMetrics {
    return .{ .ascender = 10.0, .descender = -3.0 };
}

fn testTextWidth(_: *anyopaque, value: []const u8, _: u8) f32 {
    return @as(f32, @floatFromInt(ui.utf8CodepointCount(value))) * 8.0;
}

fn testGlyph(_: *anyopaque, _: u21, _: u8) renderer_ir.Error!?renderer_ir.Glyph {
    return null;
}

pub const Workspace = struct {
    primitives: []Primitive,
    tile_marks: []u8,
    dirty_ids: []u32,
};

pub fn renderIr(
    device: Device,
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    surfaces: []const Surface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    workspace: Workspace,
) Error!Receipt {
    var renderer = try Renderer.init(
        device,
        mode,
        tile_width,
        tile_height,
        workspace.primitives,
        workspace.tile_marks,
        workspace.dirty_ids,
    );
    return renderer.renderIrWithResources(surfaces, buffers, resources);
}

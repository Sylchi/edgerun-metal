const std = @import("std");
const renderer_surface = @import("renderer_surface.zig");
const ui = @import("ui.zig");

pub const Error = error{
    InvalidMode,
    InvalidDevice,
    PrimitiveBudgetExceeded,
    DirtyTileBudgetExceeded,
    SurfaceBudgetExceeded,
    InvalidSurface,
    DeviceFailure,
};

pub const Backend = enum(u8) {
    gpu,
};

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
    surface_id: u32 = 0,
    buffer_handle: u64 = 0,
    atlas_id: u32 = 0,
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

    pub fn valid(self: Receipt) bool {
        return self.sequence != 0 and self.primitive_count != 0;
    }
};

pub const Device = struct {
    context: *anyopaque,
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
    if (sequence == 0) return error.InvalidMode;
    const plan = renderer_surface.tilePlanFromMode(mode, tile_width, tile_height, @intCast(dirty_ids.len)) orelse return error.InvalidMode;
    var dirty = renderer_surface.DirtyTileList{ .tile_ids = dirty_ids };
    if (!renderer_surface.dirtyTilesReset(plan, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;
    out.clear();

    for (surfaces) |surface| {
        try encodeSurface(surface, out);
        if (!renderer_surface.dirtyTilesMarkRect(
            plan,
            @floatFromInt(surface.x),
            @floatFromInt(surface.y),
            @floatFromInt(surface.width),
            @floatFromInt(surface.height),
            tile_marks,
            &dirty,
        )) return error.DirtyTileBudgetExceeded;
    }

    for (scene.written()) |command| {
        try encodeCommand(command, out);
    }
    if (!renderer_surface.dirtyTilesMarkScene(plan, scene, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;

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
        .is_opaque = surface.is_opaque,
    });
}

fn encodeCommand(command: ui.Command, out: *CommandBuffer) Error!void {
    switch (command) {
        .rect => |rect_cmd| try out.append(.{
            .kind = .rect,
            .bounds = rect_cmd.bounds,
            .color = rect_cmd.color,
            .color2 = rect_cmd.color2,
        }),
        .border => |border_cmd| try out.append(.{
            .kind = .border,
            .bounds = border_cmd.bounds,
            .color = border_cmd.color,
        }),
        .text => |text_cmd| try out.append(.{
            .kind = .text,
            .bounds = text_cmd.origin,
            .color = text_cmd.color,
        }),
        .icon_quad => |quad| try out.append(quadPrimitive(.icon_quad, quad)),
        .text_quad => |quad| try out.append(quadPrimitive(.text_quad, quad)),
        .image_quad => |quad| try out.append(quadPrimitive(.image_quad, quad)),
        .hit, .drag_source, .drop_target, .transition => {},
    }
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

const TestDevice = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,

    fn device(self: *TestDevice) Device {
        return .{
            .context = self,
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
        },
    };
}

fn testScene(out: []ui.Command) !ui.Scene {
    var nodes: [2]ui.Node = undefined;
    nodes[0] = .{ .text = .{ .value = "GPU", .color = .accent } };
    nodes[1] = .{ .button = .{ .id = 3, .label = "Go" } };
    const root = ui.Node{ .stack = .{ .axis = .column, .children = &nodes } };
    var scene = ui.Scene.init(out);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});
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
    try std.testing.expect(frame.primitives.len > surfaces.len);
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
}

const std = @import("std");
const renderer_surface = @import("renderer_surface.zig");
const ui = @import("ui.zig");

pub const Error = error{
    InvalidMode,
    PrimitiveBudgetExceeded,
    DirtyTileBudgetExceeded,
};

pub const Backend = enum(u8) {
    gpu,
};

pub const PrimitiveKind = enum(u8) {
    rect,
    border,
    text,
    icon_quad,
    text_quad,
};

pub const Primitive = struct {
    kind: PrimitiveKind,
    bounds: ui.Rect,
    color: ui.Color,
    color2: ui.Color = .clear,
    atlas_id: u32 = 0,
    u0: f32 = 0.0,
    v0: f32 = 0.0,
    u1: f32 = 1.0,
    v1: f32 = 1.0,
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
    mode: renderer_surface.Mode,
    tile_plan: renderer_surface.TilePlan,
    dirty_tiles: []const u32,
    primitives: []const Primitive,
};

pub fn available(mode: renderer_surface.Mode) bool {
    return mode.valid();
}

pub fn encodeFrame(
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    scene: ui.Scene,
    tile_marks: []u8,
    dirty_ids: []u32,
    out: *CommandBuffer,
) Error!Frame {
    const plan = renderer_surface.tilePlanFromMode(mode, tile_width, tile_height, @intCast(dirty_ids.len)) orelse return error.InvalidMode;
    var dirty = renderer_surface.DirtyTileList{ .tile_ids = dirty_ids };
    if (!renderer_surface.dirtyTilesReset(plan, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;
    out.clear();

    for (scene.written()) |command| {
        try encodeCommand(command, out);
    }
    if (!renderer_surface.dirtyTilesMarkScene(plan, scene, tile_marks, &dirty)) return error.DirtyTileBudgetExceeded;

    return .{
        .mode = mode,
        .tile_plan = plan,
        .dirty_tiles = dirty.written(),
        .primitives = out.written(),
    };
}

fn encodeCommand(command: ui.Command, out: *CommandBuffer) Error!void {
    switch (command) {
        .rect => |rect| try out.append(.{
            .kind = .rect,
            .bounds = rect.bounds,
            .color = rect.color,
            .color2 = rect.color2,
        }),
        .border => |border| try out.append(.{
            .kind = .border,
            .bounds = border.bounds,
            .color = border.color,
        }),
        .text => |text| try out.append(.{
            .kind = .text,
            .bounds = text.origin,
            .color = text.color,
        }),
        .icon_quad => |quad| try out.append(quadPrimitive(.icon_quad, quad)),
        .text_quad => |quad| try out.append(quadPrimitive(.text_quad, quad)),
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

test "gpu renderer encodes scene primitives and dirty tiles" {
    var nodes: [2]ui.Node = undefined;
    nodes[0] = .{ .text = .{ .value = "GPU", .color = .accent } };
    nodes[1] = .{ .button = .{ .id = 3, .label = "Go" } };
    const root = ui.Node{ .stack = .{ .axis = .column, .children = &nodes } };

    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

    var primitives: [16]Primitive = undefined;
    var command_buffer = CommandBuffer.init(&primitives);
    var tile_marks: [64]u8 = undefined;
    var dirty_ids: [64]u32 = undefined;
    const frame = try encodeFrame(
        .{ .width = 320, .height = 240, .stride = 320, .refresh_hz = 120 },
        64,
        64,
        scene,
        &tile_marks,
        &dirty_ids,
        &command_buffer,
    );

    try std.testing.expect(available(frame.mode));
    try std.testing.expect(frame.primitives.len > 0);
    try std.testing.expect(frame.dirty_tiles.len > 0);
    try std.testing.expectEqual(Backend.gpu, frame.backend);
}

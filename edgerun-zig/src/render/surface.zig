const std = @import("std");
const renderer_ir = @import("ir.zig");
const ui = @import("../ui.zig");

pub const bytes_per_pixel: u32 = 4;
pub const dirty_tile_id_bytes: u32 = 4;

pub const PixelFormat = enum {
    rgbx,
    bgrx,
};

pub const Mode = struct {
    width: u32,
    height: u32,
    stride: u32,
    refresh_hz: u32,
    pixel_format: PixelFormat = .rgbx,

    pub fn valid(self: Mode) bool {
        return self.width > 0 and self.height > 0 and self.stride >= self.width and self.refresh_hz > 0;
    }
};

pub const TilePlan = struct {
    width: u32 = 0,
    height: u32 = 0,
    stride: u32 = 0,
    bytes_per_pixel: u32 = 4,
    tile_width: u32 = 0,
    tile_height: u32 = 0,
    columns: u32 = 0,
    rows: u32 = 0,
    max_dirty_tiles: u32 = 0,
    tile_count: u64 = 0,
    scanout_bytes: u64 = 0,
    full_frame_bytes: u64 = 0,
    max_tile_bytes: u64 = 0,
    tile_state_bytes: u64 = 0,
    dirty_queue_bytes: u64 = 0,
};

pub const BandwidthPlan = struct {
    refresh_hz: u32 = 0,
    overdraw_budget: u32 = 0,
    scanout_bytes_per_second: u64 = 0,
    full_frame_bytes_per_second: u64 = 0,
    budget_bytes_per_second: u64 = 0,
};

pub const MemoryPlan = struct {
    backing_buffer_count: u32 = 0,
    scanout_bytes: u64 = 0,
    backing_bytes: u64 = 0,
    tile_state_bytes: u64 = 0,
    dirty_queue_bytes: u64 = 0,
    command_bytes: u64 = 0,
    glyph_cache_bytes: u64 = 0,
    surface_bytes: u64 = 0,
    total_bytes: u64 = 0,
};

pub const MemoryBudget = struct {
    scanout_bytes: u64 = 0,
    backing_bytes: u64 = 0,
    tile_state_bytes: u64 = 0,
    dirty_queue_bytes: u64 = 0,
    command_bytes: u64 = 0,
    glyph_cache_bytes: u64 = 0,
    surface_bytes: u64 = 0,
    total_bytes: u64 = 0,
};

pub const Violation = struct {
    name: []const u8,
    actual: u64,
    limit: u64,
};

pub const DirtyTileList = struct {
    tile_ids: []u32,
    count: usize = 0,
    overflowed: bool = false,

    pub fn written(self: DirtyTileList) []const u32 {
        return self.tile_ids[0..self.count];
    }
};

pub const PixelRect = struct {
    x0: u32,
    y0: u32,
    x1: u32,
    y1: u32,
};

pub const FrameState = struct {
    has_previous_scene: bool = false,

    pub fn reset(self: *FrameState) void {
        self.* = .{};
    }

    pub fn commit(self: *FrameState) void {
        self.has_previous_scene = true;
    }
};

pub const RenderStats = struct {
    pixels_written: u64 = 0,
    bytes_written: u64 = 0,
    blend_pixels: u64 = 0,
    text_pixels: u64 = 0,
    rects: u64 = 0,
    icon_quads: u64 = 0,
    text_quads: u64 = 0,
    image_quads: u64 = 0,
    tiles_rendered: u64 = 0,
    dirty_tiles_requested: u64 = 0,
    clipped_primitives: u64 = 0,
    rejected_primitives: u64 = 0,
};

pub const FrameBudget = RenderStats;

pub fn tilePlanFromMode(mode: Mode, tile_width: u32, tile_height: u32, max_dirty_tiles_input: u32) ?TilePlan {
    if (!mode.valid() or tile_width == 0 or tile_height == 0 or max_dirty_tiles_input == 0) return null;
    const columns = divCeil(mode.width, tile_width);
    const rows = divCeil(mode.height, tile_height);
    const tile_count = @as(u64, columns) * @as(u64, rows);
    const max_dirty_tiles = @min(@as(u64, max_dirty_tiles_input), tile_count);
    return .{
        .width = mode.width,
        .height = mode.height,
        .stride = mode.stride,
        .bytes_per_pixel = bytes_per_pixel,
        .tile_width = tile_width,
        .tile_height = tile_height,
        .columns = columns,
        .rows = rows,
        .max_dirty_tiles = @intCast(max_dirty_tiles),
        .tile_count = tile_count,
        .scanout_bytes = @as(u64, mode.stride) * @as(u64, mode.height) * bytes_per_pixel,
        .full_frame_bytes = @as(u64, mode.width) * @as(u64, mode.height) * bytes_per_pixel,
        .max_tile_bytes = @as(u64, tile_width) * @as(u64, tile_height) * bytes_per_pixel,
        .tile_state_bytes = tile_count,
        .dirty_queue_bytes = max_dirty_tiles * dirty_tile_id_bytes,
    };
}

pub fn bandwidthPlanFromMode(mode: Mode, overdraw_budget: u32) ?BandwidthPlan {
    if (!mode.valid() or overdraw_budget == 0) return null;
    const scanout_pixels = mul(mode.stride, mode.height) orelse return null;
    const full_frame_pixels = mul(mode.width, mode.height) orelse return null;
    const scanout_bytes = mul(scanout_pixels, bytes_per_pixel) orelse return null;
    const full_frame_bytes = mul(full_frame_pixels, bytes_per_pixel) orelse return null;
    const scanout_bytes_per_second = mul(scanout_bytes, mode.refresh_hz) orelse return null;
    const full_frame_bytes_per_second = mul(full_frame_bytes, mode.refresh_hz) orelse return null;
    return .{
        .refresh_hz = mode.refresh_hz,
        .overdraw_budget = overdraw_budget,
        .scanout_bytes_per_second = scanout_bytes_per_second,
        .full_frame_bytes_per_second = full_frame_bytes_per_second,
        .budget_bytes_per_second = mul(full_frame_bytes_per_second, overdraw_budget) orelse return null,
    };
}

pub fn memoryPlanFromTilePlan(tile_plan: TilePlan, backing_buffer_count: u32, command_bytes: u64, glyph_cache_bytes: u64, surface_bytes: u64) ?MemoryPlan {
    if (tile_plan.tile_count == 0) return null;
    const backing_bytes = mul(tile_plan.scanout_bytes, backing_buffer_count) orelse return null;
    var total = tile_plan.scanout_bytes;
    total = add(total, backing_bytes) orelse return null;
    total = add(total, tile_plan.tile_state_bytes) orelse return null;
    total = add(total, tile_plan.dirty_queue_bytes) orelse return null;
    total = add(total, command_bytes) orelse return null;
    total = add(total, glyph_cache_bytes) orelse return null;
    total = add(total, surface_bytes) orelse return null;
    return .{
        .backing_buffer_count = backing_buffer_count,
        .scanout_bytes = tile_plan.scanout_bytes,
        .backing_bytes = backing_bytes,
        .tile_state_bytes = tile_plan.tile_state_bytes,
        .dirty_queue_bytes = tile_plan.dirty_queue_bytes,
        .command_bytes = command_bytes,
        .glyph_cache_bytes = glyph_cache_bytes,
        .surface_bytes = surface_bytes,
        .total_bytes = total,
    };
}

pub fn memoryPlanFirstBudgetViolation(plan: MemoryPlan, budget: MemoryBudget) ?Violation {
    const entries = [_]Violation{
        .{ .name = "scanout_bytes", .actual = plan.scanout_bytes, .limit = budget.scanout_bytes },
        .{ .name = "backing_bytes", .actual = plan.backing_bytes, .limit = budget.backing_bytes },
        .{ .name = "tile_state_bytes", .actual = plan.tile_state_bytes, .limit = budget.tile_state_bytes },
        .{ .name = "dirty_queue_bytes", .actual = plan.dirty_queue_bytes, .limit = budget.dirty_queue_bytes },
        .{ .name = "command_bytes", .actual = plan.command_bytes, .limit = budget.command_bytes },
        .{ .name = "glyph_cache_bytes", .actual = plan.glyph_cache_bytes, .limit = budget.glyph_cache_bytes },
        .{ .name = "surface_bytes", .actual = plan.surface_bytes, .limit = budget.surface_bytes },
        .{ .name = "total_bytes", .actual = plan.total_bytes, .limit = budget.total_bytes },
    };
    for (entries) |entry| if (entry.actual > entry.limit) return entry;
    return null;
}

pub fn memoryPlanFitsBudget(plan: MemoryPlan, budget: MemoryBudget) bool {
    return memoryPlanFirstBudgetViolation(plan, budget) == null;
}

pub fn tileRect(plan: TilePlan, tile_id: u32) ?PixelRect {
    if (plan.tile_count == 0 or @as(u64, tile_id) >= plan.tile_count or plan.columns == 0 or plan.tile_width == 0 or plan.tile_height == 0) return null;
    const tx = tile_id % plan.columns;
    const ty = tile_id / plan.columns;
    const x0 = tx * plan.tile_width;
    const y0 = ty * plan.tile_height;
    const x1 = @min(x0 + plan.tile_width, plan.width);
    const y1 = @min(y0 + plan.tile_height, plan.height);
    if (x0 >= x1 or y0 >= y1) return null;
    return .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 };
}

pub fn dirtyTilesReset(plan: TilePlan, tile_marks: []u8, list: *DirtyTileList) bool {
    if (!dirtyInputsValid(plan, tile_marks, list)) return false;
    @memset(tile_marks[0..@intCast(plan.tile_count)], 0);
    list.count = 0;
    list.overflowed = false;
    return true;
}

pub fn dirtyTilesMarkRect(plan: TilePlan, x: f32, y: f32, w: f32, h: f32, tile_marks: []u8, list: *DirtyTileList) bool {
    if (!dirtyInputsValid(plan, tile_marks, list) or !(w > 0.0) or !(h > 0.0)) return false;

    var x0 = floorI64(x);
    var y0 = floorI64(y);
    var x1 = ceilI64(x + w);
    var y1 = ceilI64(y + h);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > plan.width) x1 = plan.width;
    if (y1 > plan.height) y1 = plan.height;
    if (x0 >= x1 or y0 >= y1) return true;

    const tx0: u32 = @intCast(@as(u64, @intCast(x0)) / plan.tile_width);
    const ty0: u32 = @intCast(@as(u64, @intCast(y0)) / plan.tile_height);
    var tx1 = divCeil(@intCast(x1), plan.tile_width);
    var ty1 = divCeil(@intCast(y1), plan.tile_height);
    if (tx1 > plan.columns) tx1 = plan.columns;
    if (ty1 > plan.rows) ty1 = plan.rows;

    var ty = ty0;
    while (ty < ty1) : (ty += 1) {
        var tx = tx0;
        while (tx < tx1) : (tx += 1) {
            const tile_id64 = @as(u64, ty) * plan.columns + tx;
            if (tile_id64 >= plan.tile_count) continue;
            const tile_id: u32 = @intCast(tile_id64);
            if (tile_marks[tile_id] != 0) continue;
            tile_marks[tile_id] = 1;
            if (list.count < list.tile_ids.len and list.count < plan.max_dirty_tiles) {
                list.tile_ids[list.count] = tile_id;
                list.count += 1;
            } else {
                list.overflowed = true;
            }
        }
    }
    return true;
}

pub fn dirtyTilesMarkScene(plan: TilePlan, scene: ui.Scene, tile_marks: []u8, list: *DirtyTileList) bool {
    for (scene.written()) |command| {
        const bounds = switch (command) {
            .rect => |rect| rect.bounds,
            .border => |border| border.bounds,
            .text => |text| text.origin,
            .icon_quad => |quad| quad.bounds,
            .svg_quad => |quad| quad.bounds,
            .text_quad => |quad| quad.bounds,
            .image_quad => |quad| quad.bounds,
            else => continue,
        };
        if (!dirtyTilesMarkRect(plan, bounds.x, bounds.y, bounds.w, bounds.h, tile_marks, list)) return false;
    }
    return true;
}

pub fn dirtyTilesMarkIrBuffers(plan: TilePlan, buffers: renderer_ir.Buffers, tile_marks: []u8, list: *DirtyTileList) bool {
    renderer_ir.validateBuffers(buffers) catch return false;
    for (renderer_ir.drawBatches(buffers)) |batch| {
        const marked = switch (batch) {
            .rects, .overlay_rects => |rects| dirtyTilesMarkIrRects(plan, rects, tile_marks, list),
            .image, .text, .overlay_text => |vertices| dirtyTilesMarkIrTextured(plan, vertices, tile_marks, list),
            .icon, .svg, .overlay_icon => |icons| dirtyTilesMarkIrIcons(plan, icons, tile_marks, list),
            .icon_lines, .overlay_icon_lines => true,
        };
        if (!marked) return false;
    }
    return true;
}

pub fn dirtyTilesMarkSceneDiff(plan: TilePlan, prev: ui.Scene, next: ui.Scene, tile_marks: []u8, list: *DirtyTileList) bool {
    const prev_commands = prev.written();
    const next_commands = next.written();
    const common = @min(prev_commands.len, next_commands.len);
    var i: usize = 0;
    while (i < common) : (i += 1) {
        const a = prev_commands[i];
        const b = next_commands[i];
        if (!std.meta.eql(a, b)) {
            if (!markCommand(plan, a, tile_marks, list) or !markCommand(plan, b, tile_marks, list)) return false;
        }
    }
    while (i < prev_commands.len) : (i += 1) if (!markCommand(plan, prev_commands[i], tile_marks, list)) return false;
    i = common;
    while (i < next_commands.len) : (i += 1) if (!markCommand(plan, next_commands[i], tile_marks, list)) return false;
    return true;
}

pub fn frameDirtyTiles(state: FrameState, plan: TilePlan, prev: ?ui.Scene, next: ui.Scene, tile_marks: []u8, list: *DirtyTileList) bool {
    if (!dirtyTilesReset(plan, tile_marks, list)) return false;
    if (!state.has_previous_scene or prev == null) {
        return dirtyTilesMarkRect(plan, 0.0, 0.0, @floatFromInt(plan.width), @floatFromInt(plan.height), tile_marks, list) and
            dirtyTilesMarkScene(plan, next, tile_marks, list);
    }
    return dirtyTilesMarkSceneDiff(plan, prev.?, next, tile_marks, list);
}

pub fn frameBudgetFromPlan(tile_plan: TilePlan, scene_budget: ui.Budget, overdraw_budget: u32) FrameBudget {
    if (tile_plan.tile_count == 0 or overdraw_budget == 0) return .{};
    const frame_pixels = @as(u64, tile_plan.width) * tile_plan.height;
    const primitive_limit = @as(u64, scene_budget.rects) + scene_budget.icon_quads + scene_budget.text_quads + scene_budget.image_quads;
    return .{
        .pixels_written = frame_pixels * overdraw_budget,
        .bytes_written = tile_plan.full_frame_bytes * overdraw_budget,
        .blend_pixels = frame_pixels * overdraw_budget,
        .text_pixels = frame_pixels,
        .rects = scene_budget.rects,
        .icon_quads = scene_budget.icon_quads,
        .text_quads = scene_budget.text_quads,
        .image_quads = scene_budget.image_quads,
        .tiles_rendered = tile_plan.tile_count,
        .dirty_tiles_requested = tile_plan.max_dirty_tiles,
        .clipped_primitives = primitive_limit * tile_plan.tile_count,
        .rejected_primitives = primitive_limit * tile_plan.tile_count,
    };
}

pub fn renderStatsFirstBudgetViolation(stats: RenderStats, budget: FrameBudget) ?Violation {
    const entries = [_]Violation{
        .{ .name = "pixels_written", .actual = stats.pixels_written, .limit = budget.pixels_written },
        .{ .name = "bytes_written", .actual = stats.bytes_written, .limit = budget.bytes_written },
        .{ .name = "blend_pixels", .actual = stats.blend_pixels, .limit = budget.blend_pixels },
        .{ .name = "text_pixels", .actual = stats.text_pixels, .limit = budget.text_pixels },
        .{ .name = "rects", .actual = stats.rects, .limit = budget.rects },
        .{ .name = "icon_quads", .actual = stats.icon_quads, .limit = budget.icon_quads },
        .{ .name = "text_quads", .actual = stats.text_quads, .limit = budget.text_quads },
        .{ .name = "image_quads", .actual = stats.image_quads, .limit = budget.image_quads },
        .{ .name = "tiles_rendered", .actual = stats.tiles_rendered, .limit = budget.tiles_rendered },
        .{ .name = "dirty_tiles_requested", .actual = stats.dirty_tiles_requested, .limit = budget.dirty_tiles_requested },
        .{ .name = "clipped_primitives", .actual = stats.clipped_primitives, .limit = budget.clipped_primitives },
        .{ .name = "rejected_primitives", .actual = stats.rejected_primitives, .limit = budget.rejected_primitives },
    };
    for (entries) |entry| if (entry.actual > entry.limit) return entry;
    return null;
}

pub fn renderStatsFitBudget(stats: RenderStats, budget: FrameBudget) bool {
    return renderStatsFirstBudgetViolation(stats, budget) == null;
}

pub fn packRgb(format: PixelFormat, r: u8, g: u8, b: u8) u32 {
    return switch (format) {
        .bgrx => (@as(u32, b) << 16) | (@as(u32, g) << 8) | r,
        .rgbx => (@as(u32, r) << 16) | (@as(u32, g) << 8) | b,
    };
}

fn markCommand(plan: TilePlan, command: ui.Command, tile_marks: []u8, list: *DirtyTileList) bool {
    const bounds = switch (command) {
        .rect => |rect| rect.bounds,
        .border => |border| border.bounds,
        .text => |text| text.origin,
        .icon_quad => |quad| quad.bounds,
        .svg_quad => |quad| quad.bounds,
        .text_quad => |quad| quad.bounds,
        .image_quad => |quad| quad.bounds,
        else => return true,
    };
    return dirtyTilesMarkRect(plan, bounds.x, bounds.y, bounds.w, bounds.h, tile_marks, list);
}

fn dirtyTilesMarkIrRects(plan: TilePlan, values: []const f32, tile_marks: []u8, list: *DirtyTileList) bool {
    var iter = renderer_ir.RectIterator.init(values) catch return false;
    while (iter.next() catch return false) |rect| {
        if (!dirtyTilesMarkRect(plan, rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h, tile_marks, list)) return false;
    }
    return true;
}

fn dirtyTilesMarkIrTextured(plan: TilePlan, values: []const f32, tile_marks: []u8, list: *DirtyTileList) bool {
    var iter = renderer_ir.TexturedQuadIterator.init(values) catch return false;
    while (iter.next() catch return false) |quad| {
        if (!dirtyTilesMarkRect(plan, quad.bounds.x, quad.bounds.y, quad.bounds.w, quad.bounds.h, tile_marks, list)) return false;
    }
    return true;
}

fn dirtyTilesMarkIrIcons(plan: TilePlan, values: []const f32, tile_marks: []u8, list: *DirtyTileList) bool {
    var iter = renderer_ir.IconIterator.init(values) catch return false;
    while (iter.next() catch return false) |instance| {
        if (!dirtyTilesMarkRect(plan, instance.bounds.x, instance.bounds.y, instance.bounds.w, instance.bounds.h, tile_marks, list)) return false;
    }
    return true;
}

fn dirtyInputsValid(plan: TilePlan, tile_marks: []u8, list: *const DirtyTileList) bool {
    return plan.tile_count > 0 and plan.tile_count <= tile_marks.len and plan.tile_count <= ~@as(u32, 0) and list.tile_ids.len >= plan.max_dirty_tiles;
}

fn divCeil(value: u32, divisor: u32) u32 {
    return (value + divisor - 1) / divisor;
}

fn add(a: u64, b: u64) ?u64 {
    return std.math.add(u64, a, b) catch null;
}

fn mul(a: anytype, b: anytype) ?u64 {
    return std.math.mul(u64, @as(u64, a), @as(u64, b)) catch null;
}

fn floorI64(value: f32) i64 {
    return @intFromFloat(@floor(value));
}

fn ceilI64(value: f32) i64 {
    return @intFromFloat(@ceil(value));
}

test "tile bandwidth and memory plans match C surface planning" {
    const mode = Mode{ .width = 100, .height = 60, .stride = 128, .refresh_hz = 60 };
    const plan = tilePlanFromMode(mode, 32, 16, 32).?;
    try std.testing.expectEqual(@as(u32, 4), plan.columns);
    try std.testing.expectEqual(@as(u32, 4), plan.rows);
    try std.testing.expectEqual(@as(u64, 16), plan.tile_count);
    try std.testing.expectEqual(@as(u64, 128 * 60 * 4), plan.scanout_bytes);
    try std.testing.expectEqual(@as(u64, 100 * 60 * 4), plan.full_frame_bytes);
    try std.testing.expectEqual(@as(u64, 16), plan.tile_state_bytes);
    try std.testing.expectEqual(@as(u64, 16 * 4), plan.dirty_queue_bytes);

    const bandwidth = bandwidthPlanFromMode(mode, 3).?;
    try std.testing.expectEqual(@as(u64, 128 * 60 * 4 * 60), bandwidth.scanout_bytes_per_second);
    try std.testing.expectEqual(@as(u64, 100 * 60 * 4 * 60 * 3), bandwidth.budget_bytes_per_second);

    const memory = memoryPlanFromTilePlan(plan, 2, 100, 200, 300).?;
    try std.testing.expectEqual(@as(u64, plan.scanout_bytes * 2), memory.backing_bytes);
    const violation = memoryPlanFirstBudgetViolation(memory, .{ .scanout_bytes = 1 }).?;
    try std.testing.expectEqualStrings("scanout_bytes", violation.name);
}

test "dirty tile tracking marks rects scene diffs and overflow" {
    const plan = tilePlanFromMode(.{ .width = 64, .height = 64, .stride = 64, .refresh_hz = 1 }, 16, 16, 4).?;
    var marks: [16]u8 = undefined;
    var ids: [4]u32 = undefined;
    var list = DirtyTileList{ .tile_ids = &ids };
    try std.testing.expect(dirtyTilesReset(plan, &marks, &list));
    try std.testing.expect(dirtyTilesMarkRect(plan, 15.5, 0.0, 2.0, 16.0, &marks, &list));
    try std.testing.expectEqualSlices(u32, &.{ 0, 1 }, list.written());

    try std.testing.expect(dirtyTilesReset(plan, &marks, &list));
    try std.testing.expect(dirtyTilesMarkRect(plan, 0.0, 0.0, 64.0, 64.0, &marks, &list));
    try std.testing.expectEqual(@as(usize, 4), list.count);
    try std.testing.expect(list.overflowed);

    var prev_commands: [4]ui.Command = undefined;
    var next_commands: [4]ui.Command = undefined;
    var prev = ui.Scene.init(&prev_commands);
    var next = ui.Scene.init(&next_commands);
    try prev.pushRect(ui.Rect.init(0, 0, 8, 8), .text, .fill, 0, 0);
    try next.pushRect(ui.Rect.init(32, 32, 8, 8), .text, .fill, 0, 0);
    try std.testing.expect(dirtyTilesReset(plan, &marks, &list));
    try std.testing.expect(dirtyTilesMarkSceneDiff(plan, prev, next, &marks, &list));
    try std.testing.expectEqualSlices(u32, &.{ 0, 10 }, list.written());
}

test "dirty tile tracking marks canonical ir buffers" {
    const plan = tilePlanFromMode(.{ .width = 64, .height = 64, .stride = 64, .refresh_hz = 1 }, 16, 16, 8).?;
    var marks: [16]u8 = undefined;
    var ids: [8]u32 = undefined;
    var list = DirtyTileList{ .tile_ids = &ids };

    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(15.5, 0, 2, 16), .text, .clear, 0, 0, renderer_ir.rectModeCode(.fill));
    try renderer_ir.pushClippedTexturedQuad(buffers.text_vertices, buffers.text_vertex_len, ui.Rect.init(32, 32, 8, 8), ui.Rect.init(32, 32, 8, 8), 0, 0, 1, 1, .accent);

    try std.testing.expect(dirtyTilesReset(plan, &marks, &list));
    try std.testing.expect(dirtyTilesMarkIrBuffers(plan, buffers, &marks, &list));
    try std.testing.expectEqualSlices(u32, &.{ 0, 1, 10 }, list.written());
}

test "frame budget and rgb packing match C planning contracts" {
    const plan = tilePlanFromMode(.{ .width = 20, .height = 10, .stride = 20, .refresh_hz = 1 }, 10, 5, 10).?;
    const budget = frameBudgetFromPlan(plan, .{ .rects = 2, .icon_quads = 3, .text_quads = 4, .image_quads = 0 }, 2);
    try std.testing.expectEqual(@as(u64, 400), budget.pixels_written);
    try std.testing.expectEqual(@as(u64, plan.full_frame_bytes * 2), budget.bytes_written);
    try std.testing.expectEqual(@as(u64, 9 * plan.tile_count), budget.clipped_primitives);
    const image_budget = frameBudgetFromPlan(plan, .{ .rects = 2, .icon_quads = 3, .text_quads = 4, .image_quads = 1 }, 2);
    try std.testing.expectEqual(@as(u64, 10 * plan.tile_count), image_budget.clipped_primitives);
    const violation = renderStatsFirstBudgetViolation(.{ .pixels_written = 401 }, budget).?;
    try std.testing.expectEqualStrings("pixels_written", violation.name);
    try std.testing.expectEqual(@as(u32, 0x112233), packRgb(.rgbx, 0x11, 0x22, 0x33));
    try std.testing.expectEqual(@as(u32, 0x332211), packRgb(.bgrx, 0x11, 0x22, 0x33));
}

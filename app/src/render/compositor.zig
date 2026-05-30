const std = @import("std");
const renderer_ir = @import("ir.zig");
const interaction = @import("../ui_interaction.zig");
const ui = @import("../ui.zig");

pub const Error = error{Budget} || ui.RenderError || interaction.Error || error{
    OverlayBudgetExceeded,
    OverlaySurfaceAlreadyFinished,
};

pub const Receipt = struct {
    input_count: usize,
    total_primitives: usize,
};

pub const Layer = enum {
    scrim,
    menu,
    popover,
    modal,
    toast,
};

const layer_order = [_]Layer{
    .scrim,
    .menu,
    .popover,
    .modal,
    .toast,
};

pub const AppIr = struct {
    buffers: renderer_ir.Buffers,
    layer: Layer,
};

pub fn compose(apps: []const AppIr, output: *renderer_ir.Buffers) Error!Receipt {
    output.clearBase();
    output.clearOverlay();
    var total_primitives: usize = 0;
    for (layer_order) |layer| {
        for (apps) |app| {
            if (app.layer != layer) continue;
            try appendBase(output, app.buffers);
            try appendOverlay(output, app.buffers);
            total_primitives += countPrimitives(app.buffers);
        }
    }
    return .{ .input_count = apps.len, .total_primitives = total_primitives };
}

fn appendBase(dst: *renderer_ir.Buffers, src: renderer_ir.Buffers) Error!void {
    try appendFloats(dst.rects, dst.rect_len, src.liveRects());
    try appendFloats(dst.icon_vertices, dst.icon_vertex_len, src.liveIconVertices());
    try appendFloats(dst.icon_line_vertices, dst.icon_line_vertex_len, src.liveIconLineVertices());
    try appendFloats(dst.image_vertices, dst.image_vertex_len, src.liveImageVertices());
}

fn appendOverlay(dst: *renderer_ir.Buffers, src: renderer_ir.Buffers) Error!void {
    try appendFloats(dst.overlay_rects, dst.overlay_rect_len, src.liveOverlayRects());
    try appendFloats(dst.overlay_icon_vertices, dst.overlay_icon_vertex_len, src.liveOverlayIconVertices());
    try appendFloats(dst.overlay_icon_line_vertices, dst.overlay_icon_line_vertex_len, src.liveOverlayIconLineVertices());
}

fn appendFloats(dst: []f32, dst_len: *usize, src: []const f32) Error!void {
    if (dst_len.* + src.len > dst.len) return error.Budget;
    @memcpy(dst[dst_len.*..][0..src.len], src);
    dst_len.* += src.len;
}

fn countPrimitives(buffers: renderer_ir.Buffers) usize {
    return renderer_ir.primitiveCount(buffers) catch 0;
}

pub const Entry = struct {
    layer: Layer,
    command_start: usize,
    command_end: usize,
    region_start: usize,
    region_end: usize,
};

pub const Host = struct {
    commands: []ui.Command,
    command_len: usize = 0,
    regions: []interaction.Region,
    region_len: usize = 0,
    entries: []Entry,
    entry_len: usize = 0,

    pub fn init(commands: []ui.Command, regions: []interaction.Region, entries: []Entry) Host {
        return .{
            .commands = commands,
            .regions = regions,
            .entries = entries,
        };
    }

    pub fn begin(self: *Host, layer: Layer) Surface {
        return .{
            .host = self,
            .layer = layer,
            .command_start = self.command_len,
            .region_start = self.region_len,
            .scene = ui.Scene.init(self.commands[self.command_len..]),
            .collector = interaction.Collector.init(self.regions[self.region_len..]),
        };
    }

    fn commit(self: *Host, surface: *Surface) Error!void {
        if (surface.finished) return error.OverlaySurfaceAlreadyFinished;
        if (self.entry_len == self.entries.len) return error.OverlayBudgetExceeded;
        const command_end = surface.command_start + surface.scene.written().len;
        const region_end = surface.region_start + surface.collector.written().len;
        if (command_end > self.commands.len or region_end > self.regions.len) return error.OverlayBudgetExceeded;
        self.entries[self.entry_len] = .{
            .layer = surface.layer,
            .command_start = surface.command_start,
            .command_end = command_end,
            .region_start = surface.region_start,
            .region_end = region_end,
        };
        self.entry_len += 1;
        self.command_len = command_end;
        self.region_len = region_end;
        surface.finished = true;
    }

    pub fn flush(self: Host, scene: *ui.Scene, collector: *interaction.Collector) Error!void {
        for (layer_order) |layer| {
            for (self.entries[0..self.entry_len]) |entry| {
                if (entry.layer != layer) continue;
                for (self.commands[entry.command_start..entry.command_end]) |command| try scene.push(command);
                for (self.regions[entry.region_start..entry.region_end]) |region| try collector.add(region);
            }
        }
    }
};

pub const Surface = struct {
    host: *Host,
    layer: Layer,
    command_start: usize,
    region_start: usize,
    scene: ui.Scene,
    collector: interaction.Collector,
    finished: bool = false,

    pub fn finish(self: *Surface) Error!void {
        try self.host.commit(self);
    }
};

test "compositor merges two app ird by layer order" {
    var a_storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    var b_storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    var out_storage = renderer_ir.FixedBuffers(2, 0, 0, 0, 0, 0, 0){};

    const a = a_storage.buffers();
    const b = b_storage.buffers();
    try renderer_ir.pushRect(a, .base, .{ .x = 0, .y = 0, .w = 10, .h = 10 }, .{ .r = 255, .g = 0, .b = 0 }, .{ .r = 0, .g = 0, .b = 0 }, 0, 0, renderer_ir.rectModeCode(.fill));
    try renderer_ir.pushRect(b, .base, .{ .x = 5, .y = 5, .w = 10, .h = 10 }, .{ .r = 0, .g = 255, .b = 0 }, .{ .r = 0, .g = 0, .b = 0 }, 0, 0, renderer_ir.rectModeCode(.fill));

    var output = out_storage.buffers();
    const receipt = try compose(&.{ .{ .buffers = a, .layer = .scrim }, .{ .buffers = b, .layer = .popover } }, &output);
    try std.testing.expectEqual(@as(usize, 2), receipt.input_count);
    try std.testing.expectEqual(@as(usize, 2), receipt.total_primitives);
}

test "compositor preserves layer z order with overlay entries" {
    var commands: [8]ui.Command = undefined;
    var overlay_regions: [4]interaction.Region = undefined;
    var entries: [4]Entry = undefined;
    var host = Host.init(&commands, &overlay_regions, &entries);

    var modal = host.begin(.modal);
    try modal.scene.pushRect(ui.Rect.init(0, 0, 20, 20), ui.Color{ .r = 2, .g = 0, .b = 0, .a = 255 }, .fill, 0.0, 0.0);
    try modal.finish();

    var scrim = host.begin(.scrim);
    try scrim.scene.pushRect(ui.Rect.init(0, 0, 20, 20), ui.Color{ .r = 1, .g = 0, .b = 0, .a = 255 }, .fill, 0.0, 0.0);
    try scrim.finish();

    var scene_commands: [8]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&scene_commands, &clips);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try host.flush(&scene, &collector);

    try std.testing.expectEqual(@as(usize, 2), scene.written().len);
    try std.testing.expectEqual(@as(u8, 1), rectRed(scene.written()[0]));
    try std.testing.expectEqual(@as(u8, 2), rectRed(scene.written()[1]));
}

test "compositor flushes overlay interactions above base content" {
    var commands: [8]ui.Command = undefined;
    var overlay_regions: [4]interaction.Region = undefined;
    var entries: [4]Entry = undefined;
    var host = Host.init(&commands, &overlay_regions, &entries);

    var menu = host.begin(.menu);
    try menu.collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, 2);
    try menu.finish();

    var scene_commands: [8]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&scene_commands, &clips);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, 1);
    try host.flush(&scene, &collector);

    try std.testing.expectEqual(@as(u32, 2), interaction.hitTest(collector.written(), 10, 10).?.id);
}

test "compositor merges two empty buffers" {
    var storage = renderer_ir.FixedBuffers(0, 0, 0, 0, 0, 0, 0){};
    var output = renderer_ir.FixedBuffers(0, 0, 0, 0, 0, 0, 0){};
    const input = storage.buffers();
    var output_buf = output.buffers();
    const receipt = try compose(&.{ .{ .buffers = input, .layer = .scrim } }, &output_buf);
    try std.testing.expectEqual(@as(usize, 1), receipt.input_count);
    try std.testing.expectEqual(@as(usize, 0), receipt.total_primitives);
}

test "compositor reports error when output buffer is too small" {
    var a_storage = renderer_ir.FixedBuffers(2, 0, 0, 0, 0, 0, 0){};
    var small = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};

    const a = a_storage.buffers();
    try renderer_ir.pushRect(a, .base, .{ .x = 0, .y = 0, .w = 10, .h = 10 }, .{ .r = 255, .g = 0, .b = 0 }, .{ .r = 0, .g = 0, .b = 0 }, 0, 0, renderer_ir.rectModeCode(.fill));
    try renderer_ir.pushRect(a, .base, .{ .x = 5, .y = 5, .w = 10, .h = 10 }, .{ .r = 0, .g = 255, .b = 0 }, .{ .r = 0, .g = 0, .b = 0 }, 0, 0, renderer_ir.rectModeCode(.fill));

    const small_buf = small.buffers();
    try std.testing.expectError(error.Budget, compose(&.{.{ .buffers = a, .layer = .scrim }}, &small_buf));
}

fn rectRed(command: ui.Command) u8 {
    return switch (command) {
        .rect => |rect| rect.color.r,
        else => 0,
    };
}

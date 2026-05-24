const std = @import("std");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

const width: usize = 2560;
const height: usize = 1440;
const max_commands: usize = 64;
const max_rects: usize = 256;
const max_text_vertices: usize = 8192;
const empty_texture_vertices: usize = 0;
const empty_alpha = [_]u8{255};
const SnapshotIrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
);

pub fn main(init: std.process.Init) !void {
    try renderSnapshot(init, ".build/edgerun-zig/ui.ppm");
}

fn renderSnapshot(init: std.process.Init, out_path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = width, .h = height }, .{});

    const pixels = try allocator.alloc(ui.Color, width * height);
    defer allocator.free(pixels);

    var ir_storage = SnapshotIrStorage{};
    const buffers = ir_storage.buffers();

    var font_atlas = renderer_font_atlas.Atlas.init();
    const sources = renderer_ir.Sources{
        .font = font_atlas.source(),
        .icon = renderer_font_atlas.nullIconSource(&font_atlas),
    };
    try renderer_ir.packScene(buffers, sources, scene.written());

    const surface = try renderer_software.Surface.init(width, height, pixels);
    surface.clear(.bg);
    _ = try surface.renderIrFrameWithAtlases(buffers, .{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .pixels = font_atlas.textureSlice() },
        .icon = .{ .width = 1, .height = 1, .alpha = &empty_alpha },
    });

    const io = init.io;
    try std.Io.Dir.cwd().createDirPath(io, ".build/edgerun-zig");
    const file = try std.Io.Dir.cwd().createFile(io, out_path, .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ width, height });
    try file.writeStreamingAll(io, header_bytes);

    for (pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

fn sampleRoot(children: []ui.Node) ui.Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "edgerun ui snapshot", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search canonical objects, identities, storage records" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph renderer", .detail = "" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render" } };
    return .{ .stack = .{ .axis = .column, .gap = 18, .padding = 48, .children = children[0..4] } };
}

test "snapshot packs and rasterizes through renderer ir" {
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

    var ir_storage = SnapshotIrStorage{};
    const buffers = ir_storage.buffers();

    var font_atlas = renderer_font_atlas.Atlas.init();
    const sources = renderer_ir.Sources{
        .font = font_atlas.source(),
        .icon = renderer_font_atlas.nullIconSource(&font_atlas),
    };
    try renderer_ir.packScene(buffers, sources, scene.written());
    try std.testing.expect(ir_storage.rect_len > 0);
    try std.testing.expect(ir_storage.text_vertex_len > 0);

    var pixels: [320 * 240]ui.Color = undefined;
    const surface = try renderer_software.Surface.init(320, 240, &pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIrFrameWithAtlases(buffers, .{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .pixels = font_atlas.textureSlice() },
        .icon = .{ .width = 1, .height = 1, .alpha = &empty_alpha },
    });
    try std.testing.expect(receipt.valid());

    var painted: usize = 0;
    for (pixels) |pixel| {
        if (pixel.a != 0 and !std.meta.eql(pixel, ui.Color.bg)) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

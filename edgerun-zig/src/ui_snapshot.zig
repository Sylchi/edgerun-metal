const std = @import("std");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

pub fn main(init: std.process.Init) !void {
    const width = 320;
    const height = 240;

    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = width, .h = height }, .{});

    var pixels: [width * height]ui.Color = undefined;
    const surface = try renderer_software.Surface.init(width, height, &pixels);
    surface.clear(.bg);
    surface.rasterize(scene.written());

    const out_path = ".build/edgerun-zig/ui.ppm";
    const io = init.io;
    const file = try std.Io.Dir.cwd().createFile(io, out_path, .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ width, height });
    try file.writeStreamingAll(io, header_bytes);

    for (surface.pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

fn sampleRoot(children: []ui.Node) ui.Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "edgerun ui", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search objects" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph", .detail = "canonical data in, scene commands out" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render" } };
    return .{ .stack = .{ .axis = .column, .gap = 10, .padding = 16, .children = children[0..4] } };
}

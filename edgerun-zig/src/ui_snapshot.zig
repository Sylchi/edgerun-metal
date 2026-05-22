const std = @import("std");
const ui = @import("ui.zig");

pub fn main(init: std.process.Init) !void {
    const width = 320;
    const height = 240;

    var nodes: [5]ui.Node = undefined;
    const root = ui.example(&nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = width, .h = height }, .{});

    var pixels: [width * height]ui.Color = undefined;
    const surface = try ui.Surface.init(width, height, &pixels);
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

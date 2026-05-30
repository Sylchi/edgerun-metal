const std = @import("std");
const codec = @import("ui_codec.zig");
const component_union = @import("ui/components/Component.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const ui = @import("ui.zig");
const linux = std.os.linux;

const fb_width: usize = 480;
const fb_height: usize = 320;
const max_commands: usize = 4096;
const max_rect_instances: usize = 256;
const max_icon_vertices: usize = 128;
const max_image_vertices: usize = 0;
const max_overlay_rect_instances: usize = 0;
const max_overlay_icon_vertices: usize = 0;
const max_icon_line_vertices: usize = 4096;
const max_overlay_icon_line_vertices: usize = 1024;
const SnapshotIrStorage = renderer_ir.FixedBuffers(
    max_rect_instances,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rect_instances,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

fn readExact(fd: i32, buf: []u8) !void {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = linux.read(fd, buf.ptr + pos, buf.len - pos);
        if (n == 0) return error.EndOfStream;
        pos += n;
    }
}

fn readU32(fd: i32) !u32 {
    var bytes: [4]u8 = undefined;
    try readExact(fd, &bytes);
    return std.mem.readInt(u32, bytes[0..4], .little);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = std.heap.page_allocator;
    const stderr_fd = std.posix.STDERR_FILENO;
    const stdin_fd = std.posix.STDIN_FILENO;
    var frame: u64 = 0;

    while (true) {
        const len = readU32(stdin_fd) catch |err| switch (err) {
            error.EndOfStream => return,
            else => |e| return e,
        };

        if (len == 0 or len > 65536) {
            _ = linux.write(stderr_fd, "bad len\n", 8);
            return;
        }

        const canonical = try allocator.alloc(u8, len);
        defer allocator.free(canonical);
        try readExact(stdin_fd, canonical);

        var nodes: [64]ui.Node = undefined;
        const root = codec.decodeObject(canonical, &nodes) catch |err| {
            _ = linux.write(stderr_fd, "decode err\n", 11);
            return err;
        };

        const pixels = try allocator.alloc(ui.Color, fb_width * fb_height);
        defer allocator.free(pixels);

        var commands: [max_commands]ui.Command = undefined;
        var scene = ui.Scene.init(&commands);
        try node_renderer.renderNode(component_union.Component, &scene, .{
            .x = 0, .y = 0, .w = fb_width, .h = fb_height,
        }, root, .{});

        var ir_storage = SnapshotIrStorage{};
        const buffers = ir_storage.buffers();
        var font_atlas: renderer_font_atlas.Atlas = undefined;
        font_atlas.initUtf8();
        try renderer_pipeline.packScene(buffers, &font_atlas, scene.written());

        const surface = try renderer_software.Framebuffer.init(fb_width, fb_height, pixels);
        surface.clear(.bg);
        _ = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));

        const ppm_name = try std.fmt.allocPrint(allocator, "stream_out_{}.ppm", .{frame});
        defer allocator.free(ppm_name);
        frame += 1;

        const cwd = std.Io.Dir.cwd();
        const file = try cwd.createFile(io, ppm_name, .{ .truncate = true });
        defer file.close(io);

        var header_buf: [64]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, "P6\n{} {}\n255\n", .{ fb_width, fb_height });
        try file.writeStreamingAll(io, header);

        const pixel_bytes = std.mem.sliceAsBytes(pixels);
        try file.writeStreamingAll(io, pixel_bytes);

        _ = linux.write(stderr_fd, "wrote ", 6);
        _ = linux.write(stderr_fd, ppm_name.ptr, ppm_name.len);
        _ = linux.write(stderr_fd, "\n", 1);
    }
}

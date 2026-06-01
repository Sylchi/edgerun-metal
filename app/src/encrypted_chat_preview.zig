const std = @import("er_std");

const app_encrypted_chat = @import("app_encrypted_chat.zig");
const interaction = @import("ui/interaction.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const ui = @import("ui/core.zig");

const W: usize = 1280;
const H: usize = 800;
const max_commands: usize = 4096;
const max_regions: usize = 512;
const max_rects: usize = 8192;
const max_image_vertices: usize = 32768;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 32768;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    0,
    0,
    max_icon_line_vertices,
    0,
);

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const io: std.Io = .{};

    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [max_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    var chat = try app_encrypted_chat.State.initDemo();

    try chat.render(&scene, &collector, ui.Rect.init(0, 0, W, H), .{});

    const pixels = try alloc.alloc(ui.Color, W * H);
    defer alloc.free(pixels);

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, scene.written());

    const surface = try renderer_software.Framebuffer.init(W, H, pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));
    if (!receipt.valid()) return error.RenderFailed;

    try std.Io.Dir.cwd().createDirPath(io, ".build/app");
    const file = try std.Io.Dir.cwd().createFile(io, ".build/app/encrypted_chat.ppm", .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ W, H });
    try file.writeStreamingAll(io, header_bytes);
    for (pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }

    std.debug.print("wrote .build/app/encrypted_chat.ppm ({d} commands, {d} hit regions)\\n", .{ scene.written().len, collector.written().len });
}

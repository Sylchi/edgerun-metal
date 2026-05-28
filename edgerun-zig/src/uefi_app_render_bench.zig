const std = @import("std");
const linux = std.os.linux;
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const interaction = @import("ui_interaction.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/software.zig");
const ui = @import("ui.zig");

const max_width: u32 = 640;
const max_height: u32 = 360;
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_interaction_regions: usize = 4096;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

var commands: [max_commands]ui.Command = undefined;
var clips: [max_clips]ui.Rect = undefined;
var regions: [max_interaction_regions]interaction.Region = undefined;
var ir_storage: IrStorage = .{};
var font_atlas: renderer_font_atlas.Atlas = undefined;
var pixels: [max_width * max_height]ui.Color = undefined;

pub fn main() !void {
    font_atlas.initUtf8();
    const image_texture = try app_images.cloudMeme();

    try runFrame(320, 180, image_texture);
    try runFrame(640, 360, image_texture);
}

fn runFrame(width: u32, height: u32, image_texture: renderer_software.RgbaTexture) !void {
    const build_start = nowNs();
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try app_frame.render(&scene, &collector, ui.Rect.init(0, 0, @floatFromInt(width), @floatFromInt(height)), .{
        .route = .{ .view = .landing },
        .public_identity = "blessed-native-renderer",
        .public_identity_ready = true,
    });
    const build_ns = nowNs() - build_start;

    const buffers = ir_storage.buffers();
    const pack_start = nowNs();
    try renderer_pipeline.packScene(buffers, &font_atlas, .object, scene.written());
    const pack_ns = nowNs() - pack_start;

    const surface = try renderer_software.Framebuffer.init(width, height, pixels[0 .. width * height]);
    const render_start = nowNs();
    const receipt = try renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResources(&font_atlas, image_texture), .bg);
    const render_ns = nowNs() - render_start;
    if (!receipt.valid()) return error.InvalidReceipt;

    std.debug.print(
        \\uefi app render bench {d}x{d}
        \\  scene commands: {d}
        \\  rect floats: {d}
        \\  text floats: {d}
        \\  icon floats: {d}
        \\  icon line floats: {d}
        \\  image floats: {d}
        \\  build ns: {d}
        \\  pack ns: {d}
        \\  render ns: {d}
        \\  checksum: 0x{x}
        \\
    , .{
        width,
        height,
        scene.written().len,
        ir_storage.rect_len,
        ir_storage.text_vertex_len,
        ir_storage.icon_vertex_len,
        ir_storage.icon_line_vertex_len,
        ir_storage.image_vertex_len,
        build_ns,
        pack_ns,
        render_ns,
        pixelChecksum(pixels[0 .. width * height]),
    });
}

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn pixelChecksum(values: []const ui.Color) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (values) |value| {
        hash ^= value.r;
        hash *%= 0x100000001b3;
        hash ^= value.g;
        hash *%= 0x100000001b3;
        hash ^= value.b;
        hash *%= 0x100000001b3;
        hash ^= value.a;
        hash *%= 0x100000001b3;
    }
    return hash;
}

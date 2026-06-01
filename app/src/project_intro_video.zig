const std = @import("er_std");

const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/backends/software.zig");
const ui = @import("ui/core.zig");

const W: usize = 960;
const H: usize = 540;
const frame_count: usize = 72;
const max_commands: usize = 512;
const max_rects: usize = 2048;
const max_icon_vertices: usize = 512;
const max_image_vertices: usize = 32768;
const max_icon_line_vertices: usize = 2048;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_icon_vertices,
    max_image_vertices,
    0,
    0,
    max_icon_line_vertices,
    0,
);

const Slide = struct {
    title: []const u8,
    detail: []const u8,
    signal: []const u8,
};

const slides = [_]Slide{
    .{
        .title = "EdgeRun",
        .detail = "A local-first runtime where apps, devices, media, and identity run under explicit user authority.",
        .signal = "kernel -> wasm -> ui -> media",
    },
    .{
        .title = "Self-hosted paths",
        .detail = "Host production code is x86_64 assembly. App logic is Zig compiled to WASM.",
        .signal = "no hidden platform control plane",
    },
    .{
        .title = "AV1 media path",
        .detail = "The encoder and decoder now round-trip sequence, frame, tile, raw420, and IVF paths in ASM tests.",
        .signal = "sequence + frame + tile + raw420",
    },
    .{
        .title = "User-owned computing",
        .detail = "Routes, storage, display, and network access move through signed grants and measurable receipts.",
        .signal = "authority is explicit",
    },
};

pub fn main() !void {
    const io: std.Io = .{};
    const alloc = std.heap.page_allocator;
    try std.Io.Dir.cwd().createDirPath(io, ".build/app/project_intro_frames");

    const pixels = try alloc.alloc(ui.Color, W * H);
    defer alloc.free(pixels);

    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();

    var index: usize = 0;
    while (index < frame_count) : (index += 1) {
        try renderFrame(pixels, &font_atlas, index);
        try writeFrame(io, index, pixels);
    }

    std.debug.print("wrote .build/app/project_intro_frames/frame_0000.ppm..frame_0071.ppm\n", .{});
}

fn renderFrame(pixels: []ui.Color, font_atlas: *renderer_font_atlas.Atlas, frame_index: usize) !void {
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const slide_index = frame_index / (frame_count / slides.len);
    const slide = slides[@min(slide_index, slides.len - 1)];
    const local = frame_index % (frame_count / slides.len);
    const phase = @as(f32, @floatFromInt(local)) / @as(f32, @floatFromInt((frame_count / slides.len) - 1));
    const ease = ui.easingSample(.ease_out, phase);

    try scene.pushGradientRect(rect(0, 0, W, H), color(8, 13, 18), color(15, 21, 26), 0);
    try scene.pushRect(rect(42, 42, W - 84, H - 84), colorA(24, 31, 42, 232), .fill, 6, 0);
    try scene.pushRect(rect(42, 42, W - 84, H - 84), colorA(75, 91, 110, 130), .border, 6, 0);

    const progress_w = @as(f32, @floatFromInt(W - 144)) * ((@as(f32, @floatFromInt(frame_index)) + 1.0) / @as(f32, @floatFromInt(frame_count)));
    try scene.pushRect(rect(72, 470, W - 144, 8), colorA(51, 65, 85, 190), .fill, 4, 0);
    try scene.pushRect(rect(72, 470, @intFromFloat(progress_w), 8), color(34, 211, 238), .fill, 4, 0);

    const title_y = 104.0 - 12.0 + 12.0 * ease;
    try scene.pushText(ui.Rect.init(72, title_y, W - 144, 58), slide.title, color(241, 245, 249));
    try scene.pushText(ui.Rect.init(74, 174, W - 148, 54), slide.detail, color(203, 213, 225));
    try scene.pushText(ui.Rect.init(74, 244, W - 148, 26), slide.signal, color(34, 211, 238));

    const card_y: f32 = 310;
    try statusCard(&scene, 74, card_y, "AV1", "ASM encode/decode", frame_index, 0);
    try statusCard(&scene, 300, card_y, "WASM", "app boundary", frame_index, 9);
    try statusCard(&scene, 526, card_y, "UI", "Wayland + IR", frame_index, 18);
    try statusCard(&scene, 752, card_y, "TPM", "receipts", frame_index, 27);

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    try renderer_pipeline.packScene(buffers, font_atlas, scene.written());
    const surface = try renderer_software.Framebuffer.init(W, H, pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(font_atlas, null));
    if (!receipt.valid()) return error.RenderFailed;
}

fn statusCard(scene: *ui.Scene, x: usize, y: f32, title: []const u8, detail: []const u8, frame_index: usize, offset: usize) !void {
    const pulse = ((frame_index + offset) % 24) < 12;
    const accent = if (pulse) color(34, 211, 238) else color(74, 222, 128);
    try scene.pushRect(ui.Rect.init(@floatFromInt(x), y, 156, 78), colorA(15, 23, 42, 225), .fill, 6, 0);
    try scene.pushRect(ui.Rect.init(@floatFromInt(x), y, 156, 78), accent, .border, 6, 0);
    try scene.pushText(ui.Rect.init(@as(f32, @floatFromInt(x)) + 14, y + 13, 128, 20), title, color(248, 250, 252));
    try scene.pushText(ui.Rect.init(@as(f32, @floatFromInt(x)) + 14, y + 40, 128, 18), detail, color(148, 163, 184));
}

fn writeFrame(io: std.Io, index: usize, pixels: []const ui.Color) !void {
    var name: [96]u8 = undefined;
    const path = try std.fmt.bufPrint(&name, ".build/app/project_intro_frames/frame_{d:0>4}.ppm", .{index});
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ W, H });
    try file.writeStreamingAll(io, header_bytes);
    for (pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

fn rect(x: usize, y: usize, w: usize, h: usize) ui.Rect {
    return ui.Rect.init(@floatFromInt(x), @floatFromInt(y), @floatFromInt(w), @floatFromInt(h));
}

fn color(r: u8, g: u8, b: u8) ui.Color {
    return .{ .r = r, .g = g, .b = b, .a = 255 };
}

fn colorA(r: u8, g: u8, b: u8, a: u8) ui.Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

test "intro video frame count stays deterministic" {
    try std.testing.expectEqual(@as(usize, 72), frame_count);
    try std.testing.expectEqual(@as(usize, 4), slides.len);
}

const std = @import("std");
const linux = std.os.linux;
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

const width = 3840;
const height = 2160;
const text_scene_scale = 12.0;
const scene_build_iterations = 1_000;
const ir_pack_iterations = 100;
const ir_render_iterations = 100;
const max_rect_instances = 256;
const max_textured_vertices = 8192;
const max_image_vertices = 0;
const max_overlay_rect_instances = 64;
const max_overlay_textured_vertices = 2048;
const IrStorage = renderer_ir.FixedBuffers(
    max_rect_instances,
    max_textured_vertices,
    max_textured_vertices,
    max_image_vertices,
    max_overlay_rect_instances,
    max_overlay_textured_vertices,
    max_overlay_textured_vertices,
);

var ir_storage: IrStorage = undefined;
var frame_pixels: [width * height]ui.Color = undefined;
var atlas_font_atlas: renderer_font_atlas.Atlas = undefined;
var object_font_atlas: renderer_font_atlas.Atlas = undefined;
var font_storage: renderer_font_atlas.AsciiFontStorage = undefined;

pub fn main() !void {
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    std.debug.print("ui bench stage: scene build\n", .{});
    const scene_start = nowNs();
    var i: usize = 0;
    while (i < scene_build_iterations) : (i += 1) {
        scene.clear();
        try buildTextScene(&scene, @intCast(i));
    }
    const scene_ns = nowNs() - scene_start;

    ir_storage = IrStorage{};
    const ir_buffers = ir_storage.buffers();
    atlas_font_atlas = renderer_font_atlas.Atlas.init();
    const atlas_sources = renderer_ir.Sources{
        .font = atlas_font_atlas.source(),
    };
    std.debug.print("ui bench stage: atlas pack\n", .{});
    const atlas_pack_start = nowNs();
    i = 0;
    while (i < ir_pack_iterations) : (i += 1) {
        try renderer_ir.packScene(ir_buffers, atlas_sources, scene.written());
    }
    const atlas_pack_ns = nowNs() - atlas_pack_start;

    const surface = try renderer_software.Surface.init(width, height, &frame_pixels);
    const atlas_resources = renderer_software.IrResources{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .alpha = atlas_font_atlas.alphaSlice() },
    };
    std.debug.print("ui bench stage: atlas render\n", .{});
    const atlas_render_start = nowNs();
    i = 0;
    while (i < ir_render_iterations) : (i += 1) {
        surface.clear(.bg);
        _ = try surface.renderIrFrameWithResources(ir_buffers, atlas_resources);
    }
    const atlas_render_ns = nowNs() - atlas_render_start;
    const atlas_packed_checksum = irChecksum(ir_buffers);
    const atlas_rendered_checksum = pixelChecksum(&frame_pixels);

    std.debug.print("ui bench stage: object font compile\n", .{});
    font_storage = renderer_font_atlas.AsciiFontStorage{};
    const font_compile_start = nowNs();
    const object_font = try renderer_font_atlas.compileGeistAscii(&font_storage);
    const font_compile_ns = nowNs() - font_compile_start;
    const object_font_body_len = @import("font_vector.zig").serializedLen(object_font.glyphs.len, object_font.kerns.len, object_font.commands.len).?;

    object_font_atlas = font_storage.atlas().?;
    const object_sources = renderer_ir.Sources{
        .font = object_font_atlas.source(),
    };
    std.debug.print("ui bench stage: object pack\n", .{});
    const object_pack_start = nowNs();
    i = 0;
    while (i < ir_pack_iterations) : (i += 1) {
        try renderer_ir.packScene(ir_buffers, object_sources, scene.written());
    }
    const object_pack_ns = nowNs() - object_pack_start;
    const object_resources = renderer_software.IrResources{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .alpha = object_font_atlas.alphaSlice() },
    };
    std.debug.print("ui bench stage: object render\n", .{});
    const object_render_start = nowNs();
    i = 0;
    while (i < ir_render_iterations) : (i += 1) {
        surface.clear(.bg);
        _ = try surface.renderIrFrameWithResources(ir_buffers, object_resources);
    }
    const object_render_ns = nowNs() - object_render_start;

    const checksum = commandChecksum(scene.written());
    const packed_checksum = irChecksum(ir_buffers);
    const rendered_checksum = pixelChecksum(&frame_pixels);
    std.debug.print(
        \\ui bench
        \\  app ui: direct text-heavy software render scene
        \\  scene commands: {d}
        \\  ir rect floats: {d}
        \\  ir text floats: {d}
        \\  ir icon floats: {d}
        \\  atlas cached glyphs: {d}
        \\  object font glyphs: {d}
        \\  object font commands: {d}
        \\  object font body bytes: {d}
        \\  object cached glyphs: {d}
        \\  scene build: {d} iterations in {d} ns ({d} ns/build)
        \\  atlas ir pack: {d} iterations in {d} ns ({d} ns/pack)
        \\  atlas ir software render: {d} iterations in {d} ns ({d} ns/render)
        \\  object font compile: {d} ns
        \\  object ir pack: {d} iterations in {d} ns ({d} ns/pack)
        \\  object ir software render: {d} iterations in {d} ns ({d} ns/render)
        \\
    , .{
        scene.written().len,
        ir_storage.rect_len,
        ir_storage.text_vertex_len,
        ir_storage.icon_vertex_len,
        atlas_font_atlas.cachedGlyphCount(),
        object_font.glyphs.len,
        object_font.commands.len,
        object_font_body_len,
        object_font_atlas.cachedGlyphCount(),
        scene_build_iterations,
        scene_ns,
        scene_ns / scene_build_iterations,
        ir_pack_iterations,
        atlas_pack_ns,
        atlas_pack_ns / ir_pack_iterations,
        ir_render_iterations,
        atlas_render_ns,
        atlas_render_ns / ir_render_iterations,
        font_compile_ns,
        ir_pack_iterations,
        object_pack_ns,
        object_pack_ns / ir_pack_iterations,
        ir_render_iterations,
        object_render_ns,
        object_render_ns / ir_render_iterations,
    });
    std.debug.print(
        \\ui bench checksums
        \\  command checksum: 0x{x}
        \\  atlas ir checksum: 0x{x}
        \\  object ir checksum: 0x{x}
        \\  atlas pixel checksum: 0x{x}
        \\  object pixel checksum: 0x{x}
        \\
    , .{
        checksum,
        atlas_packed_checksum,
        packed_checksum,
        atlas_rendered_checksum,
        rendered_checksum,
    });
}

fn buildTextScene(scene: *ui.Scene, frame_index: u32) ui.RenderError!void {
    const pulse = @as(f32, @floatFromInt(frame_index % 8)) * text_scene_scale;
    try scene.pushRect(ui.Rect.init(0, 0, width, height), .bg, .fill, 0, 0);
    try scene.pushRect(scaledRect(12, 12, 296, 216), .{ .r = 7, .g = 11, .b = 18, .a = 255 }, .fill, 8 * text_scene_scale, 0);
    try scene.pushRect(scaledRect(12, 12, 296, 216), .{ .r = 48, .g = 60, .b = 74, .a = 255 }, .border, 8 * text_scene_scale, 0);
    try scene.pushRect(ui.Rect.init((22 * text_scene_scale) + pulse, 25 * text_scene_scale, 72 * text_scene_scale, 22 * text_scene_scale), .accent, .fill, 4 * text_scene_scale, 0);
    try scene.pushText(scaledRect(24, 28, 84, 16), "CPU TEXT", .bg);
    try scene.pushText(scaledRect(24, 60, 280, 28), "Sharp text on small machines", .text);
    try scene.pushText(scaledRect(24, 94, 280, 18), "Authority boundaries need readable receipts.", .muted);
    try scene.pushText(scaledRect(24, 120, 280, 16), "abcdefghijklmnopqrstuvwxyz", .text);
    try scene.pushText(scaledRect(24, 144, 280, 16), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", .text);
    try scene.pushText(scaledRect(24, 168, 280, 16), "0123456789 .,:;!?/-_()[]{}", .muted);
    try scene.pushText(scaledRect(24, 196, 280, 16), "object font -> atlas -> IR -> CPU surface", .accent);
}

fn scaledRect(x: f32, y: f32, w: f32, h: f32) ui.Rect {
    return ui.Rect.init(x * text_scene_scale, y * text_scene_scale, w * text_scene_scale, h * text_scene_scale);
}

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn commandChecksum(commands: []const ui.Command) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (commands) |command| switch (command) {
        .rect => |rect| {
            sum = mix(sum, rect.color.r);
            sum = mix(sum, rect.color.g);
            sum = mix(sum, rect.color.b);
            sum = mix(sum, rect.color.a);
        },
        .border => |border| {
            sum = mix(sum, border.color.r);
            sum = mix(sum, border.color.g);
            sum = mix(sum, border.color.b);
            sum = mix(sum, border.color.a);
        },
        .text => |text| {
            for (text.value) |byte| sum = mix(sum, byte);
        },
        .drag_source => |source| sum = mix(sum, @truncate(source.item_id)),
        .drop_target => |target| sum = mix(sum, @truncate(target.index)),
        .icon_quad => |quad| sum = mix(sum, @truncate(quad.icon_id)),
        .text_quad => |quad| sum = mix(sum, @truncate(quad.atlas_id)),
        .image_quad => |quad| sum = mix(sum, @truncate(quad.atlas_id)),
        .transition => |transition_value| sum = mix(sum, @truncate(transition_value.id)),
    };
    return sum;
}

fn irChecksum(buffers: renderer_ir.Buffers) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (renderer_ir.drawBatches(buffers)) |batch| {
        sum = floatSliceChecksum(sum, renderer_ir.batchValues(batch));
    }
    return sum;
}

fn floatSliceChecksum(initial: u64, values: []const f32) u64 {
    var sum = initial;
    for (values) |value| {
        const bits: u32 = @bitCast(value);
        sum = mix(sum, @truncate(bits));
        sum = mix(sum, @truncate(bits >> 8));
        sum = mix(sum, @truncate(bits >> 16));
        sum = mix(sum, @truncate(bits >> 24));
    }
    return sum;
}

fn pixelChecksum(pixels: []const ui.Color) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (pixels) |pixel| {
        sum = mix(sum, pixel.r);
        sum = mix(sum, pixel.g);
        sum = mix(sum, pixel.b);
        sum = mix(sum, pixel.a);
    }
    return sum;
}

fn mix(sum: u64, byte: u8) u64 {
    return (sum ^ byte) *% 0x100000001b3;
}

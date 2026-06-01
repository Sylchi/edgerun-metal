const std = @import("er_std");
const button_component = @import("components/Button.zig");
const renderer_font_atlas = @import("../render/font_atlas_weighted.zig");
const renderer_ir = @import("../render/ir.zig");
const renderer_pipeline = @import("../render/pipeline.zig");
const renderer_software = @import("../render/backends/software.zig");
const ui = @import("core.zig");

pub const width: usize = 320;
pub const height: usize = 480;
pub const pixel_bytes: usize = 2;
pub const frame_bytes: usize = width * height * pixel_bytes;

pub const Error = error{
    FrameTooSmall,
    InvalidIrBuffer,
};

pub const RenderError = Error || renderer_software.Error;

pub fn rgb565(color: ui.Color) u16 {
    return (@as(u16, color.r & 0xf8) << 8) |
        (@as(u16, color.g & 0xfc) << 3) |
        (@as(u16, color.b) >> 3);
}

pub fn storeRgb565(out: []u8, pixel_index: usize, color: ui.Color) void {
    const value = rgb565(color);
    const offset = pixel_index * pixel_bytes;
    out[offset] = @intCast(value >> 8);
    out[offset + 1] = @intCast(value & 0xff);
}

pub fn clear(out: []u8, color: ui.Color) Error!void {
    if (out.len < frame_bytes) return error.FrameTooSmall;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) storeRgb565(out, y * width + x, color);
    }
}

pub fn renderRectIr(out: []u8, rect_values: []const f32, background: ui.Color) Error!void {
    try clear(out, background);
    var iter = renderer_ir.RectIterator.init(rect_values) catch return error.InvalidIrBuffer;
    while (iter.next() catch return error.InvalidIrBuffer) |rect| {
        if (rect.mode != .fill) continue;
        drawRect(out, rect.bounds, rect.color) catch |err| return err;
    }
}

pub fn renderPackedIr(out: []u8, rgba_scratch: []ui.Color, buffers: renderer_ir.Buffers, resources: renderer_software.Resources, background: ui.Color) RenderError!void {
    if (out.len < frame_bytes) return error.FrameTooSmall;
    if (rgba_scratch.len < width * height) return error.PixelBudgetExceeded;
    const framebuffer = try renderer_software.Framebuffer.init(width, height, rgba_scratch);
    framebuffer.clear(background);
    _ = try framebuffer.renderIr(buffers, resources);
    var index: usize = 0;
    while (index < width * height) : (index += 1) storeRgb565(out, index, rgba_scratch[index]);
}

fn drawRect(out: []u8, rect: ui.Rect, color: ui.Color) Error!void {
    if (out.len < frame_bytes) return error.FrameTooSmall;
    const x0 = clampFloor(rect.x, width);
    const y0 = clampFloor(rect.y, height);
    const x1 = clampCeil(rect.x + rect.w, width);
    const y1 = clampCeil(rect.y + rect.h, height);
    if (x1 <= x0 or y1 <= y0) return;

    var y = y0;
    while (y < y1) : (y += 1) {
        var x = x0;
        while (x < x1) : (x += 1) storeRgb565(out, y * width + x, color);
    }
}

fn clampFloor(value: f32, limit: usize) usize {
    if (value <= 0) return 0;
    const floored: usize = @intFromFloat(@floor(value));
    return @min(floored, limit);
}

fn clampCeil(value: f32, limit: usize) usize {
    if (value <= 0) return 0;
    const ceiled: usize = @intFromFloat(@ceil(value));
    return @min(ceiled, limit);
}

test "rgb565 uses display byte order" {
    try std.testing.expectEqual(@as(u16, 0xf800), rgb565(.{ .r = 255, .g = 0, .b = 0 }));
    try std.testing.expectEqual(@as(u16, 0x07e0), rgb565(.{ .r = 0, .g = 255, .b = 0 }));
    try std.testing.expectEqual(@as(u16, 0x001f), rgb565(.{ .r = 0, .g = 0, .b = 255 }));

    var out: [2]u8 = undefined;
    storeRgb565(&out, 0, .{ .r = 255, .g = 0, .b = 0 });
    try std.testing.expectEqualSlices(u8, &.{ 0xf8, 0x00 }, &out);
}

test "render rect ir into rgb565 frame" {
    var rect_storage: [renderer_ir.rect_float_stride]f32 = undefined;
    var rect_len: usize = 0;
    var dummy_icon: [1]f32 = undefined;
    var dummy_icon_len: usize = 0;
    var dummy_icon_lines: [1]f32 = undefined;
    var dummy_icon_line_len: usize = 0;
    var dummy_text: [1]f32 = undefined;
    var dummy_text_len: usize = 0;
    var dummy_overlay_text: [1]f32 = undefined;
    var dummy_overlay_text_len: usize = 0;
    var dummy_image: [1]f32 = undefined;
    var dummy_image_len: usize = 0;
    var dummy_overlay_rect: [1]f32 = undefined;
    var dummy_overlay_rect_len: usize = 0;
    var dummy_overlay_icon: [1]f32 = undefined;
    var dummy_overlay_icon_len: usize = 0;
    var dummy_overlay_icon_lines: [1]f32 = undefined;
    var dummy_overlay_icon_line_len: usize = 0;
    const buffers = renderer_ir.Buffers{
        .rects = &rect_storage,
        .rect_len = &rect_len,
        .icon_vertices = &dummy_icon,
        .icon_vertex_len = &dummy_icon_len,
        .icon_line_vertices = &dummy_icon_lines,
        .icon_line_vertex_len = &dummy_icon_line_len,
        .text_vertices = &dummy_text,
        .text_vertex_len = &dummy_text_len,
        .overlay_text_vertices = &dummy_overlay_text,
        .overlay_text_vertex_len = &dummy_overlay_text_len,
        .image_vertices = &dummy_image,
        .image_vertex_len = &dummy_image_len,
        .overlay_rects = &dummy_overlay_rect,
        .overlay_rect_len = &dummy_overlay_rect_len,
        .overlay_icon_vertices = &dummy_overlay_icon,
        .overlay_icon_vertex_len = &dummy_overlay_icon_len,
        .overlay_icon_line_vertices = &dummy_overlay_icon_lines,
        .overlay_icon_line_vertex_len = &dummy_overlay_icon_line_len,
    };
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(1, 1, 2, 2), .accent, .clear, 0, 0, renderer_ir.rect_mode_fill);

    var frame: [frame_bytes]u8 = undefined;
    try renderRectIr(&frame, buffers.liveRects(), .bg);
    try std.testing.expectEqual(rgb565(.bg), loadPixel(&frame, 0, 0));
    try std.testing.expectEqual(rgb565(.accent), loadPixel(&frame, 1, 1));
    try std.testing.expectEqual(rgb565(.accent), loadPixel(&frame, 2, 2));
    try std.testing.expectEqual(rgb565(.bg), loadPixel(&frame, 3, 3));
}

test "render app component packed ir into rgb565 frame" {
    var scene_commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&scene_commands);
    try (button_component.Button{ .id = 7, .label = "OK" }).render(&scene, ui.Rect.init(8, 8, 80, 32), .{});

    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var storage = renderer_ir.FixedBuffers(8, 0, 64, 0, 0, 0, 0){};
    try renderer_pipeline.packScene(storage.buffers(), &font_atlas, scene.written());

    const allocator = std.testing.allocator;
    const frame = try allocator.alloc(u8, frame_bytes);
    defer allocator.free(frame);
    const rgba = try allocator.alloc(ui.Color, width * height);
    defer allocator.free(rgba);

    try renderPackedIr(frame, rgba, storage.buffers(), renderer_pipeline.softwareResources(&font_atlas, null), .bg);
    try std.testing.expectEqual(rgb565(.bg), loadPixel(frame, 0, 0));
    try std.testing.expect(loadPixel(frame, 10, 10) != rgb565(.bg));
}

fn loadPixel(frame: []const u8, x: usize, y: usize) u16 {
    const offset = (y * width + x) * pixel_bytes;
    return (@as(u16, frame[offset]) << 8) | frame[offset + 1];
}

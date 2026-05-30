const std = @import("std");
const renderer_ir = @import("ir.zig");
const software = @import("backends/software.zig");
const ui = @import("../ui/core.zig");

pub const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    invalid_ir = 3,
    missing_font = 4,
    pixel_budget = 5,
    unsupported = 6,
};

pub const max_width: u32 = 4096;
pub const max_height: u32 = 2880;

var frame_width: u32 = 0;
var frame_height: u32 = 0;
var last_error: ErrorCode = .ok;

var rect_len: usize = 0;
var icon_vertex_len: usize = 0;
var icon_line_vertex_len: usize = 0;
var image_vertex_len: usize = 0;
var overlay_rect_len: usize = 0;
var overlay_icon_vertex_len: usize = 0;
var overlay_icon_line_vertex_len: usize = 0;

fn err(code: ErrorCode) u32 {
    last_error = code;
    return @intFromEnum(code);
}

fn sliceOrEmpty(comptime T: type, ptr: usize, len: u32) []T {
    if (ptr != 0 and len > 0) {
        return @as([*]T, @ptrFromInt(ptr))[0..len];
    }
    return &[_]T{};
}

pub fn rasterize(
    width: u32,
    height: u32,
    rect_ptr: usize, rect_filled: u32, rect_cap: u32,
    icon_ptr: usize, icon_filled: u32, icon_cap: u32,
    icon_line_ptr: usize, icon_line_filled: u32, icon_line_cap: u32,
    image_ptr: usize, image_filled: u32, image_cap: u32,
    font_ptr: usize, font_width: u32, font_height: u32,
    pixels_ptr: usize, pixel_count: u32,
) u32 {
    if (width == 0 or height == 0 or width > max_width or height > max_height)
        return err(.bad_size);

    const total_pixels = @as(usize, width) * @as(usize, height);
    if (pixel_count < total_pixels)
        return err(.pixel_budget);

    if (font_ptr == 0 or font_width == 0 or font_height == 0)
        return err(.missing_font);

    frame_width = width;
    frame_height = height;

    const rects = sliceOrEmpty(f32, rect_ptr, rect_cap);
    const icon_vertices = sliceOrEmpty(f32, icon_ptr, icon_cap);
    const icon_line_vertices = sliceOrEmpty(f32, icon_line_ptr, icon_line_cap);
    const image_vertices = sliceOrEmpty(f32, image_ptr, image_cap);

    rect_len = rect_filled;
    icon_vertex_len = icon_filled;
    icon_line_vertex_len = icon_line_filled;
    image_vertex_len = image_filled;
    overlay_rect_len = 0;
    overlay_icon_vertex_len = 0;
    overlay_icon_line_vertex_len = 0;

    const buffers = renderer_ir.Buffers{
        .rects = rects,
        .rect_len = &rect_len,
        .icon_vertices = icon_vertices,
        .icon_vertex_len = &icon_vertex_len,
        .icon_line_vertices = icon_line_vertices,
        .icon_line_vertex_len = &icon_line_vertex_len,
        .image_vertices = image_vertices,
        .image_vertex_len = &image_vertex_len,
        .overlay_rects = &[_]f32{},
        .overlay_rect_len = &overlay_rect_len,
        .overlay_icon_vertices = &[_]f32{},
        .overlay_icon_vertex_len = &overlay_icon_vertex_len,
        .overlay_icon_line_vertices = &[_]f32{},
        .overlay_icon_line_vertex_len = &overlay_icon_line_vertex_len,
    };

    const font_alpha = @as([*]const u8, @ptrFromInt(font_ptr))[0 .. font_width * font_height];
    const atlas = software.AlphaAtlas{
        .width = font_width,
        .height = font_height,
        .alpha = font_alpha,
    };

    const pixels = @as([*]ui.Color, @ptrFromInt(pixels_ptr))[0..total_pixels];
    var surface = software.Surface.init(width, height, pixels) catch {
        return err(.pixel_budget);
    };
    surface.clear(ui.Color.bg);

    surface.rasterizeIrWithResources(buffers, .{ .font = atlas, .image = null }) catch |e| {
        last_error = switch (e) {
            error.InvalidIrBuffer => .invalid_ir,
            error.InvalidIrResource => .missing_font,
            error.UnsupportedIrPrimitive => .unsupported,
            else => .bad_input,
        };
        return @intFromEnum(last_error);
    };


    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

pub export fn er_wasm_rasterizer_version() u32 {
    return 1;
}

pub export fn er_wasm_rasterizer_last_error() u32 {
    return @intFromEnum(last_error);
}

pub export fn er_wasm_rasterizer_state_size() u32 {
    return @sizeOf(@TypeOf(rect_len)) * 7 +
        @sizeOf(@TypeOf(frame_width)) * 2 +
        @sizeOf(@TypeOf(last_error));
}

pub export fn er_wasm_rasterizer_rasterize(
    width: u32,
    height: u32,
    rect_ptr: usize, rect_filled: u32, rect_cap: u32,
    icon_ptr: usize, icon_filled: u32, icon_cap: u32,
    icon_line_ptr: usize, icon_line_filled: u32, icon_line_cap: u32,
    image_ptr: usize, image_filled: u32, image_cap: u32,
    font_ptr: usize, font_width: u32, font_height: u32,
    pixels_ptr: usize, pixel_count: u32,
) u32 {
    return rasterize(
        width, height,
        rect_ptr, rect_filled, rect_cap,
        icon_ptr, icon_filled, icon_cap,
        icon_line_ptr, icon_line_filled, icon_line_cap,
        image_ptr, image_filled, image_cap,
        font_ptr, font_width, font_height,
        pixels_ptr, pixel_count,
    );
}

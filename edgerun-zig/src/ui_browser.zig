const renderer = @import("renderer_software.zig");
const shadcn_demo = @import("shadcn_demo.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");

const max_width: usize = 1440;
const max_height: usize = 900;
const max_pixels: usize = max_width * max_height;
const max_input_bytes: usize = 8192;
const max_nodes: usize = 256;
const max_commands: usize = 4096;
const gpu_rect_float_stride: usize = 15;
const gpu_text_float_stride: usize = 11;
const max_gpu_rects: usize = 8192;
const max_gpu_texts: usize = 4096;
const max_gpu_text_bytes: usize = 65536;

var pixels: [max_pixels]ui.Color = undefined;
var input_bytes: [max_input_bytes]u8 = undefined;
var nodes: [max_nodes]ui.Node = undefined;
var commands: [max_commands]ui.Command = undefined;
var gpu_rect_floats: [max_gpu_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_rect_float_len: usize = 0;
var gpu_text_floats: [max_gpu_texts * gpu_text_float_stride]f32 = undefined;
var gpu_text_float_len: usize = 0;
var gpu_text_bytes: [max_gpu_text_bytes]u8 = undefined;
var gpu_text_byte_len: usize = 0;
var frame_width: usize = 0;
var frame_height: usize = 0;
var last_error: ErrorCode = .ok;

const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    bad_ui = 3,
    render_failed = 4,
    gpu_budget = 5,
};

export fn er_ui_max_width() u32 {
    return max_width;
}

export fn er_ui_max_height() u32 {
    return max_height;
}

export fn er_ui_pixels_ptr() usize {
    return @intFromPtr(&pixels);
}

export fn er_ui_pixels_len() usize {
    return frame_width * frame_height * @sizeOf(ui.Color);
}

export fn er_ui_gpu_rect_float_stride() u32 {
    return gpu_rect_float_stride;
}

export fn er_ui_gpu_rect_buffer_ptr() usize {
    return @intFromPtr(gpu_rect_floats[0..].ptr);
}

export fn er_ui_gpu_rect_buffer_len() usize {
    return gpu_rect_float_len;
}

export fn er_ui_gpu_text_float_stride() u32 {
    return gpu_text_float_stride;
}

export fn er_ui_gpu_text_buffer_ptr() usize {
    return @intFromPtr(gpu_text_floats[0..].ptr);
}

export fn er_ui_gpu_text_buffer_len() usize {
    return gpu_text_float_len;
}

export fn er_ui_gpu_text_bytes_ptr() usize {
    return @intFromPtr(gpu_text_bytes[0..].ptr);
}

export fn er_ui_gpu_text_bytes_len() usize {
    return gpu_text_byte_len;
}

export fn er_ui_width() u32 {
    return @intCast(frame_width);
}

export fn er_ui_height() u32 {
    return @intCast(frame_height);
}

export fn er_ui_input_ptr() usize {
    return @intFromPtr(&input_bytes);
}

export fn er_ui_input_capacity() usize {
    return input_bytes.len;
}

export fn er_ui_last_error() u32 {
    return @intFromEnum(last_error);
}

export fn er_ui_clear(width: u32, height: u32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    surface.clear(.bg);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_render_demo(width: u32, height: u32) u32 {
    return er_ui_render_shadcn_demo(width, height);
}

export fn er_ui_render_shadcn_demo(width: u32, height: u32) u32 {
    return er_ui_render_shadcn_demo_scroll(width, height, 0.0);
}

export fn er_ui_render_shadcn_demo_scroll(width: u32, height: u32, scroll_y: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    shadcn_demo.renderGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{ .scroll_y = scroll_y }) catch return finishError(.render_failed);

    surface.clear(.{ .r = 248, .g = 250, .b = 252 });
    surface.rasterize(scene.written());
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_build_shadcn_gpu_frame(width: u32, height: u32, scroll_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    shadcn_demo.renderGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{ .scroll_y = scroll_y }) catch return finishError(.render_failed);

    packGpuScene(scene.written()) catch return finishError(.gpu_budget);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_render_input_object(input_len: usize, width: u32, height: u32) u32 {
    if (input_len == 0 or input_len > input_bytes.len) return finishError(.bad_input);
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    const root = ui_codec.decodeObject(input_bytes[0..input_len], &nodes) catch return finishError(.bad_ui);
    var scene = ui.Scene.init(&commands);
    ui.render(&scene, root, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{}) catch return finishError(.render_failed);

    surface.clear(.bg);
    surface.rasterize(scene.written());
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

fn beginFrame(width_raw: u32, height_raw: u32) ?renderer.Surface {
    const width: usize = width_raw;
    const height: usize = height_raw;
    if (!setFrameSize(width, height)) return null;
    return renderer.Surface.init(width, height, pixels[0 .. width * height]) catch null;
}

fn setFrameSize(width: usize, height: usize) bool {
    if (width == 0 or height == 0 or width > max_width or height > max_height) return false;
    frame_width = width;
    frame_height = height;
    return true;
}

fn finishError(code: ErrorCode) u32 {
    last_error = code;
    return @intFromEnum(code);
}

fn packGpuScene(scene_commands: []const ui.Command) error{Budget}!void {
    gpu_rect_float_len = 0;
    gpu_text_float_len = 0;
    gpu_text_byte_len = 0;
    for (scene_commands) |command| switch (command) {
        .rect => |rect| try pushPackedRect(rect.bounds, rect.color, rect.color2, rect.radius, rect.shadow, rectModeCode(rect.mode)),
        .border => |border| try pushPackedRect(border.bounds, border.color, .clear, 0, 0, 2),
        .text => |text_command| try pushPackedText(text_command.origin, text_command.value, text_command.color),
        .hit, .drag_source, .drop_target, .icon_quad, .text_quad, .transition => {},
    };
}

fn pushPackedText(bounds: ui.Rect, value: []const u8, color: ui.Color) error{Budget}!void {
    if (value.len == 0) return;
    if (gpu_text_float_len + gpu_text_float_stride > gpu_text_floats.len) return error.Budget;
    if (gpu_text_byte_len + value.len > gpu_text_bytes.len) return error.Budget;

    const byte_offset = gpu_text_byte_len;
    @memcpy(gpu_text_bytes[gpu_text_byte_len .. gpu_text_byte_len + value.len], value);
    gpu_text_byte_len += value.len;

    const values = [_]f32{
        bounds.x,
        bounds.y,
        bounds.w,
        bounds.h,
        channel(color.r),
        channel(color.g),
        channel(color.b),
        channel(color.a),
        @floatFromInt(byte_offset),
        @floatFromInt(value.len),
        @max(11.0, @min(22.0, bounds.h)),
    };
    @memcpy(gpu_text_floats[gpu_text_float_len .. gpu_text_float_len + gpu_text_float_stride], &values);
    gpu_text_float_len += gpu_text_float_stride;
}

fn pushPackedRect(bounds: ui.Rect, color: ui.Color, color2: ui.Color, radius: f32, shadow: f32, mode: f32) error{Budget}!void {
    if (!bounds.valid()) return;
    if (gpu_rect_float_len + gpu_rect_float_stride > gpu_rect_floats.len) return error.Budget;
    const values = [_]f32{
        bounds.x,
        bounds.y,
        bounds.w,
        bounds.h,
        radius,
        shadow,
        channel(color.r),
        channel(color.g),
        channel(color.b),
        channel(color.a),
        channel(color2.r),
        channel(color2.g),
        channel(color2.b),
        channel(color2.a),
        mode,
    };
    @memcpy(gpu_rect_floats[gpu_rect_float_len .. gpu_rect_float_len + gpu_rect_float_stride], &values);
    gpu_rect_float_len += gpu_rect_float_stride;
}

fn rectModeCode(mode: ui.RectMode) f32 {
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 0,
    };
}

fn channel(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn demoRoot() ui.Node {
    nodes[0] = .{ .text = .{ .value = "edgerun client runtime", .color = .accent } };
    nodes[1] = .{ .input = .{ .id = 10, .placeholder = "compile app source" } };
    nodes[2] = .{ .row_item = .{ .id = 20, .title = "canonical UI object", .detail = "stored, resolved, rendered locally" } };
    nodes[3] = .{ .row_item = .{ .id = 21, .title = "browser private build", .detail = "no server compiler required" } };
    nodes[4] = .{ .button = .{ .id = 30, .label = "Run" } };
    nodes[5] = .{ .slot = .{ .id = 7, .child = &nodes[4] } };
    return .{ .stack = .{ .axis = .column, .gap = 16, .padding = 32, .children = nodes[0..6] } };
}

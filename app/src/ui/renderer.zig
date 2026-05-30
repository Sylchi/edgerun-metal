const std = @import("std");

const interaction_pure = @import("interaction.zig");
const node_renderer = @import("components/NodeRenderer.zig");
const component_union = @import("components/Component.zig");
const renderer_font_atlas = @import("../render/font_atlas_weighted.zig");
const renderer_ir = @import("../render/ir.zig");
const renderer_pipeline = @import("../render/pipeline.zig");
const ui = @import("core.zig");
const ui_codec = @import("codec.zig");
const common = @import("component_common.zig");

pub const max_nodes: usize = 256;
pub const max_commands: usize = 4096;
pub const max_clips: usize = 64;
pub const max_interaction_regions: usize = 4096;

pub const max_pixels: usize = 4096 * 2880;
pub const max_packed_rects: usize = 32768;
pub const max_packed_icon_vertices: usize = 16384;
pub const max_packed_icon_line_vertices: usize = 4194304;
pub const max_packed_image_vertices: usize = 384;

pub const packed_rect_float_stride: usize = renderer_pipeline.rect_float_stride;
pub const packed_icon_vertex_float_stride: usize = renderer_pipeline.icon_instance_float_stride;
pub const packed_icon_line_vertex_float_stride: usize = renderer_pipeline.icon_line_vertex_float_stride;
pub const packed_image_vertex_float_stride: usize = renderer_pipeline.image_vertex_float_stride;

pub const font_atlas_width: usize = renderer_font_atlas.width;
pub const font_atlas_height: usize = renderer_font_atlas.height;

pub const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    bad_ui = 3,
    render_failed = 4,
    packed_budget = 5,
    font_atlas = 6,
};

var nodes: [max_nodes]ui.Node = undefined;
var commands: [max_commands]ui.Command = undefined;
var clips: [max_clips]ui.Rect = undefined;
var interaction_regions: [max_interaction_regions]interaction_pure.Region = undefined;

var packed_rect_floats: [max_packed_rects * packed_rect_float_stride]f32 = undefined;
var packed_rect_float_len: usize = 0;
var packed_icon_vertex_floats: [max_packed_icon_vertices * packed_icon_vertex_float_stride]f32 = undefined;
var packed_icon_vertex_float_len: usize = 0;
var packed_icon_line_vertex_floats: [max_packed_icon_line_vertices * packed_icon_line_vertex_float_stride]f32 = undefined;
var packed_icon_line_vertex_float_len: usize = 0;
var packed_image_vertex_floats: [max_packed_image_vertices * packed_image_vertex_float_stride]f32 = undefined;
var packed_image_vertex_float_len: usize = 0;

var font_atlas: renderer_font_atlas.Atlas = undefined;
var font_atlas_ready = false;
var font_device_scale: f32 = 1.0;
var frame_width: u32 = 0;
var frame_height: u32 = 0;
var last_interaction_region_count: usize = 0;
var last_error: ErrorCode = .ok;
var overlay_sentinel_len: usize = 0;

pub fn init() void {
    font_atlas_ready = false;
    font_device_scale = 1.0;
    last_error = .ok;
}

pub fn setDeviceScale(scale: f32) ErrorCode {
    if (!std.math.isFinite(scale)) return errorFromCode(.bad_input);
    font_device_scale = clampF(scale, 1.0, 4.0);
    font_atlas_ready = false;
    last_error = .ok;
    return .ok;
}

pub fn ensureFontAtlas() ErrorCode {
    if (font_atlas_ready) return .ok;
    font_atlas.initUtf8();
    font_atlas.setDeviceScale(font_device_scale);
    font_atlas_ready = true;
    return .ok;
}

pub fn render(codec_bytes: []const u8, width: u32, height: u32) ErrorCode {
    if (width == 0 or height == 0 or width > 4096 or height > 2880) return errorFromCode(.bad_size);
    if (codec_bytes.len == 0) return errorFromCode(.bad_input);

    frame_width = width;
    frame_height = height;

    const root = ui_codec.decodeObject(codec_bytes, &nodes) catch return errorFromCode(.bad_ui);

    var scene = ui.Scene.init(&commands);
    var collector = interaction_pure.Collector.init(&interaction_regions);
    last_interaction_region_count = 0;

    node_renderer.renderNode(component_union.Component, &scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(width),
        .h = @floatFromInt(height),
    }, root, .{}) catch return errorFromCode(.render_failed);

    _ = ensureFontAtlas();

    const buf = packedBuffers();
    renderer_pipeline.packScene(
        buf,
        &font_atlas,
        scene.written(),
    ) catch return errorFromCode(.packed_budget);

    last_interaction_region_count = collector.written().len;
    last_error = .ok;
    return .ok;
}

fn packedBuffers() renderer_ir.Buffers {
    return .{
        .rects = packed_rect_floats[0..],
        .rect_len = &packed_rect_float_len,
        .icon_vertices = packed_icon_vertex_floats[0..],
        .icon_vertex_len = &packed_icon_vertex_float_len,
        .icon_line_vertices = packed_icon_line_vertex_floats[0..],
        .icon_line_vertex_len = &packed_icon_line_vertex_float_len,
        .image_vertices = packed_image_vertex_floats[0..],
        .image_vertex_len = &packed_image_vertex_float_len,
        .overlay_rects = &.{},
        .overlay_rect_len = &overlay_sentinel_len,
        .overlay_icon_vertices = &.{},
        .overlay_icon_vertex_len = &overlay_sentinel_len,
        .overlay_icon_line_vertices = &.{},
        .overlay_icon_line_vertex_len = &overlay_sentinel_len,
    };
}

fn errorFromCode(code: ErrorCode) ErrorCode {
    last_error = code;
    return code;
}

fn clampF(value: f32, min: f32, max: f32) f32 {
    return @min(@max(value, min), max);
}

// -------------------------------------------------------------------------
// C-ABI Exports for WASM
// -------------------------------------------------------------------------

pub export fn er_ui_renderer_init() u32 {
    init();
    return @intFromEnum(ErrorCode.ok);
}

pub export fn er_ui_renderer_render(ptr: usize, len: usize, width: u32, height: u32) u32 {
    const bytes = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    return @intFromEnum(render(bytes, width, height));
}

pub export fn er_ui_renderer_version() u32 {
    return 1;
}

pub export fn er_ui_renderer_last_error() u32 {
    return @intFromEnum(last_error);
}

pub export fn er_ui_renderer_width() u32 {
    return frame_width;
}

pub export fn er_ui_renderer_height() u32 {
    return frame_height;
}

pub export fn er_ui_renderer_set_device_scale(scale: f32) u32 {
    return @intFromEnum(setDeviceScale(scale));
}

pub export fn er_ui_renderer_font_atlas_ptr() usize {
    return @intFromPtr(font_atlas.alphaSlice().ptr);
}

pub export fn er_ui_renderer_font_atlas_width() u32 {
    return font_atlas_width;
}

pub export fn er_ui_renderer_font_atlas_height() u32 {
    return font_atlas_height;
}

pub export fn er_ui_renderer_font_atlas_generation() u32 {
    return if (font_atlas_ready) 1 else 0;
}

pub export fn er_ui_renderer_rect_buffer_ptr() usize {
    return @intFromPtr(&packed_rect_floats);
}

pub export fn er_ui_renderer_rect_buffer_len() usize {
    return packed_rect_float_len;
}

pub export fn er_ui_renderer_rect_float_stride() u32 {
    return @intCast(packed_rect_float_stride);
}

pub export fn er_ui_renderer_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(&packed_icon_vertex_floats);
}

pub export fn er_ui_renderer_icon_vertex_buffer_len() usize {
    return packed_icon_vertex_float_len;
}

pub export fn er_ui_renderer_icon_vertex_float_stride() u32 {
    return @intCast(packed_icon_vertex_float_stride);
}

pub export fn er_ui_renderer_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(&packed_icon_line_vertex_floats);
}

pub export fn er_ui_renderer_icon_line_vertex_buffer_len() usize {
    return packed_icon_line_vertex_float_len;
}

pub export fn er_ui_renderer_icon_line_vertex_float_stride() u32 {
    return @intCast(packed_icon_line_vertex_float_stride);
}

pub export fn er_ui_renderer_image_vertex_buffer_ptr() usize {
    return @intFromPtr(&packed_image_vertex_floats);
}

pub export fn er_ui_renderer_image_vertex_buffer_len() usize {
    return packed_image_vertex_float_len;
}

pub export fn er_ui_renderer_image_vertex_float_stride() u32 {
    return @intCast(packed_image_vertex_float_stride);
}

pub export fn er_ui_renderer_interaction_regions_ptr() usize {
    return @intFromPtr(&interaction_regions);
}

pub export fn er_ui_renderer_interaction_regions_len() usize {
    return last_interaction_region_count;
}

pub export fn er_ui_renderer_state_size() u32 {
    return @sizeOf(@TypeOf(nodes)) +
        @sizeOf(@TypeOf(commands)) +
        @sizeOf(@TypeOf(clips)) +
        @sizeOf(@TypeOf(interaction_regions)) +
        @sizeOf(@TypeOf(packed_rect_floats)) +
        @sizeOf(@TypeOf(packed_icon_vertex_floats)) +
        @sizeOf(@TypeOf(packed_icon_line_vertex_floats)) +
        @sizeOf(@TypeOf(packed_image_vertex_floats)) +
        @sizeOf(@TypeOf(font_atlas));
}

const std = @import("std");
const renderer_font_atlas = @import("font_atlas.zig");
const icon_line_buffer = @import("icon_line_buffer.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const renderer_software = @import("software.zig");
const ui = @import("../ui.zig");

pub const Error = renderer_present.Error || renderer_software.Error;
pub const Receipt = renderer_present.Receipt;
pub const Transport = renderer_present.Transport;
pub const SoftwareFramebuffer = renderer_software.Framebuffer;
pub const IconTuning = renderer_software.IconTuning;
pub const IconTuningError = renderer_software.TuningError;
pub const IconLineError = icon_line_buffer.Error;
pub const Buffers = renderer_ir.Buffers;
pub const Sources = renderer_ir.Sources;
pub const FontAtlas = renderer_ir.FontAtlas;
pub const TextMetrics = renderer_ir.TextMetrics;
pub const Glyph = renderer_ir.Glyph;
pub const Layer = renderer_ir.Layer;
pub const IconInstance = renderer_ir.IconInstance;
pub const IrError = renderer_ir.Error;
pub const rect_float_stride = renderer_ir.rect_float_stride;
pub const text_vertex_float_stride = renderer_ir.text_vertex_float_stride;
pub const icon_instance_float_stride = renderer_ir.icon_instance_float_stride;
pub const icon_line_vertex_float_stride = renderer_ir.icon_line_vertex_float_stride;
pub const image_vertex_float_stride = renderer_ir.image_vertex_float_stride;
pub const font_first_char = renderer_ir.font_first_char;
pub const font_last_char = renderer_ir.font_last_char;

pub const FontSource = enum { atlas, object };

pub fn sources(font_atlas: *renderer_font_atlas.Atlas, font_source: FontSource) renderer_ir.Sources {
    return .{ .font = switch (font_source) { .atlas => font_atlas.source(), .object => font_atlas.objectSource() } };
}

pub fn packScene(buffers: renderer_ir.Buffers, font_atlas: *renderer_font_atlas.Atlas, font_source: FontSource, commands: []const ui.Command) (renderer_ir.Error || icon_line_buffer.Error)!void {
    try prepareSceneAssets(font_atlas, commands);
    try packSceneWithSources(buffers, sources(font_atlas, font_source), commands);
}

pub fn packSceneWithSources(buffers: renderer_ir.Buffers, source_set: renderer_ir.Sources, commands: []const ui.Command) (renderer_ir.Error || icon_line_buffer.Error)!void {
    try renderer_ir.packScene(buffers, source_set, commands);
    try packBufferIconLines(buffers);
}

pub fn prepareSceneAssets(font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) renderer_ir.Error!void {
    for (commands) |command| switch (command) {
        .text => |text_command| try font_atlas.prepareText(text_command.value, renderer_ir.textPx(text_command.origin.h), fontWeightForText(text_command.weight, text_command.origin.h)),
        else => {},
    };
}

fn fontWeightForText(weight: ui.FontWeight, height: f32) @import("../font_builtin.zig").Weight {
    return switch (weight) {
        .regular => if (height >= 24.0) .bold else if (height >= 16.0) .semibold else .regular,
        .semibold => .semibold,
        .bold => .bold,
    };
}

pub fn softwareResources(font_atlas: *const renderer_font_atlas.Atlas, image: ?renderer_software.RgbaTexture) renderer_software.Resources {
    return softwareResourcesFromAlphaAtlas(.{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .alpha = font_atlas.alphaSlice() }, image);
}

pub fn softwareResourcesFromAlphaAtlas(font: renderer_software.AlphaAtlas, image: ?renderer_software.RgbaTexture) renderer_software.Resources {
    return .{ .font = font, .image = image };
}

pub fn presentationResources(font_atlas_ready: bool, image_ready: bool) renderer_present.Resources {
    return .{ .font_atlas = font_atlas_ready, .image_texture = image_ready };
}

pub fn renderSoftwareFrame(surface: renderer_software.Framebuffer, buffers: renderer_ir.Buffers, resources: renderer_software.Resources, background: ui.Color) renderer_software.Error!renderer_present.Receipt {
    surface.clear(background);
    return surface.renderIr(buffers, resources);
}

pub fn presentPackedFrame(width: u32, height: u32, buffers: renderer_ir.Buffers, resource_set: renderer_present.Resources) renderer_present.Error!renderer_present.Receipt {
    return renderer_present.present(.{ .target = .{ .destination = .packed_frame, .width = width, .height = height }, .buffers = buffers, .resources = resource_set });
}

pub fn softwareFramebuffer(width: usize, height: usize, pixels: []ui.Color) renderer_software.Error!SoftwareFramebuffer {
    return renderer_software.Framebuffer.init(width, height, pixels);
}

pub fn setIconTuningForTest(tuning: IconTuning) IconTuningError!void { try renderer_software.setIconTuningForTest(tuning); }
pub fn resetIconTuningForTest() void { renderer_software.resetIconTuningForTest(); }

pub fn pushText(buffers: Buffers, font: FontAtlas, layer: Layer, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) IrError!void {
    try renderer_ir.pushText(buffers, font, layer, bounds, value, color, alignment);
}

pub fn pushIcon(buffers: Buffers, layer: Layer, quad: ui.IconQuad) IrError!void { try renderer_ir.pushIcon(buffers, layer, quad); }
pub fn iconAt(values: []const f32, index: usize) IrError!IconInstance { return renderer_ir.iconAt(values, index); }

pub fn packIconLines(instances: []const f32, out: []f32, out_len: *usize) icon_line_buffer.Error!void { try icon_line_buffer.packIconInstances(instances, out, out_len); }

pub fn packBufferIconLines(buffers: renderer_ir.Buffers) icon_line_buffer.Error!void {
    try packIconLines(buffers.liveIconVertices(), buffers.icon_line_vertices, buffers.icon_line_vertex_len);
    try packIconLines(buffers.liveOverlayIconVertices(), buffers.overlay_icon_line_vertices, buffers.overlay_icon_line_vertex_len);
}

test "render pipeline builds atlas and object font sources" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initEmpty();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(0, 0, 80, 24), .value = "A", .color = .text } });
    var atlas_storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    try packScene(atlas_storage.buffers(), &font_atlas, .atlas, scene.written());
    try std.testing.expect(atlas_storage.text_vertex_len != 0);
}

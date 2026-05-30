const std = @import("std");
const renderer_font_atlas = @import("font_atlas_weighted.zig");
const icon_line_buffer = @import("icon_line_buffer.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const renderer_software = @import("backends/software.zig");
const ui = @import("../ui/core.zig");

pub const Error = renderer_present.Error || renderer_software.Error;
pub const Receipt = renderer_present.Receipt;
pub const Transport = renderer_present.Transport;
pub const SoftwareFramebuffer = renderer_software.Framebuffer;
pub const IconTuning = renderer_software.IconTuning;
pub const IconTuningError = renderer_software.TuningError;
pub const IconLineError = icon_line_buffer.Error;
pub const Buffers = renderer_ir.Buffers;
pub const Layer = renderer_ir.Layer;
pub const IconInstance = renderer_ir.IconInstance;
pub const IrError = renderer_ir.Error;
pub const rect_float_stride = renderer_ir.rect_float_stride;
pub const text_vertex_float_stride = renderer_ir.text_vertex_float_stride;
pub const icon_instance_float_stride = renderer_ir.icon_instance_float_stride;
pub const icon_line_vertex_float_stride = renderer_ir.icon_line_vertex_float_stride;
pub const image_vertex_float_stride = renderer_ir.image_vertex_float_stride;

pub fn packScene(buffers: renderer_ir.Buffers, font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) (renderer_ir.Error || icon_line_buffer.Error)!void {
    try prepareSceneAssets(font_atlas, commands);
    try packPreparedScene(buffers, commands);
    try packTextQuads(buffers, font_atlas, commands);
}

fn packPreparedScene(buffers: renderer_ir.Buffers, commands: []const ui.Command) (renderer_ir.Error || icon_line_buffer.Error)!void {
    buffers.clearBase();
    buffers.clearOverlay();
    try packPreparedRange(buffers, commands, .base);
    try packBufferIconLines(buffers);
}

fn packPreparedRange(buffers: renderer_ir.Buffers, commands: []const ui.Command, layer: renderer_ir.Layer) renderer_ir.Error!void {
    for (commands) |command| switch (command) {
        .rect => |rect| try renderer_ir.pushRect(buffers, layer, rect.bounds, rect.color, rect.color2, rect.radius, rect.shadow, renderer_ir.rectModeCode(rect.mode)),
        .border => |border| try renderer_ir.pushRect(buffers, layer, border.bounds, border.color, .clear, 0, 0, renderer_ir.rectModeCode(.border)),
        .text => {},
        .icon_quad => |quad| try renderer_ir.pushSvgQuad(buffers, layer, quad),
        .svg_quad => |quad| try renderer_ir.pushSvgQuad(buffers, layer, quad),
        .image_quad => |quad| if (layer == .base) try renderer_ir.pushImage(buffers, quad),
        .drag_source, .drop_target, .text_quad, .transition => {},
    };
}

pub fn prepareSceneAssets(font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) renderer_ir.Error!void {
    for (commands) |command| switch (command) {
        .text => |text_command| font_atlas.prepareText(
            text_command.value,
            @as(u8, @intFromFloat(@ceil(text_command.origin.h))),
            fontWeightForText(text_command.weight),
        ) catch |err| switch (err) {
            error.InvalidBuffer => {},
            else => return err,
        },
        else => {},
    };
}

fn fontWeightForText(weight: ui.FontWeight) @import("font.zig").Weight {
    return switch (weight) {
        .regular => .regular,
        .semibold => .semibold,
        .bold => .bold,
    };
}

pub fn softwareResources(font_atlas: *const renderer_font_atlas.Atlas, image: ?renderer_software.RgbaTexture) renderer_software.Resources {
    return softwareResourcesFromAlphaAtlas(.{ .width = font_atlas.width, .height = font_atlas.height, .alpha = font_atlas.alphaSlice() }, image);
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
pub fn setIconTuningForTest(tuning: IconTuning) IconTuningError!void {
    try renderer_software.setIconTuningForTest(tuning);
}
pub fn resetIconTuningForTest() void {
    renderer_software.resetIconTuningForTest();
}
pub fn pushIcon(buffers: Buffers, layer: Layer, quad: ui.IconQuad) IrError!void {
    try renderer_ir.pushSvgQuad(buffers, layer, quad);
}
pub fn iconAt(values: []const f32, index: usize) IrError!IconInstance {
    return renderer_ir.iconAt(values, index);
}
pub fn packIconLines(instances: []const f32, out: []f32, out_len: *usize) icon_line_buffer.Error!void {
    try icon_line_buffer.packIconInstances(instances, out, out_len);
}

pub fn packBufferIconLines(buffers: renderer_ir.Buffers) icon_line_buffer.Error!void {
    try packIconLines(buffers.liveIconVertices(), buffers.icon_line_vertices, buffers.icon_line_vertex_len);
    try packIconLines(buffers.liveOverlayIconVertices(), buffers.overlay_icon_line_vertices, buffers.overlay_icon_line_vertex_len);
}

pub fn packTextQuads(buffers: renderer_ir.Buffers, font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) renderer_ir.Error!void {
    const font_source = font_atlas.source();
    for (commands) |command| switch (command) {
        .text_quad => |quad| try renderer_ir.pushImage(buffers, quad),
        .text => |text_command| {
            if (text_command.value.len == 0) continue;
            const px: u8 = @intFromFloat(@ceil(text_command.origin.h));
            const metrics_value = font_source.metrics(font_source.context, px);
            const text_width = font_source.width(font_source.context, text_command.value, px);
            const align_offset: f32 = switch (text_command.alignment) {
                .start => 0.0,
                .center => @max(0.0, (text_command.origin.w - text_width) * 0.5),
                .end => @max(0.0, text_command.origin.w - text_width),
            };
            var pen_x = text_command.origin.x + align_offset;
            const baseline = text_command.origin.y + metrics_value.ascender;
            var index: usize = 0;
            while (index < text_command.value.len) {
                const cp_len = std.unicode.utf8ByteSequenceLength(text_command.value[index]) catch {
                    index += 1;
                    continue;
                };
                const end = index + cp_len;
                if (end > text_command.value.len) break;
                const codepoint = std.unicode.utf8Decode(text_command.value[index..end]) catch {
                    index = end;
                    continue;
                };
                index = end;
                const glyph_value = (try font_source.glyph(font_source.context, codepoint, px)) orelse continue;
                if (glyph_value.w > 0.0 and glyph_value.h > 0.0) {
                    const gx = pen_x + glyph_value.left;
                    const gy = baseline + glyph_value.top;
                    const snapped = ui.Rect.init(
                        @round(gx),
                        @round(gy),
                        @max(1.0, @round(gx + glyph_value.w) - @round(gx)),
                        @max(1.0, @round(gy + glyph_value.h) - @round(gy)),
                    );
                    try renderer_ir.pushClippedTexturedQuad(
                        buffers.image_vertices,
                        buffers.image_vertex_len,
                        snapped,
                        snapped,
                        glyph_value.u0,
                        glyph_value.v0,
                        glyph_value.u1,
                        glyph_value.v1,
                        text_command.color,
                    );
                }
                pen_x += glyph_value.advance;
                if (pen_x > text_command.origin.x + text_command.origin.w) break;
            }
        },
        else => {},
    };
}

test "render pipeline prepares font atlas without text in packed buffers" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(0, 0, 80, 24), .value = "A", .color = .text } });
    var atlas_storage = renderer_ir.FixedBuffers(0, 0, 6, 0, 0, 0, 0){};
    try packScene(atlas_storage.buffers(), &font_atlas, scene.written());
}

test "render pipeline ignores invalid utf8 text during atlas prep" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();

    const invalid = [_]u8{0xff};
    var scene_commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&scene_commands);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(0, 0, 80, 24), .value = &invalid, .color = .text } });
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(0, 24, 80, 24), .value = "A", .color = .text } });

    var atlas_storage = renderer_ir.FixedBuffers(0, 0, 6, 0, 0, 0, 0){};
    try packScene(atlas_storage.buffers(), &font_atlas, scene.written());
}

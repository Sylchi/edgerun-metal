const std = @import("std");
const font_vector = @import("font.zig");
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
const small_text_snap_max_px: u8 = 18;

pub fn packScene(buffers: renderer_ir.Buffers, font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) (renderer_ir.Error || icon_line_buffer.Error)!void {
    try prepareSceneAssets(font_atlas, commands);
    try packPreparedScene(buffers, commands);
    try packTextQuads(buffers, commands);
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
        .overlay_rect => |rect| try renderer_ir.pushRect(buffers, .overlay, rect.bounds, rect.color, rect.color2, rect.radius, rect.shadow, renderer_ir.rectModeCode(rect.mode)),
        .border => |border| try renderer_ir.pushRect(buffers, layer, border.bounds, border.color, .clear, 0, 0, renderer_ir.rectModeCode(.border)),
        .text, .overlay_text => {},
        .icon_quad => |quad| try renderer_ir.pushSvgQuad(buffers, layer, quad),
        .overlay_icon_quad => |quad| try renderer_ir.pushSvgQuad(buffers, .overlay, quad),
        .svg_quad => |quad| try renderer_ir.pushSvgQuad(buffers, layer, quad),
        .image_quad => |quad| if (layer == .base) try renderer_ir.pushImage(buffers, quad),
        .drag_source, .drop_target, .text_quad, .transition => {},
    };
}

pub fn prepareSceneAssets(font_atlas: *renderer_font_atlas.Atlas, commands: []const ui.Command) renderer_ir.Error!void {
    for (commands) |command| switch (command) {
        .text => |text_command| try prepareText(font_atlas, text_command),
        .overlay_text => |text_command| try prepareText(font_atlas, text_command),
        else => {},
    };
}

fn prepareText(font_atlas: *renderer_font_atlas.Atlas, text_command: anytype) renderer_ir.Error!void {
    if (text_command.value.len == 0) return;
    const px: u8 = @intFromFloat(@ceil(text_command.origin.h));
    font_atlas.setTextWeight(fontWeightForText(text_command.weight));
    font_atlas.prepareText(text_command.value, px, fontWeightForText(text_command.weight)) catch |err| switch (err) {
        error.Budget => return error.Budget,
        error.InvalidBuffer => return,
    };
}

fn fontWeightForText(weight: ui.FontWeight) font_vector.Weight {
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

pub fn packTextQuads(buffers: renderer_ir.Buffers, commands: []const ui.Command) renderer_ir.Error!void {
    for (commands) |command| switch (command) {
        .text_quad => |quad| try renderer_ir.pushImage(buffers, quad),
        .text => |text_command| try packTextCommand(buffers, text_command, false),
        .overlay_text => |text_command| try packTextCommand(buffers, text_command, true),
        else => {},
    };
}

fn packTextCommand(buffers: renderer_ir.Buffers, text_command: anytype, overlay: bool) renderer_ir.Error!void {
    if (text_command.value.len == 0) return;
    const px: u8 = @intFromFloat(@ceil(text_command.origin.h));
    const font_body = font_vector.body(fontWeightForText(text_command.weight));
    const font_scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font_body.metrics.units_per_em));
    const text_width = vectorTextWidth(font_body, text_command.value, font_scale);
    const align_offset: f32 = switch (text_command.alignment) {
        .start => 0.0,
        .center => @max(0.0, (text_command.origin.w - text_width) * 0.5),
        .end => @max(0.0, text_command.origin.w - text_width),
    };
    var pen_x = text_command.origin.x + align_offset;
    if (shouldSnapTextToPixelGrid(px)) pen_x = @round(pen_x);
    const baseline = if (shouldSnapTextToPixelGrid(px))
        @round(text_command.origin.y + font_body.metrics.ascender * font_scale)
    else
        text_command.origin.y + font_body.metrics.ascender * font_scale;
    var previous: ?u21 = null;
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
        if (previous) |prev| pen_x += font_body.kern(prev, codepoint) * font_scale;
        const glyph_value = font_body.glyphForCodepoint(codepoint) orelse {
            previous = codepoint;
            continue;
        };
        if (glyph_value.commands.len != 0) {
            if (overlay) {
                try renderer_ir.pushOverlayTextGlyph(buffers, pen_x, baseline, @floatFromInt(px), codepoint, text_command.weight, text_command.color);
            } else {
                try renderer_ir.pushTextGlyph(buffers, pen_x, baseline, @floatFromInt(px), codepoint, text_command.weight, text_command.color);
            }
        }
        pen_x += glyph_value.advance * font_scale;
        previous = codepoint;
        if (pen_x > text_command.origin.x + text_command.origin.w) break;
    }
}

fn vectorTextWidth(font_body: font_vector.Body, value: []const u8, scale: f32) f32 {
    var width: f32 = 0.0;
    var previous: ?u21 = null;
    var index: usize = 0;
    while (index < value.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(value[index]) catch {
            index += 1;
            continue;
        };
        const end = index + cp_len;
        if (end > value.len) break;
        const codepoint = std.unicode.utf8Decode(value[index..end]) catch {
            index = end;
            continue;
        };
        index = end;
        if (previous) |prev| width += font_body.kern(prev, codepoint) * scale;
        if (font_body.glyphForCodepoint(codepoint)) |glyph_value| width += glyph_value.advance * scale;
        previous = codepoint;
    }
    return width;
}

fn shouldSnapTextToPixelGrid(px: u8) bool {
    return px <= small_text_snap_max_px;
}

fn isIntegral(value: f32) bool {
    return @abs(value - @round(value)) <= 0.0001;
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

test "render pipeline packs vector glyphs with snapped small text baseline" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(10.35, 11.65, 120, 12), .value = "A", .color = .text } });
    var storage = renderer_ir.FixedBuffers(0, 0, 6, 0, 0, 0, 0){};
    try packScene(storage.buffers(), &font_atlas, scene.written());
    const vertices = storage.buffers().liveTextVertices();
    try std.testing.expect(vertices.len != 0);
    const glyph = try renderer_ir.textGlyphAt(vertices, 0);
    const font_body = font_vector.body(.regular);
    const font_scale = @as(f32, 12.0) / @as(f32, @floatFromInt(font_body.metrics.units_per_em));
    try std.testing.expectApproxEqAbs(@round(10.35), glyph.x, 0.0001);
    try std.testing.expectApproxEqAbs(@round(11.65 + font_body.metrics.ascender * font_scale), glyph.baseline_y, 0.0001);
    try std.testing.expectEqual(@as(u21, 'A'), glyph.codepoint);
    try std.testing.expectEqual(ui.FontWeight.regular, glyph.weight);
}

test "render pipeline packs overlay text into overlay buffer" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushText(ui.Rect.init(0, 0, 80, 16), "Base", .text);
    try scene.pushOverlayText(ui.Rect.init(0, 20, 80, 16), "Editor", .text);

    var storage = renderer_ir.FixedBuffers(0, 0, renderer_ir.textured_quad_vertex_count, 1, 0, 0, 0){};
    try packScene(storage.buffers(), &font_atlas, scene.written());

    try std.testing.expect(storage.text_vertex_len != 0);
    try std.testing.expect(storage.overlay_text_vertex_len != 0);
}

test "render pipeline preserves subpixel placement for large text" {
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    var commands: [1]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(10.35, 11.65, 240, 40), .value = "A", .color = .text } });
    var storage = renderer_ir.FixedBuffers(0, 0, 6, 0, 0, 0, 0){};
    try packScene(storage.buffers(), &font_atlas, scene.written());
    const vertices = storage.buffers().liveTextVertices();
    try std.testing.expect(vertices.len != 0);
    const glyph = try renderer_ir.textGlyphAt(vertices, 0);
    try std.testing.expect(!isIntegral(glyph.x) or !isIntegral(glyph.baseline_y));
}

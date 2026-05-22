const std = @import("std");
const icon = @import("icon.zig");
const input = @import("input.zig");
const renderer = @import("renderer_software.zig");
const component_gallery = @import("component_gallery.zig");
const tabler_atlas = @import("tabler_atlas.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const varfont = @import("varfont.zig");

const max_width: usize = 4096;
const max_height: usize = 2880;
const max_pixels: usize = max_width * max_height;
const max_input_bytes: usize = 8192;
const max_nodes: usize = 256;
const max_commands: usize = 4096;
const gpu_rect_float_stride: usize = 15;
const gpu_text_vertex_float_stride: usize = 8;
const gpu_icon_vertex_float_stride: usize = 8;
const max_gpu_rects: usize = 8192;
const max_gpu_text_vertices: usize = 24576;
const max_gpu_icon_vertices: usize = 4096;
const font_atlas_width: usize = 4096;
const font_atlas_height: usize = 4096;
const font_atlas_bytes: usize = font_atlas_width * font_atlas_height;
const font_glyph_capacity: usize = 1280;
const font_first_px: u8 = 11;
const font_last_px: u8 = 22;
const font_first_char: u8 = 32;
const font_last_char: u8 = 126;
const font_padding: usize = 8;
const font_row_gap: usize = 8;
const font_bitmap_bytes: usize = 8 * 1024 * 1024;
const icon_atlas_width: usize = tabler_atlas.width;
const icon_atlas_height: usize = tabler_atlas.height;

var pixels: [max_pixels]ui.Color = undefined;
var input_bytes: [max_input_bytes]u8 = undefined;
var nodes: [max_nodes]ui.Node = undefined;
var commands: [max_commands]ui.Command = undefined;
var gpu_rect_floats: [max_gpu_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_rect_float_len: usize = 0;
var gpu_text_vertex_floats: [max_gpu_text_vertices * gpu_text_vertex_float_stride]f32 = undefined;
var gpu_text_vertex_float_len: usize = 0;
var gpu_icon_vertex_floats: [max_gpu_icon_vertices * gpu_icon_vertex_float_stride]f32 = undefined;
var gpu_icon_vertex_float_len: usize = 0;
var font_atlas_alpha: [font_atlas_bytes]u8 = [_]u8{0} ** font_atlas_bytes;
var font_bitmap: [font_bitmap_bytes]u8 = undefined;
var font_glyphs: [font_glyph_capacity]FontGlyph = undefined;
var font_glyph_count: usize = 0;
var font_atlas_ready = false;
var font_device_scale: f32 = 1.0;
var font_atlas_device_scale: f32 = 0.0;
var frame_width: usize = 0;
var frame_height: usize = 0;
var last_error: ErrorCode = .ok;
var hover_hit_kind: u32 = hover_hit_kind_none;
var hover_hit_id: u32 = 0;

const hover_hit_kind_none: u32 = 255;

const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    bad_ui = 3,
    render_failed = 4,
    gpu_budget = 5,
    font_atlas = 6,
};

const FontGlyph = struct {
    ch: u8,
    px: u8,
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    w: f32,
    h: f32,
    source_w: u16,
    source_h: u16,
    left: f32,
    top: f32,
    advance: f32,
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

export fn er_ui_gpu_text_vertex_float_stride() u32 {
    return gpu_text_vertex_float_stride;
}

export fn er_ui_gpu_text_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_text_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_text_vertex_buffer_len() usize {
    return gpu_text_vertex_float_len;
}

export fn er_ui_gpu_icon_vertex_float_stride() u32 {
    return gpu_icon_vertex_float_stride;
}

export fn er_ui_gpu_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_icon_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_icon_vertex_buffer_len() usize {
    return gpu_icon_vertex_float_len;
}

export fn er_ui_font_atlas_width() u32 {
    return font_atlas_width;
}

export fn er_ui_font_atlas_height() u32 {
    return font_atlas_height;
}

export fn er_ui_font_atlas_ptr() usize {
    ensureFontAtlas() catch return 0;
    return @intFromPtr(font_atlas_alpha[0..].ptr);
}

export fn er_ui_icon_atlas_width() u32 {
    return icon_atlas_width;
}

export fn er_ui_icon_atlas_height() u32 {
    return icon_atlas_height;
}

export fn er_ui_icon_atlas_ptr() usize {
    return @intFromPtr(tabler_atlas.alpha.ptr);
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

export fn er_ui_set_device_scale(scale: f32) u32 {
    const next = normalizedDeviceScale(scale);
    if (@abs(next - font_device_scale) <= 0.001) return 0;
    font_device_scale = next;
    font_atlas_ready = false;
    return 1;
}

export fn er_ui_hover_hit_kind() u32 {
    return hover_hit_kind;
}

export fn er_ui_hover_hit_id() u32 {
    return hover_hit_id;
}

export fn er_ui_component_gallery_layout_masonry_id() u32 {
    return component_gallery.layout_masonry_id;
}

export fn er_ui_component_gallery_layout_grid_id() u32 {
    return component_gallery.layout_grid_id;
}

export fn er_ui_component_gallery_gap_compact_id() u32 {
    return component_gallery.gap_compact_id;
}

export fn er_ui_component_gallery_gap_default_id() u32 {
    return component_gallery.gap_default_id;
}

export fn er_ui_component_gallery_gap_wide_id() u32 {
    return component_gallery.gap_wide_id;
}

export fn er_ui_clear(width: u32, height: u32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    surface.clear(.bg);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_render_component_gallery(width: u32, height: u32) u32 {
    return er_ui_render_component_gallery_scroll(width, height, 0.0);
}

export fn er_ui_render_component_gallery_scroll(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_render_component_gallery_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_render_component_gallery_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    component_gallery.renderComponentGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{ .layout = component_gallery.LayoutMode.fromRaw(layout_raw), .grid_gap = grid_gap, .scroll_y = scroll_y, .hover_x = hover_x, .hover_y = hover_y }) catch return finishError(.render_failed);

    updateHoverHit(scene.written(), hover_x, hover_y);
    surface.clear(.bg);
    surface.rasterize(scene.written());
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_build_component_gallery_gpu_frame(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    ensureFontAtlas() catch return finishError(.font_atlas);

    var scene = ui.Scene.init(&commands);
    component_gallery.renderComponentGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{ .layout = component_gallery.LayoutMode.fromRaw(layout_raw), .grid_gap = grid_gap, .scroll_y = scroll_y, .hover_x = hover_x, .hover_y = hover_y }) catch return finishError(.render_failed);

    updateHoverHit(scene.written(), hover_x, hover_y);
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

fn updateHoverHit(scene_commands: []const ui.Command, x: f32, y: f32) void {
    if (x < 0.0 or y < 0.0) {
        hover_hit_kind = hover_hit_kind_none;
        hover_hit_id = 0;
        return;
    }
    if (input.hitTest(scene_commands, x, y)) |hit| {
        hover_hit_kind = @intFromEnum(hit.kind);
        hover_hit_id = hit.id;
        return;
    }
    hover_hit_kind = hover_hit_kind_none;
    hover_hit_id = 0;
}

fn packGpuScene(scene_commands: []const ui.Command) error{Budget}!void {
    gpu_rect_float_len = 0;
    gpu_text_vertex_float_len = 0;
    gpu_icon_vertex_float_len = 0;
    for (scene_commands) |command| switch (command) {
        .rect => |rect| try pushPackedRect(rect.bounds, rect.color, rect.color2, rect.radius, rect.shadow, rectModeCode(rect.mode)),
        .border => |border| try pushPackedRect(border.bounds, border.color, .clear, 0, 0, rectModeCode(.border)),
        .text => |text_command| try pushPackedText(text_command.origin, text_command.value, text_command.color, text_command.alignment),
        .icon_quad => |quad| try pushPackedIcon(quad),
        .hit, .drag_source, .drop_target, .text_quad, .transition => {},
    };
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

fn pushPackedText(bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) error{Budget}!void {
    if (value.len == 0 or !bounds.valid()) return;
    const px = textPx(bounds.h);
    var pen_x = bounds.x + textAlignOffset(value, px, bounds.w, alignment);
    const metrics = fontMetrics(px);
    const baseline = bounds.y + metrics.ascender;
    const clip = textClipBounds(bounds, metrics);
    for (value) |byte| {
        if (byte < font_first_char or byte > font_last_char) continue;
        const glyph = findFontGlyph(byte, px) orelse continue;
        if (glyph.w > 0.0 and glyph.h > 0.0) {
            const quad = snapGlyphQuad(pen_x + glyph.left, baseline + glyph.top, glyph.w, glyph.h);
            try pushClippedTexturedQuad(&gpu_text_vertex_floats, &gpu_text_vertex_float_len, clip, quad, glyph.u0, glyph.v0, glyph.u1, glyph.v1, color);
        }
        pen_x += glyph.advance;
        if (pen_x > bounds.x + bounds.w) break;
    }
}

fn pushPackedIcon(quad: ui.Quad) error{Budget}!void {
    if (!quad.bounds.valid() or quad.atlas_id == 0) return;
    const rect = iconAtlasRect(quad.atlas_id) orelse return;
    try pushClippedTexturedQuad(&gpu_icon_vertex_floats, &gpu_icon_vertex_float_len, quad.bounds, quad.bounds, rect.u0, rect.v0, rect.u1, rect.v1, quad.color);
}

fn pushClippedTexturedQuad(buffer: []f32, len: *usize, clip: ui.Rect, bounds: ui.Rect, tex_u0: f32, tex_v0: f32, tex_u1: f32, tex_v1: f32, color: ui.Color) error{Budget}!void {
    const clipped = bounds.intersect(clip) orelse return;
    if (len.* + gpu_text_vertex_float_stride * 6 > buffer.len) return error.Budget;
    const tx0 = if (bounds.w > 0.0) (clipped.x - bounds.x) / bounds.w else 0.0;
    const ty0 = if (bounds.h > 0.0) (clipped.y - bounds.y) / bounds.h else 0.0;
    const tx1 = if (bounds.w > 0.0) (clipped.x + clipped.w - bounds.x) / bounds.w else 1.0;
    const ty1 = if (bounds.h > 0.0) (clipped.y + clipped.h - bounds.y) / bounds.h else 1.0;
    const cu0 = lerp(tex_u0, tex_u1, tx0);
    const cv0 = lerp(tex_v0, tex_v1, ty0);
    const cu1 = lerp(tex_u0, tex_u1, tx1);
    const cv1 = lerp(tex_v0, tex_v1, ty1);
    pushTexturedVertex(buffer, len, clipped.x, clipped.y, cu0, cv0, color);
    pushTexturedVertex(buffer, len, clipped.x + clipped.w, clipped.y, cu1, cv0, color);
    pushTexturedVertex(buffer, len, clipped.x + clipped.w, clipped.y + clipped.h, cu1, cv1, color);
    pushTexturedVertex(buffer, len, clipped.x, clipped.y, cu0, cv0, color);
    pushTexturedVertex(buffer, len, clipped.x + clipped.w, clipped.y + clipped.h, cu1, cv1, color);
    pushTexturedVertex(buffer, len, clipped.x, clipped.y + clipped.h, cu0, cv1, color);
}

fn pushTexturedVertex(buffer: []f32, len: *usize, x: f32, y: f32, u: f32, v: f32, color: ui.Color) void {
    const values = [_]f32{ x, y, u, v, channel(color.r), channel(color.g), channel(color.b), channel(color.a) };
    @memcpy(buffer[len.* .. len.* + gpu_text_vertex_float_stride], &values);
    len.* += gpu_text_vertex_float_stride;
}

fn ensureFontAtlas() !void {
    if (font_atlas_ready) return;
    const face = try varfont.Face.geist();
    @memset(&font_atlas_alpha, 0);
    font_glyph_count = 0;
    var cache = varfont.Cache.init(face, &font_bitmap);
    _ = cache.setAxis("wght", 560.0);
    const raster_scale = font_device_scale;
    font_atlas_device_scale = raster_scale;
    var x: usize = font_padding;
    var y: usize = font_padding;
    var row_h: usize = 0;
    var px: u8 = font_first_px;
    while (px <= font_last_px) : (px += 1) {
        cache.clear();
        const bake_px = @as(f32, @floatFromInt(px)) * raster_scale;
        var ch: u8 = font_first_char;
        while (ch <= font_last_char) : (ch += 1) {
            const glyph_id = face.glyphId(ch);
            const cached = cache.bakeGlyph(glyph_id, bake_px) catch continue;
            const view = cache.bitmapView(cached);
            const gw: usize = view.width;
            const gh: usize = view.height;
            if (gw > 0 and gh > 0) {
                if (x + gw + font_padding >= font_atlas_width) {
                    x = font_padding;
                    y += row_h + font_row_gap;
                    row_h = 0;
                }
                if (y + gh + font_padding >= font_atlas_height) return error.Budget;
                copyFontGlyphBitmap(x, y, gw, gh, view.pixels);
                row_h = @max(row_h, gh);
            }
            if (font_glyph_count >= font_glyphs.len) return error.Budget;
            font_glyphs[font_glyph_count] = .{
                .ch = ch,
                .px = px,
                .u0 = (@as(f32, @floatFromInt(x)) + 0.5) / @as(f32, @floatFromInt(font_atlas_width)),
                .v0 = (@as(f32, @floatFromInt(y)) + 0.5) / @as(f32, @floatFromInt(font_atlas_height)),
                .u1 = (@as(f32, @floatFromInt(x + gw)) - 0.5) / @as(f32, @floatFromInt(font_atlas_width)),
                .v1 = (@as(f32, @floatFromInt(y + gh)) - 0.5) / @as(f32, @floatFromInt(font_atlas_height)),
                .w = scaledFontValue(@floatFromInt(gw)),
                .h = scaledFontValue(@floatFromInt(gh)),
                .source_w = view.width,
                .source_h = view.height,
                .left = scaledFontValue(@floatFromInt(cached.left)),
                .top = scaledFontValue(@floatFromInt(cached.top)),
                .advance = scaledFontValue(cached.advance),
            };
            font_glyph_count += 1;
            if (gw > 0) x += gw + font_row_gap;
        }
    }
    font_atlas_ready = true;
}

fn copyFontGlyphBitmap(x: usize, y: usize, w: usize, h: usize, source: []const u8) void {
    var row: usize = 0;
    while (row < h) : (row += 1) {
        const dst = (y + row) * font_atlas_width + x;
        const src = row * w;
        @memcpy(font_atlas_alpha[dst .. dst + w], source[src .. src + w]);
    }
}

fn findFontGlyph(ch: u8, px: u8) ?FontGlyph {
    for (font_glyphs[0..font_glyph_count]) |glyph| {
        if (glyph.ch == ch and glyph.px == px) return glyph;
    }
    return null;
}

fn scaledFontValue(value: f32) f32 {
    return value / font_atlas_device_scale;
}

fn snapGlyphQuad(x: f32, y: f32, w: f32, h: f32) ui.Rect {
    const left = @round(x);
    const top = @round(y);
    const right = @max(left + 1.0, @round(x + w));
    const bottom = @max(top + 1.0, @round(y + h));
    return ui.Rect.init(left, top, right - left, bottom - top);
}

fn textPx(height: f32) u8 {
    return @intFromFloat(@round(std.math.clamp(height, @as(f32, @floatFromInt(font_first_px)), @as(f32, @floatFromInt(font_last_px)))));
}

fn normalizedDeviceScale(scale: f32) f32 {
    if (!std.math.isFinite(scale)) return 2.0;
    return std.math.clamp(scale, 2.0, 4.0);
}

const TextMetrics = struct {
    ascender: f32,
    descender: f32,
};

fn fontMetrics(px: u8) TextMetrics {
    const face = varfont.Face.geist() catch unreachable;
    const metrics = face.metrics(@floatFromInt(px));
    return .{ .ascender = metrics.ascender, .descender = metrics.descender };
}

fn textClipBounds(bounds: ui.Rect, metrics: TextMetrics) ui.Rect {
    const top_extra = @max(0.0, metrics.ascender - bounds.h);
    const bottom_extra = @max(0.0, -metrics.descender);
    return ui.Rect.init(bounds.x, bounds.y - top_extra, bounds.w, bounds.h + top_extra + bottom_extra);
}

fn textAlignOffset(value: []const u8, px: u8, width: f32, alignment: ui.TextAlign) f32 {
    const measured = textWidth(value, px);
    return switch (alignment) {
        .start => 0.0,
        .center => @max(0.0, (width - measured) * 0.5),
        .end => @max(0.0, width - measured),
    };
}

fn textWidth(value: []const u8, px: u8) f32 {
    var out: f32 = 0.0;
    for (value) |byte| {
        if (findFontGlyph(byte, px)) |glyph| out += glyph.advance;
    }
    return out;
}

const AtlasRect = struct {
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
};

fn iconAtlasRect(atlas_id: u32) ?AtlasRect {
    const value = icon.fromAtlasId(atlas_id) orelse return null;
    const found = tabler_atlas.rect(value);
    return .{
        .u0 = (@as(f32, @floatFromInt(found.x)) + 0.5) / @as(f32, @floatFromInt(icon_atlas_width)),
        .v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(icon_atlas_height)),
        .u1 = (@as(f32, @floatFromInt(found.x + found.w)) - 0.5) / @as(f32, @floatFromInt(icon_atlas_width)),
        .v1 = (@as(f32, @floatFromInt(found.y + found.h)) - 0.5) / @as(f32, @floatFromInt(icon_atlas_height)),
    };
}

fn rectModeCode(mode: ui.RectMode) f32 {
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 3,
    };
}

fn channel(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

test "browser hover state exposes scene hit kind and id" {
    var local_commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&local_commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 42, .bounds = ui.Rect.init(10, 20, 40, 30) });

    updateHoverHit(scene.written(), 20, 30);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(@as(u32, 42), hover_hit_id);

    updateHoverHit(scene.written(), -1, -1);
    try std.testing.expectEqual(hover_hit_kind_none, hover_hit_kind);
    try std.testing.expectEqual(@as(u32, 0), hover_hit_id);
}

test "browser component gallery builds packed webgl buffers and atlases" {
    const code = er_ui_build_component_gallery_gpu_frame_layout_gap_hover(960, 640, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expect(er_ui_font_atlas_ptr() != 0);
    try std.testing.expect(er_ui_icon_atlas_ptr() != 0);
}

test "browser packed text preserves variable font descenders" {
    try ensureFontAtlas();
    gpu_text_vertex_float_len = 0;
    const bounds = ui.Rect.init(0, 0, 64, 14);
    try pushPackedText(bounds, "y", .text, .start);
    try std.testing.expect(gpu_text_vertex_float_len > 0);

    var max_y: f32 = 0.0;
    var index: usize = 1;
    while (index < gpu_text_vertex_float_len) : (index += gpu_text_vertex_float_stride) {
        max_y = @max(max_y, gpu_text_vertex_floats[index]);
    }
    try std.testing.expect(max_y > bounds.y + bounds.h);
}

test "browser variable font atlas separates css size from raster scale" {
    font_atlas_ready = false;
    _ = er_ui_set_device_scale(2.0);
    try ensureFontAtlas();
    const glyph_2x = findFontGlyph('M', 14).?;

    _ = er_ui_set_device_scale(3.0);
    try ensureFontAtlas();
    const glyph_3x = findFontGlyph('M', 14).?;

    try std.testing.expect(glyph_3x.source_w > glyph_2x.source_w);
    try std.testing.expectApproxEqAbs(glyph_2x.w, glyph_3x.w, 1.5);
    try std.testing.expectApproxEqAbs(glyph_2x.advance, glyph_3x.advance, 0.75);
}

const std = @import("std");
const math = @import("../math.zig");
const icon_svg = @import("../icon_svg.zig");
const ui = @import("../ui.zig");

pub const rect_float_stride: usize = 15;
pub const text_vertex_float_stride: usize = 8;
pub const icon_instance_float_stride: usize = 9;
pub const icon_line_vertex_float_stride: usize = 6;
pub const image_vertex_float_stride: usize = 8;
pub const font_first_px: u8 = 11;
pub const font_last_px: u8 = 48;
pub const textured_quad_vertex_count: usize = 6;

pub const Error = error{
    Budget,
    InvalidBuffer,
};

pub const rect_x_index: usize = 0;
pub const rect_y_index: usize = 1;
pub const rect_w_index: usize = 2;
pub const rect_h_index: usize = 3;
pub const rect_radius_index: usize = 4;
pub const rect_shadow_index: usize = 5;
pub const rect_color_r_index: usize = 6;
pub const rect_color_g_index: usize = 7;
pub const rect_color_b_index: usize = 8;
pub const rect_color_a_index: usize = 9;
pub const rect_color2_r_index: usize = 10;
pub const rect_color2_g_index: usize = 11;
pub const rect_color2_b_index: usize = 12;
pub const rect_color2_a_index: usize = 13;
pub const rect_mode_index: usize = 14;
pub const rect_mode_fill: u8 = 0;
pub const rect_mode_shadow: u8 = 1;
pub const rect_mode_border: u8 = 2;
pub const rect_mode_linear_gradient: u8 = 3;
pub const rect_mode_pie_slice: u8 = 4;
pub const textured_x_index: usize = 0;
pub const textured_y_index: usize = 1;
pub const textured_u_index: usize = 2;
pub const textured_v_index: usize = 3;
pub const textured_color_r_index: usize = 4;
pub const textured_color_g_index: usize = 5;
pub const textured_color_b_index: usize = 6;
pub const textured_color_a_index: usize = 7;
pub const icon_x_index: usize = 0;
pub const icon_y_index: usize = 1;
pub const icon_w_index: usize = 2;
pub const icon_h_index: usize = 3;
pub const icon_color_r_index: usize = 4;
pub const icon_color_g_index: usize = 5;
pub const icon_color_b_index: usize = 6;
pub const icon_color_a_index: usize = 7;
pub const icon_id_index: usize = 8;
pub const icon_line_x_index: usize = 0;
pub const icon_line_y_index: usize = 1;
pub const icon_line_color_r_index: usize = 2;
pub const icon_line_color_g_index: usize = 3;
pub const icon_line_color_b_index: usize = 4;
pub const icon_line_color_a_index: usize = 5;

pub const Layer = enum {
    base,
    overlay,
};

pub const TextMetrics = struct {
    ascender: f32,
    descender: f32,
};

pub const Glyph = struct {
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    w: f32,
    h: f32,
    left: f32,
    top: f32,
    advance: f32,
};

pub const RectInstance = struct {
    bounds: ui.Rect,
    color: ui.Color,
    color2: ui.Color,
    radius: f32,
    shadow: f32,
    mode: ui.RectMode,
};

pub const TexturedVertex = struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    color: ui.Color,
};

pub const TexturedQuad = struct {
    bounds: ui.Rect,
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    color: ui.Color,
};

pub const IconInstance = struct {
    bounds: ui.Rect,
    color: ui.Color,
    icon_id: u32,
};

pub const RgbaTexture = struct {
    width: usize,
    height: usize,
    pixels: []const ui.Color,

    pub fn valid(self: RgbaTexture) bool {
        return self.width != 0 and self.height != 0 and self.pixels.len >= self.width * self.height;
    }
};

pub const IconOpIterator = icon_svg.Iterator;

pub fn iconOpIteratorForId(icon_id: u32) IconOpIterator {
    return icon_svg.Iterator.init(icon_svg.sourceForIconId(icon_id));
}

pub fn iconOpIteratorFromSource(source: []const u8) IconOpIterator {
    return icon_svg.Iterator.init(source);
}

pub const DrawBatch = union(enum) {
    rects: []const f32,
    image: []const f32,
    text: []const f32,
    icon: []const f32,
    icon_lines: []const f32,
    overlay_rects: []const f32,
    overlay_text: []const f32,
    overlay_icon: []const f32,
    overlay_icon_lines: []const f32,
};

pub const FontAtlas = struct {
    context: *anyopaque,
    metrics: *const fn (context: *anyopaque, px: u8) TextMetrics,
    width: *const fn (context: *anyopaque, value: []const u8, px: u8) f32,
    glyph: *const fn (context: *anyopaque, ch: u21, px: u8) Error!?Glyph,
};

pub fn commandAdapterFont(context: *anyopaque) FontAtlas {
    return .{
        .context = context,
        .metrics = commandAdapterFontMetrics,
        .width = commandAdapterTextWidth,
        .glyph = commandAdapterGlyph,
    };
}

pub const Sources = struct {
    font: FontAtlas,
};

pub const Buffers = struct {
    rects: []f32,
    rect_len: *usize,
    text_vertices: []f32,
    text_vertex_len: *usize,
    icon_vertices: []f32,
    icon_vertex_len: *usize,
    icon_line_vertices: []f32,
    icon_line_vertex_len: *usize,
    image_vertices: []f32,
    image_vertex_len: *usize,
    overlay_rects: []f32,
    overlay_rect_len: *usize,
    overlay_text_vertices: []f32,
    overlay_text_vertex_len: *usize,
    overlay_icon_vertices: []f32,
    overlay_icon_vertex_len: *usize,
    overlay_icon_line_vertices: []f32,
    overlay_icon_line_vertex_len: *usize,

    pub fn clearBase(self: Buffers) void {
        self.rect_len.* = 0;
        self.text_vertex_len.* = 0;
        self.icon_vertex_len.* = 0;
        self.icon_line_vertex_len.* = 0;
        self.image_vertex_len.* = 0;
    }

    pub fn clearOverlay(self: Buffers) void {
        self.overlay_rect_len.* = 0;
        self.overlay_text_vertex_len.* = 0;
        self.overlay_icon_vertex_len.* = 0;
        self.overlay_icon_line_vertex_len.* = 0;
    }

    pub fn liveRects(self: Buffers) []const f32 {
        return self.rects[0..self.rect_len.*];
    }

    pub fn liveTextVertices(self: Buffers) []const f32 {
        return self.text_vertices[0..self.text_vertex_len.*];
    }

    pub fn liveIconVertices(self: Buffers) []const f32 {
        return self.icon_vertices[0..self.icon_vertex_len.*];
    }

    pub fn liveIconLineVertices(self: Buffers) []const f32 {
        return self.icon_line_vertices[0..self.icon_line_vertex_len.*];
    }

    pub fn liveImageVertices(self: Buffers) []const f32 {
        return self.image_vertices[0..self.image_vertex_len.*];
    }

    pub fn liveOverlayRects(self: Buffers) []const f32 {
        return self.overlay_rects[0..self.overlay_rect_len.*];
    }

    pub fn liveOverlayTextVertices(self: Buffers) []const f32 {
        return self.overlay_text_vertices[0..self.overlay_text_vertex_len.*];
    }

    pub fn liveOverlayIconVertices(self: Buffers) []const f32 {
        return self.overlay_icon_vertices[0..self.overlay_icon_vertex_len.*];
    }

    pub fn liveOverlayIconLineVertices(self: Buffers) []const f32 {
        return self.overlay_icon_line_vertices[0..self.overlay_icon_line_vertex_len.*];
    }

    pub fn hasImageVertices(self: Buffers) bool {
        return self.image_vertex_len.* != 0;
    }

    pub fn hasTexturedVertices(self: Buffers) bool {
        return self.text_vertex_len.* != 0 or
            self.image_vertex_len.* != 0 or
            self.overlay_text_vertex_len.* != 0;
    }
};

pub fn validateBuffers(buffers: Buffers) Error!void {
    if (buffers.rect_len.* > buffers.rects.len or
        buffers.text_vertex_len.* > buffers.text_vertices.len or
        buffers.icon_vertex_len.* > buffers.icon_vertices.len or
        buffers.icon_line_vertex_len.* > buffers.icon_line_vertices.len or
        buffers.image_vertex_len.* > buffers.image_vertices.len or
        buffers.overlay_rect_len.* > buffers.overlay_rects.len or
        buffers.overlay_text_vertex_len.* > buffers.overlay_text_vertices.len or
        buffers.overlay_icon_vertex_len.* > buffers.overlay_icon_vertices.len or
        buffers.overlay_icon_line_vertex_len.* > buffers.overlay_icon_line_vertices.len)
    {
        return error.InvalidBuffer;
    }
}

pub fn drawBatches(buffers: Buffers) [9]DrawBatch {
    return .{
        .{ .rects = buffers.liveRects() },
        .{ .image = buffers.liveImageVertices() },
        .{ .text = buffers.liveTextVertices() },
        .{ .icon = buffers.liveIconVertices() },
        .{ .icon_lines = buffers.liveIconLineVertices() },
        .{ .overlay_rects = buffers.liveOverlayRects() },
        .{ .overlay_text = buffers.liveOverlayTextVertices() },
        .{ .overlay_icon = buffers.liveOverlayIconVertices() },
        .{ .overlay_icon_lines = buffers.liveOverlayIconLineVertices() },
    };
}

pub fn batchValues(batch: DrawBatch) []const f32 {
    return switch (batch) {
        .rects,
        .image,
        .text,
        .icon,
        .icon_lines,
        .overlay_rects,
        .overlay_text,
        .overlay_icon,
        .overlay_icon_lines,
        => |values| values,
    };
}

pub fn FixedBuffers(
    comptime rect_instances: usize,
    comptime text_vertices_count: usize,
    comptime icon_vertices_count: usize,
    comptime image_vertices_count: usize,
    comptime overlay_rect_instances: usize,
    comptime overlay_text_vertices_count: usize,
    comptime overlay_icon_vertices_count: usize,
    comptime icon_line_vertices_count: usize,
    comptime overlay_icon_line_vertices_count: usize,
) type {
    return struct {
        rects: [rect_instances * rect_float_stride]f32 = undefined,
        text_vertices: [text_vertices_count * text_vertex_float_stride]f32 = undefined,
        icon_vertices: [icon_vertices_count * icon_instance_float_stride]f32 = undefined,
        icon_line_vertices: [icon_line_vertices_count * icon_line_vertex_float_stride]f32 = undefined,
        image_vertices: [image_vertices_count * image_vertex_float_stride]f32 = undefined,
        overlay_rects: [overlay_rect_instances * rect_float_stride]f32 = undefined,
        overlay_text_vertices: [overlay_text_vertices_count * text_vertex_float_stride]f32 = undefined,
        overlay_icon_vertices: [overlay_icon_vertices_count * icon_instance_float_stride]f32 = undefined,
        overlay_icon_line_vertices: [overlay_icon_line_vertices_count * icon_line_vertex_float_stride]f32 = undefined,
        rect_len: usize = 0,
        text_vertex_len: usize = 0,
        icon_vertex_len: usize = 0,
        icon_line_vertex_len: usize = 0,
        image_vertex_len: usize = 0,
        overlay_rect_len: usize = 0,
        overlay_text_vertex_len: usize = 0,
        overlay_icon_vertex_len: usize = 0,
        overlay_icon_line_vertex_len: usize = 0,

        pub fn buffers(self: *@This()) Buffers {
            return .{
                .rects = &self.rects,
                .rect_len = &self.rect_len,
                .text_vertices = &self.text_vertices,
                .text_vertex_len = &self.text_vertex_len,
                .icon_vertices = &self.icon_vertices,
                .icon_vertex_len = &self.icon_vertex_len,
                .icon_line_vertices = &self.icon_line_vertices,
                .icon_line_vertex_len = &self.icon_line_vertex_len,
                .image_vertices = &self.image_vertices,
                .image_vertex_len = &self.image_vertex_len,
                .overlay_rects = &self.overlay_rects,
                .overlay_rect_len = &self.overlay_rect_len,
                .overlay_text_vertices = &self.overlay_text_vertices,
                .overlay_text_vertex_len = &self.overlay_text_vertex_len,
                .overlay_icon_vertices = &self.overlay_icon_vertices,
                .overlay_icon_vertex_len = &self.overlay_icon_vertex_len,
                .overlay_icon_line_vertices = &self.overlay_icon_line_vertices,
                .overlay_icon_line_vertex_len = &self.overlay_icon_line_vertex_len,
            };
        }
    };
}

pub fn packScene(buffers: Buffers, sources: Sources, scene_commands: []const ui.Command) Error!void {
    buffers.clearBase();
    buffers.clearOverlay();
    try packSceneRange(buffers, sources, scene_commands, .base);
}

pub fn packSceneWithOverlay(buffers: Buffers, sources: Sources, scene_commands: []const ui.Command, overlay_start: usize) Error!void {
    buffers.clearBase();
    buffers.clearOverlay();
    try packSceneRange(buffers, sources, scene_commands[0..overlay_start], .base);
    try packSceneRange(buffers, sources, scene_commands[overlay_start..], .overlay);
}

pub fn packSceneRange(buffers: Buffers, sources: Sources, scene_commands: []const ui.Command, layer: Layer) Error!void {
    for (scene_commands) |command| switch (command) {
        .rect => |rect| try pushRect(buffers, layer, rect.bounds, rect.color, rect.color2, rect.radius, rect.shadow, rectModeCode(rect.mode)),
        .border => |border| try pushRect(buffers, layer, border.bounds, border.color, .clear, 0, 0, rectModeCode(.border)),
        .text => |text_command| try pushText(buffers, sources.font, layer, text_command.origin, text_command.value, text_command.color, text_command.alignment),
        .icon_quad => |quad| try pushIcon(buffers, layer, quad),
        .image_quad => |quad| if (layer == .base) try pushImage(buffers, quad),
        .drag_source, .drop_target, .text_quad, .transition => {},
    };
}

pub fn pushRect(buffers: Buffers, layer: Layer, bounds: ui.Rect, color: ui.Color, color2: ui.Color, radius: f32, shadow: f32, mode: f32) Error!void {
    if (!bounds.valid()) return;
    const buffer = switch (layer) {
        .base => buffers.rects,
        .overlay => buffers.overlay_rects,
    };
    const len = switch (layer) {
        .base => buffers.rect_len,
        .overlay => buffers.overlay_rect_len,
    };
    if (len.* + rect_float_stride > buffer.len) return error.Budget;
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
    @memcpy(buffer[len.* .. len.* + rect_float_stride], &values);
    len.* += rect_float_stride;
}

pub fn pushText(buffers: Buffers, font: FontAtlas, layer: Layer, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) Error!void {
    if (value.len == 0 or !bounds.valid()) return;
    const buffer = switch (layer) {
        .base => buffers.text_vertices,
        .overlay => buffers.overlay_text_vertices,
    };
    const len = switch (layer) {
        .base => buffers.text_vertex_len,
        .overlay => buffers.overlay_text_vertex_len,
    };
    const px = textPx(bounds.h);
    var pen_x = bounds.x + textAlignOffset(font, value, px, bounds.w, alignment);
    const metrics_value = font.metrics(font.context, px);
    const baseline = bounds.y + metrics_value.ascender;
    const clip = textClipBounds(bounds, metrics_value);
    var index: usize = 0;
    while (ui.nextCodepoint(value, &index)) |codepoint| {
        const glyph_value = (try font.glyph(font.context, codepoint, px)) orelse continue;
        if (glyph_value.w > 0.0 and glyph_value.h > 0.0) {
            const quad = snapGlyphQuad(pen_x + glyph_value.left, baseline + glyph_value.top, glyph_value.w, glyph_value.h);
            try pushClippedTexturedQuad(buffer, len, clip, quad, glyph_value.u0, glyph_value.v0, glyph_value.u1, glyph_value.v1, color);
        }
        pen_x += glyph_value.advance;
        if (pen_x > bounds.x + bounds.w) break;
    }
}

pub fn pushIcon(buffers: Buffers, layer: Layer, quad: ui.IconQuad) Error!void {
    if (!quad.bounds.valid() or quad.icon_id == 0) return;
    const buffer = switch (layer) {
        .base => buffers.icon_vertices,
        .overlay => buffers.overlay_icon_vertices,
    };
    const len = switch (layer) {
        .base => buffers.icon_vertex_len,
        .overlay => buffers.overlay_icon_vertex_len,
    };
    if (len.* + icon_instance_float_stride > buffer.len) return error.Budget;
    const values = [_]f32{
        quad.bounds.x,
        quad.bounds.y,
        quad.bounds.w,
        quad.bounds.h,
        channel(quad.color.r),
        channel(quad.color.g),
        channel(quad.color.b),
        channel(quad.color.a),
        @floatFromInt(quad.icon_id),
    };
    @memcpy(buffer[len.* .. len.* + icon_instance_float_stride], &values);
    len.* += icon_instance_float_stride;
}

pub fn pushImage(buffers: Buffers, quad: ui.Quad) Error!void {
    if (!quad.bounds.valid() or quad.atlas_id == 0) return;
    try pushClippedTexturedQuad(buffers.image_vertices, buffers.image_vertex_len, quad.bounds, quad.bounds, quad.u0, quad.v0, quad.u1, quad.v1, quad.color);
}

pub fn pushClippedTexturedQuad(buffer: []f32, len: *usize, clip: ui.Rect, bounds: ui.Rect, tex_u0: f32, tex_v0: f32, tex_u1: f32, tex_v1: f32, color: ui.Color) Error!void {
    const clipped = bounds.intersect(clip) orelse return;
    if (len.* + text_vertex_float_stride * textured_quad_vertex_count > buffer.len) return error.Budget;
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

pub fn pushTexturedVertex(buffer: []f32, len: *usize, x: f32, y: f32, u: f32, v: f32, color: ui.Color) void {
    const values = [_]f32{ x, y, u, v, channel(color.r), channel(color.g), channel(color.b), channel(color.a) };
    @memcpy(buffer[len.* .. len.* + text_vertex_float_stride], &values);
    len.* += text_vertex_float_stride;
}

pub fn textPx(height: f32) u8 {
    return @intFromFloat(@round(math.clampF(height, @as(f32, @floatFromInt(font_first_px)), @as(f32, @floatFromInt(font_last_px)))));
}

pub fn rectModeCode(mode: ui.RectMode) f32 {
    return switch (mode) {
        .fill => rect_mode_fill,
        .shadow => rect_mode_shadow,
        .border => rect_mode_border,
        .linear_gradient => rect_mode_linear_gradient,
        .pie_slice => rect_mode_pie_slice,
    };
}

pub fn rectCount(values: []const f32) Error!usize {
    if (values.len % rect_float_stride != 0) return error.InvalidBuffer;
    return values.len / rect_float_stride;
}

pub fn rectAt(values: []const f32, index: usize) Error!RectInstance {
    const count = try rectCount(values);
    if (index >= count) return error.InvalidBuffer;
    const start = index * rect_float_stride;
    const rect = values[start .. start + rect_float_stride];
    return .{
        .bounds = ui.Rect.init(rect[rect_x_index], rect[rect_y_index], rect[rect_w_index], rect[rect_h_index]),
        .color = colorFromChannels(rect[rect_color_r_index], rect[rect_color_g_index], rect[rect_color_b_index], rect[rect_color_a_index]),
        .color2 = colorFromChannels(rect[rect_color2_r_index], rect[rect_color2_g_index], rect[rect_color2_b_index], rect[rect_color2_a_index]),
        .radius = rect[rect_radius_index],
        .shadow = rect[rect_shadow_index],
        .mode = try rectModeFromCode(rect[rect_mode_index]),
    };
}

pub const RectIterator = struct {
    values: []const f32,
    index: usize,
    count: usize,

    pub fn init(values: []const f32) Error!RectIterator {
        return .{
            .values = values,
            .index = 0,
            .count = try rectCount(values),
        };
    }

    pub fn next(self: *RectIterator) Error!?RectInstance {
        if (self.index >= self.count) return null;
        const rect = try rectAt(self.values, self.index);
        self.index += 1;
        return rect;
    }
};

pub fn texturedVertexCount(values: []const f32) Error!usize {
    if (values.len % text_vertex_float_stride != 0) return error.InvalidBuffer;
    return values.len / text_vertex_float_stride;
}

pub fn primitiveCount(buffers: Buffers) Error!usize {
    var count: usize = 0;
    for (drawBatches(buffers)) |batch| {
        count += try batchPrimitiveCount(batch);
    }
    return count;
}

pub fn batchPrimitiveCount(batch: DrawBatch) Error!usize {
    return switch (batch) {
        .rects, .overlay_rects => |rects| rectCount(rects),
        .image, .text, .overlay_text => |vertices| texturedQuadCount(vertices),
        .icon, .overlay_icon => |instances| iconCount(instances),
        .icon_lines, .overlay_icon_lines => 0,
    };
}

pub fn iconCount(values: []const f32) Error!usize {
    if (values.len % icon_instance_float_stride != 0) return error.InvalidBuffer;
    return values.len / icon_instance_float_stride;
}

pub fn texturedQuadCount(values: []const f32) Error!usize {
    const vertex_count = try texturedVertexCount(values);
    if (vertex_count % textured_quad_vertex_count != 0) return error.InvalidBuffer;
    return vertex_count / textured_quad_vertex_count;
}

pub fn texturedVertexAt(values: []const f32, index: usize) Error!TexturedVertex {
    const count = try texturedVertexCount(values);
    if (index >= count) return error.InvalidBuffer;
    const start = index * text_vertex_float_stride;
    const vertex = values[start .. start + text_vertex_float_stride];
    return .{
        .x = vertex[textured_x_index],
        .y = vertex[textured_y_index],
        .u = vertex[textured_u_index],
        .v = vertex[textured_v_index],
        .color = colorFromChannels(vertex[textured_color_r_index], vertex[textured_color_g_index], vertex[textured_color_b_index], vertex[textured_color_a_index]),
    };
}

pub fn iconAt(values: []const f32, index: usize) Error!IconInstance {
    const count = try iconCount(values);
    if (index >= count) return error.InvalidBuffer;
    const start = index * icon_instance_float_stride;
    const instance = values[start .. start + icon_instance_float_stride];
    return .{
        .bounds = ui.Rect.init(
            instance[icon_x_index],
            instance[icon_y_index],
            instance[icon_w_index],
            instance[icon_h_index],
        ),
        .color = .{
            .r = byteFromChannel(instance[icon_color_r_index]),
            .g = byteFromChannel(instance[icon_color_g_index]),
            .b = byteFromChannel(instance[icon_color_b_index]),
            .a = byteFromChannel(instance[icon_color_a_index]),
        },
        .icon_id = @intFromFloat(instance[icon_id_index]),
    };
}

pub const IconIterator = struct {
    values: []const f32,
    index: usize = 0,
    count: usize,

    pub fn init(values: []const f32) Error!IconIterator {
        return .{
            .values = values,
            .count = try iconCount(values),
        };
    }

    pub fn next(self: *IconIterator) Error!?IconInstance {
        if (self.index >= self.count) return null;
        const icon_value = try iconAt(self.values, self.index);
        self.index += 1;
        return icon_value;
    }
};

pub fn texturedQuadAt(values: []const f32, index: usize) Error!TexturedQuad {
    const count = try texturedVertexCount(values);
    if (index > count or count - index < textured_quad_vertex_count) return error.InvalidBuffer;
    return texturedQuadAtUnchecked(values, index);
}

fn texturedQuadAtUnchecked(values: []const f32, index: usize) Error!TexturedQuad {
    const a = texturedVertexAtUnchecked(values, index);
    const b = texturedVertexAtUnchecked(values, index + 1);
    const c = texturedVertexAtUnchecked(values, index + 2);
    const f = texturedVertexAtUnchecked(values, index + 5);
    const x0 = @min(@min(a.x, b.x), @min(c.x, f.x));
    const y0 = @min(@min(a.y, b.y), @min(c.y, f.y));
    const x1 = @max(@max(a.x, b.x), @max(c.x, f.x));
    const y1 = @max(@max(a.y, b.y), @max(c.y, f.y));
    const min_u = @min(@min(a.u, b.u), @min(c.u, f.u));
    const min_v = @min(@min(a.v, b.v), @min(c.v, f.v));
    const max_u = @max(@max(a.u, b.u), @max(c.u, f.u));
    const max_v = @max(@max(a.v, b.v), @max(c.v, f.v));
    const bounds = ui.Rect.init(x0, y0, x1 - x0, y1 - y0);
    if (!bounds.valid()) return error.InvalidBuffer;
    return .{
        .bounds = bounds,
        .u0 = min_u,
        .v0 = min_v,
        .u1 = max_u,
        .v1 = max_v,
        .color = a.color,
    };
}

fn texturedVertexAtUnchecked(values: []const f32, index: usize) TexturedVertex {
    const start = index * text_vertex_float_stride;
    const vertex = values[start .. start + text_vertex_float_stride];
    return .{
        .x = vertex[textured_x_index],
        .y = vertex[textured_y_index],
        .u = vertex[textured_u_index],
        .v = vertex[textured_v_index],
        .color = colorFromChannels(vertex[textured_color_r_index], vertex[textured_color_g_index], vertex[textured_color_b_index], vertex[textured_color_a_index]),
    };
}

pub const TexturedQuadIterator = struct {
    values: []const f32,
    quad_index: usize,
    quad_count: usize,

    pub fn init(values: []const f32) Error!TexturedQuadIterator {
        return .{
            .values = values,
            .quad_index = 0,
            .quad_count = try texturedQuadCount(values),
        };
    }

    pub fn next(self: *TexturedQuadIterator) Error!?TexturedQuad {
        if (self.quad_index >= self.quad_count) return null;
        const vertex_index = self.quad_index * textured_quad_vertex_count;
        const quad = try texturedQuadAtUnchecked(self.values, vertex_index);
        self.quad_index += 1;
        return quad;
    }
};

fn snapGlyphQuad(x: f32, y: f32, w: f32, h: f32) ui.Rect {
    const left = @round(x);
    const top = @round(y);
    const right = @max(left + 1.0, @round(x + w));
    const bottom = @max(top + 1.0, @round(y + h));
    return ui.Rect.init(left, top, right - left, bottom - top);
}

fn textClipBounds(bounds: ui.Rect, metrics_value: TextMetrics) ui.Rect {
    const top_extra = @max(0.0, metrics_value.ascender - bounds.h);
    const bottom_extra = @max(0.0, -metrics_value.descender);
    return ui.Rect.init(bounds.x - glyph_clip_pad, bounds.y - top_extra, bounds.w + glyph_clip_pad * 2.0, bounds.h + top_extra + bottom_extra);
}

const glyph_clip_pad: f32 = 2.0;

fn textAlignOffset(font: FontAtlas, value: []const u8, px: u8, width: f32, alignment: ui.TextAlign) f32 {
    const measured = font.width(font.context, value, px);
    return switch (alignment) {
        .start => 0.0,
        .center => @max(0.0, (width - measured) * 0.5),
        .end => @max(0.0, width - measured),
    };
}

fn channel(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn colorFromChannels(r: f32, g: f32, b: f32, a: f32) ui.Color {
    return .{
        .r = byteFromChannel(r),
        .g = byteFromChannel(g),
        .b = byteFromChannel(b),
        .a = byteFromChannel(a),
    };
}

fn byteFromChannel(value: f32) u8 {
    return @intFromFloat(@round(math.clampF(value, 0.0, 1.0) * 255.0));
}

fn rectModeFromCode(code: f32) Error!ui.RectMode {
    const rounded: u8 = @intFromFloat(@round(code));
    return switch (rounded) {
        rect_mode_fill => .fill,
        rect_mode_shadow => .shadow,
        rect_mode_border => .border,
        rect_mode_linear_gradient => .linear_gradient,
        rect_mode_pie_slice => .pie_slice,
        else => error.InvalidBuffer,
    };
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

const command_adapter_ascender: f32 = 10.0;
const command_adapter_descender: f32 = -3.0;
const command_adapter_glyph_width: f32 = 6.0;
const command_adapter_glyph_height: f32 = 9.0;
const command_adapter_glyph_left: f32 = 1.0;
const command_adapter_glyph_top: f32 = -8.0;
const command_adapter_advance: f32 = 8.0;

fn commandAdapterFontMetrics(_: *anyopaque, _: u8) TextMetrics {
    return .{ .ascender = command_adapter_ascender, .descender = command_adapter_descender };
}

fn commandAdapterTextWidth(_: *anyopaque, value: []const u8, _: u8) f32 {
    return @as(f32, @floatFromInt(ui.utf8CodepointCount(value))) * command_adapter_advance;
}

fn commandAdapterGlyph(_: *anyopaque, ch: u21, _: u8) Error!?Glyph {
    if (ch == ' ') return null;
    return .{
        .u0 = 0.0,
        .v0 = 0.0,
        .u1 = 1.0,
        .v1 = 1.0,
        .w = command_adapter_glyph_width,
        .h = command_adapter_glyph_height,
        .left = command_adapter_glyph_left,
        .top = command_adapter_glyph_top,
        .advance = command_adapter_advance,
    };
}

fn testFontMetrics(_: *anyopaque, _: u8) TextMetrics {
    return .{ .ascender = 10.0, .descender = -3.0 };
}

fn testTextWidth(_: *anyopaque, value: []const u8, _: u8) f32 {
    return @as(f32, @floatFromInt(ui.utf8CodepointCount(value))) * 8.0;
}

fn testGlyph(_: *anyopaque, ch: u21, _: u8) Error!?Glyph {
    if (ch == ' ') return null;
    return .{
        .u0 = 0.0,
        .v0 = 0.0,
        .u1 = 0.5,
        .v1 = 0.5,
        .w = 6.0,
        .h = 9.0,
        .left = 1.0,
        .top = -8.0,
        .advance = 8.0,
    };
}

fn overhangTestGlyph(_: *anyopaque, ch: u21, _: u8) Error!?Glyph {
    if (ch == ' ') return null;
    return .{
        .u0 = 0.0,
        .v0 = 0.0,
        .u1 = 0.5,
        .v1 = 0.5,
        .w = 8.0,
        .h = 9.0,
        .left = -3.0,
        .top = -8.0,
        .advance = 8.0,
    };
}

fn expectSourceDoesNotContain(source: []const u8, needle: []const u8) !void {
    try std.testing.expectEqual(@as(?usize, null), std.mem.indexOf(u8, source, needle));
}

test "renderer ir owns svg source lookup and command painting boundaries" {
    try expectSourceDoesNotContain(@embedFile("backends/software.zig"), "@import(\"icon_svg.zig\")");
    try expectSourceDoesNotContain(@embedFile("icon_line_buffer.zig"), "@import(\"icon_svg.zig\")");
    try expectSourceDoesNotContain(@embedFile("backends/gles.zig"), "dataForIconId");
    try expectSourceDoesNotContain(@embedFile("backends/software.zig"), "sourceForIconId");
    try expectSourceDoesNotContain(@embedFile("icon_line_buffer.zig"), "sourceForIconId");
    try expectSourceDoesNotContain(@embedFile("../wayland_window_host.zig"), ".rasterize(scene.written())");
    try expectSourceDoesNotContain(@embedFile("compositor.zig"), ".rasterize(scene.written())");
    try expectSourceDoesNotContain(@embedFile("../app_runtime.zig"), "renderer_ir.packScene(");
    try expectSourceDoesNotContain(@embedFile("../wayland_window_host.zig"), "renderer_ir.packScene(");
    try expectSourceDoesNotContain(@embedFile("../wayland_egl_host.zig"), "renderer_ir.packScene(");
    try expectSourceDoesNotContain(@embedFile("../drm_gbm_host.zig"), "renderer_ir.packScene(");
    try expectSourceDoesNotContain(@embedFile("../app_runtime.zig"), "renderer_present.present(");
}

test "renderer ir publishes packed frame field layout" {
    try std.testing.expectEqual(@as(usize, 15), rect_float_stride);
    try std.testing.expectEqual(rect_float_stride - 1, rect_mode_index);
    try std.testing.expectEqual(@as(u8, 0), rect_mode_fill);
    try std.testing.expectEqual(@as(u8, 1), rect_mode_shadow);
    try std.testing.expectEqual(@as(u8, 2), rect_mode_border);
    try std.testing.expectEqual(@as(u8, 3), rect_mode_linear_gradient);
    try std.testing.expectEqual(@as(u8, 4), rect_mode_pie_slice);
    try std.testing.expectEqual(@as(usize, 8), text_vertex_float_stride);
    try std.testing.expectEqual(text_vertex_float_stride - 1, textured_color_a_index);
    try std.testing.expectEqual(@as(usize, 9), icon_instance_float_stride);
    try std.testing.expectEqual(icon_instance_float_stride - 1, icon_id_index);
}

test "renderer backends stay behind adapter imports" {
    const backend_import = "render/backends/";
    try expectSourceDoesNotContain(@embedFile("../root.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../ui_core_test.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../app_runtime.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../wayland_window_host.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../wayland_egl_host.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../drm_gbm_host.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../app_images.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../ui_bench.zig"), backend_import);
    try expectSourceDoesNotContain(@embedFile("../ui_snapshot.zig"), backend_import);
}

test "renderer ir packs scene primitives into canonical buffers" {
    var rects: [rect_float_stride * 4]f32 = undefined;
    var text_vertices: [text_vertex_float_stride * textured_quad_vertex_count * 8]f32 = undefined;
    var icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var image_vertices: [image_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_rects: [rect_float_stride]f32 = undefined;
    var overlay_text_vertices: [text_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var overlay_icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var rect_len: usize = 77;
    var text_vertex_len: usize = 77;
    var icon_vertex_len: usize = 77;
    var icon_line_vertex_len: usize = 77;
    var image_vertex_len: usize = 77;
    var overlay_rect_len: usize = 77;
    var overlay_text_vertex_len: usize = 77;
    var overlay_icon_vertex_len: usize = 77;
    var overlay_icon_line_vertex_len: usize = 77;
    const buffers = Buffers{
        .rects = &rects,
        .rect_len = &rect_len,
        .text_vertices = &text_vertices,
        .text_vertex_len = &text_vertex_len,
        .icon_vertices = &icon_vertices,
        .icon_vertex_len = &icon_vertex_len,
        .icon_line_vertices = &icon_line_vertices,
        .icon_line_vertex_len = &icon_line_vertex_len,
        .image_vertices = &image_vertices,
        .image_vertex_len = &image_vertex_len,
        .overlay_rects = &overlay_rects,
        .overlay_rect_len = &overlay_rect_len,
        .overlay_text_vertices = &overlay_text_vertices,
        .overlay_text_vertex_len = &overlay_text_vertex_len,
        .overlay_icon_vertices = &overlay_icon_vertices,
        .overlay_icon_vertex_len = &overlay_icon_vertex_len,
        .overlay_icon_line_vertices = &overlay_icon_line_vertices,
        .overlay_icon_line_vertex_len = &overlay_icon_line_vertex_len,
    };
    var source_context: u8 = 0;
    const sources = Sources{
        .font = .{ .context = &source_context, .metrics = testFontMetrics, .width = testTextWidth, .glyph = testGlyph },
    };

    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(1, 2, 30, 40), .accent, .linear_gradient, 4, 0);
    try scene.pushAlignedText(ui.Rect.init(4, 6, 80, 16), "IR", .text, .start);
    try scene.pushIconQuad(.{ .bounds = ui.Rect.init(8, 10, 12, 12), .color = .text, .icon_id = 1 });

    try packScene(buffers, sources, scene.written());

    try std.testing.expectEqual(rect_float_stride, rect_len);
    try std.testing.expectEqual(text_vertex_float_stride * textured_quad_vertex_count * 2, text_vertex_len);
    try std.testing.expectEqual(icon_instance_float_stride, icon_vertex_len);
    try std.testing.expectEqual(@as(usize, 0), image_vertex_len);
    try std.testing.expectEqual(@as(usize, 0), overlay_rect_len);
    try std.testing.expectEqual(@as(usize, 0), overlay_text_vertex_len);
    try std.testing.expectEqual(@as(usize, 0), overlay_icon_vertex_len);
    try std.testing.expectEqual(@as(f32, 1.0), rects[0]);
    try std.testing.expectEqual(rectModeCode(.linear_gradient), rects[rect_float_stride - 1]);
    const first_rect = try rectAt(rects[0..rect_len], 0);
    try std.testing.expectEqual(ui.RectMode.linear_gradient, first_rect.mode);
    try std.testing.expectEqual(ui.Rect.init(1, 2, 30, 40), first_rect.bounds);
    try std.testing.expectEqual(ui.Color.accent, first_rect.color);
    const first_text_vertex = try texturedVertexAt(text_vertices[0..text_vertex_len], 0);
    try std.testing.expectEqual(ui.Color.text, first_text_vertex.color);
    try std.testing.expect(first_text_vertex.u >= 0.0);
    try std.testing.expect(first_text_vertex.v >= 0.0);
    const first_icon = try iconAt(icon_vertices[0..icon_vertex_len], 0);
    try std.testing.expectEqual(ui.Rect.init(8, 10, 12, 12), first_icon.bounds);
    try std.testing.expectEqual(ui.Color.text, first_icon.color);
    try std.testing.expectEqual(@as(u32, 1), first_icon.icon_id);
}

test "renderer ir fixed buffers expose writable canonical buffer view" {
    var storage = FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try pushRect(buffers, .base, ui.Rect.init(1, 2, 3, 4), .accent, .clear, 0, 0, rectModeCode(.fill));
    try std.testing.expectEqual(rect_float_stride, storage.rect_len);
    try std.testing.expectEqual(@as(usize, 0), storage.text_vertex_len);
    try std.testing.expect(!buffers.hasTexturedVertices());
    try std.testing.expect(!buffers.hasImageVertices());
    try std.testing.expectEqual(@as(usize, 1), try primitiveCount(buffers));
    const rect = try rectAt(storage.rects[0..storage.rect_len], 0);
    try std.testing.expectEqual(ui.Color.accent, rect.color);
}

test "renderer ir text clip preserves glyph side bearings" {
    var storage = FixedBuffers(0, textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var source_context: u8 = 0;

    try pushText(buffers, .{ .context = &source_context, .metrics = testFontMetrics, .width = testTextWidth, .glyph = overhangTestGlyph }, .base, ui.Rect.init(10, 4, 40, 16), "T", .text, .start);

    try std.testing.expectEqual(text_vertex_float_stride * textured_quad_vertex_count, storage.text_vertex_len);
    try std.testing.expectEqual(@as(f32, 8.0), storage.text_vertices[textured_x_index]);
}

test "renderer ir text rendering iterates utf8 codepoints" {
    var storage = FixedBuffers(0, textured_quad_vertex_count * 3, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var source_context: u8 = 0;
    const sources = Sources{
        .font = .{
            .context = &source_context,
            .metrics = testFontMetrics,
            .width = testTextWidth,
            .glyph = testGlyph,
        },
    };

    try pushText(
        buffers,
        sources.font,
        .base,
        ui.Rect.init(0, 0, 120, 16),
        "AéB",
        .text,
        .start,
    );

    try std.testing.expectEqual(text_vertex_float_stride * textured_quad_vertex_count * 3, storage.text_vertex_len);
}

test "renderer ir iterates rects and textured quads" {
    var storage = FixedBuffers(2, 0, 0, textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try pushRect(buffers, .base, ui.Rect.init(1, 2, 3, 4), .accent, .clear, 0, 0, rectModeCode(.fill));
    try pushRect(buffers, .base, ui.Rect.init(5, 6, 7, 8), .text, .clear, 0, 0, rectModeCode(.border));
    try pushImage(buffers, .{
        .bounds = ui.Rect.init(9, 10, 11, 12),
        .u0 = 0.25,
        .v0 = 0.5,
        .u1 = 0.75,
        .v1 = 1.0,
        .atlas_id = 1,
        .color = .muted,
    });

    var rect_iter = try RectIterator.init(buffers.liveRects());
    const first_rect = (try rect_iter.next()).?;
    const second_rect = (try rect_iter.next()).?;
    try std.testing.expectEqual(ui.Rect.init(1, 2, 3, 4), first_rect.bounds);
    try std.testing.expectEqual(ui.RectMode.border, second_rect.mode);
    try std.testing.expectEqual(@as(?RectInstance, null), try rect_iter.next());

    var quad_iter = try TexturedQuadIterator.init(buffers.liveImageVertices());
    const image_quad = (try quad_iter.next()).?;
    try std.testing.expectEqual(ui.Rect.init(9, 10, 11, 12), image_quad.bounds);
    try std.testing.expectEqual(ui.Color.muted, image_quad.color);
    try std.testing.expectEqual(@as(?TexturedQuad, null), try quad_iter.next());

    try std.testing.expectError(error.InvalidBuffer, texturedQuadAt(buffers.liveImageVertices()[0..text_vertex_float_stride], 0));
    try std.testing.expectError(error.InvalidBuffer, TexturedQuadIterator.init(buffers.liveImageVertices()[0..text_vertex_float_stride]));
}

test "renderer ir owns canonical draw batch order" {
    var storage = FixedBuffers(1, textured_quad_vertex_count, 1, textured_quad_vertex_count, 1, textured_quad_vertex_count, 1, 1, 1){};
    const batches = drawBatches(storage.buffers());
    try std.testing.expectEqual(@as(usize, 9), batches.len);
    try std.testing.expectEqual(DrawBatch{ .rects = storage.rects[0..0] }, batches[0]);
    try std.testing.expectEqual(DrawBatch{ .image = storage.image_vertices[0..0] }, batches[1]);
    try std.testing.expectEqual(DrawBatch{ .text = storage.text_vertices[0..0] }, batches[2]);
    try std.testing.expectEqual(DrawBatch{ .icon = storage.icon_vertices[0..0] }, batches[3]);
    try std.testing.expectEqual(DrawBatch{ .icon_lines = storage.icon_line_vertices[0..0] }, batches[4]);
    try std.testing.expectEqual(DrawBatch{ .overlay_rects = storage.overlay_rects[0..0] }, batches[5]);
    try std.testing.expectEqual(DrawBatch{ .overlay_text = storage.overlay_text_vertices[0..0] }, batches[6]);
    try std.testing.expectEqual(DrawBatch{ .overlay_icon = storage.overlay_icon_vertices[0..0] }, batches[7]);
    try std.testing.expectEqual(DrawBatch{ .overlay_icon_lines = storage.overlay_icon_line_vertices[0..0] }, batches[8]);
    try std.testing.expectEqual(storage.image_vertices[0..0], batchValues(batches[1]));
}

test "renderer ir counts primitives from draw batches" {
    var storage = FixedBuffers(2, textured_quad_vertex_count, 0, textured_quad_vertex_count, 1, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try pushRect(buffers, .base, ui.Rect.init(1, 2, 3, 4), .accent, .clear, 0, 0, rectModeCode(.fill));
    try pushRect(buffers, .base, ui.Rect.init(5, 6, 7, 8), .text, .clear, 0, 0, rectModeCode(.border));
    try pushImage(buffers, .{
        .bounds = ui.Rect.init(9, 10, 11, 12),
        .atlas_id = 1,
        .color = .muted,
    });
    try pushClippedTexturedQuad(
        buffers.text_vertices,
        buffers.text_vertex_len,
        ui.Rect.init(0, 0, 100, 100),
        ui.Rect.init(13, 14, 15, 16),
        0.0,
        0.0,
        1.0,
        1.0,
        .text,
    );
    try pushRect(buffers, .overlay, ui.Rect.init(17, 18, 19, 20), .panel, .clear, 0, 0, rectModeCode(.fill));

    var counted: usize = 0;
    for (drawBatches(buffers)) |batch| counted += try batchPrimitiveCount(batch);
    try std.testing.expectEqual(@as(usize, 5), counted);
    try std.testing.expectEqual(counted, try primitiveCount(buffers));
}

test "renderer ir validates live buffer lengths before slicing" {
    var storage = FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    storage.rect_len = storage.rects.len + 1;
    try std.testing.expectError(error.InvalidBuffer, validateBuffers(buffers));
}

test "renderer ir separates overlay commands from base buffers" {
    var rects: [rect_float_stride]f32 = undefined;
    var text_vertices: [text_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var image_vertices: [image_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_rects: [rect_float_stride]f32 = undefined;
    var overlay_text_vertices: [text_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var overlay_icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var rect_len: usize = 0;
    var text_vertex_len: usize = 0;
    var icon_vertex_len: usize = 0;
    var icon_line_vertex_len: usize = 0;
    var image_vertex_len: usize = 0;
    var overlay_rect_len: usize = 0;
    var overlay_text_vertex_len: usize = 0;
    var overlay_icon_vertex_len: usize = 0;
    var overlay_icon_line_vertex_len: usize = 0;
    const buffers = Buffers{
        .rects = &rects,
        .rect_len = &rect_len,
        .text_vertices = &text_vertices,
        .text_vertex_len = &text_vertex_len,
        .icon_vertices = &icon_vertices,
        .icon_vertex_len = &icon_vertex_len,
        .icon_line_vertices = &icon_line_vertices,
        .icon_line_vertex_len = &icon_line_vertex_len,
        .image_vertices = &image_vertices,
        .image_vertex_len = &image_vertex_len,
        .overlay_rects = &overlay_rects,
        .overlay_rect_len = &overlay_rect_len,
        .overlay_text_vertices = &overlay_text_vertices,
        .overlay_text_vertex_len = &overlay_text_vertex_len,
        .overlay_icon_vertices = &overlay_icon_vertices,
        .overlay_icon_vertex_len = &overlay_icon_vertex_len,
        .overlay_icon_line_vertices = &overlay_icon_line_vertices,
        .overlay_icon_line_vertex_len = &overlay_icon_line_vertex_len,
    };
    var source_context: u8 = 0;
    const sources = Sources{
        .font = .{ .context = &source_context, .metrics = testFontMetrics, .width = testTextWidth, .glyph = testGlyph },
    };

    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(0, 0, 10, 10), .bg, .fill, 0, 0);
    try scene.pushRect(ui.Rect.init(0, 0, 20, 20), .text, .fill, 0, 0);

    try packSceneWithOverlay(buffers, sources, scene.written(), 1);

    try std.testing.expectEqual(rect_float_stride, rect_len);
    try std.testing.expectEqual(rect_float_stride, overlay_rect_len);
    try std.testing.expectEqual(@as(f32, 10.0), rects[2]);
    try std.testing.expectEqual(@as(f32, 20.0), overlay_rects[2]);
}

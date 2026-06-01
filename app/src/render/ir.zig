const std = @import("std");
const byte_utils = @import("../bytes.zig");
const math = @import("../math.zig");
const icon_vector = @import("../ui/icon_vector.zig");
const icon_pack = @import("../ui/icon_pack.zig");
const ui = @import("../ui/core.zig");

pub const rect_float_stride: usize = 15;
pub const text_vertex_float_stride: usize = 8;
pub const icon_instance_float_stride: usize = 9;
pub const icon_line_vertex_float_stride: usize = 6;
pub const image_vertex_float_stride: usize = 8;
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
pub const text_glyph_x_index: usize = 0;
pub const text_glyph_baseline_y_index: usize = 1;
pub const text_glyph_px_index: usize = 2;
pub const text_glyph_codepoint_weight_index: usize = 3;
pub const text_glyph_color_r_index: usize = 4;
pub const text_glyph_color_g_index: usize = 5;
pub const text_glyph_color_b_index: usize = 6;
pub const text_glyph_color_a_index: usize = 7;
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

pub const TextGlyph = struct {
    x: f32,
    baseline_y: f32,
    px: f32,
    codepoint: u21,
    weight: ui.FontWeight,
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

pub const IconOpIterator = icon_vector.Iterator;

pub fn iconOpIteratorForId(icon_id: u32) IconOpIterator {
    return icon_vector.Iterator.init(icon_pack.getIr(icon_id) orelse &.{});
}

pub fn iconOpIteratorFromSource(source: []const f32) IconOpIterator {
    return icon_vector.Iterator.init(source);
}

pub const DrawBatch = union(enum) {
    rects: []const f32,
    text: []const f32,
    overlay_text: []const f32,
    image: []const f32,
    svg: []const f32,
    icon_lines: []const f32,
    overlay_rects: []const f32,
    overlay_icon: []const f32,
    overlay_icon_lines: []const f32,
};

pub const Buffers = struct {
    rects: []f32,
    rect_len: *usize,
    icon_vertices: []f32,
    icon_vertex_len: *usize,
    icon_line_vertices: []f32,
    icon_line_vertex_len: *usize,
    text_vertices: []f32,
    text_vertex_len: *usize,
    overlay_text_vertices: []f32,
    overlay_text_vertex_len: *usize,
    image_vertices: []f32,
    image_vertex_len: *usize,
    overlay_rects: []f32,
    overlay_rect_len: *usize,
    overlay_icon_vertices: []f32,
    overlay_icon_vertex_len: *usize,
    overlay_icon_line_vertices: []f32,
    overlay_icon_line_vertex_len: *usize,

    pub fn clearBase(self: Buffers) void {
        self.rect_len.* = 0;
        self.icon_vertex_len.* = 0;
        self.icon_line_vertex_len.* = 0;
        self.text_vertex_len.* = 0;
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

    pub fn liveIconVertices(self: Buffers) []const f32 {
        return self.icon_vertices[0..self.icon_vertex_len.*];
    }

    pub fn liveIconLineVertices(self: Buffers) []const f32 {
        return self.icon_line_vertices[0..self.icon_line_vertex_len.*];
    }

    pub fn liveImageVertices(self: Buffers) []const f32 {
        return self.image_vertices[0..self.image_vertex_len.*];
    }

    pub fn liveTextVertices(self: Buffers) []const f32 {
        return self.text_vertices[0..self.text_vertex_len.*];
    }

    pub fn liveOverlayTextVertices(self: Buffers) []const f32 {
        return self.overlay_text_vertices[0..self.overlay_text_vertex_len.*];
    }

    pub fn liveOverlayRects(self: Buffers) []const f32 {
        return self.overlay_rects[0..self.overlay_rect_len.*];
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

    pub fn hasTextVertices(self: Buffers) bool {
        return self.text_vertex_len.* != 0;
    }
};

pub fn validateBuffers(buffers: Buffers) Error!void {
    if (buffers.rect_len.* > buffers.rects.len or
        buffers.icon_vertex_len.* > buffers.icon_vertices.len or
        buffers.icon_line_vertex_len.* > buffers.icon_line_vertices.len or
        buffers.text_vertex_len.* > buffers.text_vertices.len or
        buffers.overlay_text_vertex_len.* > buffers.overlay_text_vertices.len or
        buffers.image_vertex_len.* > buffers.image_vertices.len or
        buffers.overlay_rect_len.* > buffers.overlay_rects.len or
        buffers.overlay_icon_vertex_len.* > buffers.overlay_icon_vertices.len or
        buffers.overlay_icon_line_vertex_len.* > buffers.overlay_icon_line_vertices.len)
    {
        return error.InvalidBuffer;
    }
}

pub fn drawBatches(buffers: Buffers) [9]DrawBatch {
    return .{
        .{ .rects = buffers.liveRects() },
        .{ .text = buffers.liveTextVertices() },
        .{ .image = buffers.liveImageVertices() },
        .{ .svg = buffers.liveIconVertices() },
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
        .text,
        .overlay_text,
        .image,
        .svg,
        .icon_lines,
        .overlay_rects,
        .overlay_icon,
        .overlay_icon_lines,
        => |values| values,
    };
}

pub fn FixedBuffers(
    comptime rect_instances: usize,
    comptime icon_vertices_count: usize,
    comptime image_vertices_count: usize,
    comptime overlay_rect_instances: usize,
    comptime overlay_icon_vertices_count: usize,
    comptime icon_line_vertices_count: usize,
    comptime overlay_icon_line_vertices_count: usize,
) type {
    return struct {
        rects: [rect_instances * rect_float_stride]f32 = undefined,
        icon_vertices: [icon_vertices_count * icon_instance_float_stride]f32 = undefined,
        icon_line_vertices: [icon_line_vertices_count * icon_line_vertex_float_stride]f32 = undefined,
        text_vertices: [image_vertices_count * image_vertex_float_stride]f32 = undefined,
        overlay_text_vertices: [overlay_rect_instances * text_vertex_float_stride * 32]f32 = undefined,
        image_vertices: [image_vertices_count * image_vertex_float_stride]f32 = undefined,
        overlay_rects: [overlay_rect_instances * rect_float_stride]f32 = undefined,
        overlay_icon_vertices: [overlay_icon_vertices_count * icon_instance_float_stride]f32 = undefined,
        overlay_icon_line_vertices: [overlay_icon_line_vertices_count * icon_line_vertex_float_stride]f32 = undefined,
        rect_len: usize = 0,
        icon_vertex_len: usize = 0,
        icon_line_vertex_len: usize = 0,
        text_vertex_len: usize = 0,
        overlay_text_vertex_len: usize = 0,
        image_vertex_len: usize = 0,
        overlay_rect_len: usize = 0,
        overlay_icon_vertex_len: usize = 0,
        overlay_icon_line_vertex_len: usize = 0,

        pub fn buffers(self: *@This()) Buffers {
            return .{
                .rects = &self.rects,
                .rect_len = &self.rect_len,
                .icon_vertices = &self.icon_vertices,
                .icon_vertex_len = &self.icon_vertex_len,
                .icon_line_vertices = &self.icon_line_vertices,
                .icon_line_vertex_len = &self.icon_line_vertex_len,
                .text_vertices = &self.text_vertices,
                .text_vertex_len = &self.text_vertex_len,
                .overlay_text_vertices = &self.overlay_text_vertices,
                .overlay_text_vertex_len = &self.overlay_text_vertex_len,
                .image_vertices = &self.image_vertices,
                .image_vertex_len = &self.image_vertex_len,
                .overlay_rects = &self.overlay_rects,
                .overlay_rect_len = &self.overlay_rect_len,
                .overlay_icon_vertices = &self.overlay_icon_vertices,
                .overlay_icon_vertex_len = &self.overlay_icon_vertex_len,
                .overlay_icon_line_vertices = &self.overlay_icon_line_vertices,
                .overlay_icon_line_vertex_len = &self.overlay_icon_line_vertex_len,
            };
        }
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

pub fn pushSvgQuad(buffers: Buffers, layer: Layer, quad: ui.SvgQuad) Error!void {
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

pub fn pushTextGlyph(buffers: Buffers, x: f32, baseline_y: f32, px: f32, codepoint: u21, weight: ui.FontWeight, color: ui.Color) Error!void {
    try pushTextGlyphTo(buffers.text_vertices, buffers.text_vertex_len, x, baseline_y, px, codepoint, weight, color);
}

pub fn pushOverlayTextGlyph(buffers: Buffers, x: f32, baseline_y: f32, px: f32, codepoint: u21, weight: ui.FontWeight, color: ui.Color) Error!void {
    try pushTextGlyphTo(buffers.overlay_text_vertices, buffers.overlay_text_vertex_len, x, baseline_y, px, codepoint, weight, color);
}

fn pushTextGlyphTo(out: []f32, out_len: *usize, x: f32, baseline_y: f32, px: f32, codepoint: u21, weight: ui.FontWeight, color: ui.Color) Error!void {
    if (out_len.* + text_vertex_float_stride > out.len) return error.Budget;
    const glyph_key = @as(u32, codepoint) * 4 + @intFromEnum(weight);
    const values = [_]f32{ x, baseline_y, px, @floatFromInt(glyph_key), channel(color.r), channel(color.g), channel(color.b), channel(color.a) };
    @memcpy(out[out_len.* .. out_len.* + text_vertex_float_stride], &values);
    out_len.* += text_vertex_float_stride;
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

pub const body_header_size: usize = 36;

pub fn bodySize(buffers: Buffers) usize {
    return body_header_size +
        (buffers.rect_len.* +
            buffers.icon_vertex_len.* +
            buffers.icon_line_vertex_len.* +
            buffers.text_vertex_len.* +
            buffers.image_vertex_len.* +
            buffers.overlay_rect_len.* +
            buffers.overlay_text_vertex_len.* +
            buffers.overlay_icon_vertex_len.* +
            buffers.overlay_icon_line_vertex_len.*) * @sizeOf(f32);
}

pub const BodyHeader = struct {
    rect_floats: u32,
    text_floats: u32,
    icon_floats: u32,
    icon_line_floats: u32,
    image_floats: u32,
    overlay_rect_floats: u32,
    overlay_text_floats: u32,
    overlay_icon_floats: u32,
    overlay_icon_line_floats: u32,
};

pub fn encodeBody(buffers: Buffers, out: []u8) void {
    const hdr: BodyHeader = .{
        .rect_floats = @intCast(buffers.rect_len.*),
        .text_floats = @intCast(buffers.text_vertex_len.*),
        .icon_floats = @intCast(buffers.icon_vertex_len.*),
        .icon_line_floats = @intCast(buffers.icon_line_vertex_len.*),
        .image_floats = @intCast(buffers.image_vertex_len.*),
        .overlay_rect_floats = @intCast(buffers.overlay_rect_len.*),
        .overlay_text_floats = @intCast(buffers.overlay_text_vertex_len.*),
        .overlay_icon_floats = @intCast(buffers.overlay_icon_vertex_len.*),
        .overlay_icon_line_floats = @intCast(buffers.overlay_icon_line_vertex_len.*),
    };
    writeHeader(out, hdr);
    var pos: usize = body_header_size;
    for ([_][]const f32{
        buffers.liveRects(),
        buffers.liveTextVertices(),
        buffers.liveIconVertices(),
        buffers.liveIconLineVertices(),
        buffers.liveImageVertices(),
        buffers.liveOverlayRects(),
        buffers.liveOverlayTextVertices(),
        buffers.liveOverlayIconVertices(),
        buffers.liveOverlayIconLineVertices(),
    }) |slice| {
        writeFloatSlice(out[pos..][0 .. slice.len * @sizeOf(f32)], slice);
        pos += slice.len * @sizeOf(f32);
    }
}

pub fn decodeBody(body: []const u8) BodyHeader {
    const hdr: BodyHeader = .{
        .rect_floats = byte_utils.load32(body[0..4]).?,
        .text_floats = byte_utils.load32(body[4..8]).?,
        .icon_floats = byte_utils.load32(body[8..12]).?,
        .icon_line_floats = byte_utils.load32(body[12..16]).?,
        .image_floats = byte_utils.load32(body[16..20]).?,
        .overlay_rect_floats = byte_utils.load32(body[20..24]).?,
        .overlay_text_floats = byte_utils.load32(body[24..28]).?,
        .overlay_icon_floats = byte_utils.load32(body[28..32]).?,
        .overlay_icon_line_floats = byte_utils.load32(body[32..36]).?,
    };
    return hdr;
}

pub fn applyBody(body: []const u8, buffers: *Buffers) void {
    const hdr = decodeBody(body);
    var pos: usize = body_header_size;
    inline for (.{
        .{ .dst = buffers.rects, .len = &buffers.rect_len.*, .count = hdr.rect_floats },
        .{ .dst = buffers.text_vertices, .len = &buffers.text_vertex_len.*, .count = hdr.text_floats },
        .{ .dst = buffers.icon_vertices, .len = &buffers.icon_vertex_len.*, .count = hdr.icon_floats },
        .{ .dst = buffers.icon_line_vertices, .len = &buffers.icon_line_vertex_len.*, .count = hdr.icon_line_floats },
        .{ .dst = buffers.image_vertices, .len = &buffers.image_vertex_len.*, .count = hdr.image_floats },
        .{ .dst = buffers.overlay_rects, .len = &buffers.overlay_rect_len.*, .count = hdr.overlay_rect_floats },
        .{ .dst = buffers.overlay_text_vertices, .len = &buffers.overlay_text_vertex_len.*, .count = hdr.overlay_text_floats },
        .{ .dst = buffers.overlay_icon_vertices, .len = &buffers.overlay_icon_vertex_len.*, .count = hdr.overlay_icon_floats },
        .{ .dst = buffers.overlay_icon_line_vertices, .len = &buffers.overlay_icon_line_vertex_len.*, .count = hdr.overlay_icon_line_floats },
    }) |field| {
        const n: usize = field.count;
        field.len.* = n;
        if (n == 0) continue;
        readFloatSlice(field.dst[0..n], body[pos..][0 .. n * @sizeOf(f32)]);
        pos += n * @sizeOf(f32);
    }
}

fn writeHeader(out: []u8, hdr: BodyHeader) void {
    _ = byte_utils.store32(out[0..4], hdr.rect_floats);
    _ = byte_utils.store32(out[4..8], hdr.text_floats);
    _ = byte_utils.store32(out[8..12], hdr.icon_floats);
    _ = byte_utils.store32(out[12..16], hdr.icon_line_floats);
    _ = byte_utils.store32(out[16..20], hdr.image_floats);
    _ = byte_utils.store32(out[20..24], hdr.overlay_rect_floats);
    _ = byte_utils.store32(out[24..28], hdr.overlay_text_floats);
    _ = byte_utils.store32(out[28..32], hdr.overlay_icon_floats);
    _ = byte_utils.store32(out[32..36], hdr.overlay_icon_line_floats);
}

fn writeFloatSlice(out: []u8, values: []const f32) void {
    for (values, 0..) |value, index| {
        _ = byte_utils.store32(out[index * @sizeOf(f32) ..][0..@sizeOf(f32)], @bitCast(value));
    }
}

fn readFloatSlice(out: []f32, raw: []const u8) void {
    for (out, 0..) |*value, index| {
        value.* = @bitCast(byte_utils.load32(raw[index * @sizeOf(f32) ..][0..@sizeOf(f32)]).?);
    }
}

pub fn bodyFloatCount(hdr: BodyHeader) usize {
    return hdr.rect_floats + hdr.text_floats + hdr.icon_floats + hdr.icon_line_floats + hdr.image_floats +
        hdr.overlay_rect_floats + hdr.overlay_text_floats + hdr.overlay_icon_floats + hdr.overlay_icon_line_floats;
}

pub fn batchPrimitiveCount(batch: DrawBatch) Error!usize {
    return switch (batch) {
        .rects, .overlay_rects => |rects| rectCount(rects),
        .text, .overlay_text => |vertices| textGlyphCount(vertices),
        .image => |vertices| texturedQuadCount(vertices),
        .svg, .overlay_icon => |instances| iconCount(instances),
        .icon_lines, .overlay_icon_lines => 0,
    };
}

pub fn textGlyphCount(values: []const f32) Error!usize {
    if (values.len % text_vertex_float_stride != 0) return error.InvalidBuffer;
    return values.len / text_vertex_float_stride;
}

pub fn textGlyphAt(values: []const f32, index: usize) Error!TextGlyph {
    const count = try textGlyphCount(values);
    if (index >= count) return error.InvalidBuffer;
    const start = index * text_vertex_float_stride;
    const glyph = values[start .. start + text_vertex_float_stride];
    const glyph_key: u32 = @intFromFloat(glyph[text_glyph_codepoint_weight_index]);
    const weight_raw: u8 = @intCast(glyph_key & 3);
    const codepoint_raw = glyph_key / 4;
    if (codepoint_raw > max_u21) return error.InvalidBuffer;
    return .{
        .x = glyph[text_glyph_x_index],
        .baseline_y = glyph[text_glyph_baseline_y_index],
        .px = glyph[text_glyph_px_index],
        .codepoint = @intCast(codepoint_raw),
        .weight = switch (weight_raw) {
            @intFromEnum(ui.FontWeight.regular) => .regular,
            @intFromEnum(ui.FontWeight.semibold) => .semibold,
            @intFromEnum(ui.FontWeight.bold) => .bold,
            else => return error.InvalidBuffer,
        },
        .color = colorFromChannels(glyph[text_glyph_color_r_index], glyph[text_glyph_color_g_index], glyph[text_glyph_color_b_index], glyph[text_glyph_color_a_index]),
    };
}

const max_u21: u32 = 0x10ffff;

pub const TextGlyphIterator = struct {
    values: []const f32,
    index: usize = 0,
    count: usize,

    pub fn init(values: []const f32) Error!TextGlyphIterator {
        return .{ .values = values, .count = try textGlyphCount(values) };
    }

    pub fn next(self: *TextGlyphIterator) Error!?TextGlyph {
        if (self.index >= self.count) return null;
        const glyph = try textGlyphAt(self.values, self.index);
        self.index += 1;
        return glyph;
    }
};

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

fn expectSourceDoesNotContain(source: []const u8, needle: []const u8) !void {
    try std.testing.expectEqual(@as(?usize, null), std.mem.indexOf(u8, source, needle));
}

test "renderer ir backends stay behind icon_pack adapter" {
    try expectSourceDoesNotContain(@embedFile("backends/gles.zig"), "sourceForIconId");
    try expectSourceDoesNotContain(@embedFile("backends/software.zig"), "sourceForIconId");
    try expectSourceDoesNotContain(@embedFile("icon_line_buffer.zig"), "sourceForIconId");
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

test "renderer ir fixed buffers expose writable canonical buffer view" {
    var storage = FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try pushRect(buffers, .base, ui.Rect.init(1, 2, 3, 4), .accent, .clear, 0, 0, rectModeCode(.fill));
    try std.testing.expectEqual(rect_float_stride, storage.rect_len);
    try std.testing.expect(!buffers.hasImageVertices());
    try std.testing.expectEqual(@as(usize, 1), try primitiveCount(buffers));
    const rect = try rectAt(storage.rects[0..storage.rect_len], 0);
    try std.testing.expectEqual(ui.Color.accent, rect.color);
}

test "renderer ir iterates rects and textured quads" {
    var storage = FixedBuffers(2, 0, textured_quad_vertex_count, 0, 0, 0, 0){};
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
    var storage = FixedBuffers(1, 1, textured_quad_vertex_count, 1, 1, 1, 1){};
    const batches = drawBatches(storage.buffers());
    try std.testing.expectEqual(@as(usize, 9), batches.len);
    try std.testing.expectEqual(DrawBatch{ .rects = storage.rects[0..0] }, batches[0]);
    try std.testing.expectEqual(DrawBatch{ .text = storage.text_vertices[0..0] }, batches[1]);
    try std.testing.expectEqual(DrawBatch{ .image = storage.image_vertices[0..0] }, batches[2]);
    try std.testing.expectEqual(DrawBatch{ .svg = storage.icon_vertices[0..0] }, batches[3]);
    try std.testing.expectEqual(DrawBatch{ .icon_lines = storage.icon_line_vertices[0..0] }, batches[4]);
    try std.testing.expectEqual(DrawBatch{ .overlay_rects = storage.overlay_rects[0..0] }, batches[5]);
    try std.testing.expectEqual(DrawBatch{ .overlay_text = storage.overlay_text_vertices[0..0] }, batches[6]);
    try std.testing.expectEqual(DrawBatch{ .overlay_icon = storage.overlay_icon_vertices[0..0] }, batches[7]);
    try std.testing.expectEqual(DrawBatch{ .overlay_icon_lines = storage.overlay_icon_line_vertices[0..0] }, batches[8]);
    try std.testing.expectEqual(storage.image_vertices[0..0], batchValues(batches[2]));
}

test "renderer ir counts primitives from draw batches" {
    var storage = FixedBuffers(2, 0, textured_quad_vertex_count, 1, 0, 0, 0){};
    const buffers = storage.buffers();
    try pushRect(buffers, .base, ui.Rect.init(1, 2, 3, 4), .accent, .clear, 0, 0, rectModeCode(.fill));
    try pushRect(buffers, .base, ui.Rect.init(5, 6, 7, 8), .text, .clear, 0, 0, rectModeCode(.border));
    try pushImage(buffers, .{
        .bounds = ui.Rect.init(9, 10, 11, 12),
        .atlas_id = 1,
        .color = .muted,
    });
    try pushRect(buffers, .overlay, ui.Rect.init(17, 18, 19, 20), .panel, .clear, 0, 0, rectModeCode(.fill));

    var counted: usize = 0;
    for (drawBatches(buffers)) |batch| counted += try batchPrimitiveCount(batch);
    try std.testing.expectEqual(@as(usize, 4), counted);
    try std.testing.expectEqual(counted, try primitiveCount(buffers));
}

test "renderer ir validates live buffer lengths before slicing" {
    var storage = FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    storage.rect_len = storage.rects.len + 1;
    try std.testing.expectError(error.InvalidBuffer, validateBuffers(buffers));
}

test "renderer ir separates overlay commands from base buffers" {
    var rects: [rect_float_stride]f32 = undefined;
    var icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var text_vertices: [image_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_text_vertices: [image_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var image_vertices: [image_vertex_float_stride * textured_quad_vertex_count]f32 = undefined;
    var overlay_rects: [rect_float_stride]f32 = undefined;
    var overlay_icon_vertices: [icon_instance_float_stride]f32 = undefined;
    var overlay_icon_line_vertices: [icon_line_vertex_float_stride]f32 = undefined;
    var rect_len: usize = 0;
    var icon_vertex_len: usize = 0;
    var icon_line_vertex_len: usize = 0;
    var text_vertex_len: usize = 0;
    var overlay_text_vertex_len: usize = 0;
    var image_vertex_len: usize = 0;
    var overlay_rect_len: usize = 0;
    var overlay_icon_vertex_len: usize = 0;
    var overlay_icon_line_vertex_len: usize = 0;
    const buffers = Buffers{
        .rects = &rects,
        .rect_len = &rect_len,
        .icon_vertices = &icon_vertices,
        .icon_vertex_len = &icon_vertex_len,
        .icon_line_vertices = &icon_line_vertices,
        .icon_line_vertex_len = &icon_line_vertex_len,
        .text_vertices = &text_vertices,
        .text_vertex_len = &text_vertex_len,
        .overlay_text_vertices = &overlay_text_vertices,
        .overlay_text_vertex_len = &overlay_text_vertex_len,
        .image_vertices = &image_vertices,
        .image_vertex_len = &image_vertex_len,
        .overlay_rects = &overlay_rects,
        .overlay_rect_len = &overlay_rect_len,
        .overlay_icon_vertices = &overlay_icon_vertices,
        .overlay_icon_vertex_len = &overlay_icon_vertex_len,
        .overlay_icon_line_vertices = &overlay_icon_line_vertices,
        .overlay_icon_line_vertex_len = &overlay_icon_line_vertex_len,
    };

    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(0, 0, 10, 10), .bg, .fill, 0, 0);
    try scene.pushRect(ui.Rect.init(0, 0, 20, 20), .text, .fill, 0, 0);

    const overlay_start: usize = 1;
    buffers.clearBase();
    buffers.clearOverlay();
    inline for (0.., [_]Layer{ .base, .overlay }) |i, layer| {
        const cmds = if (i == 0) scene.written()[0..overlay_start] else scene.written()[overlay_start..];
        for (cmds) |cmd| {
            switch (cmd) {
                .rect => |r| try pushRect(buffers, layer, r.bounds, r.color, r.color2, r.radius, r.shadow, rectModeCode(r.mode)),
                else => {},
            }
        }
    }

    try std.testing.expectEqual(rect_float_stride, rect_len);
    try std.testing.expectEqual(rect_float_stride, overlay_rect_len);
    try std.testing.expectEqual(@as(f32, 10.0), rects[2]);
    try std.testing.expectEqual(@as(f32, 20.0), overlay_rects[2]);
}

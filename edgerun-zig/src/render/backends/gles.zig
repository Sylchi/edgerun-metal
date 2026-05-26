const std = @import("std");
const icon_vector = @import("../../icon_vector.zig");
const renderer_font_atlas = @import("../font_atlas.zig");
const renderer_icon_mask = @import("../icon_mask.zig");
const renderer_ir = @import("../ir.zig");
const ui = @import("../../ui.zig");

pub const c = @cImport({
    @cInclude("GLES2/gl2.h");
});

pub const State = struct {
    rect_program: c.GLuint,
    textured_program: c.GLuint,
    image_program: c.GLuint,
    line_program: c.GLuint,
    rect_vbo: c.GLuint,
    textured_vbo: c.GLuint,
    line_vbo: c.GLuint,
    font_texture: c.GLuint,
    image_texture: ?c.GLuint,
};

pub const RgbaTexture = struct {
    width: usize,
    height: usize,
    pixels: []const ui.Color,

    pub fn valid(self: RgbaTexture) bool {
        return self.width != 0 and self.height != 0 and self.pixels.len >= self.width * self.height;
    }
};

pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const FrameProof = struct {
    width: i32,
    height: i32,
    sample_count: u32,
    opaque_count: u32,
    variation_count: u32,
    sample_hash: u64,

    pub fn valid(self: FrameProof) bool {
        return self.width > 0 and
            self.height > 0 and
            self.sample_count == verification_sample_count and
            self.opaque_count != 0 and
            self.variation_count != 0 and
            self.sample_hash != 0;
    }
};

const verification_sample_axis: usize = 17;
const verification_sample_count: usize = verification_sample_axis * verification_sample_axis;
const verification_grid_denominator: i32 = @intCast(verification_sample_axis + 1);
const opaque_alpha_min: u8 = 16;
const fnv64_offset_basis: u64 = 0xcbf29ce484222325;
const fnv64_prime: u64 = 0x100000001b3;
const icon_circle_segments: usize = 12;
const icon_line_vertex_count: usize = 6;
const icon_position_components: usize = 2;
const icon_line_float_count: usize = icon_line_vertex_count * icon_position_components;
const icon_texture_vertex_count: usize = renderer_ir.textured_quad_vertex_count;
const icon_texture_float_count: usize = icon_texture_vertex_count * renderer_ir.text_vertex_float_stride;
const icon_min_line_len: f32 = 0.001;
const icon_min_stroke_px: f32 = 1.5;
const icon_stroke_scale: f32 = 0.085;
const shader_log_capacity: usize = 1024;

pub fn init(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture) !State {
    try requireHardwareGl();
    c.glClearColor(0.043, 0.043, 0.043, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFuncSeparate(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA, c.GL_ONE, c.GL_ONE_MINUS_SRC_ALPHA);
    const image_texture = if (image) |texture| blk: {
        if (!texture.valid()) return error.InvalidImageTexture;
        break :blk makeRgbaTexture(texture.width, texture.height, texture.pixels);
    } else null;
    return .{
        .rect_program = try makeProgram(rect_vertex_shader, rect_fragment_shader),
        .textured_program = try makeProgram(textured_vertex_shader, textured_fragment_shader),
        .image_program = try makeProgram(textured_vertex_shader, image_fragment_shader),
        .line_program = try makeProgram(line_vertex_shader, line_fragment_shader),
        .rect_vbo = makeBuffer(),
        .textured_vbo = makeBuffer(),
        .line_vbo = makeBuffer(),
        .font_texture = makeAlphaTexture(renderer_font_atlas.width, renderer_font_atlas.height, font_atlas.alphaSlice()),
        .image_texture = image_texture,
    };
}

pub fn deinit(gl: *State) void {
    if (gl.image_texture) |texture| c.glDeleteTextures(1, &texture);
    c.glDeleteTextures(1, &gl.font_texture);
    c.glDeleteBuffers(1, &gl.rect_vbo);
    c.glDeleteBuffers(1, &gl.textured_vbo);
    c.glDeleteBuffers(1, &gl.line_vbo);
    c.glDeleteProgram(gl.rect_program);
    c.glDeleteProgram(gl.textured_program);
    c.glDeleteProgram(gl.image_program);
    c.glDeleteProgram(gl.line_program);
}

pub fn refreshFontTexture(gl: State, font_atlas: *const renderer_font_atlas.Atlas) void {
    updateAlphaTexture(gl.font_texture, renderer_font_atlas.width, renderer_font_atlas.height, font_atlas.alphaSlice());
}

pub fn renderFrame(gl: State, width: i32, height: i32, buffers: renderer_ir.Buffers) !void {
    try renderFrameToViewport(gl, width, height, width, height, buffers);
}

pub fn renderFrameToViewport(gl: State, logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32, buffers: renderer_ir.Buffers) !void {
    c.glViewport(0, 0, framebuffer_width, framebuffer_height);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    const scale = viewportScale(logical_width, logical_height, framebuffer_width, framebuffer_height);
    try drawRects(gl, logical_width, logical_height, scale, buffers.liveRects());
    try drawImage(gl, logical_width, logical_height, buffers.liveImageVertices());
    try drawTextured(gl, logical_width, logical_height, buffers.liveTextVertices(), gl.font_texture);
    try drawIcons(gl, logical_width, logical_height, buffers.liveIconVertices());
    try drawRects(gl, logical_width, logical_height, scale, buffers.liveOverlayRects());
    try drawTextured(gl, logical_width, logical_height, buffers.liveOverlayTextVertices(), gl.font_texture);
    try drawIcons(gl, logical_width, logical_height, buffers.liveOverlayIconVertices());
}

fn drawImage(gl: State, width: i32, height: i32, values: []const f32) !void {
    if (values.len == 0) return;
    const texture = gl.image_texture orelse return error.MissingImageTexture;
    try drawTexturedWithProgram(gl, width, height, values, texture, gl.image_program);
}

pub fn verifyFrameNonBlank(width: i32, height: i32) !FrameProof {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    var samples: [verification_sample_count]Pixel = undefined;
    readVerificationSamples(width, height, &samples);
    const proof = frameProof(width, height, &samples);
    if (!proof.valid()) return error.BlankGpuFrame;
    return proof;
}

pub fn readFramePixels(width: i32, height: i32, out: []ui.Color) !void {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    const width_usize: usize = @intCast(width);
    const height_usize: usize = @intCast(height);
    const pixel_count = width_usize * height_usize;
    if (out.len < pixel_count) return error.InvalidPixelBuffer;
    c.glFinish();
    c.glPixelStorei(c.GL_PACK_ALIGNMENT, 1);
    var top_row: usize = 0;
    while (top_row < height_usize) : (top_row += 1) {
        const gl_row: c.GLint = @intCast(height_usize - 1 - top_row);
        const dst = out[top_row * width_usize ..][0..width_usize];
        c.glReadPixels(0, gl_row, @intCast(width_usize), 1, c.GL_RGBA, c.GL_UNSIGNED_BYTE, @as([*]u8, @ptrCast(dst.ptr)));
    }
}

pub fn sources(font_atlas: *renderer_font_atlas.Atlas) renderer_ir.Sources {
    return .{
        .font = font_atlas.source(),
    };
}

pub fn requireHardwareGl() !void {
    const renderer_raw = c.glGetString(c.GL_RENDERER) orelse return error.GlRendererUnavailable;
    const renderer = std.mem.span(@as([*:0]const u8, @ptrCast(renderer_raw)));
    if (isSoftwareRenderer(renderer)) return error.SoftwareGlRendererRejected;
}

pub fn isSoftwareRenderer(renderer: []const u8) bool {
    return std.ascii.indexOfIgnoreCase(renderer, "llvmpipe") != null or
        std.ascii.indexOfIgnoreCase(renderer, "softpipe") != null or
        std.ascii.indexOfIgnoreCase(renderer, "swrast") != null;
}

fn readVerificationSamples(width: i32, height: i32, samples: *[verification_sample_count]Pixel) void {
    c.glFinish();
    var index: usize = 0;
    var x_slot: i32 = 1;
    while (x_slot <= verification_sample_axis) : (x_slot += 1) {
        var y_slot: i32 = 1;
        while (y_slot <= verification_sample_axis) : (y_slot += 1) {
            var pixel = [_]u8{ 0, 0, 0, 0 };
            const x = sampleCoordinate(width, x_slot);
            const y = sampleCoordinate(height, y_slot);
            c.glReadPixels(x, y, 1, 1, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &pixel);
            samples[index] = .{ .r = pixel[0], .g = pixel[1], .b = pixel[2], .a = pixel[3] };
            index += 1;
        }
    }
}

fn sampleCoordinate(size: i32, slot: i32) i32 {
    const last = size - 1;
    const scaled = @divTrunc(size * slot, verification_grid_denominator);
    return std.math.clamp(scaled, 0, last);
}

fn frameProof(width: i32, height: i32, samples: []const Pixel) FrameProof {
    if (samples.len == 0) {
        return .{
            .width = width,
            .height = height,
            .sample_count = 0,
            .opaque_count = 0,
            .variation_count = 0,
            .sample_hash = 0,
        };
    }
    const first = samples[0];
    var opaque_count: u32 = 0;
    var variation_count: u32 = 0;
    for (samples) |sample| {
        if (sample.a >= opaque_alpha_min) opaque_count += 1;
        if (sample.r != first.r or sample.g != first.g or sample.b != first.b or sample.a != first.a) {
            variation_count += 1;
        }
    }
    return .{
        .width = width,
        .height = height,
        .sample_count = @intCast(samples.len),
        .opaque_count = opaque_count,
        .variation_count = variation_count,
        .sample_hash = hashSamples(samples),
    };
}

fn hashSamples(samples: []const Pixel) u64 {
    var hash = fnv64_offset_basis;
    for (samples) |sample| {
        hash = hashByte(hash, sample.r);
        hash = hashByte(hash, sample.g);
        hash = hashByte(hash, sample.b);
        hash = hashByte(hash, sample.a);
    }
    return hash;
}

fn hashByte(hash: u64, byte: u8) u64 {
    return (hash ^ byte) *% fnv64_prime;
}

fn viewportScale(logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32) f32 {
    if (logical_width <= 0 or logical_height <= 0 or framebuffer_width <= 0 or framebuffer_height <= 0) return 1.0;
    const x_scale = @as(f32, @floatFromInt(framebuffer_width)) / @as(f32, @floatFromInt(logical_width));
    const y_scale = @as(f32, @floatFromInt(framebuffer_height)) / @as(f32, @floatFromInt(logical_height));
    return @max(x_scale, y_scale);
}

fn drawRects(gl: State, width: i32, height: i32, scale: f32, values: []const f32) !void {
    var iter = renderer_ir.RectIterator.init(values) catch return error.InvalidIrBuffer;
    c.glUseProgram(gl.rect_program);
    c.glUniform2f(c.glGetUniformLocation(gl.rect_program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_pixel_scale"), scale);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(verts.len * @sizeOf(f32)), &verts, c.GL_STATIC_DRAW);
    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
    while (try iter.next()) |rect| {
        const draw_bounds = rectDrawBounds(rect);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_rect"), draw_bounds.x, draw_bounds.y, draw_bounds.w, draw_bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_source_rect"), rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color"), colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color2"), colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_radius"), rect.radius);
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_shadow"), rect.shadow);
        c.glUniform1i(c.glGetUniformLocation(gl.rect_program, "u_mode"), rectMode(rect.mode));
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
}

fn rectDrawBounds(rect: anytype) ui.Rect {
    return switch (rect.mode) {
        .shadow => rect.bounds.insetUniform(-rect.shadow),
        .fill, .border, .linear_gradient, .pie_slice => rect.bounds,
    };
}

fn drawTextured(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint) !void {
    try drawTexturedWithProgram(gl, width, height, values, texture, gl.textured_program);
}

fn drawTexturedWithProgram(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint, program: c.GLuint) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.text_vertex_float_stride != 0) return error.InvalidIrBuffer;
    c.glUseProgram(program);
    c.glUniform2f(c.glGetUniformLocation(program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glUniform1i(c.glGetUniformLocation(program, "u_tex"), 0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.textured_vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), values.ptr, c.GL_DYNAMIC_DRAW);
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);
    c.glEnableVertexAttribArray(2);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), null);
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    c.glVertexAttribPointer(2, 4, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(4 * @sizeOf(f32)));
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(values.len / renderer_ir.text_vertex_float_stride));
}

fn drawIcons(gl: State, width: i32, height: i32, values: []const f32) !void {
    var iter = renderer_ir.IconIterator.init(values) catch return error.InvalidIrBuffer;
    c.glUseProgram(gl.line_program);
    c.glUniform2f(c.glGetUniformLocation(gl.line_program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.line_vbo);
    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
    while (iter.next() catch return error.InvalidIrBuffer) |instance| {
        try drawIconInstance(gl, width, height, instance);
    }
}

fn drawIconInstance(gl: State, screen_width: i32, screen_height: i32, instance: renderer_ir.IconInstance) !void {
    if (try drawIconAlphaMask(gl, screen_width, screen_height, instance)) return;
    c.glUniform4f(c.glGetUniformLocation(gl.line_program, "u_color"), colorF(instance.color.r), colorF(instance.color.g), colorF(instance.color.b), colorF(instance.color.a));
    var iter = renderer_ir.iconOpIteratorForId(instance.icon_id);
    var path = IconPathState{};
    while (iter.next() catch return error.InvalidIrBuffer) |op| {
        switch (op) {
            .polyline => |points| try drawIconPolyline(gl, instance.bounds, points),
            .circle => |circle| try drawIconCircle(gl, instance.bounds, circle.cx, circle.cy, circle.radius),
            .ellipse => |ellipse| try drawIconEllipse(gl, instance.bounds, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full),
            .round_rect => |rect| try drawIconBox(gl, ui.Rect.init(
                instance.bounds.x + instance.bounds.w * rect.x,
                instance.bounds.y + instance.bounds.h * rect.y,
                instance.bounds.w * rect.w,
                instance.bounds.h * rect.h,
            )),
            .filled_circle => |circle| try drawIconFilledCircle(gl, instance.bounds, circle.cx, circle.cy, circle.radius),
            .filled_ellipse => |ellipse| try drawIconEllipse(gl, instance.bounds, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full),
            .filled_round_rect => |rect| try drawIconBox(gl, ui.Rect.init(
                instance.bounds.x + instance.bounds.w * rect.x,
                instance.bounds.y + instance.bounds.h * rect.y,
                instance.bounds.w * rect.w,
                instance.bounds.h * rect.h,
            )),
            .move_to => |point| path.moveTo(point),
            .line_to => |point| {
                if (path.current) |current| try drawIconSegment(gl, instance.bounds, current, point);
                path.lineTo(point);
            },
            .quad_to => |quad| {
                if (path.current) |current| try drawIconQuadratic(gl, instance.bounds, current, quad.control, quad.end);
                path.lineTo(quad.end);
            },
            .cubic_to => |curve| {
                if (path.current) |current| try drawIconCubic(gl, instance.bounds, current, curve.control0, curve.control1, curve.end);
                path.lineTo(curve.end);
            },
            .arc_to => |arc| {
                if (path.current) |current| try drawIconSegment(gl, instance.bounds, current, arc.end);
                path.lineTo(arc.end);
            },
            .close_path => if (path.current) |current| if (path.start) |start| {
                try drawIconSegment(gl, instance.bounds, current, start);
                path.lineTo(start);
            },
            .begin_fill_path,
            .begin_evenodd_fill_path,
            .end_fill_path,
            .paint_rgba,
            .paint_current_color,
            .paint_current_color_alpha,
            .paint_linear_gradient,
            .paint_radial_gradient,
            .stroke_width,
            .stroke_cap,
            .stroke_join,
            .stroke_miter_limit,
            .begin_clip_path,
            .end_clip_path,
            .clear_clip_path,
            => {},
        }
    }
}

fn drawIconAlphaMask(gl: State, screen_width: i32, screen_height: i32, instance: renderer_ir.IconInstance) !bool {
    const width = iconMaskAxis(instance.bounds.w);
    const height = iconMaskAxis(instance.bounds.h);
    var alpha: [renderer_icon_mask.max_pixels]u8 = undefined;
    const mask = try renderer_icon_mask.rasterizeIconAlpha(instance.icon_id, width, height, &alpha);
    if (!mask.painted) return false;
    const texture = makeIconAlphaTexture(mask.width, mask.height, mask.alpha);
    defer c.glDeleteTextures(1, &texture);
    var values: [icon_texture_float_count]f32 = undefined;
    writeIconTextureQuad(&values, instance);
    try drawTextured(gl, screen_width, screen_height, &values, texture);
    return true;
}

fn iconMaskAxis(value: f32) usize {
    if (value <= 1.0) return 1;
    return @min(renderer_icon_mask.max_width, @max(@as(usize, 1), @as(usize, @intFromFloat(@ceil(value)))));
}

fn writeIconTextureQuad(out: *[icon_texture_float_count]f32, instance: renderer_ir.IconInstance) void {
    const x0 = instance.bounds.x;
    const y0 = instance.bounds.y;
    const x1 = instance.bounds.x + instance.bounds.w;
    const y1 = instance.bounds.y + instance.bounds.h;
    writeTexturedVertex(out, 0, x0, y0, 0.0, 0.0, instance.color);
    writeTexturedVertex(out, 1, x1, y0, 1.0, 0.0, instance.color);
    writeTexturedVertex(out, 2, x0, y1, 0.0, 1.0, instance.color);
    writeTexturedVertex(out, 3, x1, y0, 1.0, 0.0, instance.color);
    writeTexturedVertex(out, 4, x1, y1, 1.0, 1.0, instance.color);
    writeTexturedVertex(out, 5, x0, y1, 0.0, 1.0, instance.color);
}

fn writeTexturedVertex(out: *[icon_texture_float_count]f32, vertex_index: usize, x: f32, y: f32, u: f32, v: f32, color: ui.Color) void {
    const base = vertex_index * renderer_ir.text_vertex_float_stride;
    out[base + 0] = x;
    out[base + 1] = y;
    out[base + 2] = u;
    out[base + 3] = v;
    out[base + 4] = colorF(color.r);
    out[base + 5] = colorF(color.g);
    out[base + 6] = colorF(color.b);
    out[base + 7] = colorF(color.a);
}

const IconPathState = struct {
    current: ?icon_vector.Point = null,
    start: ?icon_vector.Point = null,

    fn moveTo(self: *IconPathState, point: icon_vector.Point) void {
        self.current = point;
        self.start = point;
    }

    fn lineTo(self: *IconPathState, point: icon_vector.Point) void {
        self.current = point;
    }
};

fn drawIconSegment(gl: State, bounds: ui.Rect, a: icon_vector.Point, b: icon_vector.Point) !void {
    try drawIconLine(gl, bounds, a.x, a.y, b.x, b.y);
}

fn drawIconQuadratic(gl: State, bounds: ui.Rect, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point) !void {
    var previous = p0;
    var index: usize = 1;
    while (index <= icon_circle_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(icon_circle_segments));
        const inv = 1.0 - t;
        const next = icon_vector.Point{
            .x = inv * inv * p0.x + 2.0 * inv * t * p1.x + t * t * p2.x,
            .y = inv * inv * p0.y + 2.0 * inv * t * p1.y + t * t * p2.y,
        };
        try drawIconSegment(gl, bounds, previous, next);
        previous = next;
    }
}

fn drawIconCubic(gl: State, bounds: ui.Rect, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point, p3: icon_vector.Point) !void {
    var previous = p0;
    var index: usize = 1;
    while (index <= icon_circle_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(icon_circle_segments));
        const inv = 1.0 - t;
        const next = icon_vector.Point{
            .x = inv * inv * inv * p0.x + 3.0 * inv * inv * t * p1.x + 3.0 * inv * t * t * p2.x + t * t * t * p3.x,
            .y = inv * inv * inv * p0.y + 3.0 * inv * inv * t * p1.y + 3.0 * inv * t * t * p2.y + t * t * t * p3.y,
        };
        try drawIconSegment(gl, bounds, previous, next);
        previous = next;
    }
}

fn drawIconBox(gl: State, bounds: ui.Rect) !void {
    try drawIconLine(gl, bounds, 0.22, 0.22, 0.78, 0.22);
    try drawIconLine(gl, bounds, 0.78, 0.22, 0.78, 0.78);
    try drawIconLine(gl, bounds, 0.78, 0.78, 0.22, 0.78);
    try drawIconLine(gl, bounds, 0.22, 0.78, 0.22, 0.22);
}

fn drawIconPolyline(gl: State, bounds: ui.Rect, points: []const f32) !void {
    if (points.len < icon_vector.polyline_min_points * icon_vector.point_float_count) return;
    var index: usize = icon_vector.point_float_count;
    while (index < points.len) : (index += icon_vector.point_float_count) {
        try drawIconLine(gl, bounds, points[index - 2], points[index - 1], points[index], points[index + 1]);
    }
}

fn drawIconCircle(gl: State, bounds: ui.Rect, cx: f32, cy: f32, radius: f32) !void {
    try drawIconEllipse(gl, bounds, cx, cy, radius, radius, true);
}

fn drawIconEllipse(gl: State, bounds: ui.Rect, cx: f32, cy: f32, rx: f32, ry: f32, full: bool) !void {
    const start: f32 = if (full) 0.0 else 0.5;
    const end: f32 = 1.0;
    const span = end - start;
    var prev_x = cx + @cos(start * std.math.tau) * rx;
    var prev_y = cy + @sin(start * std.math.tau) * ry;
    var index: usize = 1;
    while (index <= icon_circle_segments) : (index += 1) {
        const turn = start + @as(f32, @floatFromInt(index)) * span / @as(f32, @floatFromInt(icon_circle_segments));
        const angle = turn * std.math.tau;
        const next_x = cx + @cos(angle) * rx;
        const next_y = cy + @sin(angle) * ry;
        try drawIconLine(gl, bounds, prev_x, prev_y, next_x, next_y);
        prev_x = next_x;
        prev_y = next_y;
    }
}

fn drawIconFilledCircle(gl: State, bounds: ui.Rect, cx: f32, cy: f32, radius: f32) !void {
    _ = gl;
    var values: [(icon_circle_segments + 2) * 2]f32 = undefined;
    const center_x = bounds.x + bounds.w * cx;
    const center_y = bounds.y + bounds.h * cy;
    const pixel_radius = @min(bounds.w, bounds.h) * radius;
    values[0] = center_x;
    values[1] = center_y;
    var index: usize = 0;
    while (index <= icon_circle_segments) : (index += 1) {
        const angle = @as(f32, @floatFromInt(index)) * std.math.tau / @as(f32, @floatFromInt(icon_circle_segments));
        const offset = (index + 1) * 2;
        values[offset] = center_x + @cos(angle) * pixel_radius;
        values[offset + 1] = center_y + @sin(angle) * pixel_radius;
    }
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), &values, c.GL_DYNAMIC_DRAW);
    c.glDrawArrays(c.GL_TRIANGLE_FAN, 0, @intCast(values.len / 2));
}

fn drawIconLine(gl: State, bounds: ui.Rect, x0n: f32, y0n: f32, x1n: f32, y1n: f32) !void {
    _ = gl;
    const x0 = bounds.x + bounds.w * x0n;
    const y0 = bounds.y + bounds.h * y0n;
    const x1 = bounds.x + bounds.w * x1n;
    const y1 = bounds.y + bounds.h * y1n;
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = @sqrt(dx * dx + dy * dy);
    if (len <= icon_min_line_len) return;
    const half_width = @max(icon_min_stroke_px, @min(bounds.w, bounds.h) * icon_stroke_scale) * 0.5;
    const nx = -dy / len * half_width;
    const ny = dx / len * half_width;
    const values: [icon_line_float_count]f32 = .{
        x0 + nx, y0 + ny,
        x1 + nx, y1 + ny,
        x1 - nx, y1 - ny,
        x0 + nx, y0 + ny,
        x1 - nx, y1 - ny,
        x0 - nx, y0 - ny,
    };
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), &values, c.GL_DYNAMIC_DRAW);
    c.glDrawArrays(c.GL_TRIANGLES, 0, icon_line_vertex_count);
}

fn makeBuffer() c.GLuint {
    var buffer: c.GLuint = 0;
    c.glGenBuffers(1, &buffer);
    return buffer;
}

fn makeAlphaTexture(width: usize, height: usize, alpha: []const u8) c.GLuint {
    return makeAlphaTextureFiltered(width, height, alpha, c.GL_LINEAR);
}

fn makeIconAlphaTexture(width: usize, height: usize, alpha: []const u8) c.GLuint {
    return makeAlphaTextureFiltered(width, height, alpha, c.GL_NEAREST);
}

fn makeAlphaTextureFiltered(width: usize, height: usize, alpha: []const u8, filter: c.GLint) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, filter);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, filter);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_ALPHA, @intCast(width), @intCast(height), 0, c.GL_ALPHA, c.GL_UNSIGNED_BYTE, alpha.ptr);
    return texture;
}

fn makeRgbaTexture(width: usize, height: usize, pixels: []const ui.Color) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(width), @intCast(height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels.ptr);
    return texture;
}

fn updateAlphaTexture(texture: c.GLuint, width: usize, height: usize, alpha: []const u8) void {
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intCast(width), @intCast(height), c.GL_ALPHA, c.GL_UNSIGNED_BYTE, alpha.ptr);
}

fn makeProgram(vertex_source: [:0]const u8, fragment_source: [:0]const u8) !c.GLuint {
    const vertex = try makeShader(c.GL_VERTEX_SHADER, vertex_source);
    defer c.glDeleteShader(vertex);
    const fragment = try makeShader(c.GL_FRAGMENT_SHADER, fragment_source);
    defer c.glDeleteShader(fragment);
    const program = c.glCreateProgram();
    c.glAttachShader(program, vertex);
    c.glAttachShader(program, fragment);
    c.glLinkProgram(program);
    var ok: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &ok);
    if (ok == 0) return error.GlProgramFailed;
    return program;
}

fn makeShader(kind: c.GLenum, source: [:0]const u8) !c.GLuint {
    const shader = c.glCreateShader(kind);
    var ptr = source.ptr;
    c.glShaderSource(shader, 1, &ptr, null);
    c.glCompileShader(shader);
    var ok: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &ok);
    if (ok == 0) {
        var log: [shader_log_capacity]u8 = undefined;
        var len: c.GLsizei = 0;
        c.glGetShaderInfoLog(shader, log.len, &len, &log);
        std.debug.print("gles shader compile failed: {s}\n", .{log[0..@intCast(len)]});
        return error.GlShaderFailed;
    }
    return shader;
}

fn colorF(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn rectMode(mode: ui.RectMode) c.GLint {
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 3,
        .pie_slice => 0,
    };
}

const rect_vertex_shader =
    \\attribute vec2 a_pos;
    \\uniform vec2 u_screen;
    \\uniform vec4 u_rect;
    \\void main() {
    \\  vec2 px = u_rect.xy + a_pos * u_rect.zw;
    \\  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\}
;

const rect_fragment_shader =
    \\precision highp float;
    \\uniform vec2 u_screen;
    \\uniform vec4 u_rect;
    \\uniform vec4 u_source_rect;
    \\uniform vec4 u_color;
    \\uniform vec4 u_color2;
    \\uniform float u_radius;
    \\uniform float u_shadow;
    \\uniform float u_pixel_scale;
    \\uniform int u_mode;
    \\float rounded_box(vec2 p, vec2 b, float r) {
    \\  vec2 q = abs(p) - b + vec2(r);
    \\  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    \\}
    \\void main() {
    \\  float aa = 1.0 / max(u_pixel_scale, 1.0);
    \\  vec2 px = vec2(gl_FragCoord.x / max(u_pixel_scale, 1.0), u_screen.y - gl_FragCoord.y / max(u_pixel_scale, 1.0));
    \\  vec2 p = px - u_rect.xy - u_rect.zw * 0.5;
    \\  float d = rounded_box(p, u_rect.zw * 0.5, u_radius);
    \\  float alpha = clamp(-d / aa, 0.0, 1.0);
    \\  if (u_radius <= 0.0) alpha = 1.0;
    \\  alpha = floor(alpha * 255.0 + 0.5) / 255.0;
    \\  if (u_mode == 1) {
    \\    vec2 sp = px - u_source_rect.xy - u_source_rect.zw * 0.5;
    \\    float sd = rounded_box(sp, u_source_rect.zw * 0.5, u_radius);
    \\    if (sd <= 0.0 || sd >= u_shadow) discard;
    \\    float t = 1.0 - sd / max(u_shadow, 0.001);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * t * t * 0.34);
    \\  } else if (u_mode == 2) {
    \\    float inner = rounded_box(p, u_rect.zw * 0.5 - vec2(1.25), max(u_radius - 1.25, 0.0));
    \\    float border = clamp(-d / aa, 0.0, 1.0) * clamp(inner / aa, 0.0, 1.0);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * border);
    \\  } else if (u_mode == 3) {
    \\    float t = clamp((px.y - u_rect.y) / max(u_rect.w, 1.0), 0.0, 1.0);
    \\    vec4 color = mix(u_color, u_color2, t);
    \\    gl_FragColor = vec4(color.rgb, color.a * alpha);
    \\  } else {
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * alpha);
    \\  }
    \\}
;

const textured_vertex_shader =
    \\attribute vec2 a_pos;
    \\attribute vec2 a_uv;
    \\attribute vec4 a_color;
    \\uniform vec2 u_screen;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\void main() {
    \\  vec2 ndc = vec2(a_pos.x / u_screen.x * 2.0 - 1.0, 1.0 - a_pos.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_uv = a_uv;
    \\  v_color = a_color;
    \\}
;

const textured_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  float a = texture2D(u_tex, v_uv).a;
    \\  gl_FragColor = vec4(v_color.rgb, v_color.a * a);
    \\}
;

const image_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  vec4 texel = texture2D(u_tex, v_uv);
    \\  gl_FragColor = vec4(texel.rgb * v_color.rgb, texel.a * v_color.a);
    \\}
;

const line_vertex_shader =
    \\attribute vec2 a_pos;
    \\uniform vec2 u_screen;
    \\void main() {
    \\  vec2 ndc = vec2(a_pos.x / u_screen.x * 2.0 - 1.0, 1.0 - a_pos.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\}
;

const line_fragment_shader =
    \\precision mediump float;
    \\uniform vec4 u_color;
    \\void main() {
    \\  gl_FragColor = u_color;
    \\}
;

test "software GL renderer names are rejected" {
    try std.testing.expect(isSoftwareRenderer("llvmpipe (LLVM 22.1.3, 256 bits)"));
    try std.testing.expect(isSoftwareRenderer("softpipe"));
    try std.testing.expect(isSoftwareRenderer("Mesa swrast"));
    try std.testing.expect(!isSoftwareRenderer("AMD Radeon 780M Graphics (radeonsi, phoenix, ACO)"));
}

test "rect modes map to stable shader mode ids" {
    try std.testing.expectEqual(@as(c.GLint, 0), rectMode(.fill));
    try std.testing.expectEqual(@as(c.GLint, 1), rectMode(.shadow));
    try std.testing.expectEqual(@as(c.GLint, 2), rectMode(.border));
    try std.testing.expectEqual(@as(c.GLint, 3), rectMode(.linear_gradient));
    try std.testing.expectEqual(@as(c.GLint, 0), rectMode(.pie_slice));
}

test "gles shadow rect expands draw bounds but keeps source bounds" {
    const rect = renderer_ir.Rect{
        .bounds = ui.Rect.init(10, 20, 30, 40),
        .color = .accent,
        .color2 = .clear,
        .radius = 4,
        .shadow = 6,
        .mode = .shadow,
    };
    const bounds = rectDrawBounds(rect);
    try std.testing.expectEqual(@as(f32, 4), bounds.x);
    try std.testing.expectEqual(@as(f32, 14), bounds.y);
    try std.testing.expectEqual(@as(f32, 42), bounds.w);
    try std.testing.expectEqual(@as(f32, 52), bounds.h);
}

test "frame proof rejects uniform samples and accepts variation" {
    var uniform = [_]Pixel{.{ .r = 11, .g = 11, .b = 11, .a = 255 }} ** verification_sample_count;
    try std.testing.expect(!frameProof(960, 540, &uniform).valid());

    var varied = uniform;
    varied[verification_sample_count / 2] = .{ .r = 74, .g = 222, .b = 128, .a = 255 };
    const proof = frameProof(960, 540, &varied);
    try std.testing.expect(proof.valid());
    try std.testing.expectEqual(@as(u32, verification_sample_count), proof.sample_count);
    try std.testing.expectEqual(@as(u32, verification_sample_count), proof.opaque_count);
    try std.testing.expectEqual(@as(u32, 1), proof.variation_count);
}

test "frame verification sample coordinates stay in bounds" {
    try std.testing.expectEqual(@as(i32, 0), sampleCoordinate(1, 1));
    try std.testing.expectEqual(@as(i32, 1), sampleCoordinate(18, 1));
    try std.testing.expectEqual(@as(i32, 9), sampleCoordinate(18, 9));
    try std.testing.expectEqual(@as(i32, 17), sampleCoordinate(18, 17));
}

test "frame proof sample hash is stable" {
    const samples = [_]Pixel{
        .{ .r = 11, .g = 11, .b = 11, .a = 255 },
        .{ .r = 74, .g = 222, .b = 128, .a = 255 },
    };
    try std.testing.expectEqual(hashSamples(&samples), hashSamples(&samples));
    try std.testing.expect(hashSamples(&samples) != 0);
}

test "viewport scale follows the EGL framebuffer backing size" {
    try std.testing.expectEqual(@as(f32, 1.0), viewportScale(1280, 720, 1280, 720));
    try std.testing.expectEqual(@as(f32, 2.0), viewportScale(1280, 720, 2560, 1440));
    try std.testing.expectEqual(@as(f32, 1.0), viewportScale(0, 720, 2560, 1440));
}

test "font atlas refresh API accepts populated variable font atlas" {
    var atlas = renderer_font_atlas.Atlas.init();
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushText(buffers, atlas.source(), .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, "A", .text, .start);
    try std.testing.expect(atlas.cachedGlyphCount() > 0);
}

test "rgba texture type validates image pixels" {
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 4 }};
    try std.testing.expect((RgbaTexture{ .width = 1, .height = 1, .pixels = &pixels }).valid());
    try std.testing.expect(!(RgbaTexture{ .width = 1, .height = 2, .pixels = &pixels }).valid());
}

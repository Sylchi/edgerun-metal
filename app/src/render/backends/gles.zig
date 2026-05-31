const std = @import("std");
const renderer_font_atlas = @import("../font_atlas_weighted.zig");
const gl_contract = @import("../gl_contract.zig");
const renderer_ir = @import("../ir.zig");
const renderer_present = @import("../present.zig");
const ui = @import("../../ui/core.zig");
const gles_gl = @import("../../linux_gles.zig");
const gles_mod = @This();

pub const RgbaTexture = renderer_ir.RgbaTexture;

pub const State = struct {
    gles: *const gles_gl.Gles2,
    rect_program: gles_gl.GLuint,
    textured_program: gles_gl.GLuint,
    image_program: gles_gl.GLuint,
    line_program: gles_gl.GLuint,
    rect_vbo: gles_gl.GLuint,
    textured_vbo: gles_gl.GLuint,
    line_vbo: gles_gl.GLuint,
    font_texture: gles_gl.GLuint,
    image_texture: ?gles_gl.GLuint,
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
const shader_log_capacity: usize = 1024;

pub fn initState(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture, gles: *const gles_gl.Gles2) !State {
    try requireHardwareGl(gles);
    gles.glClearColor(gl_contract.clear_color_r, gl_contract.clear_color_g, gl_contract.clear_color_b, gl_contract.clear_color_a);
    gles.glDisable(gles_gl.gl_dither);
    gles.glEnable(gles_gl.gl_blend);
    gles.glBlendFuncSeparate(gles_gl.gl_one, gles_gl.gl_one_minus_src_alpha, gles_gl.gl_one, gles_gl.gl_one_minus_src_alpha);
    const image_texture = if (image) |texture| blk: {
        if (!texture.valid()) return error.InvalidImageTexture;
        break :blk makeRgbaTexture(gles, texture.width, texture.height, texture.pixels);
    } else null;
    return .{
        .gles = gles,
        .rect_program = try makeProgram(gles, gl_contract.rect_vertex_shader, gl_contract.rect_fragment_shader),
        .textured_program = try makeProgram(gles, gl_contract.textured_vertex_shader, gl_contract.text_fragment_shader),
        .image_program = try makeProgram(gles, gl_contract.textured_vertex_shader, gl_contract.image_fragment_shader),
        .line_program = try makeProgram(gles, gl_contract.line_vertex_shader, gl_contract.line_fragment_shader),
        .rect_vbo = makeBuffer(gles),
        .textured_vbo = makeBuffer(gles),
        .line_vbo = makeBuffer(gles),
        .font_texture = makeAlphaTextureFiltered(gles, font_atlas.width, font_atlas.height, font_atlas.alphaSlice(), gles_gl.gl_linear),
        .image_texture = image_texture,
    };
}

pub fn deinit(gl: *State) void {
    if (gl.image_texture) |texture| gl.gles.glDeleteTextures(1, &texture);
    gl.gles.glDeleteTextures(1, &gl.font_texture);
    gl.gles.glDeleteBuffers(1, &gl.rect_vbo);
    gl.gles.glDeleteBuffers(1, &gl.textured_vbo);
    gl.gles.glDeleteBuffers(1, &gl.line_vbo);
    gl.gles.glDeleteProgram(gl.rect_program);
    gl.gles.glDeleteProgram(gl.textured_program);
    gl.gles.glDeleteProgram(gl.image_program);
    gl.gles.glDeleteProgram(gl.line_program);
}

pub fn refreshFontTexture(gl: State, font_atlas: *const renderer_font_atlas.Atlas) void {
    updateAlphaTexture(gl.gles, gl.font_texture, font_atlas.width, font_atlas.height, font_atlas.alphaSlice());
}

pub fn renderFrame(gl: State, width: i32, height: i32, buffers: renderer_ir.Buffers) !void {
    try renderFrameToViewport(gl, width, height, width, height, buffers);
}

pub fn renderFrameToViewport(gl: State, logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32, buffers: renderer_ir.Buffers) !void {
    gl.gles.glViewport(0, 0, framebuffer_width, framebuffer_height);
    gl.gles.glClear(gles_gl.gl_color_buffer_bit);
    const scale = viewportScale(logical_width, logical_height, framebuffer_width, framebuffer_height);
    try drawRects(gl, logical_width, logical_height, scale, buffers.liveRects());
    try drawText(gl, logical_width, logical_height, buffers.liveTextVertices());
    try drawImage(gl, logical_width, logical_height, buffers.liveImageVertices());
    try drawIconLines(gl, logical_width, logical_height, buffers.liveIconLineVertices());
    try drawRects(gl, logical_width, logical_height, scale, buffers.liveOverlayRects());
    try drawText(gl, logical_width, logical_height, buffers.liveOverlayTextVertices());
    try drawIconLines(gl, logical_width, logical_height, buffers.liveOverlayIconLineVertices());
}

fn drawText(gl: State, width: i32, height: i32, values: []const f32) !void {
    if (values.len == 0) return;
    try drawTexturedWithProgram(gl, width, height, values, gl.font_texture, gl.textured_program);
}

fn drawImage(gl: State, width: i32, height: i32, values: []const f32) !void {
    if (values.len == 0) return;
    const texture = gl.image_texture orelse return error.MissingImageTexture;
    try drawTexturedWithProgram(gl, width, height, values, texture, gl.image_program);
}

pub fn verifyFrameNonBlank(gles: *const gles_gl.Gles2, width: i32, height: i32) !FrameProof {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    var samples: [verification_sample_count]Pixel = undefined;
    readVerificationSamples(gles, width, height, &samples);
    const proof = frameProof(width, height, &samples);
    if (!proof.valid()) return error.BlankGpuFrame;
    return proof;
}

pub fn readFramePixels(gles: *const gles_gl.Gles2, width: i32, height: i32, out: []ui.Color) !void {
    try readBoundFramePixels(gles, width, height, out);
}

pub fn renderFrameToRgbaPixels(gl: State, width: i32, height: i32, buffers: renderer_ir.Buffers, out: []ui.Color) !void {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    const texture = makeEmptyRgbaTexture(gl.gles, @intCast(width), @intCast(height));
    defer gl.gles.glDeleteTextures(1, &texture);
    var framebuffer: gles_gl.GLuint = 0;
    gl.gles.glGenFramebuffers(1, &framebuffer);
    defer gl.gles.glDeleteFramebuffers(1, &framebuffer);
    gl.gles.glBindFramebuffer(gles_gl.gl_framebuffer, framebuffer);
    defer gl.gles.glBindFramebuffer(gles_gl.gl_framebuffer, 0);
    gl.gles.glFramebufferTexture2D(gles_gl.gl_framebuffer, gles_gl.gl_color_attachment0, gles_gl.gl_texture_2d, texture, 0);
    if (gl.gles.glCheckFramebufferStatus(gles_gl.gl_framebuffer) != gles_gl.gl_framebuffer_complete) return error.GlFramebufferIncomplete;
    try renderFrameToViewport(gl, width, height, width, height, buffers);
    try readBoundFramePixels(gl.gles, width, height, out);
}

fn readBoundFramePixels(gles: *const gles_gl.Gles2, width: i32, height: i32, out: []ui.Color) !void {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    const width_usize: usize = @intCast(width);
    const height_usize: usize = @intCast(height);
    const pixel_count = width_usize * height_usize;
    if (out.len < pixel_count) return error.InvalidPixelBuffer;
    gles.glFinish();
    gles.glPixelStorei(gles_gl.gl_pack_alignment, 1);
    var top_row: usize = 0;
    while (top_row < height_usize) : (top_row += 1) {
        const gl_row: gles_gl.GLint = @intCast(height_usize - 1 - top_row);
        const dst = out[top_row * width_usize ..][0..width_usize];
        gles.glReadPixels(0, gl_row, @intCast(width_usize), 1, gles_gl.gl_rgba, gles_gl.gl_unsigned_byte, @as([*]u8, @ptrCast(dst.ptr)));
    }
}

pub fn requireHardwareGl(gles: *const gles_gl.Gles2) !void {
    const renderer_raw = gles.glGetString(gles_gl.gl_renderer) orelse return error.GlRendererUnavailable;
    const renderer = std.mem.span(@as([*:0]const u8, @ptrCast(renderer_raw.?)));
    if (isSoftwareRenderer(renderer)) return error.SoftwareGlRendererRejected;
}

pub fn isSoftwareRenderer(renderer: []const u8) bool {
    return std.ascii.indexOfIgnoreCase(renderer, "llvmpipe") != null or
        std.ascii.indexOfIgnoreCase(renderer, "softpipe") != null or
        std.ascii.indexOfIgnoreCase(renderer, "swrast") != null;
}

fn readVerificationSamples(gles: *const gles_gl.Gles2, width: i32, height: i32, samples: *[verification_sample_count]Pixel) void {
    gles.glFinish();
    var index: usize = 0;
    var x_slot: i32 = 1;
    while (x_slot <= verification_sample_axis) : (x_slot += 1) {
        var y_slot: i32 = 1;
        while (y_slot <= verification_sample_axis) : (y_slot += 1) {
            var pixel = [_]u8{ 0, 0, 0, 0 };
            const x = sampleCoordinate(width, x_slot);
            const y = sampleCoordinate(height, y_slot);
            gles.glReadPixels(x, y, 1, 1, gles_gl.gl_rgba, gles_gl.gl_unsigned_byte, &pixel);
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
    gl.gles.glUseProgram(gl.rect_program);
    gl.gles.glUniform2f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    gl.gles.glUniform1f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_pixel_scale), scale);
    gl.gles.glBindBuffer(gles_gl.gl_array_buffer, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    gl.gles.glBufferData(gles_gl.gl_array_buffer, @intCast(verts.len * @sizeOf(f32)), &verts, gles_gl.gl_static_draw);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    gl.gles.glVertexAttribPointer(gl_contract.attr_pos_location, 2, gles_gl.gl_float, gles_gl.gl_false, 2 * @sizeOf(f32), null);
    while (try iter.next()) |rect| {
        const draw_bounds = rectDrawBounds(rect);
        gl.gles.glUniform4f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_rect), draw_bounds.x, draw_bounds.y, draw_bounds.w, draw_bounds.h);
        gl.gles.glUniform4f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_source_rect), rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        gl.gles.glUniform4f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_color), colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        gl.gles.glUniform4f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_color2), colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        gl.gles.glUniform1f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_radius), rect.radius);
        gl.gles.glUniform1f(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_shadow), rect.shadow);
        gl.gles.glUniform1i(gl.gles.glGetUniformLocation(gl.rect_program, gl_contract.uniform_mode), rectMode(gl.gles, rect.mode));
        gl.gles.glDrawArrays(gles_gl.gl_triangle_strip, 0, 4);
    }
}

fn rectDrawBounds(rect: anytype) ui.Rect {
    return switch (rect.mode) {
        .shadow => rect.bounds.insetUniform(-rect.shadow),
        .fill, .border, .linear_gradient, .pie_slice => rect.bounds,
    };
}

fn drawTexturedWithProgram(gl: State, width: i32, height: i32, values: []const f32, texture: gles_gl.GLuint, program: gles_gl.GLuint) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.text_vertex_float_stride != 0) return error.InvalidIrBuffer;
    gl.gles.glUseProgram(program);
    gl.gles.glUniform2f(gl.gles.glGetUniformLocation(program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    gl.gles.glActiveTexture(gles_gl.gl_texture0);
    gl.gles.glBindTexture(gles_gl.gl_texture_2d, texture);
    gl.gles.glUniform1i(gl.gles.glGetUniformLocation(program, gl_contract.uniform_texture), 0);
    if (program == gl.textured_program) gl.gles.glUniform1i(gl.gles.glGetUniformLocation(program, gl_contract.uniform_texture_kind), gl_contract.texture_kind_alpha);
    gl.gles.glBindBuffer(gles_gl.gl_array_buffer, gl.textured_vbo);
    gl.gles.glBufferData(gles_gl.gl_array_buffer, @intCast(values.len * @sizeOf(f32)), values.ptr, gles_gl.gl_dynamic_draw);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_uv_location);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_color_location);
    gl.gles.glVertexAttribPointer(gl_contract.attr_pos_location, 2, gles_gl.gl_float, gles_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), null);
    gl.gles.glVertexAttribPointer(gl_contract.attr_uv_location, 2, gles_gl.gl_float, gles_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.gles.glVertexAttribPointer(gl_contract.attr_color_location, 4, gles_gl.gl_float, gles_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(4 * @sizeOf(f32)));
    gl.gles.glDrawArrays(gles_gl.gl_triangles, 0, @intCast(values.len / renderer_ir.text_vertex_float_stride));
}

fn drawIconLines(gl: State, width: i32, height: i32, values: []const f32) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.icon_line_vertex_float_stride != 0) return error.InvalidIrBuffer;
    gl.gles.glUseProgram(gl.line_program);
    gl.gles.glUniform2f(gl.gles.glGetUniformLocation(gl.line_program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    gl.gles.glBindBuffer(gles_gl.gl_array_buffer, gl.line_vbo);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    gl.gles.glEnableVertexAttribArray(gl_contract.attr_color_location);
    gl.gles.glVertexAttribPointer(gl_contract.attr_pos_location, 2, gles_gl.gl_float, gles_gl.gl_false, renderer_ir.icon_line_vertex_float_stride * @sizeOf(f32), null);
    gl.gles.glVertexAttribPointer(gl_contract.attr_color_location, 4, gles_gl.gl_float, gles_gl.gl_false, renderer_ir.icon_line_vertex_float_stride * @sizeOf(f32), @ptrFromInt(renderer_ir.icon_line_color_r_index * @sizeOf(f32)));
    gl.gles.glBufferData(gles_gl.gl_array_buffer, @intCast(values.len * @sizeOf(f32)), values.ptr, gles_gl.gl_dynamic_draw);
    gl.gles.glDrawArrays(gles_gl.gl_triangles, 0, @intCast(values.len / renderer_ir.icon_line_vertex_float_stride));
}

fn makeBuffer(gles: *const gles_gl.Gles2) gles_gl.GLuint {
    var buffer: gles_gl.GLuint = 0;
    gles.glGenBuffers(1, &buffer);
    return buffer;
}

fn makeAlphaTextureFiltered(gles: *const gles_gl.Gles2, width: usize, height: usize, alpha: []const u8, filter: gles_gl.GLint) gles_gl.GLuint {
    var texture: gles_gl.GLuint = 0;
    gles.glGenTextures(1, &texture);
    gles.glBindTexture(gles_gl.gl_texture_2d, texture);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_min_filter, filter);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_mag_filter, filter);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_s, gles_gl.gl_clamp_to_edge);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_t, gles_gl.gl_clamp_to_edge);
    gles.glPixelStorei(gles_gl.gl_unpack_alignment, 1);
    gles.glTexImage2D(gles_gl.gl_texture_2d, 0, gles_gl.gl_alpha, @intCast(width), @intCast(height), 0, gles_gl.gl_alpha, gles_gl.gl_unsigned_byte, alpha.ptr);
    return texture;
}

fn makeRgbaTexture(gles: *const gles_gl.Gles2, width: usize, height: usize, pixels: []const ui.Color) gles_gl.GLuint {
    var texture: gles_gl.GLuint = 0;
    gles.glGenTextures(1, &texture);
    gles.glBindTexture(gles_gl.gl_texture_2d, texture);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_min_filter, gles_gl.gl_linear);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_mag_filter, gles_gl.gl_linear);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_s, gles_gl.gl_clamp_to_edge);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_t, gles_gl.gl_clamp_to_edge);
    gles.glPixelStorei(gles_gl.gl_unpack_alignment, 1);
    gles.glTexImage2D(gles_gl.gl_texture_2d, 0, gles_gl.gl_rgba, @intCast(width), @intCast(height), 0, gles_gl.gl_rgba, gles_gl.gl_unsigned_byte, pixels.ptr);
    return texture;
}

fn makeEmptyRgbaTexture(gles: *const gles_gl.Gles2, width: usize, height: usize) gles_gl.GLuint {
    var texture: gles_gl.GLuint = 0;
    gles.glGenTextures(1, &texture);
    gles.glBindTexture(gles_gl.gl_texture_2d, texture);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_min_filter, gles_gl.gl_nearest);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_mag_filter, gles_gl.gl_nearest);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_s, gles_gl.gl_clamp_to_edge);
    gles.glTexParameteri(gles_gl.gl_texture_2d, gles_gl.gl_texture_wrap_t, gles_gl.gl_clamp_to_edge);
    gles.glPixelStorei(gles_gl.gl_unpack_alignment, 1);
    gles.glTexImage2D(gles_gl.gl_texture_2d, 0, gles_gl.gl_rgba, @intCast(width), @intCast(height), 0, gles_gl.gl_rgba, gles_gl.gl_unsigned_byte, null);
    return texture;
}

fn updateAlphaTexture(gles: *const gles_gl.Gles2, texture: gles_gl.GLuint, width: usize, height: usize, alpha: []const u8) void {
    gles.glBindTexture(gles_gl.gl_texture_2d, texture);
    gles.glPixelStorei(gles_gl.gl_unpack_alignment, 1);
    gles.glTexSubImage2D(gles_gl.gl_texture_2d, 0, 0, 0, @intCast(width), @intCast(height), gles_gl.gl_alpha, gles_gl.gl_unsigned_byte, alpha.ptr);
}

fn makeProgram(gles: *const gles_gl.Gles2, vertex_source: [:0]const u8, fragment_source: [:0]const u8) !gles_gl.GLuint {
    const vertex = try makeShader(gles, gles_gl.gl_vertex_shader, vertex_source);
    defer gles.glDeleteShader(vertex);
    const fragment = try makeShader(gles, gles_gl.gl_fragment_shader, fragment_source);
    defer gles.glDeleteShader(fragment);
    const program = gles.glCreateProgram();
    gles.glAttachShader(program, vertex);
    gles.glAttachShader(program, fragment);
    gles.glBindAttribLocation(program, gl_contract.attr_pos_location, gl_contract.attr_pos);
    gles.glBindAttribLocation(program, gl_contract.attr_uv_location, gl_contract.attr_uv);
    gles.glBindAttribLocation(program, gl_contract.attr_color_location, gl_contract.attr_color);
    gles.glLinkProgram(program);
    var ok: gles_gl.GLint = 0;
    gles.glGetProgramiv(program, gles_gl.gl_link_status, &ok);
    if (ok == 0) return error.GlProgramFailed;
    return program;
}

fn makeShader(gles: *const gles_gl.Gles2, kind: gles_gl.GLenum, source: [:0]const u8) !gles_gl.GLuint {
    const shader = gles.glCreateShader(kind);
    var ptr = source.ptr;
    gles.glShaderSource(shader, 1, &ptr, null);
    gles.glCompileShader(shader);
    var ok: gles_gl.GLint = 0;
    gles.glGetShaderiv(shader, gles_gl.gl_compile_status, &ok);
    if (ok == 0) {
        var log: [shader_log_capacity]u8 = undefined;
        var len: gles_gl.GLsizei = 0;
        gles.glGetShaderInfoLog(shader, log.len, &len, &log);
        std.debug.print("gles shader compile failed: {s}\n", .{log[0..@intCast(len)]});
        return error.GlShaderFailed;
    }
    return shader;
}

fn colorF(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn rectMode(gles: *const gles_gl.Gles2, mode: ui.RectMode) gles_gl.GLint {
    _ = gles;
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 3,
        .pie_slice => 4,
    };
}

test "software GL renderer names are rejected" {
    try std.testing.expect(isSoftwareRenderer("llvmpipe (LLVM 22.1.3, 256 bits)"));
    try std.testing.expect(isSoftwareRenderer("softpipe"));
    try std.testing.expect(isSoftwareRenderer("Mesa swrast"));
    try std.testing.expect(!isSoftwareRenderer("AMD Radeon 780M Graphics (radeonsi, phoenix, ACO)"));
}

test "rect modes map to stable shader mode ids" {
    const gles = try gles_gl.Gles2.open();
    try std.testing.expectEqual(@as(gles_gl.GLint, 0), rectMode(&gles, .fill));
    try std.testing.expectEqual(@as(gles_gl.GLint, 1), rectMode(&gles, .shadow));
    try std.testing.expectEqual(@as(gles_gl.GLint, 2), rectMode(&gles, .border));
    try std.testing.expectEqual(@as(gles_gl.GLint, 3), rectMode(&gles, .linear_gradient));
    try std.testing.expectEqual(@as(gles_gl.GLint, 0), rectMode(&gles, .pie_slice));
    gles.lib.close();
}

test "gles icons use the shared IR packed line contract" {
    const source = @embedFile("gles.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, "@import(\"../../icon_vector.zig\")") == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "@import(\"../icon_mask.zig\")") == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "@import(\"../icon_line_buffer.zig\")") == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "iconOpIteratorForId") == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "liveIconLineVertices") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "drawIconLines") != null);
}

test "gles clear color comes from the shared GL contract" {
    const source = @embedFile("gles.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, "glClearColor(gl_contract.clear_color_r") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "glClearColor(0.043") == null);
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
    var atlas: renderer_font_atlas.Atlas = undefined;
    atlas.initUtf8();
    try atlas.prepareText("A", 18, .regular);
    try std.testing.expect(atlas.cachedGlyphCount() > 0);
}

test "rgba texture type validates image pixels" {
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 4 }};
    try std.testing.expect((RgbaTexture{ .width = 1, .height = 1, .pixels = &pixels }).valid());
    try std.testing.expect(!(RgbaTexture{ .width = 1, .height = 2, .pixels = &pixels }).valid());
}

pub const Receipt = renderer_present.Receipt;

pub const AdapterError = error{
    InvalidImageTexture,
    GlRendererUnavailable,
    SoftwareGlRendererRejected,
    InvalidFramebufferSize,
    BlankGpuFrame,
    GlFramebufferIncomplete,
};

pub const Adapter = struct {
    state: State,
    gles: gles_gl.Gles2,
    image_texture_ready: bool,

    pub fn init(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture) AdapterError!Adapter {
        var gles_instance = try gles_gl.Gles2.open();
        const gles_ptr = &gles_instance;
        const st = try initState(font_atlas, image, gles_ptr);
        return .{ .state = st, .gles = gles_instance, .image_texture_ready = image != null };
    }

    pub fn deinit(self: *Adapter) void {
        gles_mod.deinit(&self.state);
        self.gles.lib.close();
    }

    pub fn refreshFontTexture(self: Adapter, font_atlas: *const renderer_font_atlas.Atlas) void {
        gles_mod.refreshFontTexture(self.state, font_atlas);
    }

    pub fn renderFrame(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers) AdapterError!Receipt {
        const receipt = try self.receiptForFrame(width, height, buffers);
        try gles_mod.renderFrame(self.state, width, height, buffers);
        return receipt;
    }

    pub fn renderFrameToViewport(self: Adapter, logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32, buffers: renderer_ir.Buffers) AdapterError!Receipt {
        const receipt = try self.receiptForFrame(logical_width, logical_height, buffers);
        try gles_mod.renderFrameToViewport(self.state, logical_width, logical_height, framebuffer_width, framebuffer_height, buffers);
        return receipt;
    }

    pub fn verifyFrameNonBlank(self: Adapter, width: i32, height: i32) !FrameProof {
        return gles_mod.verifyFrameNonBlank(&self.gles, width, height);
    }

    pub fn readFramePixels(self: Adapter, width: i32, height: i32, out: []ui.Color) !void {
        try gles_mod.readFramePixels(&self.gles, width, height, out);
    }

    pub fn renderFrameToRgbaPixels(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers, out: []ui.Color) AdapterError!Receipt {
        const receipt = try self.receiptForFrame(width, height, buffers);
        try gles_mod.renderFrameToRgbaPixels(self.state, width, height, buffers, out);
        return receipt;
    }

    fn receiptForFrame(self: Adapter, width: i32, height: i32) renderer_present.Error!Receipt {
        if (width <= 0 or height <= 0) return error.InvalidTarget;
        return renderer_present.present(.{
            .target = .{
                .destination = .command_frame,
                .width = @intCast(width),
                .height = @intCast(height),
            },
            .buffers = self.state.last_ir_buffers,
            .resources = .{
                .font_atlas = true,
                .image_texture = self.image_texture_ready,
            },
        });
    }
};

pub fn requireHardwareGlExt() !void {
    var gles_instance = try gles_gl.Gles2.open();
    defer gles_instance.lib.close();
    try requireHardwareGl(&gles_instance);
}

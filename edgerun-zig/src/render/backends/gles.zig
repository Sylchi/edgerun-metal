const std = @import("std");
const renderer_font_atlas = @import("../font_atlas_weighted.zig");
const gl_contract = @import("../gl_contract.zig");
const renderer_ir = @import("../ir.zig");
const ui = @import("../../ui.zig");

pub const c = @cImport({
    @cInclude("GLES2/gl2.h");
});

pub const RgbaTexture = renderer_ir.RgbaTexture;

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

pub fn init(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture) !State {
    try requireHardwareGl();
    c.glClearColor(gl_contract.clear_color_r, gl_contract.clear_color_g, gl_contract.clear_color_b, gl_contract.clear_color_a);
    c.glDisable(c.GL_DITHER);
    c.glEnable(c.GL_BLEND);
    c.glBlendFuncSeparate(c.GL_ONE, c.GL_ONE_MINUS_SRC_ALPHA, c.GL_ONE, c.GL_ONE_MINUS_SRC_ALPHA);
    const image_texture = if (image) |texture| blk: {
        if (!texture.valid()) return error.InvalidImageTexture;
        break :blk makeRgbaTexture(texture.width, texture.height, texture.pixels);
    } else null;
    return .{
        .rect_program = try makeProgram(gl_contract.rect_vertex_shader, gl_contract.rect_fragment_shader),
        .textured_program = try makeProgram(gl_contract.textured_vertex_shader, gl_contract.text_fragment_shader),
        .image_program = try makeProgram(gl_contract.textured_vertex_shader, gl_contract.image_fragment_shader),
        .line_program = try makeProgram(gl_contract.line_vertex_shader, gl_contract.line_fragment_shader),
        .rect_vbo = makeBuffer(),
        .textured_vbo = makeBuffer(),
        .line_vbo = makeBuffer(),
        .font_texture = makeAlphaTextureFiltered(font_atlas.width, font_atlas.height, font_atlas.alphaSlice(), c.GL_LINEAR),
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
    updateAlphaTexture(gl.font_texture, font_atlas.width, font_atlas.height, font_atlas.alphaSlice());
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
    try drawFontTextured(gl, logical_width, logical_height, buffers.liveTextVertices(), gl.font_texture);
    try drawIconLines(gl, logical_width, logical_height, buffers.liveIconLineVertices());
    try drawRects(gl, logical_width, logical_height, scale, buffers.liveOverlayRects());
    try drawFontTextured(gl, logical_width, logical_height, buffers.liveOverlayTextVertices(), gl.font_texture);
    try drawIconLines(gl, logical_width, logical_height, buffers.liveOverlayIconLineVertices());
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
    try readBoundFramePixels(width, height, out);
}

pub fn renderFrameToRgbaPixels(gl: State, width: i32, height: i32, buffers: renderer_ir.Buffers, out: []ui.Color) !void {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    const texture = makeEmptyRgbaTexture(@intCast(width), @intCast(height));
    defer c.glDeleteTextures(1, &texture);
    var framebuffer: c.GLuint = 0;
    c.glGenFramebuffers(1, &framebuffer);
    defer c.glDeleteFramebuffers(1, &framebuffer);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebuffer);
    defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, texture, 0);
    if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE) return error.GlFramebufferIncomplete;
    try renderFrameToViewport(gl, width, height, width, height, buffers);
    try readBoundFramePixels(width, height, out);
}

fn readBoundFramePixels(width: i32, height: i32, out: []ui.Color) !void {
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
    c.glUniform2f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    c.glUniform1f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_pixel_scale), scale);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(verts.len * @sizeOf(f32)), &verts, c.GL_STATIC_DRAW);
    c.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    c.glVertexAttribPointer(gl_contract.attr_pos_location, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
    while (try iter.next()) |rect| {
        const draw_bounds = rectDrawBounds(rect);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_rect), draw_bounds.x, draw_bounds.y, draw_bounds.w, draw_bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_source_rect), rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_color), colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_color2), colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_radius), rect.radius);
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_shadow), rect.shadow);
        c.glUniform1i(c.glGetUniformLocation(gl.rect_program, gl_contract.uniform_mode), rectMode(rect.mode));
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
}

fn rectDrawBounds(rect: anytype) ui.Rect {
    return switch (rect.mode) {
        .shadow => rect.bounds.insetUniform(-rect.shadow),
        .fill, .border, .linear_gradient, .pie_slice => rect.bounds,
    };
}

fn drawFontTextured(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint) !void {
    try drawTexturedWithProgram(gl, width, height, values, texture, gl.textured_program);
}

fn drawTexturedWithProgram(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint, program: c.GLuint) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.text_vertex_float_stride != 0) return error.InvalidIrBuffer;
    c.glUseProgram(program);
    c.glUniform2f(c.glGetUniformLocation(program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glUniform1i(c.glGetUniformLocation(program, gl_contract.uniform_texture), 0);
    if (program == gl.textured_program) c.glUniform1i(c.glGetUniformLocation(program, gl_contract.uniform_texture_kind), gl_contract.texture_kind_alpha);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.textured_vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), values.ptr, c.GL_DYNAMIC_DRAW);
    c.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    c.glEnableVertexAttribArray(gl_contract.attr_uv_location);
    c.glEnableVertexAttribArray(gl_contract.attr_color_location);
    c.glVertexAttribPointer(gl_contract.attr_pos_location, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), null);
    c.glVertexAttribPointer(gl_contract.attr_uv_location, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    c.glVertexAttribPointer(gl_contract.attr_color_location, 4, c.GL_FLOAT, c.GL_FALSE, renderer_ir.text_vertex_float_stride * @sizeOf(f32), @ptrFromInt(4 * @sizeOf(f32)));
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(values.len / renderer_ir.text_vertex_float_stride));
}

fn drawIconLines(gl: State, width: i32, height: i32, values: []const f32) !void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.icon_line_vertex_float_stride != 0) return error.InvalidIrBuffer;
    c.glUseProgram(gl.line_program);
    c.glUniform2f(c.glGetUniformLocation(gl.line_program, gl_contract.uniform_screen), @floatFromInt(width), @floatFromInt(height));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.line_vbo);
    c.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    c.glEnableVertexAttribArray(gl_contract.attr_color_location);
    c.glVertexAttribPointer(gl_contract.attr_pos_location, 2, c.GL_FLOAT, c.GL_FALSE, renderer_ir.icon_line_vertex_float_stride * @sizeOf(f32), null);
    c.glVertexAttribPointer(gl_contract.attr_color_location, 4, c.GL_FLOAT, c.GL_FALSE, renderer_ir.icon_line_vertex_float_stride * @sizeOf(f32), @ptrFromInt(renderer_ir.icon_line_color_r_index * @sizeOf(f32)));
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(values.len * @sizeOf(f32)), values.ptr, c.GL_DYNAMIC_DRAW);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(values.len / renderer_ir.icon_line_vertex_float_stride));
}

fn makeBuffer() c.GLuint {
    var buffer: c.GLuint = 0;
    c.glGenBuffers(1, &buffer);
    return buffer;
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

fn makeEmptyRgbaTexture(width: usize, height: usize) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(width), @intCast(height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);
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
    c.glBindAttribLocation(program, gl_contract.attr_pos_location, gl_contract.attr_pos);
    c.glBindAttribLocation(program, gl_contract.attr_uv_location, gl_contract.attr_uv);
    c.glBindAttribLocation(program, gl_contract.attr_color_location, gl_contract.attr_color);
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
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushText(buffers, atlas.source(), .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, "A", .text, .start);
    try std.testing.expect(atlas.cachedGlyphCount() > 0);
}

test "rgba texture type validates image pixels" {
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 4 }};
    try std.testing.expect((RgbaTexture{ .width = 1, .height = 1, .pixels = &pixels }).valid());
    try std.testing.expect(!(RgbaTexture{ .width = 1, .height = 2, .pixels = &pixels }).valid());
}

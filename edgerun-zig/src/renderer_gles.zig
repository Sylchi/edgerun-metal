const std = @import("std");
const icon = @import("icon.zig");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const tabler_atlas = @import("tabler_atlas.zig");
const ui = @import("ui.zig");

pub const c = @cImport({
    @cInclude("GLES2/gl2.h");
});

pub const State = struct {
    rect_program: c.GLuint,
    text_program: c.GLuint,
    textured_program: c.GLuint,
    rect_vbo: c.GLuint,
    textured_vbo: c.GLuint,
    font_texture: c.GLuint,
    icon_texture: c.GLuint,
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

pub fn init(font_atlas: *renderer_font_atlas.Atlas) !State {
    try requireHardwareGl();
    c.glClearColor(0.043, 0.043, 0.043, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    return .{
        .rect_program = try makeProgram(rect_vertex_shader, rect_fragment_shader),
        .text_program = try makeProgram(textured_vertex_shader, text_fragment_shader),
        .textured_program = try makeProgram(textured_vertex_shader, textured_fragment_shader),
        .rect_vbo = makeBuffer(),
        .textured_vbo = makeBuffer(),
        .font_texture = makeRgbTexture(renderer_font_atlas.width, renderer_font_atlas.height, font_atlas.textureSlice()),
        .icon_texture = makeAlphaTexture(tabler_atlas.width, tabler_atlas.height, tabler_atlas.alpha),
    };
}

pub fn deinit(gl: *State) void {
    c.glDeleteTextures(1, &gl.font_texture);
    c.glDeleteTextures(1, &gl.icon_texture);
    c.glDeleteBuffers(1, &gl.rect_vbo);
    c.glDeleteBuffers(1, &gl.textured_vbo);
    c.glDeleteProgram(gl.rect_program);
    c.glDeleteProgram(gl.text_program);
    c.glDeleteProgram(gl.textured_program);
}

pub fn refreshFontTexture(gl: State, font_atlas: *const renderer_font_atlas.Atlas) void {
    updateRgbTexture(gl.font_texture, renderer_font_atlas.width, renderer_font_atlas.height, font_atlas.textureSlice());
}

pub fn renderFrame(gl: State, width: i32, height: i32, buffers: renderer_ir.Buffers) !void {
    c.glViewport(0, 0, width, height);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    try drawRects(gl, width, height, buffers.liveRects());
    try drawText(gl, width, height, buffers.liveTextVertices());
    try drawTextured(gl, width, height, buffers.liveIconVertices(), gl.icon_texture);
    try drawRects(gl, width, height, buffers.liveOverlayRects());
    try drawText(gl, width, height, buffers.liveOverlayTextVertices());
    try drawTextured(gl, width, height, buffers.liveOverlayIconVertices(), gl.icon_texture);
}

pub fn verifyFrameNonBlank(width: i32, height: i32) !FrameProof {
    if (width <= 0 or height <= 0) return error.InvalidFramebufferSize;
    var samples: [verification_sample_count]Pixel = undefined;
    readVerificationSamples(width, height, &samples);
    const proof = frameProof(width, height, &samples);
    if (!proof.valid()) return error.BlankGpuFrame;
    return proof;
}

pub fn sources(font_atlas: *renderer_font_atlas.Atlas) renderer_ir.Sources {
    return .{
        .font = font_atlas.source(),
        .icon = .{ .context = font_atlas, .rect = iconAtlasRect },
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

fn drawRects(gl: State, width: i32, height: i32, values: []const f32) !void {
    var iter = renderer_ir.RectIterator.init(values) catch return error.InvalidIrBuffer;
    c.glUseProgram(gl.rect_program);
    c.glUniform2f(c.glGetUniformLocation(gl.rect_program, "u_screen"), @floatFromInt(width), @floatFromInt(height));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(verts.len * @sizeOf(f32)), &verts, c.GL_STATIC_DRAW);
    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
    while (try iter.next()) |rect| {
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_rect"), rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color"), colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        c.glUniform4f(c.glGetUniformLocation(gl.rect_program, "u_color2"), colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_radius"), rect.radius);
        c.glUniform1f(c.glGetUniformLocation(gl.rect_program, "u_shadow"), rect.shadow);
        c.glUniform1i(c.glGetUniformLocation(gl.rect_program, "u_mode"), rectMode(rect.mode));
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
}

fn drawTextured(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint) !void {
    try drawTextureProgram(gl, width, height, values, texture, gl.textured_program);
}

fn drawText(gl: State, width: i32, height: i32, values: []const f32) !void {
    try drawTextureProgram(gl, width, height, values, gl.font_texture, gl.text_program);
}

fn drawTextureProgram(gl: State, width: i32, height: i32, values: []const f32, texture: c.GLuint, program: c.GLuint) !void {
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

fn makeBuffer() c.GLuint {
    var buffer: c.GLuint = 0;
    c.glGenBuffers(1, &buffer);
    return buffer;
}

fn makeAlphaTexture(width: usize, height: usize, alpha: []const u8) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_ALPHA, @intCast(width), @intCast(height), 0, c.GL_ALPHA, c.GL_UNSIGNED_BYTE, alpha.ptr);
    return texture;
}

fn updateAlphaTexture(texture: c.GLuint, width: usize, height: usize, alpha: []const u8) void {
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intCast(width), @intCast(height), c.GL_ALPHA, c.GL_UNSIGNED_BYTE, alpha.ptr);
}

fn makeRgbTexture(width: usize, height: usize, pixels: []const u8) c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @intCast(width), @intCast(height), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, pixels.ptr);
    return texture;
}

fn updateRgbTexture(texture: c.GLuint, width: usize, height: usize, pixels: []const u8) void {
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intCast(width), @intCast(height), c.GL_RGB, c.GL_UNSIGNED_BYTE, pixels.ptr);
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
    if (ok == 0) return error.GlShaderFailed;
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

fn iconAtlasRect(_: *anyopaque, atlas_id: u32) ?renderer_ir.AtlasRect {
    const value = icon.fromAtlasId(atlas_id) orelse return null;
    const found = tabler_atlas.rect(value);
    return .{
        .u0 = (@as(f32, @floatFromInt(found.x)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
        .u1 = (@as(f32, @floatFromInt(found.x + found.w)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.width)),
        .v1 = (@as(f32, @floatFromInt(found.y + found.h)) - 0.5) / @as(f32, @floatFromInt(tabler_atlas.height)),
    };
}

const rect_vertex_shader =
    \\attribute vec2 a_pos;
    \\uniform vec2 u_screen;
    \\uniform vec4 u_rect;
    \\varying vec2 v_local;
    \\varying vec2 v_size;
    \\void main() {
    \\  vec2 px = u_rect.xy + a_pos * u_rect.zw;
    \\  vec2 ndc = vec2(px.x / u_screen.x * 2.0 - 1.0, 1.0 - px.y / u_screen.y * 2.0);
    \\  gl_Position = vec4(ndc, 0.0, 1.0);
    \\  v_local = a_pos * u_rect.zw;
    \\  v_size = u_rect.zw;
    \\}
;

const rect_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_local;
    \\varying vec2 v_size;
    \\uniform vec4 u_color;
    \\uniform vec4 u_color2;
    \\uniform float u_radius;
    \\uniform float u_shadow;
    \\uniform int u_mode;
    \\float rounded_box(vec2 p, vec2 b, float r) {
    \\  vec2 q = abs(p) - b + vec2(r);
    \\  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    \\}
    \\void main() {
    \\  vec2 p = v_local - v_size * 0.5;
    \\  float d = rounded_box(p, v_size * 0.5, u_radius);
    \\  float aa = 1.0;
    \\  float alpha = 1.0 - smoothstep(0.0, aa, d);
    \\  if (u_mode == 1) {
    \\    float sd = rounded_box(p - vec2(0.0, -u_shadow * 0.18), v_size * 0.5, u_radius + u_shadow * 0.35);
    \\    float blur = max(u_shadow, 1.0);
    \\    alpha = 1.0 - smoothstep(-blur, blur, sd);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * alpha * 0.28);
    \\  } else if (u_mode == 2) {
    \\    float inner = rounded_box(p, v_size * 0.5 - vec2(1.25), max(u_radius - 1.25, 0.0));
    \\    float border = (1.0 - smoothstep(0.0, aa, d)) * smoothstep(0.0, aa, inner);
    \\    gl_FragColor = vec4(u_color.rgb, u_color.a * border);
    \\  } else if (u_mode == 3) {
    \\    float t = clamp(v_local.y / max(v_size.y, 1.0), 0.0, 1.0);
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

const text_fragment_shader =
    \\precision mediump float;
    \\varying vec2 v_uv;
    \\varying vec4 v_color;
    \\uniform sampler2D u_tex;
    \\void main() {
    \\  float sd = texture2D(u_tex, v_uv).b;
    \\  float a = smoothstep(0.47, 0.53, sd);
    \\  gl_FragColor = vec4(v_color.rgb, v_color.a * a);
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

test "font atlas refresh API accepts populated variable font atlas" {
    var atlas = renderer_font_atlas.Atlas.init();
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushText(buffers, atlas.source(), .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, "A", .text, .start);
    try std.testing.expect(atlas.cachedGlyphCount() > 0);
}

test "text shader samples varfont true distance channel" {
    try std.testing.expect(std.mem.indexOf(u8, text_fragment_shader, "texture2D(u_tex, v_uv).b") != null);
    try std.testing.expect(std.mem.indexOf(u8, text_fragment_shader, "median3") == null);
}

const std = @import("std");
const wasm_gl = @import("../wasm_gl.zig");
const gl_contract = @import("../gl_contract.zig");
const renderer_ir = @import("../ir.zig");
const renderer_font_atlas = @import("../font_atlas_weighted.zig");
const ui = @import("../../ui.zig");
const renderer_present = @import("../present.zig");

pub const State = struct {
    rect_program: wasm_gl.GLuint,
    textured_program: wasm_gl.GLuint,
    image_program: wasm_gl.GLuint,
    line_program: wasm_gl.GLuint,
    rect_vbo: wasm_gl.GLuint,
    textured_vbo: wasm_gl.GLuint,
    line_vbo: wasm_gl.GLuint,
    font_texture: wasm_gl.GLuint,
    image_texture: ?wasm_gl.GLuint,
    font_atlas_width: usize,
    font_atlas_height: usize,
    font_atlas_generation: u32,
    image_texture_initialized: bool,
};

pub fn initState(font_atlas: *renderer_font_atlas.Atlas) State {
    const rect_program = makeProgram(gl_contract.rect_vertex_shader, gl_contract.rect_fragment_shader);
    const textured_program = makeProgram(gl_contract.textured_vertex_shader, gl_contract.text_fragment_shader);
    const image_program = makeProgram(gl_contract.textured_vertex_shader, gl_contract.image_fragment_shader);
    const line_program = makeProgram(gl_contract.line_vertex_shader, gl_contract.line_fragment_shader);
    return .{
        .rect_program = rect_program,
        .textured_program = textured_program,
        .image_program = image_program,
        .line_program = line_program,
        .rect_vbo = makeBuffer(),
        .textured_vbo = makeBuffer(),
        .line_vbo = makeBuffer(),
        .font_texture = makeAlphaTextureFiltered(font_atlas.width, font_atlas.height, font_atlas.alphaSlice()),
        .image_texture = null,
        .font_atlas_width = font_atlas.width,
        .font_atlas_height = font_atlas.height,
        .font_atlas_generation = font_atlas.cacheRevision(),
        .image_texture_initialized = false,
    };
}

pub fn deinit(gl: *State) void {
    if (gl.image_texture) |texture| {
        const id = texture;
        wasm_gl.glDeleteTextures(1, id);
    }
    wasm_gl.glDeleteTextures(1, gl.font_texture);
    wasm_gl.glDeleteBuffers(1, gl.rect_vbo);
    wasm_gl.glDeleteBuffers(1, gl.textured_vbo);
    wasm_gl.glDeleteBuffers(1, gl.line_vbo);
    wasm_gl.glDeleteProgram(gl.rect_program);
    wasm_gl.glDeleteProgram(gl.textured_program);
    wasm_gl.glDeleteProgram(gl.image_program);
    wasm_gl.glDeleteProgram(gl.line_program);
}

pub fn refreshFontTexture(gl: *State, font_atlas: *const renderer_font_atlas.Atlas) void {
    if (font_atlas.cacheRevision() == gl.font_atlas_generation) return;
    wasm_gl.glBindTexture(wasm_gl.gl_texture_2d, gl.font_texture);
    wasm_gl.glPixelStorei(wasm_gl.gl_unpack_alignment, 1);
    wasm_gl.glTexSubImage2D(
        wasm_gl.gl_texture_2d, 0, 0, 0,
        @intCast(font_atlas.width), @intCast(font_atlas.height),
        wasm_gl.gl_alpha, wasm_gl.gl_unsigned_byte,
        @intFromPtr(font_atlas.alphaSlice().ptr),
    );
    gl.font_atlas_generation = font_atlas.cacheRevision();
    gl.font_atlas_width = font_atlas.width;
    gl.font_atlas_height = font_atlas.height;
}

pub fn ensureImageTexture(gl: *State, image: ?renderer_ir.RgbaTexture) void {
    if (gl.image_texture_initialized) return;
    gl.image_texture_initialized = true;
    const texture = if (image) |img| blk: {
        if (!img.valid()) return;
        const t = makeRgbaTexture(img.width, img.height, img.pixels);
        break :blk t;
    } else makeEmptyRgbaTexture(1, 1);
    gl.image_texture = texture;
}

pub fn renderFrame(gl: *State, width: i32, height: i32, scale: f32, buffers: renderer_ir.Buffers) !void {
    wasm_gl.glViewport(0, 0, width, height);
    wasm_gl.glClear(wasm_gl.gl_color_buffer_bit);
    try drawRects(gl, width, height, scale, buffers.liveRects());
    drawImage(gl, width, height, buffers.liveImageVertices());
    drawTextured(gl, width, height, buffers.liveTextVertices(), gl.font_texture, gl.textured_program);
    drawIconLines(gl, width, height, buffers.liveIconLineVertices());
    try drawRects(gl, width, height, scale, buffers.liveOverlayRects());
    drawTextured(gl, width, height, buffers.liveOverlayTextVertices(), gl.font_texture, gl.textured_program);
    drawIconLines(gl, width, height, buffers.liveOverlayIconLineVertices());
}

fn drawRects(gl: *State, width: i32, height: i32, scale: f32, values: []const f32) !void {
    var iter = try renderer_ir.RectIterator.init(values);
    wasm_gl.glUseProgram(gl.rect_program);
    const screen_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_screen);
    wasm_gl.glUniform2f(screen_loc, @floatFromInt(width), @floatFromInt(height));
    const pixel_scale_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_pixel_scale);
    wasm_gl.glUniform1f(pixel_scale_loc, scale);
    wasm_gl.glBindBuffer(wasm_gl.gl_array_buffer, gl.rect_vbo);
    const verts = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1 };
    wasm_gl.glBufferData(wasm_gl.gl_array_buffer, @intCast(verts.len * @sizeOf(f32)), @intFromPtr(&verts), wasm_gl.gl_static_draw);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    wasm_gl.glVertexAttribPointer(gl_contract.attr_pos_location, 2, wasm_gl.gl_float, wasm_gl.gl_false, 2 * @sizeOf(f32), 0);
    const rect_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_rect);
    const source_rect_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_source_rect);
    const color_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_color);
    const color2_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_color2);
    const radius_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_radius);
    const shadow_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_shadow);
    const mode_loc = getUniformLocation(gl.rect_program, gl_contract.uniform_mode);
    while (try iter.next()) |rect| {
        const draw_bounds = rectDrawBounds(rect);
        wasm_gl.glUniform4f(rect_loc, draw_bounds.x, draw_bounds.y, draw_bounds.w, draw_bounds.h);
        wasm_gl.glUniform4f(source_rect_loc, rect.bounds.x, rect.bounds.y, rect.bounds.w, rect.bounds.h);
        wasm_gl.glUniform4f(color_loc, colorF(rect.color.r), colorF(rect.color.g), colorF(rect.color.b), colorF(rect.color.a));
        wasm_gl.glUniform4f(color2_loc, colorF(rect.color2.r), colorF(rect.color2.g), colorF(rect.color2.b), colorF(rect.color2.a));
        wasm_gl.glUniform1f(radius_loc, rect.radius);
        wasm_gl.glUniform1f(shadow_loc, rect.shadow);
        wasm_gl.glUniform1i(mode_loc, rectMode(rect.mode));
        wasm_gl.glDrawArrays(wasm_gl.gl_triangle_strip, 0, 4);
    }
}

fn rectDrawBounds(rect: anytype) ui.Rect {
    return switch (rect.mode) {
        .shadow => rect.bounds.insetUniform(-rect.shadow),
        .fill, .border, .linear_gradient, .pie_slice => rect.bounds,
    };
}

fn drawImage(gl: *State, width: i32, height: i32, values: []const f32) void {
    if (values.len == 0) return;
    const texture = gl.image_texture orelse return;
    drawTextured(gl, width, height, values, texture, gl.image_program);
}

fn drawTextured(gl: *State, width: i32, height: i32, values: []const f32, texture: wasm_gl.GLuint, program: wasm_gl.GLuint) void {
    if (values.len == 0) return;
    if (values.len % renderer_ir.text_vertex_float_stride != 0) return;
    wasm_gl.glUseProgram(program);
    const screen_loc = getUniformLocation(program, gl_contract.uniform_screen);
    wasm_gl.glUniform2f(screen_loc, @floatFromInt(width), @floatFromInt(height));
    wasm_gl.glActiveTexture(wasm_gl.gl_texture0);
    wasm_gl.glBindTexture(wasm_gl.gl_texture_2d, texture);
    const texture_loc = getUniformLocation(program, gl_contract.uniform_texture);
    wasm_gl.glUniform1i(texture_loc, 0);
    if (program == gl.textured_program) {
        const texture_kind_loc = getUniformLocation(program, gl_contract.uniform_texture_kind);
        wasm_gl.glUniform1i(texture_kind_loc, gl_contract.texture_kind_alpha);
    }
    wasm_gl.glBindBuffer(wasm_gl.gl_array_buffer, gl.textured_vbo);
    wasm_gl.glBufferData(wasm_gl.gl_array_buffer, @intCast(values.len * @sizeOf(f32)), @intFromPtr(values.ptr), wasm_gl.gl_dynamic_draw);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_uv_location);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_color_location);
    wasm_gl.glVertexAttribPointer(gl_contract.attr_pos_location, 2, wasm_gl.gl_float, wasm_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), 0);
    wasm_gl.glVertexAttribPointer(gl_contract.attr_uv_location, 2, wasm_gl.gl_float, wasm_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), 2 * @sizeOf(f32));
    wasm_gl.glVertexAttribPointer(gl_contract.attr_color_location, 4, wasm_gl.gl_float, wasm_gl.gl_false, renderer_ir.text_vertex_float_stride * @sizeOf(f32), 4 * @sizeOf(f32));
    wasm_gl.glDrawArrays(wasm_gl.gl_triangles, 0, @intCast(values.len / renderer_ir.text_vertex_float_stride));
}

fn drawIconLines(gl: *State, width: i32, height: i32, values: []const f32) void {
    if (values.len == 0) return;
    if (values.len % @import("../icon_line_buffer.zig").vertex_float_stride != 0) return;
    wasm_gl.glUseProgram(gl.line_program);
    const screen_loc = getUniformLocation(gl.line_program, gl_contract.uniform_screen);
    wasm_gl.glUniform2f(screen_loc, @floatFromInt(width), @floatFromInt(height));
    wasm_gl.glBindBuffer(wasm_gl.gl_array_buffer, gl.line_vbo);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_pos_location);
    wasm_gl.glEnableVertexAttribArray(gl_contract.attr_color_location);
    const icon_line_stride = @import("../icon_line_buffer.zig").vertex_float_stride * @sizeOf(f32);
    wasm_gl.glVertexAttribPointer(gl_contract.attr_pos_location, 2, wasm_gl.gl_float, wasm_gl.gl_false, icon_line_stride, 0);
    wasm_gl.glVertexAttribPointer(gl_contract.attr_color_location, 4, wasm_gl.gl_float, wasm_gl.gl_false, icon_line_stride, @import("../icon_line_buffer.zig").vertex_color_r_index * @sizeOf(f32));
    wasm_gl.glBufferData(wasm_gl.gl_array_buffer, @intCast(values.len * @sizeOf(f32)), @intFromPtr(values.ptr), wasm_gl.gl_dynamic_draw);
    wasm_gl.glDrawArrays(wasm_gl.gl_triangles, 0, @intCast(values.len / @import("../icon_line_buffer.zig").vertex_float_stride));
}

fn makeBuffer() wasm_gl.GLuint {
    return wasm_gl.glGenBuffers(1);
}

fn makeAlphaTextureFiltered(width: usize, height: usize, alpha: []const u8) wasm_gl.GLuint {
    const texture = wasm_gl.glGenTextures(1);
    wasm_gl.glBindTexture(wasm_gl.gl_texture_2d, texture);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_min_filter, wasm_gl.gl_linear);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_mag_filter, wasm_gl.gl_linear);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_s, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_t, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glPixelStorei(wasm_gl.gl_unpack_alignment, 1);
    wasm_gl.glTexImage2D(
        wasm_gl.gl_texture_2d, 0, wasm_gl.gl_alpha,
        @intCast(width), @intCast(height), 0,
        wasm_gl.gl_alpha, wasm_gl.gl_unsigned_byte,
        @intFromPtr(alpha.ptr),
    );
    return texture;
}

fn makeRgbaTexture(width: usize, height: usize, pixels: []const ui.Color) wasm_gl.GLuint {
    const texture = wasm_gl.glGenTextures(1);
    wasm_gl.glBindTexture(wasm_gl.gl_texture_2d, texture);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_min_filter, wasm_gl.gl_linear);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_mag_filter, wasm_gl.gl_linear);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_s, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_t, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glPixelStorei(wasm_gl.gl_unpack_alignment, 1);
    wasm_gl.glTexImage2D(
        wasm_gl.gl_texture_2d, 0, wasm_gl.gl_rgba,
        @intCast(width), @intCast(height), 0,
        wasm_gl.gl_rgba, wasm_gl.gl_unsigned_byte,
        @intFromPtr(pixels.ptr),
    );
    return texture;
}

fn makeEmptyRgbaTexture(width: usize, height: usize) wasm_gl.GLuint {
    const texture = wasm_gl.glGenTextures(1);
    wasm_gl.glBindTexture(wasm_gl.gl_texture_2d, texture);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_min_filter, wasm_gl.gl_nearest);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_mag_filter, wasm_gl.gl_nearest);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_s, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glTexParameteri(wasm_gl.gl_texture_2d, wasm_gl.gl_texture_wrap_t, wasm_gl.gl_clamp_to_edge);
    wasm_gl.glPixelStorei(wasm_gl.gl_unpack_alignment, 1);
    wasm_gl.glTexImage2D(
        wasm_gl.gl_texture_2d, 0, wasm_gl.gl_rgba,
        @intCast(width), @intCast(height), 0,
        wasm_gl.gl_rgba, wasm_gl.gl_unsigned_byte,
        0,
    );
    return texture;
}

fn makeProgram(vertex_source: [:0]const u8, fragment_source: [:0]const u8) wasm_gl.GLuint {
    const vertex = makeShader(wasm_gl.gl_vertex_shader, vertex_source);
    const fragment = makeShader(wasm_gl.gl_fragment_shader, fragment_source);
    const program = wasm_gl.glCreateProgram();
    if (program == 0) @panic("GL program creation failed");
    wasm_gl.glAttachShader(program, vertex);
    wasm_gl.glAttachShader(program, fragment);
    glBindAttribLocation(program, gl_contract.attr_pos_location, gl_contract.attr_pos);
    glBindAttribLocation(program, gl_contract.attr_uv_location, gl_contract.attr_uv);
    glBindAttribLocation(program, gl_contract.attr_color_location, gl_contract.attr_color);
    wasm_gl.glLinkProgram(program);
    const ok = wasm_gl.glGetProgramiv(program, wasm_gl.gl_link_status);
    if (ok == 0) @panic("GL program link failed");
    wasm_gl.glDeleteShader(vertex);
    wasm_gl.glDeleteShader(fragment);
    return program;
}

fn makeShader(kind: wasm_gl.GLenum, source: [:0]const u8) wasm_gl.GLuint {
    const shader = wasm_gl.glCreateShader(kind);
    if (shader == 0) @panic("GL shader creation failed");
    wasm_gl.glShaderSource(shader, 1, @intFromPtr(source.ptr), @intCast(source.len));
    wasm_gl.glCompileShader(shader);
    const ok = wasm_gl.glGetShaderiv(shader, wasm_gl.gl_compile_status);
    if (ok == 0) @panic("GL shader compile failed");
    return shader;
}

fn glBindAttribLocation(program: wasm_gl.GLuint, index: wasm_gl.GLuint, name: [:0]const u8) void {
    wasm_gl.glBindAttribLocation(program, index, @intFromPtr(name.ptr), @intCast(name.len));
}

fn getUniformLocation(program: wasm_gl.GLuint, name: [:0]const u8) wasm_gl.GLint {
    return wasm_gl.glGetUniformLocation(program, @intFromPtr(name.ptr), @intCast(name.len));
}

fn colorF(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn rectMode(mode: ui.RectMode) wasm_gl.GLint {
    return switch (mode) {
        .fill => 0,
        .shadow => 1,
        .border => 2,
        .linear_gradient => 3,
        .pie_slice => 0,
    };
}
